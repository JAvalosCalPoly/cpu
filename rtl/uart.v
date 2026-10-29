`timescale 1ns / 1ps
module uart #(
    parameter CLK_HZ = 80_000_000,
    parameter BAUD   = 115_200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,    // offset in [3:0]
    input  wire [31:0] wdata,
    input  wire        we,
    output reg  [31:0] rdata,   // registered, like timer
    output wire        tx       // serial out
);

localparam DIV = CLK_HZ / BAUD; // clk per bit
reg [15:0] baud_cnt;
reg [9:0] frame;    // start bit, 8 data bits, stop bit
reg [3:0] bit_cnt;  // number of bits remaining in the frame
wire tx_busy = (bit_cnt != 0);
assign tx = tx_busy ? frame[0] : 1'b1; // idle at 1

// tx
always @(posedge clk or posedge rst) begin
    if (rst) begin
        baud_cnt <= 0;
        frame    <= 10'b1;
        bit_cnt  <= 0;
    end else if (we && addr[3:0] == 4'h0 && !tx_busy) begin
        frame   <= {1'b1, wdata[7:0], 1'b0}; // stop bit, 8 data bits, start bit
        bit_cnt <= 10; // total bits in the frame
    end else if (tx_busy) begin
        if (baud_cnt == DIV - 1) begin
            baud_cnt <= 0;
            frame    <= {1'b1, frame[9:1]}; // shift out the current bit
            bit_cnt  <= bit_cnt - 1;
        end else begin
            baud_cnt <= baud_cnt + 1;
        end
    end
end

// reads
always @(posedge clk) begin
    case (addr[3:0])
        4'h8:    rdata <= {31'b0, tx_busy};  // status
        default: rdata <= 32'b0;
    endcase
end

endmodule