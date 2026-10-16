module multiplier (
    input wire clk,
    input wire [31:0] a, b,
    input wire [1:0] op,
    output reg [31:0] result
);
reg [32:0] a33_r, b33_r;
reg [1:0]  op_r;

wire a_signed = ~(op[1] & op[0]); // mul, mulh, mulhsu
wire b_signed = ~op[1]; // mul, mulh

wire [32:0] a33 = {a_signed & a[31], a}; // sign or 0 on top
wire [32:0] b33 = {b_signed & b[31], b};

always @(posedge clk) begin
    a33_r <= a33;
    b33_r <= b33;
    op_r <= op;
end

wire [65:0] prod = $signed(a33_r) * $signed(b33_r); // one signed 33x33

always @(*) begin
case (op_r)
    2'b00:   result = prod[31:0]; // mul
    default: result = prod[63:32]; // mulh, mulhsu, mulhu
endcase
end

endmodule