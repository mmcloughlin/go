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