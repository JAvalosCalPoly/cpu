#ifndef CLK_HZ
#define CLK_HZ  12000000        // arty s7: 12 MHz
#endif
 
#define UART    ((volatile unsigned *)0x10000000)
#define TX      0               // write a byte
#define RX      1               // read a byte (pops)
#define STATUS  2               // bit 0 tx_busy, bit 1 rx_valid
#define MTIME   ((volatile unsigned *)0x0200BFF8)

// uart
static void putch(char c) {
    while(UART[STATUS] & 1) ; // wait for tx_busy to clear
    UART[TX] = c;
}

static void puts(const char *s) {
    while(*s) {
        if(*s == '\n') putch('\r');
        putch(*s++);
    }
}

static void putint(int n) {
    char buf[12];
    int i = 0;
    if (n < 0) { putch('-'); n = -n; }
    do { buf[i++] = '0' + n % 10; n /= 10; } while (n);
    while (i) putch(buf[--i]);
}
 
static char getc(void) {
    while (!(UART[STATUS] & 2)) ;   // wait rx_valid
    return UART[RX];                // load pops the byte
}
 
// like cin >> c: first non-space char, rest of the line dropped
static char getchoice(void) {
    char first = 0, c;
    for (;;) {
        c = getc();
        if (c == '\r' || c == '\n') {
            if (first) break;       // blank lines are skipped
            continue;
        }
        putch(c);                    // echo, tio doesn't
        if (!first && c != ' ') first = c;
    }
    puts("\n");
    return first;
}
 
// ---------- time ----------
static void sleep_ms(unsigned ms) {
    unsigned start = MTIME[0];      // low word, wraps fine
    unsigned ticks = ms * (CLK_HZ / 1000);
    while (MTIME[0] - start < ticks) ;
}
 
// ---------- rand ----------
static unsigned seed = 1;
 
static void srand(unsigned s) { seed = s ? s : 1; }
 
static int rand(void) {             // xorshift32
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed & 0x7FFFFFFF;
}
 
// ---------- p12funcs ----------
static int drawcard(void) {
    return 1 + rand() % 10;         // card 1 through 10
}
 
static int TOT(int cards[], int size) {
    int total = 0;
    for (int i = 0; i < size; ++i) {
        if (cards[i] == 1)       total += 1;    // ace counts as 1
        else if (cards[i] >= 10) total += 10;   // face cards
        else                     total += cards[i];
    }
    return total;
}
 
// ---------- main ----------
int main(void) {
    char playAgain = 0;
 
    // no clock chip: seed from how long the player takes
    puts("Press Enter to start.\n");
    for (char c = 0; c != '\r' && c != '\n'; ) {
        c = getc();
        putint(c); putch(' ');      // show what arrived
    }
    for (char c = 0; c != '\r' && c != '\n'; ) c = getc();
    srand(MTIME[0]);
 
    while (playAgain != 'n' && playAgain != 'N') {
        puts("This is a Blackjack game.\n\ngame start\n");
        sleep_ms(1000);
        int PlayerC[22];            // 22 aces = 22, max cards
        int DealerC[22];
 
        // dealer draws first
        puts("dealer draws his card...\n");
        puts("waiting....\n");
        sleep_ms(750);
        int dealerCardCount = 2;
        DealerC[0] = drawcard();
        DealerC[1] = drawcard();
        sleep_ms(500);
 
        // player's turn
        puts("\nYour turn ... \n");
        sleep_ms(750);
        int playerCardCount = 2;
        PlayerC[0] = drawcard();
        PlayerC[1] = drawcard();
        puts("dealer cards:   |"); putint(DealerC[0]); puts("| , |--|\n");
        puts("Player's cards: |"); putint(PlayerC[0]); puts("| , |"); putint(PlayerC[1]); puts("|\n");
        int playerTotal = TOT(PlayerC, 2);
        puts("        Total: "); putint(playerTotal); puts("\n");
 
        char choice;
        while (playerTotal <= 21) {     // until bust
            puts("Do you want to hit? (y/n): ");
            choice = getchoice();
            puts("\n");
            if (choice != 'y') break;
            PlayerC[playerCardCount++] = drawcard();
            puts("dealer cards:   |"); putint(DealerC[0]); puts("| , |--|\n");
            puts("Player's cards: ");
            for (int i = 0; i < playerCardCount; i++) {
                puts("|"); putint(PlayerC[i]); puts("| , ");
            }
            playerTotal = TOT(PlayerC, playerCardCount);
            puts("\nTotal: "); putint(playerTotal); puts("\n");
        }
 
        if (playerTotal > 21) {
            puts("\nPlayer busts! Dealer wins.\n");
            puts("\nDo you want to play again? (y/n): ");
            playAgain = getchoice();
            if (playAgain != 'y' && playAgain != 'Y' && playAgain != 'n' && playAgain != 'N')
                puts("Wrong input, ");
            else if (playAgain == 'n' || playAgain == 'N')
                break;
            puts("\n");
            continue;
        }
 
        while (TOT(DealerC, dealerCardCount) < 17) {   // dealer hits to 17
            DealerC[dealerCardCount++] = drawcard();
            puts("\nDealer's cards: ");
            for (int i = 0; i < dealerCardCount; ++i) {
                puts(" |"); putint(DealerC[i]); puts("| , ");
            }
            sleep_ms(500);
        }
 
        int dealerTotal = TOT(DealerC, dealerCardCount);
        puts("\nDealer's total: "); putint(dealerTotal); puts("\n");
        if (dealerTotal > 21 || playerTotal > dealerTotal) puts("\nPlayer wins!\n");
        else if (playerTotal < dealerTotal)                 puts("\nDealer wins.\n");
        else                                                puts("\nIt's a tie!\n");
 
        puts("\nDo you want to play again? (y/n): ");
        playAgain = getchoice();
        if (playAgain != 'y' && playAgain != 'Y' && playAgain != 'n' && playAgain != 'N')
            puts("Wrong input, ");
        else if (playAgain == 'n' || playAgain == 'N')
            break;
        puts("\n");
    }
 
    puts("\nthank you for playing!\n");
    return 0;                       // crt0 spins after main
}
