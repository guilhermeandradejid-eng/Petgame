#!/bin/bash
# teste de multiplayer sem janela: 1 host + N clientes, todos bots. uso: tools/mp_test.sh <clientes> <segundos> [args extras do host]
cd "$(dirname "$0")/.."
N=${1:-2}; T=${2:-60}; shift 2
OUT=${MP_OUT:-/tmp/lumen_mp}
mkdir -p $OUT
godot --headless --path . -- --host --bot --god --profile=t_host --cls=guardiao --autostart=5 --quit=$T --log "$@" > $OUT/host.log 2>&1 &
sleep 1.5
CLS=(patrulheiro arcanista espadachim)
for i in $(seq 1 $N); do
  godot --headless --path . -- --join=127.0.0.1 --bot --god --profile=t_c$i --cls=${CLS[$((i-1))]} --quit=$((T-1)) --log > $OUT/c$i.log 2>&1 &
done
wait
for f in $OUT/host.log $OUT/c*.log; do
  echo "== $f: erros=$(grep -cE 'SCRIPT ERROR|^ERROR' $f)"
  grep -E "SCRIPT ERROR|^ERROR" -A2 $f | grep -vE "^--$|GDScript backtrace" | sort | uniq -c | sort -rn | head -12
  grep "\[dev" $f | tail -3
done
