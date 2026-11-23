module tlb #(
    parameter N = 8  // entries
) (
    input  wire        clk,
    input  wire        rst,
    // lookup (combinational)
    input  wire [19:0] vpn,         // va[31:12]
    output reg         hit,
    output reg  [21:0] ppn,         // already fixed for megapages
    output reg  [ 7:0] flags,       // D A G U X W R V
    // fill (from walker)
    input  wire        fill,
    input  wire [19:0] fill_vpn,
    input  wire [21:0] fill_ppn,
    input  wire [ 7:0] fill_flags,
    input  wire        fill_mega,   // 4 MiB page
    // sfence.vma
    input  wire        flush
);

    reg                     e_valid                           [0:N-1];
    reg     [         19:0] e_vpn                             [0:N-1];  // formatter made it weird
    reg     [         21:0] e_ppn                             [0:N-1];
    reg     [          7:0] e_flags                           [0:N-1];
    reg                     e_mega                            [0:N-1];

    integer                 i;
    reg     [$clog2(N)-1:0] next;  // round-robin slot to fill

    always @(*) begin
        hit   = 1'b0;
        ppn   = 22'd0;
        flags = 8'd0;
        for (i = 0; i < N; i = i + 1) begin
            if (!hit && e_valid[i] && (vpn[19:10] == e_vpn[i][19:10]) &&
                (e_mega[i] || (vpn[9:0] == e_vpn[i][9:0]))) begin
                hit   = 1'b1;
                ppn   = e_mega[i] ? {e_ppn[i][21:10], vpn[9:0]} : e_ppn[i];  // mega: keep vpn[0]
                flags = e_flags[i];
            end
        end
    end
    integer j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j < N; j = j + 1) begin
                e_valid[j] <= 1'b0;
                e_vpn[j]   <= 20'd0;
                e_ppn[j]   <= 22'd0;
                e_flags[j] <= 8'd0;
                e_mega[j]  <= 1'b0;
            end
            next <= 0;
        end else if (flush) begin
            for (j = 0; j < N; j = j + 1) begin
                e_valid[j] <= 1'b0;
            end
            next <= 0;
        end else if (fill) begin
            e_valid[next] <= 1'b1;
            e_vpn[next]   <= fill_vpn;
            e_ppn[next]   <= fill_ppn;
            e_flags[next] <= fill_flags;
            e_mega[next]  <= fill_mega;
            next          <= next + 1'b1;  // round-robin
        end
    end

endmodule
