# Paleta fechada de "A Pequena Hoste" (seção 11.2): 14 cores de mundo, 4 de jogador, verde dos mortos, 2 pigmentos de roupa e 1 de perigo = 22.
P = {
    'tinta':      '#231C17',   # preto-sépia, toda linha
    'papel_dia':  '#E9DFC9',   # linho
    'papel_crep': '#E3C99A',   # âmbar claro
    'papel_noite':'#8E97A3',   # cinza-azulado
    'ocre':       '#A8834F',   # ocre-terra
    'verde_terra':'#7D8A5A',
    'sombra':     '#6E4A33',   # sombra-queimada
    'rio':        '#6F8894',   # azul-cinza do rio
    'trigo':      '#C9A55A',   # ocre-amarelo do trigo
    'azinhavre':  '#5E8F7E',
    'fogo':       '#E2672B',   # laranja-mínio
    'raio':       '#F4F1E8',   # branco-papel do raio
    'raio_borda': '#7FA3E0',
    'cera':       '#F2E6C2',   # branco-cera (consagrado)
    'vermelhao':  '#D9472B',   # jogador 1
    'ouro':       '#E8B23A',   # jogador 2
    'ultramar':   '#3F62C8',   # jogador 3
    'murice':     '#9B3FA8',   # jogador 4
    'mordente':   '#A8D82A',   # só os mortos-vivos (olhos, boca)
    'anil':       '#2F4677',   # pigmento do jogador 3 (roupa); o anel usa o ultramar
    'amora':      '#6B2A63',   # pigmento do jogador 4 (roupa); o anel usa o múrice
    'perigo':     '#B5301F',   # vermelhão de perigo: só telegrafia
}
JOG = ['vermelhao', 'ouro', 'ultramar', 'murice']

def rgb(n):
    h = P[n].lstrip('#') if n in P else n.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
