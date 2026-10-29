`default_nettype none
`timescale 1ns / 1ps
// top module
module top_pipe #(
    parameter RESET_PC  = 32'h0000_0000,
    parameter ADDR_BITS = 12,
    parameter INIT_FILE = "testbenches/test_timer.hex",
    parameter CLK_HZ    = 80_000_000,
    parameter BAUD      = 115_200 
)(
input wire clk,
input wire rst,
output wire        store,      // a store happened (for LEDs)
output wire [31:0] store_data, // its data
output wire        uart_tx     // serial out
);

    wire [31:0] instr_addr, instr;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    wire        mem_write, mem_read;
    wire [2:0]  mem_funct3;

    // address decode
    wire is_timer = (mem_addr[31:16] == 16'h0200); // timer at 0x0200_xxxx
    wire is_uart  = (mem_addr[31:16] == 16'h1000); // uart at 0x1000_xxxx
    wire is_ram   = !is_timer && !is_uart;         // anything else is ram

    wire [31:0] ram_rdata, timer_rdata, uart_rdata; // load data per device
    wire        timer_irq;                          // timer -> core
    reg         is_timer_r, is_uart_r;              // last access's device
    wire        load_commit;                        // core -> uart: load retired
    wire [31:0] commit_addr;                        // its address
    wire        rx_pop;                             // uart rx pop

always @(posedge clk) begin
    is_timer_r <= is_timer;
    is_uart_r  <= is_uart;
end
assign mem_rdata = is_timer_r ? timer_rdata :
                   is_uart_r  ? uart_rdata  : ram_rdata; // last cycle's device
assign store      = mem_write;
assign store_data = mem_wdata;
assign rx_pop = load_commit && (commit_addr == 32'h1000_0004); // rx load retired

    core_pipe #(.RESET_PC(RESET_PC)) u_core (
    .clk         (clk),
    .rst         (rst),
    .instr       (instr),
    .instr_addr  (instr_addr),
    .mem_addr    (mem_addr),
    .mem_wdata   (mem_wdata),
    .mem_rdata   (mem_rdata),
    .mem_write   (mem_write),
    .mem_read    (mem_read),
    .mem_funct3  (mem_funct3),
    .timer_irq   (timer_irq),
    .load_commit (load_commit),
    .commit_addr (commit_addr)
    );

    memory #(.ADDR_BITS(ADDR_BITS), .INIT_FILE(INIT_FILE)) u_memory (
    .clk        (clk),
    .instr_addr (instr_addr),
    .mem_addr   (mem_addr),
    .mem_wdata  (mem_wdata),
    .mem_write  (mem_write && is_ram),
    .mem_read   (mem_read),
    .mem_funct3 (mem_funct3),
    .instr      (instr),
    .mem_rdata  (ram_rdata)
    );

    timer u_timer (
        .clk   (clk),
        .rst   (rst),
        .addr  (mem_addr),
        .wdata (mem_wdata),
        .we    (mem_write && is_timer),
        .rdata (timer_rdata),
        .irq   (timer_irq)
    );
    uart #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart (
        .clk   (clk),
        .rst   (rst),
        .addr  (mem_addr),
        .wdata (mem_wdata),
        .we    (mem_write && is_uart),
        .rdata (uart_rdata),
        .tx    (uart_tx)
    );
endmodule
`default_nettype wire