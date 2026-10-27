`timescale 1ns / 1ps
// runs test_csr.hex (from test_csr.S) on the pipelined CPU and checks the results
module top_pipe_csr_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_csr.hex"))
dut (.clk(clk), .rst(rst));

// results at 0x400 = mem[256], result n = mem[256 + n]
`define SIG(n) dut.u_memory.mem[256 + n]

    integer cycles = 0;
    integer pass = 0, fail = 0;

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
$dumpfile("top_pipe_csr.vcd");
$dumpvars(0, top_pipe_csr_tb);

        #10 rst = 0;

// run until DONE marker (result 21) or 2000 cycles
        while (`SIG(21) !== 32'hD0E0_000D && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// write / read
        check(0,  32'h1234_5678, "csrw then csrr");
        check(1,  32'h1234_5678, "csrrw old value");
        check(2,  32'h0000_AAAA, "csrrw new value");
// set / clear
        check(3,  32'h0000_AAAA, "csrrs old value");
        check(4,  32'h0000_AFAF, "csrrs AAAA | 0F0F");
        check(5,  32'h0000_AF00, "csrrc AFAF & ~00FF");
// mstatus
        check(6,  32'h0000_0008, "csrsi mstatus MIE");
        check(7,  32'h0000_0088, "mstatus all ones -> 88");
        check(8,  32'h0000_0088, "csrrci old value");
        check(9,  32'h0000_0080, "csrrci clears MIE");
// mepc
        check(10, 32'h0000_1000, "mepc 1003 -> 1000");
// hazards
        check(11, 32'h0000_AF01, "csr-use stall");
        check(12, 32'h0000_0055, "forward into csr src");
        check(13, 32'h0000_00AA, "csr then gap then use");
// x0 rules
        check(14, 32'h0000_0077, "csrrs rs1=x0 reads");
        check(15, 32'h0000_0077, "csrrs rs1=x0 no write");
        check(16, 32'h0000_0000, "csrrw rs1=x0 writes 0");
        check(17, 32'h0000_001F, "csrrwi uimm 31");
// other csrs
        check(18, 32'h0000_0100, "mtvec");
        check(19, 32'h0000_000B, "mcause");
        check(20, 32'h0000_0000, "unknown csr reads 0");
        check(21, 32'hD0E0_000D, "DONE marker");

$display("%0d passed / %0d failed", pass, fail);
$finish;
end
endmodule