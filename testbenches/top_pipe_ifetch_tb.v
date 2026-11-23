`timescale 1ns / 1ps
// runs test_ifetch.hex: Sv32 fetch translation: VA code, stale itlb, sfence, fetch faults
module top_pipe_ifetch_tb;

    reg clk = 0;
    reg rst = 1;

always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_ifetch.hex"))
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
$dumpvars(0, top_pipe_ifetch_tb);

#10 rst = 0;

// run until DONE marker (result 60) or 2000 cycles
while (`SIG(60) !== 32'hD0E0_000D && cycles < 2000) begin
@(posedge clk);
            cycles = cycles + 1;
end
#1;

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// fault log at 0x480 = mem[288], 3 words each
`define LOG(n) dut.u_memory.mem[288 + n]
// S code runs from a virtual address
check(`SIG(0) & 32'hFFFF_F000, 32'h8000_0000, "S pc is virtual (0x8000xxxx)");
// itlb and sfence
check(`SIG(1), 32'h0000_0011, "VA 0x5300 -> stub A");
check(`SIG(2), 32'h0000_0011, "remap, no sfence: stale itlb");
check(`SIG(3), 32'h0000_0022, "after sfence: stub B");
// fetch from page without X
check(`LOG(0), 32'd12, "no-X fetch: cause 12");
check(`LOG(1), 32'h0000_1300, "  tval = fetch VA");
check(`LOG(2), 32'h0000_1300, "  epc = fetch VA");
// U fetch from kernel page
check(`LOG(3), 32'd12, "U fetch kernel page: cause 12");
check(`LOG(4), `SIG(4), "  tval = VA of u_code");
check(`LOG(5), `SIG(4), "  epc = VA of u_code");
// ends in M
check(dut.u_core.priv_o, 2'b11, "priv = M at end");
check(`SIG(60), 32'hD0E0_000D, "DONE marker");

$display("%0d passed / %0d failed", pass, fail);
$finish;
end
endmodule