`timescale 1ns / 1ps
// runs one riscv-test, pick the program with +hex=file
// compile with -DPIPE for the pipelined CPU
module rvt_tb;

    reg clk = 0;
    reg rst = 1;

always #5 clk = ~clk;

`ifdef PIPE
top_pipe #(.INIT_FILE("")) dut (.clk(clk), .rst(rst));
`else
top #(.INIT_FILE("")) dut (.clk(clk), .rst(rst));
`endif

// result word at 0x3FF0 = mem[4092]: 1 = pass, (test << 1) | 1 = fail
`define RESULT dut.u_memory.mem[4092]

    integer cycles = 0;
    reg [255:0] hex;

initial begin
if (!$value$plusargs("hex=%s", hex)) begin
$display("usage: vvp sim +hex=file.hex");
$finish;
end
$readmemh(hex, dut.u_memory.mem);
`RESULT = 32'h0;

#10 rst = 0;

// run until a result is written, give up after 20000 cycles
while (`RESULT == 32'h0 && cycles < 20000) begin
@(posedge clk);
            cycles = cycles + 1;
end
#1;

if (cycles >= 20000) $display("FAIL: %0s timed out", hex);
else if (`RESULT == 32'h1) $display("PASS: %0s (%0d cycles)", hex, cycles);
else $display("FAIL: %0s test %0d", hex, `RESULT >> 1);

$finish;
end
endmodule
