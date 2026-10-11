`timescale 1ns / 1ps

module top_tb;

    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

top #(.INIT_FILE("program.hex")) 
dut (.clk(clk), .rst(rst));

    integer errors = 0;

    task check(
        input [31:0]   actual,
        input [31:0]   expected,
        input [8*16:1] name
    );
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s: got %h, expected %h", name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s = %h", name, actual);
            end
        end
    endtask

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, top_tb);
        #10 rst = 0;
        repeat (20) @(posedge clk);
        #1
        check(dut.u_core.u_reg32.gen_regs[1].r.q, 32'd5,  "x1");  // addi x1, x0, 5
        check(dut.u_core.u_reg32.gen_regs[2].r.q, 32'd7,  "x2");  // addi x2, x0, 7
        check(dut.u_core.u_reg32.gen_regs[3].r.q, 32'd12, "x3");  // add x3, x1, x2 (and beq skipped the 99)
        check(dut.u_core.u_reg32.gen_regs[4].r.q, 32'h18, "x4");  // jal saved the return address
        check(dut.u_core.pc,                      32'h18, "pc");  // stuck on the j done loop
        $finish;
    end

endmodule
