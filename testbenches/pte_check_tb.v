module pte_check_tb;

    reg  [1:0] priv;
    reg  [1:0] acc;
    reg        sum;
    reg        mxr;
    reg  [7:0] flags;
    wire       fault;

    pte_check dut (
        .priv (priv),
        .acc  (acc),
        .sum  (sum),
        .mxr  (mxr),
        .flags(flags),
        .fault(fault)
    );
    integer pass = 0, fail = 0;

    task row(input [1:0] p, input [1:0] a, input s, input m, input [7:0] f, input exp,
             input [8*32-1:0] name);
        begin
            priv  = p;
            acc   = a;
            sum   = s;
            mxr   = m;
            flags = f;
            #1;  // wait for combinational logic to settle
            if (fault !== exp) begin
                $display(
                    "FAIL: %0s: priv=%b acc=%b sum=%b mxr=%b flags=%b => fault=%b, expected %b",
                    name, p, a, s, m, f, fault, exp);
                fail = fail + 1;
            end else begin
                $display("PASS: %0s: priv=%b acc=%b sum=%b mxr=%b flags=%b => fault=%b", name, p,
                         a, s, m, f, fault);
                pass = pass + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("pte_check.vcd");
        $dumpvars(0, pte_check_tb);

        // kernel RWX page (D A X W R V)
        row(2'b01, 2'b01, 0, 0, 8'hCF, 0, "S load kernel page");
        row(2'b01, 2'b10, 0, 0, 8'hCF, 0, "S store kernel page");
        row(2'b01, 2'b00, 0, 0, 8'hCF, 0, "S fetch kernel page");
        row(2'b00, 2'b01, 0, 0, 8'hCF, 1, "U load kernel page");
        // user R-X page (D A U X R V)
        row(2'b00, 2'b01, 0, 0, 8'hDB, 0, "U load user RX");
        row(2'b00, 2'b10, 0, 0, 8'hDB, 1, "U store user RX (no W)");
        row(2'b00, 2'b00, 0, 0, 8'hDB, 0, "U fetch user RX");
        // SUM: S access to user pages (D A U W R V)
        row(2'b01, 2'b01, 0, 0, 8'hD7, 1, "S load user, SUM=0");
        row(2'b01, 2'b01, 1, 0, 8'hD7, 0, "S load user, SUM=1");
        row(2'b01, 2'b00, 1, 0, 8'hDB, 1, "S fetch user, SUM=1");
        // MXR: load from execute-only (D A X V)
        row(2'b01, 2'b01, 0, 0, 8'hC9, 1, "S load X-only, MXR=0");
        row(2'b01, 2'b01, 0, 1, 8'hC9, 0, "S load X-only, MXR=1");
        // A/D bits
        row(2'b01, 2'b01, 0, 0, 8'h8F, 1, "load with A=0");
        row(2'b01, 2'b10, 0, 0, 8'h4F, 1, "store with D=0");
        row(2'b01, 2'b01, 0, 0, 8'h4F, 0, "load with D=0 ok");

        $display("%0d passed / %0d failed", pass, fail);
        $finish(0);
    end
endmodule
