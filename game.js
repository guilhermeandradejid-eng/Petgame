/* Mochi Pet — a cozy jelly pet game. Vanilla JS + Canvas 2D, no build step. */
(() => {
'use strict';

// ============================================================ utils
const TAU = Math.PI * 2;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[(Math.random() * arr.length) | 0];
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
const REDUCED = matchMedia('(prefers-reduced-motion: reduce)').matches;

const _rgb = {};
function rgba(hex, a) {
  let c = _rgb[hex];
  if (!c) { const n = parseInt(hex.slice(1), 16); c = _rgb[hex] = [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
  return `rgba(${c[0]},${c[1]},${c[2]},${a})`;
}

// Damped spring — the heart of every squish.
class Spring {
  constructor(v = 0, k = 170, d = 11) { this.v = v; this.t = v; this.vel = 0; this.k = k; this.d = d; }
  step(h) { const a = (this.t - this.v) * this.k - this.vel * this.d; this.vel += a * h; this.v += this.vel * h; }
  kick(i) { this.vel += i; }
  set(v) { this.v = this.t = v; this.vel = 0; }
}
function stepSprings(list, dt) {
  const n = Math.max(1, Math.ceil(dt / (1 / 120)));
  const h = dt / n;
  for (let i = 0; i < n; i++) for (const s of list) s.step(h);
}
function P(fn) { const p = new Path2D(); fn(p); return p; }
function rrect(p, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  p.moveTo(x + r, y); p.arcTo(x + w, y, x + w, y + h, r); p.arcTo(x + w, y + h, x, y + h, r);
  p.arcTo(x, y + h, x, y, r); p.arcTo(x, y, x + w, y, r); p.closePath();
}

// ============================================================ data
const SKINS = {
  pessego: { name: 'Pêssego', light: '#FFD3B8', base: '#FFA48C', deep: '#FF8592' },
  chiclete: { name: 'Chiclete', light: '#FFC9E4', base: '#FF94C8', deep: '#F06AAE' },
  menta: { name: 'Menta', light: '#C9FBEA', base: '#86EACB', deep: '#52CFAE' },
  lavanda: { name: 'Lavanda', light: '#E8DCFF', base: '#BEA5FF', deep: '#9A80F2' },
  limao: { name: 'Limão', light: '#FFF6C4', base: '#FFE07E', deep: '#FFBE52' },
  ceu: { name: 'Céu', light: '#D3F0FF', base: '#92D4FF', deep: '#62B2F4' },
  amora: { name: 'Amora', light: '#D9C8F5', base: '#9F86D9', deep: '#7A5FBF' },
};
const SKIN_PRICE = 30;

const SPECIES_INFO = {
  mochi: { name: 'Mochi', skin: 'pessego' },
  coelho: { name: 'Coelho', skin: 'chiclete' },
  gato: { name: 'Gato', skin: 'menta' },
};

const FOODS = [
  { id: 'maca', name: 'Maçã', price: 3, hunger: 10, fun: 0 },
  { id: 'morango', name: 'Morango', price: 5, hunger: 13, fun: 3 },
  { id: 'onigiri', name: 'Onigiri', price: 8, hunger: 26, fun: 0 },
  { id: 'brigadeiro', name: 'Brigadeiro', price: 6, hunger: 9, fun: 10 },
  { id: 'cupcake', name: 'Cupcake', price: 10, hunger: 18, fun: 8 },
  { id: 'pudim', name: 'Pudim', price: 12, hunger: 30, fun: 6 },
];

const HATS = [
  { id: 'none', name: 'Nada', price: 0 },
  { id: 'laco', name: 'Laço', price: 25 },
  { id: 'folha', name: 'Brotinho', price: 30 },
  { id: 'flor', name: 'Flor', price: 35 },
  { id: 'gorro', name: 'Gorro', price: 45 },
  { id: 'festa', name: 'Festa', price: 50 },
  { id: 'coroa', name: 'Coroa', price: 120 },
];

const ROOMS = {
  kitchen: { name: 'Cozinha', wall: ['#FFF5EE', '#FCE9E0'], floor: ['#F8DDD0', '#F1CDBE'] },
  bath: { name: 'Banho', wall: ['#F0F9FF', '#DFF0FB'], floor: ['#D6EBF8', '#C4E0F2'] },
  bedroom: { name: 'Quarto', wall: ['#F4F0FF', '#E6DFFB'], floor: ['#DDD4F6', '#CFC5EF'] },
  play: { name: 'Brincar', wall: ['#F1FFF9', '#DEF7EC'], floor: ['#D0F1E2', '#BEE9D5'] },
  closet: { name: 'Closet', wall: ['#FFF2F8', '#FAE3EF'], floor: ['#F5D5E5', '#EEC6DA'] },
};
const ROOM_ORDER = ['kitchen', 'bath', 'bedroom', 'play', 'closet'];

// Decay per second while the app is open. Offline time decays slower.
const DECAY = { hunger: 0.022, energy: 0.012, fun: 0.026, clean: 0.011 };

// ============================================================ state
const SAVE_KEY = 'mochi-pet-save-v1';
function defaultState() {
  return {
    species: 'mochi', name: 'Mochi', skin: 'pessego', hat: 'none',
    coins: 60, xp: 0, level: 1, best: 0,
    stats: { hunger: 70, energy: 78, fun: 62, clean: 55 },
    owned: { skins: ['pessego', 'chiclete', 'menta'], hats: ['none'] },
    sleeping: false, sound: true, room: 'kitchen',
    last: Date.now(), tips: {},
  };
}
function load(hotData) {
  const def = defaultState();
  let d = hotData && hotData.S;
  if (!d) { try { const raw = localStorage.getItem(SAVE_KEY); if (raw) d = JSON.parse(raw); } catch (e) { /* storage blocked */ } }
  if (!d) return def;
  return { ...def, ...d, stats: { ...def.stats, ...d.stats }, owned: { ...def.owned, ...d.owned }, tips: { ...(d.tips || {}) } };
}
let S = defaultState();
function save() {
  S.last = Date.now();
  try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch (e) { /* storage blocked */ }
}
function applyOffline() {
  const secs = clamp((Date.now() - (S.last || Date.now())) / 1000, 0, 60 * 60 * 10);
  if (secs < 5) return;
  const k = 0.18;
  for (const key in DECAY) {
    if (key === 'energy' && S.sleeping) S.stats.energy = clamp(S.stats.energy + secs * 0.2, 0, 100);
    else S.stats[key] = Math.max(Math.min(S.stats[key], 12), S.stats[key] - DECAY[key] * secs * k);
  }
}

// ============================================================ sound (synthesized, no assets)
const Snd = {
  ac: null, out: null, noiseBuf: null,
  ensure() {
    if (!this.ac) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      try { this.ac = new AC(); } catch (e) { return null; }
      this.out = this.ac.createGain(); this.out.gain.value = 0.55; this.out.connect(this.ac.destination);
      const len = this.ac.sampleRate * 0.5; this.noiseBuf = this.ac.createBuffer(1, len, this.ac.sampleRate);
      const ch = this.noiseBuf.getChannelData(0); for (let i = 0; i < len; i++) ch[i] = Math.random() * 2 - 1;
    }
    if (this.ac.state === 'suspended') this.ac.resume();
    return this.ac;
  },
  tone(f1, f2, dur, type = 'sine', vol = 0.25, delay = 0) {
    if (!S.sound) return; const ac = this.ensure(); if (!ac) return;
    const t = ac.currentTime + delay, o = ac.createOscillator(), g = ac.createGain();
    o.type = type; o.frequency.setValueAtTime(f1, t); o.frequency.exponentialRampToValueAtTime(Math.max(1, f2), t + dur);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.012); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(this.out); o.start(t); o.stop(t + dur + 0.03);
  },
  noise(dur, vol = 0.2, freq = 1200, q = 1, delay = 0) {
    if (!S.sound) return; const ac = this.ensure(); if (!ac) return;
    const t = ac.currentTime + delay, src = ac.createBufferSource(), f = ac.createBiquadFilter(), g = ac.createGain();
    src.buffer = this.noiseBuf; f.type = 'bandpass'; f.frequency.value = freq; f.Q.value = q;
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(this.out); src.start(t, Math.random() * 0.3); src.stop(t + dur + 0.02);
  },
  poke() { this.tone(rand(380, 460), rand(820, 980), 0.14, 'sine', 0.22); },
  squish() { this.tone(260, 150, 0.16, 'triangle', 0.18); },
  giggle() { [0, 0.07, 0.14].forEach((d, i) => this.tone(700 + i * 90, 900 + i * 120, 0.06, 'sine', 0.12, d)); },
  munch() { this.noise(0.09, 0.32, 700, 0.8); this.tone(180, 120, 0.07, 'triangle', 0.1); },
  coin() { this.tone(988, 988, 0.07, 'square', 0.05); this.tone(1319, 1319, 0.16, 'square', 0.05, 0.06); },
  bubble() { this.tone(rand(500, 800), rand(1300, 1900), 0.07, 'sine', 0.1); },
  tap() { this.tone(640, 520, 0.05, 'sine', 0.12); },
  nope() { this.tone(240, 170, 0.12, 'triangle', 0.2); this.tone(200, 140, 0.14, 'triangle', 0.18, 0.12); },
  happy() { [523, 659, 784].forEach((f, i) => this.tone(f, f * 1.01, 0.16, 'sine', 0.15, i * 0.08)); },
  levelup() { [523, 659, 784, 1047, 1319].forEach((f, i) => this.tone(f, f, 0.2, 'triangle', 0.15, i * 0.08)); },
  snore() { this.tone(150, 105, 0.9, 'sine', 0.05); },
  splash() { this.noise(0.12, 0.05, 3500, 0.6); },
  whoosh() { this.noise(0.22, 0.09, 900, 0.5); },
  boing() { this.tone(200, 520, 0.18, 'sine', 0.2); },
  lamp() { this.tone(1200, 1100, 0.03, 'square', 0.06); },
  ouch() { this.tone(520, 220, 0.25, 'sawtooth', 0.08); },
};

// ============================================================ jelly material
// Every pet, food and toy is painted with this: gradient body, subsurface glow,
// light rim (translucency), a soft sheen and a sharp specular.
function jelly(ctx, path, sk, x, y, w, h, glossy = 1) {
  let g = ctx.createLinearGradient(0, y, 0, y + h);
  g.addColorStop(0, sk.light); g.addColorStop(0.52, sk.base); g.addColorStop(1, sk.deep);
  ctx.fillStyle = g; ctx.fill(path);
  ctx.save(); ctx.clip(path);
  const cx = x + w / 2, m = Math.min(w, h);
  g = ctx.createRadialGradient(cx, y + h * 0.98, 0, cx, y + h * 0.98, w * 0.55);
  g.addColorStop(0, 'rgba(255,255,255,0.42)'); g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g; ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = 'rgba(255,255,255,0.13)'; ctx.lineWidth = m * 0.17; ctx.stroke(path);
  ctx.strokeStyle = 'rgba(255,255,255,0.14)'; ctx.lineWidth = m * 0.075; ctx.stroke(path);
  ctx.strokeStyle = 'rgba(255,255,255,0.26)'; ctx.lineWidth = m * 0.028; ctx.stroke(path);
  if (glossy) {
    ctx.save(); ctx.translate(x + w * 0.31, y + h * 0.25); ctx.scale(1, 0.75);
    g = ctx.createRadialGradient(0, 0, 0, 0, 0, w * 0.33);
    g.addColorStop(0, 'rgba(255,255,255,0.72)'); g.addColorStop(0.45, 'rgba(255,255,255,0.24)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, w * 0.33, 0, TAU); ctx.fill(); ctx.restore();
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.beginPath(); ctx.ellipse(x + w * 0.25, y + h * 0.19, w * 0.075, w * 0.038, -0.75, 0, TAU); ctx.fill();
    ctx.beginPath(); ctx.arc(x + w * 0.355, y + h * 0.125, w * 0.019, 0, TAU); ctx.fill();
  }
  ctx.restore();
}
function jellyCircle(ctx, x, y, r, sk, glossy = 1) {
  const p = new Path2D(); p.arc(x, y, r, 0, TAU);
  jelly(ctx, p, sk, x - r, y - r, r * 2, r * 2, glossy);
}
function jellyEllipse(ctx, x, y, rx, ry, rot, sk) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot);
  const p = new Path2D(); p.ellipse(0, 0, rx, ry, 0, 0, TAU);
  jelly(ctx, p, sk, -rx, -ry, rx * 2, ry * 2); ctx.restore();
}

// ============================================================ pet species (unit space: R = 1, origin at bottom center)
const INK = '#3A2840';
const SPEC = {
  mochi: {
    w: 1.12, h: 1.42, eye: { y: -0.66, dx: 0.37, r: 0.088 }, mouthY: -0.57, hatY: -1.37, hatW: 0.8,
    path: P((p) => {
      p.moveTo(0, 0);
      p.bezierCurveTo(0.76, 0, 1.12, -0.04, 1.12, -0.44);
      p.bezierCurveTo(1.12, -1.06, 0.66, -1.42, 0, -1.42);
      p.bezierCurveTo(-0.66, -1.42, -1.12, -1.06, -1.12, -0.44);
      p.bezierCurveTo(-1.12, -0.04, -0.76, 0, 0, 0);
    }),
    front(ctx, o, sk) {
      // peach crease + little stem nub like the reference
      ctx.strokeStyle = 'rgba(255,255,255,0.28)'; ctx.lineWidth = 0.035; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(0.1, -1.36); ctx.quadraticCurveTo(0.5, -1.18, 0.56, -0.78); ctx.stroke();
      ctx.strokeStyle = rgba(sk.deep, 0.18); ctx.lineWidth = 0.025;
      ctx.beginPath(); ctx.moveTo(0.14, -1.33); ctx.quadraticCurveTo(0.54, -1.16, 0.6, -0.8); ctx.stroke();
      ctx.save(); ctx.translate(0.02, -1.41); ctx.rotate(Math.sin(o.t * 2.1) * 0.12 + o.ear * 0.6);
      jellyEllipse(ctx, 0, -0.03, 0.13, 0.085, -0.15, { light: '#FFE08A', base: '#FFB43D', deep: '#FF9330' });
      ctx.restore();
    },
  },
  coelho: {
    w: 0.8, h: 1.92, eye: { y: -1.3, dx: 0.3, r: 0.1 }, mouthY: -1.16, hatY: -1.88, hatW: 0.66, lashes: true,
    path: P((p) => {
      p.moveTo(0, 0);
      p.bezierCurveTo(0.45, 0, 0.72, -0.02, 0.72, -0.26);
      p.bezierCurveTo(0.72, -0.55, 0.62, -0.74, 0.58, -0.88);
      p.bezierCurveTo(0.84, -1.08, 0.82, -1.92, 0, -1.92);
      p.bezierCurveTo(-0.82, -1.92, -0.84, -1.08, -0.58, -0.88);
      p.bezierCurveTo(-0.62, -0.74, -0.72, -0.55, -0.72, -0.26);
      p.bezierCurveTo(-0.72, -0.02, -0.45, 0, 0, 0);
    }),
    ear: P((p) => { p.ellipse(0, -0.4, 0.19, 0.46, 0, 0, TAU); }),
    earIn: P((p) => { p.ellipse(0, -0.38, 0.085, 0.3, 0, 0, TAU); }),
    back(ctx, o, sk) {
      for (const s of [-1, 1]) {
        ctx.save(); ctx.translate(s * 0.3, -1.7);
        ctx.rotate(s * 0.16 + o.ear * s + Math.sin(o.t * 1.7 + s) * 0.03);
        jelly(ctx, this.ear, sk, -0.19, -0.86, 0.38, 0.92);
        ctx.fillStyle = 'rgba(255,170,200,0.55)'; ctx.fill(this.earIn);
        ctx.restore();
      }
    },
    front(ctx, o, sk) {
      const light = { light: '#FFFFFF', base: sk.light, deep: sk.base };
      for (const s of [-1, 1]) {
        jellyEllipse(ctx, s * 0.38, -0.07, 0.21, 0.1, 0, light);
        jellyEllipse(ctx, s * 0.2, -0.62 + Math.sin(o.t * 2 + s) * 0.006, 0.13, 0.1, s * 0.3, light);
      }
    },
  },
  gato: {
    w: 0.96, h: 1.46, eye: { y: -0.74, dx: 0.35, r: 0.082 }, mouthY: -0.57, hatY: -1.12, hatW: 0.6, nose: true, catMouth: true,
    path: P((p) => {
      p.moveTo(0, 0);
      p.bezierCurveTo(0.7, 0, 0.96, -0.02, 0.96, -0.32);
      p.bezierCurveTo(0.96, -0.72, 0.86, -0.96, 0.74, -1.06);
      p.bezierCurveTo(0.78, -1.26, 0.76, -1.42, 0.68, -1.46);
      p.bezierCurveTo(0.6, -1.46, 0.48, -1.27, 0.39, -1.14);
      p.bezierCurveTo(0.15, -1.19, -0.15, -1.19, -0.39, -1.14);
      p.bezierCurveTo(-0.48, -1.27, -0.6, -1.46, -0.68, -1.46);
      p.bezierCurveTo(-0.76, -1.42, -0.78, -1.26, -0.74, -1.06);
      p.bezierCurveTo(-0.86, -0.96, -0.96, -0.72, -0.96, -0.32);
      p.bezierCurveTo(-0.96, -0.02, -0.7, 0, 0, 0);
    }),
    back(ctx, o, sk) {
      ctx.save(); ctx.translate(0.78, -0.18); ctx.rotate(Math.sin(o.t * 2.6) * 0.16 - o.ear * 0.5);
      ctx.lineCap = 'round';
      const g = ctx.createLinearGradient(0, -0.8, 0, 0.1);
      g.addColorStop(0, sk.light); g.addColorStop(1, sk.deep);
      ctx.strokeStyle = g; ctx.lineWidth = 0.22;
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.bezierCurveTo(0.45, 0.02, 0.5, -0.5, 0.28, -0.66); ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,0.5)'; ctx.lineWidth = 0.05;
      ctx.beginPath(); ctx.moveTo(0.12, -0.06); ctx.bezierCurveTo(0.36, -0.06, 0.4, -0.42, 0.26, -0.56); ctx.stroke();
      ctx.restore();
    },
    front(ctx, o, sk) {
      ctx.fillStyle = 'rgba(255,160,190,0.5)';
      for (const s of [-1, 1]) {
        ctx.beginPath(); ctx.moveTo(s * 0.66, -1.36); ctx.quadraticCurveTo(s * 0.52, -1.24, s * 0.48, -1.16); ctx.quadraticCurveTo(s * 0.62, -1.12, s * 0.72, -1.12); ctx.closePath(); ctx.fill();
      }
      const paw = { light: '#FFFFFF', base: '#FFFFFF', deep: rgba(sk.light, 1) };
      for (const s of [-1, 1]) {
        jellyEllipse(ctx, s * 0.24, -0.08, 0.19, 0.11, 0, paw);
        ctx.strokeStyle = rgba(sk.deep, 0.5); ctx.lineWidth = 0.018; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(s * 0.24 - 0.05, -0.06); ctx.lineTo(s * 0.24 - 0.05, -0.01); ctx.moveTo(s * 0.24 + 0.05, -0.06); ctx.lineTo(s * 0.24 + 0.05, -0.01); ctx.stroke();
      }
      // whiskers
      ctx.strokeStyle = rgba(sk.deep, 0.55); ctx.lineWidth = 0.016;
      for (const s of [-1, 1]) {
        ctx.beginPath(); ctx.moveTo(s * 0.62, -0.62); ctx.lineTo(s * 0.86, -0.66); ctx.moveTo(s * 0.62, -0.56); ctx.lineTo(s * 0.86, -0.54); ctx.stroke();
      }
    },
  },
};
const DIRT_SPOTS = [[-0.55, 0.24, 0.13], [0.52, 0.5, 0.11], [0.18, 0.12, 0.09], [-0.32, 0.6, 0.08], [0.6, 0.18, 0.1], [-0.12, 0.3, 0.06]];

function drawShadow(ctx, x, y, R, d, lift, sk) {
  const s = 1 - Math.min(lift / (R * 1.6), 0.55);
  ctx.save(); ctx.translate(x, y); ctx.scale(1, 0.2);
  const rr = R * d.w * 1.35 * s;
  let g = ctx.createRadialGradient(0, 0, 0, 0, 0, rr);
  g.addColorStop(0, rgba(sk.deep, 0.32 * s)); g.addColorStop(0.55, rgba(sk.base, 0.14 * s)); g.addColorStop(1, rgba(sk.base, 0));
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, rr, 0, TAU); ctx.fill();
  g = ctx.createRadialGradient(0, 0, 0, 0, 0, rr * 0.7);
  g.addColorStop(0, `rgba(70,40,90,${0.2 * s})`); g.addColorStop(1, 'rgba(70,40,90,0)');
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, rr * 0.7, 0, TAU); ctx.fill();
  ctx.restore();
}

const PET_DEFAULTS = { sq: 0, rot: 0, hop: 0, breathe: 0, ear: 0, look: { x: 0, y: 0 }, eyes: 'open', blink: 0, mouth: 'smile', mouthOpen: 0, dirt: 0, foam: null, t: 0, hat: 'none', shadow: true, glow: 0 };
function drawPet(ctx, opts) {
  const o = Object.assign({}, PET_DEFAULTS, opts);
  const d = SPEC[o.species], sk = SKINS[o.skin] || SKINS.pessego, R = o.R;
  if (o.shadow) drawShadow(ctx, o.x, o.y, R, d, -o.hop, sk);
  ctx.save();
  ctx.translate(o.x, o.y + o.hop);
  ctx.rotate(o.rot);
  const sq = clamp(o.sq, -0.4, 0.5);
  ctx.scale(R * (1 + sq - o.breathe * 0.6), R * (1 - sq + o.breathe));
  if (o.glow > 0.01) {
    const g = ctx.createRadialGradient(0, -d.h * 0.5, 0, 0, -d.h * 0.5, d.h * 1.2);
    g.addColorStop(0, rgba(sk.light, 0.5 * o.glow)); g.addColorStop(1, rgba(sk.light, 0));
    ctx.fillStyle = g; ctx.fillRect(-2.5, -d.h * 1.8, 5, d.h * 2.6);
  }
  if (d.back) d.back(ctx, o, sk);
  jelly(ctx, d.path, sk, -d.w, -d.h, d.w * 2, d.h);
  if (d.front) d.front(ctx, o, sk);
  if (o.dirt > 0.01) drawDirt(ctx, d, o.dirt);
  drawFace(ctx, d, o);
  if (o.foam && o.foam.length) drawFoam(ctx, o.foam, o.t);
  if (o.hat && o.hat !== 'none') { ctx.save(); ctx.translate(0, d.hatY); drawHat(ctx, o.hat, d.hatW, o.t); ctx.restore(); }
  ctx.restore();
}

function drawDirt(ctx, d, a) {
  ctx.save(); ctx.clip(d.path);
  for (const [fx, fy, r] of DIRT_SPOTS) {
    const x = fx * d.w, y = -fy * d.h;
    ctx.fillStyle = `rgba(150,105,80,${0.42 * a})`;
    ctx.beginPath(); ctx.ellipse(x, y, r, r * 0.75, fx, 0, TAU); ctx.fill();
    ctx.fillStyle = `rgba(130,90,70,${0.35 * a})`;
    ctx.beginPath(); ctx.arc(x + r * 1.1, y - r * 0.5, r * 0.25, 0, TAU); ctx.arc(x - r * 0.9, y + r * 0.7, r * 0.18, 0, TAU); ctx.fill();
  }
  ctx.restore();
}

function drawFoam(ctx, foam, t) {
  for (const b of foam) {
    const r = b.r * (b.pop != null ? 1 + (1 - b.pop) * 0.4 : Math.min(1, (t - b.born) * 6));
    const a = b.pop != null ? b.pop : 1;
    ctx.fillStyle = `rgba(255,255,255,${0.78 * a})`;
    ctx.beginPath(); ctx.arc(b.x + Math.sin(t * 3 + b.ph) * 0.01, b.y, r, 0, TAU); ctx.fill();
    ctx.strokeStyle = `rgba(160,210,240,${0.6 * a})`; ctx.lineWidth = r * 0.12; ctx.stroke();
    ctx.fillStyle = `rgba(255,255,255,${a})`;
    ctx.beginPath(); ctx.arc(b.x - r * 0.35, b.y - r * 0.35, r * 0.22, 0, TAU); ctx.fill();
  }
}

function drawFace(ctx, d, o) {
  const e = d.eye, r = e.r;
  const lx = clamp(o.look.x, -1, 1) * r * 0.7, ly = clamp(o.look.y, -1, 1) * r * 0.5;
  // blush
  ctx.fillStyle = 'rgba(255,100,150,0.26)';
  for (const s of [-1, 1]) { ctx.beginPath(); ctx.ellipse(s * (e.dx + r * 1.3) + lx * 0.4, e.y + r * 1.75, r * 1.3, r * 0.66, 0, 0, TAU); ctx.fill(); }
  ctx.strokeStyle = INK; ctx.fillStyle = INK; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  for (const s of [-1, 1]) {
    const cx = s * e.dx + lx, cy = e.y + ly;
    let mode = o.eyes;
    if ((mode === 'open' || mode === 'tired') && o.blink > 0.75) mode = 'line';
    ctx.lineWidth = r * 0.44;
    if (mode === 'open' || mode === 'tired') {
      const open = mode === 'tired' ? 1 : 1 - o.blink;
      ctx.save(); ctx.translate(cx, cy);
      if (mode === 'tired') { ctx.beginPath(); ctx.rect(-r * 2, -r * 0.1, r * 4, r * 3); ctx.clip(); }
      ctx.scale(1, Math.max(0.1, open));
      ctx.fillStyle = INK; ctx.beginPath(); ctx.ellipse(0, 0, r, r * 1.12, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = 'rgba(140,100,180,0.5)'; ctx.beginPath(); ctx.ellipse(0, r * 0.5, r * 0.6, r * 0.4, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.arc(-r * 0.3, -r * 0.4, r * 0.38, 0, TAU); ctx.fill();
      ctx.beginPath(); ctx.arc(r * 0.38, r * 0.38, r * 0.15, 0, TAU); ctx.fill();
      ctx.restore();
      if (mode === 'tired') { ctx.lineWidth = r * 0.32; ctx.beginPath(); ctx.moveTo(cx - r * 1.15, cy - r * 0.1); ctx.lineTo(cx + r * 1.15, cy - r * 0.1); ctx.stroke(); }
      else if (d.lashes) {
        ctx.lineWidth = r * 0.24; ctx.beginPath();
        ctx.moveTo(cx + s * r * 0.72, cy - r * 0.78); ctx.lineTo(cx + s * r * 1.2, cy - r * 1.12);
        ctx.moveTo(cx + s * r * 0.95, cy - r * 0.4); ctx.lineTo(cx + s * r * 1.45, cy - r * 0.58); ctx.stroke();
      }
    } else if (mode === 'line') {
      ctx.beginPath(); ctx.moveTo(cx - r, cy); ctx.quadraticCurveTo(cx, cy + r * 0.4, cx + r, cy); ctx.stroke();
    } else if (mode === 'happy') {
      ctx.beginPath(); ctx.moveTo(cx - r * 1.05, cy + r * 0.4); ctx.quadraticCurveTo(cx, cy - r * 1.05, cx + r * 1.05, cy + r * 0.4); ctx.stroke();
    } else if (mode === 'sleep') {
      ctx.beginPath(); ctx.moveTo(cx - r * 1.05, cy - r * 0.1); ctx.quadraticCurveTo(cx, cy + r * 1.05, cx + r * 1.05, cy - r * 0.1); ctx.stroke();
    } else if (mode === 'x') {
      ctx.lineWidth = r * 0.36; ctx.beginPath();
      ctx.moveTo(cx - r * 0.8, cy - r * 0.8); ctx.lineTo(cx + r * 0.8, cy + r * 0.8);
      ctx.moveTo(cx + r * 0.8, cy - r * 0.8); ctx.lineTo(cx - r * 0.8, cy + r * 0.8); ctx.stroke();
    } else if (mode === 'swirl') {
      ctx.lineWidth = r * 0.28; ctx.beginPath();
      for (let a = 0; a < TAU * 1.6; a += 0.3) { const rr = r * (0.15 + a / (TAU * 1.6) * 0.9); ctx.lineTo(cx + Math.cos(a + o.t * 8 * s) * rr, cy + Math.sin(a + o.t * 8 * s) * rr); }
      ctx.stroke();
    }
  }
  const my = d.mouthY + ly * 0.5, mx = lx * 0.6;
  if (d.nose) {
    ctx.fillStyle = '#FF8DB0'; ctx.strokeStyle = '#FF8DB0'; ctx.lineWidth = r * 0.25;
    ctx.beginPath(); ctx.moveTo(mx - r * 0.38, my - r * 1.0); ctx.lineTo(mx + r * 0.38, my - r * 1.0); ctx.lineTo(mx, my - r * 0.62); ctx.closePath(); ctx.fill(); ctx.stroke();
    ctx.strokeStyle = INK;
  }
  ctx.lineWidth = r * 0.3;
  const open = o.mouthOpen;
  if (open > 0.06) {
    ctx.save(); ctx.translate(mx, my + r * 0.25);
    const ow = r * (0.55 + open * 0.55), oh = r * (0.3 + open * 1.1);
    ctx.fillStyle = '#5B2338'; ctx.beginPath(); ctx.ellipse(0, 0, ow, oh, 0, 0, TAU); ctx.fill();
    ctx.clip(); ctx.fillStyle = '#FF7C9C'; ctx.beginPath(); ctx.ellipse(0, oh * 0.8, ow * 0.75, oh * 0.55, 0, 0, TAU); ctx.fill();
    ctx.restore();
    return;
  }
  switch (o.mouth) {
    case 'smile':
      if (d.catMouth) {
        ctx.beginPath(); ctx.arc(mx - r * 0.36, my - r * 0.1, r * 0.36, 0.1 * Math.PI, 0.95 * Math.PI); ctx.stroke();
        ctx.beginPath(); ctx.arc(mx + r * 0.36, my - r * 0.1, r * 0.36, 0.05 * Math.PI, 0.9 * Math.PI); ctx.stroke();
      } else { ctx.beginPath(); ctx.arc(mx, my - r * 0.3, r * 0.6, 0.18 * Math.PI, 0.82 * Math.PI); ctx.stroke(); }
      break;
    case 'grin': {
      ctx.fillStyle = '#5B2338';
      ctx.beginPath(); ctx.moveTo(mx - r * 0.7, my - r * 0.15); ctx.quadraticCurveTo(mx, my + r * 1.4, mx + r * 0.7, my - r * 0.15); ctx.closePath(); ctx.fill();
      ctx.save(); ctx.clip(); ctx.fillStyle = '#FF7C9C'; ctx.beginPath(); ctx.ellipse(mx, my + r * 0.75, r * 0.45, r * 0.3, 0, 0, TAU); ctx.fill(); ctx.restore();
      break;
    }
    case 'frown': ctx.beginPath(); ctx.arc(mx, my + r * 0.45, r * 0.5, 1.22 * Math.PI, 1.78 * Math.PI); ctx.stroke(); break;
    case 'flat': ctx.beginPath(); ctx.moveTo(mx - r * 0.35, my); ctx.lineTo(mx + r * 0.35, my); ctx.stroke(); break;
    case 'o': ctx.fillStyle = '#5B2338'; ctx.beginPath(); ctx.ellipse(mx, my + r * 0.1, r * 0.22, r * 0.28, 0, 0, TAU); ctx.fill(); break;
    case 'wavy':
      ctx.beginPath(); ctx.moveTo(mx - r * 0.6, my);
      for (let i = 1; i <= 4; i++) ctx.quadraticCurveTo(mx - r * 0.6 + (i - 0.5) * r * 0.3, my + (i % 2 ? -1 : 1) * r * 0.25, mx - r * 0.6 + i * r * 0.3, my);
      ctx.stroke(); break;
  }
}

// ============================================================ hats
const SK = {
  pink: { light: '#FFC6E0', base: '#FF82B8', deep: '#F0579B' },
  green: { light: '#D8FFB8', base: '#8EDC6E', deep: '#5DBB52' },
  gold: { light: '#FFF2B0', base: '#FFD054', deep: '#F5A623' },
  lav: { light: '#EADFFF', base: '#B9A0FF', deep: '#9479EE' },
  white: { light: '#FFFFFF', base: '#FBF7FF', deep: '#E7DEF2' },
  mint: { light: '#CFFCEB', base: '#7FE6C6', deep: '#4FCBA9' },
  red: { light: '#FFB3BA', base: '#FF5C70', deep: '#E23D5A' },
  sky: { light: '#D6F1FF', base: '#8ED2FF', deep: '#5FB1F2' },
  brown: { light: '#B9805F', base: '#7A4530', deep: '#542A1D' },
  yellow: { light: '#FFF4C4', base: '#FFDB6E', deep: '#F4B740' },
  cream: { light: '#FFFFFF', base: '#FFF6EE', deep: '#F1E2D6' },
};
function drawHat(ctx, id, hw, t) {
  switch (id) {
    case 'laco': {
      ctx.save(); ctx.translate(hw * 0.42, 0.06); ctx.rotate(0.35 + Math.sin(t * 2) * 0.04);
      for (const s of [-1, 1]) {
        const p = P((p) => { p.moveTo(0, 0); p.bezierCurveTo(s * 0.08, -0.24, s * 0.38, -0.22, s * 0.36, 0); p.bezierCurveTo(s * 0.38, 0.22, s * 0.08, 0.24, 0, 0); });
        jelly(ctx, p, SK.pink, s > 0 ? 0 : -0.38, -0.22, 0.38, 0.44);
      }
      jellyCircle(ctx, 0, 0, 0.085, SK.pink);
      ctx.restore(); break;
    }
    case 'folha': {
      ctx.save(); ctx.rotate(Math.sin(t * 2.2) * 0.1);
      ctx.strokeStyle = '#6CC35A'; ctx.lineWidth = 0.045; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(0, 0.04); ctx.quadraticCurveTo(-0.02, -0.12, 0.02, -0.24); ctx.stroke();
      jellyEllipse(ctx, -0.14, -0.27, 0.15, 0.075, -0.5, SK.green);
      jellyEllipse(ctx, 0.15, -0.3, 0.16, 0.08, 0.55, SK.green);
      ctx.restore(); break;
    }
    case 'flor': {
      ctx.save(); ctx.translate(-hw * 0.4, 0.08); ctx.rotate(t * 0.4);
      for (let i = 0; i < 5; i++) { const a = (i / 5) * TAU; jellyEllipse(ctx, Math.cos(a) * 0.11, Math.sin(a) * 0.11, 0.1, 0.075, a, SK.white); }
      jellyCircle(ctx, 0, 0, 0.07, SK.yellow);
      ctx.restore(); break;
    }
    case 'gorro': {
      const w = hw * 0.62;
      const dome = P((p) => { p.moveTo(-w, 0.1); p.bezierCurveTo(-w, -0.46, w, -0.46, w, 0.1); p.closePath(); });
      jelly(ctx, dome, SK.lav, -w, -0.36, w * 2, 0.46);
      const band = P((p) => rrect(p, -w * 1.06, 0.0, w * 2.12, 0.16, 0.08));
      jelly(ctx, band, { light: '#D9CCFF', base: '#A68BFA', deep: '#8466E6' }, -w * 1.06, 0, w * 2.12, 0.16, 0);
      ctx.strokeStyle = 'rgba(255,255,255,0.35)'; ctx.lineWidth = 0.02;
      for (let x = -w * 0.9; x <= w * 0.9; x += 0.09) { ctx.beginPath(); ctx.moveTo(x, 0.03); ctx.lineTo(x, 0.13); ctx.stroke(); }
      jellyCircle(ctx, Math.sin(t * 2.4) * 0.02, -0.37, 0.1, SK.white);
      break;
    }
    case 'festa': {
      ctx.save(); ctx.translate(0, 0.06); ctx.rotate(-0.14);
      const cone = P((p) => { p.moveTo(-0.2, 0); p.quadraticCurveTo(0, 0.05, 0.2, 0); p.lineTo(0.02, -0.56); p.quadraticCurveTo(0, -0.6, -0.02, -0.56); p.closePath(); });
      jelly(ctx, cone, SK.mint, -0.2, -0.58, 0.4, 0.6);
      ctx.save(); ctx.clip(cone); ctx.fillStyle = 'rgba(255,120,180,0.55)';
      for (let y = -0.5; y < 0.1; y += 0.16) { ctx.beginPath(); ctx.moveTo(-0.3, y); ctx.lineTo(0.3, y - 0.1); ctx.lineTo(0.3, y - 0.04); ctx.lineTo(-0.3, y + 0.06); ctx.fill(); }
      ctx.restore();
      jellyCircle(ctx, 0, -0.58, 0.075, SK.yellow);
      ctx.restore(); break;
    }
    case 'coroa': {
      ctx.save(); ctx.translate(0, 0.04);
      const c = P((p) => {
        p.moveTo(-0.28, 0.06); p.lineTo(-0.31, -0.2); p.quadraticCurveTo(-0.3, -0.24, -0.26, -0.21);
        p.lineTo(-0.14, -0.1); p.lineTo(-0.02, -0.29); p.quadraticCurveTo(0, -0.32, 0.02, -0.29);
        p.lineTo(0.14, -0.1); p.lineTo(0.26, -0.21); p.quadraticCurveTo(0.3, -0.24, 0.31, -0.2);
        p.lineTo(0.28, 0.06); p.quadraticCurveTo(0, 0.1, -0.28, 0.06); p.closePath();
      });
      jelly(ctx, c, SK.gold, -0.31, -0.32, 0.62, 0.42);
      jellyCircle(ctx, 0, -0.02, 0.05, SK.pink);
      jellyCircle(ctx, -0.17, 0, 0.035, SK.sky);
      jellyCircle(ctx, 0.17, 0, 0.035, SK.mint);
      const tw = (Math.sin(t * 3) + 1) / 2;
      drawSparkle(ctx, 0.22, -0.28, 0.07 * tw, '#FFFFFF', tw);
      ctx.restore(); break;
    }
  }
}

function drawSparkle(ctx, x, y, s, color, a = 1) {
  if (s <= 0.0001) return;
  ctx.save(); ctx.translate(x, y); ctx.globalAlpha *= a; ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(0, -s); ctx.quadraticCurveTo(s * 0.15, -s * 0.15, s, 0); ctx.quadraticCurveTo(s * 0.15, s * 0.15, 0, s);
  ctx.quadraticCurveTo(-s * 0.15, s * 0.15, -s, 0); ctx.quadraticCurveTo(-s * 0.15, -s * 0.15, 0, -s);
  ctx.fill(); ctx.restore();
}
function heartPath(s) {
  return P((p) => {
    p.moveTo(0, s * 0.9);
    p.bezierCurveTo(-s * 1.1, s * 0.15, -s * 1.0, -s * 0.85, 0, -s * 0.35);
    p.bezierCurveTo(s * 1.0, -s * 0.85, s * 1.1, s * 0.15, 0, s * 0.9);
  });
}
const HEART = heartPath(1);

// ============================================================ items (food, toys, minigame)
const FOOD_PATHS = {
  maca: P((p) => { p.moveTo(0, -0.55); p.bezierCurveTo(0.35, -0.85, 0.95, -0.72, 0.9, -0.05); p.bezierCurveTo(0.85, 0.6, 0.4, 0.92, 0, 0.76); p.bezierCurveTo(-0.4, 0.92, -0.85, 0.6, -0.9, -0.05); p.bezierCurveTo(-0.95, -0.72, -0.35, -0.85, 0, -0.55); }),
  morango: P((p) => { p.moveTo(0, 0.95); p.bezierCurveTo(-0.5, 0.82, -0.9, 0.1, -0.85, -0.3); p.bezierCurveTo(-0.8, -0.7, -0.3, -0.68, 0, -0.58); p.bezierCurveTo(0.3, -0.68, 0.8, -0.7, 0.85, -0.3); p.bezierCurveTo(0.9, 0.1, 0.5, 0.82, 0, 0.95); }),
  onigiri: P((p) => { p.moveTo(0, -0.82); p.bezierCurveTo(0.25, -0.82, 0.95, 0.35, 0.88, 0.62); p.bezierCurveTo(0.82, 0.86, -0.82, 0.86, -0.88, 0.62); p.bezierCurveTo(-0.95, 0.35, -0.25, -0.82, 0, -0.82); }),
  pudim: P((p) => { p.moveTo(-0.5, -0.38); p.quadraticCurveTo(0, -0.52, 0.5, -0.38); p.bezierCurveTo(0.62, 0.0, 0.8, 0.45, 0.78, 0.55); p.quadraticCurveTo(0, 0.78, -0.78, 0.55); p.bezierCurveTo(-0.8, 0.45, -0.62, 0.0, -0.5, -0.38); p.closePath(); }),
  cupFrost: P((p) => { p.moveTo(-0.72, 0.05); p.bezierCurveTo(-0.95, -0.25, -0.6, -0.45, -0.42, -0.4); p.bezierCurveTo(-0.45, -0.75, 0.0, -0.85, 0.12, -0.62); p.bezierCurveTo(0.35, -0.8, 0.75, -0.6, 0.55, -0.35); p.bezierCurveTo(0.9, -0.3, 0.95, 0.0, 0.72, 0.05); p.closePath(); }),
  cupBase: P((p) => { p.moveTo(-0.7, 0.0); p.lineTo(0.7, 0.0); p.lineTo(0.52, 0.85); p.quadraticCurveTo(0, 0.95, -0.52, 0.85); p.closePath(); }),
  sabao: P((p) => rrect(p, -0.82, -0.48, 1.64, 0.96, 0.4)),
  bala: P((p) => { p.ellipse(0, 0, 0.55, 0.42, 0, 0, TAU); }),
  star: P((p) => {
    for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i / 10) * TAU, r = i % 2 ? 0.45 : 0.95; const x = Math.cos(a) * r, y = Math.sin(a) * r + 0.06; if (i) p.lineTo(x, y); else p.moveTo(x, y); }
    p.closePath();
  }),
  nuvem: P((p) => { p.moveTo(-0.7, 0.3); p.bezierCurveTo(-1.05, 0.3, -1.0, -0.2, -0.62, -0.18); p.bezierCurveTo(-0.6, -0.65, 0.0, -0.75, 0.15, -0.38); p.bezierCurveTo(0.4, -0.6, 0.85, -0.45, 0.72, -0.1); p.bezierCurveTo(1.05, -0.05, 1.0, 0.32, 0.7, 0.3); p.closePath(); }),
};
const SPRINKLES = Array.from({ length: 16 }, (_, i) => { const a = i * 2.39996, r = 0.62 * Math.sqrt((i + 0.5) / 16); return [Math.cos(a) * r, Math.sin(a) * r * 0.9 - 0.1, a * 1.7]; });

// Draws an item centered at (x, y) with a total size ≈ s pixels.
function drawItem(ctx, id, x, y, s, t = 0, extra = {}) {
  ctx.save(); ctx.translate(x, y); ctx.scale(s / 2, s / 2);
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  switch (id) {
    case 'maca':
      ctx.strokeStyle = '#8A5A3C'; ctx.lineWidth = 0.08; ctx.beginPath(); ctx.moveTo(0, -0.5); ctx.quadraticCurveTo(0.02, -0.75, 0.1, -0.9); ctx.stroke();
      jelly(ctx, FOOD_PATHS.maca, SK.red, -0.92, -0.85, 1.84, 1.75);
      jellyEllipse(ctx, 0.32, -0.82, 0.2, 0.1, -0.4, SK.green);
      break;
    case 'morango':
      jelly(ctx, FOOD_PATHS.morango, { light: '#FFB0B8', base: '#FF5A72', deep: '#E8395C' }, -0.88, -0.7, 1.76, 1.65);
      ctx.fillStyle = 'rgba(255,240,170,0.9)';
      for (const [sx, sy] of [[-0.4, -0.2], [0, -0.25], [0.4, -0.2], [-0.25, 0.15], [0.25, 0.15], [0, 0.45], [-0.5, 0.15], [0.5, 0.15]]) { ctx.beginPath(); ctx.ellipse(sx, sy, 0.045, 0.07, 0, 0, TAU); ctx.fill(); }
      for (let i = 0; i < 5; i++) { const a = -Math.PI / 2 + (i - 2) * 0.55; jellyEllipse(ctx, Math.cos(a) * 0.22, -0.62 + Math.sin(a) * 0.12 + 0.12, 0.2, 0.08, a, SK.green); }
      break;
    case 'onigiri':
      jelly(ctx, FOOD_PATHS.onigiri, { light: '#FFFFFF', base: '#FAF7FC', deep: '#E2DAEC' }, -0.92, -0.82, 1.84, 1.62);
      { const nori = P((p) => rrect(p, -0.34, 0.22, 0.68, 0.6, 0.1)); ctx.fillStyle = '#2E3A3C'; ctx.fill(nori);
        ctx.fillStyle = 'rgba(255,255,255,0.18)'; ctx.fillRect(-0.26, 0.3, 0.06, 0.42); }
      ctx.fillStyle = INK;
      ctx.beginPath(); ctx.arc(-0.2, -0.05, 0.055, 0, TAU); ctx.arc(0.2, -0.05, 0.055, 0, TAU); ctx.fill();
      ctx.fillStyle = 'rgba(255,120,160,0.35)'; ctx.beginPath(); ctx.ellipse(-0.36, 0.06, 0.09, 0.05, 0, 0, TAU); ctx.ellipse(0.36, 0.06, 0.09, 0.05, 0, 0, TAU); ctx.fill();
      break;
    case 'brigadeiro': {
      const cup = P((p) => { p.moveTo(-0.72, 0.15); p.lineTo(0.72, 0.15); p.lineTo(0.56, 0.86); p.quadraticCurveTo(0, 0.95, -0.56, 0.86); p.closePath(); });
      jelly(ctx, cup, { light: '#FFE0EC', base: '#FFB7D2', deep: '#F590B8' }, -0.72, 0.15, 1.44, 0.8, 0);
      ctx.strokeStyle = 'rgba(255,255,255,0.55)'; ctx.lineWidth = 0.04;
      for (let i = -3; i <= 3; i++) { ctx.beginPath(); ctx.moveTo(i * 0.2, 0.2); ctx.lineTo(i * 0.16, 0.86); ctx.stroke(); }
      jellyCircle(ctx, 0, -0.12, 0.7, SK.brown);
      for (const [sx, sy, a] of SPRINKLES) {
        ctx.save(); ctx.translate(sx, sy - 0.05); ctx.rotate(a);
        ctx.fillStyle = '#3A1D14'; ctx.fillRect(-0.06, -0.018, 0.12, 0.036); ctx.restore();
      }
      ctx.fillStyle = 'rgba(255,255,255,0.75)'; ctx.beginPath(); ctx.ellipse(-0.28, -0.5, 0.12, 0.06, -0.6, 0, TAU); ctx.fill();
      break;
    }
    case 'cupcake':
      jelly(ctx, FOOD_PATHS.cupBase, SK.mint, -0.7, 0, 1.4, 0.92, 0);
      ctx.strokeStyle = 'rgba(255,255,255,0.5)'; ctx.lineWidth = 0.05;
      for (let i = -2; i <= 2; i++) { ctx.beginPath(); ctx.moveTo(i * 0.26, 0.05); ctx.lineTo(i * 0.2, 0.85); ctx.stroke(); }
      jelly(ctx, FOOD_PATHS.cupFrost, SK.pink, -0.9, -0.82, 1.8, 0.9);
      jellyCircle(ctx, 0.08, -0.8, 0.16, SK.red);
      ctx.strokeStyle = '#6CC35A'; ctx.lineWidth = 0.04; ctx.beginPath(); ctx.moveTo(0.1, -0.95); ctx.quadraticCurveTo(0.15, -1.05, 0.25, -1.08); ctx.stroke();
      break;
    case 'pudim':
      ctx.fillStyle = 'rgba(255,255,255,0.95)'; ctx.beginPath(); ctx.ellipse(0, 0.62, 0.98, 0.22, 0, 0, TAU); ctx.fill();
      ctx.strokeStyle = 'rgba(200,180,220,0.6)'; ctx.lineWidth = 0.04; ctx.stroke();
      jelly(ctx, FOOD_PATHS.pudim, SK.yellow, -0.8, -0.5, 1.6, 1.25);
      ctx.save(); ctx.clip(FOOD_PATHS.pudim);
      { const g = ctx.createLinearGradient(0, -0.55, 0, 0); g.addColorStop(0, '#C9762A'); g.addColorStop(1, '#A65516');
        ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(-1, -0.6); ctx.lineTo(1, -0.6); ctx.lineTo(1, -0.2);
        ctx.quadraticCurveTo(0.6, -0.22, 0.5, 0.05); ctx.quadraticCurveTo(0.42, -0.25, 0.15, -0.22);
        ctx.quadraticCurveTo(0, -0.05, -0.12, -0.22); ctx.quadraticCurveTo(-0.45, -0.25, -0.5, 0.1); ctx.quadraticCurveTo(-0.6, -0.2, -1, -0.2); ctx.fill(); }
      ctx.restore();
      ctx.fillStyle = 'rgba(255,255,255,0.8)'; ctx.beginPath(); ctx.ellipse(-0.25, -0.4, 0.16, 0.05, -0.1, 0, TAU); ctx.fill();
      break;
    case 'sabao':
      jelly(ctx, FOOD_PATHS.sabao, { light: '#FFE0F0', base: '#FFAED6', deep: '#F88BC2' }, -0.82, -0.48, 1.64, 0.96);
      for (const [bx, by, br] of [[-0.45, -0.6, 0.18], [-0.1, -0.72, 0.13], [0.3, -0.62, 0.2], [0.6, -0.78, 0.1]]) {
        ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.beginPath(); ctx.arc(bx, by, br, 0, TAU); ctx.fill();
        ctx.strokeStyle = 'rgba(150,200,240,0.7)'; ctx.lineWidth = 0.035; ctx.stroke();
      }
      ctx.save(); ctx.translate(0, 0.02); ctx.scale(0.24, 0.24); ctx.fillStyle = 'rgba(255,255,255,0.75)'; ctx.fill(HEART); ctx.restore();
      break;
    case 'chuveiro': {
      ctx.strokeStyle = '#B9C6D6'; ctx.lineWidth = 0.16;
      ctx.beginPath(); ctx.moveTo(-0.75, 0.9); ctx.lineTo(-0.75, -0.35); ctx.quadraticCurveTo(-0.75, -0.75, -0.3, -0.75); ctx.lineTo(0.05, -0.75); ctx.stroke();
      const head = P((p) => { p.moveTo(-0.15, -0.45); p.quadraticCurveTo(0.25, -0.98, 0.65, -0.45); p.closePath(); });
      jelly(ctx, head, SK.sky, -0.15, -0.85, 0.8, 0.42);
      ctx.fillStyle = '#62B2F4';
      for (let i = 0; i < 3; i++) { const yy = ((t * 1.6 + i / 3) % 1); ctx.globalAlpha = 1 - yy; ctx.beginPath(); ctx.ellipse(0.05 + i * 0.22, -0.3 + yy * 1.0, 0.05, 0.08, 0, 0, TAU); ctx.fill(); }
      ctx.globalAlpha = 1;
      break;
    }
    case 'bola': {
      const r = 0.95;
      jellyCircle(ctx, 0, 0, r, SK.yellow);
      ctx.save(); ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.clip();
      ctx.rotate(extra.spin || 0);
      ctx.fillStyle = 'rgba(255,110,160,0.75)';
      ctx.beginPath(); ctx.ellipse(0, 0, r * 0.38, r * 1.1, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = 'rgba(95,200,240,0.7)';
      ctx.beginPath(); ctx.ellipse(r * 0.95, 0, r * 0.25, r * 1.1, 0, 0, TAU); ctx.ellipse(-r * 0.95, 0, r * 0.25, r * 1.1, 0, 0, TAU); ctx.fill();
      ctx.restore();
      ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.beginPath(); ctx.ellipse(-0.35, -0.45, 0.22, 0.12, -0.7, 0, TAU); ctx.fill();
      break;
    }
    case 'bala': {
      const sk = extra.skin || SKINS.chiclete;
      for (const s of [-1, 1]) {
        const tw = P((p) => { p.moveTo(s * 0.45, 0); p.lineTo(s * 0.95, -0.38); p.quadraticCurveTo(s * 1.02, 0, s * 0.95, 0.38); p.closePath(); });
        jelly(ctx, tw, sk, s > 0 ? 0.45 : -1, -0.4, 0.55, 0.8, 0);
      }
      jelly(ctx, FOOD_PATHS.bala, sk, -0.55, -0.42, 1.1, 0.84);
      ctx.strokeStyle = 'rgba(255,255,255,0.6)'; ctx.lineWidth = 0.08;
      ctx.beginPath(); ctx.moveTo(-0.25, -0.35); ctx.quadraticCurveTo(-0.05, 0, -0.25, 0.35); ctx.moveTo(0.15, -0.38); ctx.quadraticCurveTo(0.35, 0, 0.15, 0.38); ctx.stroke();
      break;
    }
    case 'estrela':
      jelly(ctx, FOOD_PATHS.star, SK.gold, -0.95, -0.9, 1.9, 1.8);
      ctx.fillStyle = INK;
      ctx.beginPath(); ctx.arc(-0.17, 0.08, 0.07, 0, TAU); ctx.arc(0.17, 0.08, 0.07, 0, TAU); ctx.fill();
      ctx.strokeStyle = INK; ctx.lineWidth = 0.05; ctx.beginPath(); ctx.arc(0, 0.16, 0.08, 0.15 * Math.PI, 0.85 * Math.PI); ctx.stroke();
      break;
    case 'nuvem': {
      ctx.fillStyle = SK.gold.base;
      ctx.beginPath(); ctx.moveTo(0.05, 0.25); ctx.lineTo(-0.2, 0.62); ctx.lineTo(0.02, 0.6); ctx.lineTo(-0.12, 0.98); ctx.lineTo(0.28, 0.5); ctx.lineTo(0.06, 0.52); ctx.lineTo(0.22, 0.25); ctx.fill();
      jelly(ctx, FOOD_PATHS.nuvem, { light: '#D7D3E6', base: '#A7A1BD', deep: '#7F7898' }, -1, -0.72, 2, 1.05);
      ctx.strokeStyle = INK; ctx.fillStyle = INK; ctx.lineWidth = 0.07;
      ctx.beginPath(); ctx.moveTo(-0.42, -0.2); ctx.lineTo(-0.18, -0.1); ctx.moveTo(0.42, -0.2); ctx.lineTo(0.18, -0.1); ctx.stroke();
      ctx.beginPath(); ctx.arc(-0.27, 0.0, 0.06, 0, TAU); ctx.arc(0.27, 0.0, 0.06, 0, TAU); ctx.fill();
      ctx.beginPath(); ctx.arc(0, 0.2, 0.1, 1.15 * Math.PI, 1.85 * Math.PI); ctx.stroke();
      break;
    }
    case 'skin': {
      const sk = SKINS[extra.skin];
      const p = P((p) => { p.moveTo(0, 0.75); p.bezierCurveTo(0.65, 0.75, 0.85, 0.7, 0.85, 0.3); p.bezierCurveTo(0.85, -0.35, 0.5, -0.7, 0, -0.7); p.bezierCurveTo(-0.5, -0.7, -0.85, -0.35, -0.85, 0.3); p.bezierCurveTo(-0.85, 0.7, -0.65, 0.75, 0, 0.75); });
      jelly(ctx, p, sk, -0.85, -0.7, 1.7, 1.45);
      ctx.fillStyle = INK; ctx.beginPath(); ctx.arc(-0.26, 0.12, 0.07, 0, TAU); ctx.arc(0.26, 0.12, 0.07, 0, TAU); ctx.fill();
      ctx.strokeStyle = INK; ctx.lineWidth = 0.05; ctx.beginPath(); ctx.arc(0, 0.12, 0.08, 0.2 * Math.PI, 0.8 * Math.PI); ctx.stroke();
      break;
    }
  }
  ctx.restore();
}

// Paint an item into a small DOM canvas, crisp at device pixel ratio.
function paintIcon(cv, fn) {
  const dpr = Math.min(window.devicePixelRatio || 1, 3);
  const r = cv.getBoundingClientRect();
  const w = r.width || parseFloat(getComputedStyle(cv).width) || 48, h = r.height || w;
  cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr);
  const c = cv.getContext('2d'); c.setTransform(dpr, 0, 0, dpr, 0, 0); c.clearRect(0, 0, w, h);
  fn(c, w, h);
}

// ============================================================ particles
class Particles {
  constructor() { this.list = []; }
  add(p) {
    this.list.push(Object.assign({ x: 0, y: 0, vx: 0, vy: 0, g: 0, drag: 0, life: 1, age: 0, size: 10, rot: 0, vr: 0, type: 'sparkle', color: '#fff' }, p));
    if (this.list.length > 260) this.list.shift();
  }
  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i]; p.age += dt;
      if (p.age >= p.life) { this.list.splice(i, 1); continue; }
      p.vy += p.g * dt; const k = Math.max(0, 1 - p.drag * dt); p.vx *= k; p.vy *= k;
      p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
      if (p.floor != null && p.y > p.floor) { p.y = p.floor; p.vy *= -0.35; p.vx *= 0.7; }
    }
  }
  draw(ctx) {
    for (const p of this.list) {
      const k = p.age / p.life;
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
      switch (p.type) {
        case 'heart': {
          const s = p.size * (k < 0.15 ? easeOut(k / 0.15) : 1) ;
          ctx.globalAlpha = 1 - k * k; ctx.translate(Math.sin(p.age * 5 + p.ph) * 4, 0); ctx.scale(s, s);
          jelly(ctx, HEART, SK.pink, -1, -0.8, 2, 1.7);
          break;
        }
        case 'sparkle': drawSparkle(ctx, 0, 0, p.size * Math.sin(k * Math.PI), p.color, 1); break;
        case 'crumb': ctx.globalAlpha = 1 - k; ctx.fillStyle = p.color; ctx.beginPath(); ctx.arc(0, 0, p.size, 0, TAU); ctx.fill(); break;
        case 'bubble': {
          const s = p.size * (0.6 + k * 0.5); ctx.globalAlpha = k > 0.85 ? (1 - k) / 0.15 : 1;
          ctx.translate(Math.sin(p.age * 4 + p.ph) * 5, 0);
          ctx.fillStyle = 'rgba(255,255,255,0.35)'; ctx.strokeStyle = 'rgba(140,200,240,0.8)'; ctx.lineWidth = Math.max(1, s * 0.12);
          ctx.beginPath(); ctx.arc(0, 0, s, 0, TAU); ctx.fill(); ctx.stroke();
          ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(-s * 0.35, -s * 0.35, s * 0.22, 0, TAU); ctx.fill();
          break;
        }
        case 'drop':
          ctx.globalAlpha = 0.85 * (1 - k * 0.3); ctx.fillStyle = p.color;
          ctx.rotate(Math.atan2(p.vy, p.vx) - Math.PI / 2);
          ctx.beginPath(); ctx.ellipse(0, 0, p.size * 0.45, p.size, 0, 0, TAU); ctx.fill();
          break;
        case 'z':
          ctx.globalAlpha = Math.sin(k * Math.PI); ctx.fillStyle = '#9C83F0';
          ctx.font = `600 ${p.size * (0.7 + k * 0.6)}px Fredoka, sans-serif`; ctx.textAlign = 'center'; ctx.fillText('z', 0, 0);
          break;
        case 'text': {
          const s = k < 0.2 ? easeOut(k / 0.2) * 1.1 : 1;
          ctx.globalAlpha = k > 0.7 ? (1 - k) / 0.3 : 1; ctx.scale(s, s);
          ctx.font = `700 ${p.size}px Fredoka, sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
          ctx.lineWidth = p.size * 0.22; ctx.strokeStyle = '#fff'; ctx.strokeText(p.text, 0, 0);
          ctx.fillStyle = p.color; ctx.fillText(p.text, 0, 0);
          break;
        }
        case 'confetti':
          ctx.globalAlpha = k > 0.8 ? (1 - k) / 0.2 : 1; ctx.fillStyle = p.color;
          ctx.scale(1, Math.cos(p.age * 9 + p.ph)); ctx.fillRect(-p.size / 2, -p.size / 3, p.size, p.size * 0.66);
          break;
        case 'note':
          ctx.globalAlpha = Math.sin(k * Math.PI); ctx.fillStyle = p.color;
          ctx.font = `700 ${p.size}px Fredoka, sans-serif`; ctx.textAlign = 'center'; ctx.fillText('♪', Math.sin(p.age * 4) * 6, 0);
          break;
        case 'ring':
          ctx.globalAlpha = 1 - k; ctx.strokeStyle = p.color; ctx.lineWidth = 3 * (1 - k) + 0.5;
          ctx.beginPath(); ctx.arc(0, 0, p.size * easeOut(k), 0, TAU); ctx.stroke();
          break;
      }
      ctx.restore();
    }
  }
}
const FX = new Particles();
const CONFETTI_COLORS = ['#FF8CC0', '#FFC94D', '#7FE6C6', '#A98BFF', '#7CCBFF', '#FFA58C'];
function emitHearts(x, y, n = 3) { for (let i = 0; i < n; i++) FX.add({ type: 'heart', x: x + rand(-24, 24), y: y + rand(-10, 10), vx: rand(-25, 25), vy: rand(-95, -60), life: rand(1.1, 1.6), size: rand(9, 15), ph: rand(0, TAU), drag: 0.6 }); }
function emitSparkles(x, y, n = 6, spread = 40, color = '#FFFFFF') { for (let i = 0; i < n; i++) FX.add({ type: 'sparkle', x: x + rand(-spread, spread), y: y + rand(-spread, spread), vy: rand(-30, -5), life: rand(0.5, 0.9), size: rand(5, 11), color }); }
function emitText(x, y, text, color = '#FF7FB5', size = 22) { FX.add({ type: 'text', x, y, vy: -55, drag: 1.2, life: 1.1, size, text, color }); }
function emitConfetti(x, y, n = 40) { for (let i = 0; i < n; i++) FX.add({ type: 'confetti', x, y, vx: rand(-220, 220), vy: rand(-420, -160), g: 600, drag: 1.4, life: rand(1.4, 2.2), size: rand(6, 10), rot: rand(0, TAU), vr: rand(-8, 8), ph: rand(0, TAU), color: pick(CONFETTI_COLORS) }); }

// ============================================================ DOM refs
const app = $('#app');
const scene = $('#scene');
const ctx = scene.getContext('2d');
const toastEl = $('#toast');
const ghostEl = $('#ghost');
const gctx = ghostEl.getContext('2d');

let W = 1, H = 1, DPR = 1, groundY = 1;
function resizeScene() {
  const r = scene.getBoundingClientRect();
  DPR = Math.min(window.devicePixelRatio || 1, 2);
  W = Math.max(1, r.width); H = Math.max(1, r.height);
  scene.width = Math.round(W * DPR); scene.height = Math.round(H * DPR);
  layoutPet();
}

// ============================================================ pet runtime
const pet = {
  x: 0, R: 80,
  sq: new Spring(0, 230, 10), rot: new Spring(0, 140, 8), ear: new Spring(0, 110, 4.5),
  lookX: new Spring(0, 90, 13), lookY: new Spring(0, 90, 13), mouth: new Spring(0, 220, 18),
  hopY: 0, hopV: 0,
  blinkT: 2.5, blink: 0, joy: 0, chew: 0, chewTick: 0, dizzy: 0, pokes: 0, refuse: 0,
  idleT: 4, idleLook: { x: 0, y: 0, t: 0 },
  foam: [], showerDone: false,
  bubbleT: 6, bubbleOn: 0, bubbleS: new Spring(0, 200, 14), need: null,
  zT: 0, snoreT: 0, petDist: 0, purrT: 0,
};
function layoutPet() {
  pet.R = Math.min(W * 0.22, H * 0.19);
  pet.x = W / 2;
  groundY = H * 0.84;
}
function petSpec() { return SPEC[S.species]; }
function petTopY() { return groundY + pet.hopY - petSpec().h * pet.R; }
function petHit(x, y, pad = 1.08) {
  const d = petSpec(), R = pet.R;
  const cy = groundY + pet.hopY - d.h * R * 0.5;
  const nx = (x - pet.x) / (d.w * R), ny = (y - cy) / (d.h * R * 0.5);
  return nx * nx + ny * ny <= pad * pad;
}
function mouthPos() {
  const d = petSpec();
  return { x: pet.x, y: groundY + pet.hopY + d.mouthY * pet.R * (1 - pet.sq.v) };
}
function hop(power = 6) {
  if (pet.hopY < 0 || S.sleeping) return;
  pet.hopV = -pet.R * power; pet.hopY = -0.01; pet.sq.kick(-3.2);
}
function poke(x, y) {
  if (S.sleeping) {
    pet.sq.kick(2); pet.rot.kick(rand(-1.5, 1.5)); Snd.squish();
    if (Math.random() < 0.5) toast('Shhh… está dormindo');
    return;
  }
  pet.pokes += 1;
  pet.sq.kick(3.6 + Math.random()); pet.rot.kick((x - pet.x) / pet.R * -3 + rand(-1, 1)); pet.ear.kick(rand(-9, 9));
  if (pet.pokes > 6) {
    pet.dizzy = 1.6; pet.pokes = 0; Snd.ouch(); toast(`${S.name} ficou tontinho!`);
    emitSparkles(pet.x, petTopY(), 6, 30, '#FFD054');
    return;
  }
  Snd.poke();
  pet.joy = Math.max(pet.joy, 0.5);
  emitHearts(x, y - 10, 1);
  addStat('fun', 0.7);
  if (Math.random() < 0.25) hop(4.5);
}

function addStat(k, v) {
  const before = S.stats[k];
  S.stats[k] = clamp(before + v, 0, 100);
  if (v >= 3) bumpNeed(k);
}
function bumpNeed(k) {
  const el = $(`.need[data-stat="${k}"] .ring`);
  if (!el) return; el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump');
}
function addCoins(n) {
  S.coins = Math.max(0, S.coins + n);
  const el = $('#coinPill'); el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump');
  renderHUD();
}
function addXP(n) {
  S.xp += n;
  let need = S.level * 40;
  while (S.xp >= need) {
    S.xp -= need; S.level += 1; need = S.level * 40;
    S.coins += 20;
    Snd.levelup();
    emitConfetti(W / 2, H * 0.35, 60);
    toast(`Nível ${S.level}! Você ganhou 20 moedas`);
    hop(7);
  }
  renderHUD();
}

function expression() {
  if (S.sleeping) return { eyes: 'sleep', mouth: 'o' };
  if (pet.dizzy > 0) return { eyes: 'swirl', mouth: 'wavy' };
  if (pet.refuse > 0) return { eyes: 'x', mouth: 'flat' };
  if (pet.joy > 0) return { eyes: 'happy', mouth: 'grin' };
  const st = S.stats;
  const m = Math.min(st.hunger, st.energy, st.fun, st.clean);
  return { eyes: st.energy < 22 ? 'tired' : 'open', mouth: m < 22 ? 'frown' : m < 45 ? 'flat' : 'smile' };
}

function lowestNeed() {
  let best = null, v = 30;
  for (const k of ['hunger', 'energy', 'fun', 'clean']) if (S.stats[k] < v) { v = S.stats[k]; best = k; }
  return best;
}

// ============================================================ interaction state
const pointer = { x: 0, y: 0, down: false, onPet: false, last: -10, id: null, lastX: 0, lastY: 0 };
const drag = { on: false, kind: null, id: null, el: null, x: 0, y: 0, vx: 0, mode: null, t: 0, fromX: 0, fromY: 0, sx: 0, sy: 0, rot: 0, scale: 1, scrub: 0 };
const ball = { x: 0, y: 0, vx: 0, vy: 0, r: 26, held: false, spin: 0, hitCD: 0, hx: [], placed: false };
let showering = false, showerT = 0;
let roomFade = 0, prevRoom = null;
let darkness = 0;
let T = 0;

function toScene(e) { const r = scene.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; }

scene.addEventListener('pointerdown', (e) => {
  Snd.ensure();
  const p = toScene(e);
  pointer.down = true; pointer.id = e.pointerId; pointer.x = p.x; pointer.y = p.y; pointer.lastX = p.x; pointer.lastY = p.y; pointer.last = T;
  try { scene.setPointerCapture(e.pointerId); } catch (_) { /* ignore */ }
  if (S.room === 'play' && Math.hypot(p.x - ball.x, p.y - ball.y) < ball.r * 1.6) {
    ball.held = true; ball.hx = [{ x: p.x, y: p.y, t: T }]; Snd.tap(); return;
  }
  if (S.room === 'bedroom' && lampHit(p.x, p.y)) { toggleSleep(); return; }
  if (petHit(p.x, p.y)) { pointer.onPet = true; pet.petDist = 0; poke(p.x, p.y); }
});
scene.addEventListener('pointermove', (e) => {
  const p = toScene(e);
  pointer.x = p.x; pointer.y = p.y; pointer.last = T;
  if (ball.held) {
    ball.x = p.x; ball.y = Math.min(p.y, groundY - ball.r * 0.4); ball.vx = 0; ball.vy = 0;
    ball.hx.push({ x: p.x, y: p.y, t: T }); if (ball.hx.length > 6) ball.hx.shift();
    return;
  }
  if (pointer.down && pointer.onPet && !S.sleeping) {
    const d = Math.hypot(p.x - pointer.lastX, p.y - pointer.lastY);
    pet.petDist += d;
    if (pet.petDist > 38 && petHit(p.x, p.y, 1.2)) {
      pet.petDist = 0; pet.joy = Math.max(pet.joy, 0.7); pet.pokes = 0;
      pet.sq.kick(rand(-0.8, 0.8)); pet.rot.kick((p.x - pointer.lastX) * 0.02);
      emitHearts(p.x, p.y - 12, 1); addStat('fun', 0.6);
      if (T - pet.purrT > 0.5) { pet.purrT = T; Snd.giggle(); }
    }
  }
  pointer.lastX = p.x; pointer.lastY = p.y;
});
function endScenePointer(e) {
  if (e.pointerId !== pointer.id) return;
  pointer.down = false; pointer.onPet = false;
  if (ball.held) {
    ball.held = false;
    const h = ball.hx; if (h.length >= 2) {
      const a = h[0], b = h[h.length - 1], dt = Math.max(0.016, b.t - a.t);
      ball.vx = clamp((b.x - a.x) / dt, -1600, 1600); ball.vy = clamp((b.y - a.y) / dt, -1800, 1400);
    }
    if (Math.hypot(ball.vx, ball.vy) > 300) Snd.whoosh();
  }
}
scene.addEventListener('pointerup', endScenePointer);
scene.addEventListener('pointercancel', endScenePointer);
scene.addEventListener('pointerleave', (e) => { if (e.pointerType === 'mouse') pointer.last = -10; });

// ---- tray drag & drop (food and soap)
function bindDraggable(el, kind, id) {
  el.addEventListener('pointerdown', (e) => {
    if (e.button > 0 || MG.open) return;
    Snd.ensure();
    const st = { x: e.clientX, y: e.clientY, pid: e.pointerId, started: false };
    const move = (ev) => {
      if (ev.pointerId !== st.pid) return;
      const dx = ev.clientX - st.x, dy = ev.clientY - st.y;
      if (!st.started) {
        const far = Math.hypot(dx, dy) > 8;
        if (far && (kind !== 'food' || (dy < -3 && Math.abs(dy) > Math.abs(dx) * 0.6))) {
          st.started = true;
          if (!beginDrag(kind, id, el, ev)) { cleanup(); }
        } else if (far && Math.abs(dx) > 12) cleanup();
        return;
      }
      ev.preventDefault();
      moveDrag(ev.clientX, ev.clientY);
    };
    const up = (ev) => {
      if (ev.pointerId !== st.pid) return;
      cleanup();
      if (st.started) endDrag(ev.type === 'pointercancel');
      else if (ev.type === 'pointerup') tapItem(kind, id, el);
    };
    const cleanup = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
      window.removeEventListener('pointercancel', up);
    };
    window.addEventListener('pointermove', move, { passive: false });
    window.addEventListener('pointerup', up);
    window.addEventListener('pointercancel', up);
  });
}
function canAfford(food, el) {
  if (S.coins >= food.price) return true;
  Snd.nope(); toast('Moedas insuficientes. Jogue a Chuva de Doces!');
  if (el) { el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake'); }
  const c = $('#coinPill'); c.classList.remove('shake'); void c.offsetWidth; c.classList.add('shake');
  return false;
}
function paintGhost(kind, id) {
  const dpr = Math.min(window.devicePixelRatio || 1, 3);
  ghostEl.width = 88 * dpr; ghostEl.height = 88 * dpr;
  gctx.setTransform(dpr, 0, 0, dpr, 0, 0); gctx.clearRect(0, 0, 88, 88);
  drawItem(gctx, kind === 'soap' ? 'sabao' : id, 44, 44, 62, T);
}
function beginDrag(kind, id, el, ev) {
  if (kind === 'food' && !canAfford(FOODS.find((f) => f.id === id), el)) return false;
  Object.assign(drag, { on: true, kind, id, el, x: ev.clientX, y: ev.clientY, vx: 0, mode: 'drag', t: 0, rot: 0, scale: 0.6, scrub: 0 });
  const r = el.getBoundingClientRect(); drag.fromX = r.left + r.width / 2; drag.fromY = r.top + r.height / 2;
  paintGhost(kind, id);
  ghostEl.style.display = 'block';
  el.classList.add('lifted');
  Snd.tap();
  return true;
}
function moveDrag(cx, cy) {
  drag.vx = lerp(drag.vx, cx - drag.x, 0.5);
  const lastX = drag.x, lastY = drag.y;
  drag.x = cx; drag.y = cy;
  if (drag.kind === 'soap') {
    const r = scene.getBoundingClientRect();
    const sx = cx - r.left, sy = cy - r.top;
    if (petHit(sx, sy, 1.05)) {
      drag.scrub += Math.hypot(cx - lastX, cy - lastY);
      if (drag.scrub > 16) { drag.scrub = 0; addFoam(sx, sy); }
    }
  }
}
function endDrag(cancelled) {
  if (!drag.on) return;
  if (drag.kind === 'food' && !cancelled) {
    const r = scene.getBoundingClientRect(), m = mouthPos();
    const d = Math.hypot(drag.x - (r.left + m.x), drag.y - (r.top + m.y));
    if (d < pet.R * 1.15 && tryEat(drag.id)) { finishGhost(); return; }
  }
  drag.mode = 'return'; drag.t = 0; drag.sx = drag.x; drag.sy = drag.y;
}
function tapItem(kind, id, el) {
  if (kind === 'soap') { Snd.tap(); toast('Arraste o sabonete e esfregue no bichinho'); return; }
  if (kind === 'food') {
    const food = FOODS.find((f) => f.id === id);
    if (!canAfford(food, el)) return;
    if (S.sleeping) { toast('Está dormindo. Acenda a luz primeiro'); return; }
    if (S.stats.hunger > 96) { refuseFood(); return; }
    const r = el.getBoundingClientRect();
    Object.assign(drag, { on: true, kind, id, el, mode: 'fly', t: 0, rot: 0, scale: 0.7, sx: r.left + r.width / 2, sy: r.top + r.height / 2 });
    drag.x = drag.sx; drag.y = drag.sy; drag.fromX = drag.sx; drag.fromY = drag.sy;
    paintGhost(kind, id); ghostEl.style.display = 'block'; el.classList.add('lifted');
    Snd.whoosh();
  }
}
function finishGhost() {
  drag.on = false; ghostEl.style.display = 'none';
  if (drag.el) drag.el.classList.remove('lifted');
}
function updateGhost(dt) {
  if (!drag.on) return;
  const r = scene.getBoundingClientRect(), m = mouthPos();
  const mx = r.left + m.x, my = r.top + m.y;
  if (drag.mode === 'drag') {
    drag.scale = lerp(drag.scale, 1.05, 1 - Math.exp(-dt * 14));
    drag.rot = lerp(drag.rot, clamp(drag.vx * 0.03, -0.5, 0.5), 1 - Math.exp(-dt * 12));
    drag.vx *= Math.exp(-dt * 8);
  } else if (drag.mode === 'fly') {
    drag.t += dt / 0.5;
    const k = easeOut(Math.min(1, drag.t));
    drag.x = lerp(drag.sx, mx, k); drag.y = lerp(drag.sy, my, k) - Math.sin(k * Math.PI) * 70;
    drag.scale = lerp(0.7, 0.9, k); drag.rot = Math.sin(k * Math.PI) * 0.6;
    if (drag.t >= 1) { if (!tryEat(drag.id)) { drag.mode = 'return'; drag.t = 0; drag.sx = drag.x; drag.sy = drag.y; } else finishGhost(); }
  } else if (drag.mode === 'return') {
    drag.t += dt / 0.35;
    const k = easeOut(Math.min(1, drag.t));
    drag.x = lerp(drag.sx, drag.fromX || drag.sx, k); drag.y = lerp(drag.sy, drag.fromY || drag.sy, k);
    drag.scale = lerp(1, 0.5, k); drag.rot *= 0.9;
    if (drag.t >= 1) finishGhost();
  }
  if (!drag.on) return;
  ghostEl.style.transform = `translate3d(${drag.x - 44}px, ${drag.y - 44}px, 0) rotate(${drag.rot}rad) scale(${drag.scale})`;
}
function foodNearMouth() {
  if (!drag.on || drag.kind !== 'food') return false;
  const r = scene.getBoundingClientRect(), m = mouthPos();
  return Math.hypot(drag.x - (r.left + m.x), drag.y - (r.top + m.y)) < pet.R * 1.9;
}
function refuseFood() {
  pet.refuse = 0.9; pet.rot.kick(3); Snd.nope();
  toast(`${S.name} está cheio!`);
}
function tryEat(id) {
  const food = FOODS.find((f) => f.id === id);
  if (S.sleeping) { toast('Está dormindo. Acenda a luz primeiro'); return false; }
  if (S.stats.hunger > 96) { refuseFood(); return false; }
  if (S.coins < food.price) { canAfford(food); return false; }
  addCoins(-food.price);
  addStat('hunger', food.hunger); if (food.fun) addStat('fun', food.fun);
  addXP(4);
  pet.chew = 1.15; pet.chewTick = 0; pet.mouth.kick(-6); pet.sq.kick(2.4);
  const m = mouthPos();
  emitText(m.x, m.y - pet.R * 0.9, `+${food.hunger}`, '#FF8A6A', 22);
  if (!S.tips.fed) { S.tips.fed = true; }
  return true;
}

// ---- bath
function addFoam(sx, sy) {
  const R = pet.R;
  const ux = (sx - pet.x) / R + rand(-0.08, 0.08), uy = (sy - (groundY + pet.hopY)) / R + rand(-0.08, 0.08);
  if (pet.foam.length < 46) pet.foam.push({ x: ux, y: uy, r: rand(0.07, 0.15), born: T, ph: rand(0, TAU), pop: null });
  addStat('clean', 0.9);
  pet.joy = Math.max(pet.joy, 0.4);
  pet.sq.kick(rand(-0.6, 0.6));
  if (Math.random() < 0.5) Snd.bubble();
  if (Math.random() < 0.3) FX.add({ type: 'bubble', x: sx + rand(-10, 10), y: sy, vx: rand(-20, 20), vy: rand(-60, -30), life: rand(1, 1.8), size: rand(4, 9), ph: rand(0, TAU) });
  pet.showerDone = false;
}
function updateShower(dt) {
  if (!showering || S.room !== 'bath') return;
  showerT += dt;
  const top = 0, R = pet.R, d = petSpec();
  for (let i = 0; i < 3; i++) FX.add({ type: 'drop', x: pet.x + rand(-d.w * R * 1.1, d.w * R * 1.1), y: top + rand(-10, 20), vy: rand(700, 900), vx: rand(-15, 15), life: rand(0.45, 0.6), size: rand(4, 7), color: '#7CC8F5', floor: petTopY() + rand(0, R * 0.35) });
  if (showerT > 0.07) {
    showerT = 0;
    const alive = pet.foam.filter((b) => b.pop == null);
    if (alive.length) { const b = pick(alive); b.pop = 1; addStat('clean', 1.1); Snd.splash(); }
    else {
      addStat('clean', 0.25);
      if (!pet.showerDone && S.stats.clean > 92) {
        pet.showerDone = true; pet.joy = 1.4; Snd.happy(); addXP(6);
        emitSparkles(pet.x, groundY - d.h * R * 0.6, 12, R, '#FFFFFF');
        toast('Limpinho e cheiroso!');
      }
    }
  }
  pet.joy = Math.max(pet.joy, 0.2);
}

// ---- sleep
function toggleSleep(force) {
  const next = force != null ? force : !S.sleeping;
  if (next === S.sleeping) return;
  S.sleeping = next;
  Snd.lamp();
  if (S.sleeping) { pet.foam.length = 0; pet.zT = 0; }
  else { pet.sq.kick(-2); pet.joy = S.stats.energy > 70 ? 0.8 : 0; }
  renderLamp();
}
function renderLamp() {
  const b = $('#lampBtn');
  b.classList.toggle('off', S.sleeping);
  $('#lampLbl').textContent = S.sleeping ? 'Acender a luz' : 'Apagar a luz';
  $('#sleepHint').textContent = S.sleeping ? `${S.name} está dormindo… a energia está subindo` : 'Apague a luz para recarregar a energia';
}
function lampPos() { return { x: W * 0.86, y: groundY - pet.R * 0.55 }; }
function lampHit(x, y) { const l = lampPos(); return Math.abs(x - l.x) < 34 && y > l.y - pet.R * 1.9 && y < l.y + 10; }

// ---- ball
function resetBall() {
  ball.x = W * 0.8; ball.y = groundY - ball.r; ball.vx = 0; ball.vy = 0; ball.placed = true;
}
function updateBall(dt) {
  if (S.room !== 'play') return;
  if (!ball.placed) resetBall();
  ball.r = Math.max(20, pet.R * 0.32);
  ball.hitCD -= dt;
  if (ball.held) { ball.spin += dt * 2; return; }
  const floor = groundY - ball.r * 0.9;
  ball.vy += 1900 * dt; ball.x += ball.vx * dt; ball.y += ball.vy * dt;
  ball.spin += ball.vx * dt / ball.r;
  if (ball.y > floor) { ball.y = floor; if (Math.abs(ball.vy) > 140) { ball.vy *= -0.62; Snd.tone(300, 260, 0.05, 'sine', 0.06); } else ball.vy = 0; ball.vx *= 0.985; }
  if (ball.y < ball.r) { ball.y = ball.r; ball.vy = Math.abs(ball.vy) * 0.6; }
  if (ball.x < ball.r) { ball.x = ball.r; ball.vx = Math.abs(ball.vx) * 0.7; }
  if (ball.x > W - ball.r) { ball.x = W - ball.r; ball.vx = -Math.abs(ball.vx) * 0.7; }
  // collide with pet (approx. circle around body center)
  const d = petSpec(), R = pet.R;
  const pcx = pet.x, pcy = groundY + pet.hopY - d.h * R * 0.5, pr = Math.min(d.w, d.h * 0.55) * R;
  const dx = ball.x - pcx, dy = ball.y - pcy, dist = Math.hypot(dx, dy);
  if (dist < pr + ball.r && dist > 0.001) {
    const nx = dx / dist, ny = dy / dist;
    ball.x = pcx + nx * (pr + ball.r); ball.y = pcy + ny * (pr + ball.r);
    const vn = ball.vx * nx + ball.vy * ny;
    if (vn < 0) { ball.vx -= 1.75 * vn * nx; ball.vy -= 1.75 * vn * ny; }
    const sp = Math.abs(vn);
    if (sp > 180 && ball.hitCD <= 0) {
      ball.hitCD = 0.35;
      pet.sq.kick(clamp(sp / 260, 1, 4.5)); pet.rot.kick(-nx * 3); pet.ear.kick(rand(-10, 10));
      if (!S.sleeping) { pet.joy = 0.9; addStat('fun', 4); addXP(1); Snd.boing(); emitHearts(ball.x, ball.y, 1); if (Math.random() < 0.4) hop(5); }
    }
  }
}

// ============================================================ rooms
function setRoom(room, instant) {
  if (!ROOMS[room]) room = 'kitchen';
  if (room === S.room && !instant) return;
  if (S.room === 'bedroom' && room !== 'bedroom' && S.sleeping) toggleSleep(false);
  if (!instant) { prevRoom = S.room; roomFade = 1; Snd.tap(); hop(4); }
  S.room = room;
  app.dataset.room = room;
  $$('.tabs button').forEach((b, i) => {
    const on = b.dataset.room === room; b.classList.toggle('on', on);
    if (on) { const blob = $('#tabBlob'); blob.style.transform = `translateX(${i * 100}%)`; blob.classList.toggle('go'); }
  });
  $$('.panel').forEach((p) => p.classList.toggle('on', p.dataset.panel === room));
  const chip = $('#roomChip'); chip.textContent = ROOMS[room].name; chip.classList.add('swap'); void chip.offsetWidth; chip.classList.remove('swap');
  if (room === 'play') resetBall();
  if (room === 'closet') renderCloset();
  showering = false;
}

function drawRoom(c, room, alpha) {
  const R = ROOMS[room];
  const hz = groundY - pet.R * 0.62;
  c.save(); c.globalAlpha = alpha;
  let g = c.createLinearGradient(0, 0, 0, hz); g.addColorStop(0, R.wall[0]); g.addColorStop(1, R.wall[1]);
  c.fillStyle = g; c.fillRect(0, 0, W, hz + 1);
  g = c.createLinearGradient(0, hz, 0, H); g.addColorStop(0, R.floor[0]); g.addColorStop(1, R.floor[1]);
  c.fillStyle = g; c.fillRect(0, hz, W, H - hz);
  c.fillStyle = 'rgba(255,255,255,0.65)'; c.fillRect(0, hz, W, 2);
  g = c.createLinearGradient(0, hz, 0, hz + 30); g.addColorStop(0, 'rgba(120,80,140,0.07)'); g.addColorStop(1, 'rgba(120,80,140,0)');
  c.fillStyle = g; c.fillRect(0, hz + 2, W, 30);
  DECOR[room](c, hz);
  c.restore();
}
function windowFrame(c, x, y, w, h, sky, inner) {
  const p = P((p) => rrect(p, x, y, w, h, 20));
  c.fillStyle = '#FFFFFF'; c.fill(p);
  const q = P((p) => rrect(p, x + 7, y + 7, w - 14, h - 14, 14));
  const g = c.createLinearGradient(0, y, 0, y + h); g.addColorStop(0, sky[0]); g.addColorStop(1, sky[1]);
  c.fillStyle = g; c.fill(q);
  c.save(); c.clip(q); inner(c, x + 7, y + 7, w - 14, h - 14); c.restore();
  c.fillStyle = 'rgba(255,255,255,0.9)'; c.fillRect(x + w / 2 - 3, y + 7, 6, h - 14);
  c.fillStyle = 'rgba(255,255,255,0.3)'; c.beginPath(); c.moveTo(x + 18, y + h - 14); c.lineTo(x + 40, y + 10); c.lineTo(x + 52, y + 10); c.lineTo(x + 30, y + h - 14); c.fill();
}
function cloud(c, x, y, s, a = 1) {
  c.fillStyle = `rgba(255,255,255,${a})`; c.beginPath();
  c.arc(x, y, s * 0.75, 0, TAU); c.moveTo(x + s * 1.75, y - s * 0.4); c.arc(x + s * 0.9, y - s * 0.4, s * 0.85, 0, TAU);
  c.moveTo(x + s * 2.4, y); c.arc(x + s * 1.75, y, s * 0.65, 0, TAU); c.moveTo(x + s * 1.75, y + s * 0.1); c.arc(x + s * 0.9, y + s * 0.1, s * 0.85, 0, TAU); c.fill();
}
const DECOR = {
  kitchen(c, hz) {
    const ww = Math.min(W * 0.3, 130), wh = ww * 0.82, wx = W * 0.07, wy = H * 0.1;
    windowFrame(c, wx, wy, ww, wh, ['#BFE6FF', '#FFE2EC'], (c, x, y, w, h) => {
      c.fillStyle = '#FFE58A'; c.beginPath(); c.arc(x + w * 0.72, y + h * 0.3, w * 0.13, 0, TAU); c.fill();
      cloud(c, x + ((T * 8) % (w + 60)) - 40, y + h * 0.62, w * 0.1, 0.95);
    });
    const sx = W * 0.64, sw = W * 0.3, sy = H * 0.3;
    c.fillStyle = '#FFFFFF'; c.beginPath(); rrectPath(c, sx, sy, sw, 9, 5); c.fill();
    c.fillStyle = 'rgba(160,110,140,0.12)'; c.fillRect(sx + 6, sy + 9, sw - 12, 4);
    const jars = [SKINS.pessego, SKINS.menta, SKINS.chiclete];
    const jw = Math.min(sw / 4, 30);
    jars.forEach((sk, i) => {
      const jx = sx + sw * 0.12 + i * (sw * 0.3), jh = jw * (1.1 + (i % 2) * 0.25);
      const p = P((p) => rrect(p, jx, sy - jh, jw, jh, jw * 0.3));
      jelly(c, p, sk, jx, sy - jh, jw, jh);
      c.fillStyle = '#FFFFFF'; c.beginPath(); rrectPath(c, jx - 2, sy - jh - 6, jw + 4, 8, 4); c.fill();
    });
  },
  bath(c, hz) {
    const s = 44; c.strokeStyle = 'rgba(255,255,255,0.75)'; c.lineWidth = 2;
    for (let y = 0; y < hz; y += s) for (let x = (y / s) % 2 ? -s / 2 : 0; x < W; x += s) { c.beginPath(); rrectPath(c, x + 3, y + 3, s - 6, s - 6, 9); c.stroke(); }
    const mx = W * 0.83, my = H * 0.22, mr = Math.min(W * 0.11, 46);
    c.fillStyle = '#FFFFFF'; c.beginPath(); c.ellipse(mx, my, mr + 6, mr * 1.3 + 6, 0, 0, TAU); c.fill();
    const g = c.createLinearGradient(mx - mr, my - mr, mx + mr, my + mr); g.addColorStop(0, '#E6F6FF'); g.addColorStop(1, '#BFE3F7');
    c.fillStyle = g; c.beginPath(); c.ellipse(mx, my, mr, mr * 1.3, 0, 0, TAU); c.fill();
    c.strokeStyle = 'rgba(255,255,255,0.8)'; c.lineWidth = 4; c.beginPath(); c.moveTo(mx - mr * 0.4, my - mr * 0.5); c.lineTo(mx - mr * 0.1, my - mr * 0.9); c.stroke();
    for (let i = 0; i < 6; i++) {
      const bx = (i * 97 + 40) % W, by = hz - ((T * (14 + i * 3) + i * 70) % hz), br = 4 + (i % 3) * 3;
      c.strokeStyle = 'rgba(140,200,240,0.5)'; c.lineWidth = 1.5; c.beginPath(); c.arc(bx + Math.sin(T + i) * 6, by, br, 0, TAU); c.stroke();
    }
    // duck
    const dx = W * 0.14, dy = groundY - 6, ds = Math.max(16, pet.R * 0.22);
    const body = P((p) => { p.ellipse(dx, dy - ds * 0.5, ds, ds * 0.62, 0, 0, TAU); });
    jelly(c, body, SK.yellow, dx - ds, dy - ds * 1.1, ds * 2, ds * 1.24);
    jellyCircle(c, dx + ds * 0.45, dy - ds * 1.2, ds * 0.5, SK.yellow);
    c.fillStyle = '#FF9A4D'; c.beginPath(); c.ellipse(dx + ds * 0.95, dy - ds * 1.12, ds * 0.22, ds * 0.11, 0, 0, TAU); c.fill();
    c.fillStyle = INK; c.beginPath(); c.arc(dx + ds * 0.6, dy - ds * 1.3, ds * 0.07, 0, TAU); c.fill();
  },
  bedroom(c, hz) {
    const ww = Math.min(W * 0.3, 130), wh = ww * 0.95, wx = W * 0.07, wy = H * 0.08;
    windowFrame(c, wx, wy, ww, wh, ['#3D3A78', '#7B6BC0'], (c, x, y, w, h) => {
      c.fillStyle = '#FFF4C7'; c.beginPath(); c.arc(x + w * 0.7, y + h * 0.3, w * 0.14, 0, TAU); c.fill();
      c.fillStyle = '#5A54A0'; c.beginPath(); c.arc(x + w * 0.76, y + h * 0.26, w * 0.12, 0, TAU); c.fill();
      for (let i = 0; i < 7; i++) { const tw = (Math.sin(T * 2 + i * 1.7) + 1) / 2; drawSparkle(c, x + ((i * 37) % w), y + ((i * 53) % (h * 0.9)) + 6, 2 + tw * 3, '#FFFFFF', 0.5 + tw * 0.5); }
    });
    // frame
    const fx = W * 0.62, fy = H * 0.12, fw = Math.min(W * 0.16, 64);
    c.fillStyle = '#FFFFFF'; c.beginPath(); rrectPath(c, fx, fy, fw, fw * 1.15, 10); c.fill();
    c.fillStyle = '#FFE3EE'; c.beginPath(); rrectPath(c, fx + 6, fy + 6, fw - 12, fw * 1.15 - 12, 6); c.fill();
    c.save(); c.translate(fx + fw / 2, fy + fw * 0.58); c.scale(fw * 0.2, fw * 0.2); jelly(c, HEART, SK.pink, -1, -0.8, 2, 1.7); c.restore();
    // rug
    c.fillStyle = 'rgba(255,255,255,0.35)'; c.beginPath(); c.ellipse(W / 2, groundY - 2, pet.R * 1.9, pet.R * 0.34, 0, 0, TAU); c.fill();
    c.strokeStyle = 'rgba(169,139,255,0.35)'; c.lineWidth = 3; c.setLineDash([6, 8]); c.beginPath(); c.ellipse(W / 2, groundY - 2, pet.R * 1.7, pet.R * 0.27, 0, 0, TAU); c.stroke(); c.setLineDash([]);
    // lamp
    const l = lampPos(), R = pet.R;
    c.strokeStyle = '#D6C9F2'; c.lineWidth = 5; c.lineCap = 'round';
    c.beginPath(); c.moveTo(l.x, l.y); c.lineTo(l.x, l.y - R * 1.2); c.stroke();
    c.fillStyle = '#D6C9F2'; c.beginPath(); c.ellipse(l.x, l.y, 20, 6, 0, 0, TAU); c.fill();
    const sw = Math.max(26, R * 0.42);
    const shade = P((p) => { p.moveTo(l.x - sw * 0.55, l.y - R * 1.75); p.lineTo(l.x + sw * 0.55, l.y - R * 1.75); p.lineTo(l.x + sw, l.y - R * 1.15); p.lineTo(l.x - sw, l.y - R * 1.15); p.closePath(); });
    jelly(c, shade, S.sleeping ? { light: '#E0DBEF', base: '#C7C0DE', deep: '#ADA4CC' } : SK.yellow, l.x - sw, l.y - R * 1.75, sw * 2, R * 0.6);
  },
  play(c, hz) {
    const n = Math.ceil(W / 34) + 1, y0 = H * 0.07;
    c.strokeStyle = 'rgba(255,255,255,0.9)'; c.lineWidth = 2; c.beginPath();
    for (let i = 0; i <= n; i++) { const x = i * 34, y = y0 + Math.sin((i / n) * Math.PI) * 26; i ? c.lineTo(x, y) : c.moveTo(x, y); } c.stroke();
    for (let i = 0; i < n; i++) {
      const x = i * 34 + 17, y = y0 + Math.sin(((i + 0.5) / n) * Math.PI) * 26, sw = Math.sin(T * 2 + i) * 0.08;
      c.save(); c.translate(x, y); c.rotate(sw);
      const p = P((p) => { p.moveTo(-12, 0); p.lineTo(12, 0); p.quadraticCurveTo(2, 24, 0, 26); p.quadraticCurveTo(-2, 24, -12, 0); });
      const sk = [SK.pink, SK.yellow, SK.mint, SK.lav, SK.sky][i % 5];
      jelly(c, p, sk, -12, 0, 24, 26, 0); c.restore();
    }
    const bs = Math.max(24, pet.R * 0.38), bx = W * 0.08, by = groundY - 4;
    [[0, 0, SK.sky, 'A'], [bs * 1.05, 0, SK.pink, 'B'], [bs * 0.5, -bs * 1.02, SK.yellow, 'C']].forEach(([ox, oy, sk, L]) => {
      const p = P((p) => rrect(p, bx + ox, by + oy - bs, bs, bs, bs * 0.25));
      jelly(c, p, sk, bx + ox, by + oy - bs, bs, bs);
      c.fillStyle = 'rgba(255,255,255,0.9)'; c.font = `700 ${bs * 0.55}px Fredoka, sans-serif`; c.textAlign = 'center'; c.textBaseline = 'middle';
      c.fillText(L, bx + ox + bs / 2, by + oy - bs / 2 + 1);
    });
  },
  closet(c, hz) {
    const aw = pet.R * 3.2, ah = Math.min(groundY - H * 0.08, pet.R * 3.8), ax = W / 2 - aw / 2, ay = groundY - ah;
    const arch = P((p) => { p.moveTo(ax, groundY); p.lineTo(ax, ay + aw / 2); p.arc(W / 2, ay + aw / 2, aw / 2, Math.PI, 0); p.lineTo(ax + aw, groundY); p.closePath(); });
    c.fillStyle = '#FFFFFF'; c.save(); c.translate(0, 0); c.lineWidth = 16; c.strokeStyle = '#FFFFFF'; c.stroke(arch); c.restore();
    const g = c.createLinearGradient(ax, ay, ax + aw, groundY); g.addColorStop(0, '#FFF7FB'); g.addColorStop(1, '#F3DDEB');
    c.fillStyle = g; c.fill(arch);
    c.save(); c.clip(arch); c.fillStyle = 'rgba(255,255,255,0.5)';
    c.beginPath(); c.moveTo(ax + aw * 0.12, groundY); c.lineTo(ax + aw * 0.42, ay); c.lineTo(ax + aw * 0.55, ay); c.lineTo(ax + aw * 0.25, groundY); c.fill(); c.restore();
    for (let i = 0; i < 4; i++) { const tw = (Math.sin(T * 2.4 + i * 1.6) + 1) / 2; drawSparkle(c, ax + aw * [0.15, 0.85, 0.75, 0.2][i], ay + ah * [0.25, 0.4, 0.15, 0.6][i], 4 + tw * 6, '#FFFFFF', 0.4 + tw * 0.6); }
    // plant
    const px = W * 0.1, py = groundY - 2, ps = Math.max(18, pet.R * 0.28);
    jellyEllipse(c, px - ps * 0.5, py - ps * 2.1, ps * 0.32, ps * 0.7, -0.5, SK.green);
    jellyEllipse(c, px + ps * 0.5, py - ps * 2.2, ps * 0.32, ps * 0.75, 0.5, SK.green);
    jellyEllipse(c, px, py - ps * 2.5, ps * 0.3, ps * 0.8, 0, SK.green);
    const pot = P((p) => { p.moveTo(px - ps * 0.85, py - ps * 1.5); p.lineTo(px + ps * 0.85, py - ps * 1.5); p.lineTo(px + ps * 0.6, py); p.lineTo(px - ps * 0.6, py); p.closePath(); });
    jelly(c, pot, SK.cream, px - ps * 0.85, py - ps * 1.5, ps * 1.7, ps * 1.5);
  },
};
function rrectPath(c, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r); c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
}

// ============================================================ scene update/draw
function updateScene(dt) {
  const st = S.stats;
  // springs
  const breathing = S.sleeping ? 0.5 : 1;
  pet.sq.t = 0; pet.rot.t = 0; pet.ear.t = 0;
  let lookT = { x: 0, y: 0 };
  if (drag.on) lookT = towards(drag.x - scene.getBoundingClientRect().left, drag.y - scene.getBoundingClientRect().top);
  else if (S.room === 'play' && ball.placed && (Math.abs(ball.vx) + Math.abs(ball.vy) > 20 || ball.held)) lookT = towards(ball.x, ball.y);
  else if (T - pointer.last < 2.2) lookT = towards(pointer.x, pointer.y);
  else lookT = pet.idleLook;
  if (S.sleeping) lookT = { x: 0, y: 0.3 };
  pet.lookX.t = lookT.x; pet.lookY.t = lookT.y;
  pet.mouth.t = 0;
  if (foodNearMouth() && !S.sleeping) pet.mouth.t = 1;
  if (pet.chew > 0) {
    pet.chew -= dt; pet.chewTick -= dt;
    pet.mouth.t = 0.25 + 0.35 * (Math.sin(T * 22) * 0.5 + 0.5);
    if (pet.chewTick <= 0) {
      pet.chewTick = 0.28; Snd.munch(); pet.sq.kick(1.4);
      const m = mouthPos();
      for (let i = 0; i < 4; i++) FX.add({ type: 'crumb', x: m.x + rand(-10, 10), y: m.y, vx: rand(-90, 90), vy: rand(-160, -60), g: 900, life: 0.7, size: rand(2, 3.5), color: pick(['#FFC9A8', '#FF9AA6', '#FFE08A', '#C98A5A']), floor: groundY });
    }
    if (pet.chew <= 0) { pet.joy = 1.0; Snd.happy(); emitHearts(pet.x, petTopY() + 10, 3); }
  }
  stepSprings([pet.sq, pet.rot, pet.ear, pet.lookX, pet.lookY, pet.mouth, pet.bubbleS], dt);

  // hop physics
  if (pet.hopY < 0 || pet.hopV < 0) {
    pet.hopV += pet.R * 32 * dt; pet.hopY += pet.hopV * dt;
    if (pet.hopY >= 0) { pet.hopY = 0; pet.sq.kick(clamp(pet.hopV / pet.R * 0.42, 1.2, 4)); pet.hopV = 0; }
  }

  // blink
  pet.blinkT -= dt;
  if (pet.blinkT <= 0) { pet.blink = 0.001; pet.blinkT = rand(2.2, 5.5); if (Math.random() < 0.2) pet.blinkT = 0.25; }
  if (pet.blink > 0) { pet.blink += dt / 0.16; if (pet.blink >= 2) pet.blink = 0; }
  pet.joy = Math.max(0, pet.joy - dt); pet.dizzy = Math.max(0, pet.dizzy - dt); pet.refuse = Math.max(0, pet.refuse - dt);
  pet.pokes = Math.max(0, pet.pokes - dt * 1.2);

  // idle
  pet.idleT -= dt;
  if (pet.idleT <= 0 && !S.sleeping && !drag.on) {
    pet.idleT = rand(3.5, 7);
    const r = Math.random();
    if (r < 0.3 && Math.min(st.fun, st.energy) > 35) hop(rand(4, 6));
    else if (r < 0.55) pet.idleLook = { x: rand(-1, 1), y: rand(-0.6, 0.6) };
    else if (r < 0.75) { pet.rot.kick(rand(-2, 2)); pet.ear.kick(rand(-6, 6)); }
    else pet.idleLook = { x: 0, y: 0 };
  }

  // foam pop
  for (let i = pet.foam.length - 1; i >= 0; i--) {
    const b = pet.foam[i];
    if (b.pop != null) { b.pop -= dt * 5; if (b.pop <= 0) { pet.foam.splice(i, 1); } }
  }

  // sleeping
  darkness = lerp(darkness, S.sleeping ? 1 : 0, 1 - Math.exp(-dt * 4));
  if (S.sleeping) {
    pet.zT -= dt;
    if (pet.zT <= 0) { pet.zT = 1.3; FX.add({ type: 'z', x: pet.x + pet.R * 0.6, y: petTopY() + pet.R * 0.2, vx: rand(18, 30), vy: -32, life: 2.4, size: rand(16, 24) }); }
    pet.snoreT -= dt; if (pet.snoreT <= 0) { pet.snoreT = 3.2; Snd.snore(); }
  }

  // need bubble
  pet.bubbleT -= dt;
  if (pet.bubbleT <= 0) {
    if (pet.bubbleOn > 0) { pet.bubbleOn = 0; pet.bubbleT = rand(5, 8); }
    else { const n = S.sleeping ? null : lowestNeed(); if (n) { pet.need = n; pet.bubbleOn = 1; pet.bubbleT = 3.2; pet.bubbleS.kick(8); } else pet.bubbleT = 3; }
  }
  pet.bubbleS.t = pet.bubbleOn;

  updateShower(dt);
  updateBall(dt);
  FX.update(dt);
  if (roomFade > 0) roomFade = Math.max(0, roomFade - dt / 0.35);
}
function towards(x, y) {
  const d = petSpec();
  const ex = pet.x, ey = groundY + d.eye.y * pet.R;
  const dx = x - ex, dy = y - ey, L = Math.hypot(dx, dy) || 1;
  const k = Math.min(1, L / (pet.R * 1.5));
  return { x: (dx / L) * k, y: (dy / L) * k };
}

function drawScene() {
  const c = ctx;
  c.setTransform(DPR, 0, 0, DPR, 0, 0);
  drawRoom(c, S.room, 1);
  if (roomFade > 0 && prevRoom) drawRoom(c, prevRoom, easeOut(roomFade));

  // pet
  const ex = expression();
  const breathe = Math.sin(T * (S.sleeping ? 1.6 : 2.6)) * (S.sleeping ? 0.03 : 0.018);
  const petOpts = {
    x: pet.x, y: groundY, R: pet.R, species: S.species, skin: S.skin, hat: S.hat,
    sq: pet.sq.v, rot: pet.rot.v * 0.35, hop: pet.hopY, breathe: REDUCED ? 0 : breathe, ear: pet.ear.v * 0.12,
    look: { x: pet.lookX.v, y: pet.lookY.v }, eyes: ex.eyes, mouth: ex.mouth,
    blink: pet.blink > 0 ? 1 - Math.abs(1 - pet.blink) : 0,
    mouthOpen: S.sleeping ? 0 : clamp(pet.mouth.v, 0, 1.2),
    dirt: clamp((62 - S.stats.clean) / 50, 0, 1), foam: pet.foam, t: T,
  };
  drawPet(c, petOpts);

  // stink lines when very dirty
  if (S.stats.clean < 25 && !S.sleeping) {
    c.strokeStyle = 'rgba(150,190,110,0.55)'; c.lineWidth = 3; c.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      const bx = pet.x + (i - 1) * pet.R * 0.9, k = (T * 0.6 + i * 0.33) % 1, by = petTopY() - k * pet.R * 0.6;
      c.globalAlpha = Math.sin(k * Math.PI); c.beginPath();
      for (let j = 0; j <= 10; j++) { const yy = by - j * 3, xx = bx + Math.sin(j * 0.8 + T * 4 + i) * 4; j ? c.lineTo(xx, yy) : c.moveTo(xx, yy); }
      c.stroke();
    }
    c.globalAlpha = 1;
  }

  // ball
  if (S.room === 'play' && ball.placed) {
    c.save(); c.translate(ball.x, groundY); c.scale(1, 0.2);
    const sh = 1 - clamp((groundY - ball.y) / (H * 0.6), 0, 0.7);
    c.fillStyle = `rgba(70,40,90,${0.16 * sh})`; c.beginPath(); c.arc(0, 0, ball.r * sh, 0, TAU); c.fill(); c.restore();
    drawItem(c, 'bola', ball.x, ball.y, ball.r * 2, T, { spin: ball.spin });
  }

  // shower head
  if (S.room === 'bath' && showering) {
    c.fillStyle = 'rgba(124,200,245,0.10)'; c.fillRect(pet.x - petSpec().w * pet.R * 1.2, 0, petSpec().w * pet.R * 2.4, groundY);
  }

  FX.draw(c);

  // night
  if (darkness > 0.01) {
    c.fillStyle = `rgba(32,24,70,${0.55 * darkness})`; c.fillRect(0, 0, W, H);
    const cy = groundY - petSpec().h * pet.R * 0.5;
    const g = c.createRadialGradient(pet.x, cy, 0, pet.x, cy, pet.R * 2.2);
    g.addColorStop(0, rgba(SKINS[S.skin].light, 0.35 * darkness)); g.addColorStop(1, rgba(SKINS[S.skin].light, 0));
    c.globalCompositeOperation = 'lighter'; c.fillStyle = g; c.fillRect(0, 0, W, H); c.globalCompositeOperation = 'source-over';
    for (let i = 0; i < 12; i++) { const tw = (Math.sin(T * 1.5 + i * 2.1) + 1) / 2; drawSparkle(c, (i * 89 + 30) % W, (i * 47 + 20) % (H * 0.55), 2 + tw * 3, '#FFF7D6', darkness * (0.3 + tw * 0.7)); }
  }

  // need bubble
  const bs = pet.bubbleS.v;
  if (bs > 0.02 && pet.need) {
    const R = pet.R, bx = pet.x + R * 1.25, by = petTopY() + R * 0.1;
    c.save(); c.translate(bx, by); c.scale(bs, bs);
    c.fillStyle = 'rgba(255,255,255,0.95)'; c.shadowColor = 'rgba(120,80,150,0.18)'; c.shadowBlur = 12 * DPR; c.shadowOffsetY = 3 * DPR;
    c.beginPath(); c.arc(0, 0, R * 0.42, 0, TAU); c.fill();
    c.shadowColor = 'transparent';
    c.beginPath(); c.arc(-R * 0.42, R * 0.4, R * 0.09, 0, TAU); c.arc(-R * 0.58, R * 0.58, R * 0.05, 0, TAU); c.fill();
    const s = R * 0.48;
    if (pet.need === 'hunger') drawItem(c, 'maca', 0, 0, s, T);
    else if (pet.need === 'fun') drawItem(c, 'bola', 0, 0, s, T, { spin: T });
    else if (pet.need === 'clean') drawItem(c, 'sabao', 0, 2, s, T);
    else {
      c.save(); c.scale(s / 2, s / 2);
      const moon = P((p) => { p.arc(0, 0, 0.8, 0.6, TAU - 0.6 + 0.0001); p.arc(0.45, -0.25, 0.62, TAU - 0.9, 0.9, true); p.closePath(); });
      jelly(c, moon, SK.lav, -0.8, -0.8, 1.6, 1.6); c.restore();
    }
    c.restore();
  }
}

// ============================================================ HUD
const RING_C = 125.66;
const needEls = {};
$$('.need').forEach((el) => { needEls[el.dataset.stat] = { el, val: $('.val', el) }; });
function renderHUD() {
  for (const k in needEls) {
    const v = S.stats[k];
    needEls[k].val.style.strokeDashoffset = (RING_C * (1 - v / 100)).toFixed(1);
    needEls[k].el.classList.toggle('low', v < 25);
  }
  $('#coinNum').textContent = S.coins;
  $('#lvlNum').textContent = S.level;
  $('#xpFill').style.width = `${(S.xp / (S.level * 40)) * 100}%`;
  $('#petName').textContent = S.name;
  $('#bestNum').textContent = S.best;
  $$('.food').forEach((b) => { const f = FOODS.find((x) => x.id === b.dataset.id); b.classList.toggle('poor', S.coins < f.price); });
  const sb = $('#soundBtn'); sb.classList.toggle('muted', !S.sound); sb.setAttribute('aria-label', S.sound ? 'Desligar som' : 'Ligar som');
}
let toastTimer = 0;
function toast(msg) {
  toastEl.textContent = msg; toastEl.classList.add('show');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => toastEl.classList.remove('show'), 2200);
}

function tickStats(dt) {
  const st = S.stats;
  if (S.sleeping) {
    st.energy = clamp(st.energy + 0.55 * dt, 0, 100);
    st.hunger = clamp(st.hunger - DECAY.hunger * 0.4 * dt, 0, 100);
    st.clean = clamp(st.clean - DECAY.clean * 0.3 * dt, 0, 100);
  } else {
    for (const k in DECAY) st[k] = clamp(st[k] - DECAY[k] * dt, 0, 100);
  }
}

// ============================================================ tray builders
function buildFood() {
  const row = $('#foodRow');
  row.innerHTML = '';
  for (const f of FOODS) {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'food'; b.dataset.id = f.id;
    b.setAttribute('aria-label', `${f.name}, ${f.price} moedas`);
    b.innerHTML = `<canvas></canvas><span class="fn">${f.name}</span><span class="price"><span class="coin"></span>${f.price}</span>`;
    row.appendChild(b);
    bindDraggable(b, 'food', f.id);
  }
}
function paintTrayIcons() {
  $$('.food').forEach((b) => paintIcon($('canvas', b), (c, w, h) => drawItem(c, b.dataset.id, w / 2, h / 2, w * 0.82)));
  $$('canvas[data-item]').forEach((cv) => paintIcon(cv, (c, w, h) => drawItem(c, cv.dataset.item, w / 2, h / 2, w * 0.8, 0.3, { skin: SKINS.chiclete })));
}

let closetSeg = 'species';
function renderCloset() {
  const row = $('#closetRow');
  row.innerHTML = '';
  let items = [];
  if (closetSeg === 'species') items = Object.keys(SPEC).map((id) => ({ id, name: SPECIES_INFO[id].name, price: 0, owned: true, on: S.species === id }));
  else if (closetSeg === 'skin') items = Object.keys(SKINS).map((id) => ({ id, name: SKINS[id].name, price: SKIN_PRICE, owned: S.owned.skins.includes(id), on: S.skin === id }));
  else items = HATS.map((h) => ({ id: h.id, name: h.name, price: h.price, owned: S.owned.hats.includes(h.id), on: S.hat === h.id }));
  for (const it of items) {
    const b = document.createElement('button');
    b.type = 'button'; b.className = 'citem' + (it.on ? ' on' : '');
    const tag = it.on ? '<span class="own">Usando</span>' : it.owned ? '<span class="own">Seu</span>' : `<span class="price"><span class="coin"></span>${it.price}</span>`;
    b.innerHTML = `<canvas></canvas><span class="fn">${it.name}</span>${tag}`;
    b.setAttribute('aria-label', `${it.name}${it.owned ? '' : `, ${it.price} moedas`}`);
    row.appendChild(b);
    const cv = $('canvas', b);
    paintIcon(cv, (c, w, h) => {
      if (closetSeg === 'species') {
        const d = SPEC[it.id], R = h * 0.72 / (d.h + (it.id === 'coelho' ? 0.75 : 0.1));
        drawPet(c, { x: w / 2, y: h * 0.94, R, species: it.id, skin: S.skin, shadow: false, t: 0 });
      } else if (closetSeg === 'skin') drawItem(c, 'skin', w / 2, h / 2 + 2, w * 0.82, 0, { skin: it.id });
      else if (it.id === 'none') {
        c.strokeStyle = '#C9BBD6'; c.lineWidth = 3; c.lineCap = 'round';
        c.beginPath(); c.arc(w / 2, h / 2, w * 0.26, 0, TAU); c.moveTo(w / 2 - w * 0.18, h / 2 + w * 0.18); c.lineTo(w / 2 + w * 0.18, h / 2 - w * 0.18); c.stroke();
      } else { c.save(); c.translate(w / 2, h * 0.68); c.scale(w * 0.85, w * 0.85); drawHat(c, it.id, 0.8, 0.5); c.restore(); }
    });
    b.addEventListener('click', () => closetPick(it, b));
  }
  const on = row.querySelector('.on'); if (on) row.scrollLeft = Math.max(0, on.offsetLeft - row.clientWidth / 2 + on.offsetWidth / 2);
}
function closetPick(it, el) {
  Snd.ensure();
  if (!it.owned) {
    if (S.coins < it.price) {
      Snd.nope(); toast(`Faltam ${it.price - S.coins} moedas`);
      el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake'); return;
    }
    addCoins(-it.price); Snd.coin();
    if (closetSeg === 'skin') S.owned.skins.push(it.id); else S.owned.hats.push(it.id);
    emitConfetti(pet.x, petTopY(), 30);
    toast(`Novo item: ${it.name}!`);
    addXP(5);
  } else Snd.tap();
  if (closetSeg === 'species') {
    const wasDefaultName = Object.values(SPECIES_INFO).some((s) => s.name === S.name);
    S.species = it.id;
    if (wasDefaultName) S.name = SPECIES_INFO[it.id].name;
    if (S.owned.skins.includes(SPECIES_INFO[it.id].skin) && Object.values(SPECIES_INFO).some((s) => s.skin === S.skin)) S.skin = SPECIES_INFO[it.id].skin;
    pet.foam.length = 0;
  } else if (closetSeg === 'skin') S.skin = it.id;
  else S.hat = it.id;
  pet.sq.kick(-3); hop(6); pet.joy = 1; emitSparkles(pet.x, petTopY() + pet.R * 0.3, 8, pet.R * 0.8);
  renderCloset(); renderHUD(); save();
}

// ============================================================ minigame: Chuva de Doces
const MG = {
  el: $('#mg'), cv: $('#mgCanvas'), ctx: null, w: 1, h: 1, dpr: 1, open: false, running: false,
  score: 0, lives: 3, items: [], fx: new Particles(), t: 0, spawn: 0, px: 0, tx: 0, pv: 0,
  sq: new Spring(0, 230, 10), rot: new Spring(0, 120, 10), dizzy: 0, shake: 0, combo: 0, keys: { l: false, r: false }, endT: 0, R: 50,
};
MG.ctx = MG.cv.getContext('2d');
function mgResize() {
  const r = MG.cv.getBoundingClientRect(); MG.dpr = Math.min(window.devicePixelRatio || 1, 2);
  MG.w = Math.max(1, r.width); MG.h = Math.max(1, r.height);
  MG.cv.width = Math.round(MG.w * MG.dpr); MG.cv.height = Math.round(MG.h * MG.dpr);
  MG.R = Math.min(MG.w * 0.13, MG.h * 0.075); MG.ground = MG.h * 0.88;
}
function openMG() {
  if (S.sleeping) { toast('Está dormindo. Acorde-o primeiro'); return; }
  if (S.stats.energy < 12) { Snd.nope(); toast(`${S.name} está cansado demais. Hora de dormir!`); return; }
  MG.open = true; MG.el.hidden = false; MG.running = false;
  mgResize(); MG.px = MG.tx = MG.w / 2;
  $('#mgStart').hidden = false; $('#mgOver').hidden = true;
  MG.score = 0; MG.lives = 3; MG.items.length = 0; MG.fx.list.length = 0; renderMGHud();
  Snd.tap();
  paintTrayIcons();
}
function startMG() {
  Snd.ensure();
  Object.assign(MG, { running: true, score: 0, lives: 3, t: 0, spawn: 0.6, combo: 0, dizzy: 0, shake: 0, endT: 0 });
  MG.items.length = 0; MG.fx.list.length = 0; MG.px = MG.tx = MG.w / 2;
  $('#mgStart').hidden = true; $('#mgOver').hidden = true;
  renderMGHud(); Snd.happy();
}
function endMG() {
  MG.running = false;
  const earn = MG.score;
  const record = MG.score > S.best;
  if (record) S.best = MG.score;
  S.coins += earn;
  addStat('fun', 22); addStat('energy', -10); addStat('hunger', -6);
  addXP(Math.round(6 + MG.score / 3));
  $('#mgEarn').textContent = earn;
  $('#mgOverTitle').textContent = record && MG.score > 0 ? 'Novo recorde!' : 'Fim de jogo';
  $('#mgBestLine').textContent = `Recorde: ${S.best}`;
  $('#mgOver').hidden = false;
  if (record && MG.score > 0) Snd.levelup(); else Snd.coin();
  renderHUD(); save();
}
function closeMG() { MG.open = false; MG.running = false; MG.el.hidden = true; pet.joy = 1; hop(6); renderHUD(); }
function renderMGHud() {
  $('#mgScore').textContent = MG.score;
  const L = $('#mgLives'); if (L.children.length !== 3) L.innerHTML = '<i></i><i></i><i></i>';
  [...L.children].forEach((h, i) => h.classList.toggle('lost', i >= MG.lives));
}
const MG_TYPES = [
  { id: 'bala', val: 1, w: 46 }, { id: 'morango', val: 2, w: 18 }, { id: 'estrela', val: 5, w: 6 }, { id: 'nuvem', val: -1, w: 30 },
];
function mgSpawn() {
  const badBoost = Math.min(18, MG.t * 0.35);
  const weights = MG_TYPES.map((t) => t.w + (t.val < 0 ? badBoost : 0));
  let r = Math.random() * weights.reduce((a, b) => a + b, 0), type = MG_TYPES[0];
  for (let i = 0; i < weights.length; i++) { if ((r -= weights[i]) < 0) { type = MG_TYPES[i]; break; } }
  const size = MG.R * (type.id === 'nuvem' ? 1.15 : type.id === 'estrela' ? 0.95 : 0.88);
  MG.items.push({
    ...type, x: rand(size * 0.6, MG.w - size * 0.6), y: -size, size,
    vy: MG.h * (0.24 + Math.min(MG.t, 90) * 0.0055) * rand(0.85, 1.2), rot: rand(-0.5, 0.5), vr: rand(-2, 2),
    skin: pick([SKINS.chiclete, SKINS.menta, SKINS.ceu, SKINS.limao, SKINS.lavanda]), wob: rand(0, TAU),
  });
}
function updateMG(dt) {
  MG.fx.update(dt);
  stepSprings([MG.sq, MG.rot], dt);
  MG.sq.t = 0; MG.rot.t = 0;
  MG.dizzy = Math.max(0, MG.dizzy - dt); MG.shake = Math.max(0, MG.shake - dt);
  if (MG.keys.l) MG.tx -= MG.w * 1.3 * dt;
  if (MG.keys.r) MG.tx += MG.w * 1.3 * dt;
  MG.tx = clamp(MG.tx, MG.R, MG.w - MG.R);
  const prev = MG.px;
  MG.px = lerp(MG.px, MG.tx, 1 - Math.exp(-dt * 14));
  MG.pv = (MG.px - prev) / Math.max(dt, 0.001);
  MG.rot.t = clamp(MG.pv * 0.0009, -0.35, 0.35);
  if (!MG.running) { if (MG.endT > 0) { MG.endT -= dt; if (MG.endT <= 0) endMG(); } return; }
  MG.t += dt; MG.spawn -= dt;
  if (MG.spawn <= 0) { mgSpawn(); MG.spawn = Math.max(0.3, 0.85 - MG.t * 0.011) * rand(0.75, 1.2); }
  const R = MG.R, top = MG.ground - R * 1.5;
  for (let i = MG.items.length - 1; i >= 0; i--) {
    const it = MG.items[i];
    it.y += it.vy * dt; it.rot += it.vr * dt;
    const x = it.x + Math.sin(MG.t * 3 + it.wob) * (it.val < 0 ? 12 : 4);
    if (it.y > top && it.y < MG.ground - R * 0.2 && Math.abs(x - MG.px) < R * 1.05 + it.size * 0.3) {
      MG.items.splice(i, 1);
      if (it.val > 0) {
        MG.combo += 1;
        const gain = it.val + (MG.combo >= 10 ? 1 : 0);
        MG.score += gain; MG.sq.kick(2.6);
        MG.fx.add({ type: 'text', x, y: it.y - 20, vy: -60, drag: 1.2, life: 0.9, size: 22, text: `+${gain}`, color: it.id === 'estrela' ? '#F5A623' : '#FF6FA8' });
        for (let k = 0; k < 6; k++) MG.fx.add({ type: 'sparkle', x: x + rand(-20, 20), y: it.y + rand(-20, 10), vy: rand(-60, -20), life: rand(0.4, 0.7), size: rand(5, 10), color: it.id === 'estrela' ? '#FFD054' : '#FFFFFF' });
        Snd.tone(660 + Math.min(MG.combo, 16) * 40, 990 + Math.min(MG.combo, 16) * 50, 0.08, 'sine', 0.16);
        if (it.id === 'estrela') Snd.coin();
      } else {
        MG.lives -= 1; MG.combo = 0; MG.dizzy = 1; MG.shake = 0.35; MG.sq.kick(4);
        Snd.ouch();
        for (let k = 0; k < 10; k++) MG.fx.add({ type: 'drop', x: x + rand(-20, 20), y: it.y, vx: rand(-160, 160), vy: rand(-200, 50), g: 900, life: 0.7, size: rand(4, 7), color: '#8DA2D8' });
        if (MG.lives <= 0) { MG.running = false; MG.endT = 0.8; MG.items.forEach((o) => MG.fx.add({ type: 'ring', x: o.x, y: o.y, life: 0.4, size: o.size, color: '#FFFFFF' })); MG.items.length = 0; }
      }
      renderMGHud();
      if (!MG.running) break;
      continue;
    }
    if (it.y > MG.h + it.size) { MG.items.splice(i, 1); if (it.val > 0) MG.combo = 0; }
  }
}
function drawMG() {
  const c = MG.ctx, w = MG.w, h = MG.h;
  c.setTransform(MG.dpr, 0, 0, MG.dpr, 0, 0);
  let g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, '#CFEAFF'); g.addColorStop(0.55, '#FBE3F1'); g.addColorStop(1, '#FFF1E6');
  c.fillStyle = g; c.fillRect(0, 0, w, h);
  for (let i = 0; i < 5; i++) { const s = 18 + (i % 3) * 10, x = ((T * (6 + i * 3) + i * 140) % (w + 160)) - 80; cloud(c, x, h * (0.12 + i * 0.1), s, 0.75); }
  // hills
  c.fillStyle = '#D9F5E8'; c.beginPath(); c.moveTo(0, MG.ground - 30);
  for (let x = 0; x <= w; x += 20) c.lineTo(x, MG.ground - 30 - Math.sin(x * 0.012 + 1) * 18); c.lineTo(w, h); c.lineTo(0, h); c.fill();
  g = c.createLinearGradient(0, MG.ground, 0, h); g.addColorStop(0, '#BFEBD6'); g.addColorStop(1, '#A6E0C6');
  c.fillStyle = g; c.fillRect(0, MG.ground - 4, w, h - MG.ground + 4);
  c.fillStyle = 'rgba(255,255,255,0.6)'; c.fillRect(0, MG.ground - 4, w, 2);
  c.save();
  if (MG.shake > 0) c.translate(rand(-6, 6) * MG.shake * 3, rand(-6, 6) * MG.shake * 3);
  for (const it of MG.items) {
    const x = it.x + Math.sin(MG.t * 3 + it.wob) * (it.val < 0 ? 12 : 4);
    c.save(); c.translate(x, it.y); c.rotate(it.val < 0 ? Math.sin(MG.t * 4 + it.wob) * 0.1 : it.rot);
    drawItem(c, it.id, 0, 0, it.size, T, { skin: it.skin }); c.restore();
  }
  // pet looks at nearest good item
  let near = null, nd = 1e9;
  for (const it of MG.items) if (it.val > 0) { const d = Math.abs(it.x - MG.px) + (MG.ground - it.y) * 0.5; if (d < nd) { nd = d; near = it; } }
  const look = near ? { x: clamp((near.x - MG.px) / (MG.R * 3), -1, 1), y: -0.8 } : { x: 0, y: -0.3 };
  drawPet(c, {
    x: MG.px, y: MG.ground, R: MG.R, species: S.species, skin: S.skin, hat: S.hat,
    sq: MG.sq.v + Math.min(Math.abs(MG.pv) * 0.00008, 0.08), rot: MG.rot.v, t: T, look,
    eyes: MG.dizzy > 0 ? 'swirl' : MG.sq.v > 0.15 ? 'happy' : 'open', mouth: MG.dizzy > 0 ? 'wavy' : 'grin',
    blink: 0,
  });
  MG.fx.draw(c);
  c.restore();
}
MG.cv.addEventListener('pointerdown', (e) => { const r = MG.cv.getBoundingClientRect(); MG.tx = e.clientX - r.left; try { MG.cv.setPointerCapture(e.pointerId); } catch (_) { /* */ } });
MG.cv.addEventListener('pointermove', (e) => { if (e.pointerType === 'mouse' || e.buttons || e.pressure > 0) { const r = MG.cv.getBoundingClientRect(); MG.tx = e.clientX - r.left; } });
window.addEventListener('keydown', (e) => {
  if (!MG.open) return;
  if (e.key === 'ArrowLeft' || e.key === 'a') MG.keys.l = true;
  if (e.key === 'ArrowRight' || e.key === 'd') MG.keys.r = true;
  if (e.key === 'Escape') closeMG();
});
window.addEventListener('keyup', (e) => {
  if (e.key === 'ArrowLeft' || e.key === 'a') MG.keys.l = false;
  if (e.key === 'ArrowRight' || e.key === 'd') MG.keys.r = false;
});

// ============================================================ wiring
function wire() {
  $$('.tabs button').forEach((b) => b.addEventListener('click', () => setRoom(b.dataset.room)));
  $('#soundBtn').addEventListener('click', () => { S.sound = !S.sound; renderHUD(); if (S.sound) Snd.tap(); save(); });
  $('#lampBtn').addEventListener('click', () => { Snd.ensure(); toggleSleep(); });
  $('#playBtn').addEventListener('click', openMG);
  $('#mgGo').addEventListener('click', startMG);
  $('#mgAgain').addEventListener('click', () => { if (S.stats.energy < 12) { closeMG(); toast(`${S.name} precisa dormir um pouco`); return; } startMG(); });
  $('#mgExit').addEventListener('click', closeMG);
  $('#mgClose').addEventListener('click', () => { if (MG.running) { MG.running = false; MG.endT = 0; endMG(); } else closeMG(); });
  bindDraggable($('#soapBtn'), 'soap', 'sabao');
  const sh = $('#showerBtn');
  const showerOn = (e) => { e.preventDefault(); Snd.ensure(); showering = true; sh.classList.add('held'); try { sh.setPointerCapture(e.pointerId); } catch (_) { /* */ } };
  const showerOff = () => { showering = false; sh.classList.remove('held'); };
  sh.addEventListener('pointerdown', showerOn);
  sh.addEventListener('pointerup', showerOff); sh.addEventListener('pointercancel', showerOff); sh.addEventListener('lostpointercapture', showerOff);
  sh.addEventListener('keydown', (e) => { if (e.key === ' ' || e.key === 'Enter') { showering = true; sh.classList.add('held'); } });
  sh.addEventListener('keyup', showerOff);
  $$('#closetSeg button').forEach((b) => b.addEventListener('click', () => {
    closetSeg = b.dataset.seg; $$('#closetSeg button').forEach((x) => x.classList.toggle('on', x === b)); Snd.tap(); renderCloset();
  }));
  // profile sheet
  const sheet = $('#sheet'), input = $('#nameInput');
  let resetArmed = false;
  $('#profileBtn').addEventListener('click', () => {
    Snd.ensure(); Snd.tap();
    input.value = S.name; resetArmed = false; $('#resetBtn').textContent = 'Recomeçar do zero';
    $('#facts').innerHTML = [
      ['Nível', S.level], ['Moedas', S.coins], ['Recorde', S.best], ['Acessórios', S.owned.hats.length - 1],
    ].map(([k, v]) => `<div><dt>${k}</dt><dd>${v}</dd></div>`).join('');
    sheet.hidden = false;
  });
  const closeSheet = () => { const v = input.value.trim(); if (v) S.name = v.slice(0, 12); sheet.hidden = true; renderHUD(); renderLamp(); save(); };
  $('#sheetClose').addEventListener('click', closeSheet);
  sheet.addEventListener('click', (e) => { if (e.target === sheet) closeSheet(); });
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter') closeSheet(); });
  $('#resetBtn').addEventListener('click', () => {
    if (!resetArmed) { resetArmed = true; $('#resetBtn').textContent = 'Toque de novo para confirmar'; return; }
    S = defaultState(); save(); sheet.hidden = true;
    pet.foam.length = 0; setRoom('kitchen', true); renderHUD(); renderLamp(); hop(7); toast('Um novo começo!');
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden) save(); else { applyOffline(); renderHUD(); } });
  window.addEventListener('pagehide', save);
  new ResizeObserver(resizeScene).observe(scene);
  new ResizeObserver(() => { if (MG.open) mgResize(); }).observe(MG.cv);
}

// ============================================================ loop
let last = performance.now(), hudT = 0, saveT = 0;
function frame(now) {
  const dt = Math.min((now - last) / 1000, 0.05); last = now; T += dt;
  tickStats(dt);
  if (MG.open) { updateMG(dt); drawMG(); }
  else { updateScene(dt); drawScene(); }
  updateGhost(dt);
  hudT += dt; if (hudT > 0.25) { hudT = 0; renderHUD(); }
  saveT += dt; if (saveT > 4) { saveT = 0; save(); }
  requestAnimationFrame(frame);
}

function start(hotData) {
  S = load(hotData);
  applyOffline();
  buildFood();
  wire();
  resizeScene();
  setRoom(S.room, true);
  renderHUD(); renderLamp();
  paintTrayIcons();
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(paintTrayIcons);
  if (!S.tips.hello) {
    S.tips.hello = true;
    setTimeout(() => toast(`Oi! Toque no ${S.name} ou faça carinho`), 900);
  }
  hop(6);
  requestAnimationFrame((t) => { last = t; frame(t); });
  window.claude?.hot?.snapshot?.(() => ({ S }));
}

const hot = window.claude && window.claude.hot;
if (hot && hot.ready) hot.ready(start); else start(hot && hot.data ? hot.data : null);

// debug hook for automated tests
window.__mochi = { get S() { return S; }, pet, setRoom, openMG, startMG, MG, toggleSleep };
})();
