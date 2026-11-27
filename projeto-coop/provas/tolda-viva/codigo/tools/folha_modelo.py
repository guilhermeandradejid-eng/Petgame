# Monta a folha de modelo a partir das faixas renderizadas no Godot (Forward+), com títulos.
import sys, os
from PIL import Image, ImageDraw, ImageFont
D = sys.argv[1]; OUT = sys.argv[2]
def font(sz):
    for p in ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
F1, F2 = font(34), font(22)
rows = [('r1.png', 'Tarugo (quadrado, magenta)   |   Mestra Anilina (losango, folha)', ['frente', '3/4', 'perfil'] * 2),
        ('r2.png', 'Retrós (triângulo, ciano)   |   Pavio (círculo, gema)', ['frente', '3/4', 'perfil'] * 2),
        ('r3.png', 'Inimigos: Caruncho (laca vermelho-sangue, brilho duro)   |   Caruncho-de-chifre (élitros abertos)', ['frente', '3/4', 'perfil'] * 2),
        ('r4.png', 'Tarugo, marretada pesada: poses-chave (quadro a 60 fps, chaves CONSTANT)', ['0 guarda', '6 antecipação', '10 extremo (segura 10)', '20 borrão (1 quadro)', '21 contato + hit-stop 6', '24 continuidade', '30 ricochete', '46 olha a plateia']),
        ('r5.png', 'Mestra Anilina, pincelada larga: poses-chave', ['0 guarda', '11 extremo', '18 borrão', '19 contato', '22 passagem', '26 continuidade', '31 arco final', '38 floreio'])]
ims = [Image.open(os.path.join(D, r[0])).convert('RGB') for r in rows]
W = max(i.width for i in ims)
H = sum(i.height + 80 for i in ims) + 110
S = Image.new('RGB', (W, H), (217, 205, 176))
dr = ImageDraw.Draw(S)
dr.text((30, 28), 'Tolda Viva v2 — folha de modelo (render real no motor, Godot 4.7 Forward+)', fill=(29, 24, 32), font=F1)
y = 110
for (fn, title, labels), im in zip(rows, ims):
    dr.rectangle([0, y, W, y + 44], fill=(76, 29, 54))
    dr.text((24, y + 8), title, fill=(242, 230, 200), font=F2)
    S.paste(im, (0, y + 44))
    n = len(labels)
    for k, l in enumerate(labels):
        cx = int((k + 0.5) * im.width / n)
        tw = dr.textlength(l, font=F2)
        dr.text((cx - tw / 2, y + 44 + im.height + 6), l, fill=(29, 24, 32), font=F2)
    y += im.height + 80
S.save(OUT)
print(S.size)
