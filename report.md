# AES-CTR in Assembly

## Background

The long-outstanding [Golang issue #20967](https://golang.org/issue/20967)
points out that AES-CTR mode has unacceptable performance, and could benefit
massively from acceleration with [native AES
instructions](https://en.wikipedia.org/wiki/AES_instruction_set). Two CLs
have been offered to address the issue
([#51670](https://golang.org/cl/51670),
[#51790](https://golang.org/cl/51790)) but neither of them achieve peak
performance. Let's see if we can do better with assembly that's more
reviewable than the [1200+ line AES-GCM mode
implementation](https://github.com/golang/go/blob/1bf5796cae9e8f7b55402f199a1eec82a092abb7/src/crypto/aes/gcm_amd64.s).

## Baseline

Let's take a baseline with a fresh development version of Go

```
$ ./bin/go version
go version devel +1bf5796cae Sat Sep 15 09:25:07 2018 +0000 darwin/amd64
```

We are interested in AES benchmarks for both `CTR` and `GCM` modes, as we
should expect to be able to match or exceed GCM performance.

```
$ ./bin/go test -run NONE -bench 'AES(CTR|GCM).*1K' crypto/cipher
goos: darwin
goarch: amd64
pkg: crypto/cipher
BenchmarkAESGCMSeal1K-4   	 5000000	       265 ns/op	3857.32 MB/s
BenchmarkAESGCMOpen1K-4   	 5000000	       245 ns/op	4164.26 MB/s
BenchmarkAESCTR1K-4       	 1000000	      1281 ns/op	 795.08 MB/s
PASS
ok  	crypto/cipher	4.404s
```

## Existing CLs

Performance of the existing CLs...

What's wrong with them? Analysis: look at `pprof -svg` and `pprof -list=encrypt`. If we count up time in instruction types we get

   90550.0	PSHUFB
   13720.0	MOVUPS
   10480.0	AESENC
    5380.0	MOVQ
    1380.0	AESENCLAST
    1360.0	MOVOU
    1200.0	PXOR
    1190.0	BSWAPQ
    1020.0	ADDQ
     630.0	JB
     510.0	RET
      10.0	ADCQ
       0.0	SUBQ
       0.0	JE

Not sure why so much of the time is in PSHUFB!?

1. A lot of time in PSHUFB? Not really?
2. Memory access

## How does the GCM mode work?

The `gcmAesEnc` function does this.

* Batches of 8 first.
* Single blocks.
* Then the tail end.

## After optimization

count up time in instruction types

    1520.0	AESENC
     730.0	MOVOU
     180.0	AESENCLAST
     150.0	PSHUFB
     150.0	MOVQ
     140.0	ADDQ
      90.0	ADCQ

## Reference

* [Intel Intrinsics Guide](https://software.intel.com/sites/landingpage/IntrinsicsGuide/)
* [X86 Registers](https://en.wikibooks.org/wiki/X86_Assembly/16_32_and_64_Bits) and their [oddities in Go](https://quasilyte.github.io/blog/post/go-asm-complementary-reference/#register-names)

---

## Listing of encryptBlocks8Ctr

Total: 2.65mins
ROUTINE ======================== crypto/aes.encryptBlocks8Ctr in /Users/michaelmcloughlin/Development/go/src/crypto/aes/ctr_amd64.s
  2.15mins   2.15mins (flat, cum) 80.99% of Total
         .          .      3:DATA bswapMask<>+0x00(SB)/8, $0x08090a0b0c0d0e0f
         .          .      4:DATA bswapMask<>+0x08(SB)/8, $0x0001020304050607
         .          .      5:GLOBL bswapMask<>(SB), (NOPTR+RODATA), $16
         .          .      6:
         .          .      7:// func encryptBlocks8Ctr(nr int, xk *uint32, dst, ctr *byte)
     1.47s      1.48s      8:TEXT ·encryptBlocks8Ctr(SB),0,$128-32
     430ms      430ms      9:	MOVQ nr+0(FP), CX
     100ms      100ms     10:	MOVQ xk+8(FP), AX
         .          .     11:	MOVQ dst+16(FP), DX
     110ms      110ms     12:	MOVQ ctr+24(FP), BX
     400ms      400ms     13:	MOVQ 0(BX), R8
     110ms      110ms     14:	MOVQ 8(BX), R9
      20ms       20ms     15:	BSWAPQ R8
     690ms      690ms     16:	BSWAPQ R9
     230ms      230ms     17:	MOVOU bswapMask<>(SB), X9
     120ms      120ms     18:	MOVQ R9, 0(SP)
     460ms      460ms     19:	MOVQ R8, 8(SP)
     130ms      130ms     20:	MOVOU 0(SP), X0
    12.07s     12.07s     21:	PSHUFB X9, X0
     220ms      220ms     22:	ADDQ $1, R9
         .          .     23:	ADCQ $0, R8
         .          .     24:	MOVQ R9, 16(SP)
     280ms      280ms     25:	MOVQ R8, 24(SP)
     180ms      180ms     26:	MOVOU 16(SP), X1
    10.65s     10.65s     27:	PSHUFB X9, X1
     260ms      260ms     28:	ADDQ $1, R9
         .          .     29:	ADCQ $0, R8
         .          .     30:	MOVQ R9, 32(SP)
     280ms      280ms     31:	MOVQ R8, 40(SP)
     320ms      320ms     32:	MOVOU 32(SP), X2
    10.43s     10.43s     33:	PSHUFB X9, X2
     210ms      210ms     34:	ADDQ $1, R9
      10ms       10ms     35:	ADCQ $0, R8
         .          .     36:	MOVQ R9, 48(SP)
     380ms      380ms     37:	MOVQ R8, 56(SP)
     150ms      150ms     38:	MOVOU 48(SP), X3
    10.64s     10.64s     39:	PSHUFB X9, X3
     170ms      170ms     40:	ADDQ $1, R9
         .          .     41:	ADCQ $0, R8
         .          .     42:	MOVQ R9, 64(SP)
     500ms      500ms     43:	MOVQ R8, 72(SP)
     160ms      160ms     44:	MOVOU 64(SP), X4
    11.27s     11.27s     45:	PSHUFB X9, X4
      60ms       60ms     46:	ADDQ $1, R9
         .          .     47:	ADCQ $0, R8
         .          .     48:	MOVQ R9, 80(SP)
     580ms      580ms     49:	MOVQ R8, 88(SP)
      80ms       80ms     50:	MOVOU 80(SP), X5
    11.61s     11.61s     51:	PSHUFB X9, X5
      50ms       50ms     52:	ADDQ $1, R9
         .          .     53:	ADCQ $0, R8
         .          .     54:	MOVQ R9, 96(SP)
     580ms      580ms     55:	MOVQ R8, 104(SP)
      50ms       50ms     56:	MOVOU 96(SP), X6
    11.77s     11.77s     57:	PSHUFB X9, X6
      30ms       30ms     58:	ADDQ $1, R9
         .          .     59:	ADCQ $0, R8
         .          .     60:	MOVQ R9, 112(SP)
     490ms      490ms     61:	MOVQ R8, 120(SP)
      60ms       60ms     62:	MOVOU 112(SP), X7
    12.11s     12.11s     63:	PSHUFB X9, X7
      20ms       20ms     64:	ADDQ $1, R9
         .          .     65:	ADCQ $0, R8
         .          .     66:	BSWAPQ R8
     480ms      480ms     67:	BSWAPQ R9
         .          .     68:	MOVQ R8, 0(BX)
     560ms      560ms     69:	MOVQ R9, 8(BX)
      40ms       40ms     70:	MOVUPS 0(AX), X8
         .          .     71:	PXOR X8, X0
         .          .     72:	PXOR X8, X1
     720ms      720ms     73:	PXOR X8, X2
      10ms       10ms     74:	PXOR X8, X3
         .          .     75:	PXOR X8, X4
         .          .     76:	PXOR X8, X5
     460ms      460ms     77:	PXOR X8, X6
      10ms       10ms     78:	PXOR X8, X7
         .          .     79:	ADDQ $16, AX
         .          .     80:	SUBQ $12, CX
         .          .     81:	JE Lenc192
     630ms      630ms     82:	JB Lenc128
         .          .     83:Lenc256:
         .          .     84:	MOVUPS 0(AX), X8
         .          .     85:	AESENC X8, X0
         .          .     86:	AESENC X8, X1
         .          .     87:	AESENC X8, X2
         .          .     88:	AESENC X8, X3
         .          .     89:	AESENC X8, X4
         .          .     90:	AESENC X8, X5
         .          .     91:	AESENC X8, X6
         .          .     92:	AESENC X8, X7
         .          .     93:	MOVUPS 16(AX), X8
         .          .     94:	AESENC X8, X0
         .          .     95:	AESENC X8, X1
         .          .     96:	AESENC X8, X2
         .          .     97:	AESENC X8, X3
         .          .     98:	AESENC X8, X4
         .          .     99:	AESENC X8, X5
         .          .    100:	AESENC X8, X6
         .          .    101:	AESENC X8, X7
         .          .    102:	ADDQ $32, AX
         .          .    103:Lenc192:
         .          .    104:	MOVUPS 0(AX), X8
         .          .    105:	AESENC X8, X0
         .          .    106:	AESENC X8, X1
         .          .    107:	AESENC X8, X2
         .          .    108:	AESENC X8, X3
         .          .    109:	AESENC X8, X4
         .          .    110:	AESENC X8, X5
         .          .    111:	AESENC X8, X6
         .          .    112:	AESENC X8, X7
         .          .    113:	MOVUPS 16(AX), X8
         .          .    114:	AESENC X8, X0
         .          .    115:	AESENC X8, X1
         .          .    116:	AESENC X8, X2
         .          .    117:	AESENC X8, X3
         .          .    118:	AESENC X8, X4
         .          .    119:	AESENC X8, X5
         .          .    120:	AESENC X8, X6
         .          .    121:	AESENC X8, X7
         .          .    122:	ADDQ $32, AX
         .          .    123:Lenc128:
      30ms       30ms    124:	MOVUPS 0(AX), X8
      10ms       10ms    125:	AESENC X8, X0
      10ms       10ms    126:	AESENC X8, X1
     550ms      550ms    127:	AESENC X8, X2
      20ms       20ms    128:	AESENC X8, X3
         .          .    129:	AESENC X8, X4
         .          .    130:	AESENC X8, X5
     580ms      580ms    131:	AESENC X8, X6
      10ms       10ms    132:	AESENC X8, X7
         .          .    133:	MOVUPS 16(AX), X8
         .          .    134:	AESENC X8, X0
     490ms      490ms    135:	AESENC X8, X1
      30ms       30ms    136:	AESENC X8, X2
         .          .    137:	AESENC X8, X3
         .          .    138:	AESENC X8, X4
     480ms      480ms    139:	AESENC X8, X5
      10ms       10ms    140:	AESENC X8, X6
         .          .    141:	AESENC X8, X7
      20ms       20ms    142:	MOVUPS 32(AX), X8
     530ms      530ms    143:	AESENC X8, X0
         .          .    144:	AESENC X8, X1
         .          .    145:	AESENC X8, X2
      10ms       10ms    146:	AESENC X8, X3
     380ms      380ms    147:	AESENC X8, X4
      30ms       30ms    148:	AESENC X8, X5
         .          .    149:	AESENC X8, X6
      30ms       30ms    150:	AESENC X8, X7
     1.56s      1.56s    151:	MOVUPS 48(AX), X8
         .          .    152:	AESENC X8, X0
         .          .    153:	AESENC X8, X1
         .          .    154:	AESENC X8, X2
     610ms      610ms    155:	AESENC X8, X3
      10ms       10ms    156:	AESENC X8, X4
         .          .    157:	AESENC X8, X5
         .          .    158:	AESENC X8, X6
     520ms      520ms    159:	AESENC X8, X7
     1.64s      1.64s    160:	MOVUPS 64(AX), X8
         .          .    161:	AESENC X8, X0
         .          .    162:	AESENC X8, X1
         .          .    163:	AESENC X8, X2
     540ms      540ms    164:	AESENC X8, X3
      10ms       10ms    165:	AESENC X8, X4
      10ms       10ms    166:	AESENC X8, X5
         .          .    167:	AESENC X8, X6
     510ms      510ms    168:	AESENC X8, X7
     1.76s      1.76s    169:	MOVUPS 80(AX), X8
         .          .    170:	AESENC X8, X0
         .          .    171:	AESENC X8, X1
         .          .    172:	AESENC X8, X2
     690ms      690ms    173:	AESENC X8, X3
         .          .    174:	AESENC X8, X4
         .          .    175:	AESENC X8, X5
         .          .    176:	AESENC X8, X6
     500ms      500ms    177:	AESENC X8, X7
     1.50s      1.50s    178:	MOVUPS 96(AX), X8
         .          .    179:	AESENC X8, X0
         .          .    180:	AESENC X8, X1
      10ms       10ms    181:	AESENC X8, X2
     620ms      620ms    182:	AESENC X8, X3
      10ms       10ms    183:	AESENC X8, X4
         .          .    184:	AESENC X8, X5
      10ms       10ms    185:	AESENC X8, X6
     540ms      540ms    186:	AESENC X8, X7
     1.69s      1.69s    187:	MOVUPS 112(AX), X8
         .          .    188:	AESENC X8, X0
         .          .    189:	AESENC X8, X1
      10ms       10ms    190:	AESENC X8, X2
     690ms      690ms    191:	AESENC X8, X3
         .          .    192:	AESENC X8, X4
         .          .    193:	AESENC X8, X5
      20ms       20ms    194:	AESENC X8, X6
     590ms      590ms    195:	AESENC X8, X7
     1.75s      1.75s    196:	MOVUPS 128(AX), X8
      20ms       20ms    197:	AESENC X8, X0
      30ms       30ms    198:	AESENC X8, X1
      40ms       40ms    199:	AESENC X8, X2
     570ms      570ms    200:	AESENC X8, X3
      40ms       40ms    201:	AESENC X8, X4
      90ms       90ms    202:	AESENC X8, X5
         .          .    203:	AESENC X8, X6
     620ms      620ms    204:	AESENC X8, X7
     1.72s      1.72s    205:	MOVUPS 144(AX), X8
      50ms       50ms    206:	AESENCLAST X8, X0
      30ms       30ms    207:	AESENCLAST X8, X1
      50ms       50ms    208:	AESENCLAST X8, X2
     550ms      550ms    209:	AESENCLAST X8, X3
      60ms       60ms    210:	AESENCLAST X8, X4
      60ms       60ms    211:	AESENCLAST X8, X5
      30ms       30ms    212:	AESENCLAST X8, X6
     550ms      550ms    213:	AESENCLAST X8, X7
     1.42s      1.42s    214:	MOVUPS X0, 0(DX)
      30ms       30ms    215:	MOVUPS X1, 16(DX)
         .          .    216:	MOVUPS X2, 32(DX)
      10ms       10ms    217:	MOVUPS X3, 48(DX)
     490ms      490ms    218:	MOVUPS X4, 64(DX)
      60ms       60ms    219:	MOVUPS X5, 80(DX)
         .          .    220:	MOVUPS X6, 96(DX)
         .          .    221:	MOVUPS X7, 112(DX)
     510ms      510ms    222:	RET
         .          .    223:

## Existing Patch

// Copyright 2017 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "textflag.h"

DATA bswapMask<>+0x00(SB)/8, $0x08090a0b0c0d0e0f
DATA bswapMask<>+0x08(SB)/8, $0x0001020304050607
GLOBL bswapMask<>(SB), (NOPTR+RODATA), $16

// func fillEightBlocks(nr int, xk *uint32, dst, counter *byte)
TEXT ·fillEightBlocks(SB),0,$112-32
#define BSWAP X2
#define aesRound AESENC X1, X8; AESENC X1, X9; AESENC X1, X10; AESENC X1, X11; \
                 AESENC X1, X12; AESENC X1, X13; AESENC X1, X14; AESENC X1, X15;
#define increment(i) ADDQ $1, R9; ADCQ $0, R8; \
                     MOVQ R9, (i*16)(SP); MOVQ R8, (i*16+8)(SP);
	MOVQ nr+0(FP), CX
	MOVQ xk+8(FP), AX
	MOVQ dst+16(FP), DX
	MOVQ counter+24(FP), BX
	MOVOU 0(AX), X1
	MOVOU bswapMask<>(SB), BSWAP
	ADDQ $16, AX

	MOVOU 0(BX), X8
	MOVQ 0(BX), R8
	MOVQ 8(BX), R9
	BSWAPQ R8
	BSWAPQ R9

	increment(0)
	increment(1)
	increment(2)
	increment(3)
	increment(4)
	increment(5)
	increment(6)

	ADDQ $1, R9
	ADCQ $0, R8
	BSWAPQ R8
	BSWAPQ R9
	MOVQ R8, 0(BX)
	MOVQ R9, 8(BX)

	MOVOU 0(SP), X9
	MOVOU 16(SP), X10
	MOVOU 32(SP), X11
	MOVOU 48(SP), X12
	MOVOU 64(SP), X13
	MOVOU 80(SP), X14
	MOVOU 96(SP), X15
	PSHUFB BSWAP, X9
	PSHUFB BSWAP, X10
	PSHUFB BSWAP, X11
	PSHUFB BSWAP, X12
	PSHUFB BSWAP, X13
	PSHUFB BSWAP, X14
	PSHUFB BSWAP, X15

	PXOR X1, X8
	PXOR X1, X9
	PXOR X1, X10
	PXOR X1, X11
	PXOR X1, X12
	PXOR X1, X13
	PXOR X1, X14
	PXOR X1, X15

	SUBQ $12, CX
	JE Lenc196
	JB Lenc128
Lenc256:
	MOVOU 0(AX), X1
	aesRound
	MOVOU 16(AX), X1
	aesRound
	ADDQ $32, AX
Lenc196:
	MOVOU 0(AX), X1
	aesRound
	MOVOU 16(AX), X1
	aesRound
	ADDQ $32, AX
Lenc128:
	MOVOU 0(AX), X1
	aesRound
	MOVOU 16(AX), X1
	aesRound
	MOVOU 32(AX), X1
	aesRound
	MOVOU 48(AX), X1
	aesRound
	MOVOU 64(AX), X1
	aesRound
	MOVOU 80(AX), X1
	aesRound
	MOVOU 96(AX), X1
	aesRound
	MOVOU 112(AX), X1
	aesRound
	MOVOU 128(AX), X1
	aesRound
	MOVOU 144(AX), X1

	AESENCLAST X1, X8
	AESENCLAST X1, X9
	AESENCLAST X1, X10
	AESENCLAST X1, X11
	AESENCLAST X1, X12
	AESENCLAST X1, X13
	AESENCLAST X1, X14
	AESENCLAST X1, X15

	MOVOU X8, 0(DX)
	MOVOU X9, 16(DX)
	MOVOU X10, 32(DX)
	MOVOU X11, 48(DX)
	MOVOU X12, 64(DX)
	MOVOU X13, 80(DX)
	MOVOU X14, 96(DX)
	MOVOU X15, 112(DX)
	RET

// func xorBytes(dst, a, b []byte) int
TEXT ·xorBytes(SB),NOSPLIT,$0
	MOVQ dst_base+0(FP), DI
	MOVQ a_base+24(FP), SI
	MOVQ a_len+32(FP), R8
	MOVQ b_base+48(FP), BX
	MOVQ b_len+56(FP), R9
	CMPQ R8, R9
	JLE skip
	MOVQ R9, R8
skip:
	MOVQ R8, ret+72(FP)
	XORQ CX, CX
	CMPQ R8, $16
	JL tail
loop:
	MOVOU (SI)(CX*1), X1
	MOVOU (BX)(CX*1), X2
	PXOR X1, X2
	MOVOU X2, (DI)(CX*1)
	ADDQ $16, CX
	SUBQ $16, R8
	CMPQ R8, $16
	JGE loop
tail:
	CMPQ R8, $0
	JE done
	MOVBLZX (SI)(CX*1), R9
	MOVBLZX (BX)(CX*1), R10
	XORL R10, R9
	MOVB R9B, (DI)(CX*1)
	INCQ CX
	DECQ R8
	JMP tail
done:
	RET

## Scratch

Variables:

    src: ptr, len
    dst: ptr
    buf: base, ptr, rem
    ctr:
    aes: nr, key

Structure:

    while remaining src:
        if have buf:
            jmp xor
        if at least 8 blocks remain:
            encrypt 8 blocks and xor
            loop
        encrypt a block
        if at least a block remains:
            xor
            loop
        else:
            write to buffer
        xor
        loop


## Results

### Comparing n/d values

n=8 d=2

BenchmarkAESCTR1K-4   	100000000	       223 ns/op	4550.13 MB/s
BenchmarkAESCTR8K-4   	10000000	      1496 ns/op	5470.45 MB/s

n=8 d=4

BenchmarkAESCTR1K-4   	50000000	       250 ns/op	4068.13 MB/s
BenchmarkAESCTR8K-4   	10000000	      1536 ns/op	5328.09 MB/s

n=8 d=8

BenchmarkAESCTR1K-4   	50000000	       257 ns/op	3954.38 MB/s
BenchmarkAESCTR8K-4   	10000000	      1542 ns/op	5308.10 MB/s

n=4 d=2

BenchmarkAESCTR1K-4   	100000000	       225 ns/op	4520.62 MB/s
BenchmarkAESCTR8K-4   	10000000	      1494 ns/op	5479.76 MB/s

n=4 d=4

BenchmarkAESCTR1K-4   	50000000	       233 ns/op	4361.66 MB/s
BenchmarkAESCTR8K-4   	10000000	      1498 ns/op	5463.57 MB/s

n=2 d=2

BenchmarkAESCTR1K-4   	50000000	       341 ns/op	2986.21 MB/s
BenchmarkAESCTR8K-4   	 5000000	      2531 ns/op	3233.82 MB/s

### Placement of Stage

baseline

BenchmarkAESCTR1K-4   	100000000	       221 ns/op	4596.11 MB/s
BenchmarkAESCTR8K-4   	10000000	      1493 ns/op	5481.02 MB/s

after key add

BenchmarkAESCTR1K-4   	100000000	       223 ns/op	4557.63 MB/s
BenchmarkAESCTR8K-4   	10000000	      1492 ns/op	5486.74 MB/s

interleave

BenchmarkAESCTR1K-4   	100000000	       224 ns/op	4540.25 MB/s
BenchmarkAESCTR8K-4   	10000000	      1492 ns/op	5486.26 MB/s

last

BenchmarkAESCTR1K-4   	50000000	       269 ns/op	3774.32 MB/s
BenchmarkAESCTR8K-4   	10000000	      1783 ns/op	4590.69 MB/s