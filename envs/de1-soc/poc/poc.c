#define LEDR ((volatile int*)0x10000000)

static void delay(void) {
    volatile int i;
    for (i = 0; i < 1000000; i++) {
        // take some time
    }
}

int main(void) {
    int cnt = 0;

    while (1) {
        cnt = (cnt + 1) & 0x3FF;  // 10 bits
        *LEDR = cnt;              // update LED

        delay();   
    }

    return 0;
}