`timescale 1ns / 1ps
module tlb_tb;

    reg         clk = 0;
    reg         rst = 1;
    reg  [19:0] vpn = 0;
    wire        hit;
    wire [21:0] ppn;
    wire [ 7:0] flags;
    reg         fill = 0;
    reg  [19:0] fill_vpn = 0;
    reg  [21:0] fill_ppn = 0;
    reg  [ 7:0] fill_flags = 0;
    reg         fill_mega = 0;
    reg         flush = 0;

    tlb #(
        .N(8)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .vpn       (vpn),
        .hit       (hit),
        .ppn       (ppn),
        .flags     (flags),
        .fill      (fill),
        .fill_vpn  (fill_vpn),
        .fill_ppn  (fill_ppn),
        .fill_flags(fill_flags),
        .fill_mega (fill_mega),
        .flush     (flush)
    );

    always #5 clk = ~clk;  // 10 ns clock

    integer pass = 0, fail = 0;
    integer k;

    // write one entry
    task do_fill(input [19:0] v, input [21:0] p, input [7:0] f, input m);
        begin
            fill_vpn   = v;
            fill_ppn   = p;
            fill_flags = f;
            fill_mega  = m;
            fill       = 1;
            @(posedge clk);
            #1;
            fill = 0;
        end
    endtask

    // one sfence.vma
    task do_flush;
        begin
            flush = 1;
            @(posedge clk);
            #1;
            flush = 0;
        end
    endtask

    // lookup, check hit (and ppn/flags on hit)
    task look(input [19:0] v, input exp_hit, input [21:0] exp_ppn, input [7:0] exp_flags,
              input [8*32-1:0] name);
        begin
            vpn = v;
            #1;  // wait for combinational logic to settle
            if (hit !== exp_hit || (exp_hit && (ppn !== exp_ppn || flags !== exp_flags))) begin
                $display("FAIL: %0s: vpn=%h => hit=%b ppn=%h flags=%h, expected hit=%b ppn=%h flags=%h",
                         name, v, hit, ppn, flags, exp_hit, exp_ppn, exp_flags);
                fail = fail + 1;
            end else begin
                $display("PASS: %0s: vpn=%h => hit=%b ppn=%h", name, v, hit, ppn);
                pass = pass + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tlb.vcd");
        $dumpvars(0, tlb_tb);

        #12 rst = 0;  // off the clock edge

        // empty after reset
        look(20'h00401, 0, 0, 0, "miss after reset");
        // 4 KiB page
        do_fill(20'h00401, 22'h00200, 8'hD7, 0);
        look(20'h00401, 1, 22'h00200, 8'hD7, "4K hit");
        look(20'h00402, 0, 0, 0, "4K miss, other vpn[0]");
        // 4 MiB megapage
        do_fill(20'h80000, 22'h80000, 8'hCF, 1);
        look(20'h80000, 1, 22'h80000, 8'hCF, "mega hit");
        look(20'h80123, 1, 22'h80123, 8'hCF, "mega keeps vpn[0]");
        look(20'h80400, 0, 0, 0, "mega miss, other vpn[1]");
        // 7 more fills: slots 2-7, then slot 0 again
        for (k = 0; k < 7; k = k + 1) do_fill(20'h10000 + k, 22'h00100 + k, 8'hCF, 0);
        look(20'h00401, 0, 0, 0, "slot 0 evicted");
        look(20'h80000, 1, 22'h80000, 8'hCF, "slot 1 still there");
        look(20'h10006, 1, 22'h00106, 8'hCF, "newest fill hit");
        // sfence.vma
        do_flush;
        look(20'h80000, 0, 0, 0, "miss after flush (mega)");
        look(20'h10006, 0, 0, 0, "miss after flush (4K)");

        $display("tlb testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end
endmodule