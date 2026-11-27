# Monta as folhas de contato para o usuário julgar. Uso: python3 folhas.py OUTROOT
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
R = sys.argv[1]
C = os.path.join(R, 'cap'); O = os.path.join(R, 'folhas'); os.makedirs(O, exist_ok=True)
F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 20)
Fs = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
BG = (36, 30, 33)
M = {
    'deuteranopia': np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    'protanopia': np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    'tritanopia': np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}
def s2l(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def l2s(c): c = np.clip(c, 0, 1); return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
def cvd(im, k):
    a = np.asarray(im.convert('RGB')).astype(np.float32) / 255
    return Image.fromarray((l2s(s2l(a) @ M[k].T) * 255).astype(np.uint8))
def gray(im):  # luminância OKLab L aproximada por L* de sRGB -> usar luma perceptual simples
    a = s2l(np.asarray(im.convert('RGB')).astype(np.float32) / 255)
    Y = a @ np.array([0.2126, 0.7152, 0.0722])
    L = l2s(Y)
    return Image.fromarray((np.stack([L] * 3, -1) * 255).astype(np.uint8))
def op(n): return Image.open(os.path.join(C, n)).convert('RGB')

def sheet(cells, cols, cw, ch, title, name, pad=10, lab=28):
    rows = (len(cells) + cols - 1) // cols
    W = cols * (cw + pad) + pad; H = 44 + rows * (ch + lab + pad) + pad
    S = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(S)
    d.text((pad, 10), title, font=F, fill=(237, 227, 203))
    for i, (im, label) in enumerate(cells):
        x = pad + (i % cols) * (cw + pad); y = 44 + (i // cols) * (ch + lab + pad)
        if im is not None:
            im = im.copy(); im.thumbnail((cw, ch))
            S.paste(im, (x + (cw - im.width) // 2, y + lab))
        d.text((x, y + 5), label, font=Fs, fill=(220, 210, 190))
    S.save(os.path.join(O, name)); print(name, S.size)

# 1. câmeras
cams = [('stage', 'palco (belt-scroll, 7° de inclinação)'), ('camarote', 'camarote (38°)'), ('iso', 'alta estilo Magicka (55°)')]
cells = []
for sc, scl in (('duo', 'duelo'), ('stress', '4 jogadores + 20 inimigos')):
    for c, cl in cams:
        cells.append((op(f'{sc}_{c}_compat.png'), f'{scl} | {cl} | Compatibility'))
sheet(cells, 3, 640, 360, 'Folha 1: as três câmeras (Compatibility, tinta em hierarquia)', 'folha1_cameras.png')

# 2. portões (cena de estresse)
cells = []
for c, cl in cams:
    im = op(f'stress_{c}_compat.png')
    th = im.resize((320, 180), Image.LANCZOS)
    cells += [(im, f'{c}: original'), (gray(im), 'cinza (luminância)'), (im.filter(ImageFilter.GaussianBlur(4)), 'borrão 4 px'),
              (th, 'miniatura 320x180 (tamanho real)'), (cvd(im, 'deuteranopia'), 'deuteranopia'), (cvd(im, 'protanopia'), 'protanopia')]
sheet(cells, 6, 400, 225, 'Folha 2: portões do contrato na cena de estresse (Compatibility)', 'folha2_portoes.png')

# 3. variantes de tinta e chão + paridade de renderer
cells = []
for c in ('stage', 'iso'):
    cells += [(op(f'stress_{c}_compat_preta.png'), f'{c}: tudo em tinta preta'), (op(f'stress_{c}_compat.png'), f'{c}: hierarquia de tinta'),
              (op(f'stress_{c}_compat_pardo.png'), f'{c}: chão de papel pardo')]
cells += [(op('duo_stage_compat.png').crop((380, 180, 900, 520)), 'Compatibility (recorte)'), (op('duo_stage_fplus.png').crop((380, 180, 900, 520)), 'Forward+ (recorte)'),
          (Image.fromarray(np.clip(np.abs(np.asarray(op('duo_stage_compat.png')).astype(int) - np.asarray(op('duo_stage_fplus.png')).astype(int)) * 8, 0, 255).astype(np.uint8)).crop((380, 180, 900, 520)), 'diferença x8')]
sheet(cells, 3, 560, 315, 'Folha 3: variantes de tinta/chão e paridade entre renderers', 'folha3_variantes.png')

# 4. o boneco: folha de modelo, ciclo, sprite pré-renderizado
cells = [(op('sheet_compat.png').crop((0, 220, 1280, 520)), 'folha de modelo: giro + 3 poses do ataque + inimigo (Compatibility)'),
         (op('ciclo_compat.png').crop((0, 170, 1280, 560)), 'ciclo de ataque em 2s, 8 poses, perfil (quadros 1,3,5,9,11,13,17,19)'),
         (op('ciclo34_compat.png').crop((0, 170, 1280, 560)), 'mesmo ciclo em 3/4'),
         (Image.open(os.path.join(R, 'sprite', 'strip.png')).convert('RGB'), 'variante sprite: mesmos 8 quadros no Cycles (toon por emissão), vista do palco e vista alta'),
         (op('cmp_sprite.png'), 'no motor: 3D toon (esq.) x sprite Cycles em Sprite3D (dir.), palco e vista alta')]
sheet(cells, 1, 1280, 420, 'Folha 4: o boneco gerado por bpy', 'folha4_boneco.png')
