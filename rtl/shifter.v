`timescale 1ns / 1ps
// shifter
module shifter(
    input  wire [31:0] a,
    input  wire [4:0]  shamt,
    input  wire [1:0]  shift_op, // 00: sll, 01: srl, 11: sra
    output reg  [31:0] result
);
    always @(*) begin
        case (shift_op)
            2'b00: result = a << shamt; // sll
            2'b01: result = a >> shamt; // srl
            2'b11: result = $signed(a) >>> shamt; // sra
            default: result = 32'b0;
        endcase
    end
endmodule