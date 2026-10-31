// echo: sends back every byte, ctrl-D (0x04) ends it
// timer interrupts fire constantly to hit the rx load in MEM

#define UART    ((volatile unsigned *)0x10000000)
#define TX      0           // write a byte
#define RX      1           // read a byte (pops)
#define STATUS  2           // bit 0 tx_busy, bit 1 rx_valid

#define MTIME   ((volatile unsigned *)0x0200BFF8)
#define MTCMP   ((volatile unsigned *)0x02004000)
#define RESULT  ((volatile unsigned *)0x400)

static volatile unsigned ticks;     // interrupts taken

static void putc(char c) {
    while (UART[STATUS] & 1) ;      // wait tx_busy
    UART[TX] = c;
}

static char getc(void) {
    while (!(UART[STATUS] & 2)) ;   // wait rx_valid
    return UART[RX];                // load pops the byte
}

// next interrupt soon, period changes so it lands everywhere
static void timer_next(void) {
    unsigned t = MTIME[0] + 30 + ((ticks * 7) & 31);
    MTCMP[1] = 0xFFFFFFFF;          // no early fire while
    MTCMP[0] = t;                   // the two halves change
    MTCMP[1] = MTIME[1];
}

__attribute__((interrupt("machine")))
static void trap(void) {
    ticks++;
    timer_next();
}

int main(void) {
    asm volatile("csrw mtvec, %0" :: "r"(trap));
    timer_next();
    asm volatile("csrs mie, %0" :: "r"(1 << 7));     // MTIE
    asm volatile("csrs mstatus, %0" :: "r"(1 << 3)); // MIE

    for (;;) {
        char c = getc();
        if (c == 4) break;          // ctrl-D
        putc(c);
    }

    asm volatile("csrc mstatus, %0" :: "r"(1 << 3)); // interrupts off
    RESULT[1] = ticks;
    RESULT[0] = 0xD0E0000D;         // DONE
    return 0;
}