`timescale 1ns / 1ps
// runs test_timer.hex (from test_timer.S) on the pipelined CPU and checks the results
module top_pipe_timer_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_timer.hex"))
dut (.clk(clk), .rst(rst));

// results at 0x400 = mem[256], result n = mem[256 + n]
// partial sums at 0x600 = mem[384], partial[i] = mem[384 + i]
`define SIG(n) dut.u_memory.mem[256 + n]
`define PART(i) dut.u_memory.mem[384 + i]

    integer cycles = 0;
    integer pass = 0, fail = 0;
    integer i, sum, bad;

// one check per result
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
$dumpfile("top_pipe_timer.vcd");
$dumpvars(0, top_pipe_timer_tb);

        #10 rst = 0;

// run until DONE marker (result 16) or 3000 cycles
        while (`SIG(16) !== 32'hD0E0_000D && cycles < 3000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

if (cycles >= 3000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// bus
        check(3,  `SIG(0),       "ram word 0 untouched by timer stores");
        check(1,  32'h1234_5678, "mtimecmp lo readback");
        check(2,  32'h0000_9ABC, "mtimecmp hi readback");
        check(4,  32'h0000_0004, "mtime +4 over 4 instrs");
        check(5,  32'h0000_0000, "mip clear before setup");
// interrupt
        check(6,  32'd1275,      "loop sum 1..50");
        check(7,  32'h0000_0001, "handler ran once");
        check(8,  32'h8000_0007, "mcause = timer interrupt");
        check(10, 32'h0000_0080, "mstatus in handler: MIE->MPIE");
        check(11, 32'h0000_0080, "mip in handler: MTIP set");
        check(12, 32'h0000_0088, "mstatus after mret");
        check(13, 32'h0000_0000, "mip after mtimecmp moved");

// mepc points into the loop, no +4
        if (`SIG(9) >= `SIG(14) && `SIG(9) < `SIG(15)) begin
            $display("PASS: [9] mepc in loop = %h", `SIG(9)); pass = pass + 1;
        end else begin
            $display("FAIL: [9] mepc %h not in loop %h..%h", `SIG(9), `SIG(14), `SIG(15)); fail = fail + 1;
        end

// every partial sum stored once, correctly
        sum = 0; bad = 0;
        for (i = 1; i <= 50; i = i + 1) begin
            sum = sum + i;
            if (`PART(i) !== sum) bad = bad + 1;
        end
        if (bad == 0) begin
            $display("PASS: 50 partial sums correct"); pass = pass + 1;
        end else begin
            $display("FAIL: %0d partial sums wrong", bad); fail = fail + 1;
        end

        check(16, 32'hD0E0_000D, "DONE marker");

$display("%0d passed / %0d failed", pass, fail);
$finish;
end
endmodule