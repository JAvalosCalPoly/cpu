`timescale 1ns / 1ps
// runs test_trap.hex (from test_trap.S) on the pipelined CPU and checks the results
module top_pipe_trap_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_trap.hex"))
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
$dumpfile("top_pipe_trap.vcd");
$dumpvars(0, top_pipe_trap_tb);

        #10 rst = 0;

// run until DONE marker (result 17) or 2000 cycles
        while (`SIG(17) !== 32'hD0E0_000D && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// ecall
        check(0,  32'h0000_000B, "ecall mcause = 11");
        check(1,  `SIG(3),       "ecall mepc = its own pc");
        check(2,  32'h0000_0080, "ecall mstatus: MIE->MPIE");
// ebreak
        check(4,  32'h0000_0003, "ebreak mcause = 3");
        check(5,  `SIG(7),       "ebreak mepc = its own pc");
        check(6,  32'h0000_0080, "ebreak mstatus");
// illegal
        check(8,  32'h0000_0002, "illegal mcause = 2");
        check(9,  `SIG(11),      "illegal mepc = its own pc");
        check(10, 32'h0000_0080, "illegal mstatus");
// mret
        check(12, 32'h0000_0088, "mstatus after mret");
// precise trap
        check(13, 32'h0000_0077, "illegal R-type: rd not written");
        check(14, 32'h0000_0000, "store behind trap blocked");
        check(15, 32'h0000_0064, "div flushed, handler div ok");
// unknown csr
        check(18, 32'h0000_0002, "unknown csr mcause = 2");
        check(19, `SIG(20),      "unknown csr mepc = its own pc");
        check(21, 32'h0000_0055, "unknown csr: rd not written");
// handler
        check(16, 32'h0000_0007, "handler ran 7 times");
        check(17, 32'hD0E0_000D, "DONE marker");

$display("%0d passed / %0d failed", pass, fail);
$finish;
end
endmodule