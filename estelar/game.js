/* Gramado Estelar — isometric sky mini-golf in modern pixel art.
   Everything is drawn at a low internal resolution and scaled up by an integer factor.
   Characters and enemies are lit spheres rasterized pixel by pixel every frame, so they really roll. */
(() => {
'use strict';

// ============================================================ utils
const $ = (s) => document.querySelector(s);
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (a) => a[(Math.random() * a.length) | 0];
const TAU = Math.PI * 2;
const hash = (a, b, c = 0) => { let h = (a * 374761393 + b * 668265263 + c * 2147483647) | 0; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967295; };
const RGB = {};
function rgb(hex) {
  let c = RGB[hex]; if (c) return c;
  const n = parseInt(hex.slice(1), 16); c = RGB[hex] = [(n >> 16) & 255, (n >> 8) & 255, n & 255]; return c;
}
const shade = (c, k) => [clamp(c[0] * k, 0, 255) | 0, clamp(c[1] * k, 0, 255) | 0, clamp(c[2] * k, 0, 255) | 0];
const mixc = (a, b, t) => [lerp(a[0], b[0], t) | 0, lerp(a[1], b[1], t) | 0, lerp(a[2], b[2], t) | 0];
const css = (c, a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;
const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const REDUCED = matchMedia('(prefers-reduced-motion: reduce)').matches;

// ============================================================ characters
const CHARS = [
  { id: 'pipo', name: 'Pipo', desc: 'Equilibrado e fofo', body: ['#5A1E3E', '#B8457A', '#EE6F9C', '#FFA8C4', '#FFE1EC'], feet: '#C22E58', acc: 'folha', power: 1, fric: 1, jump: 1, brake: 1, stats: [3, 3, 3] },
  { id: 'brasa', name: 'Brasa', desc: 'Tacadas fortíssimas', body: ['#5E1E14', '#C04A26', '#F27E36', '#FFB45C', '#FFE6AE'], feet: '#8A2414', acc: 'chama', power: 1.2, fric: 0.9, jump: 0.92, brake: 0.75, stats: [5, 2, 2] },
  { id: 'nimbo', name: 'Nimbo', desc: 'Pula mais alto', body: ['#1E2A66', '#4569C2', '#77A8F0', '#B3D8FF', '#ECF7FF'], feet: '#33449A', acc: 'nuvem', power: 0.93, fric: 1, jump: 1.32, brake: 1, stats: [2, 3, 5] },
  { id: 'musgo', name: 'Musgo', desc: 'Controle preciso', body: ['#143E2C', '#287F52', '#46BC74', '#8AE6A0', '#DCFCE3'], feet: '#1F5A38', acc: 'broto', power: 1, fric: 1.12, jump: 0.95, brake: 1.6, stats: [3, 5, 2] },
];
const STONE = ['#26222E', '#4C4858', '#7A7688', '#ABA8B8', '#E0DEE8'];

// ============================================================ audio (chiptune, synthesized)
const Audio = {
  ac: null, out: null, sfxOn: true, musicOn: true, mus: null, step: 0, next: 0, timer: 0, noiseBuf: null,
  init() {
    if (!this.ac) {
      const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
      try { this.ac = new AC(); } catch (e) { return null; }
      this.out = this.ac.createGain(); this.out.gain.value = 0.5; this.out.connect(this.ac.destination);
      this.mus = this.ac.createGain(); this.mus.gain.value = 0.09; this.mus.connect(this.out);
      const len = this.ac.sampleRate * 0.6; this.noiseBuf = this.ac.createBuffer(1, len, this.ac.sampleRate);
      const d = this.noiseBuf.getChannelData(0); for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    }
    if (this.ac.state === 'suspended') this.ac.resume();
    return this.ac;
  },
  tone(f, dur, type = 'square', vol = 0.12, to = null, delay = 0, dest = null) {
    const ac = this.ac; if (!ac) return;
    const t = ac.currentTime + delay, o = ac.createOscillator(), g = ac.createGain();
    o.type = type; o.frequency.setValueAtTime(f, t); if (to) o.frequency.exponentialRampToValueAtTime(to, t + dur);
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(dest || this.out); o.start(t); o.stop(t + dur + 0.02);
  },
  noise(dur, vol = 0.15, freq = 3000, delay = 0, dest = null) {
    const ac = this.ac; if (!ac) return;
    const t = ac.currentTime + delay, s = ac.createBufferSource(), f = ac.createBiquadFilter(), g = ac.createGain();
    s.buffer = this.noiseBuf; f.type = 'bandpass'; f.frequency.value = freq; f.Q.value = 0.9;
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(dest || this.out); s.start(t, Math.random() * 0.3); s.stop(t + dur + 0.02);
  },
  sfx(name, k = 1) {
    if (!this.sfxOn || !this.ac) return;
    switch (name) {
      case 'shoot': this.tone(220 + k * 300, 0.18, 'square', 0.1, 900 + k * 600); this.noise(0.1, 0.08, 2000); break;
      case 'jump': this.tone(300, 0.25, 'square', 0.08, 1200); break;
      case 'bounce': this.tone(180 + k * 60, 0.07, 'triangle', 0.18, 120); break;
      case 'wall': this.tone(140, 0.08, 'square', 0.08, 90); this.noise(0.06, 0.1, 900); break;
      case 'bumper': this.tone(520, 0.12, 'square', 0.09, 1040); this.tone(780, 0.12, 'square', 0.06, 1560, 0.05); break;
      case 'defeat': [659, 784, 1047, 1319].forEach((f, i) => this.tone(f, 0.09, 'square', 0.08, null, i * 0.05)); this.noise(0.15, 0.12, 1500); break;
      case 'spike': this.tone(900, 0.15, 'sawtooth', 0.06, 300); break;
      case 'cup': [523, 659, 784, 1047, 784, 1047].forEach((f, i) => this.tone(f, 0.1, 'triangle', 0.14, null, i * 0.07)); break;
      case 'sink': [784, 988, 1175, 1568].forEach((f, i) => this.tone(f, 0.16, 'square', 0.08, null, i * 0.09)); [392, 494, 587, 784].forEach((f, i) => this.tone(f, 0.18, 'triangle', 0.12, null, i * 0.09)); break;
      case 'splash': this.noise(0.4, 0.18, 1200); this.tone(400, 0.3, 'sine', 0.08, 120); break;
      case 'fall': this.tone(700, 0.6, 'square', 0.06, 80); break;
      case 'ability': this.tone(400, 0.3, 'square', 0.08, 1600); this.tone(600, 0.3, 'triangle', 0.08, 2000, 0.05); break;
      case 'stone': this.noise(0.25, 0.25, 300); this.tone(90, 0.25, 'square', 0.12, 50); break;
      case 'select': this.tone(880, 0.06, 'square', 0.07); this.tone(1320, 0.08, 'square', 0.06, null, 0.05); break;
      case 'tick': this.tone(1200 + k * 800, 0.025, 'square', 0.025); break;
      case 'lip': this.tone(600, 0.08, 'triangle', 0.12, 400); break;
      case 'brake': this.noise(0.08, 0.05, 4000); break;
    }
  },
  // cheerful 4-bar loop (MIDI note numbers, eighth notes)
  LEAD: [76, 79, 84, 79, 81, 79, 76, 74, 72, 74, 76, 79, 76, 74, 72, 0, 77, 81, 84, 81, 79, 76, 74, 72, 74, 76, 74, 71, 72, 0, 67, 0],
  BASS: [48, 55, 48, 55, 45, 52, 45, 52, 41, 48, 41, 48, 43, 50, 43, 47],
  ARP: [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]],
  startMusic() {
    if (!this.ac || this.timer) return;
    this.next = this.ac.currentTime + 0.1; this.step = 0;
    this.timer = setInterval(() => this.schedule(), 30);
  },
  stopMusic() { clearInterval(this.timer); this.timer = 0; },
  schedule() {
    const ac = this.ac, sp = 60 / 136 / 2;
    while (this.next < ac.currentTime + 0.15) {
      const s = this.step % 32, t = this.next - ac.currentTime, mf = (n) => 440 * Math.pow(2, (n - 69) / 12);
      if (this.musicOn) {
        const n = this.LEAD[s]; if (n) this.tone(mf(n), sp * 0.9, 'square', 0.32, null, t, this.mus);
        if (s % 2 === 0) this.tone(mf(this.BASS[s / 2]), sp * 1.8, 'triangle', 0.7, null, t, this.mus);
        const ch = this.ARP[(s / 8) | 0]; this.tone(mf(ch[s % 3] + 12), sp * 0.4, 'square', 0.1, null, t + sp * 0.5, this.mus);
        if (s % 4 === 2) this.noise(0.04, 0.35, 7000, t, this.mus);
      }
      this.next += sp; this.step++;
    }
  },
};

// ============================================================ canvas & resolution
const wrap = $('#wrap');
const cv = $('#game');
const g = cv.getContext('2d');
let VW = 240, VH = 420, SCALE = 1, CSS_K = 1;
function resize() {
  const r = wrap.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
  const dw = r.width * dpr, dh = r.height * dpr;
  // zoom so the current course fills the screen (leaving room for the HUD); the title uses a fixed framing
  let needW = 172, needH = 250, hud = 0;
  if (hole && G.mode !== 'title') { needW = Math.max(120, hole.right - hole.left + 40); needH = hole.bottom - hole.top + 40; hud = 190 * dpr; }
  SCALE = Math.max(1, Math.floor(Math.min(dw / needW, (dh - hud) / needH, dw / 110)));
  VW = Math.ceil(dw / SCALE); VH = Math.ceil(dh / SCALE);
  cv.width = VW; cv.height = VH;
  cv.style.width = `${(VW * SCALE) / dpr}px`; cv.style.height = `${(VH * SCALE) / dpr}px`;
  CSS_K = VW / ((VW * SCALE) / dpr);
  g.imageSmoothingEnabled = false;
  sky = null;
}
const scratch = {};
function getCanvas(key, w, h) {
  let c = scratch[key];
  if (!c) { c = scratch[key] = document.createElement('canvas'); c.ctx = c.getContext('2d'); }
  if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
  return c;
}

// ============================================================ sphere sprites (characters & enemies)
const LIGHT = (() => { const v = [-0.5, -0.66, 0.56], l = Math.hypot(...v); return v.map((x) => x / l); })();
const ID3 = [1, 0, 0, 0, 1, 0, 0, 0, 1];
const EYE_DEF = { x: 0.3, y: -0.1, rx: 0.12, ry: 0.25 };
/* o: { r, pal (5 hex: outline→light), M, sx, sy, cut, eyes, mouth, blush, spots, eye, alpha } */
function sphereSprite(key, o) {
  const r = o.r, sx = o.sx || 1, sy = o.sy || 1, M = o.M || ID3;
  const W = Math.ceil(r * sx) * 2 + 3, H = Math.ceil(r * sy) * 2 + 3;
  const c = getCanvas(key, W, H), ctx = c.ctx;
  const img = ctx.createImageData(W, H), d = img.data;
  const pal = o.pal.map(rgb), E = o.eye || EYE_DEF;
  const fill = new Uint8Array(W * H);
  const dark = rgb('#1B1030'), iris = rgb('#3B4FD0'), white = [255, 255, 255], mouthC = rgb('#7A1830'), blushC = rgb('#FF6F98'), spotC = rgb('#FFF6EC');
  for (let py = 0; py < H; py++) {
    for (let px = 0; px < W; px++) {
      const nx = (px + 0.5 - W / 2) / (r * sx), ny = (py + 0.5 - H / 2) / (r * sy);
      const d2 = nx * nx + ny * ny;
      if (d2 > 1) continue;
      if (o.cut != null && ny > o.cut) continue;
      const nz = Math.sqrt(1 - d2);
      const dif = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2];
      let s = dif * 0.55 + 0.48 + (BAYER[py & 3][px & 3] / 16 - 0.5) * 0.2;
      // bounce light from the ground on the lower-right rim
      if (ny > 0.35 && d2 > 0.7) s += 0.12;
      let col = pal[1 + clamp(Math.floor(s * 4), 0, 3)];
      // body-space point (rotate the view normal back into the ball)
      const b0 = M[0] * nx + M[3] * ny + M[6] * nz, b1 = M[1] * nx + M[4] * ny + M[7] * nz, b2 = M[2] * nx + M[5] * ny + M[8] * nz;
      if (o.spots) for (const sp of o.spots) { const dx = b0 - sp[0], dy = b1 - sp[1], dz = b2 - sp[2]; if (dx * dx + dy * dy + dz * dz < sp[3] * sp[3]) col = s > 0.55 ? spotC : shade(spotC, 0.85); }
      if (b2 > 0.25) {
        for (const side of [-1, 1]) {
          const ex = b0 - side * E.x, ey = b1 - E.y;
          switch (o.eyes) {
            case 'open': case 'focus': {
              const ry = o.eyes === 'focus' ? E.ry * 0.6 : E.ry, oy = o.eyes === 'focus' ? 0.06 : 0;
              const q = (ex / E.rx) ** 2 + ((ey - oy) / ry) ** 2;
              if (q < 1) {
                col = (ey - oy) > ry * 0.35 ? iris : dark;
                if (((ex + E.rx * 0.2) / (E.rx * 0.55)) ** 2 + ((ey - oy + ry * 0.45) / (ry * 0.32)) ** 2 < 1) col = white;
              }
              break;
            }
            case 'blink': if (Math.abs(ey - 0.04) < 0.035 && Math.abs(ex) < E.rx * 1.1) col = dark; break;
            case 'happy': { const dd = Math.hypot(ex, ey - 0.08); if (Math.abs(dd - E.rx * 1.05) < 0.04 && ey < 0.06) col = dark; break; }
            case 'dizzy': if (Math.hypot(ex, ey) < E.rx * 1.25 && (Math.abs(ex - ey) < 0.04 || Math.abs(ex + ey) < 0.04)) col = dark; break;
            case 'angry': {
              const q = (ex / E.rx) ** 2 + ((ey - 0.03) / (E.ry * 0.7)) ** 2;
              if (q < 1 && ey > -side * ex * 0.9 - 0.06) col = dark;
              break;
            }
          }
          if (o.blush && b2 > 0.4) {
            const q = ((b0 - side * 0.52) / 0.13) ** 2 + ((b1 - 0.16) / 0.07) ** 2;
            if (q < 1 && ((px + py) & 1)) col = blushC;
          }
        }
        if (o.mouth === 'o') { if (((b0) / 0.07) ** 2 + ((b1 - 0.2) / 0.08) ** 2 < 1) col = mouthC; }
        else if (o.mouth === 'smile') { const dd = Math.hypot(b0, b1 - 0.1); if (Math.abs(dd - 0.09) < 0.035 && b1 > 0.12) col = mouthC; }
        else if (o.mouth === 'grin') { if ((b0 / 0.12) ** 2 + ((b1 - 0.13) / 0.11) ** 2 < 1 && b1 > 0.13) col = mouthC; }
      }
      if (dif > 0.86 && (nx + 0.42) ** 2 + (ny + 0.48) ** 2 < 0.035) col = white;
      const i = (py * W + px) * 4;
      d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = o.alpha != null ? o.alpha : 255;
      fill[py * W + px] = 1;
    }
  }
  // 1px outline (selective: darker on the shadow side)
  const ol = pal[0];
  for (let py = 0; py < H; py++) for (let px = 0; px < W; px++) {
    const k = py * W + px; if (fill[k]) continue;
    if ((px > 0 && fill[k - 1]) || (px < W - 1 && fill[k + 1]) || (py > 0 && fill[k - W]) || (py < H - 1 && fill[k + W])) {
      const i = k * 4; d[i] = ol[0]; d[i + 1] = ol[1]; d[i + 2] = ol[2]; d[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return c;
}

// tiny hand-made pixel sprites
const PX = {
  folha: { p: { g: '#2F8A3E', G: '#7FDB6A', b: '#6A4030' }, f: [['...gg', '..gGg', '.gGg.', '..b..'], ['..gg.', '.gGg.', '.gGg.', '..b..']] },
  chama: { p: { y: '#FFE36E', Y: '#FFFFFF', o: '#FF8A2A', r: '#E0402A' }, f: [['..y..', '.yYy.', '.oYo.', 'roooR'.replace('R', 'r')], ['.y...', '.yYy.', 'oYYo.', '.ooo.']] },
  nuvem: { p: { w: '#DDEBFF', W: '#FFFFFF', s: '#9FB8E6' }, f: [['.ww...', 'wWWw..', 'sWWWww', '.ssss.'], ['..ww..', '.wWWw.', 'sWWWWw', '.ssss.']] },
  broto: { p: { r: '#E04A5A', R: '#FF8A94', w: '#FFFFFF', s: '#F2E2C4' }, f: [['.rrr.', 'rRwRr', 'rrrrr', '..s..'], ['.rrr.', 'rRwRr', 'rrrrr', '..s..']] },
  rocha: { p: { k: '#3A3648', g: '#8A869A', G: '#C8C4D8', w: '#FFFFFF' }, f: [['..kkk..', '.kgGgk.', 'kgGwGgk', 'kgGGggk', 'kggggk.', '.kkkk..']] },
  turbo: { p: { k: '#6A3A00', y: '#FFD45C', w: '#FFFFFF' }, f: [['...kkk', '..kyyk', '.kywk.', 'kyyyyk', '.kwyk.', '.kyk..', 'kk....']] },
  mola: { p: { k: '#1F4A2A', g: '#6EE7A8', w: '#FFFFFF' }, f: [['..kk..', '.kwgk.', 'kggggk', '..gk..', '.kgk..', '..gk..', '.kkk..']] },
  wingL: { p: { k: '#3A1E66', w: '#E8DAFF', p: '#B89CF0' }, f: [['kk...', 'kwpk.', '.kwpk', '..kk.'], ['.....', 'kkkk.', 'kwwpk', '.kkk.'], ['..kk.', '.kwpk', 'kwpk.', 'kk...']] },
};
function drawPx(ctx, id, x, y, frame = 0, flip = false) {
  const s = PX[id], f = s.f[frame % s.f.length];
  for (let r = 0; r < f.length; r++) for (let c = 0; c < f[r].length; c++) {
    const ch = f[r][c]; if (ch === '.') continue;
    ctx.fillStyle = s.p[ch]; ctx.fillRect(x + (flip ? f[r].length - 1 - c : c), y + r, 1, 1);
  }
}

// rotation helpers for rolling (row-major 3x3, view = M * body)
function rotM(M, ax, ay, az, ang) {
  const c = Math.cos(ang), s = Math.sin(ang), t = 1 - c;
  const R = [t * ax * ax + c, t * ax * ay - s * az, t * ax * az + s * ay, t * ax * ay + s * az, t * ay * ay + c, t * ay * az - s * ax, t * ax * az - s * ay, t * ay * az + s * ax, t * az * az + c];
  const o = new Array(9);
  for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) o[i * 3 + j] = R[i * 3] * M[j] + R[i * 3 + 1] * M[3 + j] + R[i * 3 + 2] * M[6 + j];
  return ortho(o);
}
function ortho(M) {
  let a = [M[0], M[3], M[6]], b = [M[1], M[4], M[7]];
  let l = Math.hypot(...a); a = a.map((v) => v / l);
  const dt = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; b = [b[0] - dt * a[0], b[1] - dt * a[1], b[2] - dt * a[2]];
  l = Math.hypot(...b); b = b.map((v) => v / l);
  const c = [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  return [a[0], b[0], c[0], a[1], b[1], c[1], a[2], b[2], c[2]];
}
// world ground axes in view space (2:1 dimetric, 30° elevation)
const EXV = [0.707, 0.354, 0.612], EYV = [-0.707, 0.354, 0.612], UPV = [0, -0.866, 0.5];

// ============================================================ course
const TH = 4, TWH = 8, HZ = 6, BOTTOM = -1.8;
const TILE_TYPES = { g: 'grass', s: 'sand', w: 'water', i: 'ice', b: 'grass' };
const DASH = { X: [1, 0], x: [-1, 0], Y: [0, 1], y: [0, -1] };
const SLOPE = { A: '+x', B: '+y', C: '-x', D: '-y' };
const FRICTION = { grass: 4.4, sand: 15, ice: 0.75, water: 4, dash: 4.4 };
let hole = null;

function parseHole(def) {
  const rows = def.map.map((r) => r.trim().split(/\s+/));
  const H = rows.length, W = rows[0].length, cells = [];
  let maxH = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const tok = rows[y][x];
    if (!tok || tok === '..') { cells.push(null); continue; }
    const ch = tok[0], h = +tok[1] || 0;
    const c = { x, y, h, type: TILE_TYPES[ch] || 'grass', slope: SLOPE[ch] || null, dash: DASH[ch] || null, bumper: ch === 'b' };
    if (c.dash) c.type = 'dash';
    maxH = Math.max(maxH, h + (c.slope ? 1 : 0));
    cells.push(c);
  }
  const ho = { def, W, H, cells, maxH };
  ho.cell = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? undefined : cells[y * W + x]);
  for (const c of cells) if (c) c.spr = buildColumn(ho, c);
  ho.bumpers = cells.filter((c) => c && c.bumper).map((c) => ({ x: c.x + 0.5, y: c.y + 0.5, z: c.h, squash: 0 }));
  return ho;
}
function corners(c) {
  const h = c.type === 'water' ? c.h - 0.2 : c.h;
  switch (c.slope) {
    case '+x': return [h, h + 1, h + 1, h];
    case '-x': return [h + 1, h, h, h + 1];
    case '+y': return [h, h, h + 1, h + 1];
    case '-y': return [h + 1, h + 1, h, h];
    default: return [h, h, h, h];
  }
}
// surface height; undefined cell = outside (wall), null = void (fall)
function surf(x, y) {
  const fx = Math.floor(x), fy = Math.floor(y), c = hole.cell(fx, fy);
  if (c === undefined) return Infinity;
  if (c === null) return -Infinity;
  const k = corners(c), u = x - fx, v = y - fy;
  return lerp(lerp(k[0], k[1], u), lerp(k[3], k[2], u), v);
}
function gradOf(c) {
  switch (c && c.slope) { case '+x': return [1, 0]; case '-x': return [-1, 0]; case '+y': return [0, 1]; case '-y': return [0, -1]; default: return [0, 0]; }
}

// ---------- tile column sprites (pre-rendered per hole)
const PAL = {
  grassA: rgb('#5BD06A'), grassB: rgb('#47BD5C'), grassHi: rgb('#9BF08A'), grassLip: rgb('#2F9A48'), grassDark: rgb('#2C8442'),
  sand: rgb('#F4D58C'), sandB: rgb('#EBC775'), sandHi: rgb('#FFF0C0'), sandLip: rgb('#C9A050'),
  ice: rgb('#BDEFFF'), iceB: rgb('#A4E3FA'), iceHi: rgb('#FFFFFF'), iceLip: rgb('#7CC8E8'),
  water: rgb('#3F9BEA'), waterB: rgb('#3A8EE0'), waterHi: rgb('#A8E2FF'), waterLip: rgb('#2C6CC0'),
  dash: rgb('#FF9A4A'), dashB: rgb('#FF8A3C'), dashHi: rgb('#FFE08A'),
  earthL: [rgb('#B07A86'), rgb('#9C6676')], earthR: [rgb('#7E4E66'), rgb('#6C4058')], earthLine: rgb('#5A3250'), pebble: rgb('#D8A6A8'),
  rail: rgb('#FFF4E0'), post: rgb('#E2C8B0'), postDark: rgb('#9A7488'),
};
function inPoly(pts, x, y) {
  let sign = 0;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[i], b = pts[(i + 1) % pts.length];
    const cr = (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0]);
    if (Math.abs(cr) < 1e-9) continue;
    const sg = cr > 0 ? 1 : -1;
    if (!sign) sign = sg; else if (sg !== sign) return false;
  }
  return true;
}
function buildColumn(ho, c) {
  const k = corners(c), top = Math.max(...k), K = top * HZ + 6;
  const P = (u, v, z) => [(u - v) * TWH + TWH, (u + v) * TH - z * HZ + K];
  const Wd = 16, Hd = Math.ceil(8 - BOTTOM * HZ + K) + 2;
  const cnv = document.createElement('canvas'); cnv.width = Wd; cnv.height = Hd;
  const ctx = cnv.getContext('2d'), img = ctx.createImageData(Wd, Hd), d = img.data;
  const topP = [P(0, 0, k[0]), P(1, 0, k[1]), P(1, 1, k[2]), P(0, 1, k[3])];
  const rightP = [P(1, 0, k[1]), P(1, 1, k[2]), P(1, 1, BOTTOM), P(1, 0, BOTTOM)];
  const leftP = [P(0, 1, k[3]), P(1, 1, k[2]), P(1, 1, BOTTOM), P(0, 1, BOTTOM)];
  const put = (x, y, col, a = 255) => { const i = (y * Wd + x) * 4; d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = a; };
  const T = c.type, skin = T === 'sand' ? 'sand' : T === 'ice' ? 'ice' : T === 'water' ? 'water' : T === 'dash' ? 'dash' : 'grass';
  const lip = PAL[skin + 'Lip'] || PAL.grassLip;
  const isTop = new Uint8Array(Wd * Hd);
  const sideFace = (pts, A, B, pal, isLeft) => {
    for (let y = 0; y < Hd; y++) for (let x = 0; x < Wd; x++) {
      if (!inPoly(pts, x + 0.5, y + 0.5)) continue;
      const t = clamp((x + 0.5 - A[0]) / (B[0] - A[0]), 0, 1), yt = lerp(A[1], B[1], t), zt = lerp(A[2], B[2], t);
      const depth = (y + 0.5 - yt), z = zt - depth / HZ;
      if (z < BOTTOM + 1.1) { const th = (z - BOTTOM) / 1.1; if (BAYER[y & 3][x & 3] / 16 > th) continue; }
      let col;
      if (depth < 2 + ((x * 3 + c.x) % 2)) col = lip;
      else {
        const layer = Math.floor(z + 10), fr = z + 10 - layer;
        col = pal[layer & 1];
        if (fr > 1 - 1 / HZ) col = PAL.earthLine;
        else if (hash(c.x * 31 + x, c.y * 17 + y, layer) < 0.05) col = PAL.pebble;
        if (!isLeft && x === Wd - 1) col = shade(col, 0.85);
      }
      put(x, y, col);
    }
  };
  sideFace(leftP, [...P(0, 1, 0).slice(0, 1), P(0, 1, k[3])[1], k[3]], [P(1, 1, 0)[0], P(1, 1, k[2])[1], k[2]], PAL.earthL, true);
  sideFace(rightP, [P(1, 0, 0)[0], P(1, 0, k[1])[1], k[1]], [P(1, 1, 0)[0], P(1, 1, k[2])[1], k[2]], PAL.earthR, false);
  // top surface, textured in tile space (u, v)
  const g2 = gradOf(c), base = corners(c)[0];
  const zc = (u, v) => lerp(lerp(k[0], k[1], u), lerp(k[3], k[2], u), v);
  const light = { '+x': 1.12, '+y': 0.96, '-x': 0.84, '-y': 1.04 }[c.slope] || 1;
  const checker = (c.x + c.y) & 1;
  for (let y = 0; y < Hd; y++) for (let x = 0; x < Wd; x++) {
    if (!inPoly(topP, x + 0.5, y + 0.5)) continue;
    // invert the projection for flat or planar slope tops
    const X = (x + 0.5 - TWH) / TWH;
    const gx = g2[0], gy = g2[1], z0 = zc(0, 0);
    const Y = y + 0.5 - K + z0 * HZ;
    const a = 4 - 6 * gx, b = 4 - 6 * gy;
    const v = (Y - a * X) / (a + b), u = v + X;
    let col;
    if (skin === 'grass') {
      col = checker ? PAL.grassA : PAL.grassB;
      const hsh = hash(c.x * 97 + x, c.y * 61 + y, 7);
      if (hsh < 0.05) col = PAL.grassHi; else if (hsh < 0.08) col = PAL.grassDark;
    } else if (skin === 'sand') {
      col = ((x + y) & 1) && hash(x, y, c.x + c.y * 9) < 0.35 ? PAL.sandB : PAL.sand;
      if (hash(c.x * 7 + x, c.y * 5 + y) < 0.04) col = PAL.sandHi;
    } else if (skin === 'ice') {
      col = PAL.ice; const s = (u + v * 0.6 + c.x * 0.3) % 1; if (Math.abs(s - 0.5) < 0.05) col = PAL.iceHi; else if (s < 0.2) col = PAL.iceB;
    } else if (skin === 'water') {
      col = checker ? PAL.water : PAL.waterB;
    } else {
      col = checker ? PAL.dash : PAL.dashB;
    }
    col = shade(col, light);
    put(x, y, col); isTop[y * Wd + x] = 1;
    void u;
  }
  // rim light on the back edges of the top
  for (let y = 1; y < Hd; y++) for (let x = 0; x < Wd; x++) {
    if (isTop[y * Wd + x] && !isTop[(y - 1) * Wd + x]) {
      const hi = PAL[skin + 'Hi'] || PAL.grassHi; put(x, y, mixc(hi, PAL.grassHi, skin === 'grass' ? 0 : 0.2));
    }
  }
  // fences on the outer border
  const edges = [];
  if (c.x === 0) edges.push([[0, 0], [0, 1]]);
  if (c.y === 0) edges.push([[0, 0], [1, 0]]);
  if (c.x === ho.W - 1) edges.push([[1, 0], [1, 1]]);
  if (c.y === ho.H - 1) edges.push([[0, 1], [1, 1]]);
  for (const [a, b] of edges) {
    const za = zc(a[0], a[1]), zb = zc(b[0], b[1]);
    const pa = P(a[0], a[1], za), pb = P(b[0], b[1], zb);
    const n = Math.max(1, Math.round(Math.abs(pb[0] - pa[0])));
    for (let i = 0; i <= n; i++) {
      const t = i / n, x = Math.round(lerp(pa[0], pb[0], t)), y = Math.round(lerp(pa[1], pb[1], t));
      if (x < 0 || x >= Wd) continue;
      if (y - 3 >= 0) put(x, y - 3, PAL.rail);
      if ((x + c.x * 16) % 4 === 0) { for (let yy = y - 3; yy <= y; yy++) if (yy >= 0) put(x, yy, yy === y ? PAL.postDark : PAL.post); }
    }
  }
  ctx.putImageData(img, 0, 0);
  return { cnv, K };
}

// ============================================================ projection & camera
const cam = { x: 0, y: 0, tx: 0, ty: 0, shake: 0 };
const P = (x, y, z) => ({ x: (x - y) * TWH, y: (x + y) * TH - z * HZ });
const sx = (x, y) => Math.round((x - y) * TWH - cam.x + VW / 2 + (cam.shake ? rand(-cam.shake, cam.shake) : 0));
function toScreen(x, y, z) { const p = P(x, y, z); return { x: Math.round(p.x - camX()), y: Math.round(p.y - camY()) }; }
let shakeX = 0, shakeY = 0;
const camX = () => cam.x - VW / 2 - shakeX, camY = () => cam.y - VH * 0.48 - shakeY;
void sx;

// ============================================================ particles
const parts = [];
function addPart(p) { parts.push(Object.assign({ vx: 0, vy: 0, g: 0, life: 0.6, age: 0, col: '#FFFFFF', type: 'px', size: 1 }, p)); if (parts.length > 400) parts.shift(); }
function burstStars(x, y, n = 10, cols = ['#FFE36E', '#FFFFFF', '#FF9EC0']) {
  for (let i = 0; i < n; i++) { const a = (i / n) * TAU + rand(-0.2, 0.2), s = rand(40, 90); addPart({ type: 'star', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s * 0.7 - 20, g: 60, life: rand(0.5, 0.8), col: pick(cols) }); }
  addPart({ type: 'ring', x, y, life: 0.4, size: 14, col: '#FFFFFF' });
}
function dust(x, y, n = 6, col = '#FFF4E0') { for (let i = 0; i < n; i++) addPart({ x: x + rand(-3, 3), y, vx: rand(-30, 30), vy: rand(-25, -5), g: 40, life: rand(0.25, 0.5), col }); }
function confetti(n = 60) { for (let i = 0; i < n; i++) addPart({ type: 'conf', screen: true, x: rand(0, VW), y: rand(-40, -5), vx: rand(-15, 15), vy: rand(20, 60), g: 30, life: rand(2, 3.5), col: pick(['#FFD45C', '#FF7FA8', '#6EE7A8', '#7FB2F2', '#FFFFFF', '#B89CF0']), ph: rand(0, TAU) }); }
function updateParts(dt) {
  for (let i = parts.length - 1; i >= 0; i--) {
    const p = parts[i]; p.age += dt; if (p.age >= p.life) { parts.splice(i, 1); continue; }
    p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt;
  }
}
function drawParts(world) {
  const ox = world ? camX() : 0, oy = world ? camY() : 0;
  for (const p of parts) {
    if (!!p.screen === world) continue;
    const k = p.age / p.life, x = Math.round(p.x - ox), y = Math.round(p.y - oy);
    g.fillStyle = p.col;
    switch (p.type) {
      case 'px': if (k < 0.8 || ((x + y) & 1)) g.fillRect(x, y, p.size, p.size); break;
      case 'star':
        g.globalCompositeOperation = 'lighter';
        g.fillRect(x, y, 1, 1);
        if (k < 0.6) { g.fillRect(x - 1, y, 3, 1); g.fillRect(x, y - 1, 1, 3); }
        if (k < 0.25) { g.fillRect(x - 2, y, 5, 1); g.fillRect(x, y - 2, 1, 5); }
        g.globalCompositeOperation = 'source-over'; break;
      case 'ring': pixelCircle(x, y, Math.round(p.size * (0.3 + k)), p.col, k < 0.5 ? 1 : 2); break;
      case 'conf': g.fillRect(x + Math.round(Math.sin(p.age * 6 + p.ph) * 2), y, Math.sin(p.age * 9 + p.ph) > 0 ? 2 : 1, 1); break;
      case 'drop': g.fillRect(x, y, 1, 2); break;
    }
  }
}
function pixelCircle(cx, cy, r, col, skip = 1) {
  g.fillStyle = col;
  let x = r, y = 0, err = 1 - r, i = 0;
  while (x >= y) {
    if (i++ % skip === 0) for (const [a, b] of [[x, y], [y, x], [-y, x], [-x, y], [-x, -y], [-y, -x], [y, -x], [x, -y]]) g.fillRect(cx + a, cy + Math.round(b * 0.6), 1, 1);
    y++; if (err < 0) err += 2 * y + 1; else { x--; err += 2 * (y - x) + 1; }
  }
}

// ============================================================ game state
const SAVE = 'gramado-estelar-v1';
let save = { best: null, char: 0, music: true, sfx: true };
try { Object.assign(save, JSON.parse(localStorage.getItem(SAVE) || '{}')); } catch (e) { /* storage blocked */ }
const persist = () => { try { localStorage.setItem(SAVE, JSON.stringify(save)); } catch (e) { /* storage blocked */ } };
Audio.musicOn = save.music; Audio.sfxOn = save.sfx;

const G = {
  mode: 'title', holeIdx: 0, strokes: 0, scores: [], charIdx: save.char || 0, jump: false, ability: null,
  enemies: [], cup: null, t: 0, modeT: 0, lastRest: null, stone: 0, trans: null, previewSpin: 0,
};
const RB = 0.28;
const ball = { x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, onGround: true, M: ID3.slice(), sq: 0, sqv: 0, brake: false, blinkT: 2, face: 'open', faceT: 0, trailT: 0, airT: 0, scale: 1 };
const ch = () => CHARS[G.charIdx];

function loadHole(i) {
  G.holeIdx = i; G.strokes = 0; G.ability = null; G.cup = null; G.jump = false; G.stone = 0;
  hole = parseHole(window.HOLES[i]);
  const [sx0, sy0] = hole.def.start;
  Object.assign(ball, { x: sx0, y: sy0, vx: 0, vy: 0, vz: 0, onGround: true, M: ID3.slice(), sq: 0, sqv: 0, scale: 1 });
  ball.z = surf(ball.x, ball.y);
  G.lastRest = { x: ball.x, y: ball.y };
  G.enemies = hole.def.enemies.map((e, k) => ({ ...e, bx: e.x, by: e.y, z: 0, alive: true, pop: 0, id: k, flash: 0 }));
  for (const e of G.enemies) e.z = groundZ(e.x, e.y);
  // camera centered on the course
  const pts = [P(0, 0, hole.maxH), P(hole.W, 0, 0), P(0, hole.H, 0), P(hole.W, hole.H, BOTTOM)];
  hole.left = Math.min(...pts.map((p) => p.x)); hole.right = Math.max(...pts.map((p) => p.x));
  hole.top = Math.min(...pts.map((p) => p.y)) - 12; hole.bottom = Math.max(...pts.map((p) => p.y));
  hole.cx = (hole.left + hole.right) / 2; hole.cy = (hole.top + hole.bottom) / 2;
  resize();
  cam.x = hole.cx; cam.y = hole.cy;
  parts.length = 0;
  renderHud();
}
function groundZ(x, y) { const s = surf(x, y); return Number.isFinite(s) ? s : 0; }
const foesLeft = () => G.enemies.filter((e) => e.alive && e.t !== 'ourico').length;

function setMode(m) { G.mode = m; G.modeT = 0; renderHud(); }

// ============================================================ physics
const GRAV = 30, SLOPE_ACC = 7.5;
function stepBall(b, h, real) {
  const c = hole.cell(Math.floor(b.x), Math.floor(b.y));
  const ground = surf(b.x, b.y);
  const wasGround = b.z <= ground + 0.02 && b.vz <= 0.01;
  b.onGround = wasGround;
  if (wasGround) {
    b.z = ground; b.vz = 0;
    const gr = gradOf(c); b.vx -= gr[0] * SLOPE_ACC * h; b.vy -= gr[1] * SLOPE_ACC * h;
    if (c && c.dash) {
      const sp = 10; b.vx = lerp(b.vx, c.dash[0] * sp, 0.2); b.vy = lerp(b.vy, c.dash[1] * sp, 0.2);
      if (real && Math.random() < 0.3) { const s = toWorldPx(b.x, b.y, b.z); addPart({ x: s.x + rand(-3, 3), y: s.y, vy: -20, life: 0.3, col: '#FFE08A' }); }
    }
    const sp = Math.hypot(b.vx, b.vy);
    if (sp > 0) {
      const dec = (FRICTION[c ? c.type : 'grass'] || 4.4) * ch().fric * (real && b.brake ? 3.2 * ch().brake : 1);
      const ns = Math.max(0, sp - dec * h); b.vx *= ns / sp; b.vy *= ns / sp;
    }
  } else b.vz -= GRAV * h;
  const events = [];
  // x axis
  let nx = b.x + b.vx * h;
  if (blocked(b.x, b.y, nx + Math.sign(b.vx) * RB, b.y, b.z)) { b.vx = -b.vx * 0.62; nx = b.x; events.push('wall'); }
  b.x = nx;
  let ny = b.y + b.vy * h;
  if (blocked(b.x, b.y, b.x, ny + Math.sign(b.vy) * RB, b.z)) { b.vy = -b.vy * 0.62; ny = b.y; events.push('wall'); }
  b.y = ny;
  b.z += b.vz * h;
  const g2 = surf(b.x, b.y);
  if (b.z < g2) {
    if (b.vz < -5) { events.push(['land', -b.vz]); b.vz = -b.vz * 0.36; b.vx *= 0.9; b.vy *= 0.9; }
    else { if (b.vz < -1.5) events.push(['land', -b.vz]); b.vz = 0; }
    b.z = g2;
  } else if (wasGround && b.vz === 0 && b.z - g2 < 0.14) b.z = g2; // stick to downhill slopes
  return events;
}
// walls only exist between tiles; inside one tile the surface is continuous (slopes are climbable)
function blocked(fx, fy, x, y, z) {
  if (Math.floor(fx) === Math.floor(x) && Math.floor(fy) === Math.floor(y)) return false;
  return surf(x, y) > Math.max(z, surf(fx, fy)) + 0.32;
}
function toWorldPx(x, y, z) { const p = P(x, y, z); return { x: p.x, y: p.y }; }

function predict(vx, vy, vz) {
  const b = { x: ball.x, y: ball.y, z: ball.z, vx, vy, vz }, pts = [];
  for (let i = 0; i < 150; i++) {
    stepBall(b, 1 / 60, false);
    if (i % 3 === 0) pts.push(P(b.x, b.y, b.z));
    if (b.z < -3) break;
    if (Math.hypot(b.vx, b.vy) < 0.15 && b.vz === 0) break;
  }
  return pts;
}

function shoot(dirx, diry, power) {
  const c = ch();
  let sp = (2 + power * 10.5) * c.power;
  let vz = 0;
  if (G.jump) { vz = (5 + power * 7) * c.jump; sp *= 0.85; Audio.sfx('jump'); }
  ball.vx = dirx * sp; ball.vy = diry * sp; ball.vz = vz; ball.onGround = vz === 0;
  if (vz) ball.z += 0.01;
  ball.sq = -0.25; ball.sqv = 0;
  G.strokes += 1; G.jump = false; G.stone = 0;
  Audio.sfx('shoot', power);
  const s = toWorldPx(ball.x, ball.y, ball.z); dust(s.x, s.y + 6, 8);
  cam.shakeT = 0.1;
  setMode('roll');
}

function useAbility() {
  const ab = G.ability; if (!ab) return false;
  G.ability = null; renderHud();
  const s = toWorldPx(ball.x, ball.y, ball.z);
  if (ab === 'rocha') {
    G.stone = 1; ball.vx = 0; ball.vy = 0; if (!ball.onGround) ball.vz = -14; Audio.sfx('stone');
    burstStars(s.x, s.y, 6, ['#C8C4D8', '#FFFFFF']); shake(3);
  } else if (ab === 'turbo') {
    const sp = Math.hypot(ball.vx, ball.vy) || 1, dx = ball.vx / sp, dy = ball.vy / sp;
    ball.vx = dx * 12; ball.vy = dy * 12; ball.turbo = 0.6; Audio.sfx('ability'); burstStars(s.x, s.y, 8, ['#FFD45C', '#FFFFFF']);
  } else if (ab === 'mola') {
    ball.vz = 10 * ch().jump; ball.z += 0.02; ball.onGround = false; Audio.sfx('jump'); burstStars(s.x, s.y + 4, 6, ['#6EE7A8', '#FFFFFF']);
  }
  return true;
}
function shake(n) { cam.shake = Math.max(cam.shake, n); }

function defeat(e) {
  e.alive = false; e.pop = 0.35;
  const s = toWorldPx(e.x, e.y, e.z + 0.4);
  burstStars(s.x, s.y, 12); shake(2); Audio.sfx('defeat');
  ball.face = 'happy'; ball.faceT = 0.8;
  if (e.ab) { G.ability = e.ab; toast(`Habilidade: ${ABIL_NAME[e.ab]}!`); setTimeout(() => Audio.sfx('ability'), 200); }
  if (foesLeft() === 0) {
    let cx = e.x, cy = e.y;
    const cc = hole.cell(Math.floor(cx), Math.floor(cy));
    if (!cc || cc.type === 'water') { const n = nearestSolid(cx, cy); cx = n[0]; cy = n[1]; }
    G.cup = { x: cx, y: cy, z: groundZ(cx, cy), t: 0, armed: false };
    setTimeout(() => { Audio.sfx('cup'); toast('O buraco apareceu!'); }, 350);
    const sc = toWorldPx(cx, cy, G.cup.z); for (let i = 0; i < 14; i++) addPart({ type: 'star', x: sc.x + rand(-4, 4), y: sc.y - rand(0, 30), vy: rand(-40, -10), life: rand(0.6, 1.2), col: pick(['#FFE36E', '#FFFFFF']) });
  }
  renderHud();
}
const ABIL_NAME = { rocha: 'Rocha', turbo: 'Turbo', mola: 'Mola' };
function nearestSolid(x, y) {
  let best = [hole.def.start[0], hole.def.start[1]], bd = 1e9;
  for (const c of hole.cells) if (c && c.type !== 'water' && !c.slope) { const d = Math.hypot(c.x + 0.5 - x, c.y + 0.5 - y); if (d < bd) { bd = d; best = [c.x + 0.5, c.y + 0.5]; } }
  return best;
}

function updateBall(dt) {
  const n = Math.max(1, Math.ceil(dt * 120)), h = dt / n;
  for (let i = 0; i < n; i++) {
    const ev = stepBall(ball, h, true);
    for (const e of ev) {
      if (e === 'wall') { Audio.sfx('wall'); ball.sq = 0.25; shake(1); const s = toWorldPx(ball.x, ball.y, ball.z); dust(s.x, s.y, 4, '#FFFFFF'); }
      else if (e[0] === 'land') {
        const v = e[1]; ball.sq = clamp(v * 0.05, 0.1, 0.45);
        if (v > 3) { Audio.sfx('bounce', Math.min(v / 10, 1)); const s = toWorldPx(ball.x, ball.y, ball.z); dust(s.x, s.y + 6, 6); }
        if (G.stone) { shake(4); const s = toWorldPx(ball.x, ball.y, ball.z); dust(s.x, s.y + 6, 14, '#D8D4E4'); }
      }
    }
    collideObjects();
    if (G.mode !== 'roll') return;
    if (ball.z < BOTTOM - 1.5) { outOfBounds('fall'); return; }
    const c = hole.cell(Math.floor(ball.x), Math.floor(ball.y));
    if (c && c.type === 'water' && ball.z <= surf(ball.x, ball.y) + 0.05) { outOfBounds('water'); return; }
  }
  if (G.stone) { ball.vx = 0; ball.vy = 0; }
  // rolling orientation
  const sp = Math.hypot(ball.vx, ball.vy);
  if (sp > 0.01) {
    const V = [ball.vx * EXV[0] + ball.vy * EYV[0], ball.vx * EXV[1] + ball.vy * EYV[1], ball.vx * EXV[2] + ball.vy * EYV[2]];
    const w = [UPV[1] * V[2] - UPV[2] * V[1], UPV[2] * V[0] - UPV[0] * V[2], UPV[0] * V[1] - UPV[1] * V[0]];
    const wl = Math.hypot(...w);
    if (wl > 1e-6 && !G.stone) ball.M = rotM(ball.M, w[0] / wl, w[1] / wl, w[2] / wl, (sp / RB) * dt * 0.9);
  }
  if (ball.turbo > 0) { ball.turbo -= dt; const s = toWorldPx(ball.x, ball.y, ball.z); addPart({ type: 'star', x: s.x + rand(-3, 3), y: s.y + rand(-3, 3), life: 0.3, col: '#FFB45C' }); }
  if (sp > 6 && Math.random() < 0.5) { const s = toWorldPx(ball.x, ball.y, ball.z); addPart({ x: s.x + rand(-2, 2), y: s.y + rand(-2, 4), life: 0.3, col: 'rgba(255,255,255,0.8)' }); }
  // cup
  if (G.cup) {
    const d = Math.hypot(ball.x - G.cup.x, ball.y - G.cup.y);
    if (!G.cup.armed && d > 0.65) G.cup.armed = true;
    if (G.cup.armed && d < 0.3 && ball.z - G.cup.z < 0.25) {
      if (sp < 5.5) { sink(); return; }
      if (!ball.lipT || G.t - ball.lipT > 0.4) { ball.lipT = G.t; ball.vz = 2.6; ball.z += 0.02; Audio.sfx('lip'); }
    }
  }
  // stop
  const c = hole.cell(Math.floor(ball.x), Math.floor(ball.y));
  const onSlope = c && c.slope;
  if (ball.onGround && ball.vz === 0 && (sp < 0.16 || G.stone) && (!onSlope || G.stone)) {
    ball.vx = 0; ball.vy = 0; G.stone = 0;
    G.lastRest = { x: ball.x, y: ball.y };
    ball.brake = false;
    setMode('aim');
  }
}
function collideObjects() {
  for (const bm of hole.bumpers) {
    const dx = ball.x - bm.x, dy = ball.y - bm.y, d = Math.hypot(dx, dy);
    if (d < RB + 0.3 && ball.z < bm.z + 0.8 && d > 0.001) {
      const nx = dx / d, ny = dy / d; ball.x = bm.x + nx * (RB + 0.31); ball.y = bm.y + ny * (RB + 0.31);
      const sp = Math.max(Math.hypot(ball.vx, ball.vy) * 1.05, 7);
      ball.vx = nx * sp; ball.vy = ny * sp; bm.squash = 1; Audio.sfx('bumper'); shake(2);
      const s = toWorldPx(bm.x, bm.y, bm.z + 0.5); burstStars(s.x, s.y, 5, ['#FF7FA8', '#FFFFFF']);
    }
  }
  for (const e of G.enemies) {
    if (!e.alive) continue;
    const dx = ball.x - e.x, dy = ball.y - e.y, d = Math.hypot(dx, dy), ez = e.z + (e.t === 'piu' ? e.fly || 1.3 : 0.2);
    if (d < RB + 0.3 && Math.abs(ball.z + 0.2 - ez) < 0.65) {
      if (e.t === 'ourico') {
        if (d > 0.001) { const nx = dx / d, ny = dy / d; ball.x = e.x + nx * (RB + 0.31); ball.y = e.y + ny * (RB + 0.31); const sp = Math.max(Math.hypot(ball.vx, ball.vy) * 0.8, 3); ball.vx = nx * sp; ball.vy = ny * sp; }
        if (e.flash <= 0) { Audio.sfx('spike'); shake(3); ball.face = 'dizzy'; ball.faceT = 0.9; e.flash = 0.4; }
      } else defeat(e);
    }
  }
}
function outOfBounds(kind) {
  setMode('out');
  G.strokes += 1;
  const s = toWorldPx(ball.x, ball.y, Math.max(ball.z, BOTTOM));
  if (kind === 'water') { Audio.sfx('splash'); for (let i = 0; i < 18; i++) addPart({ type: 'drop', x: s.x, y: s.y, vx: rand(-40, 40), vy: rand(-90, -30), g: 260, life: 0.7, col: pick(['#A8E2FF', '#FFFFFF', '#3F9BEA']) }); ball.hidden = true; }
  else Audio.sfx('fall');
  toast(kind === 'water' ? 'Splash! +1 tacada' : 'Caiu! +1 tacada');
  const h0 = hole;
  setTimeout(() => {
    if (hole !== h0) return;
    Object.assign(ball, { x: G.lastRest.x, y: G.lastRest.y, vx: 0, vy: 0, vz: 0, hidden: false, M: ID3.slice() });
    ball.z = surf(ball.x, ball.y); ball.sq = -0.3;
    const p = toWorldPx(ball.x, ball.y, ball.z); burstStars(p.x, p.y, 6, ['#FFFFFF', '#B89CF0']);
    if (G.mode === 'out') setMode('aim');
  }, 1000);
}
function sink() {
  setMode('sink');
  Audio.sfx('sink'); confetti(70); shake(2);
  ball.vx = ball.vy = ball.vz = 0; ball.x = G.cup.x; ball.y = G.cup.y;
  G.scores[G.holeIdx] = G.strokes;
  const h0 = hole; setTimeout(() => { if (hole === h0 && G.mode === 'sink') showResult(); }, 1300);
}

// ============================================================ rendering
let sky = null;
function buildSky() {
  const c = document.createElement('canvas'); c.width = VW; c.height = VH;
  const ctx = c.getContext('2d'), img = ctx.createImageData(VW, VH), d = img.data;
  const stops = [[0, rgb('#120C34')], [0.35, rgb('#2B2168')], [0.62, rgb('#6A3E9E')], [0.82, rgb('#D4699E')], [1, rgb('#FFB27A')]];
  const bands = 14;
  for (let y = 0; y < VH; y++) {
    const t = y / VH;
    for (let x = 0; x < VW; x++) {
      const tq = clamp(Math.floor(t * bands + BAYER[y & 3][x & 3] / 16) / bands, 0, 1);
      let i = 0; while (i < stops.length - 2 && tq > stops[i + 1][0]) i++;
      const a = stops[i], b = stops[i + 1], k = clamp((tq - a[0]) / (b[0] - a[0]), 0, 1);
      const col = mixc(a[1], b[1], k), j = (y * VW + x) * 4;
      d[j] = col[0]; d[j + 1] = col[1]; d[j + 2] = col[2]; d[j + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  // big dithered planet
  const pr = Math.round(Math.min(VW, VH) * 0.17), pcx = Math.round(VW * 0.8), pcy = Math.round(VH * 0.16);
  const pi = ctx.getImageData(0, 0, VW, VH), pd = pi.data;
  for (let y = -pr; y <= pr; y++) for (let x = -pr; x <= pr; x++) {
    const d2 = (x * x + y * y) / (pr * pr); if (d2 > 1) continue;
    const X = pcx + x, Y = pcy + y; if (X < 0 || Y < 0 || X >= VW || Y >= VH) continue;
    const nz = Math.sqrt(1 - d2), l = (-x * 0.6 - y * 0.5) / pr * 0.6 + nz * 0.6;
    const v = l + (BAYER[Y & 3][X & 3] / 16 - 0.5) * 0.25;
    const col = v > 0.75 ? rgb('#FFE6F0') : v > 0.5 ? rgb('#F7A8C8') : v > 0.25 ? rgb('#C77AB8') : rgb('#7A4A9A');
    const band = Math.sin((y / pr) * 7 + x / pr) > 0.7 && v > 0.3 ? 0.9 : 1;
    const j = (Y * VW + X) * 4; pd[j] = col[0] * band; pd[j + 1] = col[1] * band; pd[j + 2] = col[2] * band;
  }
  ctx.putImageData(pi, 0, 0);
  // ring
  ctx.fillStyle = '#FFD7E6';
  for (let a = 0; a < TAU; a += 0.012) { const x = Math.round(pcx + Math.cos(a) * pr * 1.7), y = Math.round(pcy + Math.sin(a) * pr * 0.32 + Math.cos(a) * pr * 0.1); if (Math.sin(a) > 0 || (x - pcx) ** 2 / (pr * pr) + (y - pcy) ** 2 / (pr * pr) > 1) ctx.fillRect(x, y, 1, 1); }
  sky = c;
}
const STARS = Array.from({ length: 70 }, (_, i) => [hash(i, 1), hash(i, 2) * 0.6, hash(i, 3)]);
const CLOUDS = Array.from({ length: 7 }, (_, i) => ({ x: hash(i, 9), y: 0.35 + hash(i, 10) * 0.6, s: 0.4 + hash(i, 11) * 0.8, sp: 2 + hash(i, 12) * 5, layer: i % 2 }));
function drawSky(t) {
  if (!sky) buildSky();
  g.drawImage(sky, 0, 0);
  for (const [sx0, sy0, ph] of STARS) {
    const tw = Math.sin(t * 2 + ph * 20);
    if (tw < -0.6) continue;
    const x = Math.round(sx0 * VW), y = Math.round(sy0 * VH);
    g.fillStyle = tw > 0.85 ? '#FFFFFF' : 'rgba(255,240,220,0.7)';
    g.fillRect(x, y, 1, 1);
    if (tw > 0.93) { g.fillRect(x - 1, y, 3, 1); g.fillRect(x, y - 1, 1, 3); }
  }
  for (const c of CLOUDS) {
    const w = Math.round(30 * c.s + 10), x = Math.round(((c.x * (VW + 120) + t * c.sp - camX() * (c.layer ? 0.08 : 0.04)) % (VW + 120)) - 60), y = Math.round(c.y * VH - camY() * 0.05);
    drawCloud(x, y, w, c.layer);
  }
}
function drawCloud(x, y, w, layer) {
  const cols = layer ? ['#F7B7D2', '#FFE0EC'] : ['#B98AC8', '#E2B6E0'];
  const h = Math.round(w * 0.3);
  g.fillStyle = cols[0]; g.fillRect(x, y, w, h); g.fillRect(x + 2, y - 2, w - 4, 2);
  g.fillStyle = cols[1];
  g.fillRect(x + Math.round(w * 0.15), y - Math.round(h * 0.7), Math.round(w * 0.35), Math.round(h * 0.8));
  g.fillRect(x + Math.round(w * 0.45), y - Math.round(h * 1.0), Math.round(w * 0.3), Math.round(h * 1.1));
  g.fillRect(x + 3, y - 1, w - 6, Math.round(h * 0.5));
}

function drawWorld(t) {
  const ox = camX(), oy = camY();
  // painter's order: tiles by x+y, objects slotted between
  const objs = [];
  if (!ball.hidden && G.mode !== 'title') objs.push({ k: Math.floor(ball.x) + Math.floor(ball.y) + 0.5, draw: drawBall, depth: ball.x + ball.y });
  for (const e of G.enemies) if (e.alive || e.pop > 0) objs.push({ k: Math.floor(e.x) + Math.floor(e.y) + 0.5, draw: () => drawEnemy(e, t), depth: e.x + e.y });
  for (const bm of hole.bumpers) objs.push({ k: Math.floor(bm.x) + Math.floor(bm.y) + 0.5, draw: () => drawBumper(bm), depth: bm.x + bm.y - 0.01 });
  if (G.cup) objs.push({ k: Math.floor(G.cup.x) + Math.floor(G.cup.y) + 0.5, draw: () => drawCup(t), depth: G.cup.x + G.cup.y - 0.02 });
  objs.sort((a, b) => a.k - b.k || a.depth - b.depth);
  let oi = 0;
  const maxK = hole.W + hole.H;
  for (let s = 0; s <= maxK; s++) {
    while (oi < objs.length && objs[oi].k < s) objs[oi++].draw();
    for (let x = Math.max(0, s - hole.H + 1); x <= Math.min(s, hole.W - 1); x++) {
      const y = s - x, c = hole.cell(x, y); if (!c) continue;
      const p = P(x, y, 0), spr = c.spr;
      const X = Math.round(p.x - TWH - ox), Y = Math.round(p.y - spr.K - oy);
      g.drawImage(spr.cnv, X, Y);
      if (c.type === 'water') drawWater(c, X, Y + spr.K, t);
      else if (c.dash) drawDashArrows(c, X, Y + spr.K - c.h * HZ, t);
    }
  }
  while (oi < objs.length) objs[oi++].draw();
}
function drawWater(c, X, Y, t) {
  const top = Y - (c.h - 0.2) * HZ;
  g.fillStyle = '#A8E2FF';
  for (let i = 0; i < 3; i++) {
    const ph = (t * 0.6 + hash(c.x, c.y, i)) % 1, yy = Math.round(top + 1 + ph * 6), w = 3 + Math.round(Math.sin(t * 3 + i) * 1.5);
    const half = yy - top < 4 ? (yy - top) * 2 : (8 - (yy - top)) * 2;
    const xx = X + 8 - Math.round(half * 0.5) + Math.round(hash(c.x, c.y, i + 4) * Math.max(0, half - w));
    if (half > w) g.fillRect(xx, yy, w, 1);
  }
  if (((t * 2 + c.x * 0.37 + c.y * 0.71) % 3) < 0.15) { g.fillStyle = '#FFFFFF'; g.fillRect(X + 7, Math.round(top + 3), 1, 1); }
}
function drawDashArrows(c, X, top, t) {
  const ph = (t * 2.2) % 1, [dx, dy] = c.dash;
  g.fillStyle = '#FFF6C8';
  for (let k = 0; k < 2; k++) {
    const a = ((ph + k * 0.5) % 1) - 0.5;
    const u = 0.5 + dx * a * 0.8, v = 0.5 + dy * a * 0.8;
    const sxp = X + 8 + (u - v) * 8, syp = top + (u + v) * 4;
    const ex = (dx - dy) * 8, ey = (dx + dy) * 4, L = Math.hypot(ex, ey), fx = ex / L, fy = ey / L;
    for (let i = -2; i <= 2; i++) {
      const back = Math.abs(i) * 1.3;
      g.fillRect(Math.round(sxp - fx * back - fy * i * 1.2), Math.round(syp - fy * back + fx * i * 0.6), 1, 1);
    }
  }
}
function drawShadow(x, y, z, r) {
  const gz = surf(x, y); if (!Number.isFinite(gz)) return;
  const p = toScreen(x, y, gz), h = Math.max(0, z - gz), k = clamp(1 - h * 0.25, 0.4, 1);
  const rx = Math.round(r * k), ry = Math.max(1, Math.round(r * 0.45 * k));
  g.fillStyle = 'rgba(30,14,50,0.42)';
  for (let yy = -ry; yy <= ry; yy++) for (let xx = -rx; xx <= rx; xx++) {
    if ((xx * xx) / (rx * rx) + (yy * yy) / (ry * ry) > 1) continue;
    if ((xx * xx) / (rx * rx) + (yy * yy) / (ry * ry) > 0.55 && ((xx + yy) & 1)) continue;
    g.fillRect(p.x + xx, p.y + yy, 1, 1);
  }
}

function ballFace() {
  if (G.stone) return 'angry';
  if (ball.faceT > 0) return ball.face;
  if (G.mode === 'aim' && aim.on) return 'focus';
  if (ball.blink > 0) return 'blink';
  return 'open';
}
function drawCharacter(cIdx, x, y, r, M, sq, face, mouth, upright, t, alpha) {
  const c = CHARS[cIdx];
  const spr = sphereSprite('ch' + r, { r, pal: G.stone && cIdx === G.charIdx && r < 12 ? STONE : c.body, M, sx: 1 + sq, sy: 1 - sq, eyes: face, mouth, blush: true, alpha });
  const X = Math.round(x - spr.width / 2), Y = Math.round(y - spr.height + 1);
  if (upright) {
    // feet
    const fw = Math.max(2, Math.round(r * 0.45)), fh = Math.max(1, Math.round(r * 0.22));
    g.fillStyle = c.feet;
    g.fillRect(Math.round(x - r * 0.55 - fw / 2), Y + spr.height - fh - 1, fw, fh + 1);
    g.fillRect(Math.round(x + r * 0.55 - fw / 2), Y + spr.height - fh - 1, fw, fh + 1);
  }
  g.drawImage(spr, X, Y);
  if (upright && !G.stone) {
    const scale = r >= 14 ? 2 : 1, frame = Math.floor(t * 4) % 2, f = PX[c.acc].f[0], aw = f[0].length, ah = f.length;
    if (scale === 1) drawPx(g, c.acc, Math.round(x - aw / 2), Y - ah + 2, frame);
    else { g.save(); g.translate(Math.round(x - aw), Y - ah * 2 + 4); g.scale(2, 2); drawPx(g, c.acc, 0, 0, frame); g.restore(); }
  }
}
function drawBall() {
  const t = G.t, r = 7;
  const z = ball.z, gzv = surf(ball.x, ball.y);
  if (G.mode !== 'sink') drawShadow(ball.x, ball.y, z, 6);
  const p = toScreen(ball.x, ball.y, z);
  const upright = ball.M[4] > 0.9 && ball.M[8] > 0.9 && G.mode !== 'roll';
  let sq = ball.sq;
  if (G.mode === 'aim' && aim.on) sq += -aim.power * 0.15 + Math.sin(t * 30) * aim.power * 0.03;
  if (G.mode === 'aim' && !aim.on) sq += Math.sin(t * 3) * 0.04;
  const air = z - (Number.isFinite(gzv) ? gzv : z);
  if (air > 0.2 && G.mode === 'roll') sq = Math.max(-0.2, sq - Math.min(air * 0.06, 0.15));
  let mouth = ball.faceT > 0 && ball.face === 'happy' ? 'grin' : (air > 0.6 ? 'o' : (G.mode === 'aim' ? 'smile' : 'none'));
  if (G.mode === 'sink') {
    const k = clamp(G.modeT / 0.6, 0, 1); if (k >= 1) return;
    g.save(); g.globalAlpha = 1 - k * 0.3;
    drawCharacter(G.charIdx, p.x, p.y + Math.round(k * 6), Math.max(2, Math.round(r * (1 - k * 0.7))), ball.M, 0, 'happy', 'grin', false, t);
    g.restore(); return;
  }
  drawCharacter(G.charIdx, p.x, p.y + 2, r, ball.M, sq, ballFace(), mouth, upright, t);
  if (ball.brake && G.mode === 'roll' && Math.random() < 0.6) addPart({ x: p.x + camX() + rand(-4, 4), y: p.y + camY() + 2, vy: -10, life: 0.25, col: '#FFFFFF' });
}

const ENEMY_PAL = {
  gota: ['#163C26', '#2E7D4A', '#4CB86A', '#86E39B', '#D6FFDD'],
  cogu: ['#5A1420', '#B8323E', '#EE5A5A', '#FF9A8E', '#FFE0D8'],
  piu: ['#2A1858', '#5A3EA8', '#8A6AE0', '#BCA6FF', '#F0E8FF'],
  ourico: ['#141030', '#2E2A5E', '#4A4690', '#7A76C0', '#C8C4F0'],
};
function drawEnemy(e, t) {
  const pop = e.alive ? 0 : e.pop;
  if (!e.alive && pop <= 0) return;
  const sc = e.alive ? 1 : 1 + (0.35 - pop) * 2;
  let z = e.z, r = 6;
  const tt = t + e.id;
  const phase = t * 2 + e.id * 1.7;
  if (e.t === 'piu') z += (e.fly = 1.3 + Math.sin(phase * 1.5) * 0.15);
  if (e.alive) drawShadow(e.x, e.y, z, 5);
  const p = toScreen(e.x, e.y, z);
  if (!e.alive) { g.save(); g.globalAlpha = clamp(pop / 0.35, 0, 1); }
  switch (e.t) {
    case 'gota': {
      const bob = Math.sin(phase * 2) * 0.12;
      const spr = sphereSprite('e' + e.id, { r: r * sc, pal: ENEMY_PAL.gota, sx: 1.1 + bob, sy: 0.85 - bob, cut: 0.6, eyes: 'open', mouth: 'smile', eye: { x: 0.32, y: -0.05, rx: 0.13, ry: 0.22 } });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(p.y - spr.height + 1 + spr.height * 0.18));
      break;
    }
    case 'cogu': {
      g.fillStyle = '#5A3A2A'; g.fillRect(p.x - 4, p.y - 6, 8, 6);
      g.fillStyle = '#F2E2C4'; g.fillRect(p.x - 3, p.y - 6, 6, 5);
      g.fillStyle = '#FFF6E6'; g.fillRect(p.x - 3, p.y - 6, 2, 4);
      g.fillStyle = '#1B1030'; g.fillRect(p.x - 2, p.y - 4, 1, 2); g.fillRect(p.x + 1, p.y - 4, 1, 2);
      const step = Math.floor(phase * 3) % 2;
      g.fillStyle = '#5A3A2A'; g.fillRect(p.x - 3 + step, p.y, 2, 1); g.fillRect(p.x + 1 - step, p.y, 2, 1);
      const spr = sphereSprite('e' + e.id, { r: 7 * sc, pal: ENEMY_PAL.cogu, sx: 1.15, sy: 0.85, cut: 0.15, spots: [[-0.4, -0.5, 0.75, 0.22], [0.35, -0.65, 0.65, 0.2], [0.05, -0.3, 0.95, 0.16], [0.7, -0.2, 0.68, 0.16]] });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(p.y - 5 - spr.height * 0.6));
      break;
    }
    case 'piu': {
      const fr = Math.floor(t * 10 + e.id) % 3;
      drawPx(g, 'wingL', p.x - 10, p.y - 10, fr);
      drawPx(g, 'wingL', p.x + 5, p.y - 10, fr, true);
      const spr = sphereSprite('e' + e.id, { r: 5 * sc, pal: ENEMY_PAL.piu, eyes: 'open', eye: { x: 0.3, y: -0.12, rx: 0.14, ry: 0.24 } });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(p.y - spr.height));
      g.fillStyle = '#FFB13D'; g.fillRect(p.x - 1, p.y - 5, 2, 1); g.fillRect(p.x, p.y - 4, 1, 1);
      break;
    }
    case 'ourico': {
      const spin = t * 1.5, cy = p.y - 7;
      g.fillStyle = e.flash > 0 && (Math.floor(t * 20) & 1) ? '#FFFFFF' : '#E8E4FF';
      for (let i = 0; i < 8; i++) { const a = spin + (i / 8) * TAU; for (let k = 7; k <= 9; k++) g.fillRect(Math.round(p.x + Math.cos(a) * k), Math.round(cy + Math.sin(a) * k * 0.9), 1, 1); }
      const spr = sphereSprite('e' + e.id, { r: 6, pal: ENEMY_PAL.ourico, eyes: 'angry', eye: { x: 0.32, y: -0.05, rx: 0.15, ry: 0.22 } });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(cy - spr.height / 2));
      break;
    }
  }
  if (!e.alive) g.restore();
  if (e.alive && e.ab) {
    const bob = Math.round(Math.sin(tt * 4) * 1.5);
    const iy = p.y - (e.t === 'cogu' ? 24 : 20) + bob;
    g.fillStyle = 'rgba(27,16,48,0.7)'; g.fillRect(p.x - 5, iy - 1, 10, 9);
    drawPx(g, e.ab, p.x - 3, iy, 0);
  }
}
function drawBumper(bm) {
  bm.squash = Math.max(0, bm.squash - 0.06);
  const p = toScreen(bm.x, bm.y, bm.z), s = bm.squash, h = Math.round(5 - s * 3), w = Math.round(5 + s * 2);
  g.fillStyle = '#7A1E46'; g.fillRect(p.x - w - 1, p.y - h - 2, w * 2 + 2, h + 3);
  g.fillStyle = '#E04A82'; g.fillRect(p.x - w, p.y - h - 1, w * 2, h + 1);
  g.fillStyle = '#FFFFFF'; g.fillRect(p.x - w, p.y - h + 1, w * 2, 1);
  g.fillStyle = '#FF8AB8'; g.fillRect(p.x - w + 1, p.y - h - 4, w * 2 - 2, 3); g.fillRect(p.x - w + 2, p.y - h - 5, w * 2 - 4, 1);
  g.fillStyle = '#FFD6E6'; g.fillRect(p.x - w + 2, p.y - h - 4, 2, 1);
}
function drawCup(t) {
  const c = G.cup; c.t += 1 / 60;
  const p = toScreen(c.x, c.y, c.z), k = clamp(c.t / 0.4, 0, 1);
  if (k < 1) pixelCircle(p.x, p.y, Math.round(12 * (1 - k) + 2), '#FFE36E');
  g.fillStyle = '#FFF4E0'; g.fillRect(p.x - 5, p.y - 2, 10, 4); g.fillRect(p.x - 4, p.y - 3, 8, 6);
  g.fillStyle = '#140A24'; g.fillRect(p.x - 4, p.y - 1, 8, 2); g.fillRect(p.x - 3, p.y - 2, 6, 4);
  // flag
  const fh = Math.round(16 * k);
  g.fillStyle = '#FFFFFF'; g.fillRect(p.x + 3, p.y - fh, 1, fh);
  if (k >= 1) {
    const wv = Math.floor(t * 6) % 2;
    g.fillStyle = '#FF5A8A';
    for (let i = 0; i < 6; i++) { const hh = Math.max(1, 4 - Math.floor(i * 0.6)); g.fillRect(p.x + 4 + i, p.y - 16 + ((i + wv) % 2), 1, hh); }
    g.fillStyle = '#FFE36E'; g.fillRect(p.x + 6, p.y - 15 + wv, 1, 1);
    if (Math.random() < 0.1) addPart({ type: 'star', x: p.x + camX() + rand(-5, 5), y: p.y + camY() - rand(0, 10), vy: -15, life: 0.5, col: '#FFE36E' });
  }
}

// ---------- aiming
const aim = { on: false, sx: 0, sy: 0, x: 0, y: 0, power: 0, dir: [1, 0], pts: [], lastTick: 0 };
function screenDirToWorld(dx, dy) {
  const a = dx / TWH, b = dy / TH; // a = x - y, b = x + y
  const x = (a + b) / 2, y = (b - a) / 2, l = Math.hypot(x, y) || 1;
  return [x / l, y / l];
}
function updateAim() {
  const dx = (aim.sx - aim.x), dy = (aim.sy - aim.y);
  const len = Math.hypot(dx, dy);
  const full = Math.min(VW, VH) * 0.42;
  aim.power = clamp(len / full, 0, 1);
  if (len > 2) aim.dir = screenDirToWorld(dx, dy);
  const c = ch();
  let sp = (2 + aim.power * 10.5) * c.power, vz = 0;
  if (G.jump) { vz = (5 + aim.power * 7) * c.jump; sp *= 0.85; }
  aim.pts = predict(aim.dir[0] * sp, aim.dir[1] * sp, vz);
  const tick = Math.floor(aim.power * 10);
  if (tick !== aim.lastTick) { aim.lastTick = tick; Audio.sfx('tick', aim.power); }
}
function drawAim(t) {
  if (!aim.on || aim.power < 0.04) return;
  const ox = camX(), oy = camY(), n = aim.pts.length, show = Math.ceil(n * 0.55);
  for (let i = 0; i < show; i++) {
    const p = aim.pts[i]; const x = Math.round(p.x - ox), y = Math.round(p.y - oy);
    const fade = 1 - i / show;
    if ((i + Math.floor(t * 12)) % 3 === 0) continue;
    g.fillStyle = fade > 0.5 ? '#FFFFFF' : '#FFE36E';
    g.fillRect(x, y, 1, 1); if (fade > 0.6) g.fillRect(x + 1, y, 1, 1);
  }
  // power ring around the ball
  const p = toScreen(ball.x, ball.y, ball.z), segs = 20, on = Math.round(aim.power * segs);
  for (let i = 0; i < segs; i++) {
    const a = -Math.PI / 2 + (i / segs) * TAU, x = Math.round(p.x + Math.cos(a) * 13), y = Math.round(p.y - 5 + Math.sin(a) * 11);
    g.fillStyle = i < on ? (aim.power > 0.85 ? '#FF5A6A' : aim.power > 0.5 ? '#FFD45C' : '#6EE7A8') : 'rgba(27,16,48,0.55)';
    g.fillRect(x, y, 2, 2);
  }
}

// ============================================================ title showcase
function drawTitle(t, dt) {
  G.previewSpin += dt;
  const c = CHARS[G.charIdx], r = 18;
  const x = Math.round(VW / 2), base = Math.round(VH * 0.56);
  const hopT = (t * 1.1) % 1, hop = hopT < 0.45 ? Math.sin((hopT / 0.45) * Math.PI) * 18 : 0;
  const land = hopT > 0.45 && hopT < 0.6 ? Math.sin(((hopT - 0.45) / 0.15) * Math.PI) * 0.25 : 0;
  // little floating island
  const iw = 46, ih = 10, ix = x - iw / 2, iy = base + 2;
  g.fillStyle = '#7E4E66'; g.fillRect(ix + 4, iy + ih, iw - 8, 6); g.fillRect(ix + 10, iy + ih + 6, iw - 20, 5); g.fillRect(ix + 18, iy + ih + 11, iw - 36, 4);
  g.fillStyle = '#B07A86'; g.fillRect(ix + 4, iy + ih, iw / 2 - 4, 6); g.fillRect(ix + 10, iy + ih + 6, iw / 2 - 10, 5);
  g.fillStyle = '#2F9A48'; g.fillRect(ix, iy + 2, iw, ih - 2); g.fillRect(ix + 2, iy + ih, iw - 4, 2);
  g.fillStyle = '#5BD06A'; g.fillRect(ix + 2, iy, iw - 4, ih - 2);
  g.fillStyle = '#9BF08A'; g.fillRect(ix + 4, iy, iw - 8, 1);
  const k = 1 - Math.min(hop / 20, 0.5);
  g.fillStyle = 'rgba(30,14,50,0.35)'; g.fillRect(Math.round(x - 12 * k), iy + 3, Math.round(24 * k), 3);
  const M = rotM(ID3, 0, 1, 0, Math.sin(t * 1.3) * 0.5);
  drawCharacter(G.charIdx, x, iy + 4 - hop, r, M, land - (hop > 0 ? 0.12 : 0), Math.sin(t * 0.7) > 0.95 ? 'blink' : hop > 0 ? 'happy' : 'open', hop > 0 ? 'grin' : 'smile', true, t);
  void c;
}

// ============================================================ HUD / DOM
const toastEl = $('#toast');
let toastTimer = 0;
function toast(msg, ms = 1500) { toastEl.textContent = msg; toastEl.classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(() => toastEl.classList.remove('show'), ms); }
function renderHud() {
  const playing = ['aim', 'roll', 'out', 'sink'].includes(G.mode);
  $('#hud').hidden = !playing;
  if (!hole) return;
  $('#hHole').textContent = `Buraco ${G.holeIdx + 1}`;
  $('#hPar').textContent = `Par ${hole.def.par}`;
  $('#hStrokes').textContent = G.strokes;
  const foes = G.enemies.filter((e) => e.t !== 'ourico');
  $('#hFoes').innerHTML = foes.map((e) => `<i class="${e.alive ? '' : 'done'}"></i>`).join('') + (G.cup ? '<i class="cup"></i>' : '');
  const jb = $('#jumpBtn'); jb.setAttribute('aria-pressed', G.jump ? 'true' : 'false');
  const slot = $('#abilitySlot');
  slot.hidden = !G.ability;
  if (G.ability) {
    $('#abilityName').textContent = ABIL_NAME[G.ability];
    const ac = $('#abilityIco').getContext('2d'); ac.clearRect(0, 0, 9, 9); drawPx(ac, G.ability, 1, 1, 0);
  }
  $('#hint').textContent = G.mode === 'roll' ? (G.ability ? 'Toque para usar a habilidade' : 'Segure para frear') : G.mode === 'aim' ? (G.jump ? 'Tacada com pulo: arraste e solte' : 'Arraste para trás e solte') : '';
}
function showScreen(id) { for (const s of ['title', 'intro', 'result', 'final', 'pause']) $('#' + s).hidden = s !== id; }

function renderCharPicker() {
  const c = ch();
  $('#charName').textContent = c.name;
  $('#charDesc').textContent = c.desc;
  $('#charStats').innerHTML = ['Força', 'Controle', 'Pulo'].map((n, i) => `<dt>${n}</dt><dd>${Array.from({ length: 5 }, (_, k) => `<i class="${k < c.stats[i] ? 'on' : ''}"></i>`).join('')}</dd>`).join('');
  const b = save.best;
  $('#bestLine').textContent = b ? `Melhor campanha: ${b.total} tacadas (${fmtDiff(b.diff)}) com ${b.char}` : 'Seis buracos flutuando no céu';
}
const fmtDiff = (d) => (d === 0 ? 'no par' : d > 0 ? `+${d}` : `${d}`);
function rankName(strokes, par) {
  if (strokes === 1) return 'Na primeira!';
  const d = strokes - par;
  return d <= -3 ? 'Albatroz!' : d === -2 ? 'Águia!' : d === -1 ? 'Birdie!' : d === 0 ? 'Par!' : d === 1 ? 'Bogey' : d === 2 ? 'Duplo bogey' : `+${d}`;
}
function startIntro(i) {
  loadHole(i);
  $('#iNum').textContent = `Buraco ${i + 1} de ${window.HOLES.length}`;
  $('#iName').textContent = hole.def.name;
  $('#iPar').textContent = `Par ${hole.def.par}`;
  $('#iTip').textContent = hole.def.tip || 'Derrube todos os inimigos. O último vira o buraco!';
  setMode('intro'); resize(); cam.x = hole.cx; cam.y = hole.cy; showScreen('intro');
}
function beginPlay() { showScreen(null); setMode('aim'); const s = toWorldPx(ball.x, ball.y, ball.z); burstStars(s.x, s.y, 8); ball.sq = -0.3; Audio.sfx('select'); }
function showResult() {
  const par = hole.def.par, s = G.strokes, d = s - par;
  $('#rName').textContent = `Buraco ${G.holeIdx + 1} · ${hole.def.name}`;
  $('#rRank').textContent = rankName(s, par);
  const stars = s === 1 || d <= -1 ? 3 : d === 0 ? 2 : 1;
  $('#rStars').innerHTML = [0, 1, 2].map((i) => `<i class="${i < stars ? 'on' : ''}"></i>`).join('');
  $('#rLine').textContent = `${s} ${s === 1 ? 'tacada' : 'tacadas'} · Par ${par}`;
  $('#rNext').textContent = G.holeIdx + 1 < window.HOLES.length ? 'Próximo buraco' : 'Ver placar';
  setMode('clear'); showScreen('result');
}
function showFinal() {
  const H = window.HOLES, tot = G.scores.reduce((a, b) => a + b, 0), par = H.reduce((a, h) => a + h.par, 0), diff = tot - par;
  $('#fTable').innerHTML = '<tr><th>Buraco</th><th>Par</th><th>Tacadas</th></tr>' + H.map((h, i) => {
    const s = G.scores[i], cls = s < h.par ? 'under' : s > h.par ? 'over' : '';
    return `<tr><td>${i + 1}. ${h.name}</td><td>${h.par}</td><td class="${cls}">${s}</td></tr>`;
  }).join('');
  const record = !save.best || tot < save.best.total;
  $('#fTotal').textContent = `Total: ${tot} (${fmtDiff(diff)})${record ? ' · Novo recorde!' : ''}`;
  if (record) { save.best = { total: tot, diff, char: ch().name }; persist(); }
  setMode('final'); showScreen('final');
  confetti(90); Audio.sfx('sink');
}
function transition(cb) { G.trans = { t: 0, cb, done: false }; }

// ============================================================ input
function toInternal(e) { const r = cv.getBoundingClientRect(); return { x: (e.clientX - r.left) * CSS_K, y: (e.clientY - r.top) * CSS_K }; }
let pid = null;
cv.addEventListener('pointerdown', (e) => {
  Audio.init(); if (Audio.musicOn) Audio.startMusic();
  if (pid !== null) return;
  pid = e.pointerId; try { cv.setPointerCapture(pid); } catch (_) { /* */ }
  const p = toInternal(e);
  if (G.mode === 'aim') { aim.on = true; aim.sx = p.x; aim.sy = p.y; aim.x = p.x; aim.y = p.y; aim.power = 0; aim.pts = []; }
  else if (G.mode === 'roll') { if (!useAbility()) { ball.brake = true; Audio.sfx('brake'); } }
});
cv.addEventListener('pointermove', (e) => {
  if (e.pointerId !== pid) return;
  if (aim.on) { const p = toInternal(e); aim.x = p.x; aim.y = p.y; updateAim(); }
});
const release = (e) => {
  if (e.pointerId !== pid) return; pid = null;
  ball.brake = false;
  if (aim.on) {
    aim.on = false;
    if (G.mode === 'aim' && aim.power > 0.06 && e.type === 'pointerup') shoot(aim.dir[0], aim.dir[1], aim.power);
  }
};
cv.addEventListener('pointerup', release);
cv.addEventListener('pointercancel', release);
window.addEventListener('keydown', (e) => {
  if (e.key === ' ' && G.mode === 'roll') { if (!useAbility()) ball.brake = true; e.preventDefault(); }
  if ((e.key === 'j' || e.key === 'J') && G.mode === 'aim') { G.jump = !G.jump; renderHud(); }
  if (e.key === 'Escape' && ['aim', 'roll'].includes(G.mode)) openPause();
});
window.addEventListener('keyup', (e) => { if (e.key === ' ') ball.brake = false; });

const tap = (id, fn) => $(id).addEventListener('click', (e) => { Audio.init(); fn(e); });
tap('#jumpBtn', () => { if (G.mode !== 'aim') return; G.jump = !G.jump; Audio.sfx(G.jump ? 'jump' : 'select'); renderHud(); if (aim.on) updateAim(); });
tap('#prevChar', () => { G.charIdx = (G.charIdx + CHARS.length - 1) % CHARS.length; save.char = G.charIdx; persist(); Audio.sfx('select'); renderCharPicker(); });
tap('#nextChar', () => { G.charIdx = (G.charIdx + 1) % CHARS.length; save.char = G.charIdx; persist(); Audio.sfx('select'); renderCharPicker(); });
tap('#startBtn', () => { if (Audio.musicOn) Audio.startMusic(); Audio.sfx('cup'); G.scores = []; transition(() => startIntro(0)); });
tap('#iGo', beginPlay);
tap('#rNext', () => { Audio.sfx('select'); if (G.holeIdx + 1 < window.HOLES.length) transition(() => startIntro(G.holeIdx + 1)); else transition(showFinal); });
tap('#fAgain', () => { G.scores = []; transition(() => startIntro(0)); });
tap('#fTitle', () => transition(goTitle));
tap('#pauseBtn', openPause);
tap('#pResume', () => { showScreen(null); setMode(G.pausedFrom || 'aim'); });
tap('#pRestart', () => { transition(() => startIntro(G.holeIdx)); });
tap('#pQuit', () => transition(goTitle));
tap('#pMusic', () => { Audio.musicOn = !Audio.musicOn; save.music = Audio.musicOn; persist(); if (Audio.musicOn) Audio.startMusic(); renderPause(); });
tap('#pSfx', () => { Audio.sfxOn = !Audio.sfxOn; save.sfx = Audio.sfxOn; persist(); renderPause(); });
function renderPause() { $('#pMusic').textContent = `Música: ${Audio.musicOn ? 'ligada' : 'desligada'}`; $('#pSfx').textContent = `Efeitos: ${Audio.sfxOn ? 'ligados' : 'desligados'}`; }
function openPause() { if (!['aim', 'roll'].includes(G.mode)) return; G.pausedFrom = G.mode === 'roll' ? 'roll' : 'aim'; aim.on = false; renderPause(); setMode('pause'); showScreen('pause'); }
function goTitle() { loadHole(0); setMode('title'); resize(); showScreen('title'); renderCharPicker(); }

// ============================================================ loop
let last = performance.now();
function frame(now) {
  const dt = Math.min((now - last) / 1000, 1 / 20); last = now;
  G.t += dt; G.modeT += dt;
  // simulation
  if (G.mode === 'roll') updateBall(dt);
  for (const e of G.enemies) {
    if (!e.alive) { e.pop -= dt; continue; }
    e.flash -= dt;
    if (e.t === 'cogu' && e.range) {
      const s = Math.sin(G.t * 0.9 + e.id) * e.range;
      if (e.axis === 'x') e.x = e.bx + s; else e.y = e.by + s;
      e.z = groundZ(e.x, e.y);
    }
  }
  // squash spring
  ball.sqv += (-ball.sq * 260 - ball.sqv * 14) * dt; ball.sq += ball.sqv * dt;
  ball.faceT -= dt; ball.blinkT -= dt;
  if (ball.blinkT < 0) { ball.blink = 0.12; ball.blinkT = rand(2, 4.5); }
  ball.blink = (ball.blink || 0) - dt;
  // upright again when resting
  if (G.mode !== 'roll') { const M = ball.M; for (let i = 0; i < 9; i++) M[i] = lerp(M[i], ID3[i], 1 - Math.exp(-dt * 9)); ball.M = ortho(M); }
  // camera
  if (hole) {
    const bp = P(ball.x, ball.y, ball.z);
    // keep the whole course in view when it fits; otherwise follow the ball within the course bounds
    const fit = (lo, hi, view, at) => (hi - lo + 16 <= view ? (lo + hi) / 2 : clamp(at, lo - 8 + view / 2, hi + 8 - view / 2));
    const tx = fit(hole.left, hole.right, VW, bp.x), ty = fit(hole.top, hole.bottom, VH * 0.8, bp.y);
    cam.x = lerp(cam.x, tx, 1 - Math.exp(-dt * 3)); cam.y = lerp(cam.y, ty, 1 - Math.exp(-dt * 3));
  }
  if (cam.shake > 0) { cam.shake = Math.max(0, cam.shake - dt * 18); shakeX = Math.round(rand(-1, 1) * cam.shake); shakeY = Math.round(rand(-1, 1) * cam.shake); } else { shakeX = shakeY = 0; }
  if (REDUCED) { shakeX = shakeY = 0; }
  updateParts(dt);
  if (G.mode === 'roll' && G.modeT % 0.25 < dt) renderHud();

  // draw
  drawSky(G.t);
  if (G.mode === 'title') {
    drawTitle(G.t, dt);
  } else if (hole) {
    drawWorld(G.t);
    if (G.mode === 'aim') drawAim(G.t);
    drawParts(true);
  }
  drawParts(false);
  // iris transition
  if (G.trans) {
    const tr = G.trans; tr.t += dt / 0.45;
    if (!tr.done && tr.t >= 1) { tr.done = true; tr.cb(); }
    const k = tr.t < 1 ? tr.t : 2 - tr.t;
    if (tr.t >= 2) G.trans = null;
    else {
      const R = Math.max(VW, VH) * (1 - clamp(k, 0, 1)) * 0.8, cx = VW / 2, cy = VH / 2;
      g.fillStyle = '#120C34';
      for (let y = 0; y < VH; y += 2) {
        const dy = y - cy, half = R * R - dy * dy;
        if (half <= 0) { g.fillRect(0, y, VW, 2); continue; }
        const w = Math.sqrt(half); g.fillRect(0, y, Math.max(0, Math.round(cx - w)), 2); g.fillRect(Math.round(cx + w), y, VW, 2);
      }
    }
  }
  requestAnimationFrame(frame);
}

// ============================================================ boot
new ResizeObserver(resize).observe(wrap);
resize();
goTitle();
requestAnimationFrame((t) => { last = t; frame(t); });
window.__estelar = { G, ball, get hole() { return hole; }, shoot, startIntro, beginPlay, toast, defeat, showFinal };
})();
