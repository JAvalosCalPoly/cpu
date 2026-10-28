`timescale 1ns / 1ps
// tests timer.v on its own
module timer_tb;
    reg clk = 0, rst = 1;
    reg [31:0] addr = 0, wdata = 0;
    reg we = 0;
    wire [31:0] rdata;
    wire irq;

timer dut (
    .clk(clk), .rst(rst),
    .addr(addr), .wdata(wdata), .we(we),
    .rdata(rdata), .irq(irq)
);

always #5 clk = ~clk; // 10 ns clock

localparam MTIMECMP_LO = 32'h0200_4000, MTIMECMP_HI = 32'h0200_4004,
           MTIME_LO    = 32'h0200_BFF8, MTIME_HI    = 32'h0200_BFFC;

integer pass = 0, fail = 0;
reg [31:0] a, b;

// value check
task expect(input [31:0] got, input [31:0] exp, input [8*32-1:0] name);
    begin
        if (got !== exp) begin
            $display("FAIL: %0s = %h, expected %h", name, got, exp);
            fail = fail + 1;
        end else begin
            $display("PASS: %0s = %h", name, got);
            pass = pass + 1;
        end
    end
endtask

// load: addr this cycle, data after the edge
task rd(input [31:0] ad, output [31:0] d);
    begin
        addr = ad; we = 0;
        @(posedge clk); #1;
        d = rdata;
    end
endtask

// store: one edge
task wr(input [31:0] ad, input [31:0] d);
    begin
        addr = ad; wdata = d; we = 1;
        @(posedge clk); #1;
        we = 0;
    end
endtask

initial begin
    #12 rst = 0; // off the clock edge

    // 1. mtime counts up 1 per clock
    rd(MTIME_LO, a);
    repeat (5) @(posedge clk); #1;
    rd(MTIME_LO, b);
    expect(b - a, 32'd6, "mtime +6 over 6 clocks");

    // 2. no irq after reset
    expect(irq, 1'b0, "irq off after reset");
    rd(MTIMECMP_HI, a);
    expect(a, 32'hFFFFFFFF, "mtimecmp hi reset");

    // 3. mtimecmp = mtime + 10 -> irq after ~10 clocks
    rd(MTIME_LO, a);           // a = mtime at this edge
    wr(MTIMECMP_HI, 32'd0);
    wr(MTIMECMP_LO, a + 32'd10);
    expect(irq, 1'b0, "irq still off");
    repeat (5) @(posedge clk); #1;
    expect(irq, 1'b0, "irq off before deadline");
    repeat (5) @(posedge clk); #1;
    expect(irq, 1'b1, "irq on at deadline");

    // 4. store wins over tick
    wr(MTIME_LO, 32'h0000_1000);
    rd(MTIME_LO, a);
    expect(a, 32'h0000_1000, "mtime write wins");
    rd(MTIME_LO, a);
    expect(a, 32'h0000_1001, "then counts on");
    expect(irq, 1'b1, "irq on: mtime past mtimecmp");

    // 5. data 1 cycle after addr
    addr = MTIMECMP_HI; #1;
    expect(rdata, 32'h0000_1001, "before edge: old data");
    @(posedge clk); #1;
    expect(rdata, 32'h0000_0000, "after edge: mtimecmp hi");

    // 6. unknown offset
    wr(32'h0200_1234, 32'hDEADBEEF);
    rd(32'h0200_1234, a);
    expect(a, 32'h0, "unknown offset reads 0");
    rd(MTIMECMP_HI, a);
    expect(a, 32'h0, "mtimecmp unchanged");

    $display("timer testbench finished: %0d passed / %0d failed", pass, fail);
    $finish;
end

endmodule