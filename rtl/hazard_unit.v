`timescale 1ns / 1ps
// load/mul/csr-use stall
module hazard_unit (
    input  wire       id_ex_mem_read,
    input  wire       id_ex_is_csr,
    input  wire [1:0] id_ex_wb_sel,
    input  wire [2:0] id_ex_funct3,
    input  wire [4:0] id_ex_rd,
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    output wire       stall
);
    wire ex_is_mul = (id_ex_wb_sel == 2'b11) && !id_ex_funct3[2];  // mul in EX
    assign stall = (id_ex_mem_read || ex_is_mul || id_ex_is_csr) && (id_ex_rd != 0) &&
                   ((id_ex_rd == id_rs1) || (id_ex_rd == id_rs2));
endmodule
