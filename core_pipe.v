`default_nettype none
`timescale 1ns / 1ps
// pipelined cpu core
module core_pipe#(parameter RESET_PC = 32'h00000000)(
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
//IF/ID
reg [31:0] if_id_pc, if_id_instr, if_id_pc_plus4;

//ID/EX
reg [31:0] id_ex_pc, id_ex_pc_plus4, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
reg [4:0] id_ex_rd, id_ex_rs1, id_ex_rs2;
reg [3:0] id_ex_alu_op;
reg [2:0] id_ex_funct3;
reg [1:0] id_ex_alu_a_sel, id_ex_wb_sel;
reg id_ex_alu_b_sel, id_ex_branch, id_ex_jal, id_ex_jalr, id_ex_mem_read, id_ex_mem_write, id_ex_reg_write;
reg id_ex_is_csr;

//EX/MEM
reg [31:0] ex_mem_alu_result, ex_mem_multdiv_result, ex_mem_rs2_data, ex_mem_pc_plus4;
reg ex_mem_is_csr, ex_mem_csr_we;
reg [11:0] ex_mem_csr_addr;
reg [31:0] ex_mem_csr_src;
reg [4:0] ex_mem_rd;
reg [2:0] ex_mem_funct3;
reg [1:0] ex_mem_wb_sel;
reg ex_mem_mem_read, ex_mem_mem_write, ex_mem_reg_write;

//MEM/WB
reg [31:0] mem_wb_alu_result, mem_wb_multdiv_result, mem_wb_pc_plus4, mem_wb_mem_rdata;
reg [4:0] mem_wb_rd;
reg [1:0] mem_wb_wb_sel;
reg mem_wb_reg_write;

//IF
reg [31:0] pc;
wire [31:0] if_pc_plus4, pc_next;

wire ex_redirect; // here since iverilog doesn't like it being declared later
wire stall;
wire ex_busy;
wire mem_trap = 1'b0; // placeholder for trap handling
wire ex_is_mul = (id_ex_wb_sel == 2'b11) && !id_ex_funct3[2]; // mul in EX

wire [31:0] fetch_addr = rst ? RESET_PC : ex_redirect ? pc_next : (stall || ex_busy) ? pc : pc_next;

assign instr_addr  = fetch_addr;
assign if_pc_plus4 = pc + 4;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc             <= RESET_PC;
        if_id_pc       <= 0;
        if_id_instr    <= 32'h00000013; // addi x0, x0, 0
        if_id_pc_plus4 <= 0;
    end else if (ex_redirect) begin
        pc             <= pc_next;
        if_id_pc       <= 0;
        if_id_instr    <= 32'h00000013; // addi x0, x0, 0
        if_id_pc_plus4 <= 0;
    end else if (stall || ex_busy) begin
        pc             <= pc; // hold pc
        if_id_pc       <= if_id_pc; // hold if_id_pc
        if_id_instr    <= if_id_instr; // hold if_id_instr
        if_id_pc_plus4 <= if_id_pc_plus4; // hold if_id_pc_plus4
    end else begin
        pc             <= pc_next;
        if_id_pc       <= pc;
        if_id_instr    <= instr;
        if_id_pc_plus4 <= if_pc_plus4;
    end
end

//ID
wire [4:0] id_rs1, id_rs2, id_rd;
wire [3:0] id_alu_op;
wire [2:0] id_funct3, id_imm_sel;
wire [1:0] id_alu_a_sel, id_wb_sel;
wire id_alu_b_sel, id_reg_write, id_mem_read, id_mem_write;
wire id_branch, id_jal, id_jalr, id_is_csr;
wire [31:0] id_rs1_data, id_rs2_data, id_imm, wb_data;

assign id_rs1 = if_id_instr[19:15];
assign id_rs2 = if_id_instr[24:20];
assign id_rd  = if_id_instr[11:7];
assign id_funct3 = if_id_instr[14:12];
assign stall = (id_ex_mem_read || ex_is_mul || id_ex_is_csr) && (id_ex_rd != 0) &&
               ((id_ex_rd == id_rs1) || (id_ex_rd == id_rs2)); // load/mul/csr-use hazard
decoder u_decoder (
    .instr(if_id_instr),
    .reg_write(id_reg_write),
    .imm_sel(id_imm_sel),
    .alu_a_sel(id_alu_a_sel),
    .alu_b_sel(id_alu_b_sel),
    .alu_op(id_alu_op),
    .mem_read(id_mem_read),
    .mem_write(id_mem_write),
    .wb_sel(id_wb_sel),
    .branch(id_branch),
    .jal(id_jal),
    .jalr(id_jalr),
    .is_csr(id_is_csr)
);

immgen u_immgen (
    .instr(if_id_instr),
    .imm_sel(id_imm_sel),
    .imm(id_imm)
);

reg32 u_reg32 (
    .clk(clk),
    .we(mem_wb_reg_write), // write comes from wb stage
    .reset(rst),
    .rs1(id_rs1),
    .rs2(id_rs2),
    .rd(mem_wb_rd),
    .wd(wb_data),
    .rd1(id_rs1_data),
    .rd2(id_rs2_data)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_ex_pc          <= 0;
        id_ex_pc_plus4    <= 0;
        id_ex_rs1_data    <= 0;
        id_ex_rs2_data    <= 0;
        id_ex_imm         <= 0;
        id_ex_rd          <= 0;
        id_ex_rs1         <= 0;
        id_ex_rs2         <= 0;
        id_ex_alu_op      <= 0;
        id_ex_funct3      <= 0;
        id_ex_alu_a_sel   <= 0;
        id_ex_alu_b_sel   <= 0;
        id_ex_wb_sel      <= 0;
        id_ex_branch      <= 0;
        id_ex_jal         <= 0;
        id_ex_jalr        <= 0;
        id_ex_mem_read    <= 0;
        id_ex_mem_write   <= 0;
        id_ex_reg_write   <= 0;
        id_ex_is_csr      <= 0;
    end else if (ex_redirect || stall) begin
        id_ex_reg_write   <= 0; // bubble
        id_ex_mem_write   <= 0;
        id_ex_mem_read    <= 0;
        id_ex_branch      <= 0;
        id_ex_jal         <= 0;
        id_ex_jalr        <= 0;
        id_ex_rd          <= 0;
        id_ex_is_csr      <= 0;
    end else if (ex_busy) begin
        id_ex_pc          <= id_ex_pc; // hold
        id_ex_pc_plus4    <= id_ex_pc_plus4; // hold
        id_ex_rs1_data    <= id_ex_rs1_data; // hold
        id_ex_rs2_data    <= id_ex_rs2_data; // hold
        id_ex_imm         <= id_ex_imm; // hold
        id_ex_rd          <= id_ex_rd; // hold
        id_ex_rs1         <= id_ex_rs1; // hold
        id_ex_rs2         <= id_ex_rs2; // hold
        id_ex_alu_op      <= id_ex_alu_op; // hold
        id_ex_funct3      <= id_ex_funct3; // hold
        id_ex_alu_a_sel   <= id_ex_alu_a_sel; // hold
        id_ex_alu_b_sel   <= id_ex_alu_b_sel; // hold
        id_ex_wb_sel      <= id_ex_wb_sel; // hold
        id_ex_branch      <= id_ex_branch; // hold
        id_ex_jal         <= id_ex_jal; // hold
        id_ex_jalr        <= id_ex_jalr; // hold
        id_ex_mem_read    <= id_ex_mem_read; // hold
        id_ex_mem_write   <= id_ex_mem_write; // hold
        id_ex_reg_write   <= id_ex_reg_write; // hold
        id_ex_is_csr      <= id_ex_is_csr; // hold
    end else begin
        id_ex_pc          <= if_id_pc;
        id_ex_pc_plus4    <= if_id_pc_plus4;
        id_ex_rs1_data    <= id_rs1_data;
        id_ex_rs2_data    <= id_rs2_data;
        id_ex_imm         <= id_imm;
        id_ex_rd          <= id_rd;
        id_ex_rs1         <= id_rs1;
        id_ex_rs2         <= id_rs2;
        id_ex_alu_op      <= id_alu_op;
        id_ex_funct3      <= id_funct3;
        id_ex_alu_a_sel   <= id_alu_a_sel;
        id_ex_alu_b_sel   <= id_alu_b_sel;
        id_ex_wb_sel      <= id_wb_sel;
        id_ex_branch      <= id_branch;
        id_ex_jal         <= id_jal;
        id_ex_jalr        <= id_jalr;
        id_ex_mem_read    <= id_mem_read;
        id_ex_mem_write   <= id_mem_write;
        id_ex_reg_write   <= id_reg_write;
        id_ex_is_csr      <= id_is_csr;
    end
end

//EX
wire [31:0] ex_alu_a, ex_alu_b, ex_alu_result, mem_mul_result;
wire [31:0] ex_branch_target, ex_jalr_target;
wire ex_branch_taken;
wire div_busy, div_done;
wire ex_is_div = (id_ex_wb_sel == 2'b11) && id_ex_funct3[2]; // funct3[2] = 1 for div/rem, 0 for mul
wire div_start = ex_is_div && !div_busy && !div_done;
wire [31:0] div_result;
// forwarding
wire fwd_a_exmem = ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1);
wire fwd_b_exmem = ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2);
wire fwd_a_memwb = mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1);
wire fwd_b_memwb = mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2);

wire [31:0] ex_mem_result = (ex_mem_wb_sel == 2'b10) ? ex_mem_pc_plus4:
                            (ex_mem_wb_sel == 2'b11) ? ex_mem_multdiv_result : ex_mem_alu_result;
wire [31:0] ex_rs1 = fwd_a_exmem ? ex_mem_result :
                    fwd_a_memwb ? wb_data : id_ex_rs1_data;
wire [31:0] ex_rs2 = fwd_b_exmem ? ex_mem_result :
                    fwd_b_memwb ? wb_data : id_ex_rs2_data;

assign ex_busy = ex_is_div && !div_done;
// alu muxes
assign ex_alu_a = (id_ex_alu_a_sel == 2'b01) ? id_ex_pc : (id_ex_alu_a_sel == 2'b10) ? 32'b0 : ex_rs1;
assign ex_alu_b = (id_ex_alu_b_sel == 1'b1) ? id_ex_imm : ex_rs2;
//jump targets
assign ex_branch_target = id_ex_pc + id_ex_imm;
wire [31:0] ex_addr = ex_rs1 + id_ex_imm; // rs1 + imm, jalr & ld/st
wire [31:0] ex_csr_src = id_ex_funct3[2] ? {27'b0, id_ex_rs1} : ex_rs1; // uimm or rs1
wire ex_csr_we = id_ex_is_csr && ((id_ex_funct3[1:0] == 2'b01) || (id_ex_rs1 != 0)); // W always, S/C only if rs1 != 0

assign ex_jalr_target = {ex_addr[31:1], 1'b0}; // rs1 + imm, bit 0 cleared
//pc_next back to IF
// assign pc_next = (id_ex_jalr) ? ex_jalr_target :
//                 (id_ex_jal) ? ex_branch_target :
//                 (id_ex_branch && ex_branch_taken) ? ex_branch_target : if_pc_plus4;
assign pc_next = id_ex_jalr ? ex_jalr_target :
                 ex_redirect ? ex_branch_target: if_pc_plus4;

// redirect
assign ex_redirect = (id_ex_branch && ex_branch_taken) || id_ex_jal || id_ex_jalr;
//alu
alu u_alu (
    .a(ex_alu_a),
    .b(ex_alu_b),
    .alu_op(id_ex_alu_op),
    .result(ex_alu_result)
);
multiplier u_multiplier (
    .clk(clk),
    .a(ex_rs1),
    .b(ex_rs2),
    .op(id_ex_funct3[1:0]),
    .result(mem_mul_result)
);
divider u_divider (
    .clk(clk),
    .rst(rst),
    .start(div_start),
    .a(ex_rs1),
    .b(ex_rs2),
    .op(id_ex_funct3[1:0]),
    .busy(div_busy),
    .done(div_done),
    .result(div_result)
);
branch_unit u_branch_unit (
    .a(ex_rs1),
    .b(ex_rs2),
    .funct3(id_ex_funct3),
    .branch_taken(ex_branch_taken)
);
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ex_mem_alu_result   <= 0;
        ex_mem_multdiv_result<= 0;
        ex_mem_rs2_data     <= 0;
        ex_mem_pc_plus4     <= 0;
        ex_mem_rd           <= 0;
        ex_mem_funct3       <= 0;
        ex_mem_wb_sel       <= 0;
        ex_mem_mem_read     <= 0;
        ex_mem_mem_write    <= 0;
        ex_mem_reg_write    <= 0;
        ex_mem_is_csr       <= 0;
        ex_mem_csr_we       <= 0;
        ex_mem_csr_addr     <= 0;
        ex_mem_csr_src      <= 0;
    end else if (ex_busy) begin
        ex_mem_reg_write <= 0;
        ex_mem_mem_write <= 0;
        ex_mem_mem_read  <= 0;
        ex_mem_rd        <= 0;
        ex_mem_is_csr    <= 0;
        ex_mem_csr_we    <= 0;
    end else begin
        ex_mem_alu_result   <= ex_alu_result;
        ex_mem_multdiv_result<= div_result;
        ex_mem_rs2_data     <= ex_rs2;
        ex_mem_pc_plus4     <= id_ex_pc_plus4;
        ex_mem_rd           <= id_ex_rd;
        ex_mem_funct3       <= id_ex_funct3;
        ex_mem_wb_sel       <= id_ex_wb_sel;
        ex_mem_mem_read     <= id_ex_mem_read;
        ex_mem_mem_write    <= id_ex_mem_write;
        ex_mem_reg_write    <= id_ex_reg_write;
        ex_mem_is_csr       <= id_ex_is_csr;
        ex_mem_csr_we       <= ex_csr_we;
        ex_mem_csr_addr     <= id_ex_imm[11:0]; // csr addr
        ex_mem_csr_src      <= ex_csr_src;
    end
end

//MEM
wire mem_is_mul = (ex_mem_wb_sel == 2'b11) && !ex_mem_funct3[2]; // mul in MEM
assign mem_addr = ex_addr; // ex mem alu result gets this
assign mem_wdata = ex_rs2;  // ex mem rs2 data gets this
assign mem_write = id_ex_mem_write && !mem_trap; // no store on trap
assign mem_read  = id_ex_mem_read;
assign mem_funct3 = id_ex_funct3;
assign wb_data = (mem_wb_wb_sel == 2'b00) ? mem_wb_alu_result :
                 (mem_wb_wb_sel == 2'b01) ? mem_wb_mem_rdata :
                 (mem_wb_wb_sel == 2'b10) ? mem_wb_pc_plus4 : mem_wb_multdiv_result;
wire [31:0] mem_csr_rdata; // old csr value

csr u_csr (
    .clk(clk),
    .rst(rst),
    .addr(ex_mem_csr_addr),
    .src(ex_mem_csr_src),
    .dst(mem_csr_rdata),
    .we(ex_mem_csr_we),
    .op(ex_mem_funct3[1:0])
);
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mem_wb_mem_rdata      <= 0;
        mem_wb_alu_result    <= 0;
        mem_wb_multdiv_result <= 0;
        mem_wb_pc_plus4      <= 0;
        mem_wb_rd            <= 0;
        mem_wb_wb_sel        <= 0;
        mem_wb_reg_write     <= 0;
    end else begin
        mem_wb_mem_rdata      <= mem_rdata;
        mem_wb_alu_result    <= ex_mem_is_csr ? mem_csr_rdata : ex_mem_alu_result;
        mem_wb_multdiv_result <= mem_is_mul ? mem_mul_result : ex_mem_multdiv_result;
        mem_wb_pc_plus4      <= ex_mem_pc_plus4;
        mem_wb_rd            <= ex_mem_rd;
        mem_wb_wb_sel        <= ex_mem_wb_sel;
        mem_wb_reg_write     <= ex_mem_reg_write;
    end
end

endmodule
`default_nettype wire