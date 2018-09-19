#include "textflag.h"
#include "iaca.h"

DATA bswap<>+0x00(SB)/8, $0x08090a0b0c0d0e0f
DATA bswap<>+0x08(SB)/8, $0x0001020304050607
GLOBL bswap<>(SB), (NOPTR+RODATA), $16

TEXT ·xorKeyStream(SB),0,$128-88
#define NR R8
	MOVQ     nr+0(FP), NR
#define XK AX
	MOVQ     xk+8(FP), XK
#define BUF_PTR BX
	MOVQ     buf_ptr+16(FP), BUF_PTR
#define BUF_LEN R9
	MOVQ     buf_len+24(FP), BUF_LEN
#define CTR CX
	MOVQ     ctr+40(FP), CTR
#define DST DI
	MOVQ     dst+48(FP), DST
#define SRC_PTR SI
	MOVQ     src_ptr+56(FP), SRC_PTR
#define SRC_LEN R10
	MOVQ     src_len+64(FP), SRC_LEN

// Working register setup.
#define T0 R11
#define T1 R12
#define C0 R13
#define C1 R14
#define B0 X0
#define B1 X1
#define B2 X2
#define B3 X3
#define B4 X4
#define B5 X5
#define B6 X6
#define B7 X7
#define KEY X8
#define BSWAP X9
	MOVOU    bswap<>(SB), BSWAP
#define TX X10

// Load counter values.
	MOVQ     0(CTR), C0
	BSWAPQ   C0
	MOVQ     8(CTR), C1
	BSWAPQ   C1

loop:
	CMPQ     SRC_LEN, $0
	JE       done

xor:
	CMPQ     BUF_LEN, $0
	JE       startenc8
	MOVB     (SRC_PTR), T0
	MOVB     (BUF_PTR), T1
	XORL     T0, T1
	MOVB     T1, (DST)
	INCQ     SRC_PTR
	DECQ     SRC_LEN
	INCQ     BUF_PTR
	DECQ     BUF_LEN
	INCQ     DST
	JMP      loop

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 16(SP)
	MOVQ     T0, 24(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 32(SP)
	MOVQ     T0, 40(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 48(SP)
	MOVQ     T0, 56(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 64(SP)
	MOVQ     T0, 72(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 80(SP)
	MOVQ     T0, 88(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 96(SP)
	MOVQ     T0, 104(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 112(SP)
	MOVQ     T0, 120(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

startenc8:

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 16(SP)
	MOVQ     T0, 24(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 32(SP)
	MOVQ     T0, 40(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 48(SP)
	MOVQ     T0, 56(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 64(SP)
	MOVQ     T0, 72(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 80(SP)
	MOVQ     T0, 88(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 96(SP)
	MOVQ     T0, 104(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 112(SP)
	MOVQ     T0, 120(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

enc8:
	CMPQ     SRC_LEN, $128
	JB       startenc4

// Snapshot counter values.
	ADDQ     $8, C1
	ADCQ     $0, C0

// Load block registers.
	MOVOU    0(SP), B0
	MOVOU    16(SP), B1
	MOVOU    32(SP), B2
	MOVOU    48(SP), B3
	MOVOU    64(SP), B4
	MOVOU    80(SP), B5
	MOVOU    96(SP), B6
	MOVOU    112(SP), B7
	PSHUFB   BSWAP, B0
	PSHUFB   BSWAP, B1
	PSHUFB   BSWAP, B2
	PSHUFB   BSWAP, B3
	PSHUFB   BSWAP, B4
	PSHUFB   BSWAP, B5
	PSHUFB   BSWAP, B6
	PSHUFB   BSWAP, B7

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 16(SP)
	MOVQ     T0, 24(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 32(SP)
	MOVQ     T0, 40(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 48(SP)
	MOVQ     T0, 56(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 64(SP)
	MOVQ     T0, 72(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 80(SP)
	MOVQ     T0, 88(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 96(SP)
	MOVQ     T0, 104(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 112(SP)
	MOVQ     T0, 120(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

// Initial key add.
	MOVOU    0(XK), KEY
	PXOR     KEY, B0
	PXOR     KEY, B1
	PXOR     KEY, B2
	PXOR     KEY, B3
	PXOR     KEY, B4
	PXOR     KEY, B5
	PXOR     KEY, B6
	PXOR     KEY, B7
	MOVOU    16(XK), KEY

// 9 rounds (all key sizes)
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    32(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    48(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    64(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    80(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    96(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    112(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    128(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    144(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    160(XK), KEY

// 2 more rounds (196- and 256-bit)
	CMPQ     NR, $12
	JB       lastenc8
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    176(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    192(XK), KEY

// 2 more rounds (256-bit only)
	JE       lastenc8
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    208(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	AESENC   KEY, B4
	AESENC   KEY, B5
	AESENC   KEY, B6
	AESENC   KEY, B7
	MOVOU    224(XK), KEY

lastenc8:
	AESENCLAST KEY, B0
	AESENCLAST KEY, B1
	AESENCLAST KEY, B2
	AESENCLAST KEY, B3
	AESENCLAST KEY, B4
	AESENCLAST KEY, B5
	AESENCLAST KEY, B6
	AESENCLAST KEY, B7

// XOR with src.
	MOVOU    0(SRC_PTR), TX
	PXOR     TX, B0
	MOVOU    B0, 0(DST)
	MOVOU    16(SRC_PTR), TX
	PXOR     TX, B1
	MOVOU    B1, 16(DST)
	MOVOU    32(SRC_PTR), TX
	PXOR     TX, B2
	MOVOU    B2, 32(DST)
	MOVOU    48(SRC_PTR), TX
	PXOR     TX, B3
	MOVOU    B3, 48(DST)
	MOVOU    64(SRC_PTR), TX
	PXOR     TX, B4
	MOVOU    B4, 64(DST)
	MOVOU    80(SRC_PTR), TX
	PXOR     TX, B5
	MOVOU    B5, 80(DST)
	MOVOU    96(SRC_PTR), TX
	PXOR     TX, B6
	MOVOU    B6, 96(DST)
	MOVOU    112(SRC_PTR), TX
	PXOR     TX, B7
	MOVOU    B7, 112(DST)
	ADDQ     $128, SRC_PTR
	SUBQ     $128, SRC_LEN
	ADDQ     $128, DST
	JMP      enc8

startenc4:

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 16(SP)
	MOVQ     T0, 24(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 32(SP)
	MOVQ     T0, 40(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 48(SP)
	MOVQ     T0, 56(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

enc4:
	CMPQ     SRC_LEN, $64
	JB       startenc2

// Snapshot counter values.
	ADDQ     $4, C1
	ADCQ     $0, C0

// Load block registers.
	MOVOU    0(SP), B0
	MOVOU    16(SP), B1
	MOVOU    32(SP), B2
	MOVOU    48(SP), B3
	PSHUFB   BSWAP, B0
	PSHUFB   BSWAP, B1
	PSHUFB   BSWAP, B2
	PSHUFB   BSWAP, B3

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 16(SP)
	MOVQ     T0, 24(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 32(SP)
	MOVQ     T0, 40(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 48(SP)
	MOVQ     T0, 56(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

// Initial key add.
	MOVOU    0(XK), KEY
	PXOR     KEY, B0
	PXOR     KEY, B1
	PXOR     KEY, B2
	PXOR     KEY, B3
	MOVOU    16(XK), KEY

// 9 rounds (all key sizes)
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    32(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    48(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    64(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    80(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    96(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    112(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    128(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    144(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    160(XK), KEY

// 2 more rounds (196- and 256-bit)
	CMPQ     NR, $12
	JB       lastenc4
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    176(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    192(XK), KEY

// 2 more rounds (256-bit only)
	JE       lastenc4
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    208(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	AESENC   KEY, B2
	AESENC   KEY, B3
	MOVOU    224(XK), KEY

lastenc4:
	AESENCLAST KEY, B0
	AESENCLAST KEY, B1
	AESENCLAST KEY, B2
	AESENCLAST KEY, B3

// XOR with src.
	MOVOU    0(SRC_PTR), TX
	PXOR     TX, B0
	MOVOU    B0, 0(DST)
	MOVOU    16(SRC_PTR), TX
	PXOR     TX, B1
	MOVOU    B1, 16(DST)
	MOVOU    32(SRC_PTR), TX
	PXOR     TX, B2
	MOVOU    B2, 32(DST)
	MOVOU    48(SRC_PTR), TX
	PXOR     TX, B3
	MOVOU    B3, 48(DST)
	ADDQ     $64, SRC_PTR
	SUBQ     $64, SRC_LEN
	ADDQ     $64, DST
	JMP      enc4

startenc2:

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 16(SP)
	MOVQ     T0, 24(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

enc2:
	CMPQ     SRC_LEN, $32
	JB       startenc1

// Snapshot counter values.
	ADDQ     $2, C1
	ADCQ     $0, C0

// Load block registers.
	MOVOU    0(SP), B0
	MOVOU    16(SP), B1
	PSHUFB   BSWAP, B0
	PSHUFB   BSWAP, B1

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0
	MOVQ     T1, 16(SP)
	MOVQ     T0, 24(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

// Initial key add.
	MOVOU    0(XK), KEY
	PXOR     KEY, B0
	PXOR     KEY, B1
	MOVOU    16(XK), KEY

// 9 rounds (all key sizes)
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    32(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    48(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    64(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    80(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    96(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    112(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    128(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    144(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    160(XK), KEY

// 2 more rounds (196- and 256-bit)
	CMPQ     NR, $12
	JB       lastenc2
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    176(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    192(XK), KEY

// 2 more rounds (256-bit only)
	JE       lastenc2
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    208(XK), KEY
	AESENC   KEY, B0
	AESENC   KEY, B1
	MOVOU    224(XK), KEY

lastenc2:
	AESENCLAST KEY, B0
	AESENCLAST KEY, B1

// XOR with src.
	MOVOU    0(SRC_PTR), TX
	PXOR     TX, B0
	MOVOU    B0, 0(DST)
	MOVOU    16(SRC_PTR), TX
	PXOR     TX, B1
	MOVOU    B1, 16(DST)
	ADDQ     $32, SRC_PTR
	SUBQ     $32, SRC_LEN
	ADDQ     $32, DST
	JMP      enc2

startenc1:

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

enc1:
	CMPQ     SRC_LEN, $16
	JB       startenc0

// Snapshot counter values.
	ADDQ     $1, C1
	ADCQ     $0, C0

// Load block registers.
	MOVOU    0(SP), B0
	PSHUFB   BSWAP, B0

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

// Initial key add.
	MOVOU    0(XK), KEY
	PXOR     KEY, B0
	MOVOU    16(XK), KEY

// 9 rounds (all key sizes)
	AESENC   KEY, B0
	MOVOU    32(XK), KEY
	AESENC   KEY, B0
	MOVOU    48(XK), KEY
	AESENC   KEY, B0
	MOVOU    64(XK), KEY
	AESENC   KEY, B0
	MOVOU    80(XK), KEY
	AESENC   KEY, B0
	MOVOU    96(XK), KEY
	AESENC   KEY, B0
	MOVOU    112(XK), KEY
	AESENC   KEY, B0
	MOVOU    128(XK), KEY
	AESENC   KEY, B0
	MOVOU    144(XK), KEY
	AESENC   KEY, B0
	MOVOU    160(XK), KEY

// 2 more rounds (196- and 256-bit)
	CMPQ     NR, $12
	JB       lastenc1
	AESENC   KEY, B0
	MOVOU    176(XK), KEY
	AESENC   KEY, B0
	MOVOU    192(XK), KEY

// 2 more rounds (256-bit only)
	JE       lastenc1
	AESENC   KEY, B0
	MOVOU    208(XK), KEY
	AESENC   KEY, B0
	MOVOU    224(XK), KEY

lastenc1:
	AESENCLAST KEY, B0

// XOR with src.
	MOVOU    0(SRC_PTR), TX
	PXOR     TX, B0
	MOVOU    B0, 0(DST)
	ADDQ     $16, SRC_PTR
	SUBQ     $16, SRC_LEN
	ADDQ     $16, DST
	JMP      enc1

// Less than a full block remains.

startenc0:
	CMPQ     SRC_LEN, $0
	JE       done

// Snapshot counter values.
	ADDQ     $1, C1
	ADCQ     $0, C0

// Load block registers.
	MOVOU    0(SP), B0
	PSHUFB   BSWAP, B0

// Stage counter blocks.
	MOVQ     C0, T0
	MOVQ     C1, T1
	MOVQ     T1, 0(SP)
	MOVQ     T0, 8(SP)
	ADDQ     $1, T1
	ADCQ     $0, T0

// Initial key add.
	MOVOU    0(XK), KEY
	PXOR     KEY, B0
	MOVOU    16(XK), KEY

// 9 rounds (all key sizes)
	AESENC   KEY, B0
	MOVOU    32(XK), KEY
	AESENC   KEY, B0
	MOVOU    48(XK), KEY
	AESENC   KEY, B0
	MOVOU    64(XK), KEY
	AESENC   KEY, B0
	MOVOU    80(XK), KEY
	AESENC   KEY, B0
	MOVOU    96(XK), KEY
	AESENC   KEY, B0
	MOVOU    112(XK), KEY
	AESENC   KEY, B0
	MOVOU    128(XK), KEY
	AESENC   KEY, B0
	MOVOU    144(XK), KEY
	AESENC   KEY, B0
	MOVOU    160(XK), KEY

// 2 more rounds (196- and 256-bit)
	CMPQ     NR, $12
	JB       lastenc0
	AESENC   KEY, B0
	MOVOU    176(XK), KEY
	AESENC   KEY, B0
	MOVOU    192(XK), KEY

// 2 more rounds (256-bit only)
	JE       lastenc0
	AESENC   KEY, B0
	MOVOU    208(XK), KEY
	AESENC   KEY, B0
	MOVOU    224(XK), KEY

lastenc0:
	AESENCLAST KEY, B0
	SUBQ     $16, BUF_PTR
	MOVOU    B0, (BUF_PTR)
	MOVQ     $16, BUF_LEN
	JMP      loop

done:

// Restore counter values.
	BSWAPQ   C0
	MOVQ     C0, 0(CTR)
	BSWAPQ   C1
	MOVQ     C1, 8(CTR)
	MOVQ     BUF_LEN, ret+80(FP)
	RET      
