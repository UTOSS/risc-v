.section .text
.globl _start

_start:
   # your assembly code goes here!
   addi x1, x0, 5       # x1 = 5
   addi x2, x0, 10      # x2 = 10
   add  x3, x1, x2      # x3 = x1 + x2 = 15

done:
    j done
