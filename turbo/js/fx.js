// Game juice: partículas, marcas de pneu, rastros de turbo, detritos, tremor de câmera e pós-processamento.
import * as THREE from 'three';
import { EffectComposer } from '../../vendor/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from '../../vendor/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from '../../vendor/jsm/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from '../../vendor/jsm/postprocessing/ShaderPass.js';
import { OutputPass } from '../../vendor/jsm/postprocessing/OutputPass.js';

const rand = (a, b) => a + Math.random() * (b - a);

// ---------------------------------------------------------------- partículas (Points com shader próprio)
export class Particles {
  constructor(scene, max, additive) {
    this.max = max;
    this.count = 0;
    this.p = new Float32Array(max * 3);
    this.v = new Float32Array(max * 3);
    this.col = new Float32Array(max * 3);
    this.c0 = new Float32Array(max * 3);
    this.c1 = new Float32Array(max * 3);
    this.size = new Float32Array(max);
    this.s0 = new Float32Array(max); this.s1 = new Float32Array(max);
    this.alpha = new Float32Array(max);
    this.life = new Float32Array(max); this.maxLife = new Float32Array(max);
    this.drag = new Float32Array(max); this.grav = new Float32Array(max);
    this.a0 = new Float32Array(max);
    const geo = new THREE.BufferGeometry();
    this.aPos = new THREE.BufferAttribute(this.p, 3).setUsage(THREE.DynamicDrawUsage);
    this.aCol = new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage);
    this.aSize = new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage);
    this.aAlpha = new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage);
    geo.setAttribute('position', this.aPos);
    geo.setAttribute('color', this.aCol);
    geo.setAttribute('size', this.aSize);
    geo.setAttribute('alpha', this.aAlpha);
    geo.setDrawRange(0, 0);
    this.mat = new THREE.ShaderMaterial({
      uniforms: { uPx: { value: 20 } },
      vertexShader: `
        attribute float size; attribute float alpha; attribute vec3 color;
        varying vec3 vC; varying float vA; uniform float uPx;
        void main(){ vC = color; vA = alpha;
          vec4 mv = modelViewMatrix * vec4(position,1.0);
          gl_Position = projectionMatrix * mv;
          gl_PointSize = size * uPx; }`,
      fragmentShader: additive ? `
        varying vec3 vC; varying float vA;
        void main(){ vec2 d = gl_PointCoord - 0.5; float r = length(d);
          float a = smoothstep(0.5, 0.0, r); a *= a;
          gl_FragColor = vec4(vC * (1.0 + 2.0*smoothstep(0.25,0.0,r)), a * vA); }` : `
        varying vec3 vC; varying float vA;
        void main(){ vec2 d = gl_PointCoord - 0.5; float r = length(d);
          float a = smoothstep(0.5, 0.32, r);
          float shade = 0.82 + 0.25 * (0.5 - d.y - d.x*0.3);
          gl_FragColor = vec4(vC * shade, a * vA); }`,
      transparent: true,
      depthWrite: false,
      blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
    });
    this.points = new THREE.Points(geo, this.mat);
    this.points.frustumCulled = false;
    this.points.renderOrder = additive ? 3 : 2;
    scene.add(this.points);
  }

  // o: {x,y,z, vx,vy,vz, life, size, size1, color, color1, alpha, drag, grav}
  emit(o) {
    let i = this.count < this.max ? this.count++ : Math.floor(Math.random() * this.max);
    const i3 = i * 3;
    this.p[i3] = o.x; this.p[i3 + 1] = o.y; this.p[i3 + 2] = o.z;
    this.v[i3] = o.vx || 0; this.v[i3 + 1] = o.vy || 0; this.v[i3 + 2] = o.vz || 0;
    const c = o.color, c1 = o.color1 || o.color;
    this.c0[i3] = c.r; this.c0[i3 + 1] = c.g; this.c0[i3 + 2] = c.b;
    this.c1[i3] = c1.r; this.c1[i3 + 1] = c1.g; this.c1[i3 + 2] = c1.b;
    this.s0[i] = o.size; this.s1[i] = o.size1 ?? o.size;
    this.life[i] = 0; this.maxLife[i] = o.life;
    this.a0[i] = o.alpha ?? 1;
    this.drag[i] = o.drag ?? 1.5; this.grav[i] = o.grav ?? 0;
  }

  update(dt) {
    let n = this.count;
    for (let i = 0; i < n; i++) {
      this.life[i] += dt;
      if (this.life[i] >= this.maxLife[i]) {
        // troca com o último vivo
        n--;
        this.copy(n, i);
        i--;
        continue;
      }
      const i3 = i * 3, t = this.life[i] / this.maxLife[i];
      const dr = Math.exp(-this.drag[i] * dt);
      this.v[i3] *= dr; this.v[i3 + 1] = this.v[i3 + 1] * dr - this.grav[i] * dt; this.v[i3 + 2] *= dr;
      this.p[i3] += this.v[i3] * dt; this.p[i3 + 1] += this.v[i3 + 1] * dt; this.p[i3 + 2] += this.v[i3 + 2] * dt;
      if (this.p[i3 + 1] < 0.03 && this.grav[i] > 0) { this.p[i3 + 1] = 0.03; this.v[i3 + 1] *= -0.4; this.v[i3] *= 0.6; this.v[i3 + 2] *= 0.6; }
      this.col[i3] = this.c0[i3] + (this.c1[i3] - this.c0[i3]) * t;
      this.col[i3 + 1] = this.c0[i3 + 1] + (this.c1[i3 + 1] - this.c0[i3 + 1]) * t;
      this.col[i3 + 2] = this.c0[i3 + 2] + (this.c1[i3 + 2] - this.c0[i3 + 2]) * t;
      this.size[i] = this.s0[i] + (this.s1[i] - this.s0[i]) * t;
      this.alpha[i] = this.a0[i] * (t < 0.1 ? t / 0.1 : 1 - (t - 0.1) / 0.9);
    }
    this.count = n;
    const geo = this.points.geometry;
    geo.setDrawRange(0, n);
    this.aPos.needsUpdate = this.aCol.needsUpdate = this.aSize.needsUpdate = this.aAlpha.needsUpdate = true;
  }

  copy(from, to) {
    const f3 = from * 3, t3 = to * 3;
    for (const arr of [this.p, this.v, this.col, this.c0, this.c1]) { arr[t3] = arr[f3]; arr[t3 + 1] = arr[f3 + 1]; arr[t3 + 2] = arr[f3 + 2]; }
    for (const arr of [this.size, this.s0, this.s1, this.alpha, this.life, this.maxLife, this.drag, this.grav, this.a0]) arr[to] = arr[from];
  }
}

// ---------------------------------------------------------------- faixas no chão (marcas de pneu) / rastros 3D
export class Ribbons {
  // segmentos independentes (quads) num buffer circular. Cada segmento: a->b com largura w.
  constructor(scene, max, opts) {
    this.max = max;
    this.head = 0;
    this.pos = new Float32Array(max * 4 * 3);
    this.col = new Float32Array(max * 4 * 4);
    this.born = new Float32Array(max).fill(-1e9);
    this.life = opts.life;
    this.baseAlpha = new Float32Array(max);
    const idx = [];
    for (let i = 0; i < max; i++) { const a = i * 4; idx.push(a, a + 1, a + 2, a, a + 2, a + 3); }
    const geo = new THREE.BufferGeometry();
    this.aPos = new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage);
    this.aCol = new THREE.BufferAttribute(this.col, 4).setUsage(THREE.DynamicDrawUsage);
    geo.setAttribute('position', this.aPos);
    geo.setAttribute('color', this.aCol);
    geo.setIndex(idx);
    this.mesh = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({
      vertexColors: true, transparent: true, depthWrite: false, side: THREE.DoubleSide,
      blending: opts.additive ? THREE.AdditiveBlending : THREE.NormalBlending,
      polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2,
    }));
    this.mesh.frustumCulled = false;
    this.mesh.renderOrder = opts.additive ? 4 : 1;
    this.color = new THREE.Color(opts.color);
    this.vertical = !!opts.vertical;
    scene.add(this.mesh);
  }

  // a, b: {x,y,z}; w largura; alpha
  add(a, b, w, alpha, color, time) {
    const i = this.head; this.head = (this.head + 1) % this.max;
    let dx = b.x - a.x, dz = b.z - a.z;
    const l = Math.hypot(dx, dz) || 1;
    let ox, oy, oz;
    if (this.vertical) { ox = 0; oy = w / 2; oz = 0; } else { ox = -dz / l * w / 2; oy = 0; oz = dx / l * w / 2; }
    const p = this.pos, k = i * 12;
    p[k] = a.x - ox; p[k + 1] = a.y - oy; p[k + 2] = a.z - oz;
    p[k + 3] = a.x + ox; p[k + 4] = a.y + oy; p[k + 5] = a.z + oz;
    p[k + 6] = b.x + ox; p[k + 7] = b.y + oy; p[k + 8] = b.z + oz;
    p[k + 9] = b.x - ox; p[k + 10] = b.y - oy; p[k + 11] = b.z - oz;
    const c = color || this.color, ck = i * 16;
    for (let q = 0; q < 4; q++) { this.col[ck + q * 4] = c.r; this.col[ck + q * 4 + 1] = c.g; this.col[ck + q * 4 + 2] = c.b; this.col[ck + q * 4 + 3] = alpha; }
    this.born[i] = time;
    this.baseAlpha[i] = alpha;
    this.dirty = true;
  }

  update(time) {
    // desbota com a idade
    for (let i = 0; i < this.max; i++) {
      const age = time - this.born[i];
      if (age > this.life + 1) continue;
      const a = Math.max(0, 1 - age / this.life) * this.baseAlpha[i];
      const ck = i * 16;
      for (let q = 0; q < 4; q++) this.col[ck + q * 4 + 3] = a;
      this.dirty = true;
    }
    if (this.dirty) { this.aPos.needsUpdate = true; this.aCol.needsUpdate = true; this.dirty = false; }
  }
}

// ---------------------------------------------------------------- detritos rígidos (pedaços, rodas soltas)
export class Debris {
  constructor(scene) { this.scene = scene; this.list = []; }
  add(mesh, x, y, z, vx, vy, vz, spin = 10, life = 5) {
    mesh.position.set(x, y, z);
    mesh.castShadow = true;
    this.scene.add(mesh);
    this.list.push({ mesh, vx, vy, vz, ax: rand(-spin, spin), ay: rand(-spin, spin), az: rand(-spin, spin), life, t: 0, r: 0.15 });
  }
  update(dt, onBounce) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const d = this.list[i];
      d.t += dt;
      d.vy -= 26 * dt;
      const m = d.mesh;
      m.position.x += d.vx * dt; m.position.y += d.vy * dt; m.position.z += d.vz * dt;
      m.rotation.x += d.ax * dt; m.rotation.y += d.ay * dt; m.rotation.z += d.az * dt;
      if (m.position.y < d.r) {
        m.position.y = d.r;
        if (d.vy < -3 && onBounce) onBounce(m.position, -d.vy);
        d.vy = -d.vy * 0.35; d.vx *= 0.7; d.vz *= 0.7; d.ax *= 0.6; d.ay *= 0.6; d.az *= 0.6;
      }
      if (d.t > d.life) {
        const s = Math.max(0, 1 - (d.t - d.life) / 0.5);
        m.scale.setScalar(s);
        if (s <= 0) { this.scene.remove(m); this.list.splice(i, 1); }
      }
    }
  }
}

// ---------------------------------------------------------------- tremor de câmera (trauma²) com ruído suave
export class Shake {
  constructor() { this.trauma = 0; this.t = 0; }
  add(a) { this.trauma = Math.min(1, this.trauma + a); }
  update(dt) {
    this.t += dt;
    this.trauma = Math.max(0, this.trauma - dt * 1.6);
    const s = this.trauma * this.trauma;
    const n = (f, o) => Math.sin(this.t * f + o) * 0.6 + Math.sin(this.t * f * 2.3 + o * 1.7) * 0.4;
    return { x: n(37, 1) * s * 1.6, y: n(41, 4) * s * 1.2, r: n(29, 9) * s * 0.035 };
  }
}

// ---------------------------------------------------------------- pós-processamento
const FinalShader = {
  uniforms: {
    tDiffuse: { value: null },
    uBlur: { value: 0 },          // blur radial (velocidade/turbo)
    uAberr: { value: 0 },         // aberração cromática
    uFlash: { value: new THREE.Vector4(1, 1, 1, 0) },
    uVig: { value: 0.35 },
    uSat: { value: 1.12 },
    uTime: { value: 0 },
    uCenter: { value: new THREE.Vector2(0.5, 0.5) },
  },
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float uBlur, uAberr, uVig, uSat, uTime; uniform vec4 uFlash; uniform vec2 uCenter;
    varying vec2 vUv;
    void main(){
      vec2 d = vUv - uCenter;
      float r = length(d);
      vec3 col = vec3(0.0);
      // blur radial: mais forte nas bordas
      float amt = uBlur * smoothstep(0.12, 0.7, r);
      const int N = 8;
      for (int i = 0; i < N; i++) {
        float k = float(i) / float(N - 1);
        vec2 uv = vUv - d * amt * k * 0.07;
        vec2 ab = d * uAberr * 0.007;
        col.r += texture2D(tDiffuse, uv + ab).r;
        col.g += texture2D(tDiffuse, uv).g;
        col.b += texture2D(tDiffuse, uv - ab).b;
      }
      col /= float(N);
      float l = dot(col, vec3(0.299, 0.587, 0.114));
      col = mix(vec3(l), col, uSat);
      col *= 1.0 - uVig * smoothstep(0.35, 0.95, r);
      col = mix(col, uFlash.rgb, uFlash.a);
      gl_FragColor = vec4(col, 1.0);
    }`,
};

export function makePost(renderer, scene, camera, w, h) {
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(w / 2, h / 2), 0.5, 0.5, 1.05);
  composer.addPass(bloom);
  const final = new ShaderPass(FinalShader);
  composer.addPass(final);
  composer.addPass(new OutputPass());
  return { composer, bloom, final };
}

// ---------------------------------------------------------------- helpers de efeitos prontos
const C = (h) => new THREE.Color(h);
export const COL = {
  smoke: C('#e9e6ee'), smokeDark: C('#3a3940'), dust: C('#d8c7a0'), spark: C('#ffd36b'), sparkEnd: C('#ff5a1a'),
  fire: C('#ffb43a'), fireEnd: C('#ff2a10'), boost: C('#7fe8ff'), boostEnd: C('#3a5cff'), white: C('#ffffff'),
  glass: C('#bfe8ff'), confetti: [C('#ff4d6d'), C('#ffd23a'), C('#4dd2ff'), C('#7dff6a'), C('#c77dff')],
};

export function burstSparks(P, x, y, z, nx, nz, power, n = 14) {
  for (let i = 0; i < n; i++) {
    const s = rand(4, 10) * (0.6 + power);
    P.emit({ x, y, z, vx: nx * s + rand(-5, 5), vy: rand(2, 9) * (0.5 + power), vz: nz * s + rand(-5, 5),
      life: rand(0.25, 0.6), size: rand(0.18, 0.35), size1: 0.05, color: COL.spark, color1: COL.sparkEnd, drag: 2, grav: 22 });
  }
}

export function puff(P, x, y, z, n, color, size = 1.4, spread = 2, life = 1.2, up = 1.5) {
  for (let i = 0; i < n; i++) {
    P.emit({ x: x + rand(-0.4, 0.4), y, z: z + rand(-0.4, 0.4), vx: rand(-spread, spread), vy: rand(0.3, up), vz: rand(-spread, spread),
      life: rand(life * 0.6, life), size: size * rand(0.5, 0.8), size1: size * rand(1.3, 2.0), color, alpha: 0.85, drag: 2.5 });
  }
}

export function explosion(Padd, Psmoke, x, y, z, scale = 1) {
  for (let i = 0; i < 40 * scale; i++) {
    const a = rand(0, Math.PI * 2), s = rand(3, 14) * scale;
    Padd.emit({ x, y: y + 0.5, z, vx: Math.cos(a) * s, vy: rand(2, 10), vz: Math.sin(a) * s,
      life: rand(0.3, 0.8), size: rand(1.0, 2.2) * scale, size1: 0.2, color: COL.fire, color1: COL.fireEnd, drag: 3 });
  }
  burstSparks(Padd, x, y + 0.5, z, 0, 0, 1.5, 30);
  for (let i = 0; i < 18 * scale; i++) {
    Psmoke.emit({ x: x + rand(-1, 1), y: y + 0.6, z: z + rand(-1, 1), vx: rand(-3, 3), vy: rand(1, 5), vz: rand(-3, 3),
      life: rand(1.2, 2.4), size: rand(1.4, 2.4), size1: rand(3.5, 5), color: COL.smokeDark, color1: COL.smoke, alpha: 0.8, drag: 1.6 });
  }
}
