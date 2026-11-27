# Monta a folha de modelo: faixas renderizadas no motor (mesmo shader de gravura) + rótulos.
import sys
from PIL import Image, ImageDraw, ImageFont
D = sys.argv[1]; out = sys.argv[2]
faixas = [('herois1.png', 'PORTA-ESTANDARTE (paladino, jogador 1)  ·  SINEIRA (clériga, jogador 2)   —   frente, 3/4, perfil'),
          ('herois2.png', 'SAPADOR (ladino, jogador 3)  ·  BRUXA DO PÁRA-RAIOS (bruxa, jogador 4)   —   frente, 3/4, perfil'),
          ('inimigos.png', 'PIQUEIRO DO OSSUÁRIO (formação)  ·  CARPIDEIRA (suporte)   —   gravura em negativo: tinta cheia, luz em linha de papel, verde-mordente só nos olhos'),
          ('poses.png', 'SINEIRA — golpe de sino com Passar: repouso · antecipação 4q · pêndulo · SOLTA (quadro ativo) · arrasto do peso · assenta'),
          ('poses2.png', 'PORTA-ESTANDARTE — Investida de Escudo: repouso · antecipação 5q · avanço · CONTATO (achata 0,85, hit-stop global 4q) · recupera 14q'),
          ('poses3.png', 'BRUXA DO PÁRA-RAIOS — Contrato: repouso · puxão de ombro · aponta o céu (3q) · segura · ACHATA no raio (0,8) · estica (1,1) · admira · volta'),
          ('silh.png', 'TESTE DE SILHUETA PRETA a 64 px, na câmera do jogo (22°): Porta · Sineira · Sapador · Bruxa · Piqueiro · Penitente (3/4 frente, 3/4 costas, perfil)')]
try:
    fnt = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf', 26)
    fnt2 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', 40)
except Exception:
    fnt = fnt2 = ImageFont.load_default()
def carrega(f):
    im = Image.open(f'{D}/{f}').convert('RGB')
    if f == 'silh.png':
        # reduz a 64 px de herói, binariza e amplia 2x em blocos (o que o jogador vê de longe)
        g = im.convert('L').resize((im.width // 4, im.height // 4), Image.BOX).point(lambda v: 0 if v < 128 else 255)
        g = g.resize((g.width * 2, g.height * 2), Image.NEAREST).convert('RGB')
        pad = Image.new('RGB', (2400, g.height + 20), (255, 255, 255)); pad.paste(g, ((2400 - g.width) // 2, 10))
        return pad
    return im
ims = [carrega(f) for f, _ in faixas]
W = max(i.width for i in ims)
H = sum(i.height + 50 for i in ims) + 90
pan = Image.new('RGB', (W, H), (233, 223, 201))
d = ImageDraw.Draw(pan)
d.text((30, 22), 'A PEQUENA HOSTE — folha de modelo v2 (render do motor, Forward+)', font=fnt2, fill=(35, 28, 23))
y = 90
for (f, t), im in zip(faixas, ims):
    d.text((30, y + 10), t, font=fnt, fill=(35, 28, 23))
    d.line([(30, y + 44), (W - 30, y + 44)], fill=(35, 28, 23), width=2)
    pan.paste(im, (0, y + 50))
    y += im.height + 50
pan.save(out)
print(pan.size)
