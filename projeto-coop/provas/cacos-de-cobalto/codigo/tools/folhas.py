# Monta a folha de modelo (modelo.png) a partir das capturas do motor: vistas de frente, 3/4 e
# perfil de cada personagem e as poses-chave do golpe. Uso: python3 folhas.py OUTDIR saida.png
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

D, OUT = sys.argv[1], sys.argv[2]
BG = (201, 195, 180)
F = '/usr/share/fonts/opentype/inter/'
def font(sz, w='Medium'):
    try:
        return ImageFont.truetype(F + f'Inter-{w}.otf', sz)
    except Exception:
        return ImageFont.load_default()

def crop(p, pad=18):
    im = Image.open(p).convert('RGB')
    a = np.asarray(im).astype(int)
    diff = np.abs(a - np.array(BG)).sum(-1) > 24
    ys, xs = np.where(diff)
    return im.crop((max(0, xs.min() - pad), max(0, ys.min() - pad), min(im.width, xs.max() + pad), min(im.height, ys.max() + pad)))

def fit_h(im, h):
    return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)

rows = [
    ('Tia Lamparina · Brasa · P1 magenta / quadrado', 'v_lamparina.png', 'pera larga; lamparina de cabo longo; avental em reserva branca; laço laranja-ferro; lenço e faixa da cintura em vidrado na cor do jogador'),
    ('Bento Rodo · Cal · P2 ciano / triângulo', 'v_bento.png', 'silhueta de cravo: chapéu de jornal de aba larga (cor do jogador) mais largo que os ombros; pescoço curto; contraposto com o rodo no ombro'),
    ('Nina Catavento · Lufada · P3 lilás / círculo', 'v_nina.png', 'dois círculos: corpo pequeno e cata-vento gigante nas costas (pás na cor do jogador)'),
    ('Seu Galvão · Faísca · P4 lima / losango', 'v_galvao.png', 'ponto de interrogação: corcunda, garrafa de Leyden, vareta; boné e garrafa na cor do jogador'),
    ('Lasca (inimigo) · pilha de cacos de azulejo vidrados', 'v_lasca.png', 'mais alta que larga, inclinada para o alvo; vidrado dos dois lados, miolo de terracota crua, olho de painel fora do lugar, salitre branco-esverdeado'),
    ('Crosta (inimigo) · blocos de barra arrancados, crosta de salitre', 'v_crosta.png', 'rosto "errado": o olho de um painel remontado de lado; miolo de terracota, salitre branco-esverdeado (acentos que nenhum herói usa)'),
]
W = 2400
blocks = []
for title, fn, sub in rows:
    p = os.path.join(D, fn)
    if not os.path.exists(p):
        continue
    im = fit_h(crop(p), 430)
    blk = Image.new('RGB', (W, 430 + 80), BG)
    dr = ImageDraw.Draw(blk)
    dr.text((30, 14), title, fill=(29, 39, 85), font=font(30, 'SemiBold'))
    dr.text((30, 52), sub, fill=(70, 74, 96), font=font(20))
    x = (W - im.width) // 2
    blk.paste(im, (x, 80))
    for i, lab in enumerate(('frente', '3/4', 'perfil')):
        dr.text((x + int(im.width * (i + 0.5) / 3) - 24, 80 + 430 - 26), lab, fill=(70, 74, 96), font=font(18))
    blocks.append(blk)
# poses-chave do golpe
pp = os.path.join(D, 'poses_lamp.png')
if os.path.exists(pp):
    im = crop(pp)
    im = im.resize((W - 60, int(im.height * (W - 60) / im.width)), Image.LANCZOS)
    blk = Image.new('RGB', (W, im.height + 130), BG)
    dr = ImageDraw.Draw(blk)
    dr.text((30, 14), 'Golpe da Tia Lamparina: 9 poses-chave (CONSTANT, 60 fps; números = quadro do clipe)', fill=(29, 39, 85), font=font(30, 'SemiBold'))
    dr.text((30, 52), 'o corpo gira como bloco (louça não estica): tilt de 10 a 16° do quadril; na descida o giro sai do quadril e chega ao peito e à cabeça 2 quadros depois', fill=(70, 74, 96), font=font(20))
    blk.paste(im, (30, 90))
    labels = ['1 guarda', '5 antecip.', '9 antecip. 2', '13 quadril sai', '15 smear', '17 solta', '19 cabeça chega', '25 follow', '41 recupera']
    for i, lab in enumerate(labels):
        dr.text((30 + int((W - 60) * (i + 0.5) / 9) - 50, 90 + im.height + 8), lab, fill=(70, 74, 96), font=font(20))
    blocks.append(blk)
pb = os.path.join(D, 'poses_bento.png')
if os.path.exists(pb):
    im = crop(pb)
    im = im.resize((W - 60, int(im.height * (W - 60) / im.width)), Image.LANCZOS)
    blk = Image.new('RGB', (W, im.height + 110), BG)
    dr = ImageDraw.Draw(blk)
    dr.text((30, 14), 'Bento: jogar a cal (preparar o chão): guarda · antecipação · smear · solta · follow-through (quadros 1, 7, 23, 25, 31)', fill=(29, 39, 85), font=font(30, 'SemiBold'))
    blk.paste(im, (30, 60))
    blocks.append(blk)
H = sum(b.height for b in blocks) + 120
sheet = Image.new('RGB', (W, H), BG)
dr = ImageDraw.Draw(sheet)
dr.text((30, 26), 'Cacos de Cobalto · folha de modelo (render do motor, Godot 4.7.2 Forward+, câmera ortográfica)', fill=(13, 16, 41), font=font(40, 'Bold'))
dr.text((30, 78), 'Faiança em negativo: esmalte azul-noite pintado de branco, acento na cor da matéria, peça de vidrado e rim duro na cor do jogador; cabeças 20 a 25% maiores; brilho em janela; peças rígidas, pano em osso de mola.', fill=(70, 74, 96), font=font(20))
y = 120
for b in blocks:
    sheet.paste(b, (0, y)); y += b.height
sheet.save(OUT)
print(OUT, sheet.size)
