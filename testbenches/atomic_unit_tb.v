`timescale 1ns / 1ps
module atomic_unit_tb;
    reg clk, rst;
    reg is_lr, is_sc, is_amo;
    reg [4:0] funct5;
    reg [31:0] pa, rs2;
    reg go, clear;
    reg hold;  // force EX to stay
    reg [31:0] mem_rdata;

    wire amo_wr;
    wire [31:0] amo_wdata;
    wire sc_ok;
    wire busy;
    wire [31:0] result;

    wire advance = !busy && !hold;

    integer pass = 0, fail = 0;

    atomic_unit dut (
        .clk(clk),
        .rst(rst),
        .is_lr(is_lr),
        .is_sc(is_sc),
        .is_amo(is_amo),
        .funct5(funct5),
        .pa(pa),
        .rs2(rs2),
        .go(go),
        .advance(advance),
        .clear(clear),
        .mem_rdata(mem_rdata),
        .amo_wr(amo_wr),
        .amo_wdata(amo_wdata),
        .sc_ok(sc_ok),
        .busy(busy),
        .result(result)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // fake BRAM: sync read, read-first
    reg [31:0] mem[0:1023];

    always @(posedge clk) begin
        if (amo_wr) begin
            mem[pa[11:2]] <= amo_wdata;
        end
        mem_rdata <= mem[pa[11:2]];
    end
    integer i;

    initial begin
        $dumpfile("build/atomic_unit.vcd");
        $dumpvars(0, atomic_unit_tb);
        for (i = 0; i < 16; i = i + 1) $dumpvars(0, mem[i]);

        rst = 1;
        is_lr = 0;
        is_sc = 0;
        is_amo = 0;
        funct5 = 0;
        pa = 0;
        rs2 = 0;
        go = 0;
        clear = 0;
        hold = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // amoadd: mem 12 + 7 -> 19, rd gets 12
        mem[4] = 32'd12;
        is_amo = 1;
        funct5 = 5'b00000;
        pa = 32'h10;
        rs2 = 32'd7;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amoadd read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoadd read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'd12) begin
            $display("FAIL: amoadd write busy = %b amo_wr = %b result = %0d", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amoadd write busy = %b amo_wr = %b result = %0d", busy, amo_wr, result);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[4] !== 32'd19 || amo_wr !== 0) begin
            $display("FAIL: amoadd mem   mem[4] = %0d amo_wr = %b", mem[4], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoadd mem   mem[4] = %0d", mem[4]);
            pass = pass + 1;
        end

        // amoswap: mem 12 <- 7, rd gets 12
        mem[1] = 32'd12;
        is_amo = 1;
        funct5 = 5'b00001;
        pa = 32'h4;
        rs2 = 32'd7;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amoswap read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoswap read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'd12) begin
            $display("FAIL: amoswap write busy = %b amo_wr = %b result = %0d", busy, amo_wr,
                     result);
            fail = fail + 1;
        end else begin
            $display("PASS: amoswap write busy = %b amo_wr = %b result = %0d", busy, amo_wr,
                     result);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[1] !== 32'd7 || amo_wr !== 0) begin
            $display("FAIL: amoswap mem   mem[1] = %0d amo_wr = %b", mem[1], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoswap mem   mem[1] = %0d", mem[1]);
            pass = pass + 1;
        end

        // amomin: signed min(5, -1) = -1, rd gets 5
        mem[2] = 32'd5;
        is_amo = 1;
        funct5 = 5'b10000;
        pa = 32'h8;
        rs2 = 32'hFFFF_FFFF;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amomin read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amomin read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'd5) begin
            $display("FAIL: amomin write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amomin write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[2] !== 32'hFFFF_FFFF || amo_wr !== 0) begin
            $display("FAIL: amomin mem   mem[2] = %h amo_wr = %b", mem[2], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amomin mem   mem[2] = %h", mem[2]);
            pass = pass + 1;
        end

        // amominu: unsigned min(0xffffffff, 5) = 5
        mem[3] = 32'hFFFF_FFFF;
        is_amo = 1;
        funct5 = 5'b11000;
        pa = 32'hC;
        rs2 = 32'd5;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amominu read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amominu read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'hFFFF_FFFF) begin
            $display("FAIL: amominu write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amominu write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[3] !== 32'd5 || amo_wr !== 0) begin
            $display("FAIL: amominu mem   mem[3] = %0d amo_wr = %b", mem[3], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amominu mem   mem[3] = %0d", mem[3]);
            pass = pass + 1;
        end

        // amomax: signed max(-1, 5) = 5, rd gets -1
        mem[5] = 32'hFFFF_FFFF;
        is_amo = 1;
        funct5 = 5'b10100;
        pa = 32'h14;
        rs2 = 32'd5;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amomax read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amomax read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'hFFFF_FFFF) begin
            $display("FAIL: amomax write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amomax write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[5] !== 32'd5 || amo_wr !== 0) begin
            $display("FAIL: amomax mem   mem[5] = %0d amo_wr = %b", mem[5], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amomax mem   mem[5] = %0d", mem[5]);
            pass = pass + 1;
        end

        // amomaxu: unsigned max(5, 0xffffffff) = 0xffffffff, rd gets 5
        mem[6] = 32'd5;
        is_amo = 1;
        funct5 = 5'b11100;
        pa = 32'h18;
        rs2 = 32'hFFFF_FFFF;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amomaxu read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amomaxu read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'd5) begin
            $display("FAIL: amomaxu write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amomaxu write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            pass = pass + 1;
        end

        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[6] !== 32'hFFFF_FFFF || amo_wr !== 0) begin
            $display("FAIL: amomaxu mem   mem[6] = %h amo_wr = %b", mem[6], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amomaxu mem   mem[6] = %h", mem[6]);
            pass = pass + 1;
        end

        // Test 5: amoand, amoor and amoxor with old value 0xc and rs2 0xa.
        mem[7] = 32'hC;
        is_amo = 1;
        funct5 = 5'b01100;
        pa = 32'h1C;
        rs2 = 32'hA;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amoand read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoand read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'hC) begin
            $display("FAIL: amoand write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amoand write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[7] !== 32'h8 || amo_wr !== 0) begin
            $display("FAIL: amoand mem   mem[7] = %h amo_wr = %b", mem[7], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoand mem   mem[7] = %h", mem[7]);
            pass = pass + 1;
        end

        mem[8] = 32'hC;
        is_amo = 1;
        funct5 = 5'b01000;
        pa = 32'h20;
        rs2 = 32'hA;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amoor read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoor read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'hC) begin
            $display("FAIL: amoor write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amoor write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[8] !== 32'hE || amo_wr !== 0) begin
            $display("FAIL: amoor mem   mem[8] = %h amo_wr = %b", mem[8], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoor mem   mem[8] = %h", mem[8]);
            pass = pass + 1;
        end

        mem[9] = 32'hC;
        is_amo = 1;
        funct5 = 5'b00100;
        pa = 32'h24;
        rs2 = 32'hA;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amoxor read  busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoxor read  busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'hC) begin
            $display("FAIL: amoxor write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            fail = fail + 1;
        end else begin
            $display("PASS: amoxor write busy = %b amo_wr = %b result = %h", busy, amo_wr, result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[9] !== 32'h6 || amo_wr !== 0) begin
            $display("FAIL: amoxor mem   mem[9] = %h amo_wr = %b", mem[9], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amoxor mem   mem[9] = %h", mem[9]);
            pass = pass + 1;
        end

        // Test 6: LR at 0x40 followed by a successful SC at 0x40.
        is_lr = 1;
        pa = 32'h40;
        #1;
        if (busy !== 0) begin
            $display("FAIL: lr 0x40 busy = %b", busy);
            fail = fail + 1;
        end else begin
            $display("PASS: lr 0x40 busy = %b", busy);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_lr = 0;

        is_sc = 1;
        pa = 32'h40;
        #1;
        if (busy !== 0 || sc_ok !== 1 || result !== 32'd0) begin
            $display("FAIL: sc 0x40 success busy = %b sc_ok = %b result = %h", busy, sc_ok, result);
            fail = fail + 1;
        end else begin
            $display("PASS: sc 0x40 success busy = %b sc_ok = %b result = %h", busy, sc_ok, result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_sc = 0;

        // Test 7: the reservation was consumed by the previous SC.
        is_sc = 1;
        pa = 32'h40;
        #1;
        if (busy !== 0 || sc_ok !== 0 || result !== 32'd1) begin
            $display("FAIL: sc 0x40 reused busy = %b sc_ok = %b result = %h", busy, sc_ok, result);
            fail = fail + 1;
        end else begin
            $display("PASS: sc 0x40 reused busy = %b sc_ok = %b result = %h", busy, sc_ok, result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_sc = 0;

        // Test 8: an SC to a different word fails and consumes the reservation.
        is_lr = 1;
        pa = 32'h40;
        #1;
        if (busy !== 0) begin
            $display("FAIL: lr 0x40 before test 8 busy = %b", busy);
            fail = fail + 1;
        end else begin
            $display("PASS: lr 0x40 before test 8 busy = %b", busy);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_lr = 0;

        is_sc = 1;
        pa = 32'h44;
        #1;
        if (busy !== 0 || sc_ok !== 0 || result !== 32'd1) begin
            $display("FAIL: sc 0x44 different word busy = %b sc_ok = %b result = %h", busy, sc_ok,
                     result);
            fail = fail + 1;
        end else begin
            $display("PASS: sc 0x44 different word busy = %b sc_ok = %b result = %h", busy, sc_ok,
                     result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_sc = 0;

        // Test 9: clear the reservation between LR and SC.
        is_lr = 1;
        pa = 32'h40;
        #1;
        if (busy !== 0) begin
            $display("FAIL: lr 0x40 before clear busy = %b", busy);
            fail = fail + 1;
        end else begin
            $display("PASS: lr 0x40 before clear busy = %b", busy);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_lr = 0;
        clear = 1;
        @(posedge clk);
        #1;
        clear = 0;

        is_sc = 1;
        pa = 32'h40;
        #1;
        if (busy !== 0 || sc_ok !== 0 || result !== 32'd1) begin
            $display("FAIL: sc 0x40 after clear busy = %b sc_ok = %b result = %h", busy, sc_ok,
                     result);
            fail = fail + 1;
        end else begin
            $display("PASS: sc 0x40 after clear busy = %b sc_ok = %b result = %h", busy, sc_ok,
                     result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_sc = 0;

        // Test 10: an AMO waits while the MMU is still walking.
        mem[10] = 32'd21;
        is_amo = 1;
        funct5 = 5'b00000;
        pa = 32'h28;
        rs2 = 32'd9;
        go = 0;
        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 0 || mem[10] !== 32'd21) begin
            $display("FAIL: amo stalled edge 1 busy = %b amo_wr = %b mem[10] = %0d", busy, amo_wr,
                     mem[10]);
            fail = fail + 1;
        end else begin
            $display("PASS: amo stalled edge 1 busy = %b amo_wr = %b mem[10] = %0d", busy, amo_wr,
                     mem[10]);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 0 || mem[10] !== 32'd21) begin
            $display("FAIL: amo stalled edge 2 busy = %b amo_wr = %b mem[10] = %0d", busy, amo_wr,
                     mem[10]);
            fail = fail + 1;
        end else begin
            $display("PASS: amo stalled edge 2 busy = %b amo_wr = %b mem[10] = %0d", busy, amo_wr,
                     mem[10]);
            pass = pass + 1;
        end

        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amo after go read busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amo after go read busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'd21) begin
            $display("FAIL: amo after go write busy = %b amo_wr = %b result = %0d", busy, amo_wr,
                     result);
            fail = fail + 1;
        end else begin
            $display("PASS: amo after go write busy = %b amo_wr = %b result = %0d", busy, amo_wr,
                     result);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        is_amo = 0;
        if (mem[10] !== 32'd30 || amo_wr !== 0) begin
            $display("FAIL: amo after go mem[10] = %0d amo_wr = %b", mem[10], amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amo after go mem[10] = %0d", mem[10]);
            pass = pass + 1;
        end

        // Test 11: clear in the write cycle while EX is held restarts it.
        mem[11] = 32'd31;
        is_amo = 1;
        funct5 = 5'b00000;
        pa = 32'h2C;
        rs2 = 32'd1;
        go = 1;
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amo clear read busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amo clear read busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end
        @(posedge clk);
        #1;
        if (busy !== 0 || amo_wr !== 1 || result !== 32'd31) begin
            $display("FAIL: amo clear write busy = %b amo_wr = %b result = %0d", busy, amo_wr,
                     result);
            fail = fail + 1;
        end else begin
            $display("PASS: amo clear write busy = %b amo_wr = %b result = %0d", busy, amo_wr,
                     result);
            pass = pass + 1;
        end
        // EX held: only clear can leave WR
        clear = 1;
        hold  = 1;
        @(posedge clk);
        #1;
        if (busy !== 1 || amo_wr !== 0) begin
            $display("FAIL: amo clear restart busy = %b amo_wr = %b", busy, amo_wr);
            fail = fail + 1;
        end else begin
            $display("PASS: amo clear restart busy = %b amo_wr = %b", busy, amo_wr);
            pass = pass + 1;
        end
        clear  = 0;
        hold   = 0;
        is_amo = 0;

        $display("atomic_unit testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end

endmodule
