`timescale 1ns / 1ps
// runs test_nohazard.hex (from test_nohazard.S) on the pipelined CPU and checks the results
// to watch registers change, compile with -DWATCH
module top_pipe_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_asm_hazards.hex"))
dut (.clk(clk), .rst(rst));

// answers start at 0x400 = mem[256], box n is mem[256 + n]
`define SIG(n) dut.u_memory.mem[256 + n]
// register n inside reg32
`define X(n) dut.u_core.u_reg32.q[n]

    integer cycles = 0;

// x5 = value, x9 = pointer, x18 = counter, x12 - x17 = answers
`ifdef WATCH
initial
$monitor("%5t  x5=%h x9=%h x18=%h | sum=%h max=%h min=%h neg=%h umax=%h prod=%h",
    $time, `X(5), `X(9), `X(18), `X(12), `X(13), `X(14), `X(15), `X(16), `X(17));
`endif

initial begin
$dumpfile("top_pipe.vcd");
$dumpvars(0, top_pipe_tb);

        #10 rst = 0;

// run until DONE (box 9), give up after 2000 cycles
        while (`SIG(9) !== 32'hD0E0_000D && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;
`ifdef WATCH
$monitoroff; // stop printing so the results are easy to read
`endif

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// array loops
if (`SIG(0) !== 32'h0000_0021) $display("FAIL: [0] sum = 33, got %h", `SIG(0));
else $display("PASS: [0] sum = 33 = %h", `SIG(0));
if (`SIG(1) !== 32'h0000_0019) $display("FAIL: [1] max (signed) = 25, got %h", `SIG(1));
else $display("PASS: [1] max (signed) = 25 = %h", `SIG(1));
if (`SIG(2) !== 32'hFFFF_FFF8) $display("FAIL: [2] min (signed) = -8, got %h", `SIG(2));
else $display("PASS: [2] min (signed) = -8 = %h", `SIG(2));
if (`SIG(3) !== 32'h0000_0002) $display("FAIL: [3] negatives = 2, got %h", `SIG(3));
else $display("PASS: [3] negatives = 2 = %h", `SIG(3));
if (`SIG(4) !== 32'hFFFF_FFFD) $display("FAIL: [4] max (unsigned) = -3, got %h", `SIG(4));
else $display("PASS: [4] max (unsigned) = -3 = %h", `SIG(4));
if (`SIG(5) !== 32'h0000_C4E0) $display("FAIL: [5] product (no 0s) = 50400, got %h", `SIG(5));
else $display("PASS: [5] product (no 0s) = 50400 = %h", `SIG(5));

// div / rem
if (`SIG(6) !== 32'h0000_0005) $display("FAIL: [6] sum / 6 = 5, got %h", `SIG(6));
else $display("PASS: [6] sum / 6 = 5 = %h", `SIG(6));
if (`SIG(7) !== 32'h0000_0003) $display("FAIL: [7] sum %% 6 = 3, got %h", `SIG(7));
else $display("PASS: [7] sum %% 6 = 3 = %h", `SIG(7));

// function call
if (`SIG(8) !== 32'h0000_0006) $display("FAIL: [8] gcd(48, 18) = 6, got %h", `SIG(8));
else $display("PASS: [8] gcd(48, 18) = 6 = %h", `SIG(8));

// done
if (`SIG(9) !== 32'hD0E0_000D) $display("FAIL: [9] DONE marker, got %h", `SIG(9));
else $display("PASS: [9] DONE marker = %h", `SIG(9));

// the CPU ends on "end: j end" at 1F8
// pipelined, so pc keeps fetching 1F8, 1FC, 200 then jumps back
        repeat (5) @(posedge clk); #1;
if (dut.u_core.pc < 32'h0000_0124 || dut.u_core.pc > 32'h0000_0200) $display("FAIL: final pc = %h", dut.u_core.pc);
else $display("PASS: final pc = %h (spinning on end)", dut.u_core.pc);

$finish;
end
endmodule