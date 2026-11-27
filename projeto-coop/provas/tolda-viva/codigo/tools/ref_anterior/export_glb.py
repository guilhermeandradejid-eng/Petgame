# Gera os bonecos e exporta GLB. Uso: python3 export_glb.py OUTDIR
import sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import boneco as K

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

VARIANTS = {
    'heroi_p1': dict(K.HERO),
    'heroi_p2': dict(K.HERO, seed=8, hat='cone', hat_c1='#2459B8', hat_c2='#F4EFE4', hat_c3='#F2C230', collar='#F4EFE4', mustache=False, wood='#E3B07E', blade='#2459B8'),
    'heroi_p3': dict(K.HERO, seed=9, hat='flores', hat_c1='#F2C230', hat_c2='#E0483A', hat_c3='#F4EFE4', collar='#F2C230', mustache=False, wood='#C98A58', blade='#2E8B57'),
    'heroi_p4': dict(K.HERO, seed=10, hat='meialua', hat_c1='#6B4A2E', hat_c2='#6B4A2E', hat_c3='#F2C230', collar='#E0483A', wood='#D49A64', blade='#8E3B9E'),
    'inimigo': dict(K.ENEMY),
}
stats = {}
for name, P in VARIANTS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t0 = time.time()
    B = K.build(P)
    arm, ob = K.assemble(B, name)
    t1 = time.time()
    K.key_action(arm, 'idle', K.IDLE)
    K.key_action(arm, 'ataque', K.ATTACK)
    K.key_action(arm, 'golpeado', K.HITA)
    scn = bpy.context.scene
    scn.render.fps = 24
    t2 = time.time()
    path = os.path.join(OUT, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=False,
                              export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=True,
                              export_materials='EXPORT', export_yup=True, export_skins=True)
    t3 = time.time()
    me = ob.data
    me.calc_loop_triangles()
    tri_by_mat = {}
    for tri in me.loop_triangles:
        tri_by_mat[tri.material_index] = tri_by_mat.get(tri.material_index, 0) + 1
    stats[name] = dict(verts=len(me.vertices), tris=len(me.loop_triangles), tris_by_mat={me.materials[k].name: v for k, v in tri_by_mat.items()},
                       bones=len(arm.data.bones), t_build=round(t1 - t0, 3), t_anim=round(t2 - t1, 3), t_export=round(t3 - t2, 3), size_kb=round(os.path.getsize(path) / 1024, 1))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + '.blend'))
print(json.dumps(stats, indent=1))
json.dump(stats, open(os.path.join(OUT, 'stats.json'), 'w'), indent=1)
