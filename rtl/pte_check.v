module pte_check (
    input  wire [1:0] priv,    // 00 U, 01 S (M never translates)
    input  wire [1:0] acc,     // 00 fetch, 01 load, 10 store
    input  wire       sum,     // sstatus.SUM
    input  wire       mxr,     // sstatus.MXR
    input  wire [7:0] flags,   // pte[7:0] = D A G U X W R V
    output wire       fault
);

    wire pte_r = flags[1];
    wire pte_w = flags[2];
    wire pte_x = flags[3];
    wire pte_u = flags[4];
    wire pte_a = flags[6];
    wire pte_d = flags[7];

    wire rwx_ok = (acc == 2'b00) ? pte_x :  // fetch
                  (acc == 2'b01) ? (pte_r || (mxr && pte_x)) :  // load
                  (acc == 2'b10) ? pte_w : 1'b0;  // store
    wire u_ok = (priv == 2'b00) ? pte_u :  // U mode: PTE.U must be set
                (priv == 2'b01) ? (!pte_u || (sum && acc != 2'b00)) : 1'b1;  // S: kernel page, or user page with SUM (no fetch)
    wire ad_ok = pte_a && (acc != 2'b10 || pte_d);  // A always, D on store

    // check for page fault
    assign fault = !(rwx_ok && u_ok && ad_ok);

endmodule