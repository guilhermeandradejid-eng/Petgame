# Folha de quadros de um clipe (para revisar o movimento): python3 folha_clip.py PASTA SAIDA [passo] [inicio] [fim] [colunas] [largura]
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont
D, OUT = sys.argv[1], sys.argv[2]
step = int(sys.argv[3]) if len(sys.argv) > 3 else 6
a = int(sys.argv[4]) if len(sys.argv) > 4 else 1
b = int(sys.argv[5]) if len(sys.argv) > 5 else 99999
cols = int(sys.argv[6]) if len(sys.argv) > 6 else 6
w = int(sys.argv[7]) if len(sys.argv) > 7 else 320
fs = sorted(glob.glob(os.path.join(D, 'q*.png')))
sel = [f for f in fs if a <= int(os.path.basename(f)[1:-4]) <= b][::step]
im0 = Image.open(sel[0]); h = int(w * im0.height / im0.width)
rows = (len(sel) + cols - 1) // cols
S = Image.new('RGB', (cols * w, rows * h), (20, 18, 24))
F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 14)
dr = ImageDraw.Draw(S)
for i, f in enumerate(sel):
    im = Image.open(f).convert('RGB').resize((w, h), Image.LANCZOS)
    x, y = (i % cols) * w, (i // cols) * h
    S.paste(im, (x, y))
    n = int(os.path.basename(f)[1:-4]) - 1
    dr.text((x + 4, y + 2), 'F%d' % n, fill=(255, 240, 200), font=F)
S.save(OUT)
print(len(sel), S.size)
