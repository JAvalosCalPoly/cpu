module timer(
    input wire clk,
    input wire rst,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire we,
    output reg [31:0] rdata,
    output wire irq // interrupt signal
);

localparam MTIME_LO = 16'hBFF8, MTIME_HI = 16'hBFFC,
    MTIMECMP_LO = 16'h4000, MTIMECMP_HI = 16'h4004;
wire [15:0] offset = addr[15:0];

reg [63:0] mtime, mtimecmp;
assign irq = (mtime >= mtimecmp);

always @(posedge clk or posedge rst) begin
    if (rst) mtime <= 0;
    else if (we && offset == MTIME_LO) mtime[31:0] <= wdata;
    else if (we && offset == MTIME_HI) mtime[63:32] <= wdata;
    else mtime <= mtime + 1;
end

always @(posedge clk or posedge rst) begin
    if (rst) mtimecmp <= 64'hFFFFFFFFFFFFFFFF; // no irq at start
    else if (we) case (offset)
        MTIMECMP_LO: mtimecmp[31:0] <= wdata;
        MTIMECMP_HI: mtimecmp[63:32] <= wdata;
        default: ;
    endcase
end

always @(posedge clk) begin
    case (offset)
        MTIME_LO: rdata <= mtime[31:0];
        MTIME_HI: rdata <= mtime[63:32];
        MTIMECMP_LO: rdata <= mtimecmp[31:0];
        MTIMECMP_HI: rdata <= mtimecmp[63:32];
        default: rdata <= 32'b0;
    endcase
end

endmodule