#!/bin/bash
# run.sh <compat|fplus> <out.png> <WxH> [args de usuário...]
G=/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-render-vfx/bin/Godot_v4.7.2-stable_linux.x86_64
P=/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas/cacos-de-cobalto/proj
case "$1" in
  compat) R="--rendering-method gl_compatibility --rendering-driver opengl3";;
  fplus) R="--rendering-method forward_plus --rendering-driver vulkan";;
esac
OUT=$2; RES=$3; shift 3
T0=$(date +%s)
timeout 3000 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path $P $R --audio-driver Dummy --fixed-fps 60 --resolution $RES -- out=$OUT "$@" > ${OUT%.*}.log 2>&1
echo "== $(basename $OUT) exit=$? $(( $(date +%s) - T0 ))s $(grep PROBE ${OUT%.*}.log)"
grep -i -E "error|warning" ${OUT%.*}.log | sort | uniq -c | sort -rn | head -6 | cut -c1-260
