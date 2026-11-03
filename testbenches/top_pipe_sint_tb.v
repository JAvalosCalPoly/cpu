`timescale 1ns / 1ps
// runs test_smode.hex: M -> S -> U, ecall from U delegated to S, ecall from S to M
module top_pipe_smode_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

    top_pipe #(
        .INIT_FILE("testbenches/test_sint.hex")
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(1'b1)
    );

    // results at 0x400 = mem[256], result n = mem[256 + n]
    `define SIG(n) dut.u_memory.mem[256 + n]

    integer cycles = 0;
    integer pass = 0, fail = 0;

    // one check per result
    task check(input [31:0] got, input [31:0] exp, input [8*40-1:0] name);
        begin
            if (got !== exp) begin
                $display("FAIL: %0s, expected %h, got %h", name, exp, got);
                fail = fail + 1;
            end else begin
                $display("PASS: %0s = %h", name, got);
                pass = pass + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("top_pipe_smode.vcd");
        $dumpvars(0, top_pipe_smode_tb);

        #10 rst = 0;

        // run until DONE marker (result 60) or 2000 cycles
        while (
        `SIG(60)
        !== 32'hD0E0_000D && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

        if (cycles >= 2000)
            $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
        else $display("DONE after %0d cycles", cycles);
        // [0] mcause, [1] mstatus, [2] scause, [3] sstatus, [4] sip, [60] DONE
        check(`SIG(0), 32'h80000007, "mcause: M timer interrupt");
        check(`SIG(1), 32'h00000882, "mstatus: MPP = S, SIE kept");
        check(`SIG(2), 32'h80000005, "scause: S timer interrupt");
        check(`SIG(3), 32'h00000120, "sstatus: SPP = S, SPIE = 1");
        check(`SIG(4), 32'h00000020, "sip: STIP = 1");
        check(dut.u_core.priv_o, 2'b01, "priv is S at the end");
        check(`SIG(60), 32'hD0E0000D, "DONE");

        $display("%0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
