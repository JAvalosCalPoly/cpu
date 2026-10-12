`timescale 1ns / 1ps
module addersub_tb;

    reg [31:0] a;
    reg [31:0] b;
    reg        sub;
    wire [31:0] sum;
    wire        cout;

    addersub dut (
        .a(a),
        .b(b),
        .sub(sub),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        $dumpfile("addersub.vcd");
        $dumpvars(0, addersub_tb);

        // Test add
        a = 32'd10; b = 32'd5; sub = 1'b0; #10;
        if (sum !== 32'd15) $display("FAIL: 10 + 5 != %d", sum);
        else $display("PASS: 10 + 5 = %d", sum);

        // Test sub
        a = 32'd10; b = 32'd5; sub = 1'b1; #10;
        if (sum !== 32'd5) $display("FAIL: 10 - 5 != %d", sum);
        else $display("PASS: 10 - 5 = %d", sum);

        // Test sub with negative result
        a = 32'd5; b = 32'd10; sub = 1'b1; #10;
        if (sum !== 32'hFFFF_FFFB) $display("FAIL: 5 - 10 != %h", sum);
        else $display("PASS: 5 - 10 = %h (-5)", sum);

        // add wraps around, carry out = 1
        a = 32'hFFFF_FFFF; b = 32'd1; sub = 1'b0; #10;
        if (sum !== 32'd0 || cout !== 1'b1) $display("FAIL: FFFFFFFF + 1 != %h, cout = %b", sum, cout);
        else $display("PASS: FFFFFFFF + 1 = %h, cout = %b", sum, cout);

        // signed overflow: biggest positive + 1 becomes most negative
        a = 32'h7FFF_FFFF; b = 32'd1; sub = 1'b0; #10;
        if (sum !== 32'h8000_0000) $display("FAIL: 7FFFFFFF + 1 != %h", sum);
        else $display("PASS: 7FFFFFFF + 1 = %h", sum);

        // signed underflow: most negative - 1 becomes biggest positive
        a = 32'h8000_0000; b = 32'd1; sub = 1'b1; #10;
        if (sum !== 32'h7FFF_FFFF) $display("FAIL: 80000000 - 1 != %h", sum);
        else $display("PASS: 80000000 - 1 = %h", sum);

        // 0 - 0: no borrow, so cout = 1
        a = 32'd0; b = 32'd0; sub = 1'b1; #10;
        if (sum !== 32'd0 || cout !== 1'b1) $display("FAIL: 0 - 0 != %h, cout = %b", sum, cout);
        else $display("PASS: 0 - 0 = %h, cout = %b", sum, cout);

        // 0 - 1: borrow, so cout = 0
        a = 32'd0; b = 32'd1; sub = 1'b1; #10;
        if (sum !== 32'hFFFF_FFFF || cout !== 1'b0) $display("FAIL: 0 - 1 != %h, cout = %b", sum, cout);
        else $display("PASS: 0 - 1 = %h, cout = %b", sum, cout);

        $finish;
    end
endmodule