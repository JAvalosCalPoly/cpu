module mmu (
    input  wire        clk,
    input  wire        rst,
    // from IF
    input  wire        i_req,      // fetching (1 except reset)
    input  wire [31:0] i_va,       // fetch_addr
    input  wire        i_kill,     // ex_redirect || mem_flush
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
    // to IF
    output wire [31:0] i_pa,
    output wire        i_ok,       // fetch translated, use instr
    output wire        i_fault,    // fetch page fault
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

    // data side
    wire tlb_hit;
    wire [21:0] tlb_ppn;
    wire [7:0] tlb_flags;
    wire perm_fault;
    // fetch side
    wire itlb_hit;
    wire [21:0] itlb_ppn;
    wire [7:0] itlb_flags;
    wire iperm_fault;
    // walker
    wire ptw_done;
    wire ptw_fault;
    wire [21:0] ptw_ppn;
    wire [7:0] ptw_flags;
    wire ptw_mega;
    wire ptw_mem_req;
    wire [31:0] ptw_mem_addr;
    reg ptw_ready;
    reg owner;  // 0 data, 1 fetch

    wire miss = req && xlate && !tlb_hit;
    wire i_miss = i_req && xlate && !itlb_hit;
    wire start_d = miss && !ptw_busy && !ptw_done && !kill;  // data first
    wire start_i = i_miss && !miss && !ptw_busy && !ptw_done && !i_kill;
    wire done_d = ptw_done && !owner;
    wire done_i = ptw_done && owner;
    wire ptw_fill = done_d && !ptw_fault && !kill;
    wire iptw_fill = done_i && !ptw_fault && !i_kill;
    wire ptw_abort = owner ? i_kill : kill;

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

    tlb itlb_inst (
        .clk       (clk),
        .rst       (rst),
        .vpn       (i_va[31:12]),
        .hit       (itlb_hit),
        .ppn       (itlb_ppn),
        .flags     (itlb_flags),
        .fill      (iptw_fill),
        .fill_vpn  (i_va[31:12]),
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

    pte_check ipte_check_inst (
        .priv(priv),
        .acc(2'b00),  // fetch
        .sum(sum),
        .mxr(mxr),
        .flags(itlb_flags),
        .fault(iperm_fault)
    );

    ptw ptw_inst (
        .clk      (clk),
        .rst      (rst),
        .start    (start_d || start_i),
        .abort    (ptw_abort),
        .vpn      (start_d ? va[31:12] : i_va[31:12]),
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
        if (rst) begin
            ptw_ready <= 1'b0;
            owner     <= 1'b0;
        end else begin
            ptw_ready <= ptw_mem_req && !ptw_ready;
            if (start_d) owner <= 1'b0;
            else if (start_i) owner <= 1'b1;
        end
    end

    assign ptw_addr = ptw_mem_addr;
    // data side
    assign pa = xlate ? {tlb_ppn[19:0], va[11:0]} : va;
    assign stall = req && ((miss && !(done_d && ptw_fault)) || (ptw_busy && owner));  // I-walk owns port
    assign fault = req && xlate && (tlb_hit ? perm_fault : (done_d && ptw_fault));
    // fetch side
    assign i_pa = xlate ? {itlb_ppn[19:0], i_va[11:0]} : i_va;
    assign i_fault = i_req && xlate && (itlb_hit ? iperm_fault : (done_i && ptw_fault));
    assign i_ok = !xlate || (itlb_hit && !iperm_fault);

endmodule
