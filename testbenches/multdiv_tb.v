`timescale 1ns / 1ps
module multdiv_tb;

    reg  [31:0] a;
    reg  [31:0] b;
    reg  [2:0]  funct3;
    wire [31:0] result;

    multdiv dut (
        .a(a),
        .b(b),
        .funct3(funct3),
        .result(result)
    );

// funct3: 000 mul  001 mulh  010 mulhsu  011 mulhu
//         100 div  101 divu  110 rem     111 remu

initial begin
$dumpfile("multdiv.vcd");
$dumpvars(0, multdiv_tb);

// mul (low 32 bits)
        a = 32'd6; b = 32'd7; funct3 = 3'b000; #10;
if (result !== 32'd42) $display("FAIL: mul 6 * 7 != %d", result);
else $display("PASS: mul 6 * 7 = %d", result);

// -2 * 3 = -6: the low half is the same whether you treat inputs as signed or not
        a = 32'hFFFF_FFFE; b = 32'd3; funct3 = 3'b000; #10;
if (result !== 32'hFFFF_FFFA) $display("FAIL: mul -2 * 3 != %h", result);
else $display("PASS: mul -2 * 3 = %h (-6)", result);

// mulh (high 32 bits, signed x signed)
// -1 * 1 = -1 = FFFFFFFF_FFFFFFFF, high half is FFFFFFFF
        a = 32'hFFFF_FFFF; b = 32'd1; funct3 = 3'b001; #10;
if (result !== 32'hFFFF_FFFF) $display("FAIL: mulh -1 * 1 != %h", result);
else $display("PASS: mulh -1 * 1 = %h", result);

// -1 * -1 = 1 = 00000000_00000001, high half is 0
        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; funct3 = 3'b001; #10;
if (result !== 32'h0000_0000) $display("FAIL: mulh -1 * -1 != %h", result);
else $display("PASS: mulh -1 * -1 = %h", result);

// -2^31 * -2^31 = 2^62 = 40000000_00000000
        a = 32'h8000_0000; b = 32'h8000_0000; funct3 = 3'b001; #10;
if (result !== 32'h4000_0000) $display("FAIL: mulh 80000000 * 80000000 != %h", result);
else $display("PASS: mulh 80000000 * 80000000 = %h", result);

// mulhsu (high 32 bits, a signed x b unsigned)
// a = -1, b = 4294967295 -> -4294967295 = FFFFFFFF_00000001
        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; funct3 = 3'b010; #10;
if (result !== 32'hFFFF_FFFF) $display("FAIL: mulhsu -1 * FFFFFFFF != %h", result);
else $display("PASS: mulhsu -1 * FFFFFFFF = %h", result);

// mulhu (high 32 bits, unsigned x unsigned)
// FFFFFFFF * FFFFFFFF = FFFFFFFE_00000001
        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; funct3 = 3'b011; #10;
if (result !== 32'hFFFF_FFFE) $display("FAIL: mulhu FFFFFFFF * FFFFFFFF != %h", result);
else $display("PASS: mulhu FFFFFFFF * FFFFFFFF = %h", result);

// div (signed, rounds toward zero)
        a = 32'd20; b = 32'd3; funct3 = 3'b100; #10;
if (result !== 32'd6) $display("FAIL: div 20 / 3 != %d", result);
else $display("PASS: div 20 / 3 = %d", result);

// -20 / 3 = -6 (toward zero, not -7)
        a = 32'hFFFF_FFEC; b = 32'd3; funct3 = 3'b100; #10;
if (result !== 32'hFFFF_FFFA) $display("FAIL: div -20 / 3 != %h", result);
else $display("PASS: div -20 / 3 = %h (-6)", result);

// divide by zero: RISC-V says the answer is all ones (-1), no trap
        a = 32'd20; b = 32'd0; funct3 = 3'b100; #10;
if (result !== 32'hFFFF_FFFF) $display("FAIL: div 20 / 0 != %h", result);
else $display("PASS: div 20 / 0 = %h", result);

// overflow: -2^31 / -1 would be +2^31, which doesn't fit. RISC-V says return -2^31
        a = 32'h8000_0000; b = 32'hFFFF_FFFF; funct3 = 3'b100; #10;
if (result !== 32'h8000_0000) $display("FAIL: div 80000000 / -1 != %h", result);
else $display("PASS: div 80000000 / -1 = %h", result);

// divu (unsigned)
        a = 32'd20; b = 32'd3; funct3 = 3'b101; #10;
if (result !== 32'd6) $display("FAIL: divu 20 / 3 != %d", result);
else $display("PASS: divu 20 / 3 = %d", result);

// FFFFFFFF is 4294967295 unsigned, not -1
        a = 32'hFFFF_FFFF; b = 32'd2; funct3 = 3'b101; #10;
if (result !== 32'h7FFF_FFFF) $display("FAIL: divu FFFFFFFF / 2 != %h", result);
else $display("PASS: divu FFFFFFFF / 2 = %h", result);

        a = 32'd20; b = 32'd0; funct3 = 3'b101; #10;
if (result !== 32'hFFFF_FFFF) $display("FAIL: divu 20 / 0 != %h", result);
else $display("PASS: divu 20 / 0 = %h", result);

// rem (signed, result takes the sign of a)
        a = 32'd20; b = 32'd3; funct3 = 3'b110; #10;
if (result !== 32'd2) $display("FAIL: rem 20 %% 3 != %d", result);
else $display("PASS: rem 20 %% 3 = %d", result);

// -20 % 3 = -2 (because -20 = 3 * -6 + -2)
        a = 32'hFFFF_FFEC; b = 32'd3; funct3 = 3'b110; #10;
if (result !== 32'hFFFF_FFFE) $display("FAIL: rem -20 %% 3 != %h", result);
else $display("PASS: rem -20 %% 3 = %h (-2)", result);

// 20 % -3 = 2 (sign follows a, not b)
        a = 32'd20; b = 32'hFFFF_FFFD; funct3 = 3'b110; #10;
if (result !== 32'd2) $display("FAIL: rem 20 %% -3 != %h", result);
else $display("PASS: rem 20 %% -3 = %h", result);

// remainder by zero: RISC-V says return a
        a = 32'd20; b = 32'd0; funct3 = 3'b110; #10;
if (result !== 32'd20) $display("FAIL: rem 20 %% 0 != %d", result);
else $display("PASS: rem 20 %% 0 = %d", result);

// overflow case: remainder is 0
        a = 32'h8000_0000; b = 32'hFFFF_FFFF; funct3 = 3'b110; #10;
if (result !== 32'd0) $display("FAIL: rem 80000000 %% -1 != %h", result);
else $display("PASS: rem 80000000 %% -1 = %h", result);

// remu (unsigned)
        a = 32'd20; b = 32'd3; funct3 = 3'b111; #10;
if (result !== 32'd2) $display("FAIL: remu 20 %% 3 != %d", result);
else $display("PASS: remu 20 %% 3 = %d", result);

        a = 32'd20; b = 32'd0; funct3 = 3'b111; #10;
if (result !== 32'd20) $display("FAIL: remu 20 %% 0 != %d", result);
else $display("PASS: remu 20 %% 0 = %d", result);

$finish;
end
endmodule