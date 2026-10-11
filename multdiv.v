`default_nettype none
`timescale 1ns / 1ps
// M-extension multiplier/divider unit
module multdiv (
    input  wire [31:0] a, b,     // rs1, rs2
    input  wire [2:0]  funct3,   // which operation
    output reg  [31:0] result
);

// ---------------- multiply ----------------
// extend each input to 64 bits ourselves, then do plain unsigned 64-bit multiplies
wire [63:0] a_s = {{32{a[31]}}, a};   // a sign-extended
wire [63:0] a_u = {32'b0, a};          // a zero-extended
wire [63:0] b_s = {{32{b[31]}}, b};   // b sign-extended
wire [63:0] b_u = {32'b0, b};          // b zero-extended

wire [63:0] prod_ss = a_s * b_s;       // signed   x signed    (mulh)
wire [63:0] prod_su = a_s * b_u;       // signed   x unsigned  (mulhsu)
wire [63:0] prod_uu = a_u * b_u;       // unsigned x unsigned  (mulhu)

// ---------------- divide edge cases ----------------
wire div_by_zero = (b == 32'b0);
wire overflow    = (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);   // -2^31 / -1

always @(*) begin
    case (funct3)
        3'b000: result = prod_uu[31:0];        // mul (low half is the same for every product)
        3'b001: result = prod_ss[63:32];       // mulh
        3'b010: result = prod_su[63:32];       // mulhsu
        3'b011: result = prod_uu[63:32];       // mulhu

        3'b100: begin                          // div (signed)
            if (div_by_zero)   result = 32'hFFFF_FFFF;
            else if (overflow) result = 32'h8000_0000;
            else               result = $signed(a) / $signed(b);
        end
        3'b101: begin                          // divu (unsigned)
            if (div_by_zero)   result = 32'hFFFF_FFFF;
            else               result = a / b;
        end
        3'b110: begin                          // rem (signed)
            if (div_by_zero)   result = a;
            else if (overflow) result = 32'b0;
            else               result = $signed(a) % $signed(b);
        end
        3'b111: begin                          // remu (unsigned)
            if (div_by_zero)   result = a;
            else               result = a % b;
        end
        default: result = 32'b0;
    endcase
end

endmodule
`default_nettype wire