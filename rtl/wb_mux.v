`timescale 1ns / 1ps
// writeback select
module wb_mux (
    input  wire [ 1:0] sel,
    input  wire [31:0] alu_result,
    input  wire [31:0] mem_rdata,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] multdiv_result,
    output wire [31:0] wb_data
);
    assign wb_data = (sel == 2'b00) ? alu_result :
                     (sel == 2'b01) ? mem_rdata :
                     (sel == 2'b10) ? pc_plus4 : multdiv_result;
endmodule
