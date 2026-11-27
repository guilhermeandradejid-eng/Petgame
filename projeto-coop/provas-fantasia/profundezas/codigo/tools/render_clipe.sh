#!/bin/bash
cd $(dirname $0)/..
P=$(pwd)
rm -rf out/clip4; mkdir -p out/clip4
TMO=2400 EXTRA="--write-movie $P/out/clip4/q.png" tools/run.sh fplus 1280x720 out/clip4_run.png cena=poca frames=300 pc=1
rm -f out/clip4/q.wav
tools/codificar.sh out/clip4 entrega/clip
echo FIM
