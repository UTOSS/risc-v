#define LEDR ((volatile int*)0x10000000)

int main() {
  int cnt = 0;
  *LEDR = 42 + 42;
  return 0;
}
