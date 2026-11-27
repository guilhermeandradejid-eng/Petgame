# Ações por poses-chave: cada chave é uma pose (osso -> r em graus no espaço do esqueleto, l em metros, s escala).
# Os intervalos são preenchidos por slerp com curva de aceleração escolhida por chave (ease) e amostrados
# em degraus (1 quadro nos golpes, 2 quadros no idle e na corrida). Todas as chaves saem CONSTANT a 60 fps:
# o espaçamento é decidido aqui, não pelo interpolador do motor.
import bpy, math
from mathutils import Vector, Matrix, Euler, Quaternion
from bpy_extras.anim_utils import action_get_channelbag_for_slot

def q_arm(rx=0, ry=0, rz=0):
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), 'XYZ').to_quaternion()

def ease(t, kind):
    if kind == 'lin':
        return t
    if kind == 'in':      # acelera (sai devagar)
        return t * t * t
    if kind == 'out':     # desacelera (chega devagar)
        return 1 - (1 - t) ** 3
    if kind == 'io':
        return 3 * t * t - 2 * t * t * t
    if kind == 'snap':    # quase tudo no fim: golpe
        return t ** 5
    if kind == 'hold':
        return 0.0
    if kind == 'out2':
        return 1 - (1 - t) ** 2
    return t

def norm(pose):
    out = {}
    for k, v in pose.items():
        k = k.replace('_L', '.L').replace('_R', '.R').replace('_F', '.F').replace('_B', '.B').replace('_T', '.T')
        out[k] = v
    return out

def P(base=None, **over):
    d = {}
    if base:
        for k, v in base.items():
            d[k] = dict(v)
    for k, v in norm(over).items():
        d[k] = dict(v)
    return d

def M(base, **over):
    """mistura: copia base e soma/sobrepõe só os canais dados (r soma, l soma, s multiplica)."""
    d = {k: dict(v) for k, v in base.items()}
    for k, v in norm(over).items():
        cur = d.setdefault(k, {})
        if 'r' in v:
            r0 = cur.get('r', (0, 0, 0))
            cur['r'] = tuple(a + b for a, b in zip(r0, v['r']))
        if 'l' in v:
            l0 = cur.get('l', (0, 0, 0))
            cur['l'] = tuple(a + b for a, b in zip(l0, v['l']))
        if 's' in v:
            s0 = cur.get('s', (1, 1, 1))
            cur['s'] = tuple(a * b for a, b in zip(s0, v['s']))
    return d

def _get(p, b):
    v = p.get(b, {})
    return (q_arm(*v.get('r', (0, 0, 0))), Vector(v.get('l', (0, 0, 0))), Vector(v.get('s', (1, 1, 1))))

def seq(keys, step=1):
    """keys: [(quadro, pose, ease_até_a_próxima)] -> [(quadro, pose_q)] amostrado de 'step' em 'step' (e sempre nas chaves)."""
    out = []
    bones = set()
    for _, p, _ in keys:
        bones |= set(p.keys())
    for i in range(len(keys) - 1):
        f0, p0, e = keys[i]
        f1, p1, _ = keys[i + 1]
        st = step if not isinstance(e, tuple) else e[1]
        ek = e if not isinstance(e, tuple) else e[0]
        f = f0
        while f < f1:
            t = ease((f - f0) / (f1 - f0), ek)
            fr = {}
            for b in bones:
                q0, l0, s0 = _get(p0, b); q1, l1, s1 = _get(p1, b)
                if q0.dot(q1) < 0:
                    q1 = -q1
                fr[b] = (q0.slerp(q1, t), l0.lerp(l1, t), s0.lerp(s1, t))
            out.append((f, fr))
            f += st
    fl, pl, _ = keys[-1]
    out.append((fl, {b: _get(pl, b) for b in bones}))
    return out

def apply_q(arm, fr):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    for bn, (q, l, s) in fr.items():
        if bn not in arm.pose.bones:
            continue
        pb = arm.pose.bones[bn]
        b = arm.data.bones[bn]
        Bq = b.matrix_local.to_quaternion()
        pb.rotation_quaternion = Bq.inverted() @ q @ Bq
        pb.location = b.matrix_local.to_3x3().inverted() @ l
        # a escala das poses é dada nos eixos do esqueleto (z = vertical); o osso escala nos eixos locais dele
        # (y = ao longo do osso). Converte: cada eixo local recebe a escala do eixo do esqueleto com que se alinha.
        R = b.matrix_local.to_3x3()
        sl = []
        for i in range(3):
            ax = R.col[i]
            sl.append(ax.x * ax.x * s[0] + ax.y * ax.y * s[1] + ax.z * ax.z * s[2])
        pb.scale = sl

def key_action(arm, name, frames):
    act = bpy.data.actions.new(name)
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    for f, fr in frames:
        apply_q(arm, fr)
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
