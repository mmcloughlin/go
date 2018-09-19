// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package aes

import (
	"crypto/cipher"
	"crypto/internal/subtle"
)

// Assert that aesCipherAsm implements the ctrAble interface.
var _ ctrAble = (*aesCipherAsm)(nil)

// xorKeyStream encrypts/decrypts src into dst. Returns the number of bytes of the buffer that remain.
//go:noescape
func xorKeyStream(nr int, xk *uint32, buf []byte, ctr, dst *byte, src []byte) int

type aesctr struct {
	block   *aesCipherAsm   // block cipher
	nr      int             // number of rounds
	ctr     [BlockSize]byte // next value of the counter (big endian)
	buf     []byte          // buffer of remaining key stream
	storage [BlockSize]byte // storage for leftover key stream
}

// NewCTR returns a Stream which encrypts/decrypts using the AES block
// cipher in counter mode. The length of iv must be the same as BlockSize.
func (c *aesCipherAsm) NewCTR(iv []byte) cipher.Stream {
	if len(iv) != BlockSize {
		panic("cipher.NewCTR: IV length must equal block size")
	}
	var ac aesctr
	ac.block = c
	ac.nr = len(c.enc)/4 - 1
	copy(ac.ctr[:], iv)
	ac.buf = ac.storage[BlockSize:]
	return &ac
}

func (c *aesctr) XORKeyStream(dst, src []byte) {
	if len(dst) < len(src) {
		panic("crypto/cipher: output smaller than input")
	}
	if subtle.InexactOverlap(dst[:len(src)], src) {
		panic("crypto/cipher: invalid buffer overlap")
	}
	n := xorKeyStream(c.nr, &c.block.enc[0], c.buf, &c.ctr[0], &dst[0], src)
	c.buf = c.storage[BlockSize-n:]
}
