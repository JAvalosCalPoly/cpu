`timescale 1ns / 1ps
// the 32 registers

module reg32 (
    input  wire        clk,
    input  wire        we,          // write enable
    input  wire        reset,       // reset
    input  wire [4:0]  rs1, rs2,    // read addresses
    input  wire [4:0]  rd,          // write address
    input  wire [31:0] wd,          // write data
    output wire [31:0] rd1, rd2     // read data
);
 
wire [31:0] q [31:0];       // output of each register
assign q[0] = 32'b0;        // x0 always reads as zero
 
// x1..x31: one regfile each, enabled only when it is the write target
genvar i;
generate
    for (i = 1; i < 32; i = i + 1) begin : gen_regs
        regfile r (
            .clk   (clk),
            .reset (reset),
            .en    (we && (rd == i)),
            .d     (wd),
            .q     (q[i])
        );
    end
endgenerate
 
// read ports: 32-to-1 muxes
assign rd1 = q[rs1];
assign rd2 = q[rs2];

endmodule