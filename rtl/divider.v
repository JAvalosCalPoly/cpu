module divider (
    input  wire        clk, rst,
    input  wire        start,      // 1 cycle: begin
    input  wire [31:0] a, b,       // dividend, divisor
    input  wire [1:0]  op,         // funct3[1:0]: 00 div, 01 divu, 10 rem, 11 remu
    input wire flush, // because of trap it needs to stop the division process
    output reg         busy,       // working
    output reg         done,       // 1 cycle: result ready
    output reg  [31:0] result
);

reg [31:0] dividend, quotient, mask;
reg [62:0] divisor;
reg is_div, invert;

wire is_signed = ~op[0];
wire a_neg = is_signed & a[31];
wire b_neg = is_signed & b[31]; // signed, 31st bit is sign, 1 & 1 = 1

always @(posedge clk) begin
    done <= 0;
    if (rst) begin
        busy <= 0; // only these matter
    end else if (flush) begin
        busy <= 0;
        done <= 0;
    end else if (start && !busy) begin
        busy <= 1;
        dividend <= a_neg ? -a : a; // (|a|) if negative, take 2's complement
        divisor <= {b_neg ? -b : b, 31'b0}; // {|b|, 31'b0}
        quotient <= 0;
        mask <= 32'h8000_0000; // 1 << 31
        is_div <= ~op[1]; // 1: div, 0: rem
        invert <= ~op[1] ? ((a_neg != b_neg) && (b != 0)) : a_neg;
    end else if (busy) begin
        if (mask != 0) begin
            if (divisor <= {31'b0, dividend}) begin
                dividend <= dividend - divisor[31:0];
                quotient <= quotient | mask;
            end
            mask <= mask >> 1;
            divisor <= divisor >> 1;
        end else begin
            busy <= 0;
            done <= 1;
            result <= is_div ? (invert ? -quotient : quotient) : (invert ? -dividend : dividend); // quotient for div and dividend for rem, invert if needed
        end
    end
end


endmodule