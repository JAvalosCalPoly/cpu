`timescale 1ns / 1ps
module mmu_tb;

    reg         clk = 0;
    reg         rst = 1;
    reg         req = 0;
    reg         store = 0;
    reg  [31:0] va = 0;
    reg  [ 1:0] priv = 2'b11;
    reg         tlb_flush = 0;
    reg         kill = 0;
    wire [31:0] pa;
    wire stall, fault, ptw_busy;
    wire [31:0] ptw_addr;
    reg  [31:0] mem_rdata = 0;

    mmu dut (
        .clk      (clk),
        .rst      (rst),
        .req      (req),
        .store    (store),
        .va       (va),
        .priv     (priv),
        .satp     (32'h8000_0400),  // Sv32, root at 0x00400000
        .sum      (1'b0),
        .mxr      (1'b0),
        .tlb_flush(tlb_flush),
        .kill     (kill),
        .pa       (pa),
        .stall    (stall),
        .fault    (fault),
        .ptw_busy (ptw_busy),
        .ptw_addr (ptw_addr),
        .mem_rdata(mem_rdata)
    );

    always #5 clk = ~clk;  // 10 ns clock

    // fake block ram, read 1 cycle later
    reg [31:0] ram[0:16383];  // index addr[15:2]
    always @(posedge clk) mem_rdata <= ram[ptw_addr[15:2]];

    integer pass = 0, fail = 0;
    integer k, cycles;
    reg [31:0] first_addr = 0;
    reg        seen = 0;
    always @(posedge clk)
        if (ptw_busy && !seen) begin
            first_addr <= ptw_addr;
            seen <= 1;
        end

    // one access: wait while stalled, check pa/fault/stall cycles
    task access (input [1:0] p, input st, input [31:0] v, input exp_fault, input [31:0] exp_pa,
                 input exp_walk, input [8*32-1:0] name);
        begin
            priv  = p;
            store = st;
            va    = v;
            req   = 1;
            #1;
            cycles = 0;
            while (stall && cycles < 20) begin  // timeout
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (cycles >= 20) begin
                $display("FAIL: %0s: va=%h stuck in stall", name, v);
                fail = fail + 1;
            end else if (fault !== exp_fault || (!exp_fault && pa !== exp_pa) ||
                         ((cycles != 0) !== exp_walk)) begin
                $display(
                    "FAIL: %0s: va=%h => pa=%h fault=%b walk=%0d cycles, expected pa=%h fault=%b walk=%b",
                    name, v, pa, fault, cycles, exp_pa, exp_fault, exp_walk);
                fail = fail + 1;
            end else begin
                $display("PASS: %0s: va=%h => pa=%h fault=%b (%0d stall cycles)", name, v, pa,
                         fault, cycles);
                pass = pass + 1;
            end
            @(posedge clk);  // instr leaves EX
            #1;
            req = 0;
        end
    endtask

    task check(input got, input exp, input [8*32-1:0] name);
        begin
            if (got !== exp) begin
                $display("FAIL: %0s = %b, expected %b", name, got, exp);
                fail = fail + 1;
            end else begin
                $display("PASS: %0s = %b", name, got);
                pass = pass + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("mmu.vcd");
        $dumpvars(0, mmu_tb);

        // page tables (same as ptw_tb)
        for (k = 0; k < 16384; k = k + 1) ram[k] = 0;
        ram[16'h0004>>2] = 32'h00100401;  // root[1]: -> 0x00401000
        ram[16'h0800>>2] = 32'h200000CF;  // root[512]: kernel mega 0x80000000
        ram[16'h0804>>2] = 32'h201000CF;  // root[513]: kernel mega 0x80400000
        ram[16'h1004>>2] = 32'h000800D7;  // L0[1]: user RW -> 0x00200
        ram[16'h100C>>2] = 32'h00080005;  // L0[3]: W without R
        ram[16'h1010>>2] = 32'h00100001;  // L0[4]: pointer at L0

        #12 rst = 0;  // off the clock edge

        access (2'b11, 0, 32'h00401234, 0, 32'h00401234, 0, "M: no translation");
        access (2'b01, 0, 32'h00401234, 1, 32'h0, 1,
                "S load user page, SUM=0");  // walk ok, then perm fault
        if (first_addr !== 32'h0040_0004) begin
            $display("FAIL: first walk read %h, expected 00400004 (root[1])", first_addr);
            fail = fail + 1;
        end else begin
            $display("PASS: first walk read root[1] at %h", first_addr);
            pass = pass + 1;
        end
        access (2'b00, 0, 32'h00401234, 0, 32'h00200234, 0, "U load: TLB hit");
        access (2'b00, 1, 32'h00401010, 0, 32'h00200010, 0, "U store RW page: hit");
        access (2'b01, 0, 32'h80000010, 0, 32'h80000010, 1, "S load megapage: walk");
        access (2'b01, 0, 32'h80000FFC, 0, 32'h80000FFC, 0, "S load megapage: hit");
        access (2'b01, 0, 32'h00402008, 1, 32'h0, 1, "S load invalid: walk fault");
        access (2'b00, 0, 32'h80000010, 1, 32'h0, 0, "U load kernel page: hit fault");
        access (2'b01, 0, 32'h00403000, 1, 32'h0, 1, "S load W-without-R: fault");
        access (2'b01, 0, 32'h00404000, 1, 32'h0, 1, "S load pointer at L0: fault");

        // sfence.vma empties the tlb
        tlb_flush = 1;
        @(posedge clk);
        #1;
        tlb_flush = 0;
        access (2'b00, 0, 32'h00401234, 0, 32'h00200234, 1, "after flush: walk again");

        // kill mid-walk: no fill
        priv = 2'b01;
        store = 0;
        va = 32'h80400000;
        req = 1;
        @(posedge clk);
        #1;
        kill = 1;
        @(posedge clk);
        #1;
        kill = 0;
        req  = 0;
        check(ptw_busy, 1'b0, "kill: walker idle");
        repeat (5) @(posedge clk);
        #1;
        access (2'b01, 0, 32'h80400000, 0, 32'h80400000, 1, "after kill: walks again");

        $display("mmu testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
