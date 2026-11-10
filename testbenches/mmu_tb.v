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
    reg         i_req = 0;
    reg  [31:0] i_va = 0;
    reg         i_kill = 0;
    wire [31:0] i_pa;
    wire i_ok, i_fault;

    mmu dut (
        .clk      (clk),
        .rst      (rst),
        .i_req    (i_req),
        .i_va     (i_va),
        .i_kill   (i_kill),
        .i_pa     (i_pa),
        .i_ok     (i_ok),
        .i_fault  (i_fault),
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

    // one fetch: wait until ok or fault, check i_pa/i_fault and walk
    task fetch(input [1:0] p, input [31:0] v, input exp_fault, input [31:0] exp_pa, input exp_walk,
               input [8*32-1:0] name);
        begin
            priv  = p;
            i_va  = v;
            i_req = 1;
            #1;
            cycles = 0;
            while (!i_ok && !i_fault && cycles < 20) begin  // timeout
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (cycles >= 20) begin
                $display("FAIL: %0s: va=%h fetch never finished", name, v);
                fail = fail + 1;
            end else if (i_fault !== exp_fault || (!exp_fault && i_pa !== exp_pa) ||
                         ((cycles != 0) !== exp_walk)) begin
                $display(
                    "FAIL: %0s: va=%h => i_pa=%h i_fault=%b walk=%0d cycles, expected i_pa=%h i_fault=%b walk=%b",
                    name, v, i_pa, i_fault, cycles, exp_pa, exp_fault, exp_walk);
                fail = fail + 1;
            end else begin
                $display("PASS: %0s: va=%h => i_pa=%h i_fault=%b (%0d cycles)", name, v, i_pa,
                         i_fault, cycles);
                pass = pass + 1;
            end
            @(posedge clk);
            #1;
            i_req = 0;
        end
    endtask

    task do_flush;
        begin
            tlb_flush = 1;
            @(posedge clk);
            #1;
            tlb_flush = 0;
        end
    endtask

    integer d_done, i_done;
    reg saw_stall;

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
        ram[16'h1014>>2] = 32'h000C00DB;  // L0[5]: user RX -> 0x00300

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

        // ---- fetch side ----
        do_flush;
        fetch(2'b01, 32'h80000010, 0, 32'h80000010, 1, "S fetch kernel mega: walk");
        fetch(2'b01, 32'h80000FF0, 0, 32'h80000FF0, 0, "S fetch kernel mega: hit");
        fetch(2'b01, 32'h00401234, 1, 32'h0, 1, "S fetch RW page (X=0): fault");
        fetch(2'b00, 32'h80000010, 1, 32'h0, 0, "U fetch kernel page: hit fault");
        fetch(2'b00, 32'h00405010, 0, 32'h00300010, 1, "U fetch user RX page: walk");

        // D and I miss together: D walks first
        do_flush;
        priv = 2'b00;
        store = 0;
        va = 32'h00401234;
        i_va = 32'h00405010;
        req = 1;
        i_req = 1;
        d_done = -1;
        i_done = -1;
        for (k = 0; k < 30 && (d_done < 0 || i_done < 0); k = k + 1) begin
            #1;
            if (d_done < 0 && !stall) d_done = k;
            if (i_done < 0 && i_ok) i_done = k;
            @(posedge clk);
        end
        if (d_done < 0 || i_done < 0 || !(d_done < i_done) || pa !== 32'h00200234 ||
            i_pa !== 32'h00300010) begin
            $display("FAIL: D+I miss: d_done=%0d i_done=%0d pa=%h i_pa=%h", d_done, i_done, pa,
                     i_pa);
            fail = fail + 1;
        end else begin
            $display("PASS: D+I miss: D done at %0d, then I at %0d", d_done, i_done);
            pass = pass + 1;
        end
        req   = 0;
        i_req = 0;
        #1;

        // I-walk owns the port: a D hit must stall
        do_flush;
        access (2'b00, 0, 32'h00401234, 0, 32'h00200234, 1, "fill DTLB");
        i_va  = 32'h00405010;
        i_req = 1;
        @(posedge clk);  // I-walk starts
        #1;
        va = 32'h00401234;
        req = 1;
        saw_stall = 0;
        for (k = 0; k < 20 && !i_ok; k = k + 1) begin
            #1;
            if (stall) saw_stall = 1;
            @(posedge clk);
        end
        #1;
        check(saw_stall, 1'b1, "D hit stalls during I-walk");
        check(stall, 1'b0, "  then D goes");
        req   = 0;
        i_req = 0;

        // i_kill mid I-walk: no fill
        do_flush;
        priv  = 2'b01;
        i_va  = 32'h80000010;
        i_req = 1;
        @(posedge clk);
        #1;
        i_kill = 1;
        @(posedge clk);
        #1;
        i_kill = 0;
        i_req  = 0;
        check(ptw_busy, 1'b0, "i_kill: walker idle");
        repeat (5) @(posedge clk);
        #1;
        fetch(2'b01, 32'h80000010, 0, 32'h80000010, 1, "after i_kill: walks again");

        $display("mmu testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
