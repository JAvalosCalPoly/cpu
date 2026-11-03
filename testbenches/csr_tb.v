`timescale 1ns / 1ps
module csr_tb;
    reg clk;
    reg rst;
    reg [11:0] addr;
    reg [31:0] src;
    wire [31:0] dst;
    reg we;
    reg [1:0] op;
    reg trap, mret;  // trap inputs
    reg [31:0] trap_pc, trap_cause;
    wire [31:0] trap_vec_o, mepc_o;
    wire [1:0] priv_o;
    wire valid, int_pending;
    reg timer_irq;  // from timer
    wire [31:0] sepc_o;  // sret target, driven by csr

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
        .sret(1'b0),
        .trap_vec_o(trap_vec_o),
        .mepc_o(mepc_o),
        .sepc_o(sepc_o),
        .valid(valid),
        .timer_irq(timer_irq),
        .int_pending(int_pending),
        .priv_o(priv_o)
    );

    always #5 clk = ~clk;  // 10 ns clock

    integer pass, fail;
    task run(input [11:0] a, input [1:0] o, input [31:0] s, input w, input [31:0] exp_old,
             input [31:0] exp_new);
        begin
            addr = a;
            op   = o;
            src  = s;
            we   = w;
            #1;  // settle, before edge
            if (dst != exp_old) begin
                $display("Error: addr=%h, op=%b, src=%h, we=%b, dst=%h, expected old=%h", addr, op,
                         src, w, dst, exp_old);
                fail = fail + 1;
            end else pass = pass + 1;
            @(posedge clk);
            #1;
            we = 0;  // one write
            if (dst != exp_new) begin
                $display("Error: addr=%h, op=%b, src=%h, we=%b, dst=%h, expected new=%h", addr, op,
                         src, w, dst, exp_new);
                fail = fail + 1;
            end else pass = pass + 1;
        end
    endtask

    // value check, no clock
    task check(input [31:0] got, input [31:0] exp, input [8*32-1:0] name);
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
            trap = 1;
            trap_pc = pc;
            trap_cause = cause;
            @(posedge clk);
            #1;
            trap = 0;
        end
    endtask

    // one mret edge
    task do_mret;
        begin
            mret = 1;
            @(posedge clk);
            #1;
            mret = 0;
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        addr = 0;
        src = 0;
        we = 0;
        op = 0;
        trap = 0;
        mret = 0;
        trap_pc = 0;
        trap_cause = 0;
        timer_irq = 0;
        pass = 0;
        fail = 0;
        #12 rst = 0;  // off the clock edge
        // op: 01 W, 10 S, 11 C
        // mstatus: 12:11 MPP, 8 SPP, 7 MPIE, 5 SPIE, 3 MIE, 1 SIE
        run(12'h300, 2'b01, 32'hFFFFFFFF, 1'b1, 32'h00000000,
            32'h000019AA);  // W all ones: MPP=11, S bits set
        run(12'h300, 2'b11, 32'h00000008, 1'b1, 32'h000019AA, 32'h000019A2);  // C bit 3
        run(12'h300, 2'b10, 32'h00000008, 1'b1, 32'h000019A2, 32'h000019AA);  // S bit 3
        // mscratch
        run(12'h340, 2'b01, 32'hDEADBEEF, 1'b1, 32'h00000000, 32'hDEADBEEF);  // W
        run(12'h340, 2'b10, 32'h00000010, 1'b1, 32'hDEADBEEF, 32'hDEADBEFF);  // S bit 4
        run(12'h340, 2'b11, 32'h0000000F, 1'b1, 32'hDEADBEFF, 32'hDEADBEF0);  // C low 4
        run(12'h340, 2'b01, 32'hFFFFFFFF, 1'b0, 32'hDEADBEF0, 32'hDEADBEF0);  // we=0, csrr
        // mepc: [1:0] always 0
        run(12'h341, 2'b01, 32'h12345679, 1'b1, 32'h00000000, 32'h12345678);  // W, low bits drop
        run(12'h341, 2'b11, 32'hFFFFFFFF, 1'b1, 32'h12345678, 32'h00000000);  // C all
        // mtvec, mcause
        run(12'h305, 2'b01, 32'h00000100, 1'b1, 32'h00000000, 32'h00000100);  // W
        run(12'h342, 2'b01, 32'h0000000B, 1'b1, 32'h00000000, 32'h0000000B);  // W
        // unknown addr: reads 0, writes ignored
        run(12'h7C0, 2'b01, 32'hFFFFFFFF, 1'b1, 32'h00000000, 32'h00000000);  // W
        run(12'h7C0, 2'b10, 32'hFFFFFFFF, 1'b1, 32'h00000000, 32'h00000000);  // S
        // trap / mret
        run(12'h305, 2'b01, 32'h00000101, 1'b1, 32'h00000100, 32'h00000101);  // mtvec, mode bit set
        check(trap_vec_o, 32'h00000100, "trap_vec_o drops mode");
        run(12'h300, 2'b01, 32'h00000008, 1'b1, 32'h000019AA, 32'h00000008);  // MIE=1, all else 0
        do_trap(32'h00000040, 32'd11);  // ecall at 0x40
        addr = 12'h341;
        #1;
        check(dst, 32'h00000040, "mepc after trap");
        check(mepc_o, 32'h00000040, "mepc_o after trap");
        addr = 12'h342;
        #1;
        check(dst, 32'h0000000B, "mcause after trap");
        addr = 12'h300;
        #1;
        check(dst, 32'h00001880, "mstatus after trap");  // MPP=11
        run(12'h341, 2'b01, 32'h00000044, 1'b1, 32'h00000040, 32'h00000044);  // handler: mepc += 4
        do_mret;
        addr = 12'h300;
        #1;
        check(dst, 32'h00000088, "mstatus after mret");
        check(mepc_o, 32'h00000044, "mepc_o after mret");
        we   = 1;
        op   = 2'b01;
        addr = 12'h340;
        src  = 32'h12345678;  // trap beats csr write
        do_trap(32'h00000080, 32'd2);
        we   = 0;
        addr = 12'h340;
        #1;
        check(dst, 32'hDEADBEF0, "csr write blocked by trap");  // unchanged
        addr = 12'h342;
        #1;
        check(dst, 32'h00000002, "mcause illegal");
        // mie / mip / int_pending   (last trap left mstatus = 0x1880)
        run(12'h300, 2'b10, 32'h00000008, 1'b1, 32'h00001880, 32'h00001888);  // MIE on
        run(12'h304, 2'b01, 32'hFFFFFFFF, 1'b1, 32'h00000000,
            32'h00000080);  // mie: only MTIE sticks
        check(int_pending, 1'b0, "no irq: int_pending 0");
        timer_irq = 1;
        addr = 12'h344;
        #1;
        check(dst, 32'h00000080, "mip shows MTIP");
        check(int_pending, 1'b1, "MIE+MTIE+MTIP: pending");
        run(12'h344, 2'b11, 32'h00000080, 1'b1, 32'h00000080, 32'h00000080);  // clear mip: ignored
        check(valid, 1'b1, "mip is valid");
        run(12'h300, 2'b11, 32'h00000008, 1'b1, 32'h00001888, 32'h00001880);  // global MIE off
        check(int_pending, 1'b0, "MIE off: not pending");
        run(12'h300, 2'b10, 32'h00000008, 1'b1, 32'h00001880, 32'h00001888);  // MIE back on
        run(12'h304, 2'b11, 32'h00000080, 1'b1, 32'h00000080, 32'h00000000);  // MTIE off
        check(int_pending, 1'b0, "MTIE off: not pending");
        timer_irq = 0;
        addr = 12'h344;
        #1;
        check(dst, 32'h00000000, "mip follows irq");
        addr = 12'h7C0;
        #1;
        check(valid, 1'b0, "0x7C0 not valid");
        // S csrs
        run(12'h100, 2'b01, 32'hFFFFFFFF, 1'b1, 32'h00000000,
            32'h00000122);  // sstatus: S bits only
        addr = 12'h300;
        #1;
        check(dst, 32'h000019AA, "sstatus write kept M bits");
        run(12'h100, 2'b01, 32'h00000000, 1'b1, 32'h00000122, 32'h00000000);  // clear S bits
        addr = 12'h300;
        #1;
        check(dst, 32'h00001888, "mstatus after sstatus clear");
        run(12'h105, 2'b01, 32'h00000200, 1'b1, 32'h00000000, 32'h00000200);  // stvec
        run(12'h140, 2'b01, 32'hCAFEF00D, 1'b1, 32'h00000000, 32'hCAFEF00D);  // sscratch
        run(12'h141, 2'b01, 32'h00000123, 1'b1, 32'h00000000, 32'h00000120);  // sepc, low bits drop
        run(12'h142, 2'b01, 32'h00000008, 1'b1, 32'h00000000, 32'h00000008);  // scause
        run(12'h143, 2'b01, 32'hDEAD0000, 1'b1, 32'h00000000, 32'hDEAD0000);  // stval
        run(12'h302, 2'b01, 32'hFFFFFFFF, 1'b1, 32'h00000000,
            32'hFFFFF7FF);  // medeleg: bit 11 stuck 0
        $display("CSR testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end

endmodule