#!/bin/bash -ex

./bin/go run src/crypto/aes/gen_amd64.go > src/crypto/aes/ctr_amd64.s

# test
./bin/go test -v crypto/aes
./bin/go test -v -bench CTR crypto/cipher

# profile
./bin/go test -run NONE -bench CTR -cpuprofile prof.out crypto/cipher
./bin/go tool pprof -list=xor prof.out | less