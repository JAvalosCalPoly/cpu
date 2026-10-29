`default_nettype none
`timescale 1ns / 1ps
// top module
module top_pipe #(
    parameter RESET_PC  = 32'h0000_0000,
    parameter ADDR_BITS = 12,
    parameter INIT_FILE = "testbenches/test_asm_hazards.hex"
)(
input wire clk,
input wire rst
);

    wire [31:0] instr_addr, instr;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    wire        mem_write, mem_read;
    wire [2:0]  mem_funct3;
    wire is_timer = (mem_addr[31:16] == 16'h0200); // its a timer, theyre at 0x0200_xxxx

    wire [31:0] ram_rdata, timer_rdata; // mem and timer load data
    wire timer_irq;                     // timer -> core
    reg is_timer_r;                     // last access was timer
always @(posedge clk) is_timer_r <= is_timer;
assign mem_rdata = is_timer_r ? timer_rdata : ram_rdata; // pick last cycle's device

    core_pipe #(.RESET_PC(RESET_PC)) u_core (
    .clk        (clk),
    .rst        (rst),
    .instr      (instr),
    .instr_addr (instr_addr),
    .mem_addr   (mem_addr),
    .mem_wdata  (mem_wdata),
    .mem_rdata  (mem_rdata),
    .mem_write  (mem_write),
    .mem_read   (mem_read),
    .mem_funct3 (mem_funct3),
    .timer_irq  (timer_irq)
    );

    memory #(.ADDR_BITS(ADDR_BITS), .INIT_FILE(INIT_FILE)) u_memory (
    .clk        (clk),
    .instr_addr (instr_addr),
    .mem_addr   (mem_addr),
    .mem_wdata  (mem_wdata),
    .mem_write  (mem_write && !is_timer),
    .mem_read   (mem_read),
    .mem_funct3 (mem_funct3),
    .instr      (instr),
    .mem_rdata  (ram_rdata)
    );
    timer u_timer (
        .clk   (clk),
        .rst   (rst),
        .addr  (mem_addr),
        .wdata (mem_wdata),
        .we    (mem_write && is_timer),
        .rdata (timer_rdata),
        .irq   (timer_irq)
    );

endmodule
`default_nettype wire