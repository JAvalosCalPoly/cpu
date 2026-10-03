`timescale 1ns / 1ps
// register file

module regfile (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,      // load enable
    input  wire [31:0] d,       // data in
    output reg  [31:0] q        // data out
);
 
always @(posedge clk) begin
    if (reset)
        q <= 32'b0;
    else if (en)
        q <= d;
end


endmodule