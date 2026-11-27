`timescale 1ns / 1ps

module top_pipe_counters_tb;
    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

    top_pipe #(
        .INIT_FILE("testbenches/test_counters.hex")
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

    initial begin
        $dumpfile("build/top_pipe_counters.vcd");
        $dumpvars(0, top_pipe_counters_tb);

        #10 rst = 0;

        while (
        `SIG(60)
        !== 32'hD0E0_000D && cycles < 4000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

        if (cycles >= 4000) begin
            $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
            fail = fail + 1;
        end else $display("DONE after %0d cycles", cycles);

        check(0, 32'd4, "instret delta");
        check(2, 32'd100, "minstret write");
        check(4, 32'd2, "csrw cycle traps");
        check(60, 32'hD0E0_000D, "DONE marker");

        // ranges: x fails too
        if (^`SIG(1) === 1'bx || `SIG(1) == 0 || `SIG(1) > 10) begin
            $display("FAIL: [1] cycle delta, got %0d", `SIG(1));
            fail = fail + 1;
        end else begin
            $display("PASS: [1] cycle delta = %0d", `SIG(1));
            pass = pass + 1;
        end
        if (^`SIG(3) === 1'bx || `SIG(3) == 0 || `SIG(3) > 20) begin
            $display("FAIL: [3] rdtime vs mtime, got %0d", `SIG(3));
            fail = fail + 1;
        end else begin
            $display("PASS: [3] rdtime vs mtime = %0d", `SIG(3));
            pass = pass + 1;
        end

        $display("%0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
