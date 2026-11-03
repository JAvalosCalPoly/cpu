`timescale 1ns / 1ps
// runs test_priv.hex (from test_priv.S): M drops to U, U can't use M-only things
module top_pipe_priv_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

    top_pipe #(
        .INIT_FILE("testbenches/test_priv.hex")
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(1'b1)
    );

    // results at 0x400 = mem[256], result n = mem[256 + n]
    `define SIG(n) dut.u_memory.mem[256 + n]
    `define CAUSE(t) `SIG(4 + 3*(t))
    `define STATUS(t) `SIG(5 + 3*(t))
    `define TVEC(t) `SIG(6 + 3*(t))

    integer cycles = 0;
    integer pass = 0, fail = 0;
    integer t;

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
        $dumpfile("top_pipe_priv.vcd");
        $dumpvars(0, top_pipe_priv_tb);

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

        // mcause per trap
        check(`CAUSE(0), 32'd8, "ecall from U: mcause 8");
        check(`CAUSE(1), 32'd2, "csrr mstatus from U: illegal");
        check(`CAUSE(2), 32'd2, "csrw mtvec from U: illegal");
        check(`CAUSE(3), 32'd2, "mret from U: illegal");
        check(`CAUSE(4), 32'd8, "ecall after bad mret: still U");
        // every trap came from U: MPP = 00
        for (t = 0; t < 5; t = t + 1)
        check(`STATUS(t), 32'h0000_0000, "mstatus in handler: MPP = U");
        // U never changed mtvec
        for (t = 0; t < 5; t = t + 1) check(`TVEC(t), `SIG(1), "mtvec kept");
        // illegal csrr didn't write rd
        check(`SIG(0), 32'h0000_0055, "illegal csrr: t1 kept");
        // handler ends in M
        check(dut.u_core.priv_o, 2'b11, "priv = M at end");
        check(`SIG(60), 32'hD0E0_000D, "DONE marker");

        $display("%0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule
