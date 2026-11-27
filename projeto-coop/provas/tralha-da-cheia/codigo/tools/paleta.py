# Paleta mestra da Tralha da Cheia (prova de estilo). 25 cores (v2: + tabua_cinza do piso). Todo gerador (bpy, numpy) e todo shader lê daqui.
# Três famílias: cenário em miriti cru e tinta desbotada (S <= ~30%); heróis em tinta nova e saturada, com massa
# escura no pé; inimigos Inchados em tinta apagada e descascada, com um só ponto de cor (o olho).
# Perigo: listra 'tinta' + 'amarelo' (só em faixa listrada). Efeitos usam a cor de quem os fez.
P = {
    'tinta':       '#1E1A22',  # contorno, faixa de perigo, breu
    'miriti':      '#EDE1C6',  # miolo cru do miriti (aparece onde a tinta falha)
    'miriti_som':  '#B5A386',  # miriti velho, molhado (cenário)
    'tabua_azul':  '#7F95A1',  # tinta desbotada do cenário
    'tabua_verde': '#8E9E86',
    'tabua_ocre':  '#C2A884',
    'tabua_rosa':  '#B99189',
    'tabua_cinza': '#C4C9C3',  # piso: cinza-azulado claro (o piso só usa este e o miriti cru, em placas)
    'lama':        '#5E4E44',  # madeira molhada, estacas, vão sob o trapiche
    'rio_claro':   '#9CC0B6',  # água em faixa pintada (3 tons)
    'rio_medio':   '#5F8E8C',
    'rio_esc':     '#3A5C66',
    'ceu':         '#EBCB9C',  # fim de tarde
    # heróis (tinta nova)
    'urucum':      '#D9452B',  # jogador 1 (Tiá Marola)
    'anil':        '#2C63D6',  # jogador 2 (Piaba)
    'folha':       '#53B83A',  # jogador 3 (Seu Remanso)
    'acai':        '#8E3FA8',  # jogador 4 (Mestra Breu)
    'amarelo':     '#F5C02E',  # detalhe pintado e faixa de perigo (com 'tinta')
    'escuro':      '#2A2642',  # massa escura no pé dos heróis, borracha da boia e da máscara
    'pele':        '#8A5234',
    'pele_clara':  '#D49A6A',
    # inimigos Inchados (tinta estufada)
    'inchado':     '#A3948A',
    'inchado_esc': '#615650',
    'ferrugem':    '#99603F',
    'olho':        '#FF4FA3',  # o único ponto de cor forte do inimigo
}

def rgb(name):
    h = P[name].lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def f(name):
    return tuple(c / 255 for c in rgb(name))

if __name__ == '__main__':
    import colorsys
    for k in P:
        r, g, b = f(k); h, s, v = colorsys.rgb_to_hsv(r, g, b)
        print(f'{k:12s} {P[k]} H{h*360:4.0f} S{s*100:3.0f} V{v*100:3.0f}')
    print(len(P), 'cores')
