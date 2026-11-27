#!/bin/bash
# run.sh <compat|fplus> <WxH> <out.png> [args...]
G=/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-render-vfx/bin/Godot_v4.7.2-stable_linux.x86_64
P=/tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas-fantasia3/caravana/proj
case "$1" in
  compat) R="--rendering-method gl_compatibility --rendering-driver opengl3";;
  fplus) R="--rendering-method forward_plus --rendering-driver vulkan";;
esac
RES=$2; OUT=$(realpath -m $3); shift 3
W=${RES%x*}; H=${RES#*x}
T0=$(date +%s.%N)
timeout ${TMO:-300} xvfb-run -a -s "-screen 0 ${W}x${H}x24" $G --path $P $R --audio-driver Dummy --fixed-fps 60 --resolution $RES ${EXTRA} -- out=$OUT "$@" > ${OUT%.*}.log 2>&1
EC=$?
T1=$(date +%s.%N)
echo "== $(basename $OUT) exit=$EC $(printf '%.1f' $(echo "$T1-$T0"|bc))s $(grep PROBE ${OUT%.*}.log)"
grep -i -E "error|warning" ${OUT%.*}.log | sort | uniq -c | sort -rn | head -6 | cut -c1-260
