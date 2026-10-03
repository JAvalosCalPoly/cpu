`timescale 1ns / 1ps

module registers_tb(

    );
reg clk = 0;
reg we = 0, reset = 0;
reg[4:0] rs1 = 0, rs2 = 0, rd = 0;
reg[31:0] wd = 0;
reg[31:0] rd1, rd2;

reg32 dut(
    .clk(clk),
    .we(we),
    .reset(reset),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .wd(wd),
    .rd1(rd1),
    .rd2(rd2)
);

endmodule