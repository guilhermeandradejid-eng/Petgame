"""Peças compartilhadas pelos personagens: esqueleto, rostos e utilidades de pose."""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from pixelrig.rig import Bone, Skeleton  # noqa: E402
from pixelrig.shapes import Decal  # noqa: E402

GROUND_FOOT = -4.0  # y do tornozelo com o pé no chão


def skeleton(extra=()):
    B = Bone
    bones = [
        B("root", None, (0, 0)),
        B("pelvis", "root", (0, -42)),
        B("spine", "pelvis", (0, -49)),
        B("chest", "spine", (0, -55)),
        B("neck", "chest", (0, -63)),
        B("head", "neck", (0, -66)),
        B("sh_b", "chest", (-3, -61)),
        B("el_b", "sh_b", (-3, -50)),
        B("hand_b", "el_b", (-3, -40)),
        B("sh_f", "chest", (2, -61)),
        B("el_f", "sh_f", (2, -50)),
        B("hand_f", "el_f", (2, -40)),
        B("hip_b", "pelvis", (-2.5, -41)),
        B("knee_b", "hip_b", (-2.5, -22)),
        B("foot_b", "knee_b", (-2.5, -4)),
        B("hip_f", "pelvis", (2, -41)),
        B("knee_f", "hip_f", (2, -22)),
        B("foot_f", "knee_f", (2, -4)),
    ] + list(extra)
    return Skeleton(bones)


def P(base, **kw):
    """Copia uma pose trocando valores. Use __ no lugar de '.': pelvis__t=(0,2)."""
    out = dict(base)
    for k, v in kw.items():
        k = k.replace("__", ".")
        if k == "ik" and isinstance(v, dict) and isinstance(out.get("ik"), dict):
            merged = dict(out["ik"])
            merged.update(v)
            out["ik"] = merged
        else:
            out[k] = v
    return out


def feet(fx, bx, fy=GROUND_FOOT, by=GROUND_FOOT, fa=0.0, ba=0.0):
    return {"foot_f": (fx, fy, fa, 1.0), "foot_b": (bx, by, ba, 1.0)}


# ---------------------------------------------------------------- rostos (decais)

def face_decals(eye_mat="eye", brow_mat="hair", angle_brow=0):
    """Olhos/boca em coordenadas locais da cabeça (junta em (0,-66)), virado para a direita.
    Chaves: k contorno do olho, E íris escura, I íris clara, w brilho, W esclera,
    m boca, M boca escura, t dente, b sobrancelha, r blush."""
    keys = {
        "k": (eye_mat, 0), "E": (eye_mat, 1), "e": (eye_mat, 2), "I": (eye_mat, 3),
        "w": ("white", 4), "W": ("white", 2),
        "m": ("mouth", 1), "M": ("mouth", 0), "t": ("white", 3), "r": ("mouth", 3),
        "b": (brow_mat, 0), "s": ("skin", 1),
    }
    D = []

    def add(rows, x, y, face):
        D.append(Decal(rows, x, y, keys, when=("face", face)))

    # olho de perto (x 1..5) e olho de longe (x 7..9), y -10..-5
    near_open = [
        ".kkkk",
        "kWwEk",
        "WeEEk",
        "WeIIk",
        ".kkk.",
    ]
    far_open = [
        "kkk",
        "Ewk",
        "EEk",
        "IIk",
        ".k.",
    ]
    near_det = [
        "kk...",
        ".kkkk",
        "kWwEk",
        "WeIIk",
        ".kkk.",
    ]
    far_det = [
        "..k",
        "kkk",
        "Ewk",
        "IIk",
        ".k.",
    ]
    near_closed = [
        ".....",
        ".....",
        "kkkkk",
        ".kkk.",
        ".....",
    ]
    far_closed = [
        "...",
        "...",
        "kkk",
        ".k.",
        "...",
    ]
    near_hurt = [
        "k....",
        ".kk..",
        "...kk",
        ".kk..",
        "k....",
    ]
    far_hurt = [
        "..k",
        ".k.",
        "k..",
        ".k.",
        "..k",
    ]
    near_happy = [
        ".....",
        ".kkk.",
        "k...k",
        ".....",
        ".....",
    ]
    far_happy = [
        "...",
        ".kk",
        "k..",
        "...",
        "...",
    ]
    sets = {
        "neutral": (near_open, far_open),
        "determined": (near_det, far_det),
        "shout": (near_det, far_det),
        "closed": (near_closed, far_closed),
        "hurt": (near_hurt, far_hurt),
        "happy": (near_happy, far_happy),
        "blink": (near_closed, far_closed),
    }
    for face, (n, f) in sets.items():
        add(n, 1, -10, face)
        add(f, 7, -10, face)
    # bocas
    mouths = {
        "neutral": (["mm"], 5, -3),
        "blink": (["mm"], 5, -3),
        "determined": (["mmm"], 4, -3),
        "closed": (["m"], 5, -3),
        "shout": (["MMm", "Mtm"], 4, -4),
        "hurt": (["MM", "Mm"], 5, -4),
        "happy": (["m.m", ".m."], 4, -4),
    }
    for face, (rows, x, y) in mouths.items():
        add(rows, x, y, face)
    # blush leve
    for face in ("neutral", "happy", "blink", "closed"):
        D.append(Decal(["r.r"], 1, -4, keys, when=("face", face)))
    return D
