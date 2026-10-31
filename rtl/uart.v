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
    output wire        tx,      // serial out
    input  wire        rx,      // serial in
    input wire        rx_pop   // rx_data unread
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

reg [1:0] rx_sync;
always @(posedge clk or posedge rst)
    if (rst) rx_sync <= 2'b11;              // idle high
    else     rx_sync <= {rx_sync[0], rx};   // 2 flop sync
wire rx_s = rx_sync[1];                     // safe to use

// rx
localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
reg  [1:0]  rx_state;    // IDLE/START/DATA/STOP
reg  [15:0] rx_cnt;      // clocks into this bit
reg  [2:0]  rx_bit;      // which data bit
reg  [7:0]  rx_shift;    // bits when arrive
reg  [7:0]  rx_data;     // last full byte
reg         rx_valid;    // rx_data unread
always @(posedge clk) begin
    case (addr[3:0])
        4'h4:    rdata <= {24'b0, rx_data};  // rx data
        4'h8:    rdata <= {30'b0, rx_valid, tx_busy};  // status: rx_valid, tx_busy
        default: rdata <= 32'b0;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rx_state <= IDLE;
        rx_valid <= 0;
        rx_cnt   <= 0;
        rx_bit   <= 0;
        rx_shift <= 0;
        rx_data  <= 0;
    end else begin
        if (rx_pop) rx_valid <= 0; //read it

        case (rx_state)
        IDLE:  begin
            if (!rx_s) begin
                rx_state <= START;
                rx_cnt   <= 0;
            end
        end
        START: begin
            if (rx_cnt == DIV/2 - 1) begin
                if (!rx_s) begin
                    rx_state <= DATA;
                    rx_cnt   <= 0;
                end else begin
                    rx_state <= IDLE;
                end
            end else begin
                rx_cnt <= rx_cnt + 1;
            end
        end
        DATA: begin
            if (rx_cnt == DIV - 1) begin
                rx_shift <= {rx_s, rx_shift[7:1]};
                rx_cnt   <= 0;
                if (rx_bit == 7) begin
                    rx_state <= STOP;
                end else begin
                    rx_bit <= rx_bit + 1;
                end
            end else begin
                rx_cnt <= rx_cnt + 1;
            end
        end
        STOP: begin
            if (rx_cnt == DIV - 1) begin
                if (rx_s) begin
                    rx_data  <= rx_shift;
                    rx_valid <= 1;
                end
                rx_state <= IDLE;
                rx_cnt   <= 0;
                rx_bit   <= 0;
            end else begin
                rx_cnt <= rx_cnt + 1;
            end
        end
        endcase
    end
end

endmodule