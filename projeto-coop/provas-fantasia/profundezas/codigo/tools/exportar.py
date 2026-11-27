# Gera os personagens, anima (poses.py) e exporta GLB a 60 fps. Uso: python3 exportar.py PROJ [nome ...]
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import personagens as K
import animar as A
import montar as MT
try:
    import poses as PS
except ImportError as e:
    print('sem poses', e); PS = None

PROJ = sys.argv[1]
only = sys.argv[2:]
GLB = os.path.join(PROJ, 'assets', 'glb')
os.makedirs(GLB, exist_ok=True)
ALL = dict(K.HEROES); ALL.update(K.ENEMIES); ALL.update(K.PROPS)
stats = {}
for name, fn in ALL.items():
    if only and name not in only:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = 60
    t0 = time.time()
    B = fn()
    rig = name not in K.PROPS
    arm, ob = MT.assemble(B, name, armature=rig, bake_kw=dict(ao_dist=0.6 if name == 'bocalume' else 0.3))
    acts = []
    spec = PS.ACTIONS.get(name, {}) if (PS and rig) else {}
    for an, frames in spec.items():
        acts.append(A.key_action(arm, an, frames))
    if acts:
        A.finish_actions(arm, acts)
    scn.frame_set(0)
    path = os.path.join(GLB, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=bool(acts),
                              export_animation_mode='ACTIONS', export_force_sampling=False,
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True, export_texcoords=True,
                              export_materials='EXPORT', export_yup=True, export_skins=rig, export_optimize_animation_size=False)
    me = ob.data
    me.calc_loop_triangles()
    stats[name] = dict(tris=len(me.loop_triangles), ossos=len(arm.data.bones) if arm else 0, pecas=len(B.specs), acoes=len(acts),
                       t=round(time.time() - t0, 2), kb=round(os.path.getsize(path) / 1024, 1))
    print(name, stats[name], flush=True)
p = os.path.join(GLB, 'stats.json')
prev = json.load(open(p)) if os.path.exists(p) else {}
prev.update(stats)
json.dump(prev, open(p, 'w'), indent=1, ensure_ascii=False)
