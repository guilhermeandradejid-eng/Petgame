# Gera os bonecos e adereços, anima (poses.py) e exporta GLB a 60 fps (chaves CONSTANT, sem otimizador).
# Uso: python3 exportar.py PROJ [nome ...]
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import herois as H
import animar as A
import importlib
try:
    import poses as PS
except ImportError as e:
    print('sem poses', e); PS = None

PROJ = sys.argv[1]
only = sys.argv[2:]
GLB = os.path.join(PROJ, 'assets', 'glb')
os.makedirs(GLB, exist_ok=True)
ALL = dict(H.HEROES); ALL.update(H.OTHERS); ALL.update(H.PROPS)
stats = {}
for name, fn in ALL.items():
    if only and name not in only:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = 60
    t0 = time.time()
    B = fn()
    arm, ob = H.assemble(B, name)
    acts = []
    spec = PS.acoes(name) if PS else {}
    for an, frames in spec.items():
        acts.append(A.key_action(arm, an, frames))
    if acts:
        A.finish_actions(arm, acts)
    scn.frame_set(0)
    t1 = time.time()
    path = os.path.join(GLB, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=False,
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True,
                              export_texcoords=True, export_materials='EXPORT', export_yup=True, export_skins=True,
                              export_optimize_animation_size=False)
    me = ob.data
    me.calc_loop_triangles()
    stats[name] = dict(tris=len(me.loop_triangles), ossos=len(arm.data.bones), pecas=B.n, acoes=list(spec.keys()),
                       t=round(time.time() - t0, 2), kb=round(os.path.getsize(path) / 1024, 1))
    print(name, stats[name], flush=True)
p = os.path.join(GLB, 'stats.json')
prev = json.load(open(p)) if os.path.exists(p) else {}
prev.update(stats)
json.dump(prev, open(p, 'w'), indent=1, ensure_ascii=False)
