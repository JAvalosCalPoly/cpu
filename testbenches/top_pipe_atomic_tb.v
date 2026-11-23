`timescale 1ns / 1ps

module top_pipe_atomic_tb;
    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

    top_pipe #(
        .INIT_FILE("testbenches/test_atomic.hex")
    ) dut (
        .clk(clk),
        .rst(rst)
    );

    `define SIG(n) dut.u_memory.mem[256 + n]

    integer cycles = 0;
    integer pass = 0;
    integer fail = 0;

    task check(input integer n, input [31:0] exp, input [8*40-1:0] name);
        begin
            if (`SIG(n) !== exp) begin
                $display("FAIL: [%0d] %0s, expected %h, got %h", n, name, exp, `SIG(n));
                fail = fail + 1;
            end else begin
                $display("PASS: [%0d] %0s = %h", n, name, `SIG(n));
                pass = pass + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("top_pipe_atomic.vcd");
        $dumpvars(0, top_pipe_atomic_tb);

        #10 rst = 0;

        while (`SIG(60) !== 32'hD0E0_000D && cycles < 4000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

        if (cycles >= 4000)
            $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
        else
            $display("DONE after %0d cycles", cycles);

        check(0, 32'h0000_000C, "amoadd rd");
        check(1, 32'h0000_0013, "amoadd mem");
        check(2, 32'h0000_0018, "amoadd rs2 forward");
        check(3, 32'h0000_0019, "amoswap rd forward");
        check(4, 32'h0000_0008, "amoand mem");
        check(5, 32'h0000_000E, "amoor mem");
        check(6, 32'h0000_0006, "amoxor mem");
        check(7, 32'hFFFF_FFFF, "amomin mem");
        check(8, 32'hFFFF_FFFF, "amomaxu mem");
        check(9, 32'h0000_0000, "lr/sc rd");
        check(10, 32'h0000_0077, "lr/sc mem");
        check(11, 32'h0000_0001, "second sc rd");
        check(12, 32'h0000_0077, "second sc mem");
        check(13, 32'h0000_0001, "sc other word");
        check(14, 32'h0000_0001, "sc after trap");
        check(15, 32'h0000_0078, "lr load-use");
        check(16, 32'h0000_000D, "aq/rl amoadd mem");
        check(60, 32'hD0E0_000D, "DONE marker");

        $display("%0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
