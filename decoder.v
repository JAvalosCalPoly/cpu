`timescale 1ns / 1ps
// decoder/control unit
module decoder (
    input  wire [31:0] instr,
    output reg         reg_write, // write rd
    output reg  [2:0]  imm_sel, // 000 I, 001 S, 010 B, 011 U, 100 J
    output reg  [1:0]  alu_a_sel, // 00 rs1, 01 PC, 10 zero
    output reg         alu_b_sel, // 0 rs2, 1 imm
    output reg  [3:0]  alu_op, // {bit 30, funct3} encoding
    output reg         mem_read, // load
    output reg         mem_write, // store
    output reg  [1:0]  wb_sel, // 00 ALU, 01 memory, 10 PC+4, 11 multiplier/divider
    output reg         branch, // branch
    output reg         jal, // jump to PC + imm
    output reg         jalr // jump to rs1 + imm
);

// opcodes (instr[6:0])
localparam OP = 7'b0110011;
localparam OP_IMM = 7'b0010011;
localparam LOAD = 7'b0000011;
localparam STORE = 7'b0100011;
localparam BRANCH = 7'b1100011;
localparam LUI = 7'b0110111;
localparam AUIPC = 7'b0010111;
localparam JAL = 7'b1101111;
localparam JALR = 7'b1100111;
localparam MISC_MEM = 7'b0001111;
localparam SYSTEM = 7'b1110011;

// imm_sel
localparam IMM_I = 3'b000, IMM_S = 3'b001, IMM_B = 3'b010, IMM_U = 3'b011, IMM_J = 3'b100;

// alu_a_sel
localparam A_RS1 = 2'b00, A_PC = 2'b01, A_ZERO = 2'b10;

// alu_b_sel
localparam B_RS2 = 1'b0, B_IMM = 1'b1;

// wb_sel
localparam WB_ALU = 2'b00, WB_MEM = 2'b01, WB_PC4 = 2'b10, WB_MUL = 2'b11;

// alu_op
localparam ALU_ADD = 4'b0000;

// extraction from instruction
wire [6:0] opcode = instr[6:0];
wire [2:0] funct3 = instr[14:12];
wire       funct7_5 = instr[30];

always@(*) begin
    reg_write = 1'b0;
    imm_sel = 3'b000;
    alu_a_sel = 2'b00;
    alu_b_sel = 1'b0;
    alu_op = 4'b0000;
    mem_read = 1'b0;
    mem_write = 1'b0;
    wb_sel = 2'b00;
    branch = 1'b0;
    jal = 1'b0;
    jalr = 1'b0;
    case(opcode)
        // R-type
        OP: begin
            reg_write = 1'b1;
            alu_a_sel = A_RS1;
            alu_b_sel = B_RS2;
            if (instr[25]) wb_sel = WB_MUL;
            else alu_op = {funct7_5, funct3};
        end
        // I-type
        OP_IMM: begin
            reg_write = 1'b1;
            imm_sel = IMM_I;
            alu_a_sel = A_RS1;
            alu_b_sel = B_IMM;
            alu_op = (funct3 == 3'b101) ? {funct7_5, funct3} : {1'b0, funct3};
        end
        // load
        LOAD: begin
            reg_write = 1'b1;
            imm_sel = IMM_I;
            alu_a_sel = A_RS1;
            alu_b_sel = B_IMM;
            alu_op = ALU_ADD;
            mem_read = 1'b1;
            wb_sel = WB_MEM;
        end
        // store
        STORE: begin
            imm_sel = IMM_S;
            alu_a_sel = A_RS1;
            alu_b_sel = B_IMM;
            alu_op = ALU_ADD;
            mem_write = 1'b1;
        end
        // branch
        BRANCH: begin
            imm_sel = IMM_B;
            branch = 1'b1;
        end
        // lui
        LUI: begin
            reg_write = 1'b1;
            imm_sel = IMM_U;
            alu_a_sel = A_ZERO;
            alu_b_sel = B_IMM;
            alu_op = ALU_ADD;
        end
        // auipc
        AUIPC: begin
            reg_write = 1'b1;
            imm_sel = IMM_U;
            alu_a_sel = A_PC;
            alu_b_sel = B_IMM;
            alu_op = ALU_ADD;
        end
        // jal
        JAL: begin
            reg_write = 1'b1;
            imm_sel = IMM_J;
            wb_sel = WB_PC4;
            jal = 1'b1;
        end
        // jalr
        JALR: begin
            reg_write = 1'b1;
            imm_sel = IMM_I;
            alu_a_sel = A_RS1;
            alu_b_sel = B_IMM;
            alu_op = ALU_ADD;
            wb_sel = WB_PC4;
            jalr = 1'b1;
        end
        // MISC-MEM (fence) and SYSTEM (ecall, ebreak):
        //   do nothing for now; defaults already cover this
        MISC_MEM: begin
        end
        SYSTEM: begin
        end
        // default: unknown opcode, defaults apply (no effect)
        default: begin
        end
    endcase
end
endmodule