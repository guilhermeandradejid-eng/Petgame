# Busca a rotação do osso de adereço que leva a ponta para um alvo (relativo à mão), por pose.
import sys, bpy, itertools
from mathutils import Vector
import herois, anims, geo as G
name, pose_name, bone, tipb = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
target = Vector([float(v) for v in sys.argv[5].split(',')]).normalized()
bpy.ops.wm.read_factory_settings(use_empty=True)
F = herois.HEROES[name](); arm, ob = F.build(name)
base = getattr(anims, pose_name)
best = None
for rx in range(-180, 181, 15):
    for rz in range(-180, 181, 15):
        p = G.P_(base, **{bone.replace('.', '_'): {'r': (rx, 0, rz)}})
        G.apply_pose(arm, p); bpy.context.view_layer.update()
        h = arm.matrix_world @ arm.pose.bones[bone].head
        t = arm.matrix_world @ arm.pose.bones[tipb].head
        d = (t - h).normalized()
        sc = d.dot(target)
        if best is None or sc > best[0]:
            best = (sc, rx, rz, tuple(round(c, 2) for c in t))
print('BEST', pose_name, best)
