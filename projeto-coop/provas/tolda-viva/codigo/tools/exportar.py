# Gera todos os bonecos, anima (poses.py), cria o smear, roda o teste de colisão e exporta GLB a 60 fps.
# Uso: python3 exportar.py SAIDA [nome ...]
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bonecos as K
import animar as A
import poses as PS
from malha import Builder

OUT = sys.argv[1]
only = sys.argv[2:]
os.makedirs(OUT, exist_ok=True)
stats = {}
for name in list(K.HEROES) + list(K.ENEMIES):
    if only and name not in only:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = 60
    t0 = time.time()
    B = K.build_hero(name) if name in K.HEROES else K.ENEMIES[name]()
    S = getattr(B, 'S', {})
    arm, ob = K.assemble(B, name)
    t1 = time.time()
    acts = []
    spec = PS.ACTIONS.get(name, PS.ACTIONS.get(name.split('_')[0], {}))
    info = {}
    for an, frames in spec.items():
        acts.append(A.key_action(arm, an, frames))
    # smear de 1 quadro, gerado da própria ação
    for an, (f_from, f_smear, kind) in PS.SMEARS.get(name, {}).items():
        act = bpy.data.actions[an]
        bm, fan = A.build_smear(arm, name, S, act, f_from, f_smear, kind, 'madeira_esc', 'madeira')
        sb = Builder(3, B.groups[:-1], outline=0.006)
        sb.piece(bm, color='madeira_esc' if kind == 'macete' else 'anilina', bone='smear', smooth=True,
                 colorfn=(lambda f: 'madeira' if (hash((round(f.calc_center_median().x, 2),)) % 5 == 0) else ('madeira_esc' if kind == 'macete' else 'anilina')))
        sb.piece(fan, color='madeira', bone='smear', smooth=True, oline=0.7)
        me = bpy.data.meshes.new(name + '_smear_' + an)
        sb.bm.to_mesh(me); sb.bm.free()
        for mname in ('cor', 'pano', 'contorno', 'olho'):
            me.materials.append(bpy.data.materials[mname])
        me.color_attributes.active_color_name = 'Col'
        so = bpy.data.objects.new(name + '_smear_' + an, me)
        scn.collection.objects.link(so)
        for g in sb.groups:
            so.vertex_groups.new(name=g)
        so.parent = arm
        md = so.modifiers.new('Armature', 'ARMATURE'); md.object = arm
    # teste de colisão do adereço
    for an, (fr, br, z0, z1) in PS.COLLIDE.get(name, {}).items():
        info['colisao_' + an] = A.collision_report(arm, S, bpy.data.actions[an], fr, br, z0, z1)
    if acts:
        A.finish_actions(arm, acts)
    scn.frame_set(0)
    t2 = time.time()
    path = os.path.join(OUT, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=False,
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True,
                              export_materials='EXPORT', export_yup=True, export_skins=True, export_optimize_animation_size=False)
    t3 = time.time()
    me = ob.data
    me.calc_loop_triangles()
    stats[name] = dict(tris=len(me.loop_triangles), bones=len(arm.data.bones), t_build=round(t1 - t0, 3), t_anim=round(t2 - t1, 3),
                       t_export=round(t3 - t2, 3), kb=round(os.path.getsize(path) / 1024, 1), **info)
print(json.dumps(stats, indent=1, ensure_ascii=False))
prev = {}
p = os.path.join(OUT, 'stats.json')
if os.path.exists(p):
    prev = json.load(open(p))
prev.update(stats)
json.dump(prev, open(p, 'w'), indent=1, ensure_ascii=False)
