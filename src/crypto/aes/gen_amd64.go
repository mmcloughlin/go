// +build ignore

package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
)

// cleanup:
// 1. convert buf and n into a slice
// 2. "block" alloc() method
// 3. store tmp vars in the struct somewhere
// 4. use CTR_LO and CTR_HI #defines
// 5. load/restore of counters can be done once for the whole function, not just in Encrypt()
// 6. unify use of jmp instructions? JB vs JLT
// 7. handling of last sub-block is inelegant
// 8. distinguish between tmp general purpose and tmp X register (T0, T1, TX)

// things to try:
// 1. prepare counters in advance

type AES struct {
	w io.Writer
	n int
}

func NewAES(w io.Writer) *AES {
	return &AES{
		w: w,
		n: 8,
	}
}

func (a *AES) Generate() error {
	a.header()
	a.data64("bswap", []uint64{0x08090a0b0c0d0e0f, 0x0001020304050607})
	a.text("xorKeyStream", a.n*16, 10*8+8)

	// func xorKeyStream(nr int, xk *uint32, buf []byte, ctr, dst *byte, src []byte) int
	a.arg("nr", 0, "R8")
	a.arg("xk", 8, "AX")
	a.arg("buf_ptr", 16, "BX")
	a.arg("buf_len", 24, "R9")
	a.arg("ctr", 40, "CX")
	a.arg("dst", 48, "DI")
	a.arg("src_ptr", 56, "SI")
	a.arg("src_len", 64, "R10")

	a.section("Working register setup.")
	a.alloc("T0", "R11")
	a.alloc("T1", "R12")

	a.alloc("C0", "R13")
	a.alloc("C1", "R14")

	for i := 0; i < a.n; i++ {
		a.alloc("B"+strconv.Itoa(i), "X"+strconv.Itoa(i))
	}

	a.alloc("KEY", "X"+strconv.Itoa(a.n))

	a.alloc("BSWAP", "X"+strconv.Itoa(a.n+1))
	a.inst("MOVOU", "bswap<>(SB), BSWAP")

	a.alloc("TX", "X"+strconv.Itoa(a.n+2))

	a.section("Load counter values.")
	for i := 0; i < 2; i++ {
		a.inst("MOVQ", "%d(CTR), C%d", 8*i, i)
		a.inst("BSWAPQ", "C%d", i)
	}

	// for len(src) > 0"
	a.label("loop")
	a.inst("CMPQ", "SRC_LEN, $0")
	a.inst("JE", "done")

	// if n > 0
	a.label("xor")
	a.inst("CMPQ", "BUF_LEN, $0")
	a.inst("JE", "startenc8")

	a.inst("MOVB", "(SRC_PTR), T0")
	a.inst("MOVB", "(BUF_PTR), T1")
	a.inst("XORL", "T0, T1")
	a.inst("MOVB", "T1, (DST)")
	a.inst("INCQ", "SRC_PTR")
	a.inst("DECQ", "SRC_LEN")
	a.inst("INCQ", "BUF_PTR")
	a.inst("DECQ", "BUF_LEN")
	a.inst("INCQ", "DST")
	a.inst("JMP", "loop")

	// encrypt successively fewer blocks at a time
	a.StageCounterBlocks(a.n)
	for n := a.n; n > 0; n /= 2 {
		name := "enc" + strconv.Itoa(n)
		a.label("start" + name)
		a.StageCounterBlocks(n)
		a.label(name)
		a.inst("CMPQ", "SRC_LEN, $%d", n*16)
		a.inst("JB", "startenc"+strconv.Itoa(n/2))
		a.Encrypt(n, name)
		a.Xor(n)
		a.inst("JMP", name)
	}

	a.section("Less than a full block remains.")
	a.label("startenc0")
	a.inst("CMPQ", "SRC_LEN, $0")
	a.inst("JE", "done")

	a.Encrypt(1, "enc0")

	a.inst("SUBQ", "$16, BUF_PTR")
	a.inst("MOVOU", "B0, (BUF_PTR)")
	a.inst("MOVQ", "$16, BUF_LEN")
	a.inst("JMP", "loop")

	// Exit
	a.label("done")

	a.section("Restore counter values.")
	for i := 0; i < 2; i++ {
		a.inst("BSWAPQ", "C%d", i)
		a.inst("MOVQ", "C%d, %d(CTR)", i, 8*i)
	}

	a.inst("MOVQ", "BUF_LEN, ret+80(FP)")
	a.inst("RET", "")

	return nil
}

// StageCounterBlocks loads the next set of counter blocks into the stack.
func (a *AES) StageCounterBlocks(n int) {
	a.section("Stage counter blocks.")
	a.inst("MOVQ", "C0, T0")
	a.inst("MOVQ", "C1, T1")
	for i := 0; i < n; i++ {
		a.inst("MOVQ", "T1, %d(SP)", 16*i)
		a.inst("MOVQ", "T0, %d(SP)", 16*i+8)
		a.inst("ADDQ", "$1, T1")
		a.inst("ADCQ", "$0, T0")
	}
}

// Encrypt encrypts n counter blocks.
func (a *AES) Encrypt(n int, name string) {
	if n == 8 {
		//a.inst("IACA_START", "")
	}

	a.section("Snapshot counter values.")
	a.inst("ADDQ", "$%d, C1", n)
	a.inst("ADCQ", "$0, C0")

	a.section("Load block registers.")
	for i := 0; i < n; i++ {
		a.inst("MOVOU", "%d(SP), B%d", 16*i, i)
	}
	for i := 0; i < n; i++ {
		a.inst("PSHUFB", "BSWAP, B%d", i)
	}

	a.StageCounterBlocks(n)

	a.section("Initial key add.")
	a.inst("MOVOU", "0(XK), KEY")
	for i := 0; i < n; i++ {
		a.inst("PXOR", "KEY, B%d", i)
	}
	a.inst("MOVOU", "16(XK), KEY")

	a.section("9 rounds (all key sizes)")
	for r := 1; r < 10; r++ {
		for i := 0; i < n; i++ {
			a.inst("AESENC", "KEY, B%d", i)
		}
		a.inst("MOVOU", "%d(XK), KEY", 16*(r+1))
	}

	a.section("2 more rounds (196- and 256-bit)")
	a.inst("CMPQ", "NR, $12")
	last := "last" + name
	a.inst("JB", last)

	for r := 10; r < 12; r++ {
		for i := 0; i < n; i++ {
			a.inst("AESENC", "KEY, B%d", i)
		}
		a.inst("MOVOU", "%d(XK), KEY", 16*(r+1))
	}

	a.section("2 more rounds (256-bit only)")
	a.inst("JE", last)

	for r := 12; r < 14; r++ {
		for i := 0; i < n; i++ {
			a.inst("AESENC", "KEY, B%d", i)
		}
		a.inst("MOVOU", "%d(XK), KEY", 16*(r+1))
	}

	a.label(last)
	for i := 0; i < n; i++ {
		a.inst("AESENCLAST", "KEY, B%d", i)
	}

	if n == 8 {
		//a.inst("IACA_END", "")
	}
}

// Xor xors n blocks into src and writes to dst.
func (a *AES) Xor(n int) {
	a.section("XOR with src.")
	for i := 0; i < n; i++ {
		a.inst("MOVOU", "%d(SRC_PTR), TX", 16*i)
		a.inst("PXOR", "TX, B%d", i)
		a.inst("MOVOU", "B%d, %d(DST)", i, 16*i)
	}

	a.inst("ADDQ", "$%d, SRC_PTR", 16*n)
	a.inst("SUBQ", "$%d, SRC_LEN", 16*n)
	a.inst("ADDQ", "$%d, DST", 16*n)
}

func (a *AES) header() {
	fmt.Fprint(a.w, "#include \"textflag.h\"\n")
	fmt.Fprint(a.w, "#include \"iaca.h\"\n")
}

func (a *AES) data64(name string, x []uint64) {
	for i := range x {
		fmt.Fprintf(a.w, "\nDATA %s<>+0x%02x(SB)/8, $0x%016x", name, 8*i, x[i])
	}
	fmt.Fprintf(a.w, "\nGLOBL %s<>(SB), (NOPTR+RODATA), $%d\n", name, 8*len(x))
}

func (a *AES) section(description string) {
	fmt.Fprintf(a.w, "\n// %s\n", description)
}

func (a *AES) label(name string) {
	fmt.Fprintf(a.w, "\n%s:\n", name)
}

func (a *AES) text(name string, frame, args int) {
	fmt.Fprintf(a.w, "\nTEXT \u00b7%s(SB),0,$%d-%d\n", name, frame, args)
}

func (a *AES) alloc(name, reg string) string {
	macro := strings.ToUpper(name)
	fmt.Fprintf(a.w, "#define %s %s\n", macro, reg)
	return macro
}

func (a *AES) arg(name string, offset int, reg string) {
	macro := a.alloc(name, reg)
	a.inst("MOVQ", "%s+%d(FP), %s", name, offset, macro)
}

func (a *AES) inst(name, format string, args ...interface{}) {
	args = append([]interface{}{name}, args...)
	fmt.Fprintf(a.w, "\t%-8s "+format+"\n", args...)
}

func main() {
	a := NewAES(os.Stdout)
	err := a.Generate()
	if err != nil {
		log.Fatal(err)
	}
}
