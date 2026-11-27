# Gera as figuras (heróis, inimigos, adereços), pinta os atlas, anima e exporta GLB.
# Uso: python3 export_glb.py OUTDIR [nome ...]
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
import pincel as K
import herois, inimigos, anims, props

OUT = sys.argv[1]
only = sys.argv[2:]
os.makedirs(OUT, exist_ok=True)
BUILD = dict(herois.HEROES); BUILD.update(inimigos.ENEMIES); BUILD.update(props.PROPS)
stats = {}
for name, fn in BUILD.items():
    if only and name not in only:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = 60
    t0 = time.time()
    F = fn()
    K.to_img(F.atlas.img).save(os.path.join(OUT, name + '_atlas.png'))
    meta = dict(getattr(F, 'meta', {}))
    S = F.atlas.S
    meta['regions'] = {k: [v[0] / S, v[1] / S, (v[0] + v[2]) / S, (v[1] + v[3]) / S] for k, v in F.atlas.regions.items()}
    if 'cabeca' in F.atlas.regions:
        x, y, w, h = F.atlas.regions['cabeca']
        meta['face_rect'] = [(x + 2) / S, (y + 2) / S, (x + w - 2) / S, (y + h - 2) / S]
    json.dump(meta, open(os.path.join(OUT, name + '_meta.json'), 'w'), indent=1)
    t1 = time.time()
    arm, ob = F.build(name)
    t2 = time.time()
    clips = anims.CLIPS.get(name, {})
    for cname, frames in clips.items():
        G_ = __import__('geo')
        G_.key_action(arm, cname, frames)
    t3 = time.time()
    path = os.path.join(OUT, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=bool(clips),
                              export_animation_mode='ACTIONS', export_force_sampling=False,
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True,
                              export_materials='EXPORT', export_yup=True, export_skins=True)
    t4 = time.time()
    me = ob.data
    me.calc_loop_triangles()
    tri = {}
    for t in me.loop_triangles:
        tri[me.materials[t.material_index].name] = tri.get(me.materials[t.material_index].name, 0) + 1
    stats[name] = dict(tris=len(me.loop_triangles), por_material=tri, ossos=len(arm.data.bones), clipes=list(clips),
                       t_modelo=round(t1 - t0, 2), t_rig=round(t2 - t1, 2), t_anim=round(t3 - t2, 2), t_export=round(t4 - t3, 2),
                       kb=round(os.path.getsize(path) / 1024, 1))
    print(name, stats[name])
old = {}
sp = os.path.join(OUT, 'stats.json')
if os.path.exists(sp):
    old = json.load(open(sp))
old.update(stats)
json.dump(old, open(sp, 'w'), indent=1)
