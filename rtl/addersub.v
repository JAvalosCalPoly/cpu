`timescale 1ns / 1ps
// 32 bit adder/subtractor
module addersub(
    input [31:0] a,
    input [31:0] b,
    input sub,
    output [31:0] sum,
    output cout
    );
    wire [31:0] b_xor;
    assign b_xor = b^{32{sub}};
    assign {cout, sum} = a + b_xor + sub;
endmodule