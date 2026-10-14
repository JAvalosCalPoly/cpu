`timescale 1ns / 1ps
module memory_tb;

    reg         clk = 0;
    reg  [31:0] instr_addr;
    reg  [31:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg         mem_write;
    reg         mem_read;
    reg  [2:0]  mem_funct3;
    wire [31:0] instr;
    wire [31:0] mem_rdata;

    memory #(.ADDR_BITS(12), .INIT_FILE("testbenches/test_asm.hex")) dut (
        .clk(clk),
        .instr_addr(instr_addr),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .mem_funct3(mem_funct3),
        .instr(instr),
        .mem_rdata(mem_rdata)
    );

    always #5 clk = ~clk;   // 10 ns clock period

// The memory is loaded with test_asm.hex: 141 instructions at 000 - 230.
// Some known words (see test_asm.lst):
//   000: 40000413   addi x8, x0, 0x400
//   014: 401181B3   sub x3, x3, x1   bytes (little endian): 014 = B3, 015 = 81, 016 = 11, 017 = 40
//   18C: 00008067   jalr x0, 0(x1)  (ret)
//   230: 0000006F   jal x0, 0       (end: j end, the last instruction)
// Nothing is loaded past 230, so those words start as x.
//
// Reads are combinational (no clock). Writes happen on the rising clock edge.
// funct3: 000 b   001 h   010 w   100 bu   101 hu

    reg [31:0] expected [0:140];   // the testbench's own copy of the program
    integer i;
    integer errors = 0;

initial begin
$dumpfile("memory.vcd");
$dumpvars(0, memory_tb);

        $readmemh("testbenches/test_asm.hex", expected);
        mem_write = 1'b0; mem_read = 1'b0; mem_wdata = 32'h0; mem_addr = 32'h0; mem_funct3 = 3'b010;

// instruction port

// first instruction
        instr_addr = 32'h0000_0000; #10;
if (instr !== 32'h4000_0413) $display("FAIL: fetch 000 = %h", instr);
else $display("PASS: fetch 000 = %h (addi x8, x0, 0x400)", instr);

        instr_addr = 32'h0000_0014; #10;
if (instr !== 32'h4011_81B3) $display("FAIL: fetch 014 = %h", instr);
else $display("PASS: fetch 014 = %h (sub x3, x3, x1)", instr);

// the low 2 bits are ignored, so 016 still fetches the word at 014
        instr_addr = 32'h0000_0016; #10;
if (instr !== 32'h4011_81B3) $display("FAIL: fetch 016 (word-aligned) = %h", instr);
else $display("PASS: fetch 016 (word-aligned) = %h", instr);

        instr_addr = 32'h0000_018C; #10;
if (instr !== 32'h0000_8067) $display("FAIL: fetch 18C = %h", instr);
else $display("PASS: fetch 18C = %h (ret)", instr);

// last instruction
        instr_addr = 32'h0000_0230; #10;
if (instr !== 32'h0000_006F) $display("FAIL: fetch 230 = %h", instr);
else $display("PASS: fetch 230 = %h (j end)", instr);

// one past the end: the file didn't load anything here, so it's x
        instr_addr = 32'h0000_0234; #10;
if (instr !== 32'hxxxx_xxxx) $display("FAIL: fetch 234 (past the program) = %h", instr);
else $display("PASS: fetch 234 (past the program) = %h (never loaded)", instr);

// every instruction: walk addresses 000, 004, ... 230 and compare with the testbench's copy
        for (i = 0; i < 141; i = i + 1) begin
            instr_addr = i * 4; #1;
            if (instr !== expected[i]) begin
                $display("FAIL: fetch %h = %h, expected %h", instr_addr, instr, expected[i]);
                errors = errors + 1;
            end
        end
if (errors != 0) $display("FAIL: %0d of 141 instructions fetched wrong", errors);
else $display("PASS: all 141 instructions fetched correctly");

// lw (data port reads the same memory)

        mem_read = 1'b1; mem_funct3 = 3'b010; mem_addr = 32'h0000_0014; #10;
if (mem_rdata !== 32'h4011_81B3) $display("FAIL: lw 014 = %h", mem_rdata);
else $display("PASS: lw 014 = %h", mem_rdata);

        mem_read = 1'b1; mem_funct3 = 3'b010; mem_addr = 32'h0000_0230; #10;
if (mem_rdata !== 32'h0000_006F) $display("FAIL: lw 230 = %h", mem_rdata);
else $display("PASS: lw 230 = %h", mem_rdata);

// lb / lbu on the word at 014 (B3 81 11 40)

// byte 014 = B3: top bit 1, so lb fills with 1
        mem_read = 1'b1; mem_funct3 = 3'b000; mem_addr = 32'h0000_0014; #10;
if (mem_rdata !== 32'hFFFF_FFB3) $display("FAIL: lb 014 = %h", mem_rdata);
else $display("PASS: lb 014 = %h", mem_rdata);

// same byte with lbu: fills with 0
        mem_read = 1'b1; mem_funct3 = 3'b100; mem_addr = 32'h0000_0014; #10;
if (mem_rdata !== 32'h0000_00B3) $display("FAIL: lbu 014 = %h", mem_rdata);
else $display("PASS: lbu 014 = %h", mem_rdata);

// byte 015 = 81
        mem_read = 1'b1; mem_funct3 = 3'b000; mem_addr = 32'h0000_0015; #10;
if (mem_rdata !== 32'hFFFF_FF81) $display("FAIL: lb 015 = %h", mem_rdata);
else $display("PASS: lb 015 = %h", mem_rdata);

// byte 016 = 11: top bit 0, so lb fills with 0
        mem_read = 1'b1; mem_funct3 = 3'b000; mem_addr = 32'h0000_0016; #10;
if (mem_rdata !== 32'h0000_0011) $display("FAIL: lb 016 = %h", mem_rdata);
else $display("PASS: lb 016 = %h", mem_rdata);

// byte 017 = 40 (the top byte of the word)
        mem_read = 1'b1; mem_funct3 = 3'b000; mem_addr = 32'h0000_0017; #10;
if (mem_rdata !== 32'h0000_0040) $display("FAIL: lb 017 = %h", mem_rdata);
else $display("PASS: lb 017 = %h", mem_rdata);

// lh / lhu on the same word

// half at 014 = 81B3: top bit 1, so lh fills with 1
        mem_read = 1'b1; mem_funct3 = 3'b001; mem_addr = 32'h0000_0014; #10;
if (mem_rdata !== 32'hFFFF_81B3) $display("FAIL: lh 014 = %h", mem_rdata);
else $display("PASS: lh 014 = %h", mem_rdata);

        mem_read = 1'b1; mem_funct3 = 3'b101; mem_addr = 32'h0000_0014; #10;
if (mem_rdata !== 32'h0000_81B3) $display("FAIL: lhu 014 = %h", mem_rdata);
else $display("PASS: lhu 014 = %h", mem_rdata);

// half at 016 = 4011: top bit 0
        mem_read = 1'b1; mem_funct3 = 3'b001; mem_addr = 32'h0000_0016; #10;
if (mem_rdata !== 32'h0000_4011) $display("FAIL: lh 016 = %h", mem_rdata);
else $display("PASS: lh 016 = %h", mem_rdata);

// reads that must give 0

// mem_read = 0
        mem_read = 1'b0; mem_funct3 = 3'b010; mem_addr = 32'h0000_0014; #10;
if (mem_rdata !== 32'h0) $display("FAIL: mem_read = 0, rdata = %h", mem_rdata);
else $display("PASS: mem_read = 0, rdata = %h", mem_rdata);

// funct3 011 is not a load on RV32
        mem_read = 1'b1; mem_funct3 = 3'b011; mem_addr = 32'h0000_0014; #10;
if (mem_rdata !== 32'h0) $display("FAIL: funct3 011, rdata = %h", mem_rdata);
else $display("PASS: funct3 011, rdata = %h", mem_rdata);

// stores, at 400 (the signature area the program writes its results to)

// sw 11223344 to 400
        mem_read = 1'b0; mem_write = 1'b1; mem_funct3 = 3'b010; mem_addr = 32'h0000_0400; mem_wdata = 32'h1122_3344;
        @(posedge clk); #1;
        mem_write = 1'b0; mem_read = 1'b1; mem_funct3 = 3'b010; #10;
if (mem_rdata !== 32'h1122_3344) $display("FAIL: sw 11223344, lw 400 = %h", mem_rdata);
else $display("PASS: sw 11223344, lw 400 = %h", mem_rdata);

// sb to 401: only that byte changes. wdata top bits are junk on purpose, only the low byte (AB) is stored
        mem_read = 1'b0; mem_write = 1'b1; mem_funct3 = 3'b000; mem_addr = 32'h0000_0401; mem_wdata = 32'hFFFF_FFAB;
        @(posedge clk); #1;
        mem_write = 1'b0; mem_read = 1'b1; mem_funct3 = 3'b010; mem_addr = 32'h0000_0400; #10;
if (mem_rdata !== 32'h1122_AB44) $display("FAIL: sb AB to 401, lw 400 = %h", mem_rdata);
else $display("PASS: sb AB to 401, lw 400 = %h", mem_rdata);

// sh to 402: only the top half changes, only the low half of wdata (BEEF) is stored
        mem_read = 1'b0; mem_write = 1'b1; mem_funct3 = 3'b001; mem_addr = 32'h0000_0402; mem_wdata = 32'h1234_BEEF;
        @(posedge clk); #1;
        mem_write = 1'b0; mem_read = 1'b1; mem_funct3 = 3'b010; mem_addr = 32'h0000_0400; #10;
if (mem_rdata !== 32'hBEEF_AB44) $display("FAIL: sh BEEF to 402, lw 400 = %h", mem_rdata);
else $display("PASS: sh BEEF to 402, lw 400 = %h", mem_rdata);

// sb to 403: the top byte
        mem_read = 1'b0; mem_write = 1'b1; mem_funct3 = 3'b000; mem_addr = 32'h0000_0403; mem_wdata = 32'h0000_0099;
        @(posedge clk); #1;
        mem_write = 1'b0; mem_read = 1'b1; mem_funct3 = 3'b010; mem_addr = 32'h0000_0400; #10;
if (mem_rdata !== 32'h99EF_AB44) $display("FAIL: sb 99 to 403, lw 400 = %h", mem_rdata);
else $display("PASS: sb 99 to 403, lw 400 = %h", mem_rdata);

// stores that must change nothing

// mem_write = 0: the clock ticks but nothing is written
        mem_read = 1'b0; mem_write = 1'b0; mem_funct3 = 3'b010; mem_addr = 32'h0000_0400; mem_wdata = 32'hDEAD_DEAD;
        @(posedge clk); #1;
        mem_read = 1'b1; mem_funct3 = 3'b010; #10;
if (mem_rdata !== 32'h99EF_AB44) $display("FAIL: mem_write = 0, lw 400 = %h", mem_rdata);
else $display("PASS: mem_write = 0, lw 400 = %h (unchanged)", mem_rdata);

// funct3 011 is not a store: nothing is written
        mem_read = 1'b0; mem_write = 1'b1; mem_funct3 = 3'b011; mem_addr = 32'h0000_0400; mem_wdata = 32'hDEAD_DEAD;
        @(posedge clk); #1;
        mem_write = 1'b0; mem_read = 1'b1; mem_funct3 = 3'b010; #10;
if (mem_rdata !== 32'h99EF_AB44) $display("FAIL: store funct3 011, lw 400 = %h", mem_rdata);
else $display("PASS: store funct3 011, lw 400 = %h (unchanged)", mem_rdata);

// stores didn't touch the program
        instr_addr = 32'h0000_0000; #10;
if (instr !== 32'h4000_0413) $display("FAIL: fetch 000 after stores = %h", instr);
else $display("PASS: fetch 000 after stores = %h (program untouched)", instr);

// one memory for both ports: the instruction port sees what the data port wrote
        instr_addr = 32'h0000_0400; #10;
if (instr !== 32'h99EF_AB44) $display("FAIL: fetch 400 after stores = %h", instr);
else $display("PASS: fetch 400 after stores = %h (same memory)", instr);

$finish;
end
endmodule