#!/bin/bash
# uso: tools/strips.sh <saida.png> <yaw> clip:t0,t1,... [clip:...]
# monta uma tira de quadros por clipe e empilha tudo numa imagem so.
cd "$(dirname "$0")/.."
out="$1"; yaw="$2"; shift 2
tmp=$(mktemp -d)
i=0
for spec in "$@"; do
  clip="${spec%%:*}"; times="${spec#*:}"
  tools/shot.sh glb=assets/models/hero.glb out=$tmp/$(printf %02d $i).png hide=eyes_sharp,eyes_sleepy,eyes_dot,eyes_happy${HIDE:+,$HIDE} size=1800x400 zoom=1.75 cy=0.72 spacing=0.95 yaws=$yaw anim=$clip times=$times ${SHOW:+show=$SHOW} > /dev/null
  i=$((i+1))
done
convert $tmp/*.png -append "$out"
rm -rf $tmp
echo "ok $out"
