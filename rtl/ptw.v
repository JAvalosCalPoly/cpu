module ptw (
    input  wire        clk,
    input  wire        rst,
    // request (TLB miss)
    input  wire        start,      // 1-cycle pulse
    input  wire        abort,      // drop the walk
    input  wire [19:0] vpn,        // va[31:12]
    input  wire [21:0] satp_ppn,   // root table
    // memory (req/ready)
    output reg         mem_req,
    output reg  [31:0] mem_addr,
    input  wire        mem_ready,  // rdata valid this cycle
    input  wire [31:0] mem_rdata,
    // result
    output reg         done,       // 1-cycle pulse
    output reg         fault,      // with done
    output reg  [21:0] ppn,        // leaf
    output reg  [ 7:0] flags,
    output reg         mega,
    output wire        busy
);

    wire v = mem_rdata[0];
    wire leaf = mem_rdata[1] || mem_rdata[3];  // R or X
    wire bad = !v || (!mem_rdata[1] && mem_rdata[2]);  // V=0, or W without R

    localparam ST_IDLE = 2'd0;
    localparam ST_L1   = 2'd1;
    localparam ST_L0   = 2'd2;

    reg [ 1:0] state;
    reg [19:0] vpn_q;
    reg [21:0] l0_ppn_q;

    assign busy = (state != ST_IDLE);

    always @* begin
        mem_req  = 1'b0;
        mem_addr = 32'b0;

        case (state)
            ST_L1: begin
                mem_req  = 1'b1;
                mem_addr = {satp_ppn[19:0], vpn_q[19:10], 2'b0};
            end
            ST_L0: begin
                mem_req  = 1'b1;
                mem_addr = {l0_ppn_q[19:0], vpn_q[9:0], 2'b0};
            end
            default: begin
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= ST_IDLE;
            vpn_q    <= 20'b0;
            l0_ppn_q <= 22'b0;
            done     <= 1'b0;
            fault    <= 1'b0;
            ppn      <= 22'b0;
            flags    <= 8'b0;
            mega     <= 1'b0;
        end else begin
            done  <= 1'b0;
            fault <= 1'b0;

            if (abort) state <= ST_IDLE;  // EX instr gone
            else
                case (state)
                    ST_IDLE: begin  // wait for start
                        if (start) begin
                            vpn_q <= vpn;
                            state <= ST_L1;
                        end
                    end

                    ST_L1: begin  // wait for L1 read
                        if (mem_ready) begin  // check for bad PTE, leaf, or go to L0
                            if (bad || (leaf && mem_rdata[19:10] != 10'd0)) begin
                                done  <= 1'b1;
                                fault <= 1'b1;
                                state <= ST_IDLE;
                            end else if (leaf) begin  // 4 MiB page
                                ppn   <= {mem_rdata[31:20], vpn_q[9:0]};
                                flags <= mem_rdata[7:0];
                                mega  <= 1'b1;
                                done  <= 1'b1;
                                state <= ST_IDLE;
                            end else begin  // go to L0
                                l0_ppn_q <= mem_rdata[31:10];
                                state    <= ST_L0;
                            end
                        end
                    end

                    ST_L0: begin
                        if (mem_ready) begin  // check for bad PTE or leaf
                            if (bad || !leaf) begin
                                fault <= 1'b1;
                            end else begin  // leaf PTE
                                ppn   <= mem_rdata[31:10];
                                flags <= mem_rdata[7:0];
                                mega  <= 1'b0;
                            end
                            done  <= 1'b1;
                            state <= ST_IDLE;
                        end
                    end

                    default: state <= ST_IDLE;
                endcase
        end
    end


endmodule
