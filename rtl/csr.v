module csr (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] addr,
    input  wire [31:0] src,
    output reg  [31:0] dst,
    input  wire        we,
    input  wire [ 1:0] op,
    input  wire        trap,         // exception in MEM
    input  wire [31:0] trap_pc,      // to mepc
    input  wire [31:0] trap_cause,   // to mcause
    output wire [31:0] trap_vec_o,
    input  wire        mret,         // mret in MEM
    input  wire        sret,         // sret in MEM
    //output wire [31:0] mtvec_o,      // trap target
    output wire [31:0] mepc_o,       // mret target
    output wire [31:0] sepc_o,       // sret target
    output wire        valid,        // is csr addr valid
    input  wire        timer_irq,    // when mtime >= mtimecmp
    output wire        int_pending,  // take that interrupt
    output wire [ 1:0] priv_o        // priveledge mode
);

    localparam MSTATUS = 12'h300, MTVEC = 12'h305, MSCRATCH = 12'h340, MEPC = 12'h341, MCAUSE = 12'h342,
    MIE = 12'h304, MIP = 12'h344;

    localparam SSTATUS = 12'h100, STVEC = 12'h105, SSCRATCH = 12'h140, SEPC = 12'h141, SCAUSE = 12'h142,
    STVAL = 12'h143, MEDELEG = 12'h302;

    reg mie_mtie;  // mie bit 7: timer enable
    reg [31:0] mtvec, mscratch, mcause;
    reg [31:2] mepc;  // mepc[1:0] always 0
    reg mstatus_mie, mstatus_mpie;
    reg [1:0] mstatus_mpp;
    reg [1:0] priv;

    // S
    reg mstatus_sie, mstatus_spie, mstatus_spp;
    reg [31:0] stvec, sscratch, scause, stval, medeleg;
    reg [31:2] sepc;  // sepc[1:0] always 0

    wire [31:0] wdata = (op == 2'b01) ? src :
                    (op == 2'b10) ? (dst | src) : (dst & ~src); // W, S, C
    wire csr_ok = (priv >= addr[9:8]);  // mode high enough
    //wire csr_ok = 1'b1; // for testing
    wire ro_write = (addr[11:10] == 2'b11) && we;  // write to read-only
    wire csr_exists = (addr == MSTATUS) || (addr == MTVEC) || (addr == MSCRATCH) ||
                  (addr == MEPC) || (addr == MCAUSE) || (addr == MIE) || (addr == MIP) ||
                  (addr == SSTATUS) || (addr == STVEC) || (addr == SSCRATCH) || (addr == SEPC)
                  || (addr == SCAUSE) || (addr == STVAL) || (addr == MEDELEG);
    wire to_s = (priv != 2'b11) && medeleg[trap_cause[4:0]] && !trap_cause[31];

    // assign mtvec_o = {mtvec[31:2], 2'b00};  // direct mode
    assign mepc_o = {mepc, 2'b00};
    assign sepc_o = {sepc, 2'b00};
    assign int_pending = (mstatus_mie || priv != 2'b11) && mie_mtie && timer_irq;
    assign valid = csr_exists && csr_ok && !ro_write;
    assign priv_o = priv;
    assign trap_vec_o = to_s ? {stvec[31:2], 2'b00} : {mtvec[31:2], 2'b00};
    wire [31:0] mstatus_val = {
        19'b0,
        mstatus_mpp,
        2'b0,
        mstatus_spp,
        mstatus_mpie,
        1'b0,
        mstatus_spie,
        1'b0,
        mstatus_mie,
        1'b0,
        mstatus_sie,
        1'b0
    };

    always @(*) begin
        case (addr)
            MSTATUS:  dst = mstatus_val;
            MTVEC:    dst = mtvec;
            MSCRATCH: dst = mscratch;
            MEPC:     dst = {mepc, 2'b0};
            MCAUSE:   dst = mcause;
            MIE:      dst = {24'b0, mie_mtie, 7'b0};  // MTIE at bit 7
            MIP:      dst = {24'b0, timer_irq, 7'b0};  // MTIP at bit 7
            SSTATUS:  dst = mstatus_val & 32'h0000_0122;  // SIE, SPIE, SPP only
            STVEC:    dst = stvec;
            SSCRATCH: dst = sscratch;
            SEPC:     dst = {sepc, 2'b0};
            SCAUSE:   dst = scause;
            STVAL:    dst = stval;
            MEDELEG:  dst = medeleg;
            default:  dst = 32'b0;
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
            mstatus_sie <= 1'b0;
            mstatus_spie <= 1'b0;
            mstatus_spp <= 1'b0;
            stvec <= 32'b0;
            sscratch <= 32'b0;
            sepc <= 30'b0;
            scause <= 32'b0;
            stval <= 32'b0;
            medeleg <= 32'b0;
        end else if (trap && to_s) begin
            sepc <= trap_pc[31:2];
            scause <= trap_cause;
            mstatus_spie <= mstatus_sie;
            mstatus_sie <= 1'b0;  // disable interrupts on trap
            mstatus_spp <= priv[0];
            priv <= 2'b01;
        end else if (trap) begin
            mepc <= trap_pc[31:2];
            mcause <= trap_cause;
            mstatus_mpie <= mstatus_mie;
            mstatus_mie <= 1'b0;  // disable interrupts on trap
            mstatus_mpp <= priv;
            priv <= 2'b11;
        end else if (mret) begin
            mstatus_mie <= mstatus_mpie;  // restore mie from mpie
            mstatus_mpie <= 1'b1;  // set mpie to 1 on mret
            priv <= mstatus_mpp;
            mstatus_mpp <= 2'b00;
        end else if (sret) begin
            mstatus_sie <= mstatus_spie;  // restore sie from spie
            mstatus_spie <= 1'b1;  // set spie to 1
            priv <= {1'b0, mstatus_spp};
            mstatus_spp <= 1'b0;
        end else if (we) begin
            case (addr)
                MSTATUS: begin
                    {mstatus_mpie, mstatus_mie} <= {wdata[7], wdata[3]};
                    {mstatus_spp, mstatus_spie, mstatus_sie} <= {wdata[8], wdata[5], wdata[1]};
                    mstatus_mpp <= (wdata[12:11] == 2'b10) ? 2'b00 : wdata[12:11];  // 10 reserved
                end
                MTVEC: mtvec <= wdata;
                MSCRATCH: mscratch <= wdata;
                MEPC: mepc <= wdata[31:2];
                MCAUSE: mcause <= wdata;
                MIE: mie_mtie <= wdata[7];
                MIP: ;  // read-only
                SSTATUS:
                {mstatus_spp, mstatus_spie, mstatus_sie} <= {
                    wdata[8], wdata[5], wdata[1]
                };  // S bits only
                STVEC: stvec <= wdata;
                SSCRATCH: sscratch <= wdata;
                SEPC: sepc <= wdata[31:2];
                SCAUSE: scause <= wdata;
                STVAL: stval <= wdata;
                MEDELEG: medeleg <= wdata & ~32'h0000_0800;  // ecall from M can't delegate
                default: ;
            endcase
        end
    end

endmodule
