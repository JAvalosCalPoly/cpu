`timescale 1ns / 1ps
// runs test_vm.hex: Sv32 data translation: loads, stores, faults, sfence
module top_pipe_vm_tb;

    reg clk = 0;
    reg rst = 1;

always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_vm.hex"))
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
$dumpvars(0, top_pipe_vm_tb);

#10 rst = 0;

// run until DONE marker (result 60) or 2000 cycles
while (`SIG(60) !== 32'hD0E0_000D && cycles < 2000) begin
@(posedge clk);
            cycles = cycles + 1;
end
#1;

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// faults logged at 0x480 = mem[288], 2 words each
`define LOG(n) dut.u_memory.mem[288 + n]
// translated loads/stores
check(`SIG(0), 32'h0000_AAAA, "VA 0x5000 -> PA 0x1000");
check(`SIG(1), 32'h0000_BBBB, "alias VA 0x6000, same PA");
check(`SIG(2), 32'h0000_BBBB, "megapage VA 0x80001000");
check(dut.u_memory.mem[32'h1000 >> 2], 32'h0000_BBBB, "ro store did not write");
// faults
check(`LOG(0), 32'd15, "store to ro page: cause 15");
check(`LOG(1), 32'h0000_6000, "  tval = VA");
check(`LOG(2), 32'd13, "load invalid page: cause 13");
check(`LOG(3), 32'h0000_7000, "  tval = VA");
check(`LOG(4), 32'd13, "S load user page, SUM=0: 13");
check(`LOG(5), 32'h0000_8000, "  tval = VA");
check(`SIG(3), 32'h0000_BBBB, "S load user page, SUM=1");
// sfence.vma
check(`SIG(4), 32'h0000_BBBB, "before sfence: old mapping");
check(`SIG(5), 32'h0000_00C7, "after sfence: new mapping");
// ends in M
check(dut.u_core.priv_o, 2'b11, "priv = M at end");
check(`SIG(60), 32'hD0E0_000D, "DONE marker");

$display("%0d passed / %0d failed", pass, fail);
$finish;
end
endmodule