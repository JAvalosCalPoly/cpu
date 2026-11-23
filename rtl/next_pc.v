`timescale 1ns / 1ps
// branch/jump redirect and fetch address
module next_pc #(
    parameter RESET_PC = 32'h00000000
) (
    input  wire        rst,
    input  wire        mem_trap,
    input  wire        hold,           // stall or ex_busy
    input  wire        branch,
    input  wire        branch_taken,
    input  wire        jal,
    input  wire        jalr,
    input  wire [31:0] pc,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] branch_target,
    input  wire [31:0] jalr_target,
    input  wire [31:0] trap_target,
    output wire        redirect,
    output wire [31:0] pc_next,
    output wire [31:0] fetch_addr
);
    assign redirect = (branch && branch_taken) || jal || jalr;
    assign pc_next = jalr ? jalr_target : redirect ? branch_target : pc_plus4;
    assign fetch_addr = rst ? RESET_PC : mem_trap ? trap_target :
                        redirect ? pc_next : hold ? pc : pc_next;
endmodule
