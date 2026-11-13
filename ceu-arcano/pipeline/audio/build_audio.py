#!/usr/bin/env python3
"""Regenerate every Céu Arcano audio asset deterministically (numpy + ffmpeg).

    python3 ceu-arcano/pipeline/audio/build_audio.py            # build all + QA
    python3 ceu-arcano/pipeline/audio/build_audio.py --only sfx  # just SFX
    python3 ceu-arcano/pipeline/audio/build_audio.py --only battle,title
    python3 ceu-arcano/pipeline/audio/build_audio.py --qa        # QA existing files only

Outputs:
    game/assets/audio/sfx/<name>.wav     PCM16 mono 44.1 kHz, peak -1 dBFS
    game/assets/audio/sfx/sfx.json       durations + suggested mixer trims
    game/assets/audio/music/<name>.ogg   Vorbis q6 stereo 44.1 kHz
    game/assets/audio/music/loops.json   loop flags + tempo metadata
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import time
from concurrent.futures import ProcessPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True  # keep the pipeline folder free of __pycache__

import synth as S  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_SFX = os.path.join(ROOT, "game", "assets", "audio", "sfx")
OUT_MUS = os.path.join(ROOT, "game", "assets", "audio", "music")


def _build_sfx_batch(names):
    import numpy as np
    import sfx
    res = []
    for name in names:
        x = sfx.render(name)
        S.write_wav(os.path.join(OUT_SFX, name + ".wav"), x)
        res.append((name, len(x) / S.SR, float(S.to_db(np.abs(x).max()))))
    return res


def _build_song(name):
    import numpy as np
    import music
    t0 = time.time()
    song, out = music.SONGS[name]()
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, name + ".wav")
        S.write_wav(wav, out)
        S.encode_ogg(wav, os.path.join(OUT_MUS, name + ".ogg"))
    meta = {
        "loop": bool(song.loop),
        "bpm": song.bpm,
        "beats_per_bar": song.bpb,
        "bars": song.bars,
        "samples": int(len(out)),
        "duration_sec": round(len(out) / S.SR, 4),
    }
    if song.loop:
        meta["loop_start_sec"] = 0.0
        meta["loop_end_sec"] = round(song.L / S.SR, 4)
    return name, meta, time.time() - t0, float(S.lufs(out)), float(S.to_db(np.abs(out).max()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="comma list: sfx, title, battle, select, victory")
    ap.add_argument("--qa", action="store_true", help="only run QA on existing outputs")
    ap.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    args = ap.parse_args()

    import music
    import sfx
    import qa

    S.ensure_dir(OUT_SFX)
    S.ensure_dir(OUT_MUS)
    if args.qa:
        sys.exit(qa.run(OUT_SFX, OUT_MUS))

    only = {s.strip() for s in args.only.split(",") if s.strip()}
    songs = [n for n in ("battle", "title", "select", "victory") if not only or n in only]
    do_sfx = not only or "sfx" in only
    t0 = time.time()

    names = list(sfx.SFX)
    batches = [names[i::max(1, args.jobs)] for i in range(max(1, args.jobs))] if do_sfx else []
    loops_path = os.path.join(OUT_MUS, "loops.json")
    loops = {}
    if os.path.exists(loops_path):
        with open(loops_path) as f:
            loops = json.load(f)

    with ProcessPoolExecutor(max_workers=args.jobs) as ex:
        song_futs = [ex.submit(_build_song, n) for n in songs]
        sfx_futs = [ex.submit(_build_sfx_batch, b) for b in batches if b]
        sfx_res = []
        for f in sfx_futs:
            sfx_res.extend(f.result())
        for f in song_futs:
            name, meta, dt, lv, pk = f.result()
            loops[name + ".ogg"] = meta
            print(f"[music] {name:8s} {meta['duration_sec']:7.2f}s  loop={meta['loop']!s:5s}  "
                  f"{lv:6.2f} LUFS  peak {pk:6.2f} dBFS  ({dt:.1f}s)")

    if sfx_res:
        sfx_res.sort()
        meta = {n: {"file": n + ".wav", "duration_sec": round(d, 4),
                    "suggested_volume_db": sfx.VOLUME_HINT_DB.get(n, 0.0)} for n, d, _ in sfx_res}
        with open(os.path.join(OUT_SFX, "sfx.json"), "w") as f:
            json.dump(meta, f, indent=2, sort_keys=True)
        print(f"[sfx] {len(sfx_res)} files")
    if songs:
        order = ["title.ogg", "select.ogg", "battle.ogg", "victory.ogg"]
        loops = {k: loops[k] for k in sorted(loops, key=lambda k: order.index(k) if k in order else 99)}
        with open(loops_path, "w") as f:
            json.dump(loops, f, indent=2)
    print(f"build time {time.time() - t0:.1f}s")
    sys.exit(qa.run(OUT_SFX, OUT_MUS))


if __name__ == "__main__":
    main()
