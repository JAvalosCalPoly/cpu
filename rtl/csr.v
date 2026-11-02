module csr (
    input wire clk,
    input wire rst,
    input wire [11:0] addr,
    input wire [31:0] src,
    output reg [31:0] dst,
    input wire we,
    input wire [1:0] op,
    input  wire        trap,       // exception in MEM
    input  wire [31:0] trap_pc,    // to mepc
    input  wire [31:0] trap_cause, // to mcause
    input  wire        mret,       // mret in MEM
    output wire [31:0] mtvec_o,    // trap target
    output wire [31:0] mepc_o,      // mret target
    output wire valid, // is csr addr valid
    input  wire timer_irq, // when mtime >= mtimecmp
    output wire int_pending, // take that interrupt
    output wire [1:0] priv_o // priveledge mode
);

localparam MSTATUS = 12'h300, MTVEC = 12'h305, MSCRATCH = 12'h340, MEPC = 12'h341, MCAUSE = 12'h342,
    MIE = 12'h304, MIP = 12'h344;
reg mie_mtie; // mie bit 7: timer enable
reg [31:0] mtvec, mscratch, mcause;
reg [31:2] mepc; // mepc[1:0] always 0
reg mstatus_mie, mstatus_mpie;
reg [1:0] mstatus_mpp;
reg [1:0] priv;

wire [31:0] wdata = (op == 2'b01) ? src :
                    (op == 2'b10) ? (dst | src) : (dst & ~src); // W, S, C
wire csr_ok   = (priv >= addr[9:8]);// mode high enough
wire ro_write = (addr[11:10] == 2'b11) && we;// write to read-only
wire csr_exists = (addr == MSTATUS) || (addr == MTVEC) || (addr == MSCRATCH) ||
                  (addr == MEPC) || (addr == MCAUSE) || (addr == MIE) || (addr == MIP);

assign mtvec_o = {mtvec[31:2], 2'b00}; // direct mode
assign mepc_o = {mepc, 2'b00};
assign int_pending = (mstatus_mie || priv != 2'b11) && mie_mtie && timer_irq;
assign valid = csr_exists && csr_ok && !ro_write;
assign priv_o = priv;

always @(*) begin
    case (addr)
        MSTATUS: dst = {19'b0, mstatus_mpp, 3'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};
        MTVEC: dst = mtvec;
        MSCRATCH: dst = mscratch;
        MEPC: dst = {mepc, 2'b0};
        MCAUSE: dst = mcause;
        MIE: dst = {24'b0, mie_mtie, 7'b0};  // MTIE at bit 7
        MIP: dst = {24'b0, timer_irq, 7'b0}; // MTIP at bit 7
        default: dst = 32'b0;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtvec <= 32'b0;
        mscratch <= 32'b0;
        mepc <= 30'b0;
        mcause <= 32'b0;
        mstatus_mie <= 1'b0;
        mstatus_mpie <= 1'b0;
        mie_mtie <= 1'b0;
        mstatus_mpp <= 2'b00;
        priv <= 2'b11;
    end else if (trap) begin
        mepc <= trap_pc[31:2];
        mcause <= trap_cause;
        mstatus_mpie <= mstatus_mie;
        mstatus_mie <= 1'b0; // disable interrupts on trap
        mstatus_mpp <= priv;
        priv <= 2'b11;
    end else if (mret) begin
        mstatus_mie <= mstatus_mpie; // restore mie from mpie
        mstatus_mpie <= 1'b1; // set mpie to 1 on mret
        priv <= mstatus_mpp;
        mstatus_mpp <= 2'b00;
    end else if (we) begin
        case (addr)
            MSTATUS: begin
                {mstatus_mpie, mstatus_mie} <= {wdata[7], wdata[3]};
                mstatus_mpp <= (wdata[12:11] == 2'b11) ? 2'b11 : 2'b00; // M or U only
            end
            MTVEC:    mtvec    <= wdata;
            MSCRATCH: mscratch <= wdata;
            MEPC:     mepc     <= wdata[31:2];
            MCAUSE:   mcause   <= wdata;
            MIE:      mie_mtie <= wdata[7];
            MIP:      ; // read-only
            default: ;
        endcase
    end
end

endmodule