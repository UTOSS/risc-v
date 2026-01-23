#define LEDR ((volatile int*)0x10000000)

int main(void) {
    register int cnt = 0;

    while (1) {
        cnt = (cnt + 1) & 0x3FF;   
        *LEDR = cnt;               

        for (volatile int i = 0; i<1000000; i++){
            //delay
        }
    }

    return 0;
}