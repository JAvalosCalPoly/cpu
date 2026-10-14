`timescale 1ns / 1ps
module immgen_tb;

    reg  [31:0] instr;
    reg  [2:0]  imm_sel;
    wire [31:0] imm;

    immgen dut (
        .instr(instr),
        .imm_sel(imm_sel),
        .imm(imm)
    );

// imm_sel: 000 I, 001 S, 010 B, 011 U, 100 J
// Each format is tested with a real encoded instruction: one positive
// immediate, and one negative immediate to check the sign extension.

initial begin
$dumpfile("immgen.vcd");
$dumpvars(0, immgen_tb);

// I-type
// addi x1, x0, 5
        instr = 32'h0050_0093; imm_sel = 3'b000; #10;
if (imm !== 32'd5) $display("FAIL: I  addi x1, x0, 5 -> imm != %h", imm);
else $display("PASS: I  addi x1, x0, 5 -> imm = %h", imm);

// addi x1, x0, -1  (imm field = FFF, sign-extends to all ones)
        instr = 32'hFFF0_0093; imm_sel = 3'b000; #10;
if (imm !== 32'hFFFF_FFFF) $display("FAIL: I  addi x1, x0, -1 -> imm != %h", imm);
else $display("PASS: I  addi x1, x0, -1 -> imm = %h", imm);

// addi x1, x0, 2047  (biggest positive I immediate, 7FF)
        instr = 32'h7FF0_0093; imm_sel = 3'b000; #10;
if (imm !== 32'h0000_07FF) $display("FAIL: I  addi x1, x0, 2047 -> imm != %h", imm);
else $display("PASS: I  addi x1, x0, 2047 -> imm = %h", imm);

// S-type (imm split into instr[31:25] and instr[11:7])
// sw x2, 8(x1)
        instr = 32'h0020_A423; imm_sel = 3'b001; #10;
if (imm !== 32'd8) $display("FAIL: S  sw x2, 8(x1) -> imm != %h", imm);
else $display("PASS: S  sw x2, 8(x1) -> imm = %h", imm);

// sw x2, -4(x1)
        instr = 32'hFE20_AE23; imm_sel = 3'b001; #10;
if (imm !== 32'hFFFF_FFFC) $display("FAIL: S  sw x2, -4(x1) -> imm != %h", imm);
else $display("PASS: S  sw x2, -4(x1) -> imm = %h", imm);

// sw x0, 0x123(x0)  (different bits in each half, so swapped halves would show)
        instr = 32'h1200_21A3; imm_sel = 3'b001; #10;
if (imm !== 32'h0000_0123) $display("FAIL: S  sw x0, 0x123(x0) -> imm != %h", imm);
else $display("PASS: S  sw x0, 0x123(x0) -> imm = %h", imm);

// B-type (scrambled bits, bit 0 always 0)
// beq x3, x3, +8  (from program.hex)
        instr = 32'h0031_8463; imm_sel = 3'b010; #10;
if (imm !== 32'd8) $display("FAIL: B  beq x3, x3, +8 -> imm != %h", imm);
else $display("PASS: B  beq x3, x3, +8 -> imm = %h", imm);

// beq x0, x0, -4  (branch back one instruction)
        instr = 32'hFE00_0EE3; imm_sel = 3'b010; #10;
if (imm !== 32'hFFFF_FFFC) $display("FAIL: B  beq x0, x0, -4 -> imm != %h", imm);
else $display("PASS: B  beq x0, x0, -4 -> imm = %h", imm);

// The two tests above can't tell imm[11] apart from its neighbours (they're all 0
// or all 1). These light up ONE immediate bit, so a bit in the wrong place shows.

// beq x0, x0, +2048  (only imm[11] set, it lives in instr[7])
        instr = 32'h0000_00E3; imm_sel = 3'b010; #10;
if (imm !== 32'h0000_0800) $display("FAIL: B  beq x0, x0, +2048 -> imm != %h", imm);
else $display("PASS: B  beq x0, x0, +2048 -> imm = %h", imm);

// beq x0, x0, -4096  (only imm[12], the sign bit, set: it lives in instr[31])
        instr = 32'h8000_0063; imm_sel = 3'b010; #10;
if (imm !== 32'hFFFF_F000) $display("FAIL: B  beq x0, x0, -4096 -> imm != %h", imm);
else $display("PASS: B  beq x0, x0, -4096 -> imm = %h", imm);

// U-type (top 20 bits, low 12 are zero, no sign extension needed)
// lui x1, 0x12345
        instr = 32'h1234_50B7; imm_sel = 3'b011; #10;
if (imm !== 32'h1234_5000) $display("FAIL: U  lui x1, 0x12345 -> imm != %h", imm);
else $display("PASS: U  lui x1, 0x12345 -> imm = %h", imm);

// lui x1, 0xFFFFF
        instr = 32'hFFFF_F0B7; imm_sel = 3'b011; #10;
if (imm !== 32'hFFFF_F000) $display("FAIL: U  lui x1, 0xFFFFF -> imm != %h", imm);
else $display("PASS: U  lui x1, 0xFFFFF -> imm = %h", imm);

// J-type (scrambled bits, bit 0 always 0)
// jal x4, +4  (from program.hex)
        instr = 32'h0040_026F; imm_sel = 3'b100; #10;
if (imm !== 32'd4) $display("FAIL: J  jal x4, +4 -> imm != %h", imm);
else $display("PASS: J  jal x4, +4 -> imm = %h", imm);

// jal x0, -8  (j -8)
        instr = 32'hFF9F_F06F; imm_sel = 3'b100; #10;
if (imm !== 32'hFFFF_FFF8) $display("FAIL: J  jal x0, -8 -> imm != %h", imm);
else $display("PASS: J  jal x0, -8 -> imm = %h", imm);

// jal x0, 0  (j . , the infinite loop at the end of program.hex)
        instr = 32'h0000_006F; imm_sel = 3'b100; #10;
if (imm !== 32'd0) $display("FAIL: J  jal x0, 0 -> imm != %h", imm);
else $display("PASS: J  jal x0, 0 -> imm = %h", imm);

// jal x0, +2048  (only imm[11] set, it lives in instr[20])
        instr = 32'h0010_006F; imm_sel = 3'b100; #10;
if (imm !== 32'h0000_0800) $display("FAIL: J  jal x0, +2048 -> imm != %h", imm);
else $display("PASS: J  jal x0, +2048 -> imm = %h", imm);

// jal x0, +4096  (only imm[12] set, it lives in instr[12])
        instr = 32'h0000_106F; imm_sel = 3'b100; #10;
if (imm !== 32'h0000_1000) $display("FAIL: J  jal x0, +4096 -> imm != %h", imm);
else $display("PASS: J  jal x0, +4096 -> imm = %h", imm);

// unused imm_sel (101): default, must be 0
        instr = 32'hFFFF_FFFF; imm_sel = 3'b101; #10;
if (imm !== 32'd0) $display("FAIL: imm_sel 101 (default) -> imm != %h", imm);
else $display("PASS: imm_sel 101 (default) -> imm = %h", imm);

$finish;
end
endmodule