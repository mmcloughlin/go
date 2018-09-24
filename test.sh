#!/bin/bash -ex

./bin/go generate crypto/aes
./bin/go test -c crypto/aes


# test
GOCACHE=off ./bin/go test crypto/aes crypto/cipher

# bench
benchtime=10s
results=results/$(uuidgen)
mkdir -p ${results}
unbuffer ./bin/go test -run NONE -benchtime ${benchtime} -bench 'CTR' crypto/cipher | tee ${results}/results.txt
cp src/crypto/aes/*ctr_amd64* ${results}
exit

# profile
prof=$(mktemp)
./bin/go test -run NONE -bench CTR -cpuprofile ${prof} crypto/cipher
./bin/go tool pprof -list=xor ${prof} | tee xor.list | less