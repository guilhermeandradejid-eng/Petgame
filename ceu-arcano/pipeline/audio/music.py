"""Music for Céu Arcano: composition data + arrangement + mixdown/mastering.

All four pieces are original.  Shared "lantern motif" (scale degrees
5-1-2-3, rising) ties title, select and victory together.

    title   D major,  80 BPM, 24 bars (72 s)  - celesta, music box, harp, pads
    select  B minor, 120 BPM, 24 bars (48 s)  - e-piano, glass lead, pulse bass
    battle  E minor, 165 BPM, 64 bars (93 s)  - drums, synth bass, brass/supersaw
    victory D major, 132 BPM, fanfare (~7 s, one-shot)
"""
from __future__ import annotations

import itertools
import math
from collections import defaultdict

import numpy as np

import instruments as I
import synth as S
from synth import SR, ns, note

# ==========================================================================
# music theory helpers
# ==========================================================================

QUAL = {
    "": (0, 4, 7), "m": (0, 3, 7), "5": (0, 7), "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9),
    "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11), "m7": (0, 3, 7, 10), "9": (0, 4, 7, 10, 14),
    "maj9": (0, 4, 7, 11, 14), "m9": (0, 3, 7, 10, 14), "add9": (0, 4, 7, 14),
    "madd9": (0, 3, 7, 14), "sus2": (0, 2, 7), "sus4": (0, 5, 7), "7sus4": (0, 5, 7, 10),
    "dim": (0, 3, 6), "m7b5": (0, 3, 6, 10), "6/9": (0, 4, 7, 9, 14), "7b9": (0, 4, 7, 10, 13),
}


def pc_of(name: str) -> int:
    return note(name + "4") % 12


def parse_chord(sym: str):
    i = 2 if len(sym) > 1 and sym[1] in "#b" else 1
    root, rest = sym[:i], sym[i:]
    bass = None
    if "/" in rest and rest != "6/9":
        rest, bass = rest.split("/")
    rpc = pc_of(root)
    return rpc, QUAL[rest], (pc_of(bass) if bass else rpc)


def chord_pcs(sym: str) -> set:
    rpc, ivs, _ = parse_chord(sym)
    return {(rpc + iv) % 12 for iv in ivs}


def _qual_set(sym):
    return set(parse_chord(sym)[1])


def _voicing_tones(sym: str, nv: int):
    """Pick nv chord tones: drop the 5th (then root) when too many, double root/5th when too few."""
    rpc, ivs, _ = parse_chord(sym)
    ivs = list(ivs)
    while len(ivs) > nv:
        if 7 in ivs and len(ivs) > 3:
            ivs.remove(7)
        else:
            ivs.remove(0)
    extra = [0, 7, 4, 3]
    k = 0
    while len(ivs) < nv:
        e = extra[k % len(extra)]
        if e in _qual_set(sym):
            ivs.append(e + 12)
        k += 1
    return [(rpc + iv) % 12 for iv in ivs]


def voice_lead(symbols, nv=4, lo=52, hi=76, center=64.0, max_span=19):
    """Choose a voicing per chord that minimises voice movement (smooth voice leading)."""
    out = []
    prev = None
    for sym in symbols:
        tones = _voicing_tones(sym, nv)
        opts = [[m for m in range(lo, hi + 1) if m % 12 == pc] for pc in tones]
        best, bc = None, 1e9
        for combo in itertools.product(*opts):
            v = sorted(combo)
            if len(set(v)) < nv or v[-1] - v[0] > max_span:
                continue
            gaps = np.diff(v)
            if np.any(gaps > 12):
                continue
            low = np.array(v[:-1]) < 60
            c = 0.25 * abs(np.mean(v) - center) + 0.9 * np.sum(gaps == 1) + 0.25 * np.sum(gaps == 2)
            c += 3.0 * np.sum((gaps == 1) & low) + 0.8 * np.sum((gaps == 2) & (np.array(v[:-1]) < 55))
            if prev is None:
                c += 0.05 * (v[-1] - v[0])
            else:
                c += sum(abs(a - b) for a, b in zip(v, prev))
            if c < bc:
                best, bc = tuple(v), c
        if best is None:
            raise ValueError(f"no voicing for {sym}")
        out.append(best)
        prev = best
    return out


def bass_midi(sym: str, lo: int) -> int:
    _, _, bpc = parse_chord(sym)
    return lo + ((bpc - lo) % 12)


def root_midi(sym: str, lo: int) -> int:
    rpc, _, _ = parse_chord(sym)
    return lo + ((rpc - lo) % 12)


def timeline(chart, bpb=4):
    """Expand a list of bars ('Em' or 'B7sus4|B7') into (beat, dur, sym)."""
    out = []
    for i, b in enumerate(chart):
        parts = b.split("|")
        d = bpb / len(parts)
        for k, p in enumerate(parts):
            out.append((i * bpb + k * d, d, p))
    return out


def chord_at(tl, beat):
    for b, d, s in tl:
        if b <= beat + 1e-6 < b + d:
            return s
    return tl[-1][2]


def mel(bars, start_bar=0, unit=0.5, bpb=4, transpose=0):
    """Parse melody bars: tokens 'E5:2' (note, length in units), 'r:1' rest,
    prefix '>' accent, '-' soft.  Each bar must sum to one bar."""
    notes = []
    per_bar = bpb / unit
    for i, bar in enumerate(bars):
        pos = 0.0
        for tok in bar.split():
            vel = 0.85
            if tok[0] == ">":
                vel, tok = 1.0, tok[1:]
            elif tok[0] == "-":
                vel, tok = 0.6, tok[1:]
            name, d = tok.split(":")
            d = float(d)
            if name != "r":
                notes.append(((start_bar + i) * bpb + pos * unit, d * unit, note(name) + transpose, vel))
            pos += d
        if abs(pos - per_bar) > 1e-6:
            raise ValueError(f"bar {start_bar + i} has {pos} units, expected {per_bar}: {bar!r}")
    return notes


def harmonize(notes, tl, scale_pcs, below=True):
    """Chord-aware harmony line: nearest chord tone 3-7 semitones below the
    melody note (or a diatonic third for passing tones)."""
    out = []
    scale = sorted(scale_pcs)
    for b, d, m, v in notes:
        pcs = chord_pcs(chord_at(tl, b))
        h = None
        if m % 12 in pcs or d >= 1.0:
            for k in range(3, 8):
                if (m - k) % 12 in pcs:
                    h = m - k
                    break
        if h is None:
            # diatonic third (or fourth) below that does not rub a semitone against the chord
            def rubs(x):
                return any(((x - p) % 12) in (1, 11) for p in pcs)
            cands = [m - k for k in (3, 4, 5) if (m - k) % 12 in scale]
            good = [c for c in cands if not rubs(c)]
            h = good[0] if good else (cands[0] if cands else m - 3)
        out.append((b, d, h, v))
    return out


# ==========================================================================
# arrangement container
# ==========================================================================

DEBUG = False


class Song:
    def __init__(self, name, bpm, bars, bpb=4, tail=8.0, loop=True):
        self.name, self.bpm, self.bars, self.bpb, self.loop = name, bpm, bars, bpb, loop
        self.spb = 60.0 / bpm
        self.L = int(round(bars * bpb * self.spb * SR))
        self.N = self.L + ns(tail)
        self.dry = np.zeros((self.N, 2))
        self.rev = np.zeros((self.N, 2))
        self.dly = np.zeros((self.N, 2))
        self.duck = np.zeros(self.N)
        self.rng = S.rng_for("song:" + name)
        self.stats = defaultdict(float)
        self.debug_groups = {} if DEBUG else None  # per-group dry buffers (mix analysis only)

    def smp(self, beat):
        return int(round(beat * self.spb * SR))

    def put(self, x, beat, gain=1.0, pan=0.0, rev=0.0, dly=0.0, duck=0.0, jitter=0.003, group="misc"):
        st = self.smp(beat)
        if jitter:
            st += int(round(self.rng.normal(0.0, jitter) * SR))
        y = S.pan(x, pan) if (x.ndim == 1 or pan) else x
        if duck > 0:
            d = np.zeros(len(y))
            a, b = max(st, 0), min(self.N, st + len(y))
            if b > a:
                d[a - st:b - st] = self.duck[a:b]
            y = y * (1.0 - duck * d)[:, None]
        targets = [(self.dry, gain), (self.rev, gain * rev), (self.dly, gain * dly)]
        for buf, g in targets:
            if g:
                S.mix_into(buf, y, st, g)
                if st < 0 and self.loop:  # attack before the loop start wraps to the loop end
                    S.mix_into(buf, y[:-st], self.L + st, g)
        self.stats[group] += gain * gain * float(np.sum(y * y))
        if self.debug_groups is not None:
            key = group.split(":")[0]
            if key not in self.debug_groups:
                self.debug_groups[key] = np.zeros((self.N, 2), dtype=np.float32)
            S.mix_into(self.debug_groups[key], y.astype(np.float32), st, gain)

    def duck_at(self, beat, release=0.11, hold=0.006):
        st = self.smp(beat)
        n = ns(hold + release * 4)
        t = np.arange(n) / SR
        shape = np.where(t < hold, 1.0, np.exp(-(t - hold) / release))
        a, b = max(st, 0), min(self.N, st + n)
        if b > a:
            self.duck[a:b] = np.maximum(self.duck[a:b], shape[a - st:b - st])

    def notes(self, inst, notes, gain=1.0, pan=0.0, rev=0.0, dly=0.0, duck=0.0, group="misc",
              legato=1.0, jitter=0.003, **kw):
        for b, d, m, v in notes:
            dur = round(d * self.spb * legato, 3)
            if inst in VEL_INST:
                sig, g = inst(int(m), dur, round(v, 2), **kw), gain
            else:
                sig, g = inst(int(m), dur, **kw), gain * v
            self.put(sig, b, g, pan, rev, dly, duck, jitter, group)

    def report(self):
        tot = sum(self.stats.values()) + 1e-12
        return {k: round(10 * math.log10(v / tot + 1e-12), 1) for k, v in sorted(self.stats.items())}


VEL_INST = {I.supersaw_lead, I.brass, I.glass_lead, I.epiano, I.pluck}


DRUM_VEL = {"X": 1.0, "x": 0.8, "o": 0.5, "g": 0.3}
for _d in "123456789":
    DRUM_VEL[_d] = int(_d) / 9.0


def drums(song, bar, pats, kit, steps=16):
    """pats: {voice: 'x...'}; kit: {voice: (fn(i)->sig, gain, pan, rev, duck_source)}"""
    for voice, pat in pats.items():
        if len(pat) != steps:
            raise ValueError(f"bad pattern length {voice}: {pat}")
        fn, g, p, rv = kit[voice][:4]
        is_kick = len(kit[voice]) > 4 and kit[voice][4]
        for st, ch in enumerate(pat):
            if ch == ".":
                continue
            vel = DRUM_VEL[ch]
            beat = bar * song.bpb + st * (song.bpb / steps)
            sig = fn(st + bar * steps)
            pp = p(st) if callable(p) else p
            song.put(sig, beat, g * vel, pp, rv, 0.0, 0.0, 0.0012 if not is_kick else 0.0, "drums:" + voice)
            if is_kick:
                song.duck_at(beat)


def bass_pattern(song, tl, bar0, bar1, pat, lo, inst, gain, scale_pcs, rev=0.0, duck=0.0, **kw):
    """8th-note bass patterns. 'R' root, 'O' octave, 'F' fifth, 'A' approach to next chord,
    '-' tie, '.' rest."""
    events = []
    for bar in range(bar0, bar1):
        p = pat if isinstance(pat, str) else pat[(bar - bar0) % len(pat)]
        for i, ch in enumerate(p):
            beat = bar * 4 + i * 0.5
            sym = chord_at(tl, beat)
            r = bass_midi(sym, lo)
            if ch == "-":
                if events:
                    events[-1][1] += 0.5
                continue
            if ch == ".":
                continue
            if ch == "R":
                m = r
            elif ch == "O":
                m = r + 12
            elif ch == "F":
                m = r + 7 if r + 7 <= lo + 14 else r - 5
            elif ch == "A":
                nxt = bass_midi(chord_at(tl, (bar + 1) * 4 if i >= 6 else beat + 0.5), lo)
                cands = [nxt - 2, nxt - 1, nxt + 2, nxt + 1]
                m = next((c for c in cands if c % 12 in scale_pcs and c != r), nxt - 1)
            else:
                raise ValueError(ch)
            acc = 1.0 if i in (0, 4) else 0.75
            events.append([beat, 0.5, m, acc])
    for beat, d, m, acc in events:
        sig = inst(int(m), round(d * song.spb, 3), round(acc, 2), **kw) if inst is I.synth_bass else \
            inst(int(m), round(d * song.spb, 3), **kw)
        song.put(sig, beat, gain * (0.85 + 0.15 * acc), 0.0, rev, 0.0, duck, 0.002, "bass")


# ==========================================================================
# mixdown & mastering
# ==========================================================================

def master(song, rev_cfg, dly_cfg, rev_gain=1.0, target_lufs=-14.0, ceiling_db=-1.7,
           comp_cfg=None, eq=None, width=1.0):
    dly_wet = S.pingpong_delay(song.dly, **dly_cfg)
    rev_in = song.rev + 0.3 * dly_wet
    rev_wet = S.fdn_reverb(rev_in, **rev_cfg)
    mix = song.dry + dly_wet + rev_gain * rev_wet
    if song.loop:
        y = mix[:song.L].copy()
        tail = mix[song.L:]
        k = 0
        while k < len(tail):
            seg = tail[k:k + song.L]
            y[:len(seg)] += seg
            k += song.L
    else:
        y = mix
    circ = song.loop

    def H(f):
        h = S.H_hp(f, 28.0, 2)
        for kind, *args in (eq or []):
            if kind == "low":
                h = h * S.H_shelf(f, args[0], args[1], high=False)
            elif kind == "high":
                h = h * S.H_shelf(f, args[0], args[1], high=True)
            elif kind == "peak":
                h = h * S.H_peak(f, *args)
        return h

    y = S.fft_filter(y, H, circular=circ)
    if width != 1.0:
        # mid/side widening above 300 Hz (low end stays mono)
        mid = 0.5 * (y[:, 0] + y[:, 1])
        side = 0.5 * (y[:, 0] - y[:, 1])
        side = S.fft_filter(side, lambda f: 1.0 + (width - 1.0) * (1.0 - S.H_lp(f, 300.0, 2)), circular=circ)
        y = np.stack([mid + side, mid - side], axis=1)
    cc = dict(thresh_db=-16.0, ratio=2.0, attack=0.015, release=0.2, knee=8.0)
    cc.update(comp_cfg or {})
    proc = (lambda fn, x, **kw: S.cyclic(fn, x, **kw)) if circ else (lambda fn, x, **kw: fn(x, **kw))
    pk = np.max(np.abs(y)) + 1e-12
    y = y / pk * S.db(-6)
    y = proc(S.compressor, y, **cc)
    g = 1.0
    z = y
    for _ in range(6):
        z = proc(S.limiter, y * g, ceiling_db=ceiling_db, release=0.09)
        lv = S.lufs(z)
        if abs(lv - target_lufs) < 0.08:
            break
        g *= float(S.db(target_lufs - lv))
    if not song.loop:
        # trim trailing silence and fade
        a = np.abs(z).max(axis=1)
        live = np.nonzero(a > S.db(-66))[0]
        end = min(len(z), live[-1] + ns(0.05)) if len(live) else len(z)
        z = S.fade_edges(z[:end], 0.0, 0.25)
    return z


# ==========================================================================
# BATTLE - E minor, 165 BPM, 64 bars
# ==========================================================================

EMIN = {4, 6, 7, 9, 11, 0, 2}


def song_battle():
    s = Song("battle", 165, 64, tail=6.0)
    intro = ["Em", "Cmaj7", "D", "B7sus4|B7"]
    verse = ["Em", "Cmaj7", "D", "Bm7", "Em", "C", "Am7", "B7"]
    verse2 = ["Em", "Cmaj7", "D", "Bm7", "Em", "C", "Am7", "B7sus4|B7"]
    pre = ["Am7", "Bm7", "Cmaj7", "D", "Am7", "Bm7", "Cmaj7|D", "B7sus4|B7"]
    chorus = ["Cmaj7", "D", "Bm7", "Em", "Cmaj7", "D", "B7sus4|B7", "Em"]
    brk = ["Cmaj7", "D", "Em", "Em", "Cmaj7", "D", "B7sus4", "B7"]
    build = ["Am7", "Bm7", "Cmaj7", "D"]
    chorus3 = ["Cmaj7", "D", "Bm7", "Em", "Cmaj7", "D", "B7sus4|B7", "Em|B7"]
    chart = intro + verse + verse2 + pre + chorus + chorus + brk + build + chorus3
    assert len(chart) == 64
    tl = timeline(chart)
    syms = [c for _, _, c in tl]
    pad_v = dict(zip(range(len(tl)), voice_lead(syms, 4, 50, 74, 62)))
    stab_v = dict(zip(range(len(tl)), voice_lead(syms, 4, 59, 79, 68)))

    def seg_index(beat):
        for i, (b, d, _) in enumerate(tl):
            if b <= beat + 1e-6 < b + d:
                return i
        return len(tl) - 1

    # ---------------- drums ----------------
    hh_pan = lambda st: 0.35 if st % 2 else 0.2
    kit = {
        "k": (lambda i: I.kick(i % 3), 0.95, 0.0, 0.03, True),
        "s": (lambda i: I.snare(i % 4), 0.4, 0.02, 0.18),
        "c": (lambda i: I.clap(i % 3), 0.26, -0.05, 0.25),
        "h": (lambda i: I.hat(i % 4), 0.15, hh_pan, 0.04),
        "oh": (lambda i: I.hat(i % 2, True), 0.11, 0.3, 0.06),
        "t1": (lambda i: I.tom(196.0, i % 2), 0.45, -0.3, 0.15),
        "t2": (lambda i: I.tom(147.0, i % 2), 0.45, 0.0, 0.15),
        "t3": (lambda i: I.tom(110.0, i % 2), 0.5, 0.3, 0.15),
    }
    P = {
        "intro": dict(k="X.....X.....X...", s="....X.......X...", h="x.x.x.x.x.x.x.x."),
        "verse": dict(k="X.....x.X.x.....", s="....X.......X..g", h="X.x.x.x.X.x.x.x."),
        "verse_b": dict(k="X.....x.X.....x.", s="....X.......X...", h="X.x.x.x.X.x.x...",
                        oh="..............x."),
        "pre": dict(k="X...X...X...X...", s="....X.......X...", h="xoxoxoxoxoxoxoxo"),
        "chorus": dict(k="X.....x.X.....x.", s="....X.......X...", c="....x.......x...",
                       h="x...x...x...x...", oh="..x...x...x...x."),
        "chorus_b": dict(k="X.....x.X.x...x.", s="....X.......X.g.", c="....x.......x...",
                         h="x...x...x...x...", oh="..x...x...x...x."),
        "brk1": dict(k="x...............", h="........g......."),
        "brk2": dict(k="x.........o.....", c="........x.......", h="g.g.g.g.g.g.g.g."),
        "fill_s": dict(k="X.....x.X.......", s="....X.......5789", h="x.x.x.x.x.x....."),
        "fill_t": dict(k="X.....x.X.......", s="....X...X.......", t1="..........xx....",
                       t2="............xx..", t3="..............xX", h="x.x.x.x........."),
        "fill_big": dict(k="X.....x.X.......", s="....X...xxxx....", t1="........xx......",
                         t2="..........xx..x.", t3="............xx.X", h="x.x.x.x........."),
        "b52": dict(k="X...X...X...X...", s="o...o...x...x..."),
        "b53": dict(k="X...X...X...X...", s="o.o.o.o.x.x.x.x."),
        "b54": dict(k="X...X...X...X...", s="3333444455556666"),
        "b55": dict(k="X...X...X.X.X...", s="6677778888999...", t3="............X..."),
    }

    def bar_pat(b):
        if b < 4:
            return P["fill_s"] if b == 3 else P["intro"]
        if b < 12:
            return P["fill_s"] if b == 11 else (P["verse_b"] if b % 2 else P["verse"])
        if b < 20:
            return P["fill_t"] if b == 19 else (P["verse_b"] if b % 2 else P["verse"])
        if b < 28:
            if b == 26:
                return dict(k="X...X...X...X...", s="x.x.x.x.x.x.x.x.", h="xoxoxoxoxoxoxoxo")
            if b == 27:
                return dict(k="X...X...X...X...", s="5566778899999999")
            return P["pre"]
        if b < 44:
            if b == 43:
                return P["fill_big"]
            if b == 35:
                return P["fill_s"]
            return P["chorus_b"] if b % 2 else P["chorus"]
        if b < 52:
            return P["brk1"] if b < 48 else P["brk2"]
        if b < 56:
            return P["b%d" % b]
        if b == 63:
            return P["fill_big"]
        return P["chorus_b"] if b % 2 else P["chorus"]

    for b in range(64):
        drums(s, b, bar_pat(b), kit)
    for b in (0, 4, 12, 20, 28, 32, 36, 40, 56, 60):
        s.put(I.crash(b % 3), b * 4, 0.24, 0.0, 0.15, group="drums:crash")
    s.put(I.crash(1), 44 * 4, 0.2, 0.0, 0.3, group="drums:crash")
    for b in (28, 56, 64):
        rc = I.rev_cymbal(round(2 * s.spb, 3))
        s.put(rc, b * 4 - 2, 0.3, 0.0, 0.2, jitter=0, group="fx")
    for b in (0, 28, 56):
        s.put(I.impact(), b * 4, 0.55, 0.0, 0.2, jitter=0, group="fx")
    s.put(I.riser(round(4 * 4 * s.spb, 3)), 24 * 4, 0.16, 0.0, 0.25, jitter=0, group="fx")
    s.put(I.riser(round(4 * 4 * s.spb, 3)), 52 * 4, 0.2, 0.0, 0.25, jitter=0, group="fx")

    # ---------------- bass ----------------
    lo = note("E1")
    bp = [("tresillo", 0, 4, "R--R--O-"), ("drive", 4, 20, "RRORRORA"), ("pre", 20, 28, "RRRRRRRO"),
          ("oct", 28, 44, "RORORORO"), ("whole", 44, 52, "R-------"), ("build", 52, 56, "RRRRRRRR"),
          ("oct", 56, 64, "RORORORO")]
    for name, b0, b1, pat in bp:
        if name == "whole":
            for b in range(b0, b1):
                sym = chord_at(tl, b * 4)
                sig = I.soft_bass(bass_midi(sym, lo) + 12, round(4 * s.spb, 3))
                s.put(sig, b * 4, 0.22, 0, 0.0, 0, 0.0, 0.0, "bass")
                s.put(I.soft_bass(bass_midi(sym, lo), round(4 * s.spb, 3)), b * 4, 0.27, 0, 0, 0, 0, 0, "bass")
        elif name == "build":
            for b in range(b0, b1):
                bass_pattern(s, tl, b, b + 1, pat, lo, I.synth_bass, 0.6, EMIN, duck=0.3,
                             open_=round(0.45 + 0.18 * (b - b0), 2))
        else:
            bass_pattern(s, tl, b0, b1, pat, lo, I.synth_bass, 0.6, EMIN, duck=0.3)

    # ---------------- harmony: pads, stabs, arps ----------------
    def pads(b0, b1, gain, cutoff=1800.0, attack=0.25):
        for i, (b, d, sym) in enumerate(tl):
            if b0 * 4 <= b < b1 * 4:
                sig = I.warm_pad(pad_v[i], round(d * s.spb + 0.05, 3), cutoff, attack, 0.6, 12.0)
                s.put(sig, b, gain, 0, 0.35, 0, 0.6, 0.0, "pad")

    pads(20, 28, 0.3, 1500)
    pads(28, 44, 0.33, 2200)
    pads(44, 52, 0.22, 1100, 0.6)
    pads(52, 56, 0.3, 1600)
    pads(56, 64, 0.36, 2400)

    def stabs(b0, b1, positions, gain, bright, durs=None):
        for b in range(b0, b1):
            for j, p in enumerate(positions):
                beat = b * 4 + p * 0.5
                i = seg_index(beat)
                d = (durs[j] if durs else 0.5) * 0.5
                br = bright(b) if callable(bright) else bright
                sig = I.stab(stab_v[i], round(min(d * s.spb, 0.6), 3), round(br, 2))
                s.put(sig, beat, gain, 0, 0.2, 0.08, 0.4, 0.0015, "stabs")

    hook_pos, hook_dur = [0, 1, 2, 5, 6], [1, 1, 3, 1, 2]
    stabs(0, 2, hook_pos, 0.55, 1.0, hook_dur)
    stabs(2, 4, [0, 3, 6], 0.55, 1.0, [3, 3, 2])
    stabs(4, 20, [1, 3, 5, 7], 0.3, 0.55)
    stabs(20, 28, [0, 3, 6], 0.36, 0.75, [3, 3, 2])
    stabs(28, 44, [1, 3, 5, 7], 0.22, 0.6)
    stabs(52, 56, list(range(8)), 0.32, lambda b: 0.25 + 0.25 * (b - 52))
    stabs(56, 64, [1, 3, 5, 7], 0.24, 0.65)

    def arps(b0, b1, gain, bright=1.0, octave=12):
        pat = [0, 1, 2, 3, 4, 3, 2, 1]
        for b in range(b0, b1):
            for k in range(16):
                beat = b * 4 + k * 0.25
                v = pad_v[seg_index(beat)]
                idx = pat[k % 8]
                m = (v[0] + 12 if idx == 4 else v[idx]) + octave
                sig = I.arp_pluck(int(m), bright)
                s.put(sig, beat, gain * (1.0 if k % 4 == 0 else 0.7), 0.55 if k % 2 else -0.55,
                      0.15, 0.35, 0.3, 0.001, "arp")

    arps(12, 20, 0.45, 0.7)
    arps(36, 44, 0.5, 0.9)
    arps(52, 56, 0.4, 0.6)
    arps(56, 64, 0.52, 1.0)

    # ---------------- melodies ----------------
    V = ["E5:1 r:1 E5:1 G5:1 r:1 A5:1 B5:2",
         "r:1 A5:1 G5:1 E5:1 r:1 D5:1 E5:2",
         "F#5:1 r:1 F#5:1 A5:1 r:1 B5:1 A5:2",
         "r:1 F#5:1 E5:1 D5:1 r:1 B4:1 D5:2",
         "E5:1 r:1 E5:1 G5:1 r:1 A5:1 B5:2",
         "r:1 C6:1 B5:1 G5:1 r:1 E5:1 G5:2",
         "A5:1 r:1 A5:1 C6:1 r:1 B5:1 A5:2",
         "F#5:2 D#5:2 B4:2 r:2"]
    V2_lead = ["E5:1 r:1 E5:1 G5:1 r:1 A5:1 B5:2",
               "r:1 A5:1 G5:1 E5:1 r:1 D5:1 E5:2",
               "r:8", "r:8",
               "E5:1 r:1 E5:1 G5:1 r:1 A5:1 B5:2",
               "r:1 C6:1 B5:1 G5:1 r:1 E6:1 D6:2",
               "r:8", "r:8"]
    V2_answer = ["r:8", "r:8",
                 "F#6:1 E6:1 D6:1 A5:1 r:1 D6:1 E6:1 F#6:1",
                 "D6:2 B5:2 A5:2 F#5:2",
                 "r:8", "r:8",
                 "E6:1 D6:1 C6:1 A5:1 r:1 C6:1 D6:1 E6:1",
                 "F#6:3 E6:1 D#6:2 B5:2"]
    PRE = ["A5:2 G5:1 E5:3 r:2",
           "B5:2 A5:1 F#5:3 r:2",
           "C6:2 B5:1 G5:3 r:2",
           "D6:2 C6:1 A5:3 F#5:2",
           "E6:3 D6:1 C6:2 A5:2",
           "D6:3 B5:1 A5:2 F#5:2",
           "G5:2 B5:2 A5:2 D6:2",
           "E6:3 F#6:1 >D#6:4"]
    CH = ["E5:1 G5:1 >B5:3 A5:1 G5:2",
          "F#5:1 G5:1 >A5:3 D5:1 F#5:2",
          "B5:1 D6:1 >F#6:3 E6:1 D6:2",
          "E6:2 B5:2 G5:2 E5:1 F#5:1",
          "E5:1 G5:1 >B5:3 A5:1 G5:2",
          "F#5:1 G5:1 >A5:3 B5:1 D6:2",
          ">E6:3 D#6:1 >F#6:2 D#6:2",
          ">E6:6 r:2"]
    CH3 = CH[:7] + [">E6:4 r:4"]
    CH_COUNTER = ["E5:6 D5:2", "D5:4 A4:4", "B4:4 A4:4", "G4:4 B4:2 D5:2",
                  "E5:6 G5:2", "D5:4 F#5:4", "B4:3 D#5:5", "E5:4 B4:4"]
    BRK = ["E5:1 G5:1 B5:6", "F#5:1 G5:1 A5:6", "B5:1 D6:1 E6:6", "r:8",
           "E5:1 G5:1 B5:6", "F#5:1 G5:1 A5:3 B5:1 D6:2", "E6:8", "D#6:4 F#6:4"]

    lead_kw = dict(rev=0.18, dly=0.16, group="lead")
    s.notes(I.brass, mel(V, 4), 0.58, 0.0, legato=0.92, **lead_kw)
    s.notes(I.brass, mel(V2_lead, 12), 0.58, 0.0, legato=0.92, **lead_kw)
    s.notes(I.pluck, mel(V2_answer, 12), 0.55, 0.15, rev=0.25, dly=0.25, group="counter")
    s.notes(I.pluck, mel(V2_answer, 12, transpose=-12), 0.25, -0.2, rev=0.2, dly=0.1, group="counter")
    s.notes(I.brass, mel(PRE, 20), 0.56, 0.0, legato=0.97, **lead_kw)
    for b0 in (28, 36):
        lead = mel(CH, b0)
        s.notes(I.supersaw_lead, lead, 0.44, 0.0, legato=0.95, **lead_kw)
        s.notes(I.brass, [(b, d, m - 12, v) for b, d, m, v in lead], 0.22, 0.0, legato=0.95, rev=0.1,
                group="lead")
        s.notes(I.brass, mel(CH_COUNTER, b0), 0.34, -0.25, rev=0.25, legato=0.98, group="counter")
    s.notes(I.pluck, harmonize(mel(CH, 36), tl, EMIN), 0.28, 0.3, rev=0.2, dly=0.2, group="counter")
    brk = mel(BRK, 44, transpose=12)
    s.notes(I.fm_bell, [(b, d, m, v) for b, d, m, v in brk], 0.25, 0.15, rev=0.45, dly=0.35, group="lead")
    s.notes(I.celesta, [(b, d, m - 12, v) for b, d, m, v in brk], 0.25, -0.15, rev=0.4, dly=0.25, group="lead")
    s.notes(I.brass, mel(PRE[:4], 52), 0.52, 0.0, legato=0.97, **lead_kw)
    lead3 = mel(CH3, 56)
    s.notes(I.supersaw_lead, lead3, 0.46, 0.0, legato=0.95, **lead_kw)
    s.notes(I.brass, [(b, d, m - 12, v) for b, d, m, v in lead3], 0.24, 0.0, legato=0.95, rev=0.1, group="lead")
    s.notes(I.brass, harmonize(lead3, tl, EMIN), 0.26, -0.3, legato=0.95, rev=0.2, group="counter")
    s.notes(I.pluck, mel(CH_COUNTER, 56, transpose=12), 0.26, 0.35, rev=0.25, dly=0.25, group="counter")

    out = master(s, rev_cfg=dict(t60=1.9, damp=0.28, size=1.0, predelay=0.012),
                 dly_cfg=dict(delay=0.75 * s.spb, feedback=0.3, lp=4500, hp=300),
                 rev_gain=0.8, comp_cfg=dict(thresh_db=-15, ratio=2.2),
                 eq=[("low", 90, 1.0), ("peak", 350, -1.5, 0.8), ("high", 9000, 1.0)], width=1.45)
    return s, out


# ==========================================================================
# TITLE - D major, 80 BPM, 24 bars
# ==========================================================================

DMAJ = {2, 4, 6, 7, 9, 11, 1}


def song_title():
    s = Song("title", 80, 24, tail=9.0)
    chart = ["Gmaj9", "D/F#", "Em9", "Asus4|A",
             "Dmaj7", "Bm7", "Gmaj7", "Asus4|A", "D/F#", "Gmaj7", "Em7", "A7sus4|A7",
             "Gmaj7", "A/G", "F#m7", "Bm7", "Em9", "F#m7", "Gmaj7", "Gm6",
             "Dmaj7", "Bm7", "Gmaj7", "A7sus4|A7"]
    tl = timeline(chart)
    syms = [c for _, _, c in tl]
    pv = voice_lead(syms, 4, 50, 74, 62)
    av = voice_lead(syms, 4, 57, 79, 67)

    # pads
    for i, (b, d, sym) in enumerate(tl):
        att = 1.2 if b < 16 else 0.6
        sig = I.warm_pad(pv[i], round(d * s.spb + 0.15, 3), 2000.0 if b < 48 else 2400.0, att, 1.8, 9.0)
        s.put(sig, b, 0.3, 0, 0.45, 0, 0, 0.0, "pad")

    # harp arpeggio (8ths), second layer in B section
    pat = [0, 1, 2, 3, 4, 3, 2, 1]
    for bar in range(24):
        for k in range(8):
            beat = bar * 4 + k * 0.5
            i = next(j for j, (b, d, _) in enumerate(tl) if b <= beat + 1e-6 < b + d)
            v = av[i]
            idx = pat[k]
            m = v[0] + 12 if idx == 4 else v[idx]
            vel = 0.9 if k == 0 else (0.7 if k % 2 == 0 else 0.55)
            if bar >= 20:
                vel *= 0.85
            s.put(I.harp(int(m), 0.4, 1.3), beat, 0.26 * vel, -0.25 if k % 2 else 0.25, 0.3, 0.22, 0, 0.004, "harp")
            if 12 <= bar < 20 and k % 2 == 1:
                s.put(I.harp(int(m) + 12, 0.3, 0.7), beat + 0.25, 0.09, 0.5, 0.35, 0.3, 0, 0.004, "harp")

    # bass
    lo = note("A1")
    for bar in range(24):
        if bar < 12 or bar >= 20:
            pats = "R-----O-" if "|" not in chart[bar] else "R---R---"
        else:
            pats = "R---F---"
        for k, ch in enumerate(pats):
            if ch == "-":
                continue
            beat = bar * 4 + k * 0.5
            L = 1
            while k + L < 8 and pats[k + L] == "-":
                L += 1
            r = bass_midi(chord_at(tl, beat), lo)
            m = {"R": r, "O": r + 12, "F": r + 7 if r + 7 <= lo + 14 else r - 5}[ch]
            s.put(I.soft_bass(int(m), round(L * 0.5 * s.spb * 0.95, 3)), beat, 0.42 if ch == "R" else 0.3,
                  0, 0.05, 0, 0, 0.003, "bass")

    # melody
    MB = ["A5:1 D6:1 E6:2 F#6:4", "E6:3 D6:1 A5:4", "G5:1 B5:1 D6:2 F#6:4", "E6:4 C#6:4"]
    A = ["A4:1 D5:1 E5:2 F#5:4",
         "B5:3 A5:1 F#5:2 D5:2",
         "B4:1 E5:1 F#5:2 G5:2 B5:2",
         "A5:3 G5:1 E5:4",
         "A4:1 D5:1 E5:2 F#5:3 A5:1",
         "B5:3 A5:1 B5:2 D6:2",
         "E6:4 D6:2 B5:2",
         "A5:4 r:2 G5:1 A5:1"]
    B = ["B5:4 A5:2 B5:2",
         "C#6:4 B5:2 C#6:2",
         "E6:3 D6:1 C#6:2 A5:2",
         "D6:6 C#6:1 B5:1",
         "F#6:4 E6:2 D6:2",
         "C#6:4 A5:2 E6:2",
         "F#6:6 E6:2",
         "D6:4 A#5:2 A5:2"]
    OUT = ["A4:1 D5:1 E5:2 F#5:4",
           "B5:3 A5:1 F#5:2 D5:2",
           "B4:1 E5:1 F#5:2 A5:4",
           "G5:3 F#5:1 E5:4"]
    s.notes(I.musicbox, mel(MB, 0), 0.32, 0.2, rev=0.5, dly=0.35, group="mbox")
    s.notes(I.celesta, mel(A, 4), 0.36, 0.0, rev=0.38, dly=0.18, group="lead")
    s.notes(I.celesta, mel(B, 12), 0.36, 0.0, rev=0.38, dly=0.18, group="lead")
    s.notes(I.musicbox, mel(B, 12, transpose=12), 0.14, 0.3, rev=0.5, dly=0.3, group="mbox")
    s.notes(I.celesta, mel(OUT, 20), 0.38, 0.0, rev=0.42, dly=0.22, group="lead")
    s.notes(I.musicbox, mel(OUT[2:], 22, transpose=12), 0.12, -0.3, rev=0.55, dly=0.4, group="mbox")

    # sparkles (lantern twinkles), deterministic
    pent = [note(n) for n in ("D7", "E7", "F#7", "A7", "B7", "D8")]
    for bar in range(4, 24):
        if s.rng.random() < 0.6:
            beat = bar * 4 + s.rng.integers(0, 16) * 0.25
            m = pent[int(s.rng.integers(0, len(pent)))]
            s.put(I.musicbox(m, 0.3), beat, 0.06, float(s.rng.uniform(-0.8, 0.8)), 0.7, 0.5, 0, 0.0, "sparkle")

    # percussion
    kit = {
        "k": (lambda i: I.soft_kick(0), 0.5, 0.0, 0.05, False),
        "r": (lambda i: I.snap(i % 3), 0.2, -0.15, 0.4),
        "sh": (lambda i: I.shaker(i % 4), 0.3, 0.35, 0.15),
    }
    for bar in range(8, 24):
        p = {"sh": "o.x.o.x.o.x.o.x." if bar >= 12 else "....x.......x..."}
        if 12 <= bar < 20:
            p["k"] = "x.........o....."
            p["r"] = "....x.......x..."
            if bar == 19:
                p["r"] = "....x.......x.oo"
        elif bar >= 20:
            p["k"] = "x..............."
            p["sh"] = "....o.......o..."
        drums(s, bar, p, kit)
    for b in (12, 24):
        s.put(I.rev_cymbal(round(4 * s.spb, 3)), b * 4 - 4, 0.12, 0.0, 0.4, jitter=0, group="fx")

    out = master(s, rev_cfg=dict(t60=3.2, damp=0.22, size=1.35, predelay=0.03),
                 dly_cfg=dict(delay=0.75 * s.spb, feedback=0.38, lp=4000, hp=350),
                 rev_gain=0.85, comp_cfg=dict(thresh_db=-18, ratio=2.0, attack=0.03, release=0.3),
                 eq=[("low", 120, 0.5), ("high", 4500, 4.0)], width=1.2)
    return s, out


# ==========================================================================
# SELECT - B minor, 120 BPM, 24 bars
# ==========================================================================

BMIN = {11, 1, 2, 4, 6, 7, 9}


def song_select():
    s = Song("select", 120, 24, tail=7.0)
    chart = ["Bm9", "Gmaj7", "Em9", "F#7sus4|F#7", "Bm9", "Gmaj7", "Em9", "F#7",
             "Gmaj7", "A6", "F#m7", "Bm7", "Gmaj7", "A6", "Bm9", "F#7sus4|F#7",
             "Em9", "F#m7", "Gmaj7", "A6", "Em9", "F#m7", "Gmaj7", "F#7sus4|F#7"]
    tl = timeline(chart)
    syms = [c for _, _, c in tl]
    ev = voice_lead(syms, 4, 52, 72, 62)
    pv = voice_lead(syms, 4, 57, 79, 67)

    def seg(beat):
        return next(j for j, (b, d, _) in enumerate(tl) if b <= beat + 1e-6 < b + d)

    # drums
    kit = {
        "k": (lambda i: I.kick808(0), 0.5, 0.0, 0.02, True),
        "r": (lambda i: I.rim(i % 2), 0.2, -0.2, 0.3),
        "c": (lambda i: I.clap(i % 3), 0.16, 0.05, 0.35),
        "h": (lambda i: I.hat(i % 4), 0.12, 0.3, 0.05),
        "oh": (lambda i: I.hat(i % 2, True), 0.09, -0.3, 0.1),
        "sh": (lambda i: I.shaker(i % 4), 0.1, -0.4, 0.1),
    }
    for bar in range(24):
        if bar < 8:
            p = dict(k="X...............", r="....x.......x...", h="x.x.x.x.x.x.x.x.")
            if bar == 0:
                p["k"] = "X..............."
        elif bar < 16:
            p = dict(k="X.........x.....", r="....x.......x...", c="............x...",
                     h="xoxoxoxoxoxoxoxo", sh="..x...x...x...x.")
        else:
            p = dict(k="X.........x...o.", r="....x.......x...", c="....x.......x...",
                     h="xoxoxoxoxoxo.oxo", oh="............x...", sh="..x...x...x...x.")
        if bar == 23:
            p["r"] = "....x.......xoxx"
        if bar == 15:
            p["r"] = "....x.......x.xx"
        drums(s, bar, p, kit)
    for b in (8, 16, 24):
        s.put(I.rev_cymbal(round(4 * s.spb, 3)), b * 4 - 4, 0.12, 0.0, 0.3, jitter=0, group="fx")
    s.put(I.crash(2), 16 * 4, 0.16, 0.0, 0.3, group="drums:crash")
    s.put(I.riser(round(8 * s.spb, 3), 400.0, 7000.0), 22 * 4, 0.08, 0.0, 0.3, jitter=0, group="fx")

    # e-piano comping
    comp = [(0.0, 1.25, 0.85), (1.5, 0.45, 0.6), (2.5, 1.4, 0.75)]
    for bar in range(24):
        for off, d, v in comp:
            beat = bar * 4 + off
            i = seg(beat)
            for m in ev[i]:
                s.put(I.epiano(int(m), round(d * s.spb, 3), round(v, 2)), beat, 0.17, 0, 0.3, 0.12, 0.25,
                      0.004, "epiano")

    # pulse bass 8ths
    lo = note("B1") - 2  # A1
    for bar in range(24):
        pat = "R.RRR.RR" if bar < 8 else "RRRRRRRA"
        if bar >= 16:
            pat = "RRORRROA"
        op = 0.6 if bar < 8 else (0.85 if bar < 16 else 1.0)
        for k, ch in enumerate(pat):
            if ch == ".":
                continue
            beat = bar * 4 + k * 0.5
            sym = chord_at(tl, beat)
            r = bass_midi(sym, lo)
            if ch == "O":
                m = r + 12
            elif ch == "A":
                nxt = bass_midi(chord_at(tl, (bar + 1) * 4 % 96), lo)
                m = next((c for c in (nxt - 2, nxt - 1, nxt + 2) if c % 12 in BMIN and c != r), nxt - 1)
            else:
                m = r
            s.put(I.pulse_bass(int(m), round(0.5 * s.spb, 3), op), beat,
                  0.55 if k % 2 == 0 else 0.42, 0, 0.0, 0, 0.45, 0.002, "bass")

    # pad from bar 8, brighter from 16
    for i, (b, d, sym) in enumerate(tl):
        if b >= 32:
            sig = I.warm_pad(pv[i], round(d * s.spb + 0.1, 3), 1100.0 if b < 64 else 1700.0, 0.4, 1.0, 10.0)
            s.put(sig, b, 0.24 if b < 64 else 0.3, 0, 0.4, 0, 0.5, 0.0, "pad")

    # arp from bar 16 (16ths, harp, high)
    pat = [0, 2, 1, 3, 2, 4, 3, 1]
    for bar in range(16, 24):
        for k in range(16):
            beat = bar * 4 + k * 0.25
            v = pv[seg(beat)]
            idx = pat[k % 8]
            m = (v[0] + 12 if idx == 4 else v[idx]) + 12
            s.put(I.harp(int(m), 0.12, 0.8), beat, 0.095 * (1.0 if k % 4 == 0 else 0.7),
                  0.4 if k % 2 else -0.4, 0.2, 0.35, 0.3, 0.002, "arp")

    # lantern motif (minor) on bell, melody, call & response
    MOT = ["F#5:1 B5:1 C#6:2 D6:4", "r:8", "r:8", "C#6:4 A#5:4",
           "F#5:1 B5:1 C#6:2 D6:4", "E6:3 D6:1 C#6:4", "r:8", "r:8"]
    s.notes(I.fm_bell, mel(MOT, 0), 0.2, 0.25, rev=0.45, dly=0.35, group="bell", ratio=3.0, index=1.6, tau=1.0)
    LEAD2 = ["F#4:1 B4:1 C#5:2 D5:4",
             "E5:3 F#5:1 C#5:4",
             "C#5:1 E5:1 F#5:2 A5:3 F#5:1",
             "D5:3 C#5:1 B4:4",
             "F#5:1 B5:1 C#6:2 D6:4",
             "E6:3 F#6:1 E6:2 C#6:2",
             "D6:3 C#6:1 B5:4",
             "C#6:4 A#5:4"]
    s.notes(I.glass_lead, mel(LEAD2, 8), 0.28, 0.0, rev=0.3, dly=0.3, legato=0.95, group="lead")
    CALL = ["G5:2 F#5:1 E5:1 F#5:4",
            "A5:2 F#5:1 E5:1 C#5:4",
            "r:8", "r:8",
            "G5:2 F#5:1 E5:1 B5:4",
            "A5:2 C#6:1 E6:1 F#6:4",
            "r:8",
            "B5:4 A#5:4"]
    RESP = ["r:8", "r:8",
            "B5:1 D6:1 F#6:2 E6:2 D6:2",
            "C#6:4 E6:4",
            "r:8", "r:8",
            "F#6:2 E6:2 D6:2 B5:2",
            "r:8"]
    s.notes(I.glass_lead, mel(CALL, 16), 0.28, 0.0, rev=0.3, dly=0.3, legato=0.95, group="lead")
    s.notes(I.fm_bell, mel(RESP, 16), 0.22, 0.2, rev=0.45, dly=0.35, group="bell", ratio=3.0, index=1.6, tau=1.0)
    s.notes(I.celesta, mel(RESP, 16, transpose=-12), 0.18, -0.2, rev=0.4, dly=0.3, group="bell")

    out = master(s, rev_cfg=dict(t60=2.4, damp=0.25, size=1.15, predelay=0.02),
                 dly_cfg=dict(delay=0.75 * s.spb, feedback=0.36, lp=4000, hp=300),
                 rev_gain=0.8, comp_cfg=dict(thresh_db=-16, ratio=2.2),
                 eq=[("low", 100, 0.5), ("high", 5000, 2.5)], width=1.3)
    return s, out


# ==========================================================================
# VICTORY - D major fanfare, 132 BPM
# ==========================================================================

def song_victory():
    s = Song("victory", 132, 3, tail=4.5, loop=False)
    t3 = 1.0 / 3.0
    lead = [(0, t3, "A4"), (t3, t3, "D5"), (2 * t3, t3, "F#5"), (1, 1.5, "A5"), (2.5, 0.5, "F#5"), (3, 1, "A5"),
            (4, 1, "B5"), (5, 0.5, "A5"), (5.5, 0.5, "G5"), (6, 1, "C#6"), (7, 1, "E6"), (8, 3.5, "D6")]
    ln = [(b, d, note(n), 1.0 if d >= 1 else 0.85) for b, d, n in lead]
    s.notes(I.brass, ln, 0.6, 0.0, rev=0.25, dly=0.0, legato=0.95, group="lead")
    s.notes(I.supersaw_lead, ln, 0.26, 0.0, rev=0.25, legato=0.95, group="lead")
    chords = [(0, 1, ("D4", "F#4", "A4", "D5")), (1, 2, ("D4", "F#4", "A4", "D5")),
              (3, 1, ("D4", "F#4", "A4", "D5")), (4, 2, ("D4", "G4", "B4", "D5")),
              (6, 2, ("E4", "A4", "C#5", "E5")), (8, 4, ("D4", "F#4", "A4", "E5"))]
    for b, d, ch in chords:
        midis = tuple(note(n) for n in ch)
        s.put(I.stab(midis, round(min(d * s.spb, 1.2), 3), 1.0), b, 0.2, 0, 0.3, 0, 0, 0.0, "stabs")
        for m in midis:
            s.put(I.brass(m - 12, round(d * s.spb * 0.95, 3), 0.8), b, 0.1, 0, 0.3, 0, 0, 0.003, "brass")
    s.put(I.warm_pad(tuple(note(n) for n in ("D3", "A3", "D4", "F#4", "A4", "E5")), round(4 * s.spb, 3),
                     2500.0, 0.05, 2.5, 10.0), 8, 0.35, 0, 0.5, 0, 0, 0.0, "pad")
    for b, n in ((0, "D2"), (3, "D2"), (4, "G1"), (6, "A1"), (8, "D2")):
        s.put(I.timpani(note(n)), b, 0.32, 0, 0.3, group="timp")
        dur = 4 if b == 8 else (1 if b == 3 else 2 if b in (4, 6) else 3)
        s.put(I.soft_bass(note(n), round(dur * s.spb, 3)), b, 0.4, 0, 0.0, group="bass")
    for k in range(8):  # timpani roll into the last chord
        s.put(I.timpani(note("A1"), k % 2), 6 + k * 0.25, 0.08 + 0.02 * k, 0, 0.3, group="timp")
    for k in range(16):  # snare roll
        s.put(I.snare(k % 4), 6 + k * 0.125, 0.06 + 0.014 * k, 0.05, 0.25, group="drums")
    for b in (0, 4, 6):
        s.put(I.kick(0), b, 0.5, 0, 0.05, group="drums")
    s.put(I.kick(1), 8, 0.6, 0, 0.05, group="drums")
    s.put(I.crash(0), 0, 0.2, 0, 0.3, group="drums")
    s.put(I.crash(1, 3.5), 8, 0.26, 0, 0.35, group="drums")
    mot = [(9.0, 0.25, "A6"), (9.25, 0.25, "D7"), (9.5, 0.5, "E7"), (10.0, 2.0, "F#7")]
    s.notes(I.celesta, [(b, d, note(n), 0.9) for b, d, n in mot], 0.12, 0.2, rev=0.5, dly=0.3, group="cel")
    s.notes(I.musicbox, [(b + 0.02, d, note(n) - 12, 0.9) for b, d, n in mot], 0.08, -0.2, rev=0.5, group="cel")
    out = master(s, rev_cfg=dict(t60=2.4, damp=0.25, size=1.2, predelay=0.02),
                 dly_cfg=dict(delay=0.5 * s.spb, feedback=0.3, lp=4000, hp=400),
                 rev_gain=0.85, comp_cfg=dict(thresh_db=-16, ratio=2.0),
                 eq=[("high", 9000, 1.0)], width=1.2)
    return s, out


SONGS = {
    "title": song_title,
    "battle": song_battle,
    "select": song_select,
    "victory": song_victory,
}
