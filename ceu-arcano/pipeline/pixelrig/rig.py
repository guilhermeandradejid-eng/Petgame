"""Esqueleto 2D, cinemática direta/inversa e correntes com física (cabelo, cachecol, capa).

Ângulos em graus, positivo = horário na tela (y para baixo). Cada osso guarda a posição de
repouso em coordenadas do mundo; as formas de cada parte são desenhadas na pose de repouso,
relativas à junta do osso. Assim, autorar uma parte é desenhar o boneco parado.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field


def rot(v, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (c * v[0] - s * v[1], s * v[0] + c * v[1])


def lerp(a, b, t):
    return a + (b - a) * t


@dataclass
class Bone:
    name: str
    parent: str | None
    pos: tuple  # repouso, mundo


@dataclass
class Xform:
    x: float
    y: float
    angle: float
    scale: float = 1.0

    def apply(self, p):
        q = rot((p[0] * self.scale, p[1] * self.scale), self.angle)
        return (self.x + q[0], self.y + q[1])

    def matrix(self):
        c, s = math.cos(math.radians(self.angle)), math.sin(math.radians(self.angle))
        k = self.scale
        return [[c * k, -s * k, self.x], [s * k, c * k, self.y]]

    def inverse(self):
        c, s = math.cos(math.radians(self.angle)), math.sin(math.radians(self.angle))
        k = 1.0 / self.scale
        # local = R(-a)/k * (w - t)
        return [[c * k, s * k, -(c * self.x + s * self.y) * k],
                [-s * k, c * k, -(-s * self.x + c * self.y) * k]]


class Skeleton:
    def __init__(self, bones):
        self.bones = {b.name: b for b in bones}
        self.order = []
        seen = set()

        def visit(b):
            if b.name in seen:
                return
            if b.parent:
                visit(self.bones[b.parent])
            seen.add(b.name)
            self.order.append(b.name)
        for b in bones:
            visit(b)

    def offset(self, name):
        b = self.bones[name]
        if b.parent is None:
            return b.pos
        p = self.bones[b.parent].pos
        return (b.pos[0] - p[0], b.pos[1] - p[1])

    def solve(self, pose):
        """pose: dict osso -> ângulo; 'root' -> (dx, dy); '<osso>.s' -> escala;
        '<osso>.t' -> (dx, dy) translação extra; 'ik' -> {osso_pé: (x, y, ângulo_pé)}."""
        out = {}
        rx, ry = pose.get("root", (0.0, 0.0))
        for name in self.order:
            b = self.bones[name]
            a = pose.get(name, 0.0)
            if not isinstance(a, (int, float)):
                a = pose.get(name + ".r", 0.0)
            s = pose.get(name + ".s", 1.0)
            tx, ty = pose.get(name + ".t", (0.0, 0.0))
            if b.parent is None:
                out[name] = Xform(b.pos[0] + rx + tx, b.pos[1] + ry + ty, a, s)
            else:
                pt = out[b.parent]
                o = self.offset(name)
                wp = pt.apply(o)
                wa = pose.get(name + ".w")
                ang = (wa + a) if wa is not None else pt.angle + a
                out[name] = Xform(wp[0] + tx, wp[1] + ty, ang, pt.scale * s)
        ik = pose.get("ik")
        if ik:
            for foot, target in ik.items():
                self._ik(out, pose, foot, target)
        return out

    def _ik(self, out, pose, foot, target):
        """IK de dois ossos: foot -> shin -> thigh. target = (x, y[, ângulo do pé no mundo])."""
        shin = self.bones[foot].parent
        thigh = self.bones[shin].parent
        hip = out[thigh]
        l1 = math.dist(self.bones[thigh].pos, self.bones[shin].pos) * hip.scale
        l2 = math.dist(self.bones[shin].pos, self.bones[foot].pos) * hip.scale
        tx, ty = target[0], target[1]
        dx, dy = tx - hip.x, ty - hip.y
        d = max(1e-3, min(l1 + l2 - 1e-3, math.hypot(dx, dy)))
        # ângulo entre coxa e reta quadril->alvo
        cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
        a = math.degrees(math.acos(max(-1.0, min(1.0, cos_a))))
        base = math.degrees(math.atan2(-dx, dy))  # rotação de (0,1) até a direção
        bend = target[3] if len(target) > 3 else 1.0  # +1 joelho para frente (+x)
        thigh_world = base - a * bend
        knee = (hip.x - math.sin(math.radians(thigh_world)) * l1,
                hip.y + math.cos(math.radians(thigh_world)) * l1)
        kdx, kdy = tx - knee[0], ty - knee[1]
        shin_world = math.degrees(math.atan2(-kdx, kdy))
        out[thigh] = Xform(hip.x, hip.y, thigh_world, hip.scale)
        out[shin] = Xform(knee[0], knee[1], shin_world, hip.scale)
        foot_world = target[2] if len(target) > 2 and target[2] is not None else 0.0
        out[foot] = Xform(tx, ty, foot_world + pose.get(foot, 0.0), hip.scale)
        # filhos do pé (dedos etc.)
        for name in self.order:
            b = self.bones[name]
            if b.parent == foot:
                o = self.offset(name)
                wp = out[foot].apply(o)
                out[name] = Xform(wp[0], wp[1], out[foot].angle + pose.get(name, 0.0), out[foot].scale)


# ---------------------------------------------------------------- correntes (física secundária)

@dataclass
class Chain:
    """Corrente Verlet presa a um osso. Vira uma fita afunilada na hora de desenhar."""
    name: str
    bone: str
    anchor: tuple                 # local ao osso
    segments: int
    seg_len: float
    rest_angle: float             # direção de repouso do 1º segmento, relativa ao osso (0 = para baixo)
    curl: float = 0.0             # curvatura de repouso por segmento (graus)
    stiffness: float = 0.25       # quanto volta para a forma de repouso
    damping: float = 0.86
    gravity: float = 0.35
    drag: float = 1.0             # quanto o vento empurra
    radii: list = field(default_factory=list)
    world_rest: bool = False      # direção de repouso no mundo, ignorando a rotação do osso
    min_y: float | None = 2.0     # não atravessa o chão (y mundo)

    def rest_points(self, xf):
        p = xf.apply(self.anchor)
        pts = [p]
        ang = self.rest_angle + (0.0 if self.world_rest else xf.angle)
        for i in range(self.segments):
            d = rot((0.0, self.seg_len * xf.scale), ang + self.curl * i)
            p = (p[0] + d[0], p[1] + d[1])
            pts.append(p)
        return pts


class ChainState:
    def __init__(self, chain, xf):
        self.c = chain
        self.p = chain.rest_points(xf)
        self.prev = list(self.p)

    def step(self, xf, wind=(0.0, 0.0), dt=1.0, root_vel=(0.0, 0.0)):
        c = self.c
        target = c.rest_points(xf)
        self.p[0] = target[0]
        new = [self.p[0]]
        for i in range(1, len(self.p)):
            x, y = self.p[i]
            px, py = self.prev[i]
            vx, vy = (x - px) * c.damping, (y - py) * c.damping
            ax = wind[0] * c.drag
            ay = c.gravity + wind[1] * c.drag
            new.append((x + vx + ax * dt * dt, y + vy + ay * dt * dt))
        self.prev = list(self.p)
        # restrições: comprimento + forma de repouso (relativa ao segmento anterior)
        for _ in range(3):
            for i in range(1, len(new)):
                ax_, ay_ = new[i - 1]
                bx, by = new[i]
                # direção de repouso deste segmento rodada com o anterior
                if i == 1:
                    rd = (target[1][0] - target[0][0], target[1][1] - target[0][1])
                else:
                    prev_rest = (target[i - 1][0] - target[i - 2][0], target[i - 1][1] - target[i - 2][1])
                    cur_rest = (target[i][0] - target[i - 1][0], target[i][1] - target[i - 1][1])
                    prev_now = (new[i - 1][0] - new[i - 2][0], new[i - 1][1] - new[i - 2][1])
                    da = math.atan2(prev_now[1], prev_now[0]) - math.atan2(prev_rest[1], prev_rest[0])
                    rd = rot(cur_rest, math.degrees(da))
                ln = math.hypot(*rd) or 1.0
                seg = c.seg_len * xf.scale
                tx, ty = ax_ + rd[0] / ln * seg, ay_ + rd[1] / ln * seg
                k = c.stiffness * (1.0 if i > 1 else 1.6)
                bx = lerp(bx, tx, min(1.0, k))
                by = lerp(by, ty, min(1.0, k))
                dx, dy = bx - ax_, by - ay_
                dl = math.hypot(dx, dy) or 1e-6
                bx, by = ax_ + dx / dl * seg, ay_ + dy / dl * seg
                if c.min_y is not None and by > c.min_y:
                    by = c.min_y
                new[i] = (bx, by)
        self.p = new
