`timescale 1ns / 1ps
// compare
module compare (
    input wire [31:0] a, b,
    output wire lt, ltu
);

assign lt = $signed(a) < $signed(b);
assign ltu = (a < b);
endmodule