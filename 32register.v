`timescale 1ns / 1ps
// the 32 registers
// parameter WRITE_THROUGH to test with single cycle CPU, otherwise use with pipelined CPU
// WRITE_THROUGH = 1: a write shows on the read port the same cycle (pipeline)
// set to 0 for the single-cycle CP
module reg32 #(parameter WRITE_THROUGH = 1)(
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
// modified for forwarding
// rd will check we && rd != 0 and rd == rs1 or rs2, and if so, will forward wd to rd1 or rd2
assign rd1 = (WRITE_THROUGH && we && rd != 0 && rd == rs1) ? wd : q[rs1];
assign rd2 = (WRITE_THROUGH && we && rd != 0 && rd == rs2) ? wd : q[rs2];

endmodule