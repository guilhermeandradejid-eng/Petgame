# Poses e ações (chaves CONSTANT a 60 fps), quadro de borrão (smear) gerado a partir da própria ação
# e teste automático de colisão do adereço (corpo e chão).
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler, Quaternion
from bpy_extras.anim_utils import action_get_channelbag_for_slot
from malha import *

def pose_q(arm, bone, rx=0, ry=0, rz=0):
    b = arm.data.bones[bone]
    R = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_quaternion()
    Bq = b.matrix_local.to_quaternion()
    return Bq.inverted() @ R @ Bq

def apply_pose(arm, pose):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    for bn, v in pose.items():
        if bn not in arm.pose.bones:
            continue
        pb = arm.pose.bones[bn]
        if 'r' in v:
            pb.rotation_quaternion = pose_q(arm, bn, *v['r'])
        if 'l' in v:
            b = arm.data.bones[bn]
            pb.location = b.matrix_local.to_3x3().inverted() @ Vector(v['l'])
        if 's' in v:
            pb.scale = v['s']
    if 'smear' in arm.pose.bones:
        on = pose.get('_smear', False)
        arm.pose.bones['smear'].scale = (1, 1, 1) if on else (0.001, 0.001, 0.001)

def P_(base, **over):
    d = {k: dict(v) if isinstance(v, dict) else v for k, v in base.items()}
    for k, v in over.items():
        k = k.replace('_L', '.L').replace('_R', '.R').replace('_F', '.F').replace('_B', '.B')
        d[k] = v
    return d

def key_action(arm, name, frames):
    act = bpy.data.actions.new(name)
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    for f, pose in frames:
        apply_pose(arm, pose)
        for pb in arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=f)
            pb.keyframe_insert('location', frame=f)
            pb.keyframe_insert('scale', frame=f)
    for slot in act.slots:
        cb = action_get_channelbag_for_slot(act, slot)
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'CONSTANT'
    act.use_fake_user = True
    return act

def finish_actions(arm, acts):
    for act in acts:
        tr = arm.animation_data.nla_tracks.new(); tr.name = act.name
        tr.strips.new(act.name, 1, act)
    arm.animation_data.action = None

def bone_mat(arm, bname, frame):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    return arm.pose.bones[bname].matrix.copy()

def build_smear(arm, ob_name, S, act, f_from, f_smear, kind, col_main, col_tip):
    """Malha de borrão para 1 quadro: o adereço varrido em arco entre a pose anterior e a de contato,
    ligada ao osso 'smear' (que só tem escala 1 no quadro do smear)."""
    arm.animation_data.action = act
    M0 = bone_mat(arm, 'prop', f_from)
    M1 = bone_mat(arm, 'prop', f_smear)
    Ms = bone_mat(arm, 'smear', f_smear)
    rest = arm.data.bones['smear'].matrix_local
    hc, d, side, L, r = S['_prop_head']
    prop_rest = arm.data.bones['prop'].matrix_local
    # pontos do adereço em espaço local do osso (em repouso)
    loc_head = prop_rest.inverted() @ hc
    loc_side = (prop_rest.inverted().to_3x3() @ side).normalized()
    loc_d = (prop_rest.inverted().to_3x3() @ d).normalized()
    q0, q1 = M0.to_quaternion(), M1.to_quaternion()
    t0, t1 = M0.translation, M1.translation
    N = 14
    centers, axes, dirs = [], [], []
    U0 = 0.4
    for i in range(N + 1):
        u = U0 + (1 - U0) * i / N
        q = q0.slerp(q1, u)
        Mi = Matrix.Translation(t0.lerp(t1, u)) @ q.to_matrix().to_4x4()
        centers.append(Mi @ loc_head)
        axes.append((Mi.to_3x3() @ loc_side).normalized())
        dirs.append((Mi.to_3x3() @ loc_d).normalized())
    # leva para o espaço de repouso do osso smear: v_rest = rest @ Ms^-1 @ v_pose
    K = rest @ Ms.inverted()
    bm = bmesh.new()
    rings = []
    for i, c in enumerate(centers):
        u = i / N
        tg = (centers[min(i + 1, N)] - centers[max(i - 1, 0)]).normalized()
        a = axes[i]
        b = tg.cross(a).normalized()
        w = (0.15 + 0.85 * u ** 1.6)
        ring = []
        M_ = 10
        for j in range(M_):
            th = 2 * math.pi * j / M_
            if kind == 'macete':
                p = c + a * math.cos(th) * (L * 0.5) * (0.6 + 0.4 * w) + b * math.sin(th) * r * w
            else:
                p = c + a * math.cos(th) * (L * 0.5) * (0.5 + 0.5 * w) + b * math.sin(th) * r * w
            ring.append(bm.verts.new(K @ p))
        rings.append(ring)
    for i in range(N):
        for j in range(10):
            bm.faces.new([rings[i][j], rings[i][(j + 1) % 10], rings[i + 1][(j + 1) % 10], rings[i + 1][j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # cabo varrido (leque fino)
    fan = bmesh.new()
    hand_l = prop_rest.inverted() @ (hc - d * (0.72 if kind == 'macete' else 0.9))
    prev = None
    for i in range(N + 1):
        u = U0 + (1 - U0) * i / N
        q = q0.slerp(q1, u)
        Mi = Matrix.Translation(t0.lerp(t1, u)) @ q.to_matrix().to_4x4()
        hand_l2 = hand_l.lerp(loc_head, 0.72)
        p0 = K @ (Mi @ hand_l2); p1 = K @ (Mi @ (loc_head - loc_d * 0.1))
        v0, v1 = fan.verts.new(p0), fan.verts.new(p1)
        if prev:
            fan.faces.new([prev[0], prev[1], v1, v0])
        prev = (v0, v1)
    bmesh.ops.solidify(fan, geom=fan.faces[:], thickness=0.02)
    return bm, fan

def collision_report(arm, S, act, frames, body_r, body_z0, body_z1):
    """Em cada quadro do golpe, o adereço não pode entrar na cápsula do corpo nem passar do chão."""
    arm.animation_data.action = act
    prop_rest = arm.data.bones['prop'].matrix_local
    pts = [prop_rest.inverted() @ p for p in S['_prop_pts']]
    worst_floor, worst_body = 9, 9
    bad = []
    for f in frames:
        M = bone_mat(arm, 'prop', f)
        Mr = arm.pose.bones['root'].matrix
        for p in pts:
            w = M @ p
            wl = Mr.inverted() @ w
            worst_floor = min(worst_floor, w.z)
            if body_z0 < wl.z < body_z1:
                dxy = math.hypot(wl.x, wl.y)
                worst_body = min(worst_body, dxy - body_r)
                if dxy < body_r:
                    bad.append((f, 'corpo', round(dxy - body_r, 3)))
            if w.z < -0.01:
                bad.append((f, 'chão', round(w.z, 3)))
    return dict(min_altura_adereco=round(worst_floor, 3), folga_min_corpo=round(worst_body, 3), violacoes=bad[:12], n_violacoes=len(bad))
