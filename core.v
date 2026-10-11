`default_nettype none
`timescale 1ns / 1ps
// cpu core
/*
PC goes out as instr_addr and comes back as instr
decoder reads instr and outputs control signals
regfile reads rs1 and rs2 and outputs their data
immgen generates immediate
2 muxes select inputs to ALU, ALU does its thing
branch unit compares rs1 and rs2
for the load and stores, alu result goes to mem_addr
a mux picks what goes into rd: ALU, mem_rdata, or PC+4
the next-pc logic picks the next PC value
@POSEDGE the reg writes, memory writes, and pc update happen
*/
module core#(parameter RESET_PC = 32'h00000000)(
    input wire clk, rst,
    // instruction memory
    input  wire [31:0] instr,
    output wire [31:0] instr_addr,
    // data memory
    input  wire [31:0] mem_rdata,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        mem_write,
    output wire        mem_read,
    output wire [2:0]  mem_funct3
);
    // decoder outputs
    wire        reg_write;
    wire [2:0]  imm_sel;
    wire [1:0]  alu_a_sel;
    wire        alu_b_sel;
    wire [3:0]  alu_op;
    wire [1:0]  wb_sel;
    wire        branch;
    wire        jal;
    wire        jalr;

    // datapath values
    wire [31:0] rs1_data, rs2_data; // register file outputs
    wire [31:0] imm;    // from immgen
    wire [31:0] alu_a, alu_b;   // ALU inputs (from muxes)
    wire [31:0] alu_result; // from ALU
    wire [31:0] wb_data;    // writeback mux for register file
    wire [31:0] muldiv_result;  // from multdiv

    // branch unit output
    wire branch_cond; // branch condition is true

    // PC
    reg  [31:0] pc; 
    wire [31:0] pc_next; // next-PC mux output
    wire [31:0] pc_plus4; // pc + 4
    wire [31:0] branch_target;  // pc + imm (branches, jal)
    wire [31:0] jalr_target;    // (rs1 + imm) with bit 0 cleared

    // instruction field
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [4:0] rd  = instr[11:7];
    wire [2:0] funct3 = instr[14:12];

    // PC register
    always @(posedge clk) begin
        if (rst) begin
            pc <= RESET_PC;
        end else begin
            pc <= pc_next;
        end
    end

    // instruction address
    assign instr_addr = pc;

    assign alu_a = (alu_a_sel == 2'b01) ? pc : (alu_a_sel == 2'b10) ? 32'b0 : rs1_data;
    assign alu_b = (alu_b_sel == 1'b1) ? imm : rs2_data;
    assign wb_data = (wb_sel == 2'b00) ? alu_result : (wb_sel == 2'b01) ? mem_rdata : (wb_sel == 2'b10) ? pc_plus4 : muldiv_result;
    // pc targets
    assign pc_plus4 = pc + 32'd4;
    assign branch_target = pc + imm;
    assign jalr_target = {alu_result[31:1], 1'b0}; // rs1 + imm, bit 0 cleared
    // next PC mux
    assign pc_next = (jalr) ? jalr_target : (jal) ? branch_target : (branch && branch_cond) ? branch_target : pc_plus4;
    // data memory outputs
    assign mem_addr = alu_result;
    assign mem_wdata = rs2_data;
    assign mem_funct3 = funct3;

    reg32 u_reg32 (
        .clk(clk),
        .we(reg_write),
        .reset(rst),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wd(wb_data),
        .rd1(rs1_data),
        .rd2(rs2_data)
    );

    immgen u_immgen (
        .instr(instr),
        .imm_sel(imm_sel),
        .imm(imm)
    );

    decoder u_decoder (
        .instr(instr),
        .reg_write(reg_write),
        .imm_sel(imm_sel),
        .alu_a_sel(alu_a_sel),
        .alu_b_sel(alu_b_sel),
        .alu_op(alu_op),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .wb_sel(wb_sel),
        .branch(branch),
        .jal(jal),
        .jalr(jalr)
    );

    alu u_alu (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result)
    );

    branch_unit u_branch_unit (
        .a(rs1_data),
        .b(rs2_data),
        .funct3(funct3),
        .branch_taken(branch_cond)
    );

    multdiv u_multdiv (
        .a(rs1_data),
        .b(rs2_data),
        .funct3(funct3),
        .result(muldiv_result)
    );

endmodule
`default_nettype wire