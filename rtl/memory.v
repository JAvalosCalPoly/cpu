`timescale 1ns / 1ps
// memory for load/store instructions
module memory#(parameter ADDR_BITS = 12, parameter INIT_FILE = "program.hex")(
    input wire clk,
    input wire [31:0] instr_addr,
    input wire [31:0] mem_addr,
    input wire [31:0] mem_wdata,
    input wire        mem_write,
    input wire        mem_read,
    input wire [2:0]  mem_funct3,
    output reg [31:0] instr,
    output reg [31:0] mem_rdata
);

localparam DEPTH = 1 << ADDR_BITS;  // 4096

reg [31:0] mem [0:DEPTH-1];
wire [ADDR_BITS-1:0] data_index = mem_addr[ADDR_BITS+1:2];
reg [31:0] word;     // read on the edge
reg [1:0]  off_r;    // byte offset
reg [2:0]  funct3_r; // load type
reg        read_r;   // was a load
wire [31:0] shifted = word >> {off_r, 3'b000};   // wanted byte/half moved to the bottom

initial begin
    $readmemh(INIT_FILE, mem);
end

// assign instr = mem[instr_addr[ADDR_BITS+1:2]]; // word-aligned
always @(posedge clk) begin
    instr <= mem[instr_addr[ADDR_BITS+1:2]];
end

always @(posedge clk) begin
    word     <= mem[data_index]; // the word at data_index
    off_r    <= mem_addr[1:0]; // low 2 bits of mem_addr
    funct3_r <= mem_funct3; // load type
    read_r   <= mem_read; // was a load
end


always @(*) begin
    if (read_r) begin
        case (funct3_r)
            3'b000: mem_rdata = {{24{shifted[7]}}, shifted[7:0]}; // lb
            3'b001: mem_rdata = {{16{shifted[15]}}, shifted[15:0]}; // lh
            3'b010: mem_rdata = word; // lw
            3'b100: mem_rdata = {24'b0, shifted[7:0]}; // lbu
            3'b101: mem_rdata = {16'b0, shifted[15:0]}; // lhu
            default: mem_rdata = 32'b0;
        endcase
    end else begin
        mem_rdata = 32'b0;
    end
end

always @(posedge clk) begin
    if (mem_write) begin
        case (mem_funct3)
            3'b000: begin
                case (mem_addr[1:0])
                    2'b00: mem[data_index][7:0]   <= mem_wdata[7:0];
                    2'b01: mem[data_index][15:8]  <= mem_wdata[7:0];
                    2'b10: mem[data_index][23:16] <= mem_wdata[7:0];
                    2'b11: mem[data_index][31:24] <= mem_wdata[7:0];
                endcase
            end
            3'b001: begin
                case (mem_addr[1])
                    1'b0: mem[data_index][15:0] <= mem_wdata[15:0];
                    1'b1: mem[data_index][31:16] <= mem_wdata[15:0];
                endcase
            end
            3'b010: mem[data_index] <= mem_wdata;   // sw
            default: ; // do nothing
        endcase
    end
end

endmodule