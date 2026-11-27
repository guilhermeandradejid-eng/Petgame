# Paleta mestra da Tolda Viva (prova de estilo). Todo gerador e todo shader lê daqui.
# Três famílias: cenário (dessaturado), bonecos (tinta nova), efeitos (picos curtos). Matizes reservados:
# jogadores (magenta, ciano, gema, folha) e perigo (vermelhão, sempre em divisas).
P = {
    # tinta / contorno
    'tinta':      '#1D1820',   # preto-violeta: contorno dos bonecos, contrarregras, aviso
    # telão (têmpera sobre lona) — família do cenário
    'anil_esc':   '#26304F',
    'anil':       '#3D4A70',
    'musgo_esc':  '#2C4239',
    'musgo':      '#557258',
    'lua':        '#EBC979',
    # praticável e madeira de palco
    'tabua':      '#A88763',
    'tabua_esc':  '#5B4232',
    'lona':       '#D9CDB0',   # lona crua da tolda, recortes, sacos
    # bonecos: madeira e tecidos
    'madeira':    '#E4B98A',
    'madeira_esc':'#A86E47',
    'bochecha':   '#D8584A',
    'vinho':      '#4C1D36',   # xadrez do Tarugo
    'verde_esc':  '#1E3A31',   # chita de fundo escuro da Anilina
    'marinho':    '#22304D',   # listrado de colchão da Retrós
    'creme':      '#F2E6C8',
    # inimigos: pragas em tons claros e lavados (cortiça, pó de traça, lona mofada)
    'cortica':    '#D7C6A3',
    'mofo':       '#8E9A6A',
    # v2: carunchos em laca vermelho-sangue (casco) e laca quase preta (pernas, furos), com brilho duro no shader
    'laca':       '#7A1622',
    'laca_esc':   '#2B0C12',
    # jogadores
    'p_magenta':  '#E5337F',
    'p_ciano':    '#22BFD6',
    'p_gema':     '#FFD84A',
    'p_folha':    '#2E7D22',
    # perigo (só em divisas)
    'vermelhao':  '#E2401B',
    # matérias
    'anilina':    '#3550D8',   # Tinta: azul-anilina (a Serragem usa a cor 'madeira')
}

def rgb(name):
    h = P[name].lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def f(name):
    return tuple(c / 255 for c in rgb(name))

if __name__ == '__main__':
    print(len(P), 'cores')
