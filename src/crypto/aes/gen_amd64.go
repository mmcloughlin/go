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
	a.text("xorKeyStream", 0, 0)

	// func xorKeyStream(nr int, xk *uint32, buf *byte, n int, ctr, dst *byte, src []byte) int
	a.arg("nr", 0, "R8")
	a.arg("xk", 8, "AX")
	a.arg("buf", 16, "BX")
	a.arg("n", 24, "R9")
	a.arg("ctr", 32, "CX")
	a.arg("dst", 40, "DI")
	a.arg("src_base", 40, "SI")
	a.arg("src_len", 48, "R10")

	a.section("Working register setup.")
	t0 := a.alloc("T0", "R11")
	t1 := a.alloc("T1", "R12")

	for i := 0; i < a.n; i++ {
		a.alloc("B"+strconv.Itoa(i), "X"+strconv.Itoa(i))
	}

	a.alloc("KEY", "X"+strconv.Itoa(a.n))

	a.alloc("BSWAP", "X"+strconv.Itoa(a.n+1))
	a.inst("MOVOU", "bswap<>(SB), BSWAP")

	// for len(src) > 0"
	a.label("loop")
	a.inst("CMPQ", "SRC_LEN, $0")
	a.inst("JE", "done")

	// if n > 0
	a.label("xor")
	a.inst("CMPQ", "N, $0")
	a.inst("JE", "enc8")

	a.inst("MOVB", "(SRC_BASE), %s", t0)
	a.inst("MOVB", "(BUF), %s", t1)
	a.inst("XORL", "%s, %s", t0, t1)
	a.inst("MOVB", "%s, (DST)", t1)
	a.inst("INCQ", "SRC_BASE")
	a.inst("DECQ", "SRC_LEN")
	a.inst("INCQ", "BUF")
	a.inst("DECQ", "N")
	a.inst("JMP", "loop")

	// encrypt successively fewer blocks at a time
	for n := a.n; n > 1; n /= 2 {
		a.label("enc" + strconv.Itoa(n))
		a.inst("CMPQ", "SRC_LEN, $%d", n*16)
		a.inst("JL", "enc"+strconv.Itoa(n/2))
		a.Encrypt(n)
		a.inst("JMP", "enc"+strconv.Itoa(n))
	}

	// Exit
	a.label("done")
	a.inst("RET", "")

	return nil
}

func (a *AES) Encrypt(n int) {
	a.section("Load counter values.")
	for i := 0; i < 2; i++ {
		a.inst("MOVQ", "%d(CTR), T%d", 8*i, i)
		a.inst("BSWAP", "T%d", i)
	}

	a.section("Increment counter and populate block registers.")
	for i := 0; i < n; i++ {
		a.inst("MOVQ", "T1, %d(SP)", 16*i)
		a.inst("MOVQ", "T0, %d(SP)", 16*i+8)
		a.inst("MOVOU", "%d(SP), B%d", 16*i, i)
		a.inst("PSHUFB", "BSWAP, B%d", i)
		a.inst("ADDQ", "$1, T1")
		a.inst("ADCQ", "$0, T0")
	}

	a.section("Restore counter values.")
	for i := 0; i < 2; i++ {
		a.inst("BSWAP", "T%d", i)
		a.inst("MOVQ", "T%d, %d(CTR)", i, 8*i)
	}

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
	last := "lastround" + strconv.Itoa(n)
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

	a.section("XOR with src.")
	for i := 0; i < n; i++ {
		a.inst("MOVOU", "%d(SRC_BASE), T0", 16*i)
		a.inst("PXOR", "T0, B%d", i)
		a.inst("MOVOU", "B%d, %d(DST)", i, 16*i)
	}

	a.inst("ADDQ", "$%d, SRC_BASE", 16*n)
	a.inst("SUBQ", "$%d, SRC_BASE", 16*n)
	a.inst("ADDQ", "$%d, DST", 16*n)
}

func (a *AES) header() {
	fmt.Fprint(a.w, "#include \"textflag.h\"\n")
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
