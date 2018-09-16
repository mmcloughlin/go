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

// encryptBlocks8Ctr encrypts 8 counter blocks.
//go:noescape
func encryptBlocks8Ctr(nr int, xk *uint32, dst, ctr *byte)

// xorBytes xors the contents of a and b and places the resulting values into
// dst. If a and b are not the same length then the number of bytes processed
// will be equal to the length of shorter of the two. Returns the number
// of bytes processed.
//go:noescape
func xorBytes(dst, a, b []byte) int

// streamBufferSize is the number of bytes of encrypted counter values to cache.
const streamBufferSize = 32 * BlockSize

type aesctr struct {
	block   *aesCipherAsm          // block cipher
	nr      int                    // number of rounds
	ctr     [BlockSize]byte        // next value of the counter (big endian)
	buffer  []byte                 // buffer for the encrypted counter values
	storage [streamBufferSize]byte // array backing buffer slice
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
	ac.buffer = ac.storage[:0]
	return &ac
}

func (c *aesctr) refill() {
	c.buffer = c.storage[:streamBufferSize]
	for n := 0; n < streamBufferSize; n += 8 * BlockSize {
		encryptBlocks8Ctr(c.nr, &c.block.enc[0], &c.buffer[n], &c.ctr[0])
	}
}

func (c *aesctr) XORKeyStream(dst, src []byte) {
	if len(dst) < len(src) {
		panic("crypto/cipher: output smaller than input")
	}
	if subtle.InexactOverlap(dst[:len(src)], src) {
		panic("crypto/cipher: invalid buffer overlap")
	}
	for len(src) > 0 {
		if len(c.buffer) == 0 {
			c.refill()
		}
		n := xorBytes(dst, src, c.buffer)
		c.buffer = c.buffer[n:]
		src = src[n:]
		dst = dst[n:]
	}
}
