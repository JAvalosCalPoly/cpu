`timescale 1ns / 1ps
// branch unit
module branch_unit (
    input  wire [31:0] a, b,
    input  wire [2:0]  funct3,
    output reg         branch_taken
);
    wire lt, ltu;

    localparam BEQ = 3'b000;
    localparam BNE = 3'b001;
    localparam BLT = 3'b100;
    localparam BGE = 3'b101;
    localparam BLTU = 3'b110;
    localparam BGEU = 3'b111;

    compare u_compare (
        .a   (a),
        .b   (b),
        .lt  (lt),
        .ltu (ltu)
    );

    wire eq = (a == b);

    always @(*) begin
        case (funct3)
            BEQ:  branch_taken = eq;
            BNE:  branch_taken = ~eq;
            BLT:  branch_taken = lt;
            BGE:  branch_taken = ~lt; // a >= b is "not a < b"
            BLTU: branch_taken = ltu;
            BGEU: branch_taken = ~ltu;
            default: branch_taken = 1'b0;
        endcase
    end
endmodule
