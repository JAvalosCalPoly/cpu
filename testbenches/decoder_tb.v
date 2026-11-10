`timescale 1ns / 1ps
module decoder_tb;

    reg  [31:0] instr;
    wire        reg_write;
    wire [ 2:0] imm_sel;
    wire [ 1:0] alu_a_sel;
    wire        alu_b_sel;
    wire [ 3:0] alu_op;
    wire        mem_read;
    wire        mem_write;
    wire [ 1:0] wb_sel;
    wire        branch;
    wire        jal;
    wire        jalr;
    wire        is_sfence;
    wire        illegal;

    decoder dut (
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
        .jalr(jalr),
        .is_sfence(is_sfence),
        .illegal(illegal)
    );

    // All 18 control bits glued together so each instruction is checked in one line.
    // written with _ between fields in this same order so I can see them all in the output:
    //
    //   reg_write _ imm_sel _ alu_a_sel _ alu_b_sel _ alu_op _ mem_read _ mem_write _ wb_sel _ branch _ jal _ jalr
    //       1         3          2           1          4         1          1          2        1       1     1
    //
    // imm_sel:   000 I   001 S   010 B   011 U   100 J
    // alu_a_sel: 00 rs1  01 PC   10 zero
    // alu_b_sel: 0 rs2   1 imm
    // wb_sel:    00 ALU  01 mem  10 PC+4  11 mul/div
    //
    wire [17:0] ctrl = {
        reg_write,
        imm_sel,
        alu_a_sel,
        alu_b_sel,
        alu_op,
        mem_read,
        mem_write,
        wb_sel,
        branch,
        jal,
        jalr
    };

    integer pass = 0, fail = 0;

    initial begin
        $dumpfile("decoder.vcd");
        $dumpvars(0, decoder_tb);

        // R-type: rs1 op rs2, alu_op = {instr[30], funct3}

        // add x3, x1, x2
        instr = 32'h0020_81B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0000_0_0_00_0_0_0) begin $display("FAIL: add  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: add  ctrl = %b", ctrl); pass = pass + 1; end

        // sub x3, x1, x2
        instr = 32'h4020_81B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_1000_0_0_00_0_0_0) begin $display("FAIL: sub  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: sub  ctrl = %b", ctrl); pass = pass + 1; end

        // sll x3, x1, x2
        instr = 32'h0020_91B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0001_0_0_00_0_0_0) begin $display("FAIL: sll  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: sll  ctrl = %b", ctrl); pass = pass + 1; end

        // slt x3, x1, x2
        instr = 32'h0020_A1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0010_0_0_00_0_0_0) begin $display("FAIL: slt  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: slt  ctrl = %b", ctrl); pass = pass + 1; end

        // sltu x3, x1, x2
        instr = 32'h0020_B1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0011_0_0_00_0_0_0) begin $display("FAIL: sltu ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: sltu ctrl = %b", ctrl); pass = pass + 1; end

        // xor x3, x1, x2
        instr = 32'h0020_C1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0100_0_0_00_0_0_0) begin $display("FAIL: xor  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: xor  ctrl = %b", ctrl); pass = pass + 1; end

        // srl x3, x1, x2
        instr = 32'h0020_D1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0101_0_0_00_0_0_0) begin $display("FAIL: srl  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: srl  ctrl = %b", ctrl); pass = pass + 1; end

        // sra x3, x1, x2 
        instr = 32'h4020_D1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_1101_0_0_00_0_0_0) begin $display("FAIL: sra  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: sra  ctrl = %b", ctrl); pass = pass + 1; end

        // or x3, x1, x2
        instr = 32'h0020_E1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0110_0_0_00_0_0_0) begin $display("FAIL: or   ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: or   ctrl = %b", ctrl); pass = pass + 1; end

        // and x3, x1, x2
        instr = 32'h0020_F1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0111_0_0_00_0_0_0) begin $display("FAIL: and  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: and  ctrl = %b", ctrl); pass = pass + 1; end

        // M extension

        // mul x3, x1, x2
        instr = 32'h0220_81B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0000_0_0_11_0_0_0) begin $display("FAIL: mul  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: mul  ctrl = %b", ctrl); pass = pass + 1; end

        // div x3, x1, x2
        instr = 32'h0220_C1B3;
        #10;
        if (ctrl !== 18'b1_000_00_0_0000_0_0_11_0_0_0) begin $display("FAIL: div  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: div  ctrl = %b", ctrl); pass = pass + 1; end

        // I-type ALU: rs1 op imm

        // addi x1, x0, 5
        instr = 32'h0050_0093;
        #10;
        if (ctrl !== 18'b1_000_00_1_0000_0_0_00_0_0_0) begin $display("FAIL: addi 5    ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: addi 5    ctrl = %b", ctrl); pass = pass + 1; end

        // addi x1, x0, -1 
        instr = 32'hFFF0_0093;
        #10;
        if (ctrl !== 18'b1_000_00_1_0000_0_0_00_0_0_0) begin $display("FAIL: addi -1   ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: addi -1   ctrl = %b", ctrl); pass = pass + 1; end

        // xori x1, x1, -1 
        instr = 32'hFFF0_C093;
        #10;
        if (ctrl !== 18'b1_000_00_1_0100_0_0_00_0_0_0) begin $display("FAIL: xori -1   ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: xori -1   ctrl = %b", ctrl); pass = pass + 1; end

        // slli x1, x1, 3
        instr = 32'h0030_9093;
        #10;
        if (ctrl !== 18'b1_000_00_1_0001_0_0_00_0_0_0) begin $display("FAIL: slli 3    ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: slli 3    ctrl = %b", ctrl); pass = pass + 1; end

        // srli x1, x1, 3
        instr = 32'h0030_D093;
        #10;
        if (ctrl !== 18'b1_000_00_1_0101_0_0_00_0_0_0) begin $display("FAIL: srli 3    ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: srli 3    ctrl = %b", ctrl); pass = pass + 1; end

        // srai x1, x1, 3 
        instr = 32'h4030_D093;
        #10;
        if (ctrl !== 18'b1_000_00_1_1101_0_0_00_0_0_0) begin $display("FAIL: srai 3    ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: srai 3    ctrl = %b", ctrl); pass = pass + 1; end

        // loads: address = rs1 + imm, write memory data to rd

        // lw x5, 8(x1)
        instr = 32'h0080_A283;
        #10;
        if (ctrl !== 18'b1_000_00_1_0000_1_0_01_0_0_0) begin $display("FAIL: lw   ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: lw   ctrl = %b", ctrl); pass = pass + 1; end

        // lb x5, 0(x1)  (same control; the byte/half/word choice comes from funct3 in memory.v)
        instr = 32'h0000_8283;
        #10;
        if (ctrl !== 18'b1_000_00_1_0000_1_0_01_0_0_0) begin $display("FAIL: lb   ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: lb   ctrl = %b", ctrl); pass = pass + 1; end

        // stores: address = rs1 + S-imm, no register write

        // sw x2, 8(x1)
        instr = 32'h0020_A423;
        #10;
        if (ctrl !== 18'b0_001_00_1_0000_0_1_00_0_0_0) begin $display("FAIL: sw   ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: sw   ctrl = %b", ctrl); pass = pass + 1; end

        // branches: B-imm, no register write

        // beq x3, x3, 8
        instr = 32'h0031_8463;
        #10;
        if (ctrl !== 18'b0_010_00_0_0000_0_0_00_1_0_0) begin $display("FAIL: beq  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: beq  ctrl = %b", ctrl); pass = pass + 1; end

        // bne x1, x2, 8
        instr = 32'h0020_9463;
        #10;
        if (ctrl !== 18'b0_010_00_0_0000_0_0_00_1_0_0) begin $display("FAIL: bne  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: bne  ctrl = %b", ctrl); pass = pass + 1; end

        // upper immediates

        // lui x1, 0x12345  (0 + imm)
        instr = 32'h1234_50B7;
        #10;
        if (ctrl !== 18'b1_011_10_1_0000_0_0_00_0_0_0) begin $display("FAIL: lui   ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: lui   ctrl = %b", ctrl); pass = pass + 1; end

        // auipc x1, 0x12345  (PC + imm)
        instr = 32'h1234_5097;
        #10;
        if (ctrl !== 18'b1_011_01_1_0000_0_0_00_0_0_0) begin $display("FAIL: auipc ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: auipc ctrl = %b", ctrl); pass = pass + 1; end

        // jumps: write PC+4 to rd

        // jal x4, 4  (target = PC + imm, computed in core.v, not the ALU)
        instr = 32'h0040_026F;
        #10;
        if (ctrl !== 18'b1_100_00_0_0000_0_0_10_0_1_0) begin $display("FAIL: jal  ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: jal  ctrl = %b", ctrl); pass = pass + 1; end

        // jalr x1, 0(x5)  (target = rs1 + imm, computed by the ALU)
        instr = 32'h0002_80E7;
        #10;
        if (ctrl !== 18'b1_000_00_1_0000_0_0_10_0_0_1) begin $display("FAIL: jalr ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: jalr ctrl = %b", ctrl); pass = pass + 1; end

        // things that I'll change later
        // reg_write and mem_write should be 0.

        // fence  (MISC-MEM: a no-op on this CPU)
        instr = 32'h0FF0_000F;
        #10;
        if (ctrl !== 18'b0) begin $display("FAIL: fence ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: fence ctrl = %b", ctrl); pass = pass + 1; end

        // sfence.vma x0, x0
        instr = 32'h1200_0073;
        #10;
        if (ctrl !== 18'b0 || is_sfence !== 1 || illegal !== 0)
            begin $display("FAIL: sfence.vma x0,x0 ctrl = %b sfence = %b illegal = %b", ctrl, is_sfence, illegal); fail = fail + 1; end
        else begin $display("PASS: sfence.vma x0,x0 ctrl = %b", ctrl); pass = pass + 1; end

        // sfence.vma a0, a1  (rs1, rs2 can be anything)
        instr = 32'h12B5_0073;
        #10;
        if (ctrl !== 18'b0 || is_sfence !== 1 || illegal !== 0)
            begin $display("FAIL: sfence.vma a0,a1 ctrl = %b sfence = %b illegal = %b", ctrl, is_sfence, illegal); fail = fail + 1; end
        else begin $display("PASS: sfence.vma a0,a1 ctrl = %b", ctrl); pass = pass + 1; end

        // sfence funct7 with rd = x1  (reserved: illegal)
        instr = 32'h1200_00F3;
        #10;
        if (is_sfence !== 0 || illegal !== 1)
            begin $display("FAIL: sfence rd!=0 sfence = %b illegal = %b", is_sfence, illegal); fail = fail + 1; end
        else begin $display("PASS: sfence rd!=0 illegal"); pass = pass + 1; end


        // ecall  (SYSTEM: a no-op for now, gets real behaviour in stage 3)
        instr = 32'h0000_0073;
        #10;
        if (ctrl !== 18'b0) begin $display("FAIL: ecall ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: ecall ctrl = %b", ctrl); pass = pass + 1; end

        // all zeros  (not a valid instruction: opcode 0000000)
        instr = 32'h0000_0000;
        #10;
        if (ctrl !== 18'b0) begin $display("FAIL: 00000000 ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: 00000000 ctrl = %b", ctrl); pass = pass + 1; end

        // all ones  (not a valid instruction: opcode 1111111)
        instr = 32'hFFFF_FFFF;
        #10;
        if (ctrl !== 18'b0) begin $display("FAIL: FFFFFFFF ctrl = %b", ctrl); fail = fail + 1; end
        else begin $display("PASS: FFFFFFFF ctrl = %b", ctrl); pass = pass + 1; end

        $display("decoder testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule