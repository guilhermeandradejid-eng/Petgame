"""Objective checks for the generated audio (we cannot listen, so we measure).

SFX:   format, finite, no clipping, peak = -1 dBFS, no leading silence,
       trimmed tail, click-free end, DC, duration window.
Music: format (Vorbis, 44.1 kHz, stereo), decoded peak/true peak < -1 dBFS,
       integrated loudness (own BS.1770 + ffmpeg ebur128), duration window,
       loop seam continuity (decoded file wrapped end->start).
"""
from __future__ import annotations

import json
import os
import re
import subprocess

import numpy as np

import synth as S

SFX_DUR = {
    "ui_move": (0.04, 0.2), "ui_confirm": (0.2, 0.9), "ui_back": (0.04, 0.25), "ui_error": (0.1, 0.5),
    "jump": (0.15, 0.45), "land": (0.12, 0.45), "dash": (0.15, 0.45), "step": (0.02, 0.12),
    "flight": (0.3, 0.6), "swing_light": (0.08, 0.3), "swing_heavy": (0.2, 0.5), "hit_light": (0.08, 0.3),
    "hit_medium": (0.15, 0.5), "hit_heavy": (0.3, 0.9), "hit_counter": (0.5, 1.4), "block": (0.2, 0.6),
    "guard_crush": (0.6, 1.6), "shot_firefly": (0.04, 0.2), "shot_star": (0.15, 0.6), "comet": (0.45, 0.9),
    "moth": (0.25, 0.7), "lantern_place": (0.5, 1.8), "beam": (2.2, 3.0), "spark_shot": (0.08, 0.3),
    "electric_orb": (0.65, 1.0), "thunder_crack": (1.2, 2.2), "uppercut": (0.25, 0.6), "explosion": (0.8, 2.0),
    "bullet_cancel": (0.02, 0.12), "graze": (0.02, 0.1), "card_gain": (0.3, 0.9), "card_select": (0.02, 0.1),
    "spell_declare": (1.3, 2.3), "super_flash": (0.3, 0.9), "heal": (0.5, 1.4), "spirit_refill": (0.3, 0.9),
    "weather_change": (1.3, 2.3), "round_announce": (1.3, 2.3), "fight_start": (0.4, 1.2), "ko": (2.2, 3.4),
    "timer_tick": (0.02, 0.12), "combo_break": (0.2, 0.7), "slowmo": (0.8, 1.3),
}
MUSIC_DUR = {"title": (60, 75), "battle": (80, 100), "victory": (6, 9), "select": (40, 60)}


def _probe(path):
    return subprocess.run(["ffmpeg", "-hide_banner", "-i", path], capture_output=True, text=True).stderr


def _ebur128(path):
    err = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-filter_complex",
                          "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    summ = err[err.rfind("Summary:"):]
    i = re.search(r"I:\s+(-?[\d.]+) LUFS", summ)
    p = re.search(r"Peak:\s+(-?[\d.]+) dBFS", summ)
    return (float(i.group(1)) if i else float("nan")), (float(p.group(1)) if p else float("nan"))


def check_sfx(path, name):
    errs, warns = [], []
    x, sr = S.read_wav(path)
    with open(path, "rb") as f:
        hdr = f.read(44)
    if sr != 44100:
        errs.append(f"sr {sr}")
    if x.ndim != 1:
        errs.append("not mono")
    if int.from_bytes(hdr[34:36], "little") != 16:
        errs.append("not 16-bit")
    n = len(x)
    dur = n / sr
    pk = float(np.abs(x).max())
    pk_db = float(S.to_db(pk))
    if abs(pk_db + 1.0) > 0.15:
        errs.append(f"peak {pk_db:.2f} dBFS")
    if np.sum(np.abs(x) >= 32767 / 32768) > 0:
        errs.append("clipping")
    lead = int(np.argmax(np.abs(x) > pk * S.db(-50)))
    if lead > S.ns(0.003):
        errs.append(f"leading silence {lead / sr * 1000:.1f} ms")
    above = np.nonzero(np.abs(x) > pk * S.db(-60))[0]
    trail = (n - 1 - above[-1]) / sr if len(above) else dur
    if trail > 0.03:
        errs.append(f"untrimmed tail {trail * 1000:.0f} ms")
    if abs(x[-1]) > 2e-3 or abs(x[0]) > 0.05:
        errs.append(f"edge sample start {x[0]:.4f} end {x[-1]:.4f}")
    if abs(float(np.mean(x))) > 2e-3:
        warns.append(f"DC {np.mean(x):.4f}")
    lo, hi = SFX_DUR.get(name, (0, 99))
    if not lo <= dur <= hi:
        errs.append(f"duration {dur:.3f}s not in [{lo}, {hi}]")
    rms_db = float(S.to_db(np.sqrt(np.mean(x ** 2))))
    return dict(name=name, dur=dur, peak=pk_db, rms=rms_db, errs=errs, warns=warns)


def check_music(path, name, meta):
    errs, warns = [], []
    pr = _probe(path)
    if "Audio: vorbis" not in pr:
        errs.append("not vorbis")
    if "44100 Hz" not in pr:
        errs.append("not 44.1 kHz")
    if "stereo" not in pr:
        errs.append("not stereo")
    x = S.decode_audio(path)
    if x.ndim != 2:
        errs.append("decoded not stereo")
        x = np.stack([x, x], axis=1)
    if not np.all(np.isfinite(x)):
        errs.append("non-finite")
    n = len(x)
    dur = n / S.SR
    lo, hi = MUSIC_DUR.get(name, (0, 999))
    if not lo <= dur <= hi:
        errs.append(f"duration {dur:.2f}s not in [{lo}, {hi}]")
    if meta and meta.get("samples") and abs(n - meta["samples"]) > 0:
        (errs if abs(n - meta["samples"]) > 64 else warns).append(
            f"decoded length {n} != rendered {meta['samples']}")
    pk = float(S.to_db(np.abs(x).max()))
    tp = S.true_peak_db(x)
    if pk >= -1.0:
        errs.append(f"decoded sample peak {pk:.2f} dBFS")
    if tp >= -1.0:
        warns.append(f"true peak {tp:.2f} dBTP")
    lv = S.lufs(x)
    ff_i, ff_tp = _ebur128(path)
    if name != "victory" and abs(ff_i + 14.0) > 1.0:
        warns.append(f"loudness {ff_i:.1f} LUFS")
    seam = {}
    if meta and meta.get("loop"):
        dd = np.abs(np.diff(x, axis=0)).max(axis=1)
        p999 = float(np.percentile(dd, 99.9))
        jump = float(np.abs(x[0] - x[-1]).max())
        w = S.ns(0.02)
        r_end = float(S.to_db(np.sqrt(np.mean(x[-w:] ** 2))))
        r_start = float(S.to_db(np.sqrt(np.mean(x[:w] ** 2))))
        # second-difference energy across the seam vs. typical windows in the file
        k = 64
        wrap = np.concatenate([x[-k:], x[:k]], axis=0)
        d2 = lambda z: float(np.sqrt(np.mean(np.diff(z, 2, axis=0) ** 2)))
        seam_hf = d2(wrap)
        rng = np.random.default_rng(0)
        typ = [d2(x[i:i + 2 * k]) for i in rng.integers(0, n - 2 * k, 400)]
        ratio = seam_hf / (np.percentile(typ, 95) + 1e-12)
        seam = dict(jump=jump, p999=p999, rms_end=r_end, rms_start=r_start, hf_ratio=float(ratio))
        if jump > max(p999, 0.02):
            errs.append(f"seam jump {jump:.4f} > p99.9 step {p999:.4f}")
        if ratio > 2.0:
            errs.append(f"seam HF energy {ratio:.2f}x the 95th pct window")
    return dict(name=name, dur=dur, peak=pk, tp=tp, lufs=lv, ff_lufs=ff_i, ff_tp=ff_tp, seam=seam,
                errs=errs, warns=warns)


def run(sfx_dir, mus_dir) -> int:
    bad = 0
    print("\n== SFX QA ==")
    expected = set(SFX_DUR)
    present = {f[:-4] for f in os.listdir(sfx_dir) if f.endswith(".wav")}
    for missing in sorted(expected - present):
        print(f"  MISSING {missing}.wav")
        bad += 1
    for name in sorted(present):
        r = check_sfx(os.path.join(sfx_dir, name + ".wav"), name)
        flag = "FAIL" if r["errs"] else "ok  "
        bad += bool(r["errs"])
        print(f"  {flag} {name:15s} {r['dur']:6.3f}s  peak {r['peak']:6.2f}  rms {r['rms']:6.1f}"
              + ("  " + "; ".join(r["errs"] + r["warns"]) if r["errs"] or r["warns"] else ""))
    print("\n== MUSIC QA ==")
    lp = os.path.join(mus_dir, "loops.json")
    loops = json.load(open(lp)) if os.path.exists(lp) else {}
    if not loops:
        print("  MISSING loops.json")
        bad += 1
    for name in ("title", "select", "battle", "victory"):
        path = os.path.join(mus_dir, name + ".ogg")
        if not os.path.exists(path):
            print(f"  MISSING {name}.ogg")
            bad += 1
            continue
        r = check_music(path, name, loops.get(name + ".ogg"))
        bad += bool(r["errs"])
        flag = "FAIL" if r["errs"] else "ok  "
        sm = r["seam"]
        seam = (f"  seam: jump {sm['jump']:.4f} (p99.9 step {sm['p999']:.4f}), rms end/start "
                f"{sm['rms_end']:.1f}/{sm['rms_start']:.1f} dB, HF x{sm['hf_ratio']:.2f}") if sm else ""
        print(f"  {flag} {name:8s} {r['dur']:7.2f}s  {r['lufs']:6.2f} LUFS (ffmpeg {r['ff_lufs']:.1f})  "
              f"peak {r['peak']:6.2f} dBFS  TP {r['tp']:6.2f} (ffmpeg {r['ff_tp']:.1f})" + seam
              + ("\n       " + "; ".join(r["errs"] + r["warns"]) if r["errs"] or r["warns"] else ""))
    total = 0
    for d in (sfx_dir, mus_dir):
        for f in os.listdir(d):
            total += os.path.getsize(os.path.join(d, f))
    print(f"\n  total audio size {total / 1e6:.2f} MB" + ("  (OVER 25 MB)" if total > 25e6 else ""))
    bad += total > 25e6
    print("QA:", "PASS" if bad == 0 else f"{bad} problem(s)")
    return 0 if bad == 0 else 1
