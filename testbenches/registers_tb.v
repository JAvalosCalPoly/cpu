`timescale 1ns / 1ps

module registers_tb(

    );
reg clk = 0;
reg we = 0, reset = 0;
reg[4:0] rs1 = 0, rs2 = 0, rd = 0;
reg[31:0] wd = 0;
reg[31:0] rd1, rd2;

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

initial begin
    // reset all
    @(posedge clk) reset = 1;
    @(posedge clk) reset = 0;
    rs1 = 5; rs2 = 31;
    #1;
    if (rd1 !== 0 || rd2 !== 0) $display("Error: reset failed");
    else $display("Reset passed");
    
    // write and read from both ports
    @(posedge clk) we = 1; rd = 5; wd = 32'hbeefbeef;
    rs1 = 5; rs2 = 5;
    #1;
    if (rd1 !== 32'hbeefbeef || rd2 !== 32'hbeefbeef) $display("Error: write/read failed");
    else $display("Write/read passed");

    // ignore x0 writes
    @(posedge clk) we = 1; rd = 0; wd = 32'hbeefbeef;
    rs1 = 0; rs2 = 0;
    #1;
    if (rd1 !== 0 || rd2 !== 0) $display("Error: x0 write failed");
    else $display("x0 write passed");

    // no write when we=0
    @(posedge clk) we = 0; rd = 5; wd = 32'hbeefbeef;
    rs1 = 5; rs2 = 5;
    #1;
    if (rd1 !== 32'hbeefbeef || rd2 !== 32'hbeefbeef) $display("Error: write when we=0 failed");
    else $display("Write when we=0 passed");

    // the ports can read different registers
    @(posedge clk) we = 1; rd = 10; wd = 32'hffffffff;
    rs1 = 5; rs2 = 10;
    #1;
    if (rd1 !== 32'hbeefbeef || rd2 !== 32'hffffffff) $display("Error: read different registers failed");
    else $display("Read different registers passed");

    // old value is present until next clock edge
    @(negedge clk) we = 1; rd = 5; wd = 32'00000000;
    rs1 = 5;
    #1;
    $display("rd1=%h before clock edge", rd1);
    @(posedge clk) #1;
    if (rd1 !== 32'h00000000) $display("Error: old value present until next clock edge failed");
    else $display("Old value present until next clock edge passed");

    // highest register is 31
    @(posedge clk) we = 1; rd = 31; wd = 32'haaaaaaaa;
    rs1 = 31;
    #1;
    if (rd1 !== 32'haaaaaaaa) $display("Error: highest register is 31");
    else $display("Highest register is 31 passed");
end

endmodule