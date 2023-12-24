imm.s:
.align 4
.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:

    li x1, 7
    li x2, 12
    li x3, 15
    li x4, 127
    add x5, x1, x2
    sub x5, x1, x2
    addi x7, x1, 5
    lui x6, %hi(space)
    auipc	x7,0x0
    lw x5,0(x7)
    lw x5,0(x6)
    add x5,x7,x5
    add x5,x7,x6
    addi x6,x6,%lo(space)
    sh x5, 0(x6)
    lh x7, 0(x6)
    la x10, result      # X10 <= Addr[result]
    addi x10, x10,12
    addi x0, x10, 18
    addi x7, x0, 0

    slt x3, x2, x1

    sub x3,x3,x3
    sub x4, x4, x4
    addi x4, x4, 4
    
lol:
    addi x3, x3, 1
    bne x3, x4, lol
    la x5, half
    lh x6, 0(x5)
    lhu x7, 0(x5)
    lb x8, 1(x5)
    lbu x9, 1(x5)
    sw x7, 4(x5)
    sw x8, 8(x5)



    li  t0, 1
    lui t1, %hi(tohost)
    addi t1, t1, %lo(tohost)

    sw  t0, 0(t1)
    sw  x0, 4(t1)

halt:                 # Infinite loop to keep
    beq x0, x0, halt  # from trying to execute the data below.
                      # Your own programs should also make use
                      # of an infinite loop at the end.

deadend:
    lw x8, bad     # X8 <= 0xdeadbeef
deadloop:
    beq x8, x8, deadloop

.section .rodata

bad:        .word 0xdeadbeef
threshold:  .word 0x00000040
result:     .word 0x00000000
good:       .word 0x600d600d
half:       .word 0xFFFFF000
h1:         .word 0x00000000
h2:         .word 0x00000000

space:      .word 0x00000000

.section ".tohost"
.globl tohost
tohost: .dword 0
.section ".fromhost"
.globl fromhost
fromhost: .dword 0
