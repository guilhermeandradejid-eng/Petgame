"""Animações da Lumia. Tempos em frames de jogo (60 fps). Ângulos em graus (+ = horário).

Guia rápido: braço para frente = ângulo negativo no ombro; inclinar o tronco para frente =
positivo em spine/chest; joelho é resolvido por IK a partir da posição do tornozelo.
"""
from __future__ import annotations

import math

from common import P, feet, GROUND_FOOT as G
from pixelrig.bake import Anim, Hit, Smear

REST = {"ik": feet(2, -2.5)}

STANCE = {
    "root": (0, 1.5),
    "spine": 3, "chest": 2, "neck": -1, "head": 3,
    "sh_f": -18, "el_f": -52, "hand_f": 18, "staff.w": 14,
    "sh_b": 14, "el_b": -24, "hand_b": 10,
    "ik": feet(8, -7, fa=0, ba=-6),
    "hand": "fist",
}

CROUCH = P(STANCE, root=(0, 13), pelvis=6, spine=10, chest=6, head=-4,
           sh_f=-34, el_f=-40, hand_f=10, staff__w=30,
           sh_b=-6, el_b=-30,
           ik=feet(9, -8, fa=0, ba=-10))

AIR = P(STANCE, root=(0, -2), spine=4, chest=0, head=0,
        sh_f=-30, el_f=-50, hand_f=20, staff__w=20, sh_b=30, el_b=-30,
        ik={"foot_f": (6, -14, 10, 1.0), "foot_b": (-5, -9, 20, 1.0)})

POSES = {"stance": STANCE, "crouch": CROUCH, "air": AIR}


def blink(base):
    return P(base, face="blink")


def anims():
    A = []
    st = STANCE

    # ------------------------------------------------------------ básicos
    A.append(Anim("idle", 72, [
        (0, P(st)),
        (18, P(st, root=(0, 2.4), chest=3, sh_f=-16, el_f=-54, sh_b=16, staff__w=14)),
        (36, P(st, root=(0, 2.8), chest=3.5, sh_f=-15, el_f=-55, sh_b=17, staff__w=13)),
        (40, P(st, root=(0, 2.8), chest=3.5, sh_f=-15, el_f=-55, sh_b=17, staff__w=13, face="blink")),
        (44, P(st, root=(0, 2.6), chest=3.2, sh_f=-15.5, el_f=-54.5, sh_b=16.5, staff__w=13.5)),
        (56, P(st, root=(0, 1.8), chest=2.5)),
    ], loop=True, step=4))

    def walk(name, forward=True):
        L = 44
        s = 1 if forward else -1
        sw = 7.0
        keys = []
        for i, t in enumerate((0, 11, 22, 33)):
            ph = i / 4.0
            ff = 1.5 + sw * math.cos(ph * 2 * math.pi) * s
            fb = -1.5 - sw * math.cos(ph * 2 * math.pi) * s
            lift_f = max(0.0, math.sin(ph * 2 * math.pi)) * 4.0
            lift_b = max(0.0, -math.sin(ph * 2 * math.pi)) * 4.0
            bob = 1.0 + 1.4 * abs(math.sin(ph * 2 * math.pi))
            keys.append((t, P(st, root=(0, 3.0 - bob), spine=5 if forward else 0, chest=1,
                             sh_b=14 + 10 * math.cos(ph * 2 * math.pi) * s, el_b=-22,
                             staff__w=14 + 4 * math.sin(ph * 2 * math.pi),
                             ik={"foot_f": (ff, G - lift_f, -8 * lift_f / 4, 1.0),
                                 "foot_b": (fb, G - lift_b, -8 * lift_b / 4, 1.0)},
                             ease="linear")))
        return Anim(name, L, keys, loop=True, step=4, wind=(-0.12 * s, 0))
    A.append(walk("walk_f", True))
    A.append(walk("walk_b", False))

    A.append(Anim("crouch", 8, [(0, P(st)), (6, P(CROUCH, ease="out"))], hold_last=True, step=2))
    A.append(Anim("stand_up", 6, [(0, P(CROUCH)), (6, P(st))], step=2))
    A.append(Anim("jump_squat", 4, [(0, P(st)), (3, P(CROUCH, root=(0, 7), ease="out"))], step=1))
    A.append(Anim("jump", 18, [
        (0, P(AIR, root=(0, -4), ik={"foot_f": (4, -6, 30, 1.0), "foot_b": (-4, -4, 30, 1.0)}, sh_b=40)),
        (8, P(AIR, ease="out")),
        (17, P(AIR, root=(0, -3))),
    ], loop=False, hold_last=True, step=3, wind=(0, 0.25)))
    A.append(Anim("fall", 24, [
        (0, P(AIR)),
        (12, P(AIR, root=(0, -1), sh_b=44, el_b=-50, sh_f=-40,
               ik={"foot_f": (5, -6, 18, 1.0), "foot_b": (-5, -3, 26, 1.0)})),
    ], loop=True, step=4, wind=(0, -0.3)))
    A.append(Anim("land", 10, [
        (0, P(CROUCH, root=(0, 9))),
        (10, P(st, ease="out")),
    ], step=2))

    A.append(Anim("dash_f", 18, [
        (0, P(st, root=(0, -2), pelvis=10, spine=14, chest=8, head=-10, sh_b=60, el_b=-10, sh_f=-30,
              el_f=-30, staff__w=60, ik={"foot_f": (4, -8, 30, 1.0), "foot_b": (-12, -12, 50, 1.0)})),
        (9, P(st, root=(0, -3), pelvis=10, spine=15, chest=8, head=-10, sh_b=64, el_b=-8, sh_f=-32,
              el_f=-28, staff__w=58, ik={"foot_f": (4, -9, 32, 1.0), "foot_b": (-12, -14, 54, 1.0)})),
    ], loop=True, step=3, wind=(-0.9, -0.05)))
    A.append(Anim("dash_b", 20, [
        (0, P(st, root=(0, -2), spine=-8, chest=-6, head=-6, sh_b=-20, sh_f=10, el_f=-70,
              ik={"foot_f": (8, -9, -10, 1.0), "foot_b": (-4, -10, -20, 1.0)})),
        (12, P(st, root=(0, -6), spine=-10, chest=-6, head=-4, sh_b=-30, sh_f=14, el_f=-74,
               ik={"foot_f": (9, -12, -20, 1.0), "foot_b": (-3, -12, -10, 1.0)})),
        (20, P(CROUCH, root=(0, 6))),
    ], step=3, wind=(0.7, 0)))
    fly = P(st, root=(0, -4), pelvis=24, spine=18, chest=8, head=-22, sh_b=70, el_b=-6, sh_f=-60, el_f=-20,
            staff__w=75, ik={"foot_f": (-6, -10, 60, 1.0), "foot_b": (-14, -7, 70, 1.0)})
    A.append(Anim("fly", 16, [(0, fly), (8, P(fly, root=(0, -5), sh_b=74))], loop=True, step=4,
                  wind=(-1.0, 0.0)))

    # ------------------------------------------------------------ defesa / dano
    guard = P(st, root=(0, 2.5), spine=-2, chest=-3, head=4, sh_f=-70, el_f=-48, hand_f=30, staff__w=-20,
              sh_b=-40, el_b=-70, face="determined")
    A.append(Anim("block", 10, [(0, P(st)), (3, P(guard, ease="snap")), (10, P(guard, root=(0, 3)))],
                  hold_last=True, step=2))
    cguard = P(CROUCH, sh_f=-70, el_f=-40, hand_f=30, staff__w=-24, sh_b=-40, el_b=-70, face="determined")
    A.append(Anim("block_low", 10, [(0, P(CROUCH)), (3, P(cguard, ease="snap"))], hold_last=True, step=2))
    aguard = P(AIR, sh_f=-70, el_f=-48, hand_f=30, staff__w=-20, sh_b=-40, el_b=-70, face="determined")
    A.append(Anim("block_air", 10, [(0, P(AIR)), (3, P(aguard, ease="snap"))], hold_last=True, step=2))

    hurt_hi = P(st, root=(-2, 2), spine=-14, chest=-10, neck=-6, head=-16, sh_f=20, el_f=-30, staff__w=40,
                sh_b=30, el_b=-10, face="hurt", hand="open")
    A.append(Anim("hit_hi", 20, [(0, P(hurt_hi, ease="out")), (6, P(hurt_hi, root=(-3, 2), spine=-16)),
                                 (20, P(st))], step=2, wind=(0.6, 0)))
    hurt_lo = P(st, root=(-2, 5), pelvis=-6, spine=22, chest=14, head=14, sh_f=10, el_f=-20, staff__w=50,
                sh_b=-10, face="hurt", ik=feet(6, -9))
    A.append(Anim("hit_lo", 20, [(0, P(hurt_lo, ease="out")), (6, P(hurt_lo, root=(-3, 6))), (20, P(st))],
                  step=2, wind=(0.6, 0)))
    tumble = P(AIR, pelvis=-30, spine=-20, chest=-10, head=-20, sh_f=40, el_f=-10, sh_b=60, face="hurt",
               hand="open", ik={"foot_f": (10, -12, 30, 1.0), "foot_b": (4, -8, 20, 1.0)})
    A.append(Anim("hit_air", 24, [(0, P(tumble)), (12, P(tumble, pelvis=-48, spine=-24)),
                                  (24, P(tumble, pelvis=-30))], loop=True, step=3, wind=(0.5, -0.3)))
    A.append(Anim("spin", 20, [(0, P(tumble, pelvis=0)), (5, P(tumble, pelvis=-90)), (10, P(tumble, pelvis=-180)),
                               (15, P(tumble, pelvis=-270)), (20, P(tumble, pelvis=-355))],
                  loop=True, step=2, wind=(0.4, -0.4)))
    lying = P(st, root=(-30, 37), pelvis=-90, spine=-4, chest=0, neck=-6, head=-10, sh_f=150, el_f=-10,
              hand_f=0, staff__w=-90, sh_b=170, el_b=-20, face="closed", hand="open",
              ik={"foot_f": (8, -3, -80, -1.0), "foot_b": (14, -2, -90, -1.0)})
    A.append(Anim("knockdown", 28, [
        (0, P(tumble, root=(0, -6), pelvis=-40, ease="in")),
        (10, P(lying, root=(-28, 33), pelvis=-84, ease="out")),
        (14, P(lying, root=(-30, 35), pelvis=-90, head=-16)),
        (20, P(lying)),
    ], hold_last=True, step=2))
    A.append(Anim("lying", 30, [(0, P(lying)), (15, P(lying, chest=1.5)), ], loop=True, step=6))
    A.append(Anim("wakeup", 24, [
        (0, P(lying)),
        (8, P(CROUCH, root=(-6, 16), pelvis=-30, spine=30, chest=10, sh_b=40, face="determined")),
        (16, P(CROUCH, face="determined")),
        (24, P(st)),
    ], step=2))
    dizzy = P(st, root=(0, 4), spine=-6, chest=-6, head=10, neck=8, sh_f=10, el_f=-20, staff__w=30, sh_b=20,
              face="hurt")
    A.append(Anim("crush", 40, [(0, P(dizzy)), (10, P(dizzy, root=(-2, 5), spine=4, head=-6)),
                                (20, P(dizzy, root=(1, 4), spine=-8, head=14)), (30, P(dizzy, root=(-1, 5), spine=2))],
                  loop=True, step=4))

    # ------------------------------------------------------------ golpes (A)
    # 5A: estocada rápida com o cajado
    a1_wind = P(st, root=(-1, 2), spine=-2, chest=-6, sh_f=10, el_f=-60, hand_f=40, staff__w=70, face="determined")
    a1_hit = P(st, root=(3, 1), spine=10, chest=8, head=-4, sh_f=-82, el_f=-8, hand_f=12, staff__w=90,
               sh_b=40, el_b=-20, face="shout", ik=feet(11, -7, ba=-12))
    A.append(Anim("a5_1", 20, [(0, P(a1_wind, ease="snap")), (4, P(a1_hit, ease="out")),
                               (9, P(a1_hit, root=(3, 1.5))), (20, P(st))],
                  hits=[Hit(4, 8, "staff", (0, -18), 7, rx=14)],
                  smears=[Smear(3, 7, "staff", (8, -36), width=3.5, trail=3)], step=2))
    # 5AA: varrida de baixo para cima
    a2_wind = P(st, root=(0, 3), spine=8, chest=4, sh_f=30, el_f=-20, hand_f=10, staff__w=160, face="determined")
    a2_hit = P(st, root=(2, 0), spine=-6, chest=-10, head=-8, sh_f=-150, el_f=-20, hand_f=10, staff__w=-10,
               sh_b=30, face="shout", ik=feet(10, -8))
    A.append(Anim("a5_2", 24, [(0, P(a2_wind, ease="snap")), (5, P(a2_hit, ease="out")), (11, P(a2_hit, root=(2, 0.5))),
                               (24, P(st))],
                  hits=[Hit(5, 10, "staff", (2, -26), 12)],
                  smears=[Smear(4, 9, "staff", (8, -36), width=4.5, trail=4)], step=2))
    # 5AAA: giro com a lanterna
    a3_mid = P(st, root=(0, 2), spine=4, chest=-4, sh_f=-90, el_f=-6, hand_f=0, staff__w=90, sh_b=60,
               face="shout", ik=feet(9, -9))
    a3_end = P(st, root=(3, 2), spine=12, chest=8, sh_f=-40, el_f=-20, hand_f=40, staff__w=150, sh_b=20,
               face="shout", ik=feet(12, -7))
    A.append(Anim("a5_3", 28, [(0, P(st, sh_f=40, el_f=-80, staff__w=-60, chest=-8, face="determined", ease="snap")),
                               (5, P(a3_mid, ease="linear")), (9, P(a3_end, ease="out")), (14, P(a3_end)),
                               (28, P(st))],
                  hits=[Hit(5, 11, "staff", (4, -30), 13)],
                  smears=[Smear(4, 10, "staff", (8, -36), width=5, trail=5)], step=2))
    # 5AAAA: lanterna em explosão (finalizador)
    a4_up = P(st, root=(-2, 0), spine=-12, chest=-12, head=-10, sh_f=-170, el_f=-10, hand_f=-10, staff__w=-20,
              sh_b=-120, el_b=-20, face="determined", ik=feet(7, -8))
    a4_hit = P(st, root=(6, 6), pelvis=6, spine=24, chest=14, head=6, sh_f=-70, el_f=-6, hand_f=20, staff__w=130,
               sh_b=40, el_b=-40, face="shout", ik=feet(16, -9, ba=-20))
    A.append(Anim("a5_4", 40, [(0, P(st)), (8, P(a4_up, ease="snap")), (13, P(a4_hit, ease="out")),
                               (24, P(a4_hit, root=(6, 6.5))), (40, P(st))],
                  hits=[Hit(13, 18, "staff", (6, -32), 15)], events=[(13, "burst")],
                  smears=[Smear(11, 17, "staff", (8, -36), width=6, trail=4)], step=2))
    # 2A: varrida baixa
    a2a = P(CROUCH, root=(4, 13), spine=18, sh_f=-70, el_f=-6, hand_f=0, staff__w=105, sh_b=50, face="shout",
            ik=feet(16, -8))
    A.append(Anim("a2", 24, [(0, P(CROUCH, sh_f=10, staff__w=70, ease="snap")), (5, P(a2a, ease="out")),
                             (12, P(a2a, root=(4, 13.5))), (24, P(CROUCH))],
                  hits=[Hit(5, 10, "staff", (2, -20), 8, rx=16)],
                  smears=[Smear(4, 9, "staff", (8, -36), width=3.5, trail=3, z=4)], step=2, hold_last=False))
    # 6A: grande arco com a lanterna
    a6_wind = P(st, root=(-4, 2), spine=-14, chest=-10, head=-6, sh_f=60, el_f=-40, hand_f=40, staff__w=-120,
                sh_b=-60, face="determined", ik=feet(5, -10))
    a6_hit = P(st, root=(8, 3), pelvis=4, spine=20, chest=12, head=4, sh_f=-110, el_f=-4, hand_f=10, staff__w=120,
               sh_b=60, face="shout", ik=feet(17, -8, ba=-16))
    A.append(Anim("a6", 36, [(0, P(st)), (9, P(a6_wind, ease="out")), (14, P(a6_hit, ease="out")),
                             (22, P(a6_hit, root=(8, 3.5))), (36, P(st))],
                  hits=[Hit(14, 19, "staff", (5, -30), 15)],
                  smears=[Smear(12, 18, "staff", (8, -36), width=6, trail=5)], step=2))
    # j5A: giro aéreo
    aj_hit = P(AIR, spine=10, chest=6, sh_f=-90, el_f=-4, staff__w=110, sh_b=50, face="shout")
    A.append(Anim("aj", 24, [(0, P(AIR, sh_f=30, el_f=-60, staff__w=-60, face="determined", ease="snap")),
                             (5, P(aj_hit, ease="out")), (11, P(aj_hit)), (24, P(AIR))],
                  hits=[Hit(5, 11, "staff", (5, -28), 13)],
                  smears=[Smear(4, 10, "staff", (8, -36), width=5, trail=4)], step=2))
    # j2A: lanterna para baixo
    aj2_hit = P(AIR, spine=30, chest=10, head=10, sh_f=-30, el_f=-10, hand_f=40, staff__w=170, sh_b=50,
                face="shout", ik={"foot_f": (2, -16, 20, 1.0), "foot_b": (-8, -12, 30, 1.0)})
    A.append(Anim("aj2", 26, [(0, P(AIR, sh_f=-150, el_f=-20, staff__w=-20, face="determined", ease="snap")),
                              (6, P(aj2_hit, ease="out")), (13, P(aj2_hit)), (26, P(AIR))],
                  hits=[Hit(6, 12, "staff", (3, -30), 12)],
                  smears=[Smear(5, 11, "staff", (8, -36), width=5, trail=4)], step=2))
    # dash A: estocada deslizando
    ad = P(st, root=(6, 4), pelvis=10, spine=18, chest=10, head=-6, sh_f=-86, el_f=-2, hand_f=6, staff__w=90,
           sh_b=70, el_b=-10, face="shout", ik=feet(18, -12, fa=0, ba=-30))
    A.append(Anim("ad", 28, [(0, P(st, root=(0, 3), spine=10, sh_f=0, el_f=-60, staff__w=60, ease="snap")),
                             (5, P(ad, ease="out")), (15, P(ad, root=(6, 4.5))), (28, P(st))],
                  hits=[Hit(5, 13, "staff", (0, -20), 8, rx=18)],
                  smears=[Smear(4, 8, "staff", (8, -36), width=4, trail=3)], step=2, wind=(-0.5, 0)))

    # ------------------------------------------------------------ tiros (B)
    shoot = P(st, root=(-1, 2), spine=-4, chest=-4, head=0, sh_f=-86, el_f=-10, hand_f=-4, staff__w=90,
              sh_b=-60, el_b=-60, face="determined", ik=feet(8, -9))
    A.append(Anim("b5", 26, [(0, P(st, ease="out")), (6, P(shoot, ease="snap")), (10, P(shoot, root=(-3, 2), chest=-8)),
                             (16, P(shoot)), (26, P(st))], events=[(8, "fire")], step=2))
    shoot_up = P(shoot, spine=-10, chest=-12, head=-10, sh_f=-128, el_f=-10, staff__w=45)
    A.append(Anim("b2", 26, [(0, P(st, ease="out")), (6, P(shoot_up, ease="snap")), (10, P(shoot_up, root=(-3, 2))),
                             (26, P(st))], events=[(8, "fire")], step=2))
    shoot_air = P(AIR, spine=12, chest=10, head=12, sh_f=-56, el_f=-8, hand_f=-4, staff__w=130, sh_b=-40, el_b=-60,
                  face="determined")
    A.append(Anim("bj", 26, [(0, P(AIR, ease="out")), (6, P(shoot_air, ease="snap")), (10, P(shoot_air, root=(-2, -3))),
                             (26, P(AIR))], events=[(8, "fire")], step=2))
    shoot_cr = P(CROUCH, sh_f=-90, el_f=-6, staff__w=90, face="determined")
    A.append(Anim("b2c", 24, [(0, P(CROUCH, ease="out")), (6, P(shoot_cr, ease="snap")), (24, P(CROUCH))],
                  events=[(8, "fire")], step=2))

    # ------------------------------------------------------------ habilidades (C)
    plant = P(st, root=(0, 3), spine=6, chest=2, sh_f=-122, el_f=-10, hand_f=10, staff__w=0, sh_b=-30,
              el_b=-60, hand_b=0, face="determined", hand="open")
    release = P(st, root=(2, 2), spine=10, chest=4, sh_f=-100, el_f=-6, hand_f=20, staff__w=90, sh_b=-90, el_b=-10,
                face="shout", ik=feet(10, -8))
    A.append(Anim("c5", 36, [(0, P(st)), (10, P(plant, ease="out")), (15, P(release, ease="snap")),
                             (24, P(release)), (36, P(st))], events=[(15, "skill")], step=2,
                  ))
    comet_w = P(st, root=(-4, 3), spine=-10, chest=-12, sh_f=40, el_f=-90, hand_f=30, staff__w=-90, sh_b=-50,
                face="determined", ik=feet(6, -10))
    comet_h = P(st, root=(5, 3), pelvis=6, spine=18, chest=10, head=-4, sh_f=-90, el_f=0, hand_f=0, staff__w=90,
                sh_b=60, el_b=-10, face="shout", ik=feet(16, -9, ba=-16))
    A.append(Anim("c6", 34, [(0, P(st)), (9, P(comet_w, ease="out")), (13, P(comet_h, ease="snap")),
                             (22, P(comet_h, root=(5, 3.5))), (34, P(st))], events=[(13, "skill")],
                  smears=[Smear(11, 15, "staff", (8, -36), width=4, trail=3)], step=2, wind=(-0.4, 0)))
    moth = P(st, root=(0, 1), spine=-12, chest=-10, head=-14, sh_f=-118, el_f=-6, hand_f=0, staff__w=8,
             sh_b=-140, el_b=-10, face="shout", hand="open", ik=feet(8, -7))
    A.append(Anim("c2", 34, [(0, P(CROUCH, ease="out")), (8, P(CROUCH, root=(0, 14))), (12, P(moth, ease="snap")),
                             (22, P(moth, root=(0, 0))), (34, P(st))], events=[(12, "skill")], step=2,
                  smears=[Smear(10, 14, "staff", (8, -36), width=4, trail=3)]))
    A.append(Anim("cj", 34, [(0, P(AIR)), (9, P(AIR, sh_f=40, el_f=-90, staff__w=-90, face="determined", ease="out")),
                             (13, P(shoot_air, ease="snap")), (34, P(AIR))], events=[(13, "skill")], step=2))

    # ------------------------------------------------------------ cartas
    declare = P(st, root=(0, 0), spine=-6, chest=-10, neck=-4, head=-8, sh_f=-112, el_f=-6, hand_f=0, staff__w=0,
                sh_b=-60, el_b=-90, hand_b=-20, face="shout", hand="open", ik=feet(9, -9))
    A.append(Anim("declare", 44, [(0, P(st, root=(0, 3), face="closed")), (10, P(st, root=(0, 4), chest=4, face="closed")),
                                  (18, P(declare, ease="back")), (44, P(declare, root=(0, -1)))],
                  step=2, wind=(0.0, -0.45)))
    cast = P(st, root=(-1, 2), spine=-6, chest=-8, head=-4, sh_f=-96, el_f=-6, staff__w=90, sh_b=-70, el_b=-60,
             face="shout", ik=feet(9, -9))
    A.append(Anim("cast", 24, [(0, P(cast)), (12, P(cast, root=(-2, 2.5), chest=-9))], loop=True, step=3,
                  wind=(-0.3, -0.25)))
    cast_up = P(declare, root=(0, 1), sh_b=-150, el_b=-10)
    A.append(Anim("cast_up", 24, [(0, P(cast_up)), (12, P(cast_up, root=(0, 0)))], loop=True, step=3,
                  wind=(0.0, -0.6)))

    # ------------------------------------------------------------ apresentação
    A.append(Anim("intro", 70, [
        (0, P(st, root=(0, 2), spine=8, chest=10, head=20, sh_f=-10, el_f=-30, staff__w=10, face="closed")),
        (24, P(st, root=(0, 2), spine=8, chest=10, head=20, sh_f=-10, el_f=-30, staff__w=10, face="closed")),
        (36, P(declare, ease="back", face="determined")),
        (52, P(declare, face="determined")),
        (70, P(st)),
    ], step=3, wind=(0, -0.2)))
    win = P(st, root=(0, 0), spine=-4, chest=-6, head=-10, sh_f=-30, el_f=-100, hand_f=40, staff__w=0,
            sh_b=-20, el_b=-120, hand_b=0, face="happy", hand="open", ik=feet(5, -5))
    A.append(Anim("win", 80, [(0, P(st)), (14, P(win, ease="back")), (40, P(win, root=(0, -1), head=-12)),
                              (60, P(win)), (80, P(win, root=(0, -1)))], loop=True, loop_start=14, step=4))
    A.append(Anim("portrait", 1, [(0, P(declare, root=(0, -1)))], step=1))
    return A
