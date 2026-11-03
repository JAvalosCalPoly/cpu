`timescale 1ns / 1ps
// runs test_smode.hex: M -> S -> U, ecall from U delegated to S, ecall from S to M
module top_pipe_smode_tb;

    reg clk = 0;
    reg rst = 1;

always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_smode.hex"))
dut (.clk(clk), .rst(rst), .uart_rx(1'b1));

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
while (`SIG(60) !== 32'hD0E0_000D && cycles < 2000) begin
@(posedge clk);
            cycles = cycles + 1;
end
#1;

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// S mode works
check(`SIG(0), 32'h0000_5C5C, "sscratch from S");
// U ecall delegated to S
check(`SIG(2), 32'd8, "scause: ecall from U");
check(`SIG(3), `SIG(1), "sepc = U ecall");
check(`SIG(4), 32'h0000_0000, "sstatus: SPP = U");
// S ecall not delegated, goes to M
check(`SIG(6), 32'd9, "mcause: ecall from S");
check(`SIG(7), `SIG(5), "mepc = S ecall");
check(`SIG(8), 32'h0000_0800, "mstatus: MPP = S");
// ends in M
check(dut.u_core.priv_o, 2'b11, "priv = M at end");
check(`SIG(60), 32'hD0E0_000D, "DONE marker");

$display("%0d passed / %0d failed", pass, fail);
$finish;
end
endmodule