`timescale 1ns / 1ps
// EX operand forwarding
module forward_unit (
    input  wire [ 4:0] id_ex_rs1,
    input  wire [ 4:0] id_ex_rs2,
    input  wire [31:0] id_ex_rs1_data,
    input  wire [31:0] id_ex_rs2_data,
    // EX/MEM
    input  wire        ex_mem_reg_write,
    input  wire [ 4:0] ex_mem_rd,
    input  wire [ 1:0] ex_mem_wb_sel,
    input  wire [31:0] ex_mem_alu_result,
    input  wire [31:0] ex_mem_multdiv_result,
    input  wire [31:0] ex_mem_pc_plus4,
    // MEM/WB
    input  wire        mem_wb_reg_write,
    input  wire [ 4:0] mem_wb_rd,
    input  wire [31:0] wb_data,
    output wire [31:0] ex_rs1,
    output wire [31:0] ex_rs2
);
    wire fwd_a_exmem = ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1);
    wire fwd_b_exmem = ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2);
    wire fwd_a_memwb = mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1);
    wire fwd_b_memwb = mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2);

    wire [31:0] ex_mem_result = (ex_mem_wb_sel == 2'b10) ? ex_mem_pc_plus4 :
                                (ex_mem_wb_sel == 2'b11) ? ex_mem_multdiv_result : ex_mem_alu_result;

    assign ex_rs1 = fwd_a_exmem ? ex_mem_result : fwd_a_memwb ? wb_data : id_ex_rs1_data;
    assign ex_rs2 = fwd_b_exmem ? ex_mem_result : fwd_b_memwb ? wb_data : id_ex_rs2_data;
endmodule
