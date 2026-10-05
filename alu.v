`timescale 1ns / 1ps
// alu

module alu (
    input  wire [31:0] a, b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] result
);

wire [31:0] sum;    // from addersub
wire [31:0] shift_result;   // from shifter
wire        cout;
wire lt, ltu;
wire [31:0] logic_result;

logics u_logics (
    .a      (a),
    .b      (b),
    .op     (alu_op[1:0]),
    .result (logic_result)
);

compare u_compare (
    .a   (a),
    .b   (b),
    .lt  (lt),
    .ltu (ltu)
);

shifter u_shifter (
    .a        (a),
    .shamt    (b[4:0]),
    .shift_op (alu_op[3:2]),
    .result   (shift_result)
);

addersub adder_sub (
    .a    (a),
    .b    (b),
    .sub  (alu_op[3]),
    .sum  (sum),
    .cout (cout)
);

always @(*) begin
    case (alu_op)
        4'b0000: result = sum;  // add
        4'b1000: result = sum;  // sub
        4'b0001: result = shift_result; // sll
        4'b0010: result = {31'b0, lt};    // slt
        4'b0011: result = {31'b0, ltu};   // sltu
        4'b0100: result = logic_result;   // xor
        4'b0101: result = shift_result; // srl
        4'b1101: result = shift_result; // sra
        4'b0110: result = logic_result;    // or
        4'b0111: result = logic_result;    // and
        default: result = 32'b0;
    endcase
end

endmodule