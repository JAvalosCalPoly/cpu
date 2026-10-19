`timescale 1ns / 1ps
module csr_tb;
    reg clk;
    reg rst;
    reg [11:0] addr;
    reg [31:0] src;
    wire [31:0] dst;
    reg we;
    reg [1:0] op;

csr dut (
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .src(src),
    .dst(dst),
    .we(we),
    .op(op)
);

always #5 clk = ~clk; // 10 ns clock

integer pass, fail;
task run(input [11:0] a, input [1:0] o, input [31:0] s, input w,
         input [31:0] exp_old, input [31:0] exp_new);
    begin
        addr = a; op = o; src = s; we = w;
        #1; // settle, before edge
        if (dst != exp_old) begin
            $display("Error: addr=%h, op=%b, src=%h, we=%b, dst=%h, expected old=%h", addr, op, src, w, dst, exp_old);
            fail = fail + 1;
        end else pass = pass + 1;
        @(posedge clk); #1; we = 0; // one write
        if (dst != exp_new) begin
            $display("Error: addr=%h, op=%b, src=%h, we=%b, dst=%h, expected new=%h", addr, op, src, w, dst, exp_new);
            fail = fail + 1;
        end else pass = pass + 1;
    end
endtask

initial begin
    clk = 0; rst = 1; addr = 0; src = 0; we = 0; op = 0;
    pass = 0; fail = 0;
    #12 rst = 0; // off the clock edge
    // op: 01 W, 10 S, 11 C
    // mstatus: only bits 7, 3
    run(12'h300, 2'b01, 32'hFFFFFFFF, 1'b1, 32'h00000000, 32'h00000088); // W all ones
    run(12'h300, 2'b11, 32'h00000008, 1'b1, 32'h00000088, 32'h00000080); // C bit 3
    run(12'h300, 2'b10, 32'h00000008, 1'b1, 32'h00000080, 32'h00000088); // S bit 3
    // mscratch
    run(12'h340, 2'b01, 32'hDEADBEEF, 1'b1, 32'h00000000, 32'hDEADBEEF); // W
    run(12'h340, 2'b10, 32'h00000010, 1'b1, 32'hDEADBEEF, 32'hDEADBEFF); // S bit 4
    run(12'h340, 2'b11, 32'h0000000F, 1'b1, 32'hDEADBEFF, 32'hDEADBEF0); // C low 4
    run(12'h340, 2'b01, 32'hFFFFFFFF, 1'b0, 32'hDEADBEF0, 32'hDEADBEF0); // we=0, csrr
    // mepc: [1:0] always 0
    run(12'h341, 2'b01, 32'h12345679, 1'b1, 32'h00000000, 32'h12345678); // W, low bits drop
    run(12'h341, 2'b11, 32'hFFFFFFFF, 1'b1, 32'h12345678, 32'h00000000); // C all
    // mtvec, mcause
    run(12'h305, 2'b01, 32'h00000100, 1'b1, 32'h00000000, 32'h00000100); // W
    run(12'h342, 2'b01, 32'h0000000B, 1'b1, 32'h00000000, 32'h0000000B); // W
    // unknown addr: reads 0, writes ignored
    run(12'h7C0, 2'b01, 32'hFFFFFFFF, 1'b1, 32'h00000000, 32'h00000000); // W
    run(12'h7C0, 2'b10, 32'hFFFFFFFF, 1'b1, 32'h00000000, 32'h00000000); // S
    $display("CSR testbench finished: %0d passed / %0d failed", pass, fail);
    $finish;
end

endmodule