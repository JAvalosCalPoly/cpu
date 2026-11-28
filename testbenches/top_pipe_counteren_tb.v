`timescale 1ns / 1ps

module top_pipe_counteren_tb;
    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

    top_pipe #(
        .INIT_FILE("testbenches/test_counteren.hex")
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(1'b1)  // idle line
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

    // read worked: not x, not 0
    task nonzero(input integer n, input [8*40-1:0] name);
        begin
            if (^`SIG(n) === 1'bx || `SIG(n) == 0) begin
                $display("FAIL: [%0d] %0s, got %h", n, name, `SIG(n));
                fail = fail + 1;
            end else begin
                $display("PASS: [%0d] %0s = %0d", n, name, `SIG(n));
                pass = pass + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("build/top_pipe_counteren.vcd");
        $dumpvars(0, top_pipe_counteren_tb);

        #10 rst = 0;

        while (`SIG(60) !== 32'hD0E0_000D && cycles < 4000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

        if (cycles >= 4000) begin
            $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
            fail = fail + 1;
        end else $display("DONE after %0d cycles", cycles);

        nonzero(0, "S rdtime, TM=1");
        check(1, 32'd2, "S rdcycle, CY=0 traps");
        check(2, 32'd2, "U rdtime, sTM=0 traps");
        nonzero(3, "U rdtime, sTM=1");
        check(4, 32'd0, "no unexpected trap");
        check(60, 32'hD0E0_000D, "DONE marker");

        $display("%0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
