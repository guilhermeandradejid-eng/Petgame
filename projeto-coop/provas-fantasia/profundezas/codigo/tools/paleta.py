# Paleta mestra de Plumbdeep (seção 11 do conceito): 22 cores. As derivadas abaixo são misturas declaradas
# dessas 22 (pele = osso + ocre, couro = ocre + preto de lavagem etc.), como um pintor de miniatura faria com
# um jogo curto de tintas. A cor base vai na cor de vértice; o shader mini_pintada faz lavagem, luz zenital,
# luz de aresta, metal pintado, brilho pintado e lascas.
MESTRA = {
    'primer': '#16141A', 'ardosia_funda': '#2C3340', 'ardosia': '#4A5463', 'aresta_pedra': '#7A8594',
    'musgo': '#2F4632', 'ciano': '#5FD6D0', 'dourado': '#E6C77A', 'ocre': '#7A5234', 'osso': '#D8CCB4',
    'forja': '#E8833A', 'azul_negro': '#141C2B', 'violeta': '#7B5FC4', 'chumbo': '#9AA0A8', 'primer_cinza': '#8C8A86',
    'nevoa_fria': '#5C6B80', 'nevoa_cinza': '#6E5E52', 'magenta': '#F03C9E',
    'ambar': '#F0A030', 'veneno': '#7CD04A', 'cobalto': '#3E7CF0', 'giz': '#F2EEE6', 'lavagem': '#24180F',
}
DERIVADAS = {
    # gente (quente)
    'pele': '#C99476', 'pele_esc': '#9A6A50', 'couro': '#5E4030', 'couro_claro': '#9A7048', 'madeira': '#7E5A38',
    'madeira_clara': '#A07A4E', 'lona': '#8E8270', 'lona_esc': '#5A5246', 'cal': '#E4DED2', 'cera': '#E8DDBE',
    'resina': '#E09A2A', 'corda': '#A88A56', 'corda_esc': '#6E5636', 'tinta': '#1C1418', 'branco_olho': '#F2EDE2',
    'ferro': '#6E7480', 'bronze': '#A87A3E', 'latao': '#C49A52', 'preto_pano': '#2A2630', 'terra': '#4E3C2E',
    'cobalto_esc': '#1E3C80', 'veneno_esc': '#3A6A24', 'ambar_esc': '#8A5414', 'giz_esc': '#9A968E', 'rubor': '#B8705A', 'cabelo': '#4A3224', 'ruivo': '#8A4A2E',
    # peles por herói (v2): cada um tem tom e marca próprios
    'pele_escorador': '#9E6446', 'pele_cristaleira': '#DCB9A6', 'pele_coveira': '#A79E94', 'pele_gancheiro': '#7E6248',
    'fuligem': '#2A2228', 'cicatriz': '#C88A78', 'olheira': '#6A5A5E',
    'quartzo': '#D8E6F0', 'geodo': '#F4E2B0',
    # abismo (frio)
    'ouvidor': '#262C30', 'ouvidor_esc': '#161A1E', 'trapo': '#1E1A22', 'bocalume': '#1E2438', 'bocalume_esc': '#121522',
    'gesso': '#CFC6B4', 'boca': '#3A2A30',
}
P = dict(MESTRA); P.update(DERIVADAS)

def rgb(h):
    if not h.startswith('#'):
        h = P[h]
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
