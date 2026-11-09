`timescale 1ns / 1ps
// runs test_tval.hex: M -> S -> U, ecall from U delegated to S, ecall from S to M
module top_pipe_tval_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

    top_pipe #(
        .INIT_FILE("testbenches/test_tval.hex")
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
        $dumpfile("top_pipe_tval.vcd");
        $dumpvars(0, top_pipe_tval_tb);

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
        // illegal .word
        check(`SIG(0), 32'd2, "mcause: illegal word");
        check(`SIG(1), 32'hFFFF_FFFF, "mtval: instr bits");
        // csr not real
        check(`SIG(2), 32'd2, "mcause: bad csr");
        check(`SIG(3), 32'h7C00_2373, "mtval: csrr bits");
        // ebreak
        check(`SIG(4), 32'd3, "mcause: ebreak");
        check(`SIG(5), `SIG(6), "mtval: ebreak pc");
        // ecall
        check(`SIG(7), 32'd11, "mcause: ecall from M");
        check(`SIG(8), 32'd0, "mtval: ecall clears");
        // delegated illegal in S
        check(`SIG(9), 32'd2, "scause: illegal in S");
        check(`SIG(10), 32'hFFFF_FFFF, "stval: instr bits");
        check(dut.u_core.priv_o, 2'b01, "priv = S at end");
        check(`SIG(60), 32'hD0E0_000D, "DONE marker");

        $display("%0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
