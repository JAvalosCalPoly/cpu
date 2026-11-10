module mmu (
    input  wire        clk,
    input  wire        rst,
    // from EX
    input  wire        req,        // load/store in EX
    input  wire        store,
    input  wire [31:0] va,
    // from csr
    input  wire [ 1:0] priv,
    input  wire [31:0] satp,
    input  wire        sum,
    input  wire        mxr,
    // from MEM
    input  wire        tlb_flush,  // sfence.vma
    input  wire        kill,       // mem_flush: EX instr is gone
    // to core
    output wire [31:0] pa,
    output wire        stall,      // miss, walking
    output wire        fault,      // page fault (with req, !stall)
    // memory port
    output wire        ptw_busy,   // PTW owns the port
    output wire [31:0] ptw_addr,
    input  wire [31:0] mem_rdata
);

    wire xlate = satp[31] && (priv != 2'b11);
    wire tlb_hit;
    wire [21:0] tlb_ppn;
    wire [7:0] tlb_flags;
    wire perm_fault;
    wire ptw_done;
    wire ptw_fault;
    wire [21:0] ptw_ppn;
    wire [7:0] ptw_flags;
    wire ptw_mega;
    wire ptw_mem_req;
    wire [31:0] ptw_mem_addr;
    wire ptw_start = req && xlate && !tlb_hit && !ptw_busy && !ptw_done && !kill;
    wire ptw_fill = ptw_done && !ptw_fault && !kill;
    wire miss = req && xlate && !tlb_hit;

    reg ptw_ready;

    tlb tlb_inst (
        .clk       (clk),
        .rst       (rst),
        .vpn       (va[31:12]),
        .hit       (tlb_hit),
        .ppn       (tlb_ppn),
        .flags     (tlb_flags),
        .fill      (ptw_fill),
        .fill_vpn  (va[31:12]),
        .fill_ppn  (ptw_ppn),
        .fill_flags(ptw_flags),
        .fill_mega (ptw_mega),
        .flush     (tlb_flush)
    );

    pte_check pte_check_inst (
        .priv (priv),
        .acc  (store ? 2'b10 : 2'b01),
        .sum  (sum),
        .mxr  (mxr),
        .flags(tlb_flags),
        .fault(perm_fault)
    );

    ptw ptw_inst (
        .clk      (clk),
        .rst      (rst),
        .start    (ptw_start),
        .abort    (kill),
        .vpn      (va[31:12]),
        .satp_ppn (satp[21:0]),
        .mem_req  (ptw_mem_req),
        .mem_addr (ptw_mem_addr),
        .mem_ready(ptw_ready),
        .mem_rdata(mem_rdata),
        .done     (ptw_done),
        .fault    (ptw_fault),
        .ppn      (ptw_ppn),
        .flags    (ptw_flags),
        .mega     (ptw_mega),
        .busy     (ptw_busy)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) ptw_ready <= 1'b0;
        else ptw_ready <= ptw_mem_req && !ptw_ready;
    end

    assign ptw_addr = ptw_mem_addr;
    assign pa = xlate ? {tlb_ppn[19:0], va[11:0]} : va;
    assign stall = miss && !(ptw_done && ptw_fault);
    assign fault = req && xlate && (tlb_hit ? perm_fault : (ptw_done && ptw_fault));

endmodule
