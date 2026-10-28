`default_nettype none
// board top: cpu + memory, last stored value on the LEDs
module board_top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,   // red button, active low
    output reg  [15:0] LED
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

    wire [31:0] instr_addr, instr, mem_addr, mem_wdata, mem_rdata;
    wire        mem_write, mem_read;
    wire [2:0]  mem_funct3;

    core_pipe u_core (
        .clk(clk), .rst(rst),
        .instr(instr), .instr_addr(instr_addr),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_rdata(mem_rdata),
        .mem_write(mem_write), .mem_read(mem_read), .mem_funct3(mem_funct3)
    );

    memory #(.ADDR_BITS(12), .INIT_FILE("test_trap.hex")) u_memory (
        .clk(clk),
        .instr_addr(instr_addr), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_write(mem_write), .mem_read(mem_read), .mem_funct3(mem_funct3),
        .instr(instr), .mem_rdata(mem_rdata)
    );

    // latch every store, so the DONE marker ends up showing: 000D
    always @(posedge clk)
        if (rst)            LED <= 0;
        else if (mem_write) LED <= mem_wdata[15:0];
endmodule
`default_nettype wire