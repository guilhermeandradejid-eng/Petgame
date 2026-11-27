# Busca a rotação do rodo (prop.R) para apoiá-lo no ombro na pose de contraposto do Bento.
import sys, bpy
from mathutils import Vector
import herois, anims, geo as G
bpy.ops.wm.read_factory_settings(use_empty=True)
F = herois.HEROES['bento'](); arm, ob = F.build('bento')
base = anims.B_IDLE
best = None
for rx in range(-180, 181, 10):
    for ry in range(-90, 91, 15):
        for rz in range(-180, 181, 15):
            p = G.P_(base, prop_R={'r': (rx, ry, rz)})
            G.apply_pose(arm, p); bpy.context.view_layer.update()
            pb = arm.pose.bones['prop.R']
            h = arm.matrix_world @ pb.head; t = arm.matrix_world @ pb.tail
            d = (t - h).normalized()
            sh = arm.matrix_world @ arm.pose.bones['upperarm.R'].head
            # o cabo (lado do rodo, -d... d aponta para o rodo) deve passar pelo ombro: ponto mais próximo
            v = sh - h; s = v.dot(d); dist = (v - d * s).length
            goal = d.z > 0.45 and d.y > 0.15 and s > 0.05
            sc = -dist + (0.5 if goal else 0) + 0.2 * d.y
            if best is None or sc > best[0]:
                best = (round(sc, 3), rx, ry, rz, tuple(round(c, 2) for c in h), tuple(round(c, 2) for c in d), round(dist, 3), round(s, 2))
print('BEST', best)
