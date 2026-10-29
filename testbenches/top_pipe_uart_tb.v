`timescale 1ns / 1ps
// runs test_uart.hex (from test_uart.S) and decodes the uart line
module top_pipe_uart_tb;

    reg clk = 0;
    reg rst = 1;
    wire tx;

    always #5 clk = ~clk;

// fast uart: DIV = 1M / 100k = 10 clocks per bit
top_pipe #(.INIT_FILE("testbenches/test_uart.hex"), .CLK_HZ(1_000_000), .BAUD(100_000))
dut (.clk(clk), .rst(rst), .uart_tx(tx));

`define SIG(n) dut.u_memory.mem[256 + n]
localparam DIV = 10;
localparam N   = 45;                       // bytes expected

    reg [8*N-1:0] expect_str = "0\n1\n1\n2\n3\n5\n8\n13\n21\n34\n55\n89\n144\n233\n377\n610\n";
    reg [7:0] got [0:N-1];
    reg [7:0] b, e;
    integer i, k, pass = 0, fail = 0, bad = 0;
    integer cycles = 0;
    always @(posedge clk) cycles = cycles + 1;

// act like the pc receiving
task recv(output [7:0] b);
    integer j;
    begin
        @(negedge tx);                      // start bit
        repeat (DIV/2) @(posedge clk);      // middle of start
        for (j = 0; j < 8; j = j + 1) begin
            repeat (DIV) @(posedge clk);    // middle of next bit
            b[j] = tx;                      // lsb first
        end
        repeat (DIV) @(posedge clk);        // middle of stop
        if (tx !== 1'b1) begin
            $display("FAIL: stop bit on byte %0d", k); fail = fail + 1;
        end
    end
endtask

initial begin
$dumpfile("top_pipe_uart.vcd");
$dumpvars(0, top_pipe_uart_tb);

        #10 rst = 0;

// receive every byte, print them as they come
        for (k = 0; k < N; k = k + 1) begin
            recv(b);
            got[k] = b;
            $write("%c", b);
        end

// compare with the expected text
        for (i = 0; i < N; i = i + 1) begin
            e = expect_str[8*(N-1-i) +: 8];
            if (got[i] !== e) begin
                if (bad == 0) $display("FAIL: byte %0d expected %h got %h", i, e, got[i]);
                bad = bad + 1;
            end
        end
        if (bad == 0) begin
            $display("PASS: %0d bytes match", N); pass = pass + 1;
        end else begin
            $display("FAIL: %0d bytes wrong", bad); fail = fail + 1;
        end

// done marker lands right after the last store to tx
        repeat (20) @(posedge clk);
        if (`SIG(0) === 32'hD0E0_000D) begin
            $display("PASS: DONE marker"); pass = pass + 1;
        end else begin
            $display("FAIL: DONE marker, got %h", `SIG(0)); fail = fail + 1;
        end

// nothing else gets sent
        k = 0;
        fork : idle
            begin @(negedge tx) k = 1; end
            begin repeat (20*DIV) @(posedge clk); disable idle; end
        join
        if (k == 0) begin
            $display("PASS: line idle after"); pass = pass + 1;
        end else begin
            $display("FAIL: extra byte after DONE"); fail = fail + 1;
        end

$display("DONE after %0d cycles, %0d passed / %0d failed", cycles, pass, fail);
$finish;
end

// timeout
initial begin
    #2000000 $display("FAIL: timeout, %0d bytes received", k);
    $finish;
end

endmodule