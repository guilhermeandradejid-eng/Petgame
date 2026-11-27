# Monta a folha de modelo (modelo.png) a partir das faixas renderizadas no motor, com títulos.
# Uso: python3 folha_modelo.py PASTA_FAIXAS saida.png
import sys, os
from PIL import Image, ImageDraw, ImageFont

d, out = sys.argv[1], sys.argv[2]
def fonte(sz):
    for p in ('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
F1, F2 = fonte(30), fonte(20)
faixas = [
    ('f1.png', 'Rodeira (guerreira, Carmim): elmo-panela de estanho, roda de carroça  |  Pavieiro (mago, Ouro velho): chapéu-vela aceso, barba de cera. Rostos de cera talhada, olhos de botão',
     ['frente', '3/4', 'perfil'] * 2),
    ('f2.png', 'Sineira (clériga, Celeste): capuz pontudo, sino pendurado no gancho do cabo, atrás do ombro  |  Gatuno (ladino, Lilás): capuz anguloso de ponta única, corcunda de saque',
     ['frente', '3/4', 'perfil'] * 2),
    ('f3.png', 'Na luz (guache): Fuligento (vela que a Treva apagou: pavio carbonizado, cera escorrida, olhos de brasa em fenda)  |  Apagador (elite, 1,8 m, cone de latão)', ['frente', '3/4', 'perfil'] * 2),
    ('f4.png', 'Na Treva (gravura): os mesmos inimigos fora da luz: massa tinta-noite, poucas linhas, brasa nos olhos e na boca', ['frente', '3/4', 'perfil'] * 2),
    ('f5.png', 'Recepção "Eixo" da Rodeira, 8 poses-chave (12 poses/s): guarda, antecipação, estica, pega (congela 4 q), crava (achata 0,8), giro, elmo cai no olho, dedo no elmo',
     ['1 guarda', '2 antecipa', '3 estica', '4 pega', '5 crava', '6 giro', '7 continuidade', '8 assenta']),
]
W = 2400
blocos = []
for arq, tit, rot in faixas:
    im = Image.open(os.path.join(d, arq)).convert('RGB')
    blocos.append((im, tit, rot))
# teste de silhueta: as 4 classes e os 2 inimigos em preto chapado, com o herói a 64 px de altura (ampliado 3x)
import numpy as np
def silh(arq):
    a = np.asarray(Image.open(os.path.join(d, arq)).convert('RGB')).astype(int)
    fundo = np.array([216, 204, 176])
    m = np.abs(a - fundo).sum(-1) > 30
    out = np.where(m[..., None], 20, 216).astype(np.uint8).repeat(3, -1)
    return Image.fromarray(out)
ss = [silh(f) for f in ('f1.png', 'f2.png', 'f3.png')]
ys = np.where((np.asarray(ss[0])[..., 0] < 100).any(1))[0]
k = 64.0 / (ys.max() - ys.min() + 1)
peq = [im.resize((int(im.width * k), int(im.height * k)), Image.BILINEAR).point(lambda v: 20 if v < 118 else 216) for im in ss]
tira = Image.new('RGB', (sum(p.width for p in peq), max(p.height for p in peq)), (216, 204, 176))
x = 0
for p in peq:
    tira.paste(p, (x, 0)); x += p.width
tira = tira.resize((tira.width * 3 * W // (tira.width * 3), tira.height * 3 * W // (tira.width * 3)), Image.NEAREST)
blocos.append((tira, 'Teste de silhueta: preto chapado com o herói a 64 px de altura (ampliado). Panela com roda, vela, capuz pontudo com sino, capuz de ponta com corcunda, Fuligento, Apagador',
               ['Rodeira', '', '', 'Pavieiro', '', '', 'Sineira', '', '', 'Gatuno', '', '', 'Fuligento', '', '', 'Apagador', '', '']))
H = sum(b[0].height + 60 for b in blocos) + 90
sh = Image.new('RGB', (W, H), (216, 204, 176))
dr = ImageDraw.Draw(sh)
dr.text((30, 22), 'Wickwain, a caravana do pavio longo: folha de modelo (render do motor, shader pintado_pela_luz, contorno de casca invertida)', fill=(40, 28, 30), font=F1)
y = 90
for im, tit, rot in blocos:
    dr.rectangle([0, y, W, y + 52], fill=(62, 51, 80))
    dr.text((24, y + 14), tit, fill=(242, 221, 176), font=F2)
    sh.paste(im, (0, y + 52))
    n = len(rot)
    claro = sum(im.resize((1, 1)).getpixel((0, 0))) > 300
    for i, r in enumerate(rot):
        cx = int((i + 0.5) * W / n)
        dr.text((cx - 45, y + 52 + im.height - 32), r, fill=(40, 28, 30) if claro else (220, 210, 190), font=F2)
    y += im.height + 60
sh.save(out)
print(out, sh.size)
