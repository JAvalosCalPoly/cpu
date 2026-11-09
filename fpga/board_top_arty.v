`default_nettype none
// arty s7 top: cpu at 12 MHz, uart on usb
module board_top_arty (
    input  wire CLK12MHZ,
    input  wire ck_rst,          // red RESET, active low
    output wire uart_rxd_out,    // fpga tx
    input  wire uart_txd_in      // fpga rx
);
    wire clk = CLK12MHZ;

    // sync the reset button
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~ck_rst};
    wire rst = rst_sync[1];

    top_pipe #(.ADDR_BITS(12), .INIT_FILE("echo.hex"),
               .CLK_HZ(12_000_000), .BAUD(115_200)) u_top (
        .clk(clk), .rst(rst),
        .store(), .store_data(),
        .uart_tx(uart_rxd_out),
        .uart_rx(uart_txd_in)
    );
endmodule
`default_nettype wire