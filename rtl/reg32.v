`timescale 1ns / 1ps
// the 32 registers, as one array so Vivado maps them to LUT RAM
// WRITE_THROUGH = 1: a write shows on the read port the same cycle (pipeline)
// set to 0 for the single-cycle CPU
module reg32 #(parameter WRITE_THROUGH = 1)(
    input  wire        clk,
    input  wire        we,          // write enable
    input  wire        reset,       // unused, ram can't reset
    input  wire [4:0]  rs1, rs2,    // read addresses
    input  wire [4:0]  rd,          // write address
    input  wire [31:0] wd,          // write data
    output wire [31:0] rd1, rd2     // read data
);

reg [31:0] regs [1:31];     // x1..x31, x0 isn't stored

// write, x0 ignored
always @(posedge clk)
    if (we && rd != 0) regs[rd] <= wd;

integer k;
initial for (k = 1; k < 32; k = k + 1) regs[k] = 0;  // power-up zeros

// read ports: async ram reads, x0 = 0, same-cycle write forwarded
assign rd1 = (rs1 == 0) ? 32'b0 :                                    // x0
             (WRITE_THROUGH && we && rd == rs1) ? wd : regs[rs1];    // forward or read
assign rd2 = (rs2 == 0) ? 32'b0 :                                    // x0
             (WRITE_THROUGH && we && rd == rs2) ? wd : regs[rs2];    // forward or read

endmodule