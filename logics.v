`timescale 1ns / 1ps
// logic operations
module logics (
    input  wire [31:0] a, b,
    input  wire [1:0]  op, // 00: xor, 10: or, 11: and
    output reg  [31:0] result
);

always @(*) begin
    case (op)
        2'b00: result = a ^ b; // xor
        2'b10: result = a | b; // or
        2'b11: result = a & b; // and
        default: result = 32'b0;
    endcase
end
endmodule