#define LEDR ((volatile int*)0x10000000)

int main() {
  int cnt = 0;
  cnt += 42;
  cnt += 22;
  *LEDR = cnt;
  return 0;
}
