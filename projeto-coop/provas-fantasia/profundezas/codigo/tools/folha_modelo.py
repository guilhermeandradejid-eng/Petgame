# Monta a folha de modelo (modelo.png) a partir dos renders do motor em out/folha/.
import sys
from PIL import Image, ImageDraw, ImageFont
D = sys.argv[1]; OUT = sys.argv[2]
def fonte(s):
    for p in ['/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']:
        try: return ImageFont.truetype(p, s)
        except Exception: pass
    return ImageFont.load_default()
F, f2, f3 = fonte(30), fonte(21), fonte(18)
linhas = [
    ('a', 'O Escorador (guerreiro, Âmbar): atarracado e largo, pele curtida com fuligem da vela; viga atravessada nos ombros e capacete de vela: "um T com uma chama"', ['frente', '3/4', 'perfil']),
    ('b', 'A Cristaleira (maga, Cobalto): alta e estreita, pálida; chapéu com geodo aceso  |  A Coveira (clériga, Branco-giz): encurvada, pele cinza, olheiras; aba larga com véu, pá, turíbulo', ['frente', '3/4', 'perfil', 'frente', '3/4', 'perfil']),
    ('c', 'O Gancheiro (ladino, Verde-veneno): magro, pele escura com cicatriz na sobrancelha; capuz de duas pontas, rolo de corda (a "rosca"), gancho, dois punhais', ['frente', '3/4', 'perfil']),
    ('d', 'Ouvidor (comum): cego, orelhas em leque, membros mais grossos (v2), aresta fria pintada; a boca, 2x maior, é o único ponto de cor', ['frente', '3/4', 'perfil']),
    ('g', 'Ouvidor, poses de jogo: descanso, telegrafia (orelhas em T, boca magenta, 30 quadros), pulo-mordida, eletrocutado (Corrente), atordoado', ['descanso', 'telegrafia', 'pulo', 'Corrente', 'atordoado']),
    ('e', 'Bocalume (comum, suporte): lesma de 2 m; isca quente e boca 2x maiores (v2); a isca imita a lanterna de um aventureiro e apaga na telegrafia', ['frente', '3/4', 'perfil']),
    ('f', 'Gancheiro, 8 poses-chave do combo e do Lance do Prumo (30 poses/s, smear no motor): guarda, antecipação, golpe 1, golpe 2, arma o Lance, solta, continuidade, abraço no saque', ['1 guarda', '2 antecipa', '3 golpe 1', '4 golpe 2', '5 arma', '6 solta', '7 segue', '8 abraço']),
    ('h', 'MODELO DE JOGO (v2): ícones de silhueta exagerados só no jogo: viga 1,3x, chapéu-geodo 1,2x, aba da Coveira 1,4x, rosca de corda 1,2x', ['Escorador', '', 'Cristaleira', '', 'Coveira', '', 'Gancheiro', '']),
    ('s', 'Teste de silhueta preta na câmera de jogo (1920x1080, máscara do estresse): as quatro classes sem cor e a altura de cada herói em pixels', ['', '', '', '']),
]
ims = []
W = 2400
for k, t, labs in linhas:
    im = Image.open('%s/%s.png' % (D, k)).convert('RGB')
    if im.width != W:
        im = im.resize((W, int(im.height * W / im.width)), Image.NEAREST)
    ims.append((im, t, labs))
H = 70 + sum(im.height + 46 for im, _, _ in ims)
sheet = Image.new('RGB', (W, H), (30, 31, 36))
d = ImageDraw.Draw(sheet)
d.text((24, 18), 'Plumbdeep, a Guilda do Prumo: folha de modelo (render do motor, Forward+, shader mini_pintada, casca de 1,5 px na cor da lavagem)', font=F, fill=(236, 226, 205))
y = 70
for im, t, labs in ims:
    d.rectangle([0, y, W, y + 40], fill=(52, 48, 62))
    d.text((18, y + 9), t, font=f2, fill=(236, 226, 205))
    y += 42
    sheet.paste(im, (0, y))
    n = len(labs)
    for i, l in enumerate(labs):
        cx = int((i + 0.5) * W / n)
        d.text((cx - 40, y + im.height - 30), l, font=f3, fill=(200, 190, 170))
    y += im.height + 4
sheet.save(OUT)
print(sheet.size)
