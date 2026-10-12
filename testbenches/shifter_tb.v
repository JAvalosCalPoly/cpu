`timescale 1ns / 1ps
module shifter_tb;

    reg  [31:0] a;
    reg  [4:0]  shamt;
    reg  [1:0]  shift_op;
    wire [31:0] result;

    shifter dut (
        .a(a),
        .shamt(shamt),
        .shift_op(shift_op),
        .result(result)
    );

initial begin
$dumpfile("shifter.vcd");
$dumpvars(0, shifter_tb);

// sll (00): zeros come in from the right
// 1 << 4 = 16
        a = 32'd1; shamt = 5'd4; shift_op = 2'b00; #10;
if (result !== 32'd16) $display("FAIL: 1 << 4 != %d", result);
else $display("PASS: 1 << 4 = %d", result);

// shift by 0 must leave the value alone
        a = 32'h1234_5678; shamt = 5'd0; shift_op = 2'b00; #10;
if (result !== 32'h1234_5678) $display("FAIL: 12345678 << 0 != %h", result);
else $display("PASS: 12345678 << 0 = %h", result);

// shift by 31 (the max): only bit 0 survives, moved to bit 31
        a = 32'hFFFF_FFFF; shamt = 5'd31; shift_op = 2'b00; #10;
if (result !== 32'h8000_0000) $display("FAIL: FFFFFFFF << 31 != %h", result);
else $display("PASS: FFFFFFFF << 31 = %h", result);

// srl (01): zeros come in from the left
// 16 >> 4 = 1
        a = 32'd16; shamt = 5'd4; shift_op = 2'b01; #10;
if (result !== 32'd1) $display("FAIL: 16 >> 4 != %d", result);
else $display("PASS: 16 >> 4 = %d", result);

// negative number, logical shift: top bits fill with 0
        a = 32'h8000_0000; shamt = 5'd4; shift_op = 2'b01; #10;
if (result !== 32'h0800_0000) $display("FAIL: 80000000 >> 4 != %h", result);
else $display("PASS: 80000000 >> 4 = %h", result);

// shift by 31: only the top bit survives, moved to bit 0
        a = 32'hFFFF_FFFF; shamt = 5'd31; shift_op = 2'b01; #10;
if (result !== 32'h0000_0001) $display("FAIL: FFFFFFFF >> 31 != %h", result);
else $display("PASS: FFFFFFFF >> 31 = %h", result);

// sra (11): copies of the sign bit come in from the left
// negative number: top bits fill with 1  (this is the case that proves it's arithmetic)
        a = 32'h8000_0000; shamt = 5'd4; shift_op = 2'b11; #10;
if (result !== 32'hF800_0000) $display("FAIL: 80000000 >>> 4 != %h", result);
else $display("PASS: 80000000 >>> 4 = %h", result);

// -16 >>> 2 = -4  (sra is divide by 2^n for negatives, rounding toward -infinity)
        a = 32'hFFFF_FFF0; shamt = 5'd2; shift_op = 2'b11; #10;
if (result !== 32'hFFFF_FFFC) $display("FAIL: -16 >>> 2 != %h", result);
else $display("PASS: -16 >>> 2 = %h (-4)", result);

// positive number: sra behaves exactly like srl
        a = 32'h7000_0000; shamt = 5'd4; shift_op = 2'b11; #10;
if (result !== 32'h0700_0000) $display("FAIL: 70000000 >>> 4 != %h", result);
else $display("PASS: 70000000 >>> 4 = %h", result);

// shift by 31: a negative number becomes all ones (-1)
        a = 32'h8000_0000; shamt = 5'd31; shift_op = 2'b11; #10;
if (result !== 32'hFFFF_FFFF) $display("FAIL: 80000000 >>> 31 != %h", result);
else $display("PASS: 80000000 >>> 31 = %h", result);

// 10 is not a shift: default, must be 0
        a = 32'h1234_5678; shamt = 5'd4; shift_op = 2'b10; #10;
if (result !== 32'h0000_0000) $display("FAIL: shift_op 10 (default) != %h", result);
else $display("PASS: shift_op 10 (default) = %h", result);

$finish;
end
endmodule