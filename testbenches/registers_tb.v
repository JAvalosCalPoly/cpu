`timescale 1ns / 1ps

module registers_tb;

reg clk = 0;
reg we = 0, reset = 0;
reg [4:0] rs1 = 0, rs2 = 0, rd = 0;
reg [31:0] wd = 0;
wire [31:0] rd1, rd2;       // driven by the module's outputs, so wire

reg32 dut(
    .clk(clk),
    .we(we),
    .reset(reset),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .wd(wd),
    .rd1(rd1),
    .rd2(rd2)
);

always #5 clk = ~clk;

// Pattern for every test:
//   change inputs on the falling edge,
//   let the write happen on the rising edge,
//   check 1 ns after the rising edge.

initial begin
    $dumpfile("registers.vcd");
    $dumpvars(0, registers_tb);

    // reset all
    @(negedge clk); reset = 1;
    @(negedge clk); reset = 0;
    rs1 = 5; rs2 = 31;
    #1;
    if (rd1 !== 0 || rd2 !== 0) $display("Error: reset failed");
    else $display("Reset passed");

    // write and read from both ports
    @(negedge clk);
    we = 1; rd = 5; wd = 32'hbeefbeef;
    rs1 = 5; rs2 = 5;
    @(posedge clk); #1;
    if (rd1 !== 32'hbeefbeef || rd2 !== 32'hbeefbeef) $display("Error: write/read failed");
    else $display("Write/read passed");

    // ignore x0 writes
    @(negedge clk);
    we = 1; rd = 0; wd = 32'hbeefbeef;
    rs1 = 0; rs2 = 0;
    @(posedge clk); #1;
    if (rd1 !== 0 || rd2 !== 0) $display("Error: x0 write failed");
    else $display("x0 write passed");

    // no write when we=0 (use a different value than x5 already holds)
    @(negedge clk);
    we = 0; rd = 5; wd = 32'h12345678;
    rs1 = 5; rs2 = 5;
    @(posedge clk); #1;
    if (rd1 !== 32'hbeefbeef || rd2 !== 32'hbeefbeef) $display("Error: write when we=0 failed");
    else $display("Write when we=0 passed");

    // the ports can read different registers
    @(negedge clk);
    we = 1; rd = 10; wd = 32'hffffffff;
    rs1 = 5; rs2 = 10;
    @(posedge clk); #1;
    if (rd1 !== 32'hbeefbeef || rd2 !== 32'hffffffff) $display("Error: read different registers failed");
    else $display("Read different registers passed");

    // old value is present until next clock edge
    @(negedge clk);
    we = 1; rd = 5; wd = 32'h00000000;
    rs1 = 5;
    #1;
    if (rd1 !== 32'hbeefbeef) $display("Error: old value not held before clock edge");
    else $display("Old value held before clock edge passed");
    @(posedge clk); #1;
    if (rd1 !== 32'h00000000) $display("Error: new value not present after clock edge");
    else $display("New value present after clock edge passed");

    // highest register is 31
    @(negedge clk);
    we = 1; rd = 31; wd = 32'haaaaaaaa;
    rs1 = 31;
    @(posedge clk); #1;
    if (rd1 !== 32'haaaaaaaa) $display("Error: highest register is 31");
    else $display("Highest register is 31 passed");

    @(negedge clk); we = 0;
    $finish;
end

endmodule