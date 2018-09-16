import sys
import random


DECL = '// func {name}(nr int, xk *uint32, dst, ctr *byte)'
TEXT = u'TEXT \u00b7{name}(SB),0,${framesize}-{argsize}'
HEADER = (
    u'''	MOVQ nr+0(FP), CX
	MOVQ xk+8(FP), AX
	MOVQ dst+16(FP), DX
	MOVQ ctr+24(FP), BX''')


def generate(n):
    """
    Generate Go assembly for encrypting n blocks in ctr mode.
    """
    params = {
        'framesize': 16 * n,
        'argsize': 32,
        'name': 'encryptBlocks{}Ctr'.format(n),
        'reg_key': 'X{}'.format(n),
        'reg_bswap': 'X{}'.format(n+1),
    }

    # file header
    print '#include "textflag.h"'
    print

    # 16-byte byte swap permutation
    print 'DATA bswapMask<>+0x00(SB)/8, $0x08090a0b0c0d0e0f'
    print 'DATA bswapMask<>+0x08(SB)/8, $0x0001020304050607'
    print 'GLOBL bswapMask<>(SB), (NOPTR+RODATA), $16'
    print

    # function header
    for tmpl in [DECL, TEXT, HEADER]:
        print tmpl.format(**params)

    # load ctr values and reverse endian-ness
    print '\tMOVQ 0(BX), R8'
    print '\tMOVQ 8(BX), R9'
    print '\tBSWAPQ R8'
    print '\tBSWAPQ R9'

    # increment counter and populate block registers
    print '\tMOVOU bswapMask<>(SB), {reg_bswap}'.format(**params)
    for i in xrange(n):
        print '\tMOVQ R9, {offset}(SP)'.format(offset=i*16)
        print '\tMOVQ R8, {offset}(SP)'.format(offset=i*16+8)
        print '\tMOVOU {offset}(SP), X{i}'.format(offset=i*16, i=i)
        print '\tPSHUFB {reg_bswap}, X{i}'.format(i=i, **params)
        print '\tADDQ $1, R9'
        print '\tADCQ $0, R8'

    # store ctr value back
    print '\tBSWAPQ R8'
    print '\tBSWAPQ R9'
    print '\tMOVQ R8, 0(BX)'
    print '\tMOVQ R9, 8(BX)'

    # initial key add
    print '\tMOVUPS 0(AX), {reg_key}'.format(**params)
    for i in xrange(n):
        print '\tPXOR {reg_key}, X{i}'.format(i=i, **params)
    print '\tADDQ $16, AX'

    # num rounds branching
    print '\tSUBQ $12, CX'
    print '\tJE Lenc192'
    print '\tJB Lenc128'

    def enc(ax, inst='AESENC'):
        print '\tMOVUPS {offset}(AX), {reg_key}'.format(offset=16*ax, **params)
        for i in xrange(n):
            print '\t{inst} {reg_key}, X{i}'.format(inst=inst, i=i, **params)

    # 2 extra rounds for 256-bit keys
    print 'Lenc256:'
    enc(0)
    enc(1)
    print '\tADDQ $32, AX'

    # 2 extra rounds for 192-bit keys
    print 'Lenc192:'
    enc(0)
    enc(1)
    print '\tADDQ $32, AX'

    # 10 rounds for 128-bit (with special handling for final)
    print 'Lenc128:'
    for r in xrange(9):
        enc(r)
    enc(9, inst='AESENCLAST')

    # write results to destination
    for i in xrange(n):
        print '\tMOVUPS X{i}, {offset}(DX)'.format(i=i, offset=16*i)

    # return
    print '\tRET'
    print


def main(args):
    n = int(args[1])
    generate(n)


if __name__ == '__main__':
    main(sys.argv)
