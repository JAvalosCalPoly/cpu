`timescale 1ns / 1ps
// uart tx: idle, send, status, dropped write, polled back-to-back
module uart_tb;

    reg clk;
    reg rst;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg we;
    wire [31:0] rdata;
    wire tx;

uart #(.CLK_HZ(1_000_000), .BAUD(100_000)) dut (
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .wdata(wdata),
    .we(we),
    .rdata(rdata),
    .tx(tx)
);

localparam DIV = 10;            // clocks per bit
integer pass = 0, fail = 0;
reg [7:0] got;                  // byte received

task write(input [3:0] off, input [31:0] d);
    begin
        @(negedge clk);         // change inputs away from posedge
        addr = off; wdata = d; we = 1;
        @(negedge clk);
        we = 0;
    end
endtask

// act like the pc receiving
task recv(output [7:0] b);
    integer i;
    begin
        @(negedge tx);                      // start bit
        repeat (DIV/2) @(posedge clk);      // middle of start
        if (tx !== 1'b0) $display("FAIL: start bit glitch");
        for (i = 0; i < 8; i = i + 1) begin
            repeat (DIV) @(posedge clk);    // middle of next bit
            b[i] = tx;                      // lsb first
        end
        repeat (DIV) @(posedge clk);        // middle of stop
        if (tx !== 1'b1) begin
            $display("FAIL: stop bit"); fail = fail + 1;
        end
    end
endtask

// read status, rdata is one clock late
task status(output busy);
    begin
        @(negedge clk) addr = 4'h8;
        @(negedge clk) busy = rdata[0];
    end
endtask

// poll until not busy
task wait_idle;
    reg busy;
    begin
        busy = 1;
        while (busy) status(busy);
    end
endtask

task check(input [31:0] g, input [31:0] e, input [8*32-1:0] name);
    begin
        if (g !== e) begin
            $display("FAIL: %0s, expected %h, got %h", name, e, g);
            fail = fail + 1;
        end else begin
            $display("PASS: %0s = %h", name, g);
            pass = pass + 1;
        end
    end
endtask

    // clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // reset generation
    initial begin
        rst = 1;
        #20 rst = 0;
    end

    reg busy;
    integer edges;

    // test stimulus
    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb);
        addr = 0; wdata = 0; we = 0;
        @(negedge rst);               // wait out reset

        // 1) idle
        check(tx, 1, "idle high");
        status(busy);
        check(busy, 0, "status idle");

        // 2) send 'A'
        fork
            write(0, 32'h41);
            recv(got);
        join
        check(got, 8'h41, "send A");

        // 3) status busy during, 0 after
        write(0, 32'h42);             // 'B'
        status(busy);
        check(busy, 1, "status busy during");
        wait_idle;
        status(busy);
        check(busy, 0, "status idle after");

        // 4) write while busy is dropped
        fork
            begin
                write(0, 32'h43);     // 'C'
                repeat (3*DIV) @(negedge clk);
                write(0, 32'h5A);     // 'Z' mid-frame, dropped
            end
            recv(got);
        join
        check(got, 8'h43, "C sent, Z dropped");
        wait_idle;
        edges = 0;                    // no frame for Z
        fork : watch
            begin @(negedge tx) edges = 1; end
            begin repeat (15*DIV) @(posedge clk); disable watch; end
        join
        check(edges, 0, "no frame after drop");

        // 5) back-to-back with polling
        fork
            begin
                wait_idle; write(0, 32'h44);  // 'D'
                wait_idle; write(0, 32'h45);  // 'E'
            end
            begin
                recv(got); check(got, 8'h44, "send D");
                recv(got); check(got, 8'h45, "send E");
            end
        join

        // 6) store to status doesn't send
        wait_idle;
        write(4'h8, 32'h46);
        status(busy);
        check(busy, 0, "write to status ignored");

        $display("uart testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end

    // timeout
    initial begin
        #200000 $display("FAIL: timeout"); $finish;
    end

endmodule