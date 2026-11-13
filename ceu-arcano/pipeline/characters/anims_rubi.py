"""Animações da Rubi. Mesma convenção da Lumia (60 fps, + = horário, IK nos pés)."""
from __future__ import annotations

import math

from common import P, feet, GROUND_FOOT as G
from pixelrig.bake import Anim, Hit, Smear

REST = {"ik": feet(2, -2.5)}

STANCE = {
    "root": (0, 4),
    "pelvis": 2, "spine": 6, "chest": 4, "neck": -4, "head": 0,
    "sh_f": -58, "el_f": -96, "hand_f": -10,
    "sh_b": -30, "el_b": -118, "hand_b": -10,
    "ik": feet(11, -9, fa=0, ba=-8),
    "face": "determined",
}

CROUCH = P(STANCE, root=(0, 15), pelvis=8, spine=14, chest=6, head=-10,
           sh_f=-50, el_f=-100, sh_b=-30, el_b=-110, ik=feet(12, -10, ba=-12))

AIR = P(STANCE, root=(0, -2), pelvis=0, spine=6, chest=2,
        sh_f=-50, el_f=-90, sh_b=-10, el_b=-100,
        ik={"foot_f": (8, -16, 10, 1.0), "foot_b": (-4, -10, 26, 1.0)})

POSES = {"stance": STANCE, "crouch": CROUCH, "air": AIR}


def anims():
    A = []
    st = STANCE

    # ------------------------------------------------------------ básicos: pulinho de boxeadora
    A.append(Anim("idle", 48, [
        (0, P(st, ease="out")),
        (12, P(st, root=(0, 6), chest=6, sh_f=-56, el_f=-98, sh_b=-28, ease="in")),
        (24, P(st, ease="out")),
        (36, P(st, root=(0, 6), chest=6, sh_f=-56, el_f=-98, sh_b=-28, face="blink", ease="in")),
    ], loop=True, step=3))

    def walk(name, forward=True):
        L = 36
        s = 1 if forward else -1
        keys = []
        for i, t in enumerate((0, 9, 18, 27)):
            ph = i / 4.0
            c, sn = math.cos(ph * 2 * math.pi), math.sin(ph * 2 * math.pi)
            ff = 2.0 + 8.0 * c * s
            fb = -1.0 - 8.0 * c * s
            lf = max(0.0, sn) * 4.5
            lb = max(0.0, -sn) * 4.5
            keys.append((t, P(st, root=(0, 5.5 - 1.6 * abs(sn)), spine=9 if forward else 3,
                             sh_f=-58 + 6 * c * s, sh_b=-30 - 6 * c * s,
                             ik={"foot_f": (ff, G - lf, -10 * lf / 4.5, 1.0), "foot_b": (fb, G - lb, -10 * lb / 4.5, 1.0)},
                             ease="linear")))
        return Anim(name, L, keys, loop=True, step=3, wind=(-0.15 * s, 0))
    A.append(walk("walk_f", True))
    A.append(walk("walk_b", False))

    A.append(Anim("crouch", 8, [(0, P(st)), (6, P(CROUCH, ease="out"))], hold_last=True, step=2))
    A.append(Anim("stand_up", 6, [(0, P(CROUCH)), (6, P(st))], step=2))
    A.append(Anim("jump_squat", 4, [(0, P(st)), (3, P(CROUCH, root=(0, 10), ease="out"))], step=1))
    A.append(Anim("jump", 18, [
        (0, P(AIR, root=(0, -4), ik={"foot_f": (4, -6, 30, 1.0), "foot_b": (-4, -4, 30, 1.0)})),
        (8, P(AIR, ease="out")),
        (17, P(AIR, root=(0, -3), ik={"foot_f": (9, -18, 0, 1.0), "foot_b": (-3, -12, 20, 1.0)})),
    ], hold_last=True, step=3, wind=(0, 0.25)))
    A.append(Anim("fall", 24, [
        (0, P(AIR)),
        (12, P(AIR, root=(0, -1), sh_b=10, ik={"foot_f": (7, -10, 10, 1.0), "foot_b": (-5, -6, 20, 1.0)})),
    ], loop=True, step=4, wind=(0, -0.3)))
    A.append(Anim("land", 10, [(0, P(CROUCH, root=(0, 12))), (10, P(st, ease="out"))], step=2))

    run = P(st, root=(0, 6), pelvis=14, spine=16, chest=8, head=-12, sh_f=-20, el_f=-60, sh_b=50, el_b=-60)
    A.append(Anim("dash_f", 16, [
        (0, P(run, ik={"foot_f": (14, -6, -10, 1.0), "foot_b": (-12, -10, 40, 1.0)}, ease="linear")),
        (8, P(run, root=(0, 4), sh_f=30, sh_b=-30, ik={"foot_f": (-10, -10, 40, 1.0), "foot_b": (14, -6, -10, 1.0)},
              ease="linear")),
    ], loop=True, step=2, wind=(-1.0, -0.1)))
    A.append(Anim("dash_b", 20, [
        (0, P(st, root=(0, -2), spine=-8, chest=-6, head=-4, ik={"foot_f": (8, -9, -10, 1.0), "foot_b": (-4, -12, -20, 1.0)})),
        (12, P(st, root=(0, -6), spine=-10, chest=-6, ik={"foot_f": (9, -12, -20, 1.0), "foot_b": (-3, -12, -10, 1.0)})),
        (20, P(CROUCH, root=(0, 8))),
    ], step=3, wind=(0.7, 0)))
    fly = P(st, root=(0, -4), pelvis=30, spine=20, chest=8, head=-26, sh_f=-110, el_f=-10, sh_b=40, el_b=-20,
            ik={"foot_f": (-8, -10, 60, 1.0), "foot_b": (-16, -6, 70, 1.0)})
    A.append(Anim("fly", 16, [(0, fly), (8, P(fly, root=(0, -5), sh_b=46))], loop=True, step=4, wind=(-1.2, 0.0)))

    # ------------------------------------------------------------ defesa / dano
    guard = P(st, root=(-1, 5), spine=-4, chest=-4, head=8, sh_f=-80, el_f=-120, sh_b=-70, el_b=-130)
    A.append(Anim("block", 10, [(0, P(st)), (3, P(guard, ease="snap")), (10, P(guard, root=(-1, 5.5)))],
                  hold_last=True, step=2))
    cguard = P(CROUCH, sh_f=-80, el_f=-120, sh_b=-70, el_b=-130, head=4)
    A.append(Anim("block_low", 10, [(0, P(CROUCH)), (3, P(cguard, ease="snap"))], hold_last=True, step=2))
    aguard = P(AIR, sh_f=-80, el_f=-120, sh_b=-70, el_b=-130, head=6)
    A.append(Anim("block_air", 10, [(0, P(AIR)), (3, P(aguard, ease="snap"))], hold_last=True, step=2))

    hurt_hi = P(st, root=(-2, 4), spine=-16, chest=-12, neck=-6, head=-18, sh_f=10, el_f=-40, sh_b=20, el_b=-30,
                face="hurt", hand="open")
    A.append(Anim("hit_hi", 20, [(0, P(hurt_hi, ease="out")), (6, P(hurt_hi, root=(-3, 4), spine=-18)), (20, P(st))],
                  step=2, wind=(0.6, 0)))
    hurt_lo = P(st, root=(-2, 7), pelvis=-6, spine=24, chest=16, head=16, sh_f=10, el_f=-30, sh_b=-10, face="hurt",
                ik=feet(8, -10))
    A.append(Anim("hit_lo", 20, [(0, P(hurt_lo, ease="out")), (6, P(hurt_lo, root=(-3, 8))), (20, P(st))],
                  step=2, wind=(0.6, 0)))
    tumble = P(AIR, pelvis=-30, spine=-20, chest=-10, head=-20, sh_f=40, el_f=-10, sh_b=60, el_b=-10, face="hurt",
               hand="open", ik={"foot_f": (10, -12, 30, 1.0), "foot_b": (4, -8, 20, 1.0)})
    A.append(Anim("hit_air", 24, [(0, P(tumble)), (12, P(tumble, pelvis=-48, spine=-24)), (24, P(tumble, pelvis=-30))],
                  loop=True, step=3, wind=(0.5, -0.3)))
    A.append(Anim("spin", 20, [(0, P(tumble, pelvis=0)), (5, P(tumble, pelvis=-90)), (10, P(tumble, pelvis=-180)),
                               (15, P(tumble, pelvis=-270)), (20, P(tumble, pelvis=-355))], loop=True, step=2,
                  wind=(0.4, -0.4)))
    lying = P(st, root=(-14, 37), pelvis=-90, spine=-4, chest=0, neck=-6, head=-10, sh_f=150, el_f=-10, sh_b=170,
              el_b=-20, face="closed", hand="open", ik={"foot_f": (24, -3, -80, -1.0), "foot_b": (30, -2, -90, -1.0)})
    A.append(Anim("knockdown", 28, [
        (0, P(tumble, root=(0, -6), pelvis=-40, ease="in")),
        (10, P(lying, root=(-12, 33), pelvis=-84, ease="out")),
        (14, P(lying, root=(-14, 35), head=-16)),
        (20, P(lying)),
    ], hold_last=True, step=2))
    A.append(Anim("lying", 30, [(0, P(lying)), (15, P(lying, chest=1.5))], loop=True, step=6))
    A.append(Anim("wakeup", 24, [
        (0, P(lying)),
        (8, P(CROUCH, root=(-4, 18), pelvis=-30, spine=30, chest=10, sh_b=40)),
        (16, P(CROUCH)),
        (24, P(st)),
    ], step=2))
    dizzy = P(st, root=(0, 6), spine=-6, chest=-6, head=10, neck=8, sh_f=10, el_f=-20, sh_b=20, el_b=-10, face="hurt",
              hand="open")
    A.append(Anim("crush", 40, [(0, P(dizzy)), (10, P(dizzy, root=(-2, 7), spine=4, head=-6)),
                                (20, P(dizzy, root=(1, 6), spine=-8, head=14)), (30, P(dizzy, root=(-1, 7), spine=2))],
                  loop=True, step=4))

    # ------------------------------------------------------------ golpes
    jab = P(st, root=(3, 4), spine=10, chest=8, head=-2, sh_f=-90, el_f=-4, hand_f=0, sh_b=-40, el_b=-120,
            face="shout", ik=feet(13, -8))
    A.append(Anim("a5_1", 16, [(0, P(st, ease="snap")), (3, P(jab, ease="out")), (7, P(jab, root=(3, 4.5))), (16, P(st))],
                  hits=[Hit(3, 7, "hand_f", (1, 2), 6, rx=8)],
                  smears=[Smear(2, 6, "hand_f", (1, 2), width=3.2, trail=3)], step=1))
    cross = P(st, root=(5, 5), pelvis=6, spine=16, chest=14, head=-4, sh_f=10, el_f=-110, sh_b=-92, el_b=-2,
              hand_b=0, face="shout", ik=feet(15, -8, ba=-14), **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3,
                                                                    "z.hand_b": 10.4})
    A.append(Anim("a5_2", 20, [(0, P(st, ease="snap")), (4, P(cross, ease="out")), (9, P(cross, root=(5, 5.5))),
                               (20, P(st))],
                  hits=[Hit(4, 8, "hand_b", (1, 2), 7, rx=9)],
                  smears=[Smear(3, 7, "hand_b", (1, 2), width=3.6, trail=3, z=10.1)], step=2))
    kick_ch = P(st, root=(-2, 2), pelvis=-24, spine=-10, chest=-6, head=-2, sh_f=-30, el_f=-120, sh_b=-60, el_b=-100,
                face="shout", ik={"foot_f": (26, -44, -60, 1.0), "foot_b": (-6, G, -10, 1.0)})
    A.append(Anim("a5_3", 26, [(0, P(st, ik={"foot_f": (8, -16, 20, 1.0), "foot_b": (-6, G, 0, 1.0)}, ease="out")),
                               (5, P(kick_ch, ease="snap")), (11, P(kick_ch, root=(-2, 2.5))), (26, P(st))],
                  hits=[Hit(5, 11, "foot_f", (3, 2), 9)],
                  smears=[Smear(4, 9, "foot_f", (3, 2), width=4.5, trail=4)], step=2))
    upper_w = P(CROUCH, root=(2, 16), spine=20, chest=10, sh_b=40, el_b=-60, sh_f=-30, el_f=-100,
                **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3, "z.hand_b": 10.4})
    upper = P(st, root=(6, -4), pelvis=-10, spine=-14, chest=-14, head=-16, sh_b=-176, el_b=-6, sh_f=20, el_f=-60,
              face="shout", ik={"foot_f": (14, -8, 0, 1.0), "foot_b": (0, -14, 30, 1.0)},
              **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3, "z.hand_b": 12.5})
    A.append(Anim("a5_4", 38, [(0, P(st)), (7, P(upper_w, ease="out")), (12, P(upper, ease="snap")),
                               (24, P(upper, root=(6, -3))), (38, P(st))],
                  hits=[Hit(12, 18, "hand_b", (1, 1), 10)], events=[(12, "burst")],
                  smears=[Smear(10, 16, "hand_b", (1, 2), width=5.5, trail=4, z=12.4)], step=2))
    sweep = P(CROUCH, root=(0, 22), pelvis=-10, spine=26, chest=10, head=-10, sh_f=-20, el_f=-60, sh_b=20, el_b=-40,
              face="shout", ik={"foot_f": (28, G, -6, -1.0), "foot_b": (-6, -8, -20, 1.0)})
    A.append(Anim("a2", 24, [(0, P(CROUCH, ease="snap")), (5, P(sweep, ease="out")), (12, P(sweep, root=(0, 22.5))),
                             (24, P(CROUCH))],
                  hits=[Hit(5, 11, "foot_f", (0, 1), 6, rx=12)],
                  smears=[Smear(4, 9, "foot_f", (3, 2), width=3.6, trail=3, z=4.5)], step=2))
    palm_w = P(st, root=(-4, 5), spine=-6, chest=-10, sh_f=40, el_f=-120, sh_b=-20, el_b=-100, face="determined",
               ik=feet(8, -12))
    palm = P(st, root=(9, 6), pelvis=6, spine=18, chest=10, head=-2, sh_f=-88, el_f=-2, hand_f=-20, sh_b=40, el_b=-60,
             face="shout", hand="open", ik=feet(20, -9, ba=-16))
    A.append(Anim("a6", 34, [(0, P(st)), (8, P(palm_w, ease="out")), (13, P(palm, ease="snap")), (22, P(palm, root=(9, 6.5))),
                             (34, P(st))],
                  hits=[Hit(13, 18, "hand_f", (2, 2), 10, rx=12)], events=[(13, "burst")],
                  smears=[Smear(11, 16, "hand_f", (1, 2), width=5, trail=3)], step=2))
    jkick = P(AIR, pelvis=-30, spine=-8, sh_f=-30, el_f=-120, sh_b=-40, el_b=-100, face="shout",
              ik={"foot_f": (24, -22, -60, 1.0), "foot_b": (-6, -18, 30, 1.0)})
    A.append(Anim("aj", 22, [(0, P(AIR, ik={"foot_f": (6, -18, 30, 1.0), "foot_b": (-4, -10, 30, 1.0)}, ease="snap")),
                             (4, P(jkick, ease="out")), (11, P(jkick)), (22, P(AIR))],
                  hits=[Hit(4, 11, "foot_f", (3, 2), 8)],
                  smears=[Smear(3, 8, "foot_f", (3, 2), width=4, trail=3)], step=2))
    axe_w = P(AIR, pelvis=-40, spine=-10, ik={"foot_f": (14, -60, -40, 1.0), "foot_b": (-4, -12, 30, 1.0)}, face="determined")
    axe = P(AIR, pelvis=10, spine=16, chest=10, head=10, sh_f=-40, el_f=-100, sh_b=30, face="shout",
            ik={"foot_f": (14, 4, 30, 1.0), "foot_b": (-6, -14, 30, 1.0)})
    A.append(Anim("aj2", 26, [(0, P(AIR)), (5, P(axe_w, ease="out")), (9, P(axe, ease="snap")), (16, P(axe)), (26, P(AIR))],
                  hits=[Hit(9, 15, "foot_f", (3, 0), 9)],
                  smears=[Smear(8, 13, "foot_f", (3, 2), width=4.5, trail=3)], step=2))
    tackle = P(st, root=(8, 8), pelvis=16, spine=26, chest=14, head=-12, sh_f=-70, el_f=-100, sh_b=-40, el_b=-110,
               face="shout", ik=feet(18, -16, ba=-30))
    A.append(Anim("ad", 26, [(0, P(run, ease="snap")), (4, P(tackle, ease="out")), (14, P(tackle, root=(8, 8.5))),
                             (26, P(st))],
                  hits=[Hit(4, 13, "chest", (8, 0), 10, rx=11)], step=2, wind=(-0.6, 0)))

    # ------------------------------------------------------------ tiros
    zap = P(st, root=(0, 4), spine=4, chest=0, sh_f=-90, el_f=-6, hand_f=-30, sh_b=-40, el_b=-110, face="shout",
            hand="open", ik=feet(12, -9))
    A.append(Anim("b5", 22, [(0, P(st, ease="out")), (5, P(zap, ease="snap")), (9, P(zap, root=(-2, 4))), (22, P(st))],
                  events=[(6, "fire")], step=2))
    zap_up = P(zap, spine=-8, chest=-10, head=-10, sh_f=-135, el_f=-6)
    A.append(Anim("b2", 22, [(0, P(st, ease="out")), (5, P(zap_up, ease="snap")), (9, P(zap_up, root=(-2, 4))), (22, P(st))],
                  events=[(6, "fire")], step=2))
    zap_air = P(AIR, spine=14, chest=10, head=10, sh_f=-50, el_f=-6, hand_f=-30, face="shout", hand="open")
    A.append(Anim("bj", 22, [(0, P(AIR, ease="out")), (5, P(zap_air, ease="snap")), (22, P(AIR))], events=[(6, "fire")],
                  step=2))
    zap_cr = P(CROUCH, sh_f=-90, el_f=-6, hand_f=-30, face="shout", hand="open")
    A.append(Anim("b2c", 22, [(0, P(CROUCH, ease="out")), (5, P(zap_cr, ease="snap")), (22, P(CROUCH))],
                  events=[(6, "fire")], step=2))

    # ------------------------------------------------------------ habilidades
    charge = P(st, root=(-3, 6), spine=-4, chest=-8, sh_f=-20, el_f=-110, sh_b=10, el_b=-120, hand="open",
               face="determined", ik=feet(9, -11))
    push = P(st, root=(5, 5), spine=12, chest=8, sh_f=-90, el_f=-4, hand_f=-30, sh_b=-84, el_b=-8, hand_b=-30,
             hand="open", face="shout", ik=feet(15, -9), **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3, "z.hand_b": 10.4})
    A.append(Anim("c5", 36, [(0, P(st)), (10, P(charge, ease="out")), (15, P(push, ease="snap")), (24, P(push)), (36, P(st))],
                  events=[(15, "skill")], step=2))
    elbow = P(st, root=(8, 6), pelvis=10, spine=20, chest=16, head=-8, sh_f=-110, el_f=-150, sh_b=40, el_b=-60,
              face="shout", ik=feet(18, -12, ba=-20))
    A.append(Anim("c6", 34, [(0, P(st)), (7, P(charge, ease="out")), (10, P(elbow, ease="snap")), (24, P(elbow, root=(8, 6.5))),
                             (34, P(st))],
                  hits=[Hit(10, 22, "el_f", (0, 0), 10, rx=12)], events=[(10, "skill")], step=2, wind=(-0.8, 0)))
    rise = P(st, root=(4, -10), pelvis=-6, spine=-12, chest=-10, head=-14, sh_f=-158, el_f=-8, hand_f=0, sh_b=20,
             el_b=-90, face="shout", ik={"foot_f": (10, -22, 20, 1.0), "foot_b": (-2, -12, 40, 1.0)},
             **{"z.arm_f_up": 12.2, "z.forearm_f": 12.3, "z.hand_f": 12.4})
    A.append(Anim("c2", 36, [(0, P(CROUCH, ease="snap")), (4, P(CROUCH, root=(0, 18))), (8, P(rise, ease="out")),
                             (20, P(rise, root=(4, -12))), (36, P(AIR))],
                  hits=[Hit(6, 18, "hand_f", (0, 0), 10)], events=[(6, "skill")],
                  smears=[Smear(6, 16, "hand_f", (0, 2), width=5, trail=5)], step=2, wind=(0, 0.6)))
    dive = P(AIR, pelvis=-40, spine=10, chest=6, head=20, sh_f=-30, el_f=-120, sh_b=-60, el_b=-100, face="shout",
             ik={"foot_f": (22, 10, 40, 1.0), "foot_b": (-4, -12, 30, 1.0)})
    A.append(Anim("cj", 34, [(0, P(AIR)), (8, P(axe_w, ease="out")), (11, P(dive, ease="snap")), (34, P(dive))],
                  hits=[Hit(11, 34, "foot_f", (2, 1), 9)], events=[(11, "skill")], step=2, wind=(-0.6, -0.6)))

    # ------------------------------------------------------------ cartas
    declare = P(st, root=(0, 2), spine=-8, chest=-12, neck=-4, head=-12, sh_f=-100, el_f=-62, sh_b=-150, el_b=-40,
                hand="fist", face="shout", ik=feet(12, -12), **{"z.forearm_f": 12.3, "z.hand_f": 12.4})
    A.append(Anim("declare", 44, [(0, P(st, root=(0, 6), face="closed")), (10, P(st, root=(0, 7), chest=8, face="closed",
                                                                              sh_f=-20, el_f=-130, sh_b=-10, el_b=-130)),
                                  (18, P(declare, ease="back")), (44, P(declare, root=(0, 1)))],
                  step=2, wind=(0.0, -0.5)))
    rush_a = P(st, root=(4, 5), spine=12, chest=8, sh_f=-90, el_f=-4, sh_b=-30, el_b=-120, face="shout",
               ik=feet(14, -9))
    rush_b = P(st, root=(4, 5), spine=14, chest=12, sh_f=-20, el_f=-120, sh_b=-90, el_b=-2, face="shout",
               ik=feet(14, -9), **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3, "z.hand_b": 10.4})
    A.append(Anim("cast", 12, [(0, P(rush_a, ease="out")), (6, P(rush_b, ease="out"))], loop=True, step=1,
                  hits=[Hit(0, 12, "chest", (14, 0), 12, rx=14)],
                  smears=[Smear(0, 5, "hand_f", (1, 2), width=3.4, trail=2), Smear(6, 11, "hand_b", (1, 2), width=3.4, trail=2)],
                  wind=(-0.6, -0.2)))
    call = P(st, root=(0, 2), spine=-10, chest=-12, head=-18, sh_f=-150, el_f=-14, hand="open", sh_b=20, el_b=-40,
             face="shout", ik=feet(12, -10), **{"z.arm_f_up": 12.2, "z.forearm_f": 12.3, "z.hand_f": 12.4})
    A.append(Anim("cast_up", 24, [(0, P(call)), (12, P(call, root=(0, 1)))], loop=True, step=3, wind=(0.0, -0.6)))

    # ------------------------------------------------------------ apresentação
    A.append(Anim("intro", 70, [
        (0, P(st, root=(0, 3), spine=0, chest=0, sh_f=-70, el_f=-80, sh_b=-60, el_b=-90, hand_f=0, face="closed",
              **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3, "z.hand_b": 10.4})),
        (16, P(st, root=(0, 3), spine=0, chest=0, sh_f=-70, el_f=-80, sh_b=-60, el_b=-90, face="closed",
               **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3, "z.hand_b": 10.4})),
        (22, P(st, root=(0, 3), spine=2, chest=2, sh_f=-72, el_f=-84, sh_b=-62, el_b=-86, face="determined",
               **{"z.arm_b_up": 10.2, "z.forearm_b": 10.3, "z.hand_b": 10.4})),
        (40, P(declare, ease="back")),
        (56, P(declare)),
        (70, P(st)),
    ], step=3, wind=(0, -0.2)))
    win = P(st, root=(0, 0), spine=-6, chest=-8, head=-12, sh_f=-100, el_f=-62, sh_b=10, el_b=-100, hand_b=0,
            face="happy", ik=feet(8, -7), **{"z.forearm_f": 12.3, "z.hand_f": 12.4})
    A.append(Anim("win", 80, [(0, P(st)), (14, P(win, ease="back")), (40, P(win, root=(0, -1), sh_f=-106, el_f=-58)),
                              (60, P(win)), (80, P(win, root=(0, -1)))], loop=True, loop_start=14, step=4,
                  wind=(-0.3, -0.1)))
    A.append(Anim("portrait", 1, [(0, P(declare, root=(0, 0)))], step=1))
    return A
