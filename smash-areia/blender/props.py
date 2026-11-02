"""Cenário extra: morros ao fundo, veleiro, quiosque, cadeira do juiz,
arquibancada nova e bandeirinha."""
import math

from mathutils import Vector

import build_assets as B


def build_mountains():
    B.reset_scene()
    rock = B.material("MorroRock", "#7d6fa8")
    green = B.material("MorroGreen", "#3fae6a")
    green2 = B.material("MorroGreen2", "#2f8f58")
    b = B.Builder("Mountains")
    # morros arredondados (pão de açúcar genérico) e serra
    b.sphere((0, 0, 0), 1.0, rock, scale=(14, 12, 30), seg=16, rings=10, cut_below=0)
    b.sphere((0, 0, 22), 1.0, green, scale=(9.5, 8.5, 9), seg=14, rings=8, cut_below=20)
    b.sphere((26, 6, 0), 1.0, rock, scale=(10, 9, 18), seg=14, rings=8, cut_below=0)
    b.sphere((26, 6, 13), 1.0, green2, scale=(7, 6.5, 6), seg=12, rings=8, cut_below=11)
    for i in range(7):
        x = -30 - i * 18
        h = 14 + (i * 37 % 11)
        b.sphere((x, 10 + (i % 2) * 6, 0), 1.0, green if i % 2 else green2, scale=(16, 12, h), seg=12, rings=8,
                 cut_below=0)
    b.build()
    B.export("mountains")


def build_sailboat():
    B.reset_scene()
    hull = B.material("BoatHull", "#ffffff")
    stripe = B.material("BoatStripe", "#ff4b3e")
    sail = B.material("Sail", "#fff4e0")
    sail2 = B.material("Sail2", "#ffd23f")
    mast = B.material("Mast", "#6b4a2b")
    b = B.Builder("Sailboat")
    b.sphere((0, 0, 0.3), 1.0, hull, scale=(0.9, 3.0, 0.5), seg=16, rings=8, cut_above=0.45)
    b.sphere((0, 0, 0.42), 1.0, stripe, scale=(0.92, 3.02, 0.06), seg=16, rings=4)
    b.cone((0, 0.2, 0.4), (0, 0, 1), 5.0, 0.06, 0.04, mast, seg=6)
    bm = b.bm
    for (pts, m) in (([(0, 0.25, 0.9), (0, 0.25, 5.2), (0, 2.6, 0.9)], sail),
                     ([(0, 0.15, 1.0), (0, 0.15, 4.6), (0, -2.2, 1.0)], sail2)):
        vs = [bm.verts.new(p) for p in pts]
        f = bm.faces.new(vs)
        f.material_index = b._mi(m)
        vs2 = [bm.verts.new((p[0] + 0.02, p[1], p[2])) for p in reversed(pts)]
        f2 = bm.faces.new(vs2)
        f2.material_index = b._mi(m)
    b.build()
    B.export("sailboat")


def build_kiosk():
    B.reset_scene()
    wood = B.material("KioskWood", "#c98a4b")
    roof = B.material("KioskRoof", "#e8c066")
    roof2 = B.material("KioskRoof2", "#d4a94e")
    counter = B.material("KioskCounter", "#2fb5ff")
    sign = B.material("KioskSign", "#ff4b3e")
    coco = B.material("Coco", "#5fbf3f")
    b = B.Builder("Kiosk")
    for sx in (-1.3, 1.3):
        for sy in (-1.0, 1.0):
            b.cone((sx, sy, 0), (0, 0, 1), 2.6, 0.08, 0.07, wood, seg=6)
    b.box((0, -0.9, 0.55), (2.8, 0.5, 1.1), counter)
    b.box((0, -0.9, 1.13), (3.0, 0.7, 0.08), wood)
    b.cone((0, 0, 2.5), (0, 0, 1), 1.3, 2.4, 0.1, roof, seg=10, smooth=False)
    b.cone((0, 0, 2.45), (0, 0, 1), 0.25, 2.5, 2.3, roof2, seg=10, smooth=False)
    b.box((0, -1.25, 2.3), (1.6, 0.06, 0.4), sign)
    for i in range(5):
        b.sphere((-0.9 + i * 0.45, -0.9, 1.3), 0.15, coco, seg=10, rings=8)
    b.build()
    B.export("kiosk")


def build_refchair():
    B.reset_scene()
    metal = B.material("RefMetal", "#ffffff")
    seat = B.material("RefSeat", "#2f8cff")
    b = B.Builder("RefChair")
    for sx in (-0.35, 0.35):
        b.box((sx, 0.25, 1.0), (0.06, 0.06, 2.0), metal)
        b.box((sx, -0.35, 0.9), (0.06, 0.06, 1.85), metal, rot=B.rot_x(-14))
    for i in range(5):
        b.box((0, -0.25 - i * 0.04, 0.3 + i * 0.36), (0.7, 0.05, 0.04), metal)
    b.box((0, 0.0, 1.95), (0.8, 0.75, 0.08), seat)
    b.box((0, 0.36, 2.3), (0.8, 0.06, 0.65), seat)
    b.box((-0.4, 0.0, 2.15), (0.05, 0.7, 0.3), metal)
    b.box((0.4, 0.0, 2.15), (0.05, 0.7, 0.3), metal)
    b.build()
    B.export("refchair")


def build_bleachers():
    B.reset_scene()
    frame = B.material("BleachFrame", "#dfe6f2")
    seat_a = B.material("BleachSeatA", "#2f8cff")
    seat_b = B.material("BleachSeatB", "#ffd23f")
    skirt = B.material("BleachSkirt", "#ff4b3e")
    b = B.Builder("Bleachers")
    rows = 5
    length = 15.0
    for i in range(rows):
        y = i * 0.75
        z = 0.45 + i * 0.5
        b.box((0, y, z - 0.04), (length, 0.75, 0.08), frame)
        b.box((0, y + 0.1, z + 0.18), (length - 0.2, 0.32, 0.1), seat_a if i % 2 == 0 else seat_b, smooth=False)
        b.box((0, y - 0.36, z * 0.5 - 0.02), (length, 0.04, z), skirt if i == 0 else frame)
    for k in range(7):
        x = -length / 2 + 0.2 + k * (length - 0.4) / 6
        b.box((x, rows * 0.75 - 0.4, (0.45 + rows * 0.5) / 2), (0.08, 0.08, 0.45 + rows * 0.5), frame)
        b.box((x, (rows * 0.75) / 2 - 0.4, 0.2), (0.06, rows * 0.75, 0.06), frame)
    b.box((0, rows * 0.75 - 0.35, 0.45 + rows * 0.5 + 0.35), (length, 0.05, 0.05), frame)
    b.build()
    B.export("bleachers")


def build_all():
    build_mountains()
    build_sailboat()
    build_kiosk()
    build_refchair()
    build_bleachers()
