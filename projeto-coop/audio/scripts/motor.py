"""Motor de mixagem offline do Plumbdeep.
Reproduz em numpy a MESMA logica de camadas que o som.gd executa no Godot
(escolha sem repetir, variacao de pitch/volume, atraso entre camadas, escala por peso),
para assar os sons compostos e montar a trilha de demonstracao."""
import os, json, numpy as np, soundfile as sf
from scipy.signal import resample_poly
import pyloudnorm as pyln

SR = 48000
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_cache = {}


def db(v):
    return 10.0 ** (v / 20.0)


def carrega(rel):
    """le um .ogg da biblioteca (caminho relativo a som/) como float64 [n, canais] a 48 kHz."""
    if rel not in _cache:
        x, sr = sf.read(os.path.join(RAIZ, rel), always_2d=True, dtype='float64')
        if sr != SR:
            x = resample_poly(x, SR, sr, axis=0)
        _cache[rel] = x
    return _cache[rel]


def varispeed(x, p):
    """p > 1 = mais agudo e mais curto (igual ao pitch_scale do Godot)."""
    if abs(p - 1.0) < 1e-4:
        return x
    up = int(round(1000 / p))
    return resample_poly(x, up, 1000, axis=0)


def corta(x, max_s, fade_s=0.04):
    if max_s is None or len(x) <= int(max_s * SR):
        return x
    x = x[:int(max_s * SR)].copy()
    f = int(fade_s * SR)
    x[-f:] *= (np.linspace(1, 0, f) ** 2)[:, None]
    return x


def tp_db(x):
    y = resample_poly(x, 4, 1, axis=0)
    return 20 * np.log10(np.abs(y).max() + 1e-12)


def lufs(x):
    m = pyln.Meter(SR)
    xp = x if len(x) > 0.5 * SR else np.vstack([x, np.zeros((int(0.5 * SR), x.shape[1]))])
    try:
        return float(m.integrated_loudness(xp))
    except Exception:
        return float('nan')


class Escolhedor:
    """escolha aleatoria sem repetir a ultima variacao de cada grupo (como o som.gd)."""

    def __init__(self, grupos, seed=7):
        self.g = grupos
        self.rng = np.random.default_rng(seed)
        self.ultimo = {}

    def escolhe(self, grupo, indices=None):
        arqs = self.g[grupo]['arquivos']
        cand = list(indices) if indices else list(range(len(arqs)))
        ult = self.ultimo.get(grupo, -1)
        if len(cand) > 1 and ult in cand:
            cand.remove(ult)
        i = cand[int(self.rng.integers(len(cand)))]
        self.ultimo[grupo] = i
        return i, arqs[i]


def camadas_do_evento(ev, alvo=None):
    cs = list(ev['camadas'])
    alvos = ev.get('alvos') or {}
    a = alvo if alvo is not None else ev.get('alvo_padrao')
    if a and a in alvos:
        cs += alvos[a]
    return cs


def instancia(ev, esc, peso=1.0, alvo=None, camadas=None, indice0=None):
    """devolve a lista de vozes (arquivo, atraso_s, pitch, ganho_linear) que o som.gd tocaria."""
    rng = esc.rng
    pv_ev = ev.get('pitch_var', 0.04)
    p_ev = ev.get('pitch', 1.0) * (1 + rng.uniform(-pv_ev, pv_ev))
    p_ev *= 1.0 - (peso - 0.5) * ev.get('peso_pitch', 0.0)
    v_ev = ev.get('volume_db', 0.0) + rng.uniform(-1, 1) * ev.get('volume_var_db', 1.5) + (peso - 1.0) * ev.get('peso_volume_db', 0.0)
    vozes = []
    for n, c in enumerate(camadas if camadas is not None else camadas_do_evento(ev, alvo)):
        if c.get('probabilidade', 1.0) < 1.0 and rng.random() > c['probabilidade']:
            continue
        vol = v_ev + c.get('volume_db', 0.0) + rng.uniform(-1, 1) * c.get('volume_var_db', 0.75)
        if c.get('escala_peso'):
            if peso < c.get('peso_min', 0.2):
                continue
            vol += (peso - 1.0) * 12.0
        pv = c.get('pitch_var', 0.02)
        p = p_ev * c.get('pitch', 1.0) * (1 + rng.uniform(-pv, pv))
        at = c.get('atraso_ms', 0.0) + rng.uniform(0, c.get('atraso_var_ms', 0.0))
        if n == 0 and indice0 is not None:
            i, arq = indice0, esc.g[c['grupo']]['arquivos'][indice0]
            esc.ultimo[c['grupo']] = i
        else:
            i, arq = esc.escolhe(c['grupo'], c.get('indices'))
        vol += esc.g[c['grupo']].get('ganho_db', [0.0] * (i + 1))[i]
        vozes.append(dict(arquivo=arq, grupo=c['grupo'], indice=i, atraso_s=at / 1000.0, pitch=p, ganho=db(vol),
                          max_s=c.get('max_s'), papel=c.get('papel', '')))
    return vozes


def renderiza(vozes, ch=1, pan=0.0):
    """mistura as vozes num buffer. pan em [-1,1] (lei de potencia constante) quando ch == 2."""
    partes = []
    for v in vozes:
        x = carrega(v['arquivo'])
        if x.shape[1] > 1 and ch == 1:
            x = x.mean(1, keepdims=True)
        x = corta(varispeed(x, v['pitch']), v.get('max_s')) * v['ganho']
        partes.append((int(round(v['atraso_s'] * SR)), x))
    if not partes:
        return np.zeros((1, ch))
    n = max(o + len(x) for o, x in partes)
    y = np.zeros((n, ch))
    for o, x in partes:
        if ch == 2 and x.shape[1] == 1:
            a = (pan + 1) * np.pi / 4
            x = np.hstack([x * np.cos(a), x * np.sin(a)])
        y[o:o + len(x)] += x[:, :ch]
    return y


def apara_inicio(x, lead_db=-45):
    m = np.abs(x).max(1)
    on = np.where(m > m.max() * db(lead_db))[0]
    a = max(0, on[0] - int(0.002 * SR))
    x = x[a:].copy()
    fi = int(0.002 * SR)
    x[:fi] *= np.linspace(0, 1, fi)[:, None]
    m = np.abs(x).max(1)
    on2 = np.where(m > m.max() * db(-60))[0]
    x = x[:min(len(x), on2[-1] + int(0.03 * SR))]
    fo = int(min(0.12, 0.2 * len(x) / SR) * SR)
    x[-fo:] *= (np.linspace(1, 0, fo) ** 2)[:, None]
    return x


def momentaneo_max(x):
    """loudness momentaneo maximo (janela de 400 ms, ponderacao K), em LUFS: medida melhor que o integrado para sons curtos."""
    meter = pyln.Meter(SR)
    y = x.astype(np.float64).copy()
    for f in meter._filters.values():
        y = np.stack([f.apply_filter(y[:, c]) for c in range(y.shape[1])], 1)
    w = int(0.4 * SR)
    if len(y) < w:
        y = np.vstack([y, np.zeros((w - len(y), y.shape[1]))])
    p = np.cumsum(np.vstack([np.zeros((1, y.shape[1])), y ** 2]), 0)
    hop = int(0.01 * SR)
    idx = np.arange(0, len(y) - w + 1, hop)
    ms = (p[idx + w] - p[idx]) / w
    return float(-0.691 + 10 * np.log10(ms.sum(1).max() + 1e-20))


def limitador(x, teto_db=-1.3, ataque_ms=1.5, soltura_ms=40.0):
    """limitador de pico com antecipacao (deteccao com sobreamostragem 4x). Devolve (y, reducao_max_db)."""
    from scipy.ndimage import minimum_filter1d
    det = np.abs(resample_poly(x, 4, 1, axis=0)).max(1).reshape(-1, 4).max(1)[:len(x)]
    if len(det) < len(x):
        det = np.concatenate([det, np.zeros(len(x) - len(det))])
    teto = db(teto_db)
    g = np.minimum(1.0, teto / (det + 1e-12))
    la = max(1, int(ataque_ms * SR / 1000))
    g = minimum_filter1d(g, 2 * la + 1)
    a = np.exp(-1.0 / (soltura_ms * SR / 1000))
    out = np.empty_like(g)
    prev = 1.0
    for i, gi in enumerate(g):  # soltura exponencial (subida lenta, descida imediata)
        prev = gi if gi < prev else gi + (prev - gi) * a
        out[i] = prev
    # suaviza a descida dentro da janela de antecipacao
    k = np.hanning(2 * la + 1); k /= k.sum()
    out = np.minimum(out, np.convolve(np.pad(out, la, mode='edge'), k, mode='valid'))
    return x * out[:, None], float(-20 * np.log10(out.min() + 1e-12))
