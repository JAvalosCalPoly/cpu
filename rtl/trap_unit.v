`timescale 1ns / 1ps
// exceptions/interrupts in MEM
module trap_unit (
    input  wire [ 1:0] priv,
    input  wire        valid,        // real instr in MEM
    input  wire        mem_write,
    input  wire        illegal,
    input  wire        ecall,
    input  wire        ebreak,
    input  wire        mret,
    input  wire        sret,
    input  wire        is_csr,
    input  wire        csr_valid,
    input  wire        int_pending,
    input  wire [31:0] int_cause,
    input  wire [31:0] instr,
    input  wire [31:0] pc,
    input  wire [31:0] trap_vec,
    input  wire [31:0] mepc,
    input  wire [31:0] sepc,
    output wire        take_trap,    // save epc/cause
    output wire        mem_trap,     // flush + redirect
    output wire        mret_ok,
    output wire        sret_ok,
    output wire [31:0] cause,
    output wire [31:0] tval,
    output wire [31:0] trap_target
);
    wire mret_bad = mret && (priv != 2'b11);  // mret from S or U
    wire sret_bad = sret && (priv == 2'b00);  // sret from U
    wire csr_bad = is_csr && !csr_valid;
    wire bad = illegal || csr_bad || mret_bad || sret_bad;  // illegal instr
    wire exc = bad || ecall || ebreak;
    // interrupt: real instr, not a store, no exception
    wire irq = int_pending && valid && !mem_write && !exc;

    assign take_trap = exc || irq;
    assign mem_trap = take_trap || mret || sret;
    assign mret_ok = mret && !mret_bad;
    assign sret_ok = sret && !sret_bad;
    assign cause       = irq ? int_cause : bad ? 32'd2 : ebreak ? 32'd3 :
                         ecall ? (32'd8 + priv) : 32'd0;  // ecall: 8 U, 9 S, 11 M
    assign tval = irq ? 32'd0 : bad ? instr : ebreak ? pc : 32'd0;
    assign trap_target = take_trap ? trap_vec : sret ? sepc : mepc;
endmodule
