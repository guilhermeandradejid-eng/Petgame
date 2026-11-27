# Paleta mestra da Wickwain (seção 11 do conceito). As cores base vão na cor de vértice; o shader
# pintado_pela_luz faz o guache (3 faixas, sombra violeta-fuligem) e a gravura (hachura sobre azul-noite).
P = {
    # mestra
    'sebo': '#F2DDB0', 'ambar': '#E8A24A', 'telha': '#B5583A', 'couro': '#7A4A2E', 'musgo': '#6B7340',
    'violeta': '#3E3350', 'azul_grav': '#2B3A52', 'noite': '#161C2A', 'linha': '#8296B0', 'ceu': '#5A5F6E',
    'acido': '#C6EE3A',
    # jogadores
    'carmim': '#E0503C', 'ouro': '#E8C34A', 'celeste': '#5CB8EE', 'lilas': '#B07BE6',
    # derivadas (mesma família, poucas)
    'carmim_esc': '#8E2A22', 'ouro_esc': '#8F6E1E', 'celeste_esc': '#245F86', 'lilas_esc': '#5E3A86',
    'pele': '#D6B892', 'pele_esc': '#A9845F', 'cera': '#EBCB78', 'cera_esc': '#C99A45',
    'latao': '#C8963E', 'ferro': '#6A6874', 'estanho': '#A6A2AC', 'madeira': '#8A5A36', 'madeira_clara': '#A8774A',
    'lona': '#C9B48A', 'lona_esc': '#8C7A5C', 'bronze': '#A6763A', 'tinta': '#1E1824',
    'fuligem': '#4A4256', 'lodo': '#4A4436', 'lodo_claro': '#6A5E48', 'junco': '#8A8450', 'osso': '#D8CFB8',
    'branco_olho': '#F4ECD8', 'sal': '#E8E4DA', 'graxa': '#3A2E26', 'pedra': '#6E6A66', 'pedra_esc': '#4A4750',
}

def rgb(h):
    if not h.startswith('#'):
        h = P[h]
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
