// Carro: física arcade 2D no plano (com altura para rampas/pulos), destroço 3D, visual com suspensão e IA.
import * as THREE from 'three';
import { LANES_FWD, LANES_ONC } from './track.js';

const TAU = Math.PI * 2;
export const wrap = (a) => { a = (a + Math.PI) % TAU; if (a < 0) a += TAU; return a - Math.PI; };
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const rand = (a, b) => a + Math.random() * (b - a);

// atributos por modelo
export const SPECS = {
  faisca: { len: 3.7, wid: 2.0, mass: 1.0, vmax: 40, boostV: 57, accel: 27, grip: 9.5, driftGrip: 1.7, turn: 2.75, wr: 0.5 },
  trovao: { len: 4.1, wid: 2.1, mass: 1.25, vmax: 39, boostV: 52, accel: 25, grip: 8.5, driftGrip: 1.8, turn: 2.5, wr: 0.5 },
  vespa: { len: 3.4, wid: 2.0, mass: 0.95, vmax: 38, boostV: 52, accel: 27, grip: 9.0, driftGrip: 1.8, turn: 2.8, wr: 0.55 },
  sedan: { len: 3.9, wid: 1.95, mass: 1.0, vmax: 26, boostV: 26, accel: 12, grip: 8, driftGrip: 2, turn: 2.2, wr: 0.44 },
  taxi: { len: 3.9, wid: 1.95, mass: 1.0, vmax: 26, boostV: 26, accel: 12, grip: 8, driftGrip: 2, turn: 2.2, wr: 0.44 },
  policia: { len: 3.9, wid: 1.95, mass: 1.1, vmax: 30, boostV: 30, accel: 14, grip: 8, driftGrip: 2, turn: 2.2, wr: 0.44 },
  picape: { len: 4.3, wid: 2.1, mass: 1.5, vmax: 24, boostV: 24, accel: 10, grip: 8, driftGrip: 2, turn: 2.0, wr: 0.52 },
  van: { len: 4.4, wid: 2.1, mass: 1.8, vmax: 22, boostV: 22, accel: 9, grip: 8, driftGrip: 2, turn: 1.9, wr: 0.46 },
};

export class Car {
  constructor(assets, kind, role, color) {
    this.kind = kind;
    this.role = role;           // 'player' | 'rival' | 'traffic'
    Object.assign(this, SPECS[kind]);
    this.inertia = this.mass * (this.len * this.len + this.wid * this.wid) / 12;
    this.r = this.wid * 0.5;
    this.k = this.len / 2 - this.r;   // offset dos círculos de colisão
    this.reset(0, 0, 0);
    this.ctrl = { steer: 0, throttle: 0, brake: 0, drift: false, boost: false, dir: null, dirMag: 0 };
    this.boost = role === 'player' ? 0.35 : 1;
    this.color = new THREE.Color(color);
    this.buildVisual(assets);
  }

  reset(x, z, heading, speed = 0) {
    this.x = x; this.z = z; this.y = 0; this.vy = 0;
    this.h = heading;
    this.vx = Math.sin(heading) * speed; this.vz = Math.cos(heading) * speed;
    this.omega = 0;
    this.onGround = true; this.airT = 0;
    this.drifting = false; this.driftDir = 0; this.driftT = 0; this.driftSlip = 0;
    this.steerS = 0;
    this.stun = 0;
    this.vF = speed; this.vS = 0; this.prevVF = speed;
    this.boosting = false;
    this.wrecked = false; this.wreckT = 0;
    this.invuln = 0;
    this.lastHitBy = null; this.lastHitT = -10;
  }

  // ------------------------------------------------------------ visual
  buildVisual(assets) {
    const src = assets.getObjectByName('car_' + this.kind);
    const model = src.clone(true);
    model.position.set(0, 0, 0);
    this.group = new THREE.Group();        // posição + yaw
    this.tilt = new THREE.Group();         // inclinação no ar / rampa / capotagem
    this.pivot = new THREE.Group();        // suspensão (só a carroceria)
    this.pivot.position.y = 0.7;
    this.group.add(this.tilt);
    this.tilt.add(this.pivot);
    this.wheels = [];
    this.paint = null; this.tailMat = null; this.headMat = null;
    const mats = new Map();
    const fix = (m) => {
      if (mats.has(m)) return mats.get(m);
      let c = m;
      if (m.name === 'Paint') { c = m.clone(); c.color.copy(this.color); this.paint = c; }
      else if (m.name === 'Taillight') { c = m.clone(); this.tailMat = c; }
      else if (m.name === 'Headlight') { c = m.clone(); this.headMat = c; }
      else if (m.name === 'SirenR' || m.name === 'SirenB') { c = m.clone(); (this.sirens ||= []).push(c); }
      mats.set(m, c);
      return c;
    };
    const kids = [...model.children];
    for (const ch of kids) {
      ch.traverse((o) => {
        if (o.isMesh) {
          o.castShadow = true; o.receiveShadow = false;
          o.material = Array.isArray(o.material) ? o.material.map(fix) : fix(o.material);
        }
      });
      if (/_w(FL|FR|RL|RR)$/.test(ch.name)) {
        ch.rotation.order = 'YXZ';
        const front = ch.position.z > 0;
        this.wheels.push({ mesh: ch, front, x: ch.position.x, z: ch.position.z, r: ch.position.y, spin: 0, last: null });
        this.tilt.add(ch);
      } else {
        // corpo: pendurado no pivô da suspensão
        ch.position.y -= 0.7;
        this.pivot.add(ch);
        this.body = ch;
      }
    }
    // suspensão (molas)
    this.sp = { pitch: 0, pv: 0, roll: 0, rv: 0, heave: 0, hv: 0 };
    this.airPitch = 0;
    this.q = new THREE.Quaternion();
  }

  // ------------------------------------------------------------ física
  step(dt, track) {
    if (this.wrecked) { this.stepWreck(dt, track); return; }
    const c = this.ctrl;
    this.invuln = Math.max(0, this.invuln - dt);
    this.stun = Math.max(0, this.stun - dt);
    let sin = Math.sin(this.h), cos = Math.cos(this.h);
    let vF = this.vx * sin + this.vz * cos;
    let vS = this.vx * cos - this.vz * sin;      // >0: deslizando para a esquerda

    // direção: analógico de tela vira um alvo de rumo
    let steer = c.steer;
    if (c.dir) {
      const target = Math.atan2(c.dir.x, c.dir.z);
      const d = wrap(target - this.h);
      steer = clamp(d * 2.4, -1, 1) * c.dirMag;
      if (vF < -2) steer = -steer;
    }
    this.steerS += (steer - this.steerS) * Math.min(1, dt * 14);
    const ground = this.onGround;
    const spd01 = Math.min(1, Math.abs(vF) / this.vmax);

    // ----- drift
    if (!this.drifting && ground && c.drift && vF > 11 && Math.abs(this.steerS) > 0.2) {
      this.drifting = true; this.driftDir = Math.sign(this.steerS); this.driftT = 0;
      this.omega += this.driftDir * 1.1;
      this.onDriftStart?.();
    }
    if (this.drifting) {
      this.driftT += dt;
      const slip = Math.abs(Math.atan2(vS, Math.max(1, vF)));
      this.driftSlip = slip;
      const holding = c.drift || this.steerS * this.driftDir > 0.25;
      if (vF < 7 || !ground || (this.driftT > 0.35 && slip < 0.1 && !holding) || (this.driftT > 0.2 && slip < 0.05)) {
        this.drifting = false;
        this.onDriftEnd?.(this.driftT);
      }
    } else this.driftSlip = 0;

    // ----- rotação (guinada)
    const auth = this.stun > 0 ? 0.25 : 1;
    if (ground) {
      let target;
      if (this.drifting) {
        target = (this.steerS * 1.25 + this.driftDir * 0.55) * this.turn * 0.95;
      } else {
        const rate = this.turn * Math.min(1, Math.abs(vF) / 5) * (1 - 0.32 * spd01);
        target = this.steerS * rate * Math.sign(vF || 1);
      }
      this.omega += (target - this.omega) * Math.min(1, dt * (this.drifting ? 5 : 9) * auth);
    } else {
      this.omega *= Math.exp(-0.6 * dt);
    }
    this.h += this.omega * dt;
    sin = Math.sin(this.h); cos = Math.cos(this.h);
    // a velocidade fica para trás quando o carro gira (é isso que gera o deslize)
    vF = this.vx * sin + this.vz * cos;
    vS = this.vx * cos - this.vz * sin;

    // ----- turbo
    this.boosting = c.boost && this.boost > 0.01 && vF > 2;
    const vmaxNow = this.boosting ? this.boostV : this.vmax;
    if (this.boosting && this.role === 'player') this.boost = Math.max(0, this.boost - dt * 0.3);

    if (ground) {
      // ----- longitudinal
      if (c.throttle > 0 && !(c.brake && vF > 1)) {
        if (vF < vmaxNow) {
          const f = Math.max(0.12, 1 - (vF / vmaxNow) ** 2);
          vF += this.accel * (this.boosting ? 1.7 : 1) * c.throttle * f * dt;
        } else vF -= (vF - vmaxNow) * 1.2 * dt;
      } else if (!c.brake) {
        vF -= Math.sign(vF) * Math.min(Math.abs(vF), 4 * dt) + vF * 0.08 * dt;
      }
      if (c.brake) {
        if (vF > 0.5) vF -= (this.drifting ? 8 : 32) * dt;
        else if (vF > -12) vF -= 16 * dt;
      }
      if (this.drifting) vF -= vF * 0.1 * dt;
      // ----- lateral (aderência)
      let grip = this.drifting ? this.driftGrip : this.grip;
      if (this.stun > 0) grip *= 0.25;
      const keep = Math.exp(-grip * dt);
      const lost = vS * (1 - keep);
      vS *= keep;
      // no drift parte da velocidade lateral vira velocidade para frente (mantém o embalo)
      if (this.drifting) vF += Math.abs(lost) * 0.35;
      this.vx = sin * vF + cos * vS;
      this.vz = cos * vF - sin * vS;
    } else {
      if (this.boosting) { this.vx += sin * 10 * dt; this.vz += cos * 10 * dt; }
    }
    this.prevVF = this.vF;
    this.vF = vF; this.vS = vS;

    this.x += this.vx * dt;
    this.z += this.vz * dt;

    // ----- vertical (rampas e pulos)
    const g = track.groundAt(this.x, this.z);
    if (this.onGround) {
      if (g.h >= this.y - 0.3) {
        this.vy = clamp((g.h - this.y) / dt, -5, 25);
        this.y = g.h;
        this.slope = g.slope;
      } else {
        this.onGround = false; this.airT = 0;
        this.onTakeoff?.();
      }
    } else {
      this.vy -= 30 * dt;
      this.y += this.vy * dt;
      this.airT += dt;
      if (this.y <= g.h) {
        const impact = -this.vy;
        this.y = g.h; this.vy = 0; this.onGround = true;
        this.sp.hv -= Math.min(6, impact * 0.25);
        this.sp.pv += 1.5;
        this.onLand?.(this.airT, impact);
      }
    }
  }

  // empurra o carro (impulso j na direção n, no ponto de contato p)
  impulse(px, pz, nx, nz, j) {
    this.vx += (j * nx) / this.mass;
    this.vz += (j * nz) / this.mass;
    const rx = px - this.x, rz = pz - this.z;
    this.omega += (rz * nx * j - rx * nz * j) / this.inertia;
  }

  pointVel(px, pz) {
    const rx = px - this.x, rz = pz - this.z;
    return [this.vx + this.omega * rz, this.vz - this.omega * rx];
  }

  circle(i) {
    const o = (i - 1) * this.k;
    return [this.x + Math.sin(this.h) * o, this.z + Math.cos(this.h) * o];
  }

  // ------------------------------------------------------------ destroço (capotando)
  wreck(power, nx, nz) {
    if (this.wrecked) return;
    this.wrecked = true; this.wreckT = 0;
    this.drifting = false; this.boosting = false;
    const p = clamp(power / 30, 0.4, 1.5);
    this.wy = this.y + 0.75;
    this.wvy = 7 + p * 7;
    // gira principalmente em torno do eixo longitudinal (capota) e um pouco de guinada
    const sin = Math.sin(this.h), cos = Math.cos(this.h);
    const side = Math.sign((nx * cos - nz * sin) || (Math.random() - 0.5));
    this.wav = new THREE.Vector3(rand(-3, 3) * p, (this.omega + rand(-4, 4)) * p, side * rand(6, 11) * p);
    this.wav.applyAxisAngle(new THREE.Vector3(0, 1, 0), this.h);
    this.q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), this.h);
    this.vx += nx * 6; this.vz += nz * 6;
  }

  stepWreck(dt, track) {
    this.wreckT += dt;
    this.wvy -= 28 * dt;
    this.wy += this.wvy * dt;
    this.x += this.vx * dt; this.z += this.vz * dt;
    // integra rotação
    const w = this.wav, ang = w.length() * dt;
    if (ang > 1e-5) {
      const dq = new THREE.Quaternion().setFromAxisAngle(w.clone().normalize(), ang);
      this.q.premultiply(dq);
    }
    const floor = 0.6;
    this.bounced = 0;
    if (this.wy < floor) {
      this.wy = floor;
      if (this.wvy < -2) this.bounced = -this.wvy;
      this.wvy = -this.wvy * 0.32;
      this.vx *= 0.82; this.vz *= 0.82;
      this.wav.multiplyScalar(0.72);
      if (Math.abs(this.wvy) < 1.5) this.wvy = 0;
    }
    if (this.wy <= floor + 0.01) {
      const f = Math.exp(-2.2 * dt);
      this.vx *= f; this.vz *= f; this.wav.multiplyScalar(Math.exp(-2.5 * dt));
      // tende a parar de lado ou de cabeça pra baixo: endireita devagar
    }
    this.h = Math.atan2(2 * (this.q.w * this.q.y + this.q.x * this.q.z), 1 - 2 * (this.q.y * this.q.y + this.q.x * this.q.x));
    this.omega = 0;
    this.y = this.wy - 0.75;
  }

  // ------------------------------------------------------------ IA
  ai(track, game, dt) {
    const c = this.ctrl;
    const pr = track.project(this.x, this.z, this.ti ?? -1);
    this.ti = pr.i; this.lat = pr.lat;
    const dir = this.oncoming ? -1 : 1;
    const look = 5 + Math.max(0, this.vF) * 0.42;
    this.laneT = this.laneT ?? this.lane;
    // muda de faixa suavemente
    this.laneCur = this.laneCur ?? this.lane;
    this.laneCur += clamp(this.laneT - this.laneCur, -dt * 4, dt * 4);
    const tp = track.at(pr.s + look * dir, this.laneCur);
    const desired = Math.atan2(tp.x - this.x, tp.z - this.z);
    c.dir = null;
    c.steer = clamp(wrap(desired - this.h) * 2.2, -1, 1);
    c.drift = false;

    let want = this.cruise;
    if (this.role === 'rival') {
      // freia para curvas fechadas à frente
      let maxC = 0;
      for (let k = 2; k < 22; k += 2) maxC = Math.max(maxC, Math.abs(track.curv[track.idx(pr.i + k)]));
      const lim = Math.sqrt(30 / Math.max(maxC, 1e-4));
      want = Math.min(this.cruise * this.rubber, lim);
      // turbo nas retas
      c.boost = maxC < 0.012 && this.vF > 25 && Math.sin(game.time * 0.7 + this.seed) > 0.1;
      if (c.boost) want = this.boostV;
      // agressividade: encosta no jogador
      const p = game.player;
      if (!p.wrecked && !this.wrecked) {
        const dx = p.x - this.x, dz = p.z - this.z, d = Math.hypot(dx, dz);
        if (d < 9 && game.time > this.nextBash) {
          this.laneT = clamp(p.lat ?? this.laneT, -9, 9);
          this.nextBash = game.time + rand(3, 6);
        }
      }
    }
    // evita bater em quem está à frente na mesma faixa
    let blocked = null;
    for (const o of game.cars) {
      if (o === this || o.wrecked) continue;
      const dx = o.x - this.x, dz = o.z - this.z;
      const fwd = dx * Math.sin(this.h) + dz * Math.cos(this.h);
      const side = dx * Math.cos(this.h) - dz * Math.sin(this.h);
      if (fwd > 0 && fwd < 10 + this.vF * 0.5 && Math.abs(side) < 2.4) {
        if (!blocked || fwd < blocked.fwd) blocked = { fwd, o };
      }
    }
    if (blocked) {
      if (this.role === 'rival') {
        if (game.time > (this.laneSwitchT || 0)) {
          const opts = this.lat < 0 ? [-2.75, -8.25, 2.75] : [-2.75, -8.25];
          this.laneT = opts.reduce((b, l) => (Math.abs(l - blocked.o.lat) > Math.abs(b - blocked.o.lat) ? l : b), opts[0]);
          this.laneSwitchT = game.time + 1.2;
        }
      } else if (blocked.o.role !== 'player') {
        want = Math.min(want, Math.max(0, blocked.o.vF) * 0.9);
      }
    } else if (this.role === 'rival' && game.time > (this.laneSwitchT || 0) && this.laneT > 0) {
      this.laneT = LANES_FWD[Math.floor(this.seed) % 2];
    }
    c.throttle = this.vF < want ? 1 : 0;
    c.brake = this.vF > want + 3 ? 1 : 0;
    if (this.role === 'traffic') this.boost = 1;
  }

  // ------------------------------------------------------------ visual por frame
  updateVisual(dt, time) {
    const g = this.group;
    if (this.wrecked) {
      g.position.set(this.x, this.wy, this.z);
      g.quaternion.copy(this.q);
      g.rotation.order = 'XYZ';
      this.tilt.rotation.set(0, 0, 0);
      this.tilt.position.y = -0.75;
      this.pivot.rotation.set(0, 0, 0);
      return;
    }
    this.tilt.position.y = 0;
    g.position.set(this.x, this.y, this.z);
    g.quaternion.setFromAxisAngle(_up, this.h);
    // inclinação no ar e na rampa
    let targetPitch = 0;
    if (!this.onGround) targetPitch = -Math.atan2(this.vy, Math.max(8, Math.abs(this.vF))) * 0.8;
    else if (this.slope) targetPitch = -Math.atan(this.slope) * (this.y > 0.02 ? 1 : 0);
    this.airPitch += (targetPitch - this.airPitch) * Math.min(1, dt * (this.onGround ? 18 : 4));
    this.tilt.rotation.x = this.airPitch;

    // suspensão
    const dv = dt > 0 ? (this.vF - this.prevVF) / Math.max(dt, 1e-3) : 0;
    const latA = this.vF * this.omega;
    const sp = this.sp;
    const pitchT = clamp(-dv * 0.005, -0.09, 0.09);
    const rollT = clamp(latA * 0.0035 * (this.drifting ? 1.6 : 1), -0.14, 0.14);
    sp.pv += ((pitchT - sp.pitch) * 160 - sp.pv * 14) * dt; sp.pitch += sp.pv * dt;
    sp.rv += ((rollT - sp.roll) * 140 - sp.rv * 12) * dt; sp.roll += sp.rv * dt;
    sp.hv += ((0 - sp.heave) * 180 - sp.hv * 13) * dt; sp.heave += sp.hv * dt;
    this.pivot.rotation.x = sp.pitch;
    this.pivot.rotation.z = sp.roll;
    this.pivot.position.y = 0.7 + sp.heave * 0.12;
    // squash & stretch leve no pouso
    const sq = clamp(-sp.heave * 0.06, -0.08, 0.1);
    this.pivot.scale.set(1 + sq * 0.6, 1 - sq, 1 + sq * 0.6);

    // rodas
    for (const w of this.wheels) {
      w.spin += (this.vF / (w.r || 0.5)) * dt * (this.onGround || this.ctrl.throttle ? 1 : 0.6);
      let steerV = 0;
      if (w.front) steerV = this.drifting ? -this.driftDir * 0.35 + this.steerS * 0.2 : this.steerS * 0.42;
      w.mesh.rotation.set(w.spin, steerV, 0);
    }
    // luzes
    if (this.tailMat) this.tailMat.emissiveIntensity = this.ctrl.brake ? 5 : this.boosting ? 3 : 1.4;
    if (this.headMat) this.headMat.emissiveIntensity = 2.2;
    if (this.sirens) {
      const on = Math.sin(time * 14) > 0;
      this.sirens[0].emissiveIntensity = on ? 6 : 0.3;
      if (this.sirens[1]) this.sirens[1].emissiveIntensity = on ? 0.3 : 6;
    }
    // pisca quando invulnerável
    g.visible = this.invuln <= 0 || Math.floor(time * 16) % 2 === 0;
  }

  // posição no mundo de um ponto local (x direita?, y, z frente)
  local(lx, ly, lz, out) {
    const s = Math.sin(this.h), c = Math.cos(this.h);
    out.x = this.x + lx * c + lz * s;
    out.y = this.y + ly;
    out.z = this.z - lx * s + lz * c;
    return out;
  }
}
const _up = new THREE.Vector3(0, 1, 0);
