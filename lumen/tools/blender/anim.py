"""anim.py: animacao pose-a-pose escrita em codigo e assada quadro a quadro em Actions.

Cada animacao e uma lista de chaves (quadro, {canal: valor}, easing). Os canais usam
uma semantica de "boneco" em vez de Euler cru, para dar para escrever poses de cabeca:

  tronco  'hips' 'spine' 'chest' 'head'      -> (inclina_frente, gira_esq, tomba_esq)
  braco   'arm.L' / 'arm.R'                  -> (flexao_frente, abre_lado, torce)
  cotovelo 'elbow.L'                          -> dobra  ou (dobra, torce)
  mao     'hand.L'                           -> (sobe, vira, torce)
  perna   'leg.L'                            -> (flexao_frente, abre_lado, torce)
  joelho  'knee.L'                           -> dobra
  pe      'foot.L'                           -> ponta_para_baixo
  posicao '<osso>.pos'                       -> (esquerda, frente, cima) em metros
  escala  '<osso>.scale'                     -> (x, y, z) nos eixos da armature
  cru     qualquer outro osso                -> (rx, ry, rz) graus, eixos da armature

Lados .R sao espelhados automaticamente: os mesmos numeros dao a pose simetrica.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))


def _q(axis, deg):
    return Quaternion(axis, math.radians(deg))


# ------------------------------------------------------------------ easing
def ease(kind, t):
    if kind == 'l':
        return t
    if kind == 'i':      # acelera (chega rapido)
        return t * t * t
    if kind == 'o':      # desacelera
        u = 1 - t
        return 1 - u * u * u
    if kind == 'b':      # passa do ponto e volta
        c1 = 1.70158 * 1.4
        u = t - 1
        return 1 + (c1 + 1) * u * u * u + c1 * u * u
    if kind == 'h':      # segura ate a chave
        return 1.0 if t >= 1.0 else 0.0
    if kind == 's':      # suave forte
        return t * t * t * (t * (6 * t - 15) + 10)
    return t * t * (3 - 2 * t)  # 'io'


# ------------------------------------------------------------------ canais -> ossos
TORSO = ('hips', 'spine', 'chest', 'head')

# canal semantico -> osso real
ALIAS = {'arm': 'upper_arm', 'elbow': 'forearm', 'leg': 'thigh', 'knee': 'shin'}


def split_side(ch):
    if ch.endswith('.L') or ch.endswith('.R'):
        return ch[:-2], ch[-2:]
    return ch, ''


def channel_bone(ch):
    base, side = split_side(ch)
    return ALIAS.get(base, base) + side


def as3(v):
    if isinstance(v, (int, float)):
        return (float(v), 0.0, 0.0)
    v = tuple(float(x) for x in v)
    return v + (0.0,) * (3 - len(v))


def channel_quat(ch, val):
    """Valor semantico -> quaternion nos eixos da armature (relativo ao pai)."""
    base, side = split_side(ch)
    a, b, c = as3(val)
    m = -1.0 if side == '.R' else 1.0
    if base in TORSO:
        return _q(Z, b) @ _q(X, a) @ _q(Y, c)
    if base == 'arm':
        return _q(X, -a) @ _q(Y, m * (90.0 - b)) @ _q(X, c)
    if base == 'elbow':
        return _q(Z, -m * a) @ _q(X, b)
    if base == 'hand':
        return _q(Y, -m * a) @ _q(Z, m * b) @ _q(X, c)
    if base == 'leg':
        return _q(X, -a) @ _q(Y, -m * b) @ _q(Z, m * c)
    if base == 'knee':
        return _q(X, a)
    if base == 'foot':
        return _q(X, a) @ _q(Z, m * b)
    # cru: Euler XYZ espelhado
    return _q(Z, m * c) @ _q(Y, m * b) @ _q(X, a)


class Clip:
    def __init__(self, name, length, keys, loop=False, base=None, ground=True, flat_feet=None):
        """ground: ajusta a altura do quadril para o pe mais baixo encostar no chao
        (o canal 'lift' soma altura por cima). flat_feet: compensa a perna para o pe ficar plano."""
        self.name = name + ('-loop' if loop and not name.endswith('-loop') else '')
        self.length = length
        self.loop = loop
        self.ground = ground
        self.flat_feet = ground if flat_feet is None else flat_feet
        self.tracks = {}
        base = base or {}
        for ch, v in base.items():
            self.tracks.setdefault(ch, []).append((0, as3(v), 'io'))
        seen0 = set()
        for k in keys:
            frame, pose = k[0], k[1]
            e = k[2] if len(k) > 2 else 'io'
            for ch, v in pose.items():
                tr = self.tracks.setdefault(ch, [])
                # chave no mesmo quadro substitui a da base
                tr[:] = [t for t in tr if t[0] != frame]
                tr.append((frame, as3(v), e))
                if frame == 0:
                    seen0.add(ch)
        for ch, tr in self.tracks.items():
            tr.sort(key=lambda t: t[0])
            if ch.endswith('.scale') and tr[0][0] > 0:
                tr.insert(0, (0, (1.0, 1.0, 1.0), 'io'))
            if loop and tr[-1][0] < length:
                tr.append((length, tr[0][1], tr[0][2] if len(tr) < 2 else 'io'))

    def sample(self, ch, frame):
        tr = self.tracks[ch]
        if frame <= tr[0][0]:
            return tr[0][1]
        for (fa, va, _), (fb, vb, eb) in zip(tr, tr[1:]):
            if frame <= fb:
                t = (frame - fa) / float(fb - fa) if fb > fa else 1.0
                t = ease(eb, t)
                return tuple(va[i] + (vb[i] - va[i]) * t for i in range(3))
        return tr[-1][1]


class Rig:
    """Assa Clips numa armature do Blender."""

    def __init__(self, arm_ob, skip=()):
        self.ob = arm_ob
        self.rest = {b.name: b.matrix_local.to_3x3() for b in arm_ob.data.bones}
        self.skip = set(skip)
        for pb in arm_ob.pose.bones:
            pb.rotation_mode = 'QUATERNION'
        if not arm_ob.animation_data:
            arm_ob.animation_data_create()

    def pose_frame(self, clip, frame):
        rot, loc, scl = {}, {}, {}
        vals = {ch: clip.sample(ch, frame) for ch in clip.tracks}
        if clip.flat_feet:
            hp = vals.get('hips', (0, 0, 0))[0]
            for sd in ('.L', '.R'):
                f = vals.get('leg' + sd, (0, 0, 0))[0]
                k = vals.get('knee' + sd, (0, 0, 0))[0]
                u = vals.get('foot' + sd, (0, 0, 0))
                vals['foot' + sd] = (u[0] + f - k - hp, u[1], u[2])
        for ch, v in vals.items():
            if ch == 'lift':
                continue
            if ch.endswith('.pos'):
                loc[channel_bone(ch[:-4])] = Vector((v[0], -v[1], v[2]))
            elif ch.endswith('.scale'):
                scl[channel_bone(ch[:-6])] = Vector(v)
            else:
                rot[channel_bone(ch)] = channel_quat(ch, v)
        return rot, loc, scl

    def bake(self, clip):
        ob = self.ob
        act = bpy.data.actions.new(clip.name)
        ob.animation_data.action = act
        bones = [pb for pb in ob.pose.bones if pb.name not in self.skip]
        for f in range(0, clip.length + 1):
            rot, loc, scl = self.pose_frame(clip, f)
            for pb in bones:
                r = self.rest[pb.name]
                ri = r.inverted()
                q = rot.get(pb.name)
                if q is None:
                    pb.rotation_quaternion = Quaternion()
                else:
                    pb.rotation_quaternion = (ri @ q.to_matrix() @ r).to_quaternion()
                d = loc.get(pb.name)
                pb.location = (ri @ d) if d is not None else Vector()
                s = scl.get(pb.name)
                if s is None:
                    pb.scale = Vector((1, 1, 1))
                else:
                    pb.scale = Vector([abs(r[0][i]) * s[0] + abs(r[1][i]) * s[1] + abs(r[2][i]) * s[2]
                                       for i in range(3)])
            if clip.ground:
                self._fit_ground(clip, f)
            for pb in bones:
                pb.keyframe_insert('rotation_quaternion', frame=f)
                pb.keyframe_insert('location', frame=f)
                pb.keyframe_insert('scale', frame=f)
        tr = ob.animation_data.nla_tracks.new()
        tr.name = clip.name
        st = tr.strips.new(clip.name, 0, act)
        st.name = clip.name
        ob.animation_data.action = None
        tr.mute = True
        return act

    def _fit_ground(self, clip, f):
        ob = self.ob
        bpy.context.view_layer.update()
        low = 1e9
        for sd in ('.L', '.R'):
            pb = ob.pose.bones.get('foot' + sd)
            if pb is None:
                return
            rb = ob.data.bones['foot' + sd]
            low = min(low, pb.head.z - rb.head_local.z, pb.tail.z - rb.tail_local.z)
        lift = clip.sample('lift', f)[0] if 'lift' in clip.tracks else 0.0
        hips = ob.pose.bones['hips']
        r = self.rest['hips']
        hips.location = hips.location + r.inverted() @ Vector((0, 0, -low + lift))

    def bake_all(self, clips):
        for c in clips:
            self.bake(c)
        for pb in self.ob.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
            pb.scale = Vector((1, 1, 1))

    def apply_pose(self, clip, frame):
        """Aplica a pose de um quadro (para previews)."""
        rot, loc, scl = self.pose_frame(clip, frame)
        for pb in self.ob.pose.bones:
            r = self.rest[pb.name]
            ri = r.inverted()
            q = rot.get(pb.name)
            pb.rotation_quaternion = (ri @ q.to_matrix() @ r).to_quaternion() if q else Quaternion()
            d = loc.get(pb.name)
            pb.location = (ri @ d) if d is not None else Vector()
