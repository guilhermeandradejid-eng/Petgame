# Diagnóstico de pose: aplica poses no Blender e imprime posições de mundo de pontos-chave
# (frente = -Y). Uso: python3 posecheck.py heroi
import sys, bpy, importlib
import herois, anims, geo as G
name = sys.argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
F = herois.HEROES[name]()
arm, ob = F.build(name)
pts = {'lamparina': ['hand.R', 'prop.R', 'mola_lanterna', 'head', 'hand.L'], 'bento': ['hand.L', 'mola_balde', 'hand.R', 'prop.R', 'head']}[name]
mod = anims
poses = {k: v for k, v in vars(mod).items() if isinstance(v, dict) and k[:2] in ('L_', 'B_')}
for pn, p in poses.items():
    if (name == 'lamparina') != pn.startswith('L_'):
        continue
    G.apply_pose(arm, p)
    bpy.context.view_layer.update()
    out = []
    for b in pts:
        pb = arm.pose.bones[b]
        h = arm.matrix_world @ pb.head; t = arm.matrix_world @ pb.tail
        out.append(f"{b}: h({h.x:+.2f},{h.y:+.2f},{h.z:+.2f}) t({t.x:+.2f},{t.y:+.2f},{t.z:+.2f})")
    print(pn.ljust(9), ' | '.join(out))
