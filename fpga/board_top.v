`default_nettype none
// board top: cpu + memory, last stored value on the LEDs
module board_top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,   // red button, active low
    output reg  [15:0] LED,
    output wire        UART_RXD_OUT,    // serial out
    input  wire        UART_TXD_IN
);
    // 100 MHz in, 80 MHz out
    wire clk, locked;
    clk_wiz_0 u_clk (
        .clk_in1(CLK100MHZ),
        .clk_out1(clk),
        .locked(locked)              // high once clk is stable
    );

    // stay in reset until the clock is stable
    reg [1:0] rst_sync;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~CPU_RESETN | ~locked}; // button or clock not ready
    wire rst = rst_sync[1];                                                  // the second flip-flop

    wire        store;
    wire [31:0] store_data;

    top_pipe #(.ADDR_BITS(12), .INIT_FILE("test_uart.hex")) u_top (
    .clk(clk), .rst(rst),
    .store(store), .store_data(store_data),
    .uart_tx(UART_RXD_OUT),
    .uart_rx(UART_TXD_IN)
    );

    // latch every store, so the DONE marker ends up showing: 000D
    always @(posedge clk)
        if (rst)            LED <= 0;
        else if (store) LED <= store_data[15:0];
endmodule
`default_nettype wire