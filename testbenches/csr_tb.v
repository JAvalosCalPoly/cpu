`timescale 1ns / 1ps
module csr_tb;
    reg clk;
    reg rst;
    reg [11:0] addr;
    reg [31:0] src;
    wire [31:0] dst;
    reg we;
    reg [1:0] op;
    reg trap, mret;            // trap inputs
    reg [31:0] trap_pc, trap_cause;
    wire [31:0] mtvec_o, mepc_o;

csr dut (
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .src(src),
    .dst(dst),
    .we(we),
    .op(op),
    .trap(trap),
    .trap_pc(trap_pc),
    .trap_cause(trap_cause),
    .mret(mret),
    .mtvec_o(mtvec_o),
    .mepc_o(mepc_o)
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

// value check, no clock
task expect(input [31:0] got, input [31:0] exp, input [8*32-1:0] name);
    begin
        if (got !== exp) begin
            $display("Error: %0s = %h, expected %h", name, got, exp);
            fail = fail + 1;
        end else pass = pass + 1;
    end
endtask

// one trap edge
task do_trap(input [31:0] pc, input [31:0] cause);
    begin
        trap = 1; trap_pc = pc; trap_cause = cause;
        @(posedge clk); #1; trap = 0;
    end
endtask

// one mret edge
task do_mret;
    begin
        mret = 1;
        @(posedge clk); #1; mret = 0;
    end
endtask

initial begin
    clk = 0; rst = 1; addr = 0; src = 0; we = 0; op = 0;
    trap = 0; mret = 0; trap_pc = 0; trap_cause = 0;
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
    // trap / mret
    run(12'h305, 2'b01, 32'h00000101, 1'b1, 32'h00000100, 32'h00000101); // mtvec, mode bit set
    expect(mtvec_o, 32'h00000100, "mtvec_o drops mode");
    run(12'h300, 2'b01, 32'h00000008, 1'b1, 32'h00000088, 32'h00000008); // MIE=1, MPIE=0
    do_trap(32'h00000040, 32'd11);                                        // ecall at 0x40
    addr = 12'h341; #1; expect(dst, 32'h00000040, "mepc after trap");
    expect(mepc_o, 32'h00000040, "mepc_o after trap");
    addr = 12'h342; #1; expect(dst, 32'h0000000B, "mcause after trap");
    addr = 12'h300; #1; expect(dst, 32'h00000080, "mstatus after trap");
    run(12'h341, 2'b01, 32'h00000044, 1'b1, 32'h00000040, 32'h00000044); // handler: mepc += 4
    do_mret;
    addr = 12'h300; #1; expect(dst, 32'h00000088, "mstatus after mret");
    expect(mepc_o, 32'h00000044, "mepc_o after mret");
    we = 1; op = 2'b01; addr = 12'h340; src = 32'h12345678;               // trap beats csr write
    do_trap(32'h00000080, 32'd2);
    we = 0;
    addr = 12'h340; #1; expect(dst, 32'hDEADBEF0, "csr write blocked by trap"); // unchanged
    addr = 12'h342; #1; expect(dst, 32'h00000002, "mcause illegal");
    $display("CSR testbench finished: %0d passed / %0d failed", pass, fail);
    $finish;
end

endmodule