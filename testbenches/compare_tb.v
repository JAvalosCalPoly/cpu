`timescale 1ns / 1ps
module compare_tb;

    reg  [31:0] a;
    reg  [31:0] b;
    wire        lt;
    wire        ltu;

    compare dut (
        .a(a),
        .b(b),
        .lt(lt),
        .ltu(ltu)
    );

initial begin
$dumpfile("compare.vcd");
$dumpvars(0, compare_tb);

// 3 < 5 both ways
        a = 32'd3; b = 32'd5; #10;
if (lt !== 1'b1 || ltu !== 1'b1) $display("FAIL: 3 < 5: lt = %b, ltu = %b", lt, ltu);
else $display("PASS: 3 < 5: lt = %b, ltu = %b", lt, ltu);

// 5 < 3 is false both ways
        a = 32'd5; b = 32'd3; #10;
if (lt !== 1'b0 || ltu !== 1'b0) $display("FAIL: 5 < 3: lt = %b, ltu = %b", lt, ltu);
else $display("PASS: 5 < 3: lt = %b, ltu = %b", lt, ltu);

// equal: "less than" is false both ways
        a = 32'd7; b = 32'd7; #10;
if (lt !== 1'b0 || ltu !== 1'b0) $display("FAIL: 7 < 7: lt = %b, ltu = %b", lt, ltu);
else $display("PASS: 7 < 7: lt = %b, ltu = %b", lt, ltu);

// 80000000 vs 7FFFFFFF: signed it's -2147483648 < 2147483647 (true)
// unsigned it's 2147483648 < 2147483647 (false)
        a = 32'h8000_0000; b = 32'h7FFF_FFFF; #10;
if (lt !== 1'b1 || ltu !== 1'b0) $display("FAIL: 80000000 < 7FFFFFFF: lt = %b, ltu = %b", lt, ltu);
else $display("PASS: 80000000 < 7FFFFFFF: lt = %b, ltu = %b", lt, ltu);

// FFFFFFFF vs 0: signed it's -1 < 0 (true)
// unsigned it's 4294967295 < 0 (false)
        a = 32'hFFFF_FFFF; b = 32'd0; #10;
if (lt !== 1'b1 || ltu !== 1'b0) $display("FAIL: FFFFFFFF < 0: lt = %b, ltu = %b", lt, ltu);
else $display("PASS: FFFFFFFF < 0: lt = %b, ltu = %b", lt, ltu);

// 0 vs FFFFFFFF: the reverse, so the answers flip
        a = 32'd0; b = 32'hFFFF_FFFF; #10;
if (lt !== 1'b0 || ltu !== 1'b1) $display("FAIL: 0 < FFFFFFFF: lt = %b, ltu = %b", lt, ltu);
else $display("PASS: 0 < FFFFFFFF: lt = %b, ltu = %b", lt, ltu);

// two negatives: -5 < -3 (FFFFFFFB < FFFFFFFD), true both ways
        a = 32'hFFFF_FFFB; b = 32'hFFFF_FFFD; #10;
if (lt !== 1'b1 || ltu !== 1'b1) $display("FAIL: -5 < -3: lt = %b, ltu = %b", lt, ltu);
else $display("PASS: -5 < -3: lt = %b, ltu = %b", lt, ltu);

$finish;
end
endmodule