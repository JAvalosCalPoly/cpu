`timescale 1ns / 1ps
module logics_tb;

    reg  [31:0] a;
    reg  [31:0] b;
    reg  [1:0]  op;
    wire [31:0] result;

    logics dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result)
    );

initial begin
$dumpfile("logics.vcd");
$dumpvars(0, logics_tb);

// xor: bits that differ become 1
// F^0=F, F^F=0 per hex digit  ->  FFFF0000 ^ 0F0F0F0F = F0F00F0F
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; op = 2'b00; #10;
if (result !== 32'hF0F0_0F0F) $display("FAIL: FFFF0000 ^ 0F0F0F0F != %h", result);
else $display("PASS: FFFF0000 ^ 0F0F0F0F = %h", result);

// or: any 1 gives 1  ->  FFFF0F0F
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; op = 2'b10; #10;
if (result !== 32'hFFFF_0F0F) $display("FAIL: FFFF0000 | 0F0F0F0F != %h", result);
else $display("PASS: FFFF0000 | 0F0F0F0F = %h", result);

// and: both must be 1  ->  0F0F0000
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; op = 2'b11; #10;
if (result !== 32'h0F0F_0000) $display("FAIL: FFFF0000 & 0F0F0F0F != %h", result);
else $display("PASS: FFFF0000 & 0F0F0F0F = %h", result);

// op 01 is not a logic op: falls to default, must be 0
        a = 32'hFFFF_0000; b = 32'h0F0F_0F0F; op = 2'b01; #10;
if (result !== 32'h0000_0000) $display("FAIL: op 01 (default) != %h", result);
else $display("PASS: op 01 (default) = %h", result);

// x ^ x = 0
        a = 32'h1234_5678; b = 32'h1234_5678; op = 2'b00; #10;
if (result !== 32'h0000_0000) $display("FAIL: x ^ x != %h", result);
else $display("PASS: x ^ x = %h", result);

// xor with all ones = bitwise not (this is how "not" is done in RISC-V: xori rd, rs, -1)
        a = 32'h1234_5678; b = 32'hFFFF_FFFF; op = 2'b00; #10;
if (result !== 32'hEDCB_A987) $display("FAIL: 12345678 ^ FFFFFFFF != %h", result);
else $display("PASS: 12345678 ^ FFFFFFFF = %h (not)", result);

$finish;
end
endmodule