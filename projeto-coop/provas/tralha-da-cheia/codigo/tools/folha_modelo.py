# Monta a folha de modelo da Tralha da Cheia a partir das faixas renderizadas no Godot (Forward+), com títulos.
import sys, os
from PIL import Image, ImageDraw, ImageFont
D = sys.argv[1]; OUT = sys.argv[2]
def font(sz):
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', sz)
F1, F2 = font(34), font(21)
V = ['frente', '3/4', 'perfil'] * 2
rows = [('r1.png', 'Tiá Marola, estivadora (trapézio; urucum, quadrado)   |   Piaba, mergulhador (bola; anil, triângulo)', V),
        ('r2.png', 'Seu Remanso, balseiro (linha quebrada pela vara; folha, círculo)   |   Mestra Breu, calafate (assimétrica: pote de breu e pincel de estopa; açaí, losango)', V),
        ('r3.png', 'Inchados: Bucho (bexiga de duas câmaras amarrada, olho único)   |   Gaiola (caranguejo de gaiola)', V),
        ('r4.png', 'Remada de Marola (15 poses/s): antecipação longa e contato próprios', ['0 guarda', '4 antecipação', '12 extremo (segura 18)', '30 borrão', '31 contato, +15% braço', '39 passa do alvo', '55 freio', '71 volta']),
        ('r5.png', 'A mesma remada no Piaba (30 poses/s): agacha na boia, salta no contato; recuperação comum', ['0 guarda', '2 antecipação (boia 0,7)', '8 borrão', '9 contato no ar (boia 1,4)', '13 pouso (achata)', '21 passa do alvo', '29 freio', '37 volta']),
        ('r6.png', 'Malho de Marola até a Despedida (poses-chave, chaves CONSTANT a 60 fps)', ['0 guarda', '6 ergue', '12 extremo (segura 20)', '32 borrão', '33 contato: congela 14', '40 continua', '52 (no jogo, mão vazia)', '60 olha a mão'])]
ims = [Image.open(os.path.join(D, r[0])).convert('RGB') for r in rows]
W = max(i.width for i in ims)
H = sum(i.height + 82 for i in ims) + 100
S = Image.new('RGB', (W, H), (230, 217, 189))
dr = ImageDraw.Draw(S)
dr.text((30, 30), 'Tralha da Cheia: folha de modelo (render real no motor, Godot 4.7 Forward+, bonecos de miriti gerados por código)', fill=(30, 26, 34), font=F1)
y = 100
for (fn, title, labels), im in zip(rows, ims):
    dr.rectangle([0, y, W, y + 42], fill=(42, 38, 66))
    dr.text((22, y + 9), title, fill=(237, 225, 198), font=F2)
    S.paste(im, (0, y + 42))
    n = len(labels)
    for k, l in enumerate(labels):
        cx = int((k + 0.5) * im.width / n)
        tw = dr.textlength(l, font=F2)
        dr.text((cx - tw / 2, y + 42 + im.height + 8), l, fill=(30, 26, 34), font=F2)
    y += im.height + 82
S.save(OUT)
print(S.size)
