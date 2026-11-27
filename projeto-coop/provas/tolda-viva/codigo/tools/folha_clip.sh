#!/bin/bash
# folha_clip.sh out.png "frames" args... : renderiza quadros soltos do clipe (Compatibility, 640x360) e monta uma folha
OUT=$1; FR=$2; shift 2
D=$(mktemp -d)
for f in $FR; do TMO=100 /tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas/tolda-viva/tools/run.sh compat 640x360 $D/f$f.png quadro=$f "$@" >/dev/null & 
  while [ $(jobs -r | wc -l) -ge 3 ]; do sleep 0.5; done; done; wait
python3 - "$OUT" $D $FR <<'PY'
import sys
from PIL import Image, ImageDraw
out, d, fr = sys.argv[1], sys.argv[2], sys.argv[3:]
cols = 4; rows = (len(fr) + cols - 1) // cols
S = Image.new('RGB', (640 * cols, 360 * rows), (20, 20, 20))
for i, f in enumerate(fr):
    try: im = Image.open(f'{d}/f{f}.png').convert('RGB')
    except Exception: continue
    dr = ImageDraw.Draw(im); dr.text((8, 8), f'f{f}', fill=(255, 255, 0))
    S.paste(im, ((i % cols) * 640, (i // cols) * 360))
S.save(out)
PY
