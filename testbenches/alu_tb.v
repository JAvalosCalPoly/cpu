`timescale 1ns / 1ps
module alu_tb;

    reg  [31:0] a;
    reg  [31:0] b;
    reg  [3:0]  alu_op;
    wire [31:0] result;

    alu dut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result)
    );

// alu_op = {funct7 bit 30, funct3}
// 0000 add  1000 sub  0001 sll  0010 slt  0011 sltu
// 0100 xor  0101 srl  1101 sra  0110 or   0111 and

initial begin
$dumpfile("alu.vcd");
$dumpvars(0, alu_tb);

// add
        a = 32'd10; b = 32'd5; alu_op = 4'b0000; #10;
if (result !== 32'd15) $display("FAIL: add 10 + 5 != %d", result);
else $display("PASS: add 10 + 5 = %d", result);

// sub
        a = 32'd10; b = 32'd5; alu_op = 4'b1000; #10;
if (result !== 32'd5) $display("FAIL: sub 10 - 5 != %d", result);
else $display("PASS: sub 10 - 5 = %d", result);

// sub going negative
        a = 32'd5; b = 32'd10; alu_op = 4'b1000; #10;
if (result !== 32'hFFFF_FFFB) $display("FAIL: sub 5 - 10 != %h", result);
else $display("PASS: sub 5 - 10 = %h (-5)", result);

// sll
        a = 32'd1; b = 32'd4; alu_op = 4'b0001; #10;
if (result !== 32'd16) $display("FAIL: sll 1 << 4 != %d", result);
else $display("PASS: sll 1 << 4 = %d", result);

// sll only uses the low 5 bits of b: 33 = 100001, so shift by 1
        a = 32'd1; b = 32'd33; alu_op = 4'b0001; #10;
if (result !== 32'd2) $display("FAIL: sll 1 << 33 (low 5 bits = 1) != %d", result);
else $display("PASS: sll 1 << 33 (low 5 bits = 1) = %d", result);

// slt: -1 < 1 signed, so 1
        a = 32'hFFFF_FFFF; b = 32'd1; alu_op = 4'b0010; #10;
if (result !== 32'd1) $display("FAIL: slt -1 < 1 != %d", result);
else $display("PASS: slt -1 < 1 = %d", result);

// sltu: FFFFFFFF < 1 unsigned is false, so 0
        a = 32'hFFFF_FFFF; b = 32'd1; alu_op = 4'b0011; #10;
if (result !== 32'd0) $display("FAIL: sltu FFFFFFFF < 1 != %d", result);
else $display("PASS: sltu FFFFFFFF < 1 = %d", result);

// sltu with 0: "sltu rd, x0, rs" is the "rs != 0" trick, so 0 < 5 gives 1
        a = 32'd0; b = 32'd5; alu_op = 4'b0011; #10;
if (result !== 32'd1) $display("FAIL: sltu 0 < 5 != %d", result);
else $display("PASS: sltu 0 < 5 = %d", result);

// xor
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; alu_op = 4'b0100; #10;
if (result !== 32'hF0F0_0F0F) $display("FAIL: xor != %h", result);
else $display("PASS: xor = %h", result);

// srl: zeros fill in
        a = 32'h8000_0000; b = 32'd4; alu_op = 4'b0101; #10;
if (result !== 32'h0800_0000) $display("FAIL: srl 80000000 >> 4 != %h", result);
else $display("PASS: srl 80000000 >> 4 = %h", result);

// sra: sign bit fills in (same inputs as srl, different answer)
        a = 32'h8000_0000; b = 32'd4; alu_op = 4'b1101; #10;
if (result !== 32'hF800_0000) $display("FAIL: sra 80000000 >>> 4 != %h", result);
else $display("PASS: sra 80000000 >>> 4 = %h", result);

// or
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; alu_op = 4'b0110; #10;
if (result !== 32'hFFFF_0F0F) $display("FAIL: or != %h", result);
else $display("PASS: or = %h", result);

// and
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; alu_op = 4'b0111; #10;
if (result !== 32'h0F0F_0000) $display("FAIL: and != %h", result);
else $display("PASS: and = %h", result);

// unused alu_op (1111): default, must be 0
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; alu_op = 4'b1111; #10;
if (result !== 32'd0) $display("FAIL: alu_op 1111 (default) != %h", result);
else $display("PASS: alu_op 1111 (default) = %h", result);

$finish;
end
endmodule