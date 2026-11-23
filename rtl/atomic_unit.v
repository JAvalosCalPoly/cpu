module atomic_unit (
    input  wire        clk,
    input  wire        rst,
    // from EX
    input  wire        is_lr,      // valid lr.w in EX
    input  wire        is_sc,
    input  wire        is_amo,
    input  wire [ 4:0] funct5,     // which AMO
    input  wire [31:0] pa,         // translated address
    input  wire [31:0] rs2,        // forwarded
    input  wire        go,         // MMU done: !mmu_stall && !mmu_fault
    input  wire        advance,    // EX -> MEM this cycle
    input  wire        clear,      // trap / mret / sret
    // memory
    input  wire [31:0] mem_rdata,  // old value (cycle 2)
    output wire        amo_wr,     // AMO write cycle
    output wire [31:0] amo_wdata,
    output wire        sc_ok,
    // to core
    output wire        busy,       // AMO read cycle: hold EX
    output wire [31:0] result      // sc: 0/1, amo: old
);
    localparam IDLE = 1'b0, WR = 1'b1;

    reg        state;
    reg        resv_valid;
    reg [29:0] resv_addr;

    assign busy   = (state == IDLE) && is_amo && go;
    assign amo_wr = (state == WR);

    assign sc_ok  = is_sc && resv_valid && (resv_addr == pa[31:2]);

    always @(posedge clk) begin
        if (rst || clear) begin
            resv_valid <= 1'b0;
        end else if (advance && is_lr) begin
            resv_valid <= 1'b1;
            resv_addr  <= pa[31:2];
        end else if (advance && is_sc) begin
            resv_valid <= 1'b0;
        end
    end

    function [31:0] amo_op;
        input [31:0] old_value;
        input [31:0] new_value;
        input [4:0] operation;
        reg signed [31:0] old_signed;
        reg signed [31:0] new_signed;
        begin
            old_signed = old_value;
            new_signed = new_value;
            case (operation)
                5'b00000: amo_op = old_value + new_value;  // AMOADD
                5'b00001: amo_op = new_value;  // AMOSWAP
                5'b00100: amo_op = old_value ^ new_value;  // AMOXOR
                5'b01100: amo_op = old_value & new_value;  // AMOAND
                5'b01000: amo_op = old_value | new_value;  // AMOOR
                5'b10000: amo_op = (old_signed < new_signed) ? old_value : new_value;  // AMOMIN
                5'b10100: amo_op = (old_signed > new_signed) ? old_value : new_value;  // AMOMAX
                5'b11000: amo_op = (old_value < new_value) ? old_value : new_value;  // AMOMINU
                5'b11100: amo_op = (old_value > new_value) ? old_value : new_value;  // AMOMAXU
                default:  amo_op = old_value;
            endcase
        end
    endfunction

    assign amo_wdata = amo_op(mem_rdata, rs2, funct5);
    assign result    = is_sc ? (sc_ok ? 32'b0 : 32'b1)
                            : (is_amo ? mem_rdata : 32'b0);

    always @(posedge clk) begin
        if (rst || clear) begin
            state  <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (is_amo && go) state <= WR;
                end
                WR: begin
                    if (advance) begin
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
