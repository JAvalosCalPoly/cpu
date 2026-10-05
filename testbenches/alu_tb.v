`timescale 1ns / 1ps
// alu testbench
module alu_tb;

localparam ADD  = 4'b0000, SUB = 4'b1000, SLL = 4'b0001, SLT = 4'b0010,
           SLTU = 4'b0011, XOR = 4'b0100, SRL = 4'b0101, SRA = 4'b1101,
           OR   = 4'b0110, AND = 4'b0111;

reg [31:0] a = 0, b = 0;
reg [3:0] alu_op = 0;
wire [31:0] result;

integer errors = 0;

alu dut (
    .a(a),
    .b(b),
    .alu_op(alu_op),
    .result(result)
);

// task to set operation and check result
task check(
    input [3:0]    op,
    input [31:0]   x,
    input [31:0]   y,
    input [31:0]   expected,
    input [8*32:1] op_name
);
begin
    alu_op = op; a = x; b = y;
    #1; // wait for result to settle
    if (result !== expected) begin
        $display("FAIL: %0s: got %h, expected %h", op_name, result, expected);
        errors = errors + 1;
    end else begin
        $display("PASS: %0s a=%h, b=%h, result=%h", op_name, x, y, result);
    end
end
endtask

initial begin
    $display("Starting ALU testbench...");
    $dumpfile("alu.vcd");
    $dumpvars(0, alu_tb);
//        op  |      a       |     b      |   expected   |      name
    check(ADD,  32'h00000001, 32'h00000001, 32'h00000002, "add 1 + 1");
    check(ADD,  32'hFFFFFFFF, 32'h00000001, 32'h00000000, "add overflow wraps");
    check(ADD,  32'h7FFFFFFF, 32'h00000001, 32'h80000000, "add into sign bit");
 
    check(SUB,  32'h00000005, 32'h00000003, 32'h00000002, "sub 5 - 3");
    check(SUB,  32'h00000000, 32'h00000001, 32'hFFFFFFFF, "sub goes negative");
    check(SUB,  32'h80000000, 32'h00000001, 32'h7FFFFFFF, "sub most negative - 1");
 
    check(SLL,  32'h00000001, 32'h00000004, 32'h00000010, "sll by 4");
    check(SLL,  32'h00000001, 32'h0000001F, 32'h80000000, "sll by 31");
    check(SLL,  32'h00000001, 32'h00000021, 32'h00000002, "sll uses b[4:0] only");
    check(SLL,  32'h12345678, 32'h00000000, 32'h12345678, "sll by 0");
 
    check(SRL,  32'h80000000, 32'h00000004, 32'h08000000, "srl fills with 0s");
    check(SRL,  32'hFFFFFFFF, 32'h0000001F, 32'h00000001, "srl by 31");
 
    check(SRA,  32'h80000000, 32'h00000004, 32'hF8000000, "sra fills with sign");
    check(SRA,  32'hFFFFFFFF, 32'h0000001F, 32'hFFFFFFFF, "sra negative by 31");
    check(SRA,  32'h7FFFFFFF, 32'h0000001F, 32'h00000000, "sra positive by 31");
 
    check(SLT,  32'hFFFFFFFF, 32'h00000001, 32'h00000001, "slt -1 < 1");
    check(SLT,  32'h00000001, 32'hFFFFFFFF, 32'h00000000, "slt 1 < -1 is false");
    check(SLT,  32'h80000000, 32'h7FFFFFFF, 32'h00000001, "slt min < max");
    check(SLT,  32'h00000005, 32'h00000005, 32'h00000000, "slt equal");
 
    check(SLTU, 32'hFFFFFFFF, 32'h00000001, 32'h00000000, "sltu max < 1 is false");
    check(SLTU, 32'h00000001, 32'hFFFFFFFF, 32'h00000001, "sltu 1 < max");
    check(SLTU, 32'h00000005, 32'h00000005, 32'h00000000, "sltu equal");
 
    check(XOR,  32'hF0F0F0F0, 32'hFF00FF00, 32'h0FF00FF0, "xor mixed bits");
    check(XOR,  32'h12345678, 32'h12345678, 32'h00000000, "xor with itself");
 
    check(OR,   32'hF0F0F0F0, 32'h0F0F0F0F, 32'hFFFFFFFF, "or no overlap");
 
    check(AND,  32'hF0F0F0F0, 32'hFF00FF00, 32'hF000F000, "and mixed bits");
 
    check(4'b1001, 32'h12345678, 32'h12345678, 32'h00000000, "invalid op gives 0");
 
    if (errors == 0) $display("\nALL TESTS PASSED");
    else             $display("\n%0d TEST(S) FAILED", errors);
    $finish;
end

endmodule