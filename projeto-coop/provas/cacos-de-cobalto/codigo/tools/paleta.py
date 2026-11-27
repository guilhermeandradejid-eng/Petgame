# Paleta mestra de Cacos de Cobalto (uma só fonte para texturas, malhas e shaders).
# Mundo: faiança (estanho + cobalto em 3 valores + biscoito + rejunte), porto (4 neutros), salitre.
# Matérias: pigmentos históricos de azulejo. Perigo: só vermelho-lacre. Jogadores: matizes fora das matérias.
P = {
    # faiança
    'estanho':   '#EFE9DC',  # branco-estanho levemente quente (nunca branco puro)
    'aguado':    '#A9BBDD',  # cobalto aguado
    'medio':     '#4363AE',  # cobalto médio
    'noite':     '#1D2755',  # azul-noite (também o esmalte dos heróis)
    'biscoito':  '#D7B49C',  # biscoito bege-rosado (miolo do caco)
    'rejunte':   '#ADA595',  # massa entre os azulejos
    # porto (foscos, sem pintura)
    'madeira':   '#6E5646',
    'madeira_e': '#3F3129',
    'ferro':     '#4B4D55',
    'corda':     '#A89472',
    # inimigo
    'salitre':   '#D2D1C8',  # salitre do cenário (chão e parede)
    'salitre_v': '#CFE0C6',  # salitre branco-esverdeado: acento hostil, só nos Descascados
    'terracota': '#A3583A',  # terracota crua: miolo dos cacos inimigos (nenhum herói usa)
    # matérias
    'brasa':     '#DA6A2C',  # laranja-ferro
    'cal':       '#3F9C80',  # verde-cobre
    'faisca':    '#F3C631',  # amarelo-antimônio
    'oleo':      '#6F402B',  # castanho-manganês
    'lufada':    '#F7F4EF',  # branco-leite (borda roxa abaixo)
    'roxo':      '#7A4EA3',
    # perigo
    'lacre':     '#C42036',
    # jogadores (anel e símbolo)
    'p_magenta': '#E43C9E',
    'p_ciano':   '#23C4DB',
    'p_lilas':   '#9A78E0',
    'p_lima':    '#9BE03C',  # P4 (era branco; sumia no piso claro)
    # tinta do contorno
    'tinta':     '#0D1029',
}

def rgb(name):
    h = P[name].lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

def rgb8(name):
    h = P[name].lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def srgb2lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lin(name):
    return tuple(srgb2lin(c) for c in rgb(name))
