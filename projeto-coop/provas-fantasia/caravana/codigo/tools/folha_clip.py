# folha de contato de um clipe: folha_clip.py PASTA saida.png q1,q2,... [colunas] [largura]
import sys
from PIL import Image, ImageDraw
d, out, qs = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(',')]
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 4
W = int(sys.argv[5]) if len(sys.argv) > 5 else 640
ims = [Image.open('%s/q%08d.png' % (d, q)).convert('RGB') for q in qs]
H = int(W * ims[0].height / ims[0].width)
rows = (len(ims) + cols - 1) // cols
sh = Image.new('RGB', (cols * W, rows * H), (0, 0, 0))
dr = ImageDraw.Draw(sh)
for i, (q, im) in enumerate(zip(qs, ims)):
    x, y = (i % cols) * W, (i // cols) * H
    sh.paste(im.resize((W, H), Image.LANCZOS), (x, y))
    dr.text((x + 6, y + 4), 'q%d' % q, fill=(255, 240, 200))
sh.save(out)
