# Teste de silhueta preta (correção 1 da crítica): a partir da máscara do estresse renderizada em 1920x1080 na câmera
# de jogo, recorta cada herói, pinta de preto sobre branco e mede a altura em pixels. As quatro classes precisam ser
# reconhecíveis sem cor. Uso: python3 silhueta.py mascara_1080.png saida.png
import sys, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
m = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int)
hero = (m[..., 0] > 150) & (m[..., 1] < 90)
hero_all = hero
nomes = ['Escorador', 'Cristaleira', 'Coveira', 'Gancheiro']
def fonte(s):
    try: return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', s)
    except Exception: return ImageFont.load_default()
cel = 300; out = Image.new('RGB', (cel * 4, cel + 60), (245, 242, 235)); d = ImageDraw.Draw(out)
res = {}
for i, v in enumerate([60, 110, 160, 210]):
    sel = hero & (np.abs(m[..., 2] - v) <= 6)
    ys, xs = np.nonzero(sel)
    if len(ys) == 0: continue
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    res[nomes[i]] = dict(altura_px=int(y1 - y0 + 1), largura_px=int(x1 - x0 + 1))
    crop = sel[y0:y1 + 1, x0:x1 + 1]
    im = Image.fromarray(np.where(crop, 0, 255).astype(np.uint8))
    k = min((cel - 30) / crop.shape[0], (cel - 30) / crop.shape[1], 3.0)
    im = im.resize((max(1, int(crop.shape[1] * k)), max(1, int(crop.shape[0] * k))), Image.NEAREST).convert('RGB')
    out.paste(im, (i * cel + (cel - im.width) // 2, 10 + (cel - 20 - im.height) // 2))
    d.text((i * cel + 12, cel + 8), '%s: %d px' % (nomes[i], y1 - y0 + 1), font=fonte(22), fill=(20, 20, 20))
out.save(sys.argv[2])
print(json.dumps(res, ensure_ascii=False))
