#!/bin/bash
# Renderiza o clipe em partes (retoma de onde parou se o processo for morto). Quadros finais em out/clipv2/q%08d.png
cd "$(dirname "$0")/.."
TOTAL=${TOTAL:-1022}; PARTE=${PARTE:-120}
D=$(pwd)/out/clipv2
while true; do
  start=0
  while [ -f $D/q$(printf %08d $start).png ]; do start=$((start+1)); done
  # o último quadro gravado pode estar truncado: refaz
  [ $start -gt 0 ] && start=$((start-1))
  [ $start -ge $((TOTAL-1)) ] && break
  n=$((TOTAL-start)); [ $n -gt $PARTE ] && n=$PARTE
  T=$D/parte_$start; rm -rf $T; mkdir -p $T
  echo "parte $start +$n $(date +%T)"
  EXTRA="--write-movie $T/q.png" TMO=3000 tools/run.sh fplus 1920x1080 out/clipv2_parte.png cena=vau pc=1 frames=$n f0=$start msaa=2 > /dev/null 2>&1
  k=$(ls $T | wc -l)
  [ $k -gt $n ] && k=$n
  [ $k -gt 1 ] && k=$((k-1))
  for i in $(seq 0 $((k-1))); do mv $T/q$(printf %08d $i).png $D/q$(printf %08d $((start+i))).png; done
  rm -rf $T
done
echo fim $(date +%T)
