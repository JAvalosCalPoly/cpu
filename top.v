`default_nettype none
`timescale 1ns / 1ps
// top module
module top #(
    parameter RESET_PC  = 32'h0000_0000,
    parameter ADDR_BITS = 12,
    parameter INIT_FILE = "program.hex"
)(
    input wire clk,
    input wire rst
);

    wire [31:0] instr_addr, instr;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    wire        mem_write, mem_read;
    wire [2:0]  mem_funct3;

    core #(.RESET_PC(RESET_PC)) u_core (
    .clk        (clk),
    .rst        (rst),
    .instr      (instr),
    .instr_addr (instr_addr),
    .mem_addr   (mem_addr),
    .mem_wdata  (mem_wdata),
    .mem_rdata  (mem_rdata),
    .mem_write  (mem_write),
    .mem_read   (mem_read),
    .mem_funct3 (mem_funct3)
    );

    memory #(.ADDR_BITS(ADDR_BITS), .INIT_FILE(INIT_FILE)) u_memory (
    .clk        (clk),
    .instr_addr (instr_addr),
    .mem_addr   (mem_addr),
    .mem_wdata  (mem_wdata),
    .mem_write  (mem_write),
    .mem_read   (mem_read),
    .mem_funct3 (mem_funct3),
    .instr      (instr),
    .mem_rdata  (mem_rdata)
    );

endmodule
`default_nettype wire