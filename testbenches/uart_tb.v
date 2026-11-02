`timescale 1ns / 1ps
// uart tx: idle, send, status, dropped write, polled back-to-back
// uart rx: receive, pop, glitch, framing error, overrun, full duplex
module uart_tb;

    reg clk;
    reg rst;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg we;
    wire [31:0] rdata;
    wire tx;
    reg rx = 1;                     // tb drives the pc side
    reg rx_pop = 0;

uart #(.CLK_HZ(1_000_000), .BAUD(100_000)) dut (
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .wdata(wdata),
    .we(we),
    .rdata(rdata),
    .tx(tx),
    .rx(rx),
    .rx_pop(rx_pop)
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

// act like the pc sending, stop = 0 makes a framing error
task send(input [7:0] b, input stop);
    integer i;
    begin
        rx = 0; repeat (DIV) @(posedge clk);          // start
        for (i = 0; i < 8; i = i + 1) begin
            rx = b[i]; repeat (DIV) @(posedge clk);   // lsb first
        end
        rx = stop; repeat (DIV) @(posedge clk);       // stop
        rx = 1;
    end
endtask

// read a register, rdata is one clock late
task rd(input [3:0] off, output [31:0] d);
    begin
        @(negedge clk) addr = off;
        @(negedge clk) d = rdata;
    end
endtask

// cpu load from rx retires: one pop pulse
task pop;
    begin
        @(negedge clk) rx_pop = 1;
        @(negedge clk) rx_pop = 0;
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
    reg [31:0] d;

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

        // 7) rx: nothing yet
        rd(4'h8, d);
        check(d[1], 0, "rx_valid idle");

        // 8) receive a byte
        send(8'h5A, 1);
        repeat (DIV) @(posedge clk);
        rd(4'h8, d);
        check(d[1], 1, "rx_valid after byte");
        rd(4'h4, d);
        check(d, 32'h5A, "rx byte 5A");
        rd(4'h8, d);
        check(d[1], 1, "reading alone doesn't pop");

        // 9) pop clears valid
        pop;
        rd(4'h8, d);
        check(d[1], 0, "pop clears rx_valid");

        // 10) glitch: short low pulse is not a start bit
        @(negedge clk) rx = 0;
        repeat (2) @(negedge clk);
        rx = 1;
        repeat (15*DIV) @(posedge clk);
        rd(4'h8, d);
        check(d[1], 0, "glitch ignored");

        // 11) framing error: bad stop bit, no byte
        send(8'h33, 0);
        repeat (15*DIV) @(posedge clk);
        rd(4'h8, d);
        check(d[1], 0, "bad stop bit dropped");
        send(8'hC3, 1);                     // recovers after
        repeat (DIV) @(posedge clk);
        rd(4'h4, d);
        check(d, 32'hC3, "rx works after framing error");
        pop;

        // 12) overrun: two bytes, no read, newest wins
        send(8'h11, 1);
        send(8'h22, 1);
        repeat (DIV) @(posedge clk);
        rd(4'h4, d);
        check(d, 32'h22, "overrun keeps newest");
        pop;

        // 13) full duplex: tx and rx at once
        wait_idle;
        fork
            write(0, 32'h51);               // 'Q' out
            recv(got);
            send(8'h52, 1);                 // 'R' in
        join
        check(got, 8'h51, "tx Q during rx");
        repeat (DIV) @(posedge clk);
        rd(4'h4, d);
        check(d, 32'h52, "rx R during tx");

        pop;

        // 14) rx_data holds while the next byte shifts in
        send(8'hA5, 1);
        fork
            send(8'h0F, 1);                 // next byte arriving
            begin
                repeat (6*DIV) @(posedge clk);  // mid frame
                rd(4'h4, d);
                check(d, 32'hA5, "rx byte stable during next");
            end
        join
        repeat (DIV) @(posedge clk);
        rd(4'h4, d);
        check(d, 32'h0F, "then next byte");
        pop;

        $display("uart testbench finished: %0d passed / %0d failed", pass, fail);
        $finish;
    end

    // timeout
    initial begin
        #200000 $display("FAIL: timeout"); $finish;
    end

endmodule