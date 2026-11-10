`timescale 1ns / 1ps
module ptw_tb;

    reg         clk = 0;
    reg         rst = 1;
    reg         start = 0;
    reg  [19:0] vpn = 0;
    wire        mem_req;
    wire [31:0] mem_addr;
    reg         mem_ready = 0;
    reg  [31:0] mem_rdata = 0;
    wire done, fault, mega, busy;
    wire [21:0] ppn;
    wire [ 7:0] flags;

    ptw dut (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .vpn      (vpn),
        .satp_ppn (22'h00400),  // root table at 0x00400000
        .mem_req  (mem_req),
        .mem_addr (mem_addr),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),
        .done     (done),
        .fault    (fault),
        .ppn      (ppn),
        .flags    (flags),
        .mega     (mega),
        .busy     (busy)
    );

    always #5 clk = ~clk;  // 10 ns clock

    // fake memory: answers 1 cycle after req, like block ram
    reg [31:0] ram[0:16383];  // index addr[15:2]
    always @(posedge clk) begin
        mem_ready <= mem_req && !mem_ready;  // 1-cycle pulse
        mem_rdata <= ram[mem_addr[15:2]];
    end

    integer pass = 0, fail = 0;
    integer k, cycles;

    // one walk, check result
    task walk(input [19:0] v, input exp_fault, input [21:0] exp_ppn, input [7:0] exp_flags,
              input exp_mega, input [8*32-1:0] name);
        begin
            vpn   = v;
            start = 1;
            @(posedge clk);
            #1;
            start  = 0;
            cycles = 0;
            while (!done && cycles < 20) begin  // timeout
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (cycles >= 20) begin
                $display("FAIL: %0s: vpn=%h never finished", name, v);
                fail = fail + 1;
            end else if (fault !== exp_fault ||
                         (!exp_fault && (ppn !== exp_ppn || flags !== exp_flags || mega !== exp_mega))) begin
                $display(
                    "FAIL: %0s: vpn=%h => fault=%b ppn=%h flags=%h mega=%b, expected fault=%b ppn=%h flags=%h mega=%b",
                    name, v, fault, ppn, flags, mega, exp_fault, exp_ppn, exp_flags, exp_mega);
                fail = fail + 1;
            end else begin
                $display("PASS: %0s: vpn=%h => fault=%b ppn=%h mega=%b (%0d cycles)", name, v,
                         fault, ppn, mega, cycles);
                pass = pass + 1;
            end
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $dumpfile("ptw.vcd");
        $dumpvars(0, ptw_tb);

        // page tables (everything else 0 = invalid)
        for (k = 0; k < 16384; k = k + 1) ram[k] = 0;
        ram[16'h0004>>2] = 32'h00100401;  // 0x00400004 root[1]: -> 0x00401000
        ram[16'h000C>>2] = 32'h000004CF;  // 0x0040000C root[3]: mega, PPN[0]=1
        ram[16'h0010>>2] = 32'h000008CF;  // 0x00400010 root[4]: mega, PPN[0]=2
        ram[16'h0800>>2] = 32'h200000CF;  // 0x00400800 root[512]: kernel mega
        ram[16'h1004>>2] = 32'h000800D7;  // 0x00401004 L0[1]: user RW -> 0x00200
        ram[16'h100C>>2] = 32'h00080005;  // 0x0040100C L0[3]: W without R
        ram[16'h1010>>2] = 32'h00100001;  // 0x00401010 L0[4]: pointer at L0

        #12 rst = 0;  // off the clock edge

        walk(20'h00401, 0, 22'h00200, 8'hD7, 0, "4K user page");
        walk(20'h80000, 0, 22'h80000, 8'hCF, 1, "kernel megapage");
        walk(20'h00402, 1, 0, 0, 0, "L0 invalid");
        walk(20'h00800, 1, 0, 0, 0, "L1 invalid");
        walk(20'h00C00, 1, 0, 0, 0, "misaligned mega (bit 10)");
        walk(20'h00403, 1, 0, 0, 0, "W without R");
        walk(20'h00404, 1, 0, 0, 0, "pointer at L0");
        walk(20'h01000, 1, 0, 0, 0, "misaligned mega (bit 11)");

        $display("ptw testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule