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
    input  wire        sfence,
    input  wire        pf,
    input  wire        pf_store,
    input  wire [31:0] va,           // load/store address
    input  wire        csr_we,       // csr write in MEM
    input  wire [11:0] csr_addr,
    output wire        take_trap,    // save epc/cause
    output wire        mem_trap,     // flush + redirect
    output wire        mret_ok,
    output wire        sret_ok,
    output wire [31:0] cause,
    output wire [31:0] tval,
    output wire [31:0] trap_target,
    output wire        refetch,      // flush younger, restart at pc+4
    output wire        tlb_flush     // sfence.vma done
);
    wire mret_bad = mret && (priv != 2'b11);  // mret from S or U
    wire sret_bad = sret && (priv == 2'b00);  // sret from U
    wire csr_bad = is_csr && !csr_valid;
    wire sfence_bad = sfence && (priv == 2'b00);  // sfence from U
    wire bad = illegal || csr_bad || mret_bad || sret_bad || sfence_bad;  // illegal instr
    wire exc = bad || ecall || ebreak || pf;
    // interrupt: real instr, not a store, no exception
    wire irq = int_pending && valid && !mem_write && !exc;
    wire xlate_csr = csr_we && (csr_addr == 12'h180 || csr_addr == 12'h300 || csr_addr == 12'h100);  // satp, mstatus, sstatus

    assign take_trap = exc || irq;
    assign mem_trap = take_trap || mret || sret;
    assign mret_ok = mret && !mret_bad;
    assign sret_ok = sret && !sret_bad;
    assign cause = irq ? int_cause : bad ? 32'd2 :
               pf ? (pf_store ? 32'd15 : 32'd13) :  // store/load page fault
        ebreak ? 32'd3 : ecall ? (32'd8 + priv) : 32'd0;
    assign tval = irq ? 32'd0 : bad ? instr : pf ? va : ebreak ? pc : 32'd0;
    assign trap_target = take_trap ? trap_vec : sret ? sepc : mepc;
    assign tlb_flush = sfence && !take_trap;
    assign refetch = !take_trap && (xlate_csr || sfence);
endmodule
