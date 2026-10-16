`timescale 1ns / 1ps
// runs test_asm.hex (from test_asm.S) on the pipelined CPU and checks the results
module top_pipe_asm_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

top_pipe #(.INIT_FILE("testbenches/test_asm.hex"))
dut (.clk(clk), .rst(rst));

// The program writes one result word per test into memory starting at
// address 0x400. Memory is indexed by word, so address 0x400 is mem[256],
// and result n is mem[256 + n].
// `SIG(n) is a shortcut so each check doesn't need the full path.
`define SIG(n) dut.u_memory.mem[256 + n]

    integer cycles = 0;

initial begin
$dumpfile("top_pipe_asm.vcd");
$dumpvars(0, top_pipe_asm_tb);

        #10 rst = 0;

// Run until the program writes its DONE marker (result 46), or give up after
// 2000 cycles. This way the test doesn't care how many cycles the CPU needs,
// so it still works once the core is pipelined.
        while (`SIG(46) !== 32'hD0E0_000D && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

if (cycles >= 2000) $display("FAIL: never reached DONE (timed out after %0d cycles)", cycles);
else $display("DONE after %0d cycles", cycles);

// arithmetic
if (`SIG(0) !== 32'h0000_000C) $display("FAIL: [0] add  5 + 7 = 12, got %h", `SIG(0));
else $display("PASS: [0] add  5 + 7 = 12 = %h", `SIG(0));
if (`SIG(1) !== 32'h0000_0007) $display("FAIL: [1] sub  12 - 5 = 7, got %h", `SIG(1));
else $display("PASS: [1] sub  12 - 5 = 7 = %h", `SIG(1));
if (`SIG(2) !== 32'hFFFF_FFFE) $display("FAIL: [2] sub  5 - 7 = -2, got %h", `SIG(2));
else $display("PASS: [2] sub  5 - 7 = -2 = %h", `SIG(2));
if (`SIG(3) !== 32'hFFFF_F800) $display("FAIL: [3] addi -2 + -2046 = -2048, got %h", `SIG(3));
else $display("PASS: [3] addi -2 + -2046 = -2048 = %h", `SIG(3));

// lui / auipc
if (`SIG(4) !== 32'h1234_5678) $display("FAIL: [4] lui + addi = 12345678, got %h", `SIG(4));
else $display("PASS: [4] lui + addi = 12345678 = %h", `SIG(4));
if (`SIG(5) !== 32'h7FFF_FFFF) $display("FAIL: [5] lui 80000000 + addi -1, got %h", `SIG(5));
else $display("PASS: [5] lui 80000000 + addi -1 = %h", `SIG(5));
if (`SIG(6) !== 32'h0000_0044) $display("FAIL: [6] auipc = address of here, got %h", `SIG(6));
else $display("PASS: [6] auipc = address of here = %h", `SIG(6));

// logic
if (`SIG(7) !== 32'hEDCB_A987) $display("FAIL: [7] xori -1 (not), got %h", `SIG(7));
else $display("PASS: [7] xori -1 (not) = %h", `SIG(7));
if (`SIG(8) !== 32'h0000_0778) $display("FAIL: [8] andi then ori, got %h", `SIG(8));
else $display("PASS: [8] andi then ori = %h", `SIG(8));
if (`SIG(9) !== 32'hFFFF_FFFF) $display("FAIL: [9] xor x ^ not x, got %h", `SIG(9));
else $display("PASS: [9] xor x ^ not x = %h", `SIG(9));
if (`SIG(10) !== 32'h0000_0000) $display("FAIL: [10] and x & not x, got %h", `SIG(10));
else $display("PASS: [10] and x & not x = %h", `SIG(10));
if (`SIG(11) !== 32'h0000_0007) $display("FAIL: [11] or 5 | 7, got %h", `SIG(11));
else $display("PASS: [11] or 5 | 7 = %h", `SIG(11));

// shifts
if (`SIG(12) !== 32'h0000_0050) $display("FAIL: [12] slli 5 << 4, got %h", `SIG(12));
else $display("PASS: [12] slli 5 << 4 = %h", `SIG(12));
if (`SIG(13) !== 32'h0000_000E) $display("FAIL: [13] srli EDCBA987 >> 28, got %h", `SIG(13));
else $display("PASS: [13] srli EDCBA987 >> 28 = %h", `SIG(13));
if (`SIG(14) !== 32'hFFFF_FFFE) $display("FAIL: [14] srai EDCBA987 >>> 28, got %h", `SIG(14));
else $display("PASS: [14] srai EDCBA987 >>> 28 = %h", `SIG(14));
if (`SIG(15) !== 32'h0000_0280) $display("FAIL: [15] sll 5 << 7, got %h", `SIG(15));
else $display("PASS: [15] sll 5 << 7 = %h", `SIG(15));
if (`SIG(16) !== 32'h07FF_FFFF) $display("FAIL: [16] srl FFFFFFFF >> 5, got %h", `SIG(16));
else $display("PASS: [16] srl FFFFFFFF >> 5 = %h", `SIG(16));
if (`SIG(17) !== 32'hFF6E_5D4C) $display("FAIL: [17] sra EDCBA987 >>> 5, got %h", `SIG(17));
else $display("PASS: [17] sra EDCBA987 >>> 5 = %h", `SIG(17));

// compares
if (`SIG(18) !== 32'h0000_0001) $display("FAIL: [18] slt -2 < 5, got %h", `SIG(18));
else $display("PASS: [18] slt -2 < 5 = %h", `SIG(18));
if (`SIG(19) !== 32'h0000_0000) $display("FAIL: [19] sltu FFFFFFFE < 5, got %h", `SIG(19));
else $display("PASS: [19] sltu FFFFFFFE < 5 = %h", `SIG(19));
if (`SIG(20) !== 32'h0000_0001) $display("FAIL: [20] slti -2 < -1, got %h", `SIG(20));
else $display("PASS: [20] slti -2 < -1 = %h", `SIG(20));
if (`SIG(21) !== 32'h0000_0001) $display("FAIL: [21] sltiu 5 < FFFFFFFF, got %h", `SIG(21));
else $display("PASS: [21] sltiu 5 < FFFFFFFF = %h", `SIG(21));

// loads and stores
if (`SIG(22) !== 32'hFFFF_FF81) $display("FAIL: [22] lb, got %h", `SIG(22));
else $display("PASS: [22] lb = %h", `SIG(22));
if (`SIG(23) !== 32'h0000_0081) $display("FAIL: [23] lbu, got %h", `SIG(23));
else $display("PASS: [23] lbu = %h", `SIG(23));
if (`SIG(24) !== 32'hFFFF_8081) $display("FAIL: [24] lh, got %h", `SIG(24));
else $display("PASS: [24] lh = %h", `SIG(24));
if (`SIG(25) !== 32'h0000_8081) $display("FAIL: [25] lhu, got %h", `SIG(25));
else $display("PASS: [25] lhu = %h", `SIG(25));
if (`SIG(26) !== 32'h8081_7F02) $display("FAIL: [26] lw then addi (load-use), got %h", `SIG(26));
else $display("PASS: [26] lw then addi (load-use) = %h", `SIG(26));
if (`SIG(27) !== 32'h0007_0501) $display("FAIL: [27] sb + sh then lw, got %h", `SIG(27));
else $display("PASS: [27] sb + sh then lw = %h", `SIG(27));

// branches and loop
if (`SIG(28) !== 32'h0000_0007) $display("FAIL: [28] branches (1 + 2 + 4), got %h", `SIG(28));
else $display("PASS: [28] branches (1 + 2 + 4) = %h", `SIG(28));
if (`SIG(29) !== 32'h0000_0037) $display("FAIL: [29] loop sum 1..10 = 55, got %h", `SIG(29));
else $display("PASS: [29] loop sum 1..10 = 55 = %h", `SIG(29));

// jal / jalr
if (`SIG(30) !== 32'h0000_002A) $display("FAIL: [30] jal/jalr double(21) = 42, got %h", `SIG(30));
else $display("PASS: [30] jal/jalr double(21) = 42 = %h", `SIG(30));
if (`SIG(31) !== 32'h0000_0054) $display("FAIL: [31] jal/jalr double(42) = 84, got %h", `SIG(31));
else $display("PASS: [31] jal/jalr double(42) = 84 = %h", `SIG(31));
if (`SIG(32) !== 32'h0000_017C) $display("FAIL: [32] jal return address = ret2, got %h", `SIG(32));
else $display("PASS: [32] jal return address = ret2 = %h", `SIG(32));

// M extension
if (`SIG(33) !== 32'hFFFF_FFD6) $display("FAIL: [33] mul 6 * -7, got %h", `SIG(33));
else $display("PASS: [33] mul 6 * -7 = %h", `SIG(33));
if (`SIG(34) !== 32'h4000_0000) $display("FAIL: [34] mulh 80000000 * 80000000, got %h", `SIG(34));
else $display("PASS: [34] mulh 80000000 * 80000000 = %h", `SIG(34));
if (`SIG(35) !== 32'hFFFF_FFFE) $display("FAIL: [35] mulhu FFFFFFFF * FFFFFFFF, got %h", `SIG(35));
else $display("PASS: [35] mulhu FFFFFFFF * FFFFFFFF = %h", `SIG(35));
if (`SIG(36) !== 32'hFFFF_FFFF) $display("FAIL: [36] mulhsu -1 * FFFFFFFF, got %h", `SIG(36));
else $display("PASS: [36] mulhsu -1 * FFFFFFFF = %h", `SIG(36));
if (`SIG(37) !== 32'hFFFF_FFFD) $display("FAIL: [37] div -20 / 6, got %h", `SIG(37));
else $display("PASS: [37] div -20 / 6 = %h", `SIG(37));
if (`SIG(38) !== 32'hFFFF_FFFE) $display("FAIL: [38] rem -20 %% 6, got %h", `SIG(38));
else $display("PASS: [38] rem -20 %% 6 = %h", `SIG(38));
if (`SIG(39) !== 32'h2AAA_AAAA) $display("FAIL: [39] divu FFFFFFFF / 6, got %h", `SIG(39));
else $display("PASS: [39] divu FFFFFFFF / 6 = %h", `SIG(39));
if (`SIG(40) !== 32'h0000_0003) $display("FAIL: [40] remu FFFFFFFF %% 6, got %h", `SIG(40));
else $display("PASS: [40] remu FFFFFFFF %% 6 = %h", `SIG(40));
if (`SIG(41) !== 32'hFFFF_FFFF) $display("FAIL: [41] div 6 / 0, got %h", `SIG(41));
else $display("PASS: [41] div 6 / 0 = %h", `SIG(41));
if (`SIG(42) !== 32'h0000_0006) $display("FAIL: [42] rem 6 %% 0, got %h", `SIG(42));
else $display("PASS: [42] rem 6 %% 0 = %h", `SIG(42));
if (`SIG(43) !== 32'h8000_0000) $display("FAIL: [43] div 80000000 / -1, got %h", `SIG(43));
else $display("PASS: [43] div 80000000 / -1 = %h", `SIG(43));

// fibonacci, x0, done
if (`SIG(44) !== 32'h0000_1A6D) $display("FAIL: [44] fibonacci fib(20) = 6765, got %h", `SIG(44));
else $display("PASS: [44] fibonacci fib(20) = 6765 = %h", `SIG(44));
if (`SIG(45) !== 32'h0000_0000) $display("FAIL: [45] x0 stays 0, got %h", `SIG(45));
else $display("PASS: [45] x0 stays 0 = %h", `SIG(45));
if (`SIG(46) !== 32'hD0E0_000D) $display("FAIL: [46] DONE marker, got %h", `SIG(46));
else $display("PASS: [46] DONE marker = %h", `SIG(46));

// the CPU ends on "end: j end" at 230
// pipelined, so pc keeps fetching 230, 234, 238 then jumps back
        repeat (5) @(posedge clk); #1;
if (dut.u_core.pc < 32'h0000_0230 || dut.u_core.pc > 32'h0000_0238) $display("FAIL: final pc = %h", dut.u_core.pc);
else $display("PASS: final pc = %h (spinning on end)", dut.u_core.pc);

$finish;
end
endmodule