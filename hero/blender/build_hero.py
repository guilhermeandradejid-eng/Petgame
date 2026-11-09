"""
Kael — JRPG hack-and-slash hero, modelled, rigged and animated procedurally with Blender (bpy).

    blender -b -P hero/blender/build_hero.py -- [options]
    python3 hero/blender/build_hero.py [options]          (with the `bpy` pip module)

Options
    --stills front,quarter,...      beauty stills of the bind pose
    --poses "Attack1:0,5,9;Run:0,9" render animation frames (with --view quarter|side|front|back|top)
    --reel                          render the showcase reel frames
    --no-export                     skip hero.glb / hero.blend
Outputs: hero/hero.glb, hero/hero.meta.json, hero/blender/hero.blend, hero/preview/*
"""
import bpy, sys, os, time, json
from math import radians
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
HERO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def opt(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


from kael import geo, facetex, look, skel, model, assemble, rig, anim   # noqa: E402

T0 = time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 60

# -- textures + materials -------------------------------------------------------
tex_path = os.path.join(HERE, "textures", "kael_face.png")
os.makedirs(os.path.dirname(tex_path), exist_ok=True)
atlas = facetex.build_atlas(int(opt("--face-res", "1024")))
face_img = look.face_image(atlas, tex_path)
for n in look.MAT_NAMES:
    look.make_pbr(n, face_img)

# -- model + rig -----------------------------------------------------------------
b = geo.Builder(look.MAT_NAMES)
model.build(b, only=opt("--parts"))
arm, BONES = assemble.armature(scene, model.EXTRA)
body = assemble.mesh_object(b, "KaelBody", scene, [x[0] for x in BONES])
assemble.bind(body, arm)
print("mesh: %d verts, %d faces, %d bones  (%.1fs)" % (len(b.v), len(b.f), len(BONES), time.time() - T0))

rg = rig.Rig(BONES)
rg.set_rest(arm)
anim.init(rg)
clips = anim.make_clips()
only = opt("--clips")
if only:
    clips = [c for c in clips if c.name in only.split(",")]


# -- baking ----------------------------------------------------------------------
def evaluate(clip, f, springs, shift=0.0):
    P = clip.controls(f)
    D, pos, info = rg.solve(P)
    rg.follow(D, pos)
    r = clip.root(f)
    Dw, pw = rg.to_world(D, pos, (r[0], r[1] + shift, r[2]))
    if springs is not None:
        springs.step(Dw, pw)
    info["tipw"] = Quaternion((0, 0, 1), radians(r[2])) @ info["tip"] + rig.V(r[0], r[1] + shift, 0)
    return P, pos, Dw, r, info


def set_pose(pos, Dw, r, prev, frame=None):
    loc = rg.local(Dw)
    for pb in arm.pose.bones:
        q = loc[pb.name]
        if pb.name in prev and prev[pb.name].dot(q) < 0:
            q = -q
        prev[pb.name] = q
        pb.rotation_quaternion = q
        if frame is not None:
            pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
    hp, rp = arm.pose.bones["hips"], arm.pose.bones["root"]
    hp.location = rg.RQ["hips"].inverted() @ (pos["hips"] - rg.RH["hips"])
    rp.location = rg.RQ["root"].inverted() @ rig.V(r[0], r[1], 0.0)
    if frame is not None:
        hp.keyframe_insert("location", frame=frame, group="hips")
        rp.keyframe_insert("location", frame=frame, group="root")


arm.animation_data_create()
ACTIONS, DIAG = {}, {}
for clip in clips:
    act = bpy.data.actions.new(clip.name)
    act.use_fake_user = True
    arm.animation_data.action = act
    springs = rig.Springs(rg, model.EXTRA)
    rg.edge_prev = None
    vel = clip.speed / 60.0
    if clip.loop:
        for f in range(-2 * clip.n, 0):
            evaluate(clip, f % clip.n, springs, vel * f)
    else:
        for _ in range(90):
            evaluate(clip, 0, springs)
    prev, rows, tip_prev = {}, [], None
    for f in range(clip.n + 1):
        P, pos, Dw, r, info = evaluate(clip, (f % clip.n) if clip.loop else f, springs, vel * f)
        set_pose(pos, Dw, r, prev, frame=f)
        tip = info["tipw"] - Vector((0, -vel * f, 0))
        sp = 0.0 if tip_prev is None else (tip - tip_prev).length * 60.0
        ed = 0.0
        if tip_prev is not None and sp > 1e-6:
            ed = info["edge"].dot((tip - tip_prev).normalized())
        tip_prev = tip
        rows.append(dict(f=f, tip=[round(x, 4) for x in tip], speed=round(sp, 2), edge=round(ed, 2),
                         rollY=round(info["rollY"], 1),
                         wrist=round(info["wrist_dev"], 1), bf=round(info["blade_fore"], 1),
                         legL=round(info["legL"], 3), legR=round(info["legR"], 3), root=[round(x, 4) for x in r]))
    ACTIONS[clip.name] = (act, clip.n)
    DIAG[clip.name] = rows
    pk = max(rows, key=lambda x: x["speed"])
    print("clip %-8s %3d f | tip peak %5.1f m/s @f%d (edge lead %.2f) | wrist max %3.0f deg | blade/forearm min %3.0f | leg max %.3f"
          % (clip.name, clip.n, pk["speed"], pk["f"], pk["edge"], max(x["wrist"] for x in rows),
             min(x["bf"] for x in rows), max(max(x["legL"], x["legR"]) for x in rows)))
json.dump(DIAG, open(os.path.join(HERE, "diag.json"), "w"))
print("baked %d clips (%.1fs)" % (len(clips), time.time() - T0))


def use_action(name):
    ad = arm.animation_data
    act = ACTIONS[name][0]
    ad.action = act
    try:
        if ad.action_slot is None and len(act.slots):
            ad.action_slot = act.slots[0]
    except Exception:
        pass


# -- export ----------------------------------------------------------------------
ad = arm.animation_data
if "--no-export" not in argv:
    ad.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    for name, (act, nfr) in ACTIONS.items():
        tr = ad.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 0, act)
        st.name = name
        try:
            if st.action_slot is None and len(act.slots):
                st.action_slot = act.slots[0]
        except Exception:
            pass
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(HERO, "hero.glb"), export_format="GLB", use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_yup=True, export_skins=True,
                              export_def_bones=False, export_optimize_animation_size=False,
                              export_anim_slide_to_zero=True, export_image_format="AUTO")
    meta = dict(
        fps=60,
        clips={c.name: dict(frames=c.n, loop=c.loop, speed=round(c.speed, 4), events=c.events,
                            root=[[round(v, 4) for v in c.root(f)] for f in range(c.n + 1)]) for c in clips},
        springs={ch["name"]: dict(parent=ch["parent"], bones=["%s%d" % (ch["name"], i + 1) for i in range(len(ch["pts"]) - 1)],
                                  stiffness=rig.SPRING[ch["name"]][0], drag=rig.SPRING[ch["name"]][1],
                                  gravity=rig.SPRING[ch["name"]][2], radius=rig.SPRING[ch["name"]][3],
                                  group=rig.GROUP[ch["name"]], pts=[[round(v, 5) for v in q] for q in ch["pts"]])
                 for ch in model.EXTRA},
        colliders=[dict(bone=c[0], center=list(c[1]), radius=c[2], groups=c[3]) for c in rig.COLLIDERS],
        rest={n: list(rg.RH[n]) for n in rg.names},
        palette={k: dict(base=v["base"], shade=v["shade"], kind=v["kind"], line=v["line"]) for k, v in look.PALETTE.items()},
        face=dict(cells=facetex.CELL),
        tris=sum(len(f) - 2 for f in b.f), bones=len(BONES),
    )
    json.dump(meta, open(os.path.join(HERO, "hero.meta.json"), "w"))
    print("exported hero.glb + hero.meta.json (%.1fs)" % (time.time() - T0))
    for tr in ad.nla_tracks:
        tr.mute = True

# -- look-dev ----------------------------------------------------------------------
want_render = any(k in argv for k in ("--stills", "--poses", "--reel", "--sheet"))
if want_render or "--no-export" not in argv:
    for n in look.MAT_NAMES:
        look.make_toon(n, face_img)
    look.add_outline(body)
    cam = look.setup_scene(scene)
    use_action("Idle" if "Idle" in ACTIONS else list(ACTIONS)[0])
    scene.frame_set(0)
if "--no-export" not in argv:
    look.aim(cam, (-3.4, -5.5, 1.5), (0, 0, 0.83), 110)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "hero.blend"), compress=True)
    print("saved hero.blend")

out = opt("--out", os.path.join(HERO, "preview"))
res = int(opt("--res", "640"))
samples = int(opt("--samples", "8"))
VIEWS = {   # name: (camera, target, lens, (w, h) as multiples of --res)
    "headF": ((0.0, -2.2, 1.47), (0, 0, 1.47), 200, (1, 1)), "headQ": ((-1.25, -1.8, 1.50), (0, 0, 1.47), 200, (1, 1)),
    "headS": ((-2.2, 0.0, 1.47), (0, 0, 1.47), 200, (1, 1)), "headB": ((0.9, 2.0, 1.52), (0, 0, 1.45), 200, (1, 1)),
    "front": ((0.0, -6.5, 1.0), (0, 0, 0.83), 150, (0.62, 1)), "quarter": ((-3.4, -5.5, 1.5), (0, 0, 0.83), 150, (0.62, 1)),
    "side": ((-6.5, 0.0, 1.0), (0, 0, 0.83), 150, (0.62, 1)), "back": ((2.0, 6.2, 1.3), (0, 0, 0.83), 150, (0.62, 1)),
    "quarterL": ((3.4, -5.5, 1.5), (0, 0, 0.83), 150, (0.62, 1)),
    "bust": ((-0.9, -3.0, 1.38), (0, 0, 1.22), 150, (1, 1)), "bustL": ((1.2, -2.9, 1.30), (0, 0, 1.22), 150, (1, 1)),
    "handR": ((-1.3, -1.4, 1.05), (-0.55, 0.0, 0.88), 200, (1, 1)), "handL": ((1.3, -1.4, 1.05), (0.55, 0.0, 0.88), 200, (1, 1)),
    "feet": ((-1.6, -2.4, 0.5), (0, 0, 0.2), 150, (1, 1)),
}
if opt("--stills"):
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    for v in opt("--stills").split(","):
        loc, tgt, lens, asp = VIEWS[v]
        look.aim(cam, loc, tgt, lens)
        look.render(scene, os.path.join(out, "still_%s.png" % v), (int(res * asp[0]), int(res * asp[1])), samples=samples)

# animation frames: wide action framing that follows the root
AVIEW = {"quarter": (-4.6, -6.6, 2.3), "side": (-8.2, 0.0, 1.1), "front": (0.0, -8.2, 1.2), "back": (3.0, 7.4, 2.2),
         "top": (0.0, -0.01, 9.0), "quarterL": (4.6, -6.6, 2.3), "game": (1.6, 5.2, 2.6)}
if opt("--poses"):
    view = opt("--view", "quarter")
    for spec in opt("--poses").split(";"):
        name, frs = spec.split(":")
        use_action(name)
        for f in frs.split(","):
            f = int(f)
            scene.frame_set(f)
            r = clips[[c.name for c in clips].index(name)].root(f)
            o = rig.V(r[0], r[1], 0.0)
            for vw in view.split(","):
                look.aim(cam, Vector(AVIEW[vw]) + o, Vector((0, 0, 0.92)) + o, 150 if vw != "top" else 105)
                look.render(scene, os.path.join(out, "pose_%s_%03d_%s.png" % (name, f, vw)), (res, res), samples=samples)

# -- presentation sheets ---------------------------------------------------------
def render_pose(name, f, vw, path, size, lens=150, tz=0.92):
    use_action(name)
    scene.frame_set(f)
    r = clips[[c.name for c in clips].index(name)].root(f)
    o = rig.V(r[0], r[1], 0.0)
    look.aim(cam, Vector(AVIEW[vw]) + o, Vector((0, 0, tz)) + o, lens)
    look.render(scene, path, size, samples=samples)


if "--sheet" in argv:
    os.makedirs(os.path.join(out, "sheet"), exist_ok=True)
    for i, vw in enumerate(("front", "quarter", "side", "back")):
        use_action("Idle")
        scene.frame_set(0)
        loc, tgt, lens, asp = VIEWS[vw]
        look.aim(cam, loc, tgt, 122)
        look.render(scene, os.path.join(out, "sheet", "turn_%d.png" % i), (560, 900), samples=samples)
    look.aim(cam, (-0.55, -2.3, 1.50), (0.0, 0.0, 1.45), 200)
    look.render(scene, os.path.join(out, "sheet", "face.png"), (900, 900), samples=samples)
    POSES = [("Idle", 0, "quarter"), ("Attack1", 9, "quarter"), ("Attack1", 19, "quarter"), ("Attack2", 13, "quarter"),
             ("Attack3", 21, "quarterL"), ("Attack3", 30, "quarter"), ("Run", 9, "side"), ("Dash", 8, "side")]
    for i, (name, f, vw) in enumerate(POSES):
        render_pose(name, f, vw, os.path.join(out, "sheet", "pose_%d.png" % i), (640, 640), lens=135,
                    tz=1.25 if (name == "Attack3" and f < 26) else 0.92)

# -- reel: one continuous performance, springs simulated across clip changes ------------
if "--reel" in argv:
    C = {c.name: c for c in clips}
    seq = []                                    # (clip, frame, blend-in frames)
    def add(name, f0, f1, blend=0):
        for k, f in enumerate(range(f0, f1)):
            seq.append((name, f, blend if k == 0 else 0))
    add("Idle", 0, 56); add("Attack1", 0, 22); add("Attack2", 0, 22); add("Attack3", 0, 82); add("Idle", 0, 20)
    add("Dash", 0, 36); add("Idle", 0, 10); add("Run", 0, 108, 8); add("Idle", 0, 34, 10); add("Hit", 0, 40); add("Idle", 0, 26)
    act = bpy.data.actions.new("Reel")
    arm.animation_data.action = act
    springs = rig.Springs(rg, model.EXTRA)
    rg.edge_prev = None
    off = Vector((0.0, 0.0))                    # accumulated stage offset (side, fwd)
    prev, last, base_root, Pprev, blend_left, blend_n, roots = {}, None, (0.0, 0.0, 0.0), None, 0, 1, []
    face_uv = bpy.data.materials["face"].node_tree.nodes["FaceUV"].inputs[1]
    EXPR = {"neutral": (0.0, 0.0, 0.0), "blink": (0.5, 0.0, 0.0), "attack": (0.0, -0.5, 0.0), "hurt": (0.5, -0.5, 0.0)}
    expr_prev = "neutral"
    for i, (name, f, bl) in enumerate(seq):
        clip = C[name]
        fr = (f % clip.n) if clip.loop else f
        if last is not None and (name != last[0] or f < last[1]):      # clip change: keep world position
            lr = C[last[0]].root(last[1])
            off += Vector((lr[0], lr[1]))
            if bl:
                blend_left, blend_n, Pfrom = bl, bl, Pprev
        P = clip.controls(fr)
        if blend_left > 0:
            w = 1.0 - (blend_left - 1) / float(blend_n)
            w = w * w * (3 - 2 * w)
            P = {k: tuple(a + (b2 - a) * w for a, b2 in zip(Pfrom[k], v)) if k in Pfrom else v for k, v in P.items()}
            blend_left -= 1
        Pprev = P
        r = clip.root(fr)
        if clip.speed:
            off += Vector((0.0, clip.speed / 60.0))
        D, pos, info = rg.solve(P)
        rg.follow(D, pos)
        stage = (off.x + r[0], off.y + r[1], r[2])
        Dw, pw = rg.to_world(D, pos, stage)
        springs.step(Dw, pw)
        set_pose(pos, Dw, stage, prev, frame=i)
        ex = "neutral"
        if name.startswith("Attack") and 4 <= f <= clip.events["hit"] + 14:
            ex = "attack"
        elif name == "Hit" and f < 22:
            ex = "hurt"
        elif i % 170 in range(60, 67):
            ex = "blink"
        if ex != expr_prev:
            face_uv.default_value = EXPR[expr_prev]
            face_uv.keyframe_insert("default_value", frame=i - 1)
        face_uv.default_value = EXPR[ex]
        face_uv.keyframe_insert("default_value", frame=i)
        expr_prev = ex
        roots.append(stage)
        last = (name, f)
    ACTIONS["Reel"] = (act, len(seq))
    use_action("Reel")
    os.makedirs(os.path.join(out, "reel"), exist_ok=True)
    cx, cy = 0.0, 0.0
    step = int(opt("--reel-step", "2"))
    size = int(opt("--reel-res", "720"))
    only = [int(x) for x in opt("--reel-only").split(",")] if opt("--reel-only") else None
    for i in range(0, len(seq), step):
        cx += (roots[i][0] - cx) * 0.22
        cy += (roots[i][1] - cy) * 0.22
        if only and (i // step) not in only:
            continue
        if "--reel-resume" in argv and os.path.exists(os.path.join(out, "reel", "%04d.png" % (i // step))):
            continue
        o = rig.V(cx, cy, 0.0)
        scene.frame_set(i)
        # 4:3 frame tall enough for the whole body, the sword overhead and the leap
        look.aim(cam, Vector((-4.4, -6.2, 2.3)) + o, Vector((0, 0, 1.12)) + o, 77)
        look.render(scene, os.path.join(out, "reel", "%04d.png" % (i // step)), (int(size * 4 / 3), size), samples=samples)
    print("reel: %d frames" % (len(seq) // step))
print("done in %.1fs" % (time.time() - T0))
