`timescale 1ns / 1ps
module divider_tb;

reg clk, rst, start;
reg [31:0] a, b;
reg [1:0] op;
wire busy, done;
wire [31:0] result;

divider uut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .a(a),
    .b(b),
    .op(op),
    .busy(busy),
    .done(done),
    .result(result)
);

wire [31:0] expected;
integer cycle_count;
integer errors = 0;
integer i;

multdiv test (
    .a(a),
    .b(b),
    .funct3({1'b1, op}), // 1xx = div ops
    .result(expected)
);

task run(input [31:0] dividend, input [31:0] divisor, input [1:0] operation); begin
    @(posedge clk);
        a <= dividend;
        b <= divisor;
        op <= operation;
        start <= 1;
        cycle_count = 0;
    @(posedge clk);
        start <= 0;
    // count cycles until done
    while (!done) begin
    @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        if (result !== expected) begin
                    errors = errors + 1;
            $display("FAIL: op=%b a=%h b=%h got %h expected %h", operation, dividend, divisor, result, expected);
        end
    $display("cycles: %0d", cycle_count);
end
endtask

initial begin
    clk = 0;
end
always #5 clk = ~clk;

initial begin
    rst = 1;
    start = 0;
    #10;
    rst = 0;
    // tests
    // x / 0 for all 4 (-7/0)
    run(32'hFFFF_FFF9, 32'h0000_0000, 2'b00); // div
    run(32'hFFFF_FFF9, 32'h0000_0000, 2'b01); // divu
    run(32'hFFFF_FFF9, 32'h0000_0000, 2'b10); // rem
    run(32'hFFFF_FFF9, 32'h0000_0000, 2'b11); // remu
    // 0x8000_0000 / -1 for div and rem
    run(32'h8000_0000, 32'hFFFF_FFFF, 2'b00); // div
    run(32'h8000_0000, 32'hFFFF_FFFF, 2'b10); // rem
    // -20 / 6, 20 / 6, -20 / -6, 20 / -6
    run(32'hFFFF_FFEC, 32'h0000_0006, 2'b00); // div
    run(32'h0000_0014, 32'h0000_0006, 2'b00); // div
    run(32'hFFFF_FFEC, 32'hFFFF_FFFA, 2'b00); // div
    run(32'h0000_0014, 32'hFFFF_FFFA, 2'b00); // div
    // 0 / 5
    run(32'h0000_0000, 32'h0000_0005, 2'b00); // div
    // 5 / 5
    run(32'h0000_0005, 32'h0000_0005, 2'b00); // div
    // random
    for (i = 0; i < 1000; i = i + 1) begin
        run($random, $random, $random & 3);
    end
    if (errors == 0) begin
        $display("All tests passed!");
    end else begin
        $display("%0d tests failed.", errors);
    end
    $finish;
end

endmodule