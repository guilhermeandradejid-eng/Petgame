# Gera os bonecos, pinta o atlas de cada um (pintura.py), anima (poses.py) e exporta GLB a 60 fps.
# Uso: python3 exportar.py PROJ [nome ...]
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bonecos as K
import animar as A
import pintura as PT
try:
    import poses as PS
except ImportError:
    PS = None

PROJ = sys.argv[1]
only = sys.argv[2:]
GLB = os.path.join(PROJ, 'assets', 'glb'); TEX = os.path.join(PROJ, 'assets', 'tex')
os.makedirs(GLB, exist_ok=True); os.makedirs(TEX, exist_ok=True)
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
    t1 = time.time()
    dens, size = PT.bake(B, os.path.join(TEX, name + '.png'), dens=700.0 if name in K.HEROES else 520.0, W=2048)
    t2 = time.time()
    arm, ob = K.assemble(B, name)
    acts = []
    spec = PS.ACTIONS.get(name, {}) if PS else {}
    for an, frames in spec.items():
        acts.append(A.key_action(arm, an, frames))
    if acts:
        A.finish_actions(arm, acts)
    scn.frame_set(0)
    t3 = time.time()
    path = os.path.join(GLB, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=False,
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True,
                              export_materials='EXPORT', export_yup=True, export_skins=True, export_optimize_animation_size=False)
    t4 = time.time()
    me = ob.data
    me.calc_loop_triangles()
    stats[name] = dict(tris=len(me.loop_triangles), bones=len(arm.data.bones), pecas=len(B.specs) if hasattr(B, 'specs') else 0,
                       atlas=list(size), dens=round(dens), t_build=round(t1 - t0, 2), t_tinta=round(t2 - t1, 2), t_anim=round(t3 - t2, 2),
                       t_export=round(t4 - t3, 2), kb=round(os.path.getsize(path) / 1024, 1), body=list(getattr(B, 'S', {}).get('_body', [])))
    print(name, stats[name], flush=True)
p = os.path.join(GLB, 'stats.json')
prev = json.load(open(p)) if os.path.exists(p) else {}
prev.update(stats)
json.dump(prev, open(p, 'w'), indent=1, ensure_ascii=False)
