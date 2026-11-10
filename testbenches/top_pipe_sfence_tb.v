`timescale 1ns / 1ps
// runs test_sfence.hex: sfence.vma: ok in M and S, illegal in U
module top_pipe_sfence_tb;

    reg clk = 0;
    reg rst = 1;

always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_sfence.hex"))
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
$dumpfile("top_pipe_sfence.vcd");
$dumpvars(0, top_pipe_sfence_tb);

#10 rst = 0;

// run until DONE marker (result 60) or 2000 cycles
while (`SIG(60) !== 32'hD0E0_000D && cycles < 2000) begin
@(posedge clk);
            cycles = cycles + 1;
end
#1;

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// M and S: sfence is a nop
check(`SIG(0), 32'h0000_0011, "past sfence in M");
check(`SIG(1), 32'h0000_0022, "past sfence in S");
// U: illegal instruction
check(`SIG(2), 32'h0000_0000, "instr after U sfence flushed");
check(`SIG(3), 32'd2, "mcause: illegal");
check(`SIG(4), `SIG(6), "mepc = U sfence");
check(`SIG(5), 32'h1200_0073, "mtval = sfence bits");
// ends in M
check(dut.u_core.priv_o, 2'b11, "priv = M at end");
check(`SIG(60), 32'hD0E0_000D, "DONE marker");

$display("%0d passed / %0d failed", pass, fail);
$finish;
end
endmodule