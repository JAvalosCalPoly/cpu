#define UART    ((volatile unsigned *)0x10000000)
#define TX      0
#define RX      1
#define STATUS  2

#define MTIME   ((volatile unsigned *)0x0200BFF8)
#define MTCMP   ((volatile unsigned *)0x02004000)
#define TICK    8000000         // start: 5 moves/s at 40 MHz
#define FAST    2000000         // cap: 20 moves/s
#define SPEEDUP 400000          // per food

#define ROWS    15
#define COLS    30

#define SIZE    512
#define MASK    (SIZE - 1)

#define BODY    512             // snake ring, power of 2
#define BMASK   (BODY - 1)

#define NONE    0               // next_dir values
#define UP      1
#define DOWN    2
#define LEFT    3
#define RIGHT   4

#define RESTART 0
#define PLAYING 1
#define OVER    2

static char buf[SIZE];
static unsigned head, tail;
static unsigned drops;
static unsigned state;          // RESTART / PLAYING / OVER

// snake: handler only, no atomics
static unsigned char body_r[BODY], body_c[BODY];
static unsigned bhead, btail;   // free-running, length = bhead - btail
static int dr, dc;              // direction

// main -> handler: last key, 0 = none
static unsigned next_dir;

// food and score
#define CELLS   (ROWS * COLS)
static unsigned char occ[ROWS + 2][COLS + 2];   // segments per cell
static unsigned fr, fc;         // food
static unsigned score;          // amoadd
static unsigned rng = 0x1234567;  // handler only
static unsigned stir;           // main counts, handler mixes in
static unsigned period = TICK;  // handler only, shrinks as you eat

static unsigned space(void)
{
    unsigned t = __atomic_load_n(&tail, __ATOMIC_ACQUIRE);
    return SIZE - (head - t);
}

static void emit(char c)
{
    buf[head & MASK] = c;
    __atomic_store_n(&head, head + 1, __ATOMIC_RELEASE);
}

static void emit_str(const char *s)
{
    while (*s)
        emit(*s++);
}

static void emit_num(unsigned n)
{
    if (n >= 10)
        emit((char)('0' + n / 10));
    emit((char)('0' + n % 10));
}

static void emit_dec(unsigned n)       // up to 999
{
    if (n >= 100)
        emit((char)('0' + n / 100));
    if (n >= 10)
        emit((char)('0' + n / 10 % 10));
    emit((char)('0' + n % 10));
}

static unsigned digits(unsigned n)
{
    return n >= 10 ? 2 : 1;
}

static unsigned xy_len(unsigned r, unsigned c)
{
    return 4 + digits(r) + digits(c);
}

static void goto_xy(unsigned r, unsigned c)
{
    emit_str("\033[");
    emit_num(r);
    emit(';');
    emit_num(c);
    emit('H');
}

static void emit_hashes(unsigned n)
{
    while (n--)
        emit('#');
}

// one char at (r, c)
static unsigned cell_len(unsigned r, unsigned c)
{
    return xy_len(r, c) + 1;
}

static void cell(unsigned r, unsigned c, char ch)
{
    goto_xy(r, c);
    emit(ch);
}

static void push(unsigned r, unsigned c)
{
    body_r[bhead & BMASK] = (unsigned char)r;
    body_c[bhead & BMASK] = (unsigned char)c;
    ++bhead;
    ++occ[r][c];
}

static void pop(void)
{
    unsigned ti = btail & BMASK;

    --occ[body_r[ti]][body_c[ti]];
    ++btail;
}

// xorshift, stirred by main's loop count
static unsigned rand32(void)
{
    rng ^= __atomic_load_n(&stir, __ATOMIC_RELAXED);
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    return rng;
}

// random empty cell, 0 if full
static unsigned place_food(void)
{
    unsigned i = rand32() % CELLS;
    unsigned n;

    for (n = 0; n < CELLS; ++n) {
        fr = 2 + i / COLS;
        fc = 2 + i % COLS;
        if (!occ[fr][fc])
            return 1;
        i = (i + 1 == CELLS) ? 0 : i + 1;
    }
    return 0;
}

#define FOOD_LEN  (4 + 2 + 2 + 1)                 // worst-case cell
#define SCORE_LEN (4 + 2 + 1 + 7 + 3)             // "Score: 999"

static void score_line(unsigned n)
{
    goto_xy(ROWS + 3, 1);
    emit_str("Score: ");
    emit_dec(n);
}

static unsigned slen(const char *s)
{
    unsigned n = 0;

    while (s[n])
        ++n;
    return n;
}

// banner in the middle of the board, all or nothing
static unsigned banner(const char *msg)
{
    unsigned r = ROWS / 2 + 1;
    unsigned c = 2 + (COLS - slen(msg)) / 2;

    if (space() < xy_len(r, c) + slen(msg)) {
        ++drops;
        return 0;
    }
    goto_xy(r, c);
    emit_str(msg);
    return 1;
}

static void game_over(const char *msg)
{
    if (banner(msg))
        __atomic_store_n(&state, OVER, __ATOMIC_RELEASE);
    // no room: still PLAYING, same crash next tick
}

static unsigned border_len(void)
{
    unsigned width = COLS + 2;
    unsigned need = 10 + xy_len(1, 1) + xy_len(ROWS + 2, 1) + 2 * width;
    unsigned r;

    for (r = 2; r <= ROWS + 1; ++r)
        need += xy_len(r, 1) + 1 + xy_len(r, width) + 1;
    return need;
}

static void border(void)
{
    unsigned width = COLS + 2;
    unsigned r;

    emit_str("\033[2J");
    emit_str("\033[?25l");
    goto_xy(1, 1);
    emit_hashes(width);
    for (r = 2; r <= ROWS + 1; ++r) {
        goto_xy(r, 1);
        emit('#');
        goto_xy(r, width);
        emit('#');
    }
    goto_xy(ROWS + 2, 1);
    emit_hashes(width);
}

// new game: border + 3-long snake, all or nothing
static unsigned restart(void)
{
    unsigned r = ROWS / 2 + 1;
    unsigned need = border_len() + cell_len(r, 5) + cell_len(r, 6) + cell_len(r, 7)
                    + FOOD_LEN + SCORE_LEN;
    unsigned i, j;

    if (space() < need) {
        ++drops;
        return 0;
    }

    border();
    for (i = 0; i < ROWS + 2; ++i)
        for (j = 0; j < COLS + 2; ++j)
            occ[i][j] = 0;
    bhead = btail = 0;
    push(r, 5);
    push(r, 6);
    push(r, 7);
    dr = 0;
    dc = 1;                     // moving right
    __atomic_exchange_n(&next_dir, NONE, __ATOMIC_ACQUIRE);  // drop old key
    cell(r, 5, 'o');
    cell(r, 6, 'o');
    cell(r, 7, '@');
    __atomic_store_n(&score, 0, __ATOMIC_RELAXED);
    period = TICK;              // back to slow
    place_food();
    cell(fr, fc, '*');
    score_line(0);
    return 1;
}

// one move: no room to draw = no move
// take the pending key, ignore a turn into the neck
static void turn(void)
{
    unsigned d = __atomic_exchange_n(&next_dir, NONE, __ATOMIC_ACQUIRE);  // amoswap
    int ndr = 0, ndc = 0;

    if (d == UP)         ndr = -1;
    else if (d == DOWN)  ndr = 1;
    else if (d == LEFT)  ndc = -1;
    else if (d == RIGHT) ndc = 1;
    else return;

    if (ndr == -dr && ndc == -dc)
        return;                 // reverse
    dr = ndr;
    dc = ndc;
}

static void step(void)
{
    unsigned hi = (bhead - 1) & BMASK;
    unsigned ti = btail & BMASK;
    unsigned hr = body_r[hi], hc = body_c[hi];
    unsigned tr = body_r[ti], tc = body_c[ti];
    int nr = (int)hr + dr;
    int nc = (int)hc + dc;
    unsigned eat, need, sc;

    if (nr < 2 || nr > ROWS + 1 || nc < 2 || nc > COLS + 1) {
        game_over(" GAME OVER  R=restart ");   // wall
        return;
    }

    eat = ((unsigned)nr == fr && (unsigned)nc == fc);
    // body, but the tail cell is free unless we grow
    if (occ[nr][nc] && (eat || (unsigned)nr != tr || (unsigned)nc != tc)) {
        game_over(" GAME OVER  R=restart ");   // self
        return;
    }
    need = cell_len(hr, hc) + cell_len(nr, nc);
    need += eat ? FOOD_LEN + SCORE_LEN : cell_len(tr, tc);
    if (space() < need) {
        ++drops;
        return;
    }

    if (!eat) {
        cell(tr, tc, ' ');      // tail first, so a head on that cell survives
        pop();
    }
    cell(hr, hc, 'o');
    cell(nr, nc, '@');
    push(nr, nc);

    if (eat) {                  // grew: no pop, new food, +1
        sc = __atomic_fetch_add(&score, 1, __ATOMIC_RELAXED) + 1;  // amoadd
        if (place_food())
            cell(fr, fc, '*');
        score_line(sc);
        period = (period > FAST + SPEEDUP) ? period - SPEEDUP : FAST;
        if (bhead - btail == CELLS)
            game_over(" YOU WIN  R=restart ");  // board full
    }
}

static void timer_next(void)
{
    unsigned low = MTIME[0];
    unsigned high = MTIME[1];
    unsigned next = low + period;
    unsigned next_high = high + (next < low);

    MTCMP[1] = 0xffffffffu;
    MTCMP[0] = next;
    MTCMP[1] = next_high;
}

static void drain(void)
{
    unsigned h = __atomic_load_n(&head, __ATOMIC_ACQUIRE);

    if (tail != h && !(UART[STATUS] & 1)) {
        UART[TX] = (unsigned char)buf[tail & MASK];
        __atomic_store_n(&tail, tail + 1, __ATOMIC_RELEASE);
    }
}

// wasd -> next_dir, no waiting
static void keys(void)
{
    unsigned d;
    char c;

    if (!(UART[STATUS] & 2))
        return;                 // no byte
    c = (char)UART[RX];         // pops it
    if (c == 'w' || c == 'W')      d = UP;
    else if (c == 's' || c == 'S') d = DOWN;
    else if (c == 'a' || c == 'A') d = LEFT;
    else if (c == 'd' || c == 'D') d = RIGHT;
    else if (c == 'r' || c == 'R') {
        unsigned exp = OVER;    // only from game over
        __atomic_compare_exchange_n(&state, &exp, RESTART, 0,
                                    __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);  // lr/sc
        return;
    }
    else return;
    __atomic_exchange_n(&next_dir, d, __ATOMIC_RELEASE);  // amoswap, newest wins
}

__attribute__((interrupt("machine")))
static void trap(void)
{
    unsigned st = __atomic_load_n(&state, __ATOMIC_ACQUIRE);

    if (st == RESTART) {
        if (restart())
            __atomic_store_n(&state, PLAYING, __ATOMIC_RELEASE);
    } else if (st == PLAYING) {
        turn();
        step();
    }
    timer_next();
}

int main(void)
{
    unsigned v;

    __atomic_store_n(&state, RESTART, __ATOMIC_RELAXED);  // irqs still off
    v = (unsigned)trap;
    __asm__ volatile("csrw mtvec, %0" :: "r"(v));
    timer_next();

    v = 1u << 7;
    __asm__ volatile("csrs mie, %0" :: "r"(v));
    v = 1u << 3;
    __asm__ volatile("csrs mstatus, %0" :: "r"(v));

    for (;;) {
        drain();
        keys();
        __atomic_fetch_add(&stir, 1, __ATOMIC_RELAXED);  // amoadd: timing noise
    }
}