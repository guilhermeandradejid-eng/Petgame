#!/bin/bash
# v2: re-renderiza o quadro bonito e o clipe (Forward+), em paralelo
cd $(dirname $0)/..
P=$(pwd)
rm -rf out/clip4; mkdir -p out/clip4
TMO=1500 tools/run.sh fplus 1920x1080 entrega/beauty.png cena=poca frames=63 pc=1 pitch=27 dist=19 fov=30 cz=-1.0 cx=-0.5 dof_far=42 dof_near=11 dof_amt=0.03 &
TMO=2400 EXTRA="--write-movie $P/out/clip4/q.png" tools/run.sh fplus 1280x720 out/clip4_run.png cena=poca frames=300 pc=1 &
wait
echo FIM
