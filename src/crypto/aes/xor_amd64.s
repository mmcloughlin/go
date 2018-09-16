// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "textflag.h"

// func xorBytes(dst, a, b []byte) int
TEXT ·xorBytes(SB),NOSPLIT,$0
	MOVQ	dst_base+0(FP), DI
	MOVQ	a_base+24(FP), SI
	MOVQ	a_len+32(FP), R8
	MOVQ	b_base+48(FP), BX
	MOVQ	b_len+56(FP), R9

	CMPQ	R8, R9
	JLE		skip
	MOVQ	R9, R8
skip:
	MOVQ	R8, ret+72(FP)
	XORQ	CX, CX
	CMPQ	R8, $16
	JL		tail
loop:
	MOVOU	(SI)(CX*1), X1
	MOVOU	(BX)(CX*1), X2
	PXOR	X1, X2
	MOVOU	X2, 0(DI)(CX*1)
	ADDQ	$16, CX
	SUBQ	$16, R8
	CMPQ	R8, $16
	JGE		loop
tail:
	CMPQ	R8, $0
	JE		done
	MOVB	(SI)(CX*1), R10
	MOVB	(BX)(CX*1), R11
	XORL	R10, R11
	MOVB	R11B, (DI)(CX*1)
	INCQ	CX
	DECQ	R8
	JMP		tail
done:
	RET
