`timescale 1ns/1ps
// immediate generator
module immgen (
    input  wire [31:0] instr,    // full 32-bit instruction word
    input  wire [2:0]  imm_sel,  // format select from control unit
    output reg  [31:0] imm       // sign-extended immediate
);

    always@(*) begin
        case(imm_sel)
            3'b000: imm = {{20{instr[31]}}, instr[31:20]};  // I-type
            3'b001: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type
            3'b010: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
            3'b011: imm = {instr[31:12], 12'b0};    // U-type
            3'b100: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};   // J-type
            default: imm = 32'b0;
        endcase
    end

endmodule