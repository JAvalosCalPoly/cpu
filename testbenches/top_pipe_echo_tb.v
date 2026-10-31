`timescale 1ns / 1ps
// runs echo.hex (from echo.c): the tb types a line into uart_rx and
// checks it comes back on uart_tx, no byte lost or doubled, while
// timer interrupts keep landing on the cpu
module top_pipe_echo_tb;

    reg clk = 0;
    reg rst = 1;
    reg rx  = 1;                            // pc -> fpga, idle high
    wire tx;

    always #5 clk = ~clk;

// fast uart: DIV = 1M / 100k = 10 clocks per bit
top_pipe #(.INIT_FILE("testbenches/echo.hex"), .CLK_HZ(1_000_000), .BAUD(100_000))
dut (.clk(clk), .rst(rst), .uart_tx(tx), .uart_rx(rx));

`define SIG(n) dut.u_memory.mem[256 + n]
localparam DIV = 10;
localparam N    = 31;                       // bytes in a line
localparam REPS = 12;                       // lines typed

    reg [8*N-1:0] line = "the quick brown fox jumps over\n";
    reg [7:0] got [0:N*REPS-1];
    reg [7:0] b, e;
    integer i, k = 0, pass = 0, fail = 0, bad = 0, len = 0;
    integer cycles = 0;

    always @(posedge clk) cycles = cycles + 1;

// count interrupts that land on the rx load while it sits in MEM
    integer hits = 0, bad_pops = 0;
    always @(posedge clk)
        if (dut.u_core.mem_int && dut.u_core.ex_mem_mem_read &&
            dut.u_core.ex_mem_alu_result == 32'h1000_0004) begin
            hits = hits + 1;
            if (dut.rx_pop) bad_pops = bad_pops + 1;  // popped a load that gets replayed
        end

// act like the pc sending
task send(input [7:0] c);
    integer j;
    begin
        rx = 0; repeat (DIV) @(posedge clk);          // start
        for (j = 0; j < 8; j = j + 1) begin
            rx = c[j]; repeat (DIV) @(posedge clk);   // lsb first
        end
        rx = 1; repeat (DIV) @(posedge clk);          // stop
    end
endtask

// act like the pc receiving
task recv(output [7:0] c);
    integer j;
    begin
        @(negedge tx);                      // start bit
        repeat (DIV/2) @(posedge clk);      // middle of start
        for (j = 0; j < 8; j = j + 1) begin
            repeat (DIV) @(posedge clk);
            c[j] = tx;                      // lsb first
        end
        repeat (DIV) @(posedge clk);        // stop bit
    end
endtask

// byte i of the line, first char first
function [7:0] ch(input integer i);
    ch = line[8*(N-1-i) +: 8];
endfunction

initial begin
$dumpfile("top_pipe_echo.vcd");
$dumpvars(0, top_pipe_echo_tb);

        len = N * REPS;                     // bytes echoed

        #10 rst = 0;
        repeat (200) @(posedge clk);        // let main set up

// type the line and listen at the same time
        fork
            begin                           // keyboard
                for (i = 0; i < len; i = i + 1) begin
                    send(ch(i % N));
                    repeat ((i % 7) * DIV) @(posedge clk); // uneven typing
                end
                send(8'h04);                // ctrl-D ends it
            end
            begin                           // screen
                for (k = 0; k < len; k = k + 1) begin
                    recv(b);
                    got[k] = b;
                    $write("%c", b);
                end
            end
        join

// compare
        for (i = 0; i < len; i = i + 1)
            if (got[i] !== ch(i % N)) begin
                if (bad == 0) $display("FAIL: byte %0d expected %h got %h", i, ch(i % N), got[i]);
                bad = bad + 1;
            end
        if (bad == 0) begin
            $display("PASS: %0d bytes echoed", len); pass = pass + 1;
        end else begin
            $display("FAIL: %0d bytes wrong", bad); fail = fail + 1;
        end

        repeat (50) @(posedge clk);
        if (`SIG(0) === 32'hD0E0_000D) begin
            $display("PASS: DONE marker"); pass = pass + 1;
        end else begin
            $display("FAIL: DONE marker, got %h", `SIG(0)); fail = fail + 1;
        end

// the point: interrupts really happened during the echo
        if (`SIG(1) > 200) begin
            $display("PASS: %0d timer interrupts during echo", `SIG(1)); pass = pass + 1;
        end else begin
            $display("FAIL: only %0d interrupts", `SIG(1)); fail = fail + 1;
        end

// the rx load got interrupted in MEM at least once
        if (hits > 0) begin
            $display("PASS: %0d interrupts hit the rx load in MEM", hits); pass = pass + 1;
        end else begin
            $display("FAIL: no interrupt hit the rx load, test proves nothing"); fail = fail + 1;
        end

// a trapped load must not pop: it runs again after mret
        if (bad_pops == 0) begin
            $display("PASS: no pop from a trapped rx load"); pass = pass + 1;
        end else begin
            $display("FAIL: %0d pops from trapped rx loads", bad_pops); fail = fail + 1;
        end

$display("DONE after %0d cycles, %0d passed / %0d failed", cycles, pass, fail);
$finish;
end

// timeout: a lost byte means the echo never finishes
initial begin
    #20000000 $display("FAIL: timeout, %0d bytes echoed", k);
    $finish;
end

endmodule