`timescale 1ns / 1ps
module branch_unit_tb;

    reg  [31:0] a;
    reg  [31:0] b;
    reg  [2:0]  funct3;
    wire        branch_taken;

    branch_unit dut (
        .a(a),
        .b(b),
        .funct3(funct3),
        .branch_taken(branch_taken)
    );

// funct3: 000 beq  001 bne  100 blt  101 bge  110 bltu  111 bgeu
// Every branch is tested once where it is taken and once where it is not.

initial begin
$dumpfile("branch_unit.vcd");
$dumpvars(0, branch_unit_tb);

// beq
        a = 32'd7; b = 32'd7; funct3 = 3'b000; #10;
if (branch_taken !== 1'b1) $display("FAIL: beq 7, 7 taken = %b", branch_taken);
else $display("PASS: beq 7, 7 taken = %b", branch_taken);

        a = 32'd7; b = 32'd8; funct3 = 3'b000; #10;
if (branch_taken !== 1'b0) $display("FAIL: beq 7, 8 taken = %b", branch_taken);
else $display("PASS: beq 7, 8 taken = %b", branch_taken);

// bne
        a = 32'd7; b = 32'd8; funct3 = 3'b001; #10;
if (branch_taken !== 1'b1) $display("FAIL: bne 7, 8 taken = %b", branch_taken);
else $display("PASS: bne 7, 8 taken = %b", branch_taken);

        a = 32'd7; b = 32'd7; funct3 = 3'b001; #10;
if (branch_taken !== 1'b0) $display("FAIL: bne 7, 7 taken = %b", branch_taken);
else $display("PASS: bne 7, 7 taken = %b", branch_taken);

// blt (signed)
// -1 < 1 signed
        a = 32'hFFFF_FFFF; b = 32'd1; funct3 = 3'b100; #10;
if (branch_taken !== 1'b1) $display("FAIL: blt -1, 1 taken = %b", branch_taken);
else $display("PASS: blt -1, 1 taken = %b", branch_taken);

        a = 32'd1; b = 32'hFFFF_FFFF; funct3 = 3'b100; #10;
if (branch_taken !== 1'b0) $display("FAIL: blt 1, -1 taken = %b", branch_taken);
else $display("PASS: blt 1, -1 taken = %b", branch_taken);

// bge (signed)
// equal counts as "greater or equal"
        a = 32'd5; b = 32'd5; funct3 = 3'b101; #10;
if (branch_taken !== 1'b1) $display("FAIL: bge 5, 5 taken = %b", branch_taken);
else $display("PASS: bge 5, 5 taken = %b", branch_taken);

        a = 32'hFFFF_FFFF; b = 32'd1; funct3 = 3'b101; #10;
if (branch_taken !== 1'b0) $display("FAIL: bge -1, 1 taken = %b", branch_taken);
else $display("PASS: bge -1, 1 taken = %b", branch_taken);

// bltu (unsigned)
// same inputs as the blt test, opposite answer: FFFFFFFF is huge unsigned
        a = 32'd1; b = 32'hFFFF_FFFF; funct3 = 3'b110; #10;
if (branch_taken !== 1'b1) $display("FAIL: bltu 1, FFFFFFFF taken = %b", branch_taken);
else $display("PASS: bltu 1, FFFFFFFF taken = %b", branch_taken);

        a = 32'hFFFF_FFFF; b = 32'd1; funct3 = 3'b110; #10;
if (branch_taken !== 1'b0) $display("FAIL: bltu FFFFFFFF, 1 taken = %b", branch_taken);
else $display("PASS: bltu FFFFFFFF, 1 taken = %b", branch_taken);

// bgeu (unsigned)
        a = 32'hFFFF_FFFF; b = 32'd1; funct3 = 3'b111; #10;
if (branch_taken !== 1'b1) $display("FAIL: bgeu FFFFFFFF, 1 taken = %b", branch_taken);
else $display("PASS: bgeu FFFFFFFF, 1 taken = %b", branch_taken);

        a = 32'd1; b = 32'hFFFF_FFFF; funct3 = 3'b111; #10;
if (branch_taken !== 1'b0) $display("FAIL: bgeu 1, FFFFFFFF taken = %b", branch_taken);
else $display("PASS: bgeu 1, FFFFFFFF taken = %b", branch_taken);

// 010 and 011 are not branches: never taken
        a = 32'd7; b = 32'd7; funct3 = 3'b010; #10;
if (branch_taken !== 1'b0) $display("FAIL: funct3 010 (default) taken = %b", branch_taken);
else $display("PASS: funct3 010 (default) taken = %b", branch_taken);

        a = 32'd7; b = 32'd7; funct3 = 3'b011; #10;
if (branch_taken !== 1'b0) $display("FAIL: funct3 011 (default) taken = %b", branch_taken);
else $display("PASS: funct3 011 (default) taken = %b", branch_taken);

$finish;
end
endmodule