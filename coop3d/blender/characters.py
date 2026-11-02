"""Builds the two playable characters and exports them as .glb.

Lumi   - a fox/firefly spirit: big ears, glowing antennae and a lantern tail.
Bolota - a little acorn knight: acorn head with a sprout, leaf cape, mittens.

The hierarchy is made of pivot empties placed at the joints (Hips, Head,
ArmL, EarL, Tail1, Cape...). Godot's `character_rig.gd` animates those pivots
procedurally (squash & stretch, overlapping action, follow-through), so the
names below are part of the contract with the game code.

Blender is Z-up and the characters face -Y, which glTF/Godot read as +Z.
"""
import math
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401  (loads mathutils)
from mathutils import Vector  # noqa: E402

import bl_common as C  # noqa: E402


# ======================================================================= LUMI
def build_lumi():
    C.reset_scene()
    fur = C.mat("M_Fur_Lumi", "#FF8A4C", 0.55)
    fur_dark = C.mat("M_Fur_LumiTip", "#E2553A", 0.6)
    cream = C.mat("M_Cream", "#FFEBCB", 0.6)
    pink = C.mat("M_Pink", "#FF9AB0", 0.6)
    blush = C.mat("M_Blush", "#FF6F91", 0.7)
    scarf = C.mat("M_Cloth_Scarf", "#2EC4B6", 0.75)
    scarf_dark = C.mat("M_Cloth_ScarfDark", "#1A8C8A", 0.75)
    eye = C.mat("M_Eye", "#1B1530", 0.15)
    shine = C.mat("M_EyeShine", "#FFFFFF", 0.1)
    nose = C.mat("M_Nose", "#3A2233", 0.3)
    glow = C.mat("M_Glow_Lantern", "#FFE66D", 0.3, emission="#FFD23F")
    lantern_cap = C.mat("M_Metal_Brass", "#C9A227", 0.35, metallic=0.6)

    root = C.empty("Lumi")

    # ---- legs (children of root so they stay planted while the body bobs)
    for side, nm in ((1, "L"), (-1, "R")):
        leg = C.empty("Leg" + nm, (0.1 * side, 0, 0.21), root)
        C.link_mesh("LegMesh" + nm, C.tube([(0, 0, 0.02), (0, 0, -0.13)], [0.06, 0.05]), fur, leg)
        C.link_mesh("Foot" + nm, C.blob((0.075, 0.1, 0.055), deform=lambda q, n: q + Vector((0, 0, -0.02 * max(0, -n.z)))),
                    cream, leg, loc=(0, -0.035, -0.165))

    hips = C.empty("Hips", (0, 0, 0.22), root)

    def body_deform(q, n):
        # pear shape: wider at the bottom, slight forward belly
        k = 1.0 + 0.16 * max(0.0, -n.z) - 0.1 * max(0.0, n.z)
        q = Vector((q.x * k, q.y * k, q.z))
        if n.y < 0:
            q.y -= 0.03 * (-n.y) * (1 - abs(n.z))
        return q

    C.link_mesh("Body", C.blob((0.24, 0.22, 0.25), deform=body_deform), fur, hips, loc=(0, 0, 0.16))
    C.link_mesh("Belly", C.blob((0.15, 0.06, 0.16)), cream, hips, loc=(0, -0.19, 0.13), rot=(math.radians(-6), 0, 0))

    # ---- scarf: a ring plus a fluttering tail (pivot for follow-through)
    C.link_mesh("ScarfRing", C.torus(0.17, 0.06, 32, 10, 0.8), scarf, hips, loc=(0, 0, 0.36), rot=(math.radians(-8), 0, 0))
    scarf_tail = C.empty("ScarfTail", (0.08, 0.15, 0.35), hips)

    def flap(q, n):
        # flattened ribbon that widens to the end and curls back
        t = (q.z + 0.16) / 0.32
        q.x *= 0.6 + 0.6 * (1 - t)
        q.y += 0.06 * (1 - t) ** 2
        return q

    C.link_mesh("ScarfFlap", C.blob((0.07, 0.025, 0.16), deform=flap), scarf_dark, scarf_tail,
                loc=(0, 0.03, -0.12), rot=(math.radians(25), 0, math.radians(-10)))

    # ---- head
    head = C.empty("Head", (0, 0, 0.38), hips)

    def head_deform(q, n):
        # chubby cheeks low, slightly flatter face
        cheek = C.smoothstep(0.2, -0.6, n.z) * (1 - abs(n.y))
        q.x *= 1.0 + 0.1 * cheek
        if n.y < -0.3:
            q.y *= 0.95
        return q

    C.link_mesh("HeadMesh", C.blob((0.33, 0.29, 0.28), 32, 20, head_deform), fur, head, loc=(0, 0, 0.26))
    C.link_mesh("Muzzle", C.blob((0.13, 0.08, 0.08)), cream, head, loc=(0, -0.235, 0.17))
    C.link_mesh("Nose", C.blob((0.04, 0.028, 0.028)), nose, head, loc=(0, -0.315, 0.205))
    for side, nm in ((1, "L"), (-1, "R")):
        eye_p = C.empty("Eye" + nm, (0.125 * side, -0.245, 0.29), head, rot=(0, 0, math.radians(-22 * side)))
        C.link_mesh("EyeMesh" + nm, C.blob((0.062, 0.03, 0.085)), eye, eye_p)
        C.link_mesh("EyeShine" + nm, C.blob((0.022, 0.012, 0.024)), shine, eye_p, loc=(0.018 * side, -0.026, 0.035), subsurf=0)
        C.link_mesh("EyeShine2" + nm, C.blob((0.011, 0.008, 0.011)), shine, eye_p, loc=(-0.02 * side, -0.026, -0.03), subsurf=0)
        C.link_mesh("Cheek" + nm, C.blob((0.05, 0.015, 0.032)), blush, head,
                    loc=(0.175 * side, -0.24, 0.175), rot=(0, 0, math.radians(-30 * side)))

        # ears: tall teardrops tilted outwards, with pink inner
        ear = C.empty("Ear" + nm, (0.15 * side, 0.02, 0.47), head, rot=(math.radians(-6), math.radians(24 * side), 0))

        def ear_def(q, n):
            t = C.smoothstep(-0.3, 1.0, n.z)
            q.x *= 1.0 - 0.75 * t
            q.y *= 1.0 - 0.6 * t
            q.y += 0.03 * t * t  # bend back
            return q

        C.link_mesh("EarMesh" + nm, C.blob((0.1, 0.055, 0.2), deform=ear_def), fur, ear, loc=(0, 0, 0.15))
        C.link_mesh("EarTip" + nm, C.blob((0.035, 0.025, 0.05)), fur_dark, ear, loc=(0, 0.01, 0.33))
        C.link_mesh("EarInner" + nm, C.blob((0.06, 0.02, 0.13), deform=ear_def), pink, ear, loc=(0, -0.035, 0.13))

        # antennae with glowing tips (firefly)
        ant = C.empty("Ant" + nm, (0.06 * side, -0.08, 0.52), head, rot=(math.radians(-15), math.radians(10 * side), 0))
        pts = C.bezier_points((0, 0, 0), (0.02 * side, -0.02, 0.12), (0.09 * side, -0.1, 0.16), 7)
        C.link_mesh("AntStalk" + nm, C.tube(pts, [0.014, 0.013, 0.012, 0.011, 0.01, 0.01, 0.009], 8), nose, ant, subsurf=0)
        C.link_mesh("AntGlow" + nm, C.blob((0.035, 0.035, 0.035)), glow, ant, loc=pts[-1])

    # ---- arms
    for side, nm in ((1, "L"), (-1, "R")):
        arm = C.empty("Arm" + nm, (0.21 * side, -0.01, 0.27), hips, rot=(0, math.radians(-25 * side), 0))
        C.link_mesh("ArmMesh" + nm, C.tube([(0, 0, 0), (0, 0, -0.08), (0, -0.01, -0.15)], [0.045, 0.042, 0.04]), fur, arm)
        C.link_mesh("Hand" + nm, C.blob((0.052, 0.05, 0.055)), cream, arm, loc=(0, -0.012, -0.18))

    # ---- tail with lantern (two pivots -> overlapping action)
    tail1 = C.empty("Tail1", (0, 0.2, 0.06), hips, rot=(math.radians(-10), 0, 0))
    pts = C.bezier_points((0, 0, 0), (0, 0.2, -0.02), (0, 0.3, 0.14), 6)
    C.link_mesh("TailMesh", C.tube(pts, [0.06, 0.085, 0.095, 0.09, 0.075, 0.06], 14), fur, tail1)
    tail2 = C.empty("Tail2", pts[-1], tail1)
    C.link_mesh("LanternCap", C.blob((0.065, 0.065, 0.04)), lantern_cap, tail2, loc=(0, 0, 0.0))

    def bulb(q, n):
        # firefly-abdomen lantern with soft ridges
        r = 1.0 + 0.06 * math.cos(n.z * 14)
        return Vector((q.x * r, q.y * r, q.z))

    C.link_mesh("Lantern", C.blob((0.11, 0.11, 0.14), 24, 18, bulb), glow, tail2, loc=(0, 0.04, 0.12), rot=(math.radians(-25), 0, 0))
    C.export_glb("lumi.glb", root)


# ===================================================================== BOLOTA
def build_bolota():
    C.reset_scene()
    wood = C.mat("M_Wood_Body", "#C7884A", 0.6)
    nut = C.mat("M_Nut_Head", "#E0A766", 0.5)
    cap = C.mat("M_Cap", "#7A4A2A", 0.85)
    cap_rim = C.mat("M_CapRim", "#5E3720", 0.85)
    moss = C.mat("M_Moss", "#6DBE45", 0.8)
    moss_dark = C.mat("M_MossDark", "#3E8C3A", 0.8)
    leaf = C.mat("M_Leaf_Cape", "#4CB050", 0.6)
    leaf_vein = C.mat("M_LeafVein", "#2F7A38", 0.6)
    boot = C.mat("M_Boot", "#5B3A29", 0.7)
    gold = C.mat("M_Metal_Gold", "#F2C14E", 0.3, metallic=0.7)
    eye = C.mat("M_Eye", "#1B1530", 0.15)
    shine = C.mat("M_EyeShine", "#FFFFFF", 0.1)
    brow = C.mat("M_Brow", "#4A2C1A", 0.8)
    blush = C.mat("M_Blush", "#F27979", 0.7)
    nose_m = C.mat("M_NoseB", "#D9814E", 0.5)
    glow = C.mat("M_Glow_Gem", "#7CF5FF", 0.3, emission="#46E3FF")

    root = C.empty("Bolota")
    for side, nm in ((1, "L"), (-1, "R")):
        leg = C.empty("Leg" + nm, (0.15 * side, 0, 0.2), root)
        C.link_mesh("LegMesh" + nm, C.tube([(0, 0, 0.02), (0, 0, -0.1)], [0.08, 0.075]), wood, leg)
        C.link_mesh("Boot" + nm, C.blob((0.11, 0.14, 0.075), deform=lambda q, n: q + Vector((0, 0, -0.025 * max(0, -n.z)))),
                    boot, leg, loc=(0, -0.035, -0.135))
        C.link_mesh("BootCuff" + nm, C.torus(0.085, 0.025, 20, 8), boot, leg, loc=(0, 0, -0.08))

    hips = C.empty("Hips", (0, 0, 0.2), root)

    def torso(q, n):
        k = 1.0 + 0.1 * max(0.0, -n.z)
        return Vector((q.x * k, q.y * k, q.z))

    C.link_mesh("Body", C.blob((0.31, 0.28, 0.27), deform=torso), moss, hips, loc=(0, 0, 0.2))
    C.link_mesh("Belt", C.torus(0.305, 0.04, 36, 10, 0.9), wood, hips, loc=(0, 0, 0.13))
    C.link_mesh("Buckle", C.blob((0.06, 0.03, 0.05)), gold, hips, loc=(0, -0.3, 0.13), subsurf=1)
    C.link_mesh("BuckleGem", C.blob((0.026, 0.02, 0.026)), glow, hips, loc=(0, -0.325, 0.13))

    cape = C.empty("Cape", (0, 0.24, 0.4), hips, rot=(math.radians(14), 0, 0))

    def leaf_shape(q, n):
        t = (q.z + 0.34) / 0.68  # 0 bottom .. 1 top
        w = math.sin(min(1.0, max(0.0, t)) * math.pi) ** 0.7
        q.x *= 0.25 + 0.85 * w
        q.y += 0.05 * math.cos(q.x * 7.0)  # soft curl
        return q

    C.link_mesh("CapeLeaf", C.blob((0.22, 0.025, 0.28), 28, 18, leaf_shape), leaf, cape, loc=(0, 0.02, -0.2))
    C.link_mesh("CapeVein", C.tube([(0, -0.005, 0.05), (0, -0.01, -0.22), (0, 0.0, -0.46)], [0.016, 0.012, 0.005], 8), leaf_vein, cape,
                loc=(0, 0.04, 0.0), subsurf=0)

    head = C.empty("Head", (0, 0, 0.36), hips)

    def acorn(q, n):
        # acorn nut: rounder top, gently pointed chin
        if n.z < 0:
            k = 1.0 - 0.18 * (-n.z) ** 2
            q = Vector((q.x * k, q.y * k, q.z * (1.0 + 0.08 * -n.z)))
        return q

    C.link_mesh("HeadMesh", C.blob((0.33, 0.31, 0.3), 32, 20, acorn), nut, head, loc=(0, 0, 0.27))
    C.link_mesh("Chin", C.blob((0.05, 0.05, 0.05)), nut, head, loc=(0, 0, -0.01))

    def cap_shape(q, n):
        # bumpy scaled cap (the classic acorn crosshatch, made with sin bumps)
        lat = math.asin(max(-1, min(1, n.z)))
        lon = math.atan2(n.y, n.x)
        bump = 0.018 * max(0.0, math.sin(lon * 14) * math.sin(lat * 14)) * (1 if n.z > -0.2 else 0)
        q = q + n * bump
        if n.z < -0.2:
            q.z = q.z * 0.35 - 0.02  # tuck the underside
        return q

    C.link_mesh("CapMesh", C.blob((0.38, 0.36, 0.22), 40, 24, cap_shape), cap, head, loc=(0, 0.02, 0.43))
    C.link_mesh("CapRim", C.torus(0.35, 0.045, 40, 10, 0.8), cap_rim, head, loc=(0, 0.02, 0.38))
    sprout = C.empty("Sprout", (0, 0.02, 0.63), head)
    C.link_mesh("Stem", C.tube([(0, 0, -0.03), (0, 0, 0.05), (0.02, 0, 0.09)], [0.035, 0.03, 0.022]), cap_rim, sprout)
    sprout_leaf = C.empty("SproutLeaf", (0.02, 0, 0.09), sprout, rot=(0, math.radians(-50), 0))
    C.link_mesh("SproutLeafMesh", C.blob((0.06, 0.012, 0.11), deform=leaf_shape), moss_dark, sprout_leaf, loc=(0, 0, 0.1))

    for side, nm in ((1, "L"), (-1, "R")):
        eye_p = C.empty("Eye" + nm, (0.11 * side, -0.275, 0.29), head, rot=(0, 0, math.radians(-20 * side)))
        C.link_mesh("EyeMesh" + nm, C.blob((0.058, 0.03, 0.075)), eye, eye_p)
        C.link_mesh("EyeShine" + nm, C.blob((0.02, 0.012, 0.022)), shine, eye_p, loc=(0.016 * side, -0.026, 0.03), subsurf=0)
        C.link_mesh("EyeShine2" + nm, C.blob((0.01, 0.008, 0.01)), shine, eye_p, loc=(-0.018 * side, -0.026, -0.028), subsurf=0)
        brow_p = C.empty("Brow" + nm, (0.115 * side, -0.27, 0.39), head, rot=(0, math.radians(-8 * side), 0))
        C.link_mesh("BrowMesh" + nm, C.tube([(-0.045, 0, 0), (0, -0.01, 0.01), (0.045, 0, 0)], [0.022, 0.026, 0.018], 8), brow, brow_p)
        C.link_mesh("Cheek" + nm, C.blob((0.05, 0.015, 0.03)), blush, head,
                    loc=(0.18 * side, -0.255, 0.2), rot=(0, 0, math.radians(-32 * side)))

        arm = C.empty("Arm" + nm, (0.31 * side, 0, 0.3), hips, rot=(0, math.radians(-32 * side), 0))
        C.link_mesh("ArmMesh" + nm, C.tube([(0, 0, 0), (0, 0, -0.08), (0, -0.01, -0.14)], [0.07, 0.065, 0.06]), wood, arm)
        C.link_mesh("Mitten" + nm, C.blob((0.095, 0.085, 0.095)), moss_dark, arm, loc=(0, -0.015, -0.19))
        C.link_mesh("Thumb" + nm, C.blob((0.035, 0.035, 0.045)), moss_dark, arm, loc=(-0.06 * side, -0.06, -0.16))
        C.link_mesh("MittenCuff" + nm, C.torus(0.072, 0.022, 20, 8), moss, arm, loc=(0, -0.01, -0.12))

    C.link_mesh("Nose", C.blob((0.06, 0.045, 0.05)), nose_m, head, loc=(0, -0.31, 0.22))
    C.export_glb("bolota.glb", root)


if __name__ == "__main__":
    build_lumi()
    build_bolota()
