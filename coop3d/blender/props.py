"""Builds the stylized environment props and exports one .glb per prop.

Material names drive the Godot side: M_Grass*/M_Rock*/M_Bark* get the
triplanar toon terrain shader with CC0 detail normals, M_Glow* become
emissive, everything else becomes the regular toon shader.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402,F401
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

import bl_common as C  # noqa: E402


def island():
    """Floating island chunk: flat grassy top with drippy grass rim and a
    rocky, stalactite-like underside. Unit radius 1 (scaled in Godot)."""
    C.reset_scene()
    grass = C.mat("M_Grass_Top", "#7BD35A", 0.9)
    rock = C.mat("M_Rock_Island", "#B98A6A", 0.9)
    root = C.empty("Island")

    def top(q, n):
        # flattened dome with drips around the rim
        if n.z > -0.1:
            q.z = 0.12 + 0.06 * n.z
        lon = math.atan2(n.y, n.x)
        rim = 1.0 - C.smoothstep(0.0, 0.5, n.z)
        q.z -= rim * (0.08 + 0.1 * max(0.0, math.sin(lon * 7.0)) ** 3)
        return q

    C.link_mesh("Top", C.blob((1.02, 1.02, 0.25), 48, 16, top), grass, root)

    def under(q, n):
        if n.z > 0:
            q.z = 0.0
        else:
            d = -n.z
            wob = noise.noise(Vector((n.x * 3, n.y * 3, 1.0))) * 0.15
            q.z = -d ** 0.8 * (1.0 + wob) * 1.0
            k = (1.0 - d ** 1.4 * 0.9) * (1.0 + 0.08 * math.sin(math.atan2(n.y, n.x) * 9))
            q.x *= k
            q.y *= k
        return q

    C.link_mesh("Under", C.blob((0.98, 0.98, 1.0), 40, 20, under), rock, root, loc=(0, 0, 0.0))
    C.export_glb("island.glb", root)


def tree(name="tree.glb", seed=1, canopy="#4FBF5A", canopy2="#7BDC6A"):
    C.reset_scene()
    random.seed(seed)
    bark = C.mat("M_Bark", "#8B5A3C", 0.9)
    leaves = C.mat("M_Leaf_Canopy", canopy, 0.8)
    leaves2 = C.mat("M_Leaf_Canopy2", canopy2, 0.8)
    root = C.empty("Tree")
    pts = C.bezier_points((0, 0, -0.1), (0.15, 0, 1.0), (-0.1, 0.05, 1.9), 8)
    C.link_mesh("Trunk", C.tube(pts, [0.26, 0.2, 0.17, 0.15, 0.14, 0.13, 0.12, 0.11], 12), bark, root)
    C.link_mesh("Roots", C.blob((0.42, 0.42, 0.15)), bark, root, loc=(0, 0, 0.0))
    sway = C.empty("Canopy", pts[-1], root)
    for i in range(7):
        a = i / 7 * math.tau + random.random() * 0.4
        r = 0.55 if i else 0.0
        size = random.uniform(0.55, 0.75)
        m = leaves if i % 2 else leaves2
        C.link_mesh("Leaf%d" % i, C.blob((size, size, size * 0.85)), m, sway,
                    loc=(math.cos(a) * r, math.sin(a) * r, random.uniform(0.15, 0.55)))
    C.link_mesh("LeafTop", C.blob((0.7, 0.7, 0.6)), leaves2, sway, loc=(0, 0, 0.85))
    C.export_glb(name, root)


def mushroom():
    C.reset_scene()
    stem = C.mat("M_Stem", "#FFF1DA", 0.7)
    cap = C.mat("M_Cap_Mushroom", "#FF4F79", 0.5)
    dots = C.mat("M_Dots", "#FFF6E8", 0.6)
    root = C.empty("Mushroom")
    C.link_mesh("Stem", C.tube([(0, 0, 0), (0, 0, 0.35), (0, 0, 0.7)], [0.32, 0.26, 0.24], 16), stem, root)
    top = C.empty("CapPivot", (0, 0, 0.7), root)

    def cap_def(q, n):
        if n.z < 0:
            q.z *= 0.25
        return q

    C.link_mesh("Cap", C.blob((1.0, 1.0, 0.55), 40, 20, cap_def), cap, top, loc=(0, 0, 0.05))
    random.seed(3)
    for i in range(9):
        a = i / 9 * math.tau
        lat = 0.45 if i % 2 else 0.85
        n = Vector((math.cos(a) * math.cos(lat), math.sin(a) * math.cos(lat), math.sin(lat)))
        p = Vector((n.x * 1.0, n.y * 1.0, n.z * 0.55 + 0.05))
        C.link_mesh("Dot%d" % i, C.blob((0.15, 0.15, 0.05)), dots, top, loc=p,
                    rot=(0, math.acos(max(-1, min(1, n.z))) * 0.9, a))
    C.link_mesh("CapTop", C.blob((0.24, 0.24, 0.06)), dots, top, loc=(0, 0, 0.6))
    C.export_glb("mushroom.glb", root)


def crystal():
    C.reset_scene()
    glow = C.mat("M_Glow_Crystal", "#8AE9FF", 0.2, emission="#5BD7FF")
    base = C.mat("M_Rock_Crystal", "#6B6A8F", 0.9)
    root = C.empty("Crystal")
    C.link_mesh("Base", C.blob((0.45, 0.45, 0.18)), base, root, subsurf=1)
    random.seed(7)
    for i in range(5):
        h = random.uniform(0.5, 1.1) if i else 1.4
        bm = C.cone(0.16 if i else 0.22, 0.0, h, 6)
        for v in bm.verts:
            if v.co.z > h * 0.25:
                v.co.x *= 0.9
        a = i / 4 * math.tau
        r = 0.22 if i else 0.0
        C.link_mesh("Shard%d" % i, bm, glow, root, loc=(math.cos(a) * r, math.sin(a) * r, h * 0.45),
                    rot=(math.cos(a) * 0.4 * (1 if i else 0), math.sin(a) * 0.4 * (1 if i else 0), 0), subsurf=0, smooth=False)
    C.export_glb("crystal.glb", root)


def rock():
    C.reset_scene()
    m = C.mat("M_Rock", "#A79A8C", 0.95)
    root = C.empty("Rock")

    def d(q, n):
        f = 1.0 + 0.25 * noise.noise(n * 1.7) + 0.08 * noise.noise(n * 5.0)
        q = q * f
        if q.z < -0.2:
            q.z = -0.2
        return q

    C.link_mesh("RockMesh", C.blob((0.7, 0.55, 0.5), 20, 12, d), m, root, subsurf=1, smooth=True)
    C.export_glb("rock.glb", root)


def bush():
    C.reset_scene()
    a = C.mat("M_Leaf_Bush", "#4DB860", 0.8)
    b = C.mat("M_Leaf_Bush2", "#6FD072", 0.8)
    berry = C.mat("M_Berry", "#FF5A8A", 0.4)
    root = C.empty("Bush")
    random.seed(11)
    for i in range(5):
        ang = i / 5 * math.tau
        s = random.uniform(0.35, 0.5)
        C.link_mesh("B%d" % i, C.blob((s, s, s * 0.85)), a if i % 2 else b, root,
                    loc=(math.cos(ang) * 0.3, math.sin(ang) * 0.3, s * 0.6))
    for i in range(6):
        ang = i / 6 * math.tau + 0.3
        C.link_mesh("Berry%d" % i, C.blob((0.06, 0.06, 0.06)), berry, root,
                    loc=(math.cos(ang) * 0.55, math.sin(ang) * 0.55, 0.45 + 0.15 * (i % 2)))
    C.export_glb("bush.glb", root)


def flower():
    C.reset_scene()
    stem = C.mat("M_Stem_Flower", "#3E9B4A", 0.8)
    petal = C.mat("M_Petal", "#FFFFFF", 0.6)  # tinted per instance in Godot
    center = C.mat("M_Glow_Pollen", "#FFD84D", 0.4, emission="#FFB830")
    root = C.empty("Flower")
    C.link_mesh("Stem", C.tube(C.bezier_points((0, 0, 0), (0.05, 0, 0.2), (0, 0, 0.4), 5), [0.02] * 5, 6), stem, root, subsurf=0)
    head = C.empty("Head", (0, 0, 0.4), root, rot=(math.radians(-20), 0, 0))
    for i in range(6):
        a = i / 6 * math.tau
        C.link_mesh("Petal%d" % i, C.blob((0.07, 0.035, 0.012)), petal, head,
                    loc=(math.cos(a) * 0.07, math.sin(a) * 0.07, 0), rot=(0, 0, a))
    C.link_mesh("Center", C.blob((0.04, 0.04, 0.03)), center, head)
    C.export_glb("flower.glb", root)


def spark():
    """Small collectible: a puffy 4-point star gem."""
    C.reset_scene()
    m = C.mat("M_Glow_Spark", "#FFE36E", 0.2, emission="#FFC93C")
    root = C.empty("Spark")

    def star(q, n):
        lon = math.atan2(n.z, n.x)
        k = 0.55 + 0.45 * abs(math.cos(lon * 2.0)) ** 3
        return Vector((q.x * k, q.y, q.z * k))

    C.link_mesh("Star", C.blob((0.3, 0.12, 0.3), 32, 16, star), m, root)
    C.export_glb("spark.glb", root)


def star_seed():
    """Rare collectible (3 per level): a glowing seed with leaves."""
    C.reset_scene()
    seed_m = C.mat("M_Glow_Seed", "#B88CFF", 0.2, emission="#9D6BFF")
    leaf = C.mat("M_Leaf_Seed", "#7BE07A", 0.6)
    root = C.empty("StarSeed")

    def drop(q, n):
        t = C.smoothstep(-0.2, 1.0, n.z)
        return Vector((q.x * (1 - 0.6 * t), q.y * (1 - 0.6 * t), q.z))

    C.link_mesh("Seed", C.blob((0.3, 0.3, 0.42), 28, 18, drop), seed_m, root)
    for side in (1, -1):
        C.link_mesh("Leaf%d" % side, C.blob((0.18, 0.03, 0.08)), leaf, root,
                    loc=(0.14 * side, 0, 0.42), rot=(0, math.radians(-30 * side), 0))
    C.export_glb("star_seed.glb", root)


def lantern_post():
    """Checkpoint: a wooden post with a lantern that lights up."""
    C.reset_scene()
    wood = C.mat("M_Bark_Post", "#8B5A3C", 0.9)
    metal = C.mat("M_Metal_Lantern", "#3E3550", 0.4, metallic=0.5)
    glass = C.mat("M_Glow_Checkpoint", "#FFF2B3", 0.2, emission="#FFE08A")
    root = C.empty("LanternPost")
    C.link_mesh("Post", C.tube(C.bezier_points((0, 0, 0), (0, 0, 0.9), (0.08, 0, 1.6), 6), [0.1, 0.09, 0.085, 0.08, 0.075, 0.07], 10), wood, root)
    C.link_mesh("Arm", C.tube(C.bezier_points((0.06, 0, 1.55), (0.35, 0, 1.75), (0.5, 0, 1.6), 6), [0.04] * 6, 8), wood, root)
    lamp = C.empty("Lamp", (0.5, 0, 1.55), root)
    C.link_mesh("LampTop", C.cone(0.17, 0.03, 0.12, 8), metal, lamp, loc=(0, 0, -0.06), subsurf=0, smooth=False)
    C.link_mesh("LampGlass", C.blob((0.12, 0.12, 0.16), 16, 10), glass, lamp, loc=(0, 0, -0.25))
    C.link_mesh("LampBottom", C.cone(0.09, 0.13, 0.05, 8), metal, lamp, loc=(0, 0, -0.42), subsurf=0, smooth=False)
    C.export_glb("lantern_post.glb", root)


def urchin():
    """Enemy 'Espinhudo': grumpy round urchin with soft spikes and eyes."""
    C.reset_scene()
    body = C.mat("M_Body_Urchin", "#8E5BD9", 0.5)
    spike = C.mat("M_Spike", "#FF6FAE", 0.5)
    eye = C.mat("M_Eye", "#1B1530", 0.15)
    white = C.mat("M_EyeWhite", "#FFFFFF", 0.3)
    shine = C.mat("M_EyeShine", "#FFFFFF", 0.1)
    root = C.empty("Urchin")
    bodyp = C.empty("BodyPivot", (0, 0, 0.45), root)
    C.link_mesh("Body", C.blob((0.45, 0.45, 0.42)), body, bodyp)
    golden = math.pi * (3 - math.sqrt(5))
    n = 26
    for i in range(n):
        y = 1 - (i / (n - 1)) * 2
        r = math.sqrt(1 - y * y)
        th = golden * i
        d = Vector((math.cos(th) * r, math.sin(th) * r, y))
        if d.y < -0.55 and abs(d.z) < 0.6:
            continue  # keep the face clear
        if d.z < -0.6:
            continue
        rot = d.to_track_quat("Z", "Y").to_euler()
        C.link_mesh("Spike%d" % i, C.cone(0.09, 0.0, 0.3, 8), spike, bodyp, loc=d * 0.5, rot=rot, subsurf=0)
    for side, nm in ((1, "L"), (-1, "R")):
        ep = C.empty("Eye" + nm, (0.15 * side, -0.38, 0.06), bodyp, rot=(0, 0, math.radians(-25 * side)))
        C.link_mesh("EyeWhite" + nm, C.blob((0.11, 0.05, 0.12)), white, ep)
        C.link_mesh("Pupil" + nm, C.blob((0.055, 0.03, 0.07)), eye, ep, loc=(-0.015 * side, -0.04, -0.01))
        C.link_mesh("Shine" + nm, C.blob((0.018, 0.01, 0.02)), shine, ep, loc=(0.0, -0.07, 0.02), subsurf=0)
        C.link_mesh("Brow" + nm, C.tube([(-0.07, 0, 0.03), (0.07, 0, -0.02)], [0.025, 0.025], 6), eye, ep,
                    loc=(0, -0.04, 0.14), rot=(0, math.radians(20 * side), 0))
    C.export_glb("urchin.glb", root)


def star_bloom():
    """Level goal: a big crystal flower that blooms when both heroes touch it."""
    C.reset_scene()
    stem = C.mat("M_Stem_Bloom", "#3E9B4A", 0.7)
    petal = C.mat("M_Glow_Petal", "#FFB3E6", 0.3, emission="#FF7AD1")
    core = C.mat("M_Glow_Core", "#FFF4B0", 0.2, emission="#FFE066")
    leaf = C.mat("M_Leaf_Bloom", "#5CCB5F", 0.7)
    root = C.empty("StarBloom")
    C.link_mesh("Stem", C.tube(C.bezier_points((0, 0, 0), (0.2, 0, 1.0), (0, 0, 2.0), 8), [0.12, 0.11, 0.1, 0.1, 0.09, 0.09, 0.08, 0.08], 10), stem, root)
    for side in (1, -1):
        C.link_mesh("Leaf%d" % side, C.blob((0.5, 0.05, 0.18)), leaf, root, loc=(0.4 * side, 0, 0.6),
                    rot=(0, math.radians(-25 * side), 0))
    head = C.empty("Bloom", (0, 0, 2.05), root)
    for i in range(5):
        a = i / 5 * math.tau
        piv = C.empty("Petal%d" % i, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0), head, rot=(0, 0, a))
        C.link_mesh("PetalMesh%d" % i, C.blob((0.45, 0.2, 0.05), deform=lambda q, n: q + Vector((0, 0, 0.12 * (q.x / 0.45) ** 2))),
                    petal, piv, loc=(0.42, 0, 0.05), rot=(0, math.radians(-25), 0))
    C.link_mesh("Core", C.blob((0.22, 0.22, 0.2)), core, head, loc=(0, 0, 0.1))
    C.export_glb("star_bloom.glb", root)


if __name__ == "__main__":
    island()
    tree()
    tree("tree_pink.glb", 5, "#FF8FB8", "#FFB3CF")
    mushroom()
    crystal()
    rock()
    bush()
    flower()
    spark()
    star_seed()
    lantern_post()
    urchin()
    star_bloom()
