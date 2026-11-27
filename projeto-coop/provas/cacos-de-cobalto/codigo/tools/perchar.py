# Contraste por personagem (cinza e borrão) para achar quem reprova. Uso: perchar.py img mask
import sys, numpy as np
from PIL import Image, ImageFilter
IMG, MASK = sys.argv[1], sys.argv[2]
sys.argv = ['x', IMG, MASK, '/tmp']
exec(open(__file__.replace('perchar.py', 'gates.py')).read().split("img = load(IMG)")[0])
img = load(IMG); mask = load(MASK); chars, anym = ids(mask)
bl = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255
c = contrast(img, chars, anym, 6); b = contrast(bl, chars, anym, 6)
for k in sorted(chars, key=lambda k: (k[0], int(k[1:]))):
    ys, xs = np.where(chars[k]); print(k, 'cinza', round(c.get(k, 0), 3), 'borrao', round(b.get(k, 0), 3), 'pos', int(xs.mean()), int(ys.mean()), 'px', int(chars[k].sum()))
