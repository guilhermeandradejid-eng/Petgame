/* Gramado Estelar — isometric sky mini-golf in modern pixel art.
   Two layers:
   - #game: the pixel world, drawn at a low internal resolution and scaled up by an integer factor
   - #ui:   a full-resolution overlay for things that must stay crisp and readable (aim, power, arrows, popups)
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
const easeOutBack = (t) => { const c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };
const hash = (a, b, c = 0) => { let h = (a * 374761393 + b * 668265263 + c * 2147483647) | 0; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967295; };
const RGB = {};
function rgb(hex) { let c = RGB[hex]; if (c) return c; const n = parseInt(hex.slice(1), 16); c = RGB[hex] = [(n >> 16) & 255, (n >> 8) & 255, n & 255]; return c; }
const shade = (c, k) => [clamp(c[0] * k, 0, 255) | 0, clamp(c[1] * k, 0, 255) | 0, clamp(c[2] * k, 0, 255) | 0];
const mixc = (a, b, t) => [lerp(a[0], b[0], t) | 0, lerp(a[1], b[1], t) | 0, lerp(a[2], b[2], t) | 0];
const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const REDUCED = matchMedia('(prefers-reduced-motion: reduce)').matches;
const buzz = (ms) => { try { if (navigator.vibrate) navigator.vibrate(ms); } catch (e) { /* not allowed */ } };

// ============================================================ characters
const CHARS = [
  { id: 'pipo', name: 'Pipo', desc: 'Equilibrado e fofo', body: ['#4A1634', '#B03F72', '#E8689A', '#FFA3C2', '#FFE4EE'], feet: ['#8E1E44', '#D23A66'], acc: 'folha', power: 1, fric: 1, jump: 1, brake: 1, stats: [3, 3, 3] },
  { id: 'brasa', name: 'Brasa', desc: 'Tacadas fortíssimas', body: ['#4E180E', '#BA4422', '#F07A34', '#FFB45C', '#FFE9B4'], feet: ['#6E1C0E', '#A8331A'], acc: 'chama', power: 1.2, fric: 0.9, jump: 0.92, brake: 0.75, stats: [5, 2, 2] },
  { id: 'nimbo', name: 'Nimbo', desc: 'Pula mais alto', body: ['#18225C', '#3F62BC', '#73A4EE', '#B2D7FF', '#EEF8FF'], feet: ['#24357E', '#3E57B8'], acc: 'nuvem', power: 0.93, fric: 1, jump: 1.32, brake: 1, stats: [2, 3, 5] },
  { id: 'musgo', name: 'Musgo', desc: 'Controle preciso', body: ['#103424', '#24784C', '#42B870', '#88E49E', '#DEFCE4'], feet: ['#174A2E', '#24703F'], acc: 'broto', power: 1, fric: 1.12, jump: 0.95, brake: 1.6, stats: [3, 5, 2] },
];
const STONE = ['#211D2A', '#47425A', '#767288', '#AAA6BA', '#E2E0EC'];

// ============================================================ audio (chiptune, synthesized)
const Audio = {
  ac: null, out: null, sfxOn: true, musicOn: true, mus: null, step: 0, next: 0, timer: 0, noiseBuf: null,
  init() {
    if (!this.ac) {
      const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return null;
      try { this.ac = new AC(); } catch (e) { return null; }
      this.out = this.ac.createGain(); this.out.gain.value = 0.5; this.out.connect(this.ac.destination);
      this.mus = this.ac.createGain(); this.mus.gain.value = 0.085; this.mus.connect(this.out);
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
      case 'shoot': this.tone(220 + k * 300, 0.18, 'square', 0.1, 900 + k * 600); this.noise(0.18, 0.12, 1800); break;
      case 'jump': this.tone(300, 0.25, 'square', 0.08, 1200); break;
      case 'bounce': this.tone(170 + k * 70, 0.08, 'triangle', 0.2, 110); this.noise(0.05, 0.06, 600); break;
      case 'wall': this.tone(140, 0.08, 'square', 0.08, 90); this.noise(0.07, 0.12, 900); break;
      case 'bumper': this.tone(520, 0.12, 'square', 0.09, 1040); this.tone(780, 0.12, 'square', 0.06, 1560, 0.05); break;
      case 'defeat': [659, 784, 1047, 1319].forEach((f, i) => this.tone(f * k, 0.09, 'square', 0.08, null, i * 0.045)); this.noise(0.15, 0.14, 1500); break;
      case 'combo': [880, 1109, 1319, 1760].forEach((f, i) => this.tone(f, 0.1, 'triangle', 0.12, null, i * 0.06)); break;
      case 'spike': this.tone(900, 0.15, 'sawtooth', 0.06, 300); break;
      case 'scared': this.tone(1200, 0.07, 'square', 0.03, 1600); break;
      case 'tree': this.noise(0.25, 0.12, 2500); this.tone(160, 0.1, 'triangle', 0.12, 90); break;
      case 'cup': [523, 659, 784, 1047, 784, 1047, 1319].forEach((f, i) => this.tone(f, 0.12, 'triangle', 0.14, null, i * 0.07)); break;
      case 'sink': [784, 988, 1175, 1568].forEach((f, i) => this.tone(f, 0.16, 'square', 0.08, null, i * 0.09)); [392, 494, 587, 784].forEach((f, i) => this.tone(f, 0.2, 'triangle', 0.13, null, i * 0.09)); break;
      case 'firework': this.noise(0.3, 0.1, 1200 + Math.random() * 2000); break;
      case 'splash': this.noise(0.4, 0.2, 1200); this.tone(400, 0.3, 'sine', 0.08, 120); break;
      case 'fall': this.tone(700, 0.6, 'square', 0.06, 80); break;
      case 'ability': this.tone(400, 0.3, 'square', 0.08, 1600); this.tone(600, 0.3, 'triangle', 0.08, 2000, 0.05); break;
      case 'stone': this.noise(0.3, 0.3, 300); this.tone(90, 0.3, 'square', 0.14, 45); break;
      case 'select': this.tone(880, 0.06, 'square', 0.07); this.tone(1320, 0.08, 'square', 0.06, null, 0.05); break;
      case 'tick': this.tone(500 + k * 900, 0.025, 'square', 0.025); break;
      case 'lip': this.tone(600, 0.08, 'triangle', 0.12, 400); break;
      case 'brake': this.noise(0.08, 0.05, 4000); break;
      case 'whoosh': this.noise(0.2, 0.06, 900); break;
    }
  },
  LEAD: [76, 79, 84, 79, 81, 79, 76, 74, 72, 74, 76, 79, 76, 74, 72, 0, 77, 81, 84, 81, 79, 76, 74, 72, 74, 76, 74, 71, 72, 0, 67, 0],
  BASS: [48, 55, 48, 55, 45, 52, 45, 52, 41, 48, 41, 48, 43, 50, 43, 47],
  ARP: [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]],
  startMusic() { if (!this.ac || this.timer) return; this.next = this.ac.currentTime + 0.1; this.step = 0; this.timer = setInterval(() => this.schedule(), 30); },
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

// ============================================================ canvases & resolution
const wrap = $('#wrap');
const cv = $('#game'), g = cv.getContext('2d');
const ui = $('#ui'), u = ui.getContext('2d');
let VW = 300, VH = 520, SCALE = 1, CSS_K = 1, DPR = 1;
function resize() {
  const r = wrap.getBoundingClientRect(); DPR = window.devicePixelRatio || 1;
  const dw = r.width * DPR, dh = r.height * DPR;
  let s;
  if (G.overview && hole) s = Math.floor(Math.min(dw / (hole.right - hole.left + 30), (dh - 200 * DPR) / (hole.bottom - hole.top + 20)));
  else s = Math.round(Math.min(dw / (G.mode === 'title' ? 230 : 320), dh / 470));
  SCALE = Math.max(1, s);
  VW = Math.ceil(dw / SCALE); VH = Math.ceil(dh / SCALE);
  cv.width = VW; cv.height = VH;
  const cw = (VW * SCALE) / DPR, chh = (VH * SCALE) / DPR;
  cv.style.width = `${cw}px`; cv.style.height = `${chh}px`;
  ui.width = VW * SCALE; ui.height = VH * SCALE; ui.style.width = `${cw}px`; ui.style.height = `${chh}px`;
  CSS_K = VW / cw;
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
const RAMPS = {};
function rampOf(pal) {
  const key = pal.join(); let r = RAMPS[key]; if (r) return r;
  const c = pal.map(rgb);
  r = RAMPS[key] = { ol: c[0], soft: mixc(c[0], c[1], 0.55), tones: [c[1], mixc(c[1], c[2], 0.5), c[2], mixc(c[2], c[3], 0.5), c[3], mixc(c[3], c[4], 0.5), c[4]] };
  return r;
}
const C_DARK = rgb('#1B1030'), C_IRIS = rgb('#3B4FD0'), C_IRIS2 = rgb('#7A8CFF'), C_WHITE = [255, 255, 255], C_MOUTH = rgb('#7A1830'), C_TONGUE = rgb('#FF7A96'), C_BLUSH = rgb('#FF6F98'), C_SPOT = rgb('#FFF6EC');
/* o: { r, pal, M, sx, sy, cut, eyes, mouth, blush, spots, eye, look:[x,y], flash } */
function sphereSprite(key, o) {
  const r = o.r, sx = o.sx || 1, sy = o.sy || 1, M = o.M || ID3;
  const W = Math.ceil(r * sx) * 2 + 3, H = Math.ceil(r * sy) * 2 + 3;
  const c = getCanvas(key, W, H), ctx = c.ctx;
  const img = ctx.createImageData(W, H), d = img.data;
  const R = rampOf(o.pal), E = o.eye || EYE_DEF, lk = o.look || [0, 0];
  const ex0 = E.x, ey0 = E.y + lk[1] * 0.07, exo = lk[0] * 0.09;
  const fill = new Uint8Array(W * H);
  for (let py = 0; py < H; py++) {
    for (let px = 0; px < W; px++) {
      const nx = (px + 0.5 - W / 2) / (r * sx), ny = (py + 0.5 - H / 2) / (r * sy);
      const d2 = nx * nx + ny * ny;
      if (d2 > 1) continue;
      if (o.cut != null && ny > o.cut) continue;
      const nz = Math.sqrt(1 - d2);
      const dif = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2];
      const s = dif * 0.5 + 0.5;
      let idx = Math.floor(s * 7 + (BAYER[py & 3][px & 3] / 16 - 0.5) * 0.9);
      if (ny > 0.25 && nx > -0.3 && d2 > 0.72) idx += 1; // bounce light from the ground
      if (ny > 0.8) idx -= 1;                           // contact occlusion
      let col = R.tones[clamp(idx, 0, 6)];
      const b0 = M[0] * nx + M[3] * ny + M[6] * nz, b1 = M[1] * nx + M[4] * ny + M[7] * nz, b2 = M[2] * nx + M[5] * ny + M[8] * nz;
      if (o.spots) for (const sp of o.spots) { const dx = b0 - sp[0], dy = b1 - sp[1], dz = b2 - sp[2]; if (dx * dx + dy * dy + dz * dz < sp[3] * sp[3]) col = s > 0.5 ? C_SPOT : shade(C_SPOT, 0.86); }
      if (b2 > 0.25) {
        for (const side of [-1, 1]) {
          const ex = b0 - side * ex0 - exo, ey = b1 - ey0;
          switch (o.eyes) {
            case 'open': case 'focus': case 'wide': {
              const ry = o.eyes === 'focus' ? E.ry * 0.62 : o.eyes === 'wide' ? E.ry * 1.15 : E.ry, oy = o.eyes === 'focus' ? 0.06 : 0, rx = o.eyes === 'wide' ? E.rx * 1.15 : E.rx;
              const q = (ex / rx) ** 2 + ((ey - oy) / ry) ** 2;
              if (q < 1) {
                const yy = (ey - oy) / ry;
                col = yy > 0.55 ? C_IRIS2 : yy > 0.15 ? C_IRIS : C_DARK;
                if (((ex + rx * 0.22) / (rx * 0.5)) ** 2 + ((ey - oy + ry * 0.45) / (ry * 0.3)) ** 2 < 1) col = C_WHITE;
                else if (((ex - rx * 0.35) / (rx * 0.22)) ** 2 + ((ey - oy - ry * 0.05) / (ry * 0.13)) ** 2 < 1) col = C_WHITE;
              }
              break;
            }
            case 'blink': if (Math.abs(ey - 0.05) < 0.03 && Math.abs(ex) < E.rx * 1.15) col = C_DARK; break;
            case 'happy': { const dd = Math.hypot(ex, ey - 0.08); if (Math.abs(dd - E.rx * 1.05) < 0.035 && ey < 0.06) col = C_DARK; break; }
            case 'sleepy': if (Math.abs(ey - 0.03) < 0.03 && Math.abs(ex) < E.rx * 1.15 && ey > 0) col = C_DARK; else if ((ex / E.rx) ** 2 + ((ey - 0.08) / (E.ry * 0.35)) ** 2 < 1 && ey > 0.03) col = C_DARK; break;
            case 'dizzy': if (Math.hypot(ex, ey) < E.rx * 1.3 && (Math.abs(ex - ey) < 0.035 || Math.abs(ex + ey) < 0.035)) col = C_DARK; break;
            case 'angry': { const q = (ex / E.rx) ** 2 + ((ey - 0.03) / (E.ry * 0.72)) ** 2; if (q < 1 && ey > -side * ex * 0.9 - 0.06) col = C_DARK; break; }
          }
          if (o.blush && b2 > 0.4) { const q = ((b0 - side * 0.54) / 0.14) ** 2 + ((b1 - 0.17) / 0.07) ** 2; if (q < 1 && ((px + py) & 1)) col = C_BLUSH; }
        }
        if (o.mouth === 'o') { const q = (b0 / 0.075) ** 2 + ((b1 - 0.21) / 0.09) ** 2; if (q < 1) col = q < 0.4 && b1 > 0.22 ? C_TONGUE : C_MOUTH; }
        else if (o.mouth === 'smile') { const dd = Math.hypot(b0, b1 - 0.1); if (Math.abs(dd - 0.09) < 0.03 && b1 > 0.13) col = C_MOUTH; }
        else if (o.mouth === 'grin') { if ((b0 / 0.13) ** 2 + ((b1 - 0.13) / 0.12) ** 2 < 1 && b1 > 0.13) col = b1 > 0.2 && Math.abs(b0) < 0.07 ? C_TONGUE : C_MOUTH; }
        else if (o.mouth === 'wavy') { if (Math.abs(b1 - 0.18 - Math.sin(b0 * 40) * 0.02) < 0.022 && Math.abs(b0) < 0.12) col = C_MOUTH; }
      }
      if (dif > 0.84 && (nx + 0.42) ** 2 + (ny + 0.5) ** 2 < 0.028) col = C_WHITE;
      else if (dif > 0.7 && (nx + 0.18) ** 2 + (ny + 0.62) ** 2 < 0.006) col = C_WHITE;
      if (o.flash) col = C_WHITE;
      const i = (py * W + px) * 4;
      d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
      fill[py * W + px] = 1;
    }
  }
  // selective outline: dark on the shadow side, softer on the lit side
  const cx = W / 2, cy = H / 2;
  for (let py = 0; py < H; py++) for (let px = 0; px < W; px++) {
    const k = py * W + px; if (fill[k]) continue;
    if ((px > 0 && fill[k - 1]) || (px < W - 1 && fill[k + 1]) || (py > 0 && fill[k - W]) || (py < H - 1 && fill[k + W])) {
      const col = o.flash ? C_WHITE : (px - cx) * 0.6 + (py - cy) > -r * 0.45 ? R.ol : R.soft;
      const i = k * 4; d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return c;
}

// hand-made pixel sprites
const PX = {
  folha: { p: { g: '#2B7A38', G: '#6CCB5C', L: '#B8F59A', b: '#6A4030' }, f: [['.....gGL', '...gGGLg', '..gGGgg.', '.ggg....', '..b.....', '..b.....'], ['....gGL.', '..gGGLg.', '.gGGgg..', '.ggg....', '..b.....', '..b.....']] },
  chama: { p: { y: '#FFE36E', Y: '#FFF8C8', W: '#FFFFFF', o: '#FF8A2A', r: '#D83A24' }, f: [['...y....', '..yY....', '..yYy.y.', '.oyYYyy.', '.oYWYyo.', 'r.oooo.r'], ['....y...', '...Yy...', '.y.yYy..', '.yyYYyo.', '.oyWYyo.', '.roooor.'], ['...y....', '...yY.y.', '..yYYy..', '.oyYWyo.', '.oYWYyo.', '..oooo..']] },
  nuvem: { p: { w: '#DCEAFF', W: '#FFFFFF', s: '#9DB6E6' }, f: [['..www.....', '.wWWWw.ww.', 'wWWWWWwWWw', 'sWWWWWWWWs', '.ssssssss.'], ['...www....', '.wwWWWwww.', 'wWWWWWWWWw', 'sWWWWWWWWs', '.ssssssss.']] },
  broto: { p: { r: '#D63A4C', R: '#FF8A94', w: '#FFFFFF', s: '#F2E2C4', S: '#C9B48E' }, f: [['..rrrr..', '.rRwRrr.', 'rRwwRrwr', 'rrrrrrrr', '...sS...', '...sS...']] },
  rocha: { p: { k: '#2A2638', g: '#7E7A92', G: '#B8B4CC', W: '#FFFFFF' }, f: [['...kkk...', '..kgGgk..', '.kgGWGgk.', 'kgGGGggk.', 'kgggggggk', '.kgggggk.', '..kkkkk..']] },
  turbo: { p: { k: '#5A2E00', y: '#FFD45C', W: '#FFFFFF' }, f: [['.....kkk', '....kyWk', '...kyyk.', '..kyyyk.', '.kyyyyyk', '..kkyyk.', '...kyk..', '..kyk...', '..kk....']] },
  mola: { p: { k: '#17402A', g: '#6EE7A8', W: '#FFFFFF' }, f: [['...kk...', '..kggk..', '.kgWggk.', 'kkkggkkk', '..kggk..', '..kggk..', '..kkkk..']] },
  wing: { p: { k: '#2A1658', w: '#EDE2FF', p: '#B49AF0' }, f: [['kk......', 'kwk.....', 'kwpk....', '.kwpk...', '..kwpk..', '...kkk..'], ['........', 'kkkk....', 'kwwppk..', '.kwwppk.', '..kkkk..', '........'], ['........', '........', '..kkkk..', '.kwwpk..', 'kwpk....', 'kk......']] },
  sweat: { p: { k: '#3A5AA8', w: '#BFE8FF', W: '#FFFFFF' }, f: [['.k.', 'kWk', 'kwk', '.k.']] },
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
const EXV = [0.707, 0.354, 0.612], EYV = [-0.707, 0.354, 0.612], UPV = [0, -0.866, 0.5];

// ============================================================ course
const TWH = 16, TH = 8, HZ = 12, BOTTOM = -2.2;
const TILE_TYPES = { g: 'grass', s: 'sand', w: 'water', i: 'ice', b: 'grass', t: 'grass' };
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
    const c = { x, y, h, type: TILE_TYPES[ch] || 'grass', slope: SLOPE[ch] || null, dash: DASH[ch] || null, bumper: ch === 'b', tree: ch === 't', pop: 0 };
    if (c.dash) c.type = 'dash';
    maxH = Math.max(maxH, h + (c.slope ? 1 : 0));
    cells.push(c);
  }
  const ho = { def, W, H, cells, maxH };
  ho.cell = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? undefined : cells[y * W + x]);
  for (const c of cells) if (c) c.spr = buildColumn(ho, c);
  ho.bumpers = cells.filter((c) => c && c.bumper).map((c) => ({ x: c.x + 0.5, y: c.y + 0.5, z: c.h, squash: 0 }));
  ho.trees = cells.filter((c) => c && c.tree).map((c, i) => ({ x: c.x + 0.5, y: c.y + 0.5, z: c.h, shake: 0, i, big: hash(c.x, c.y, 5) > 0.5 }));
  const pts = [P(0, 0, maxH + 2), P(W, 0, 0), P(0, H, 0), P(W, H, BOTTOM)];
  ho.left = Math.min(...pts.map((p) => p.x)); ho.right = Math.max(...pts.map((p) => p.x));
  ho.top = Math.min(...pts.map((p) => p.y)) - 20; ho.bottom = Math.max(...pts.map((p) => p.y));
  ho.cx = (ho.left + ho.right) / 2; ho.cy = (ho.top + ho.bottom) / 2;
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
function surf(x, y, ho = hole) {
  const fx = Math.floor(x), fy = Math.floor(y), c = ho.cell(fx, fy);
  if (c === undefined) return Infinity;
  if (c === null) return -Infinity;
  const k = corners(c), uu = x - fx, vv = y - fy;
  return lerp(lerp(k[0], k[1], uu), lerp(k[3], k[2], uu), vv);
}
function gradOf(c) {
  switch (c && c.slope) { case '+x': return [1, 0]; case '-x': return [-1, 0]; case '+y': return [0, 1]; case '-y': return [0, -1]; default: return [0, 0]; }
}

// ---------- tile column sprites (pre-rendered per hole)
const PAL = {
  grassA: rgb('#5ACB64'), grassB: rgb('#48B958'), grassHi: rgb('#A6F48E'), grassBlade: rgb('#7EE070'), grassDark: rgb('#2E8C46'), grassLip: rgb('#2A8443'), grassLipHi: rgb('#62C85E'),
  sand: rgb('#F4D58C'), sandB: rgb('#E6C072'), sandHi: rgb('#FFF2C6'), sandLip: rgb('#C49A4E'), sandLipHi: rgb('#E8C27A'),
  ice: rgb('#C4F0FF'), iceB: rgb('#A2E0F8'), iceHi: rgb('#FFFFFF'), iceLip: rgb('#78C2E4'), iceLipHi: rgb('#B4E6FA'),
  water: rgb('#3E96E6'), waterB: rgb('#3888DA'), waterHi: rgb('#A8E2FF'), waterLip: rgb('#2A64B6'), waterLipHi: rgb('#4A8ADA'),
  dash: rgb('#FF9A4A'), dashB: rgb('#F4823A'), dashHi: rgb('#FFE08A'), dashLip: rgb('#B85A22'), dashLipHi: rgb('#E07A36'),
  stone: [rgb('#BC8E92'), rgb('#AC7E88'), rgb('#9C707E')], stoneHi: rgb('#DDB4B4'), stoneShade: rgb('#84566C'), mortar: rgb('#5A3250'), pebble: rgb('#E8C2BE'),
  vine: [rgb('#2F9A48'), rgb('#3FB656'), rgb('#257A3C')],
  rail: rgb('#FFF4E0'), railShade: rgb('#D8C4B4'), post: rgb('#EAD6C2'), postDark: rgb('#8E6A80'),
  flower: [rgb('#FFFFFF'), rgb('#FF9EC4'), rgb('#FFE36E'), rgb('#C9A8FF')],
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
  const k = corners(c), top = Math.max(...k), K = Math.ceil(top * HZ) + 12;
  const Pl = (uu, vv, z) => [(uu - vv) * TWH + TWH, (uu + vv) * TH - z * HZ + K];
  const Wd = TWH * 2, Hd = Math.ceil(TH * 2 - BOTTOM * HZ + K) + 2;
  const cnv = document.createElement('canvas'); cnv.width = Wd; cnv.height = Hd;
  const ctx = cnv.getContext('2d'), img = ctx.createImageData(Wd, Hd), d = img.data;
  const put = (x, y, col) => { if (x < 0 || y < 0 || x >= Wd || y >= Hd) return; const i = (y * Wd + x) * 4; d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255; };
  const T = c.type, skin = T === 'sand' ? 'sand' : T === 'ice' ? 'ice' : T === 'water' ? 'water' : T === 'dash' ? 'dash' : 'grass';
  const lip = PAL[skin + 'Lip'], lipHi = PAL[skin + 'LipHi'];
  const zc = (uu, vv) => lerp(lerp(k[0], k[1], uu), lerp(k[3], k[2], uu), vv);
  // ---- side faces: grass lip, stone blocks, vines, fading into the sky
  const sideFace = (pts, A, B, isLeft) => {
    for (let y = 0; y < Hd; y++) for (let x = 0; x < Wd; x++) {
      if (!inPoly(pts, x + 0.5, y + 0.5)) continue;
      const t = clamp((x + 0.5 - A[0]) / (B[0] - A[0]), 0, 1), yt = lerp(A[1], B[1], t), zt = lerp(A[2], B[2], t);
      const depth = y + 0.5 - yt, z = zt - depth / HZ;
      if (z < BOTTOM + 1.3) { const th = (z - BOTTOM) / 1.3; if (BAYER[y & 3][x & 3] / 16 > th) continue; }
      const colId = x + (isLeft ? 0 : 40) + c.x * 31 + c.y * 17;
      const lipD = 3 + Math.floor(hash(colId, 3) * 3);
      let col;
      if (depth < lipD) col = depth < 1 ? lipHi : lip;
      else {
        const vineLen = hash(colId, 9) < 0.16 && skin === 'grass' ? 3 + Math.floor(hash(colId, 10) * 12) : 0;
        if (depth < lipD + vineLen) col = PAL.vine[(Math.floor(depth) + (x & 1)) % 3];
        else {
          const rowF = (10 - z) * 2.4, row = Math.floor(rowF), fy = rowF - row;
          const colF = (x + (row & 1) * 4 + c.x * 7 + c.y * 3 + (isLeft ? 0 : 3)) / 7, cl = Math.floor(colF), fx = colF - cl;
          const hs = hash(cl, row, c.x * 3 + c.y);
          col = PAL.stone[Math.floor(hs * 3)];
          if (fy < 0.16 || fx < 0.12) col = PAL.mortar;
          else if (fy < 0.34) col = PAL.stoneHi;
          else if (fy > 0.84 || fx > 0.9) col = PAL.stoneShade;
          else if (hash(x * 7 + c.x, y * 13 + c.y, 2) < 0.04) col = PAL.pebble;
          if (depth < lipD + 3) col = shade(col, 0.78);
          if (!isLeft) col = shade(col, 0.8);
        }
      }
      put(x, y, col);
    }
  };
  const L0 = Pl(0, 1, k[3]), L1 = Pl(1, 1, k[2]), R0 = Pl(1, 0, k[1]);
  sideFace([L0, L1, Pl(1, 1, BOTTOM), Pl(0, 1, BOTTOM)], [L0[0], L0[1], k[3]], [L1[0], L1[1], k[2]], true);
  sideFace([R0, L1, Pl(1, 1, BOTTOM), Pl(1, 0, BOTTOM)], [R0[0], R0[1], k[1]], [L1[0], L1[1], k[2]], false);
  // ---- neighbour heights for ambient occlusion on the top face
  const nbH = (dx, dy) => { const n = ho.cell(c.x + dx, c.y + dy); if (!n) return -99; return Math.max(...corners(n)); };
  const myH = top, aoW = 0.4;
  const ao = { mx: nbH(-1, 0) > myH + 0.3, px: nbH(1, 0) > myH + 0.3, my: nbH(0, -1) > myH + 0.3, py: nbH(0, 1) > myH + 0.3 };
  // ---- top surface, textured in tile space (uu, vv)
  const topP = [Pl(0, 0, k[0]), Pl(1, 0, k[1]), Pl(1, 1, k[2]), Pl(0, 1, k[3])];
  const gr = gradOf(c), light = { '+x': 1.12, '+y': 0.95, '-x': 0.82, '-y': 1.05 }[c.slope] || 1;
  const checker = (c.x + c.y) & 1, isTop = new Uint8Array(Wd * Hd);
  const z0 = k[0], a = 8 - 12 * gr[0], b = 8 - 12 * gr[1];
  for (let y = 0; y < Hd; y++) for (let x = 0; x < Wd; x++) {
    if (!inPoly(topP, x + 0.5, y + 0.5)) continue;
    const X = (x + 0.5 - TWH) / TWH, Y = y + 0.5 - K + z0 * HZ;
    const vv = (Y - a * X) / (a + b), uu = vv + X;
    let col;
    const n = hash(x + c.x * 32, y + c.y * 16, 7);
    if (skin === 'grass') {
      col = checker ? PAL.grassA : PAL.grassB;
      if (Math.floor(uu * 4) & 1) col = shade(col, 1.035);
      if (n < 0.045) col = PAL.grassBlade; else if (hash(x + c.x * 32, y - 1 + c.y * 16, 7) < 0.045) col = PAL.grassDark; else if (n > 0.985) col = PAL.grassHi;
    } else if (skin === 'sand') {
      const rip = (uu * 3.2 + vv * 1.6 + hash(c.x, c.y) * 3) % 1;
      col = rip < 0.18 ? PAL.sandB : PAL.sand;
      if (n < 0.05) col = PAL.sandHi; else if (n > 0.96) col = PAL.sandB;
    } else if (skin === 'ice') {
      const s = ((uu + vv) * 1.4 + c.x * 0.37 + c.y * 0.21) % 1;
      col = s < 0.5 ? PAL.ice : PAL.iceB;
      if (Math.abs(s - 0.78) < 0.03) col = PAL.iceHi;
      if (n > 0.992) col = PAL.iceHi;
    } else if (skin === 'water') {
      col = mixc(checker ? PAL.water : PAL.waterB, rgb('#2A6CC8'), clamp(vv * 0.4, 0, 0.4));
    } else {
      col = checker ? PAL.dash : PAL.dashB;
      if (uu < 0.08 || uu > 0.92 || vv < 0.08 || vv > 0.92) col = PAL.dashLipHi;
    }
    let f = light;
    if (ao.mx) f *= 1 - 0.32 * clamp(1 - uu / aoW, 0, 1);
    if (ao.my) f *= 1 - 0.32 * clamp(1 - vv / aoW, 0, 1);
    if (ao.px) f *= 1 - 0.22 * clamp(1 - (1 - uu) / aoW, 0, 1);
    if (ao.py) f *= 1 - 0.22 * clamp(1 - (1 - vv) / aoW, 0, 1);
    put(x, y, shade(col, f)); isTop[y * Wd + x] = 1;
  }
  // rim light on the back edges
  for (let y = 1; y < Hd - 1; y++) for (let x = 0; x < Wd; x++) {
    if (!isTop[y * Wd + x]) continue;
    if (!isTop[(y - 1) * Wd + x]) put(x, y, PAL[skin + 'Hi'] || PAL.grassHi);
  }
  // flowers and tufts on flat grass
  if (skin === 'grass' && !c.slope && !c.tree && !c.bumper) {
    const n = Math.floor(hash(c.x, c.y, 11) * 3.2);
    for (let i = 0; i < n; i++) {
      const fu = 0.2 + hash(c.x, c.y, 20 + i) * 0.6, fv = 0.2 + hash(c.x, c.y, 30 + i) * 0.6, p = Pl(fu, fv, zc(fu, fv));
      const px = Math.round(p[0]), py = Math.round(p[1]), col = PAL.flower[Math.floor(hash(c.x, c.y, 40 + i) * 4)];
      put(px, py + 1, PAL.grassDark); put(px, py, PAL.flower[2]);
      put(px - 1, py, col); put(px + 1, py, col); put(px, py - 1, col);
    }
    for (let i = 0; i < 3; i++) {
      const fu = 0.15 + hash(c.x, c.y, 50 + i) * 0.7, fv = 0.15 + hash(c.x, c.y, 60 + i) * 0.7, p = Pl(fu, fv, zc(fu, fv));
      const px = Math.round(p[0]), py = Math.round(p[1]);
      put(px - 1, py - 1, PAL.grassBlade); put(px, py, PAL.grassDark); put(px + 1, py - 1, PAL.grassBlade); put(px + 1, py - 2, PAL.grassHi);
    }
  }
  // fences on the outer border
  const edges = [];
  if (c.x === 0) edges.push([[0, 0], [0, 1]]);
  if (c.y === 0) edges.push([[0, 0], [1, 0]]);
  if (c.x === ho.W - 1) edges.push([[1, 0], [1, 1]]);
  if (c.y === ho.H - 1) edges.push([[0, 1], [1, 1]]);
  for (const [ea, eb] of edges) {
    const pa = Pl(ea[0], ea[1], zc(ea[0], ea[1])), pb = Pl(eb[0], eb[1], zc(eb[0], eb[1]));
    const n = Math.max(1, Math.round(Math.abs(pb[0] - pa[0])));
    for (let i = 0; i <= n; i++) {
      const t = i / n, x = Math.round(lerp(pa[0], pb[0], t)), y = Math.round(lerp(pa[1], pb[1], t));
      put(x, y - 5, PAL.rail); put(x, y - 4, PAL.railShade);
      if ((x + c.x * 32 + c.y * 32) % 8 === 0) for (let yy = y - 6; yy <= y; yy++) put(x, yy, yy === y ? PAL.postDark : yy === y - 6 ? PAL.rail : PAL.post);
    }
  }
  ctx.putImageData(img, 0, 0);
  return { cnv, K };
}

// ============================================================ projection & camera
const cam = { x: 0, y: 0, shake: 0, panX: 0, panY: 0 };
const P = (x, y, z) => ({ x: (x - y) * TWH, y: (x + y) * TH - z * HZ });
let shakeX = 0, shakeY = 0;
const camX = () => Math.round(cam.x - VW / 2) - shakeX, camY = () => Math.round(cam.y - VH * 0.5) - shakeY;
const toScreen = (x, y, z) => { const p = P(x, y, z); return { x: Math.round(p.x - camX()), y: Math.round(p.y - camY()) }; };
const toWorldPx = (x, y, z) => P(x, y, z);
const w2o = (px, py) => [(px - camX()) * SCALE, (py - camY()) * SCALE]; // world px → overlay device px

// ============================================================ particles & popups
const parts = [];
function addPart(p) { parts.push(Object.assign({ vx: 0, vy: 0, g: 0, life: 0.6, age: 0, col: '#FFFFFF', type: 'px', size: 1 }, p)); if (parts.length > 600) parts.shift(); }
function burstStars(x, y, n = 10, cols = ['#FFE36E', '#FFFFFF', '#FF9EC0'], sp = 1) {
  for (let i = 0; i < n; i++) { const a = (i / n) * TAU + rand(-0.2, 0.2), s = rand(60, 140) * sp; addPart({ type: 'star', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s * 0.7 - 30, g: 120, life: rand(0.5, 0.85), col: pick(cols) }); }
  addPart({ type: 'ring', x, y, life: 0.4, size: 22 * sp, col: '#FFFFFF' });
}
function dust(x, y, n = 6, col = '#FFF4E0', sp = 1) { for (let i = 0; i < n; i++) addPart({ type: 'puff', x: x + rand(-5, 5), y, vx: rand(-50, 50) * sp, vy: rand(-35, -5), g: 50, life: rand(0.3, 0.6), col, size: rand(1.5, 3.2) }); }
function confetti(n = 60) { for (let i = 0; i < n; i++) addPart({ type: 'conf', screen: true, x: rand(0, VW), y: rand(-60, -5), vx: rand(-20, 20), vy: rand(30, 80), g: 40, life: rand(2, 3.5), col: pick(['#FFD45C', '#FF7FA8', '#6EE7A8', '#7FB2F2', '#FFFFFF', '#B89CF0']), ph: rand(0, TAU) }); }
function firework(x, y) {
  const cols = pick([['#FFE36E', '#FFFFFF'], ['#FF7FA8', '#FFD6E6'], ['#6EE7A8', '#E0FFF0'], ['#7FB2F2', '#FFFFFF']]);
  for (let i = 0; i < 26; i++) { const a = (i / 26) * TAU, s = rand(70, 110); addPart({ type: 'spark', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, g: 60, life: rand(0.7, 1.1), col: pick(cols), drag: 1.6 }); }
  Audio.sfx('firework');
}
function updateParts(dt) {
  for (let i = parts.length - 1; i >= 0; i--) {
    const p = parts[i]; p.age += dt; if (p.age >= p.life) { parts.splice(i, 1); continue; }
    if (p.drag) { const k = Math.exp(-p.drag * dt); p.vx *= k; p.vy *= k; }
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
      case 'px': if (k < 0.75 || ((x + y) & 1)) g.fillRect(x, y, p.size, p.size); break;
      case 'puff': { const s = Math.max(1, Math.round(p.size * (1 - k * 0.6))); if (k < 0.7 || ((x + y) & 1)) g.fillRect(x - (s >> 1), y - (s >> 1), s, s); break; }
      case 'star':
        g.globalCompositeOperation = 'lighter';
        g.fillRect(x, y, 1, 1);
        if (k < 0.7) { g.fillRect(x - 1, y, 3, 1); g.fillRect(x, y - 1, 1, 3); }
        if (k < 0.35) { g.fillRect(x - 2, y, 5, 1); g.fillRect(x, y - 2, 1, 5); }
        g.globalCompositeOperation = 'source-over'; break;
      case 'spark': g.globalCompositeOperation = 'lighter'; g.fillRect(x, y, 1, 1); if (k < 0.5) { g.fillRect(x + 1, y, 1, 1); g.fillRect(x, y + 1, 1, 1); } g.globalCompositeOperation = 'source-over'; break;
      case 'ring': pixelCircle(x, y, Math.round(p.size * (0.3 + k)), p.col, k < 0.5 ? 1 : 2); break;
      case 'conf': g.fillRect(x + Math.round(Math.sin(p.age * 6 + p.ph) * 3), y, Math.sin(p.age * 9 + p.ph) > 0 ? 3 : 1, 2); break;
      case 'drop': g.fillRect(x, y, 1, 2); break;
      case 'leaf': g.fillRect(x + Math.round(Math.sin(p.age * 8 + p.ph) * 2), y, 2, 1); break;
      case 'beam': {
        const a = 1 - k, w = Math.round(10 * a + 2);
        g.globalCompositeOperation = 'lighter';
        g.fillStyle = `rgba(255,236,150,${0.25 * a})`;
        for (let yy = y - 120; yy < y; yy++) { if (((yy + x) & 1) && a < 0.7) continue; g.fillRect(x - w, yy, w * 2, 1); }
        g.globalCompositeOperation = 'source-over'; break;
      }
    }
  }
}
function pixelCircle(cx, cy, r, col, skip = 1) {
  g.fillStyle = col;
  let x = r, y = 0, err = 1 - r, i = 0;
  while (x >= y) {
    if (i++ % skip === 0) for (const [a, b] of [[x, y], [y, x], [-y, x], [-x, y], [-x, -y], [-y, -x], [y, -x], [x, -y]]) g.fillRect(cx + a, cy + Math.round(b * 0.55), 1, 1);
    y++; if (err < 0) err += 2 * y + 1; else { x--; err += 2 * (y - x) + 1; }
  }
}
const pops = [];
function popup(x, y, text, color = '#FFE36E', size = 22, life = 1.1) { pops.push({ x, y, text, color, size, life, t: 0 }); }

// ============================================================ game state
const SAVE = 'gramado-estelar-v1';
let save = { best: null, char: 0, music: true, sfx: true, tutorial: false };
try { Object.assign(save, JSON.parse(localStorage.getItem(SAVE) || '{}')); } catch (e) { /* storage blocked */ }
const persist = () => { try { localStorage.setItem(SAVE, JSON.stringify(save)); } catch (e) { /* storage blocked */ } };
Audio.musicOn = save.music; Audio.sfxOn = save.sfx;

const G = {
  mode: 'title', holeIdx: 0, strokes: 0, scores: [], charIdx: save.char || 0, jump: false, ability: null,
  enemies: [], cup: null, t: 0, modeT: 0, lastRest: null, stone: 0, trans: null, overview: false,
  freeze: 0, slowT: 0, flash: 0, combo: 0, focus: null, idleT: 0,
};
const RB = 0.28, BALL_R = 12;
const ball = { x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, onGround: true, M: ID3.slice(), sq: 0, sqv: 0, brake: false, blinkT: 2, blink: 0, face: 'open', faceT: 0, trail: [], turbo: 0 };
const ch = () => CHARS[G.charIdx];

function loadHole(def) {
  G.strokes = 0; G.ability = null; G.cup = null; G.jump = false; G.stone = 0; G.combo = 0; G.focus = null; G.overview = false;
  hole = parseHole(def);
  const [sx0, sy0] = def.start;
  Object.assign(ball, { x: sx0, y: sy0, vx: 0, vy: 0, vz: 0, onGround: true, M: ID3.slice(), sq: 0, sqv: 0, hidden: false, trail: [], turbo: 0 });
  ball.z = surf(ball.x, ball.y);
  G.lastRest = { x: ball.x, y: ball.y };
  G.enemies = def.enemies.map((e, k) => ({ ...e, bx: e.x, by: e.y, z: 0, alive: true, id: k, flash: 0, die: null, scared: 0 }));
  for (const e of G.enemies) e.z = groundZ(e.x, e.y);
  parts.length = 0; pops.length = 0;
  cam.panX = cam.panY = 0;
  treeSprites = {};
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
      b.vx = lerp(b.vx, c.dash[0] * 10, 0.2); b.vy = lerp(b.vy, c.dash[1] * 10, 0.2);
      if (real && Math.random() < 0.3) { const s = toWorldPx(b.x, b.y, b.z); addPart({ type: 'star', x: s.x + rand(-5, 5), y: s.y, vy: -30, life: 0.35, col: '#FFE08A' }); }
    }
    const sp = Math.hypot(b.vx, b.vy);
    if (sp > 0) {
      const dec = (FRICTION[c ? c.type : 'grass'] || 4.4) * ch().fric * (real && b.brake ? 3.2 * ch().brake : 1);
      const ns = Math.max(0, sp - dec * h); b.vx *= ns / sp; b.vy *= ns / sp;
    }
  } else b.vz -= GRAV * h;
  const events = [];
  let nx = b.x + b.vx * h;
  if (blocked(b.x, b.y, nx + Math.sign(b.vx) * RB, b.y, b.z)) { events.push(['wall', Math.abs(b.vx)]); b.vx = -b.vx * 0.62; nx = b.x; }
  b.x = nx;
  let ny = b.y + b.vy * h;
  if (blocked(b.x, b.y, b.x, ny + Math.sign(b.vy) * RB, b.z)) { events.push(['wall', Math.abs(b.vy)]); b.vy = -b.vy * 0.62; ny = b.y; }
  b.y = ny;
  b.z += b.vz * h;
  const g2 = surf(b.x, b.y);
  if (b.z < g2) {
    if (b.vz < -5) { events.push(['land', -b.vz]); b.vz = -b.vz * 0.36; b.vx *= 0.9; b.vy *= 0.9; }
    else { if (b.vz < -1.5) events.push(['land', -b.vz]); b.vz = 0; }
    b.z = g2;
  } else if (wasGround && b.vz === 0 && b.z - g2 < 0.14) b.z = g2;
  if (real) collideObjects(b, events); else collideStatic(b);
  return events;
}
function blocked(fx, fy, x, y, z) {
  if (Math.floor(fx) === Math.floor(x) && Math.floor(fy) === Math.floor(y)) return false;
  return surf(x, y) > Math.max(z, surf(fx, fy)) + 0.32;
}
function bounceOff(b, ox, oy, rad, minSp, k) {
  const dx = b.x - ox, dy = b.y - oy, d = Math.hypot(dx, dy);
  if (d >= RB + rad || d < 0.001) return false;
  const nx = dx / d, ny = dy / d; b.x = ox + nx * (RB + rad + 0.01); b.y = oy + ny * (RB + rad + 0.01);
  const sp = Math.max(Math.hypot(b.vx, b.vy) * k, minSp); b.vx = nx * sp; b.vy = ny * sp;
  return true;
}
function collideStatic(b) {
  for (const bm of hole.bumpers) if (b.z < bm.z + 0.8) bounceOff(b, bm.x, bm.y, 0.3, 7, 1.05);
  for (const tr of hole.trees) if (b.z < tr.z + 1.6) bounceOff(b, tr.x, tr.y, 0.26, 1.5, 0.7);
}
function collideObjects(b, events) {
  for (const bm of hole.bumpers) if (b.z < bm.z + 0.8 && bounceOff(b, bm.x, bm.y, 0.3, 7, 1.05)) events.push(['bumper', bm]);
  for (const tr of hole.trees) if (b.z < tr.z + 1.6 && bounceOff(b, tr.x, tr.y, 0.26, 1.5, 0.7)) events.push(['tree', tr]);
  for (const e of G.enemies) {
    if (!e.alive) continue;
    const ez = e.z + (e.t === 'piu' ? e.fly || 1.3 : 0.2);
    if (Math.abs(b.z + 0.2 - ez) >= 0.65) continue;
    if (e.t === 'ourico') { if (bounceOff(b, e.x, e.y, 0.3, 3, 0.8)) events.push(['spike', e]); }
    else if (Math.hypot(b.x - e.x, b.y - e.y) < RB + 0.3) events.push(['defeat', e]);
  }
}

function predict(vx, vy, vz) {
  const b = { x: ball.x, y: ball.y, z: ball.z, vx, vy, vz }, pts = [];
  let land = null;
  const wasAir = vz > 0;
  for (let i = 0; i < 200; i++) {
    stepBall(b, 1 / 60, false);
    pts.push(P(b.x, b.y, b.z));
    const gz = surf(b.x, b.y);
    if (wasAir && !land && b.z <= gz + 0.01 && i > 2) land = P(b.x, b.y, gz);
    if (b.z < -3) break;
    if (Math.hypot(b.vx, b.vy) < 0.15 && b.vz === 0) break;
  }
  return { pts, land };
}
function shotVel(dirx, diry, power) {
  const c = ch();
  let sp = (2 + power * 10.5) * c.power, vz = 0;
  if (G.jump) { vz = (5 + power * 7) * c.jump; sp *= 0.85; }
  return [dirx * sp, diry * sp, vz];
}
function shoot(dirx, diry, power) {
  const [vx, vy, vz] = shotVel(dirx, diry, power);
  if (vz) Audio.sfx('jump');
  ball.vx = vx; ball.vy = vy; ball.vz = vz; ball.onGround = vz === 0;
  if (vz) ball.z += 0.01;
  ball.sq = -0.32; ball.sqv = 0;
  G.strokes += 1; G.jump = false; G.stone = 0; G.combo = 0; G.idleT = 0;
  cam.panX = cam.panY = 0;
  if (G.overview) toggleOverview(false);
  Audio.sfx('shoot', power); buzz(12);
  const s = toWorldPx(ball.x, ball.y, ball.z); dust(s.x, s.y + 8, 12, '#FFF4E0', 1.4);
  addPart({ type: 'ring', x: s.x, y: s.y + 6, life: 0.35, size: 18, col: '#FFFFFF' });
  if (power > 0.85) { shake(3); popup(s.x, s.y - 30, 'Com tudo!', '#FF7FA8', 18, 0.8); }
  bumpStroke();
  setMode('roll');
}

function useAbility() {
  const ab = G.ability; if (!ab) return false;
  G.ability = null; renderHud();
  const s = toWorldPx(ball.x, ball.y, ball.z);
  if (ab === 'rocha') {
    G.stone = 1; ball.vx = 0; ball.vy = 0; if (!ball.onGround) ball.vz = -16; Audio.sfx('stone');
    burstStars(s.x, s.y, 8, ['#C8C4D8', '#FFFFFF']); shake(4); popup(s.x, s.y - 30, 'ROCHA!', '#C8C4D8', 22);
  } else if (ab === 'turbo') {
    const sp = Math.hypot(ball.vx, ball.vy) || 1, dx = ball.vx / sp, dy = ball.vy / sp;
    ball.vx = dx * 13; ball.vy = dy * 13; ball.turbo = 0.7; Audio.sfx('ability'); burstStars(s.x, s.y, 10, ['#FFD45C', '#FFFFFF']); shake(2); popup(s.x, s.y - 30, 'TURBO!', '#FFD45C', 22);
  } else if (ab === 'mola') {
    ball.vz = 10 * ch().jump; ball.z += 0.02; ball.onGround = false; Audio.sfx('jump'); burstStars(s.x, s.y + 6, 8, ['#6EE7A8', '#FFFFFF']); popup(s.x, s.y - 30, 'BOING!', '#6EE7A8', 22);
  }
  buzz(20);
  return true;
}
function shake(n) { if (!REDUCED) cam.shake = Math.max(cam.shake, n); }

function defeat(e) {
  e.alive = false;
  const s = toWorldPx(e.x, e.y, e.z + 0.5);
  const dirx = Math.sign(ball.vx - ball.vy) || pick([-1, 1]);
  e.die = { t: 0, vx: dirx * rand(60, 100), vy: -rand(150, 190) };
  G.combo += 1;
  burstStars(s.x, s.y, 14); shake(3); buzz(25);
  Audio.sfx('defeat', 1 + (G.combo - 1) * 0.12);
  G.freeze = 0.07; G.flash = 0.25;
  ball.face = 'happy'; ball.faceT = 0.9;
  popup(s.x, s.y - 26, pick(['POW!', 'PLIM!', 'TOING!', 'PAF!']), '#FFFFFF', 20, 0.8);
  if (G.combo > 1) { const n = G.combo; setTimeout(() => { popup(s.x, s.y - 50, `COMBO x${n}!`, '#FFE36E', 26, 1.3); Audio.sfx('combo'); }, 120); }
  if (e.ab) { G.ability = e.ab; setTimeout(() => { popup(s.x, s.y - 70, `Habilidade: ${ABIL_NAME[e.ab]}!`, '#6EE7A8', 18, 1.6); Audio.sfx('ability'); }, 250); }
  if (foesLeft() === 0) {
    let cx = e.x, cy = e.y;
    const cc = hole.cell(Math.floor(cx), Math.floor(cy));
    if (!cc || cc.type === 'water' || cc.tree || cc.bumper) { const n = nearestSolid(cx, cy); cx = n[0]; cy = n[1]; }
    G.cup = { x: cx, y: cy, z: groundZ(cx, cy), t: 0, armed: false };
    G.freeze = 0.16; G.slowT = 0.6; G.flash = 0.6;
    G.focus = { x: cx, y: cy, z: G.cup.z, t: 1.4 };
    const cp = P(cx, cy, G.cup.z);
    setTimeout(() => { Audio.sfx('cup'); popup(cp.x, cp.y - 46, 'O buraco apareceu!', '#FFE36E', 20, 1.6); }, 300);
    addPart({ type: 'beam', x: cp.x, y: cp.y, life: 1.3 });
    for (let i = 0; i < 24; i++) addPart({ type: 'star', x: cp.x + rand(-7, 7), y: cp.y - rand(0, 60), vy: rand(-60, -15), life: rand(0.7, 1.4), col: pick(['#FFE36E', '#FFFFFF']) });
  }
  renderHud();
}
const ABIL_NAME = { rocha: 'Rocha', turbo: 'Turbo', mola: 'Mola' };
function nearestSolid(x, y) {
  let best = [hole.def.start[0], hole.def.start[1]], bd = 1e9;
  for (const c of hole.cells) if (c && c.type !== 'water' && !c.slope && !c.tree && !c.bumper) { const d = Math.hypot(c.x + 0.5 - x, c.y + 0.5 - y); if (d < bd) { bd = d; best = [c.x + 0.5, c.y + 0.5]; } }
  return best;
}
function popTile(x, y, k) {
  for (const [dx, dy, f] of [[0, 0, 1], [1, 0, 0.5], [-1, 0, 0.5], [0, 1, 0.5], [0, -1, 0.5]]) { const c = hole.cell(Math.floor(x) + dx, Math.floor(y) + dy); if (c) c.pop = Math.max(c.pop, k * f); }
}

function updateBall(dt) {
  const n = Math.max(1, Math.ceil(dt * 120)), h = dt / n;
  for (let i = 0; i < n; i++) {
    const ev = stepBall(ball, h, true);
    for (const e of ev) {
      const s = toWorldPx(ball.x, ball.y, ball.z);
      switch (e[0]) {
        case 'wall':
          if (e[1] > 1) { Audio.sfx('wall'); ball.sq = 0.28; shake(Math.min(3, e[1] * 0.3)); dust(s.x, s.y, 5, '#FFFFFF'); for (let k = 0; k < 4; k++) addPart({ type: 'star', x: s.x, y: s.y, vx: rand(-60, 60), vy: rand(-60, 0), g: 100, life: 0.3, col: '#FFE36E' }); buzz(8); }
          break;
        case 'land': {
          const v = e[1]; ball.sq = clamp(v * 0.05, 0.12, 0.5);
          if (v > 3) { Audio.sfx('bounce', Math.min(v / 10, 1)); dust(s.x, s.y + 8, 8, '#FFF4E0', 1.2); addPart({ type: 'ring', x: s.x, y: s.y + 8, life: 0.35, size: 16, col: '#FFFFFF' }); popTile(ball.x, ball.y, clamp(v / 10, 0.4, 1)); }
          if (G.stone) { shake(6); dust(s.x, s.y + 8, 20, '#D8D4E4', 2); popTile(ball.x, ball.y, 1); buzz(40); }
          break;
        }
        case 'bumper': { e[1].squash = 1; Audio.sfx('bumper'); shake(2); const p = toWorldPx(e[1].x, e[1].y, e[1].z + 0.6); burstStars(p.x, p.y, 6, ['#FF7FA8', '#FFFFFF']); buzz(10); break; }
        case 'tree': {
          const tr = e[1];
          if (tr.shake < 0.3) { tr.shake = 1; Audio.sfx('tree'); const p = toWorldPx(tr.x, tr.y, tr.z + 2); for (let k = 0; k < 10; k++) addPart({ type: 'leaf', x: p.x + rand(-12, 12), y: p.y + rand(-10, 6), vx: rand(-25, 25), vy: rand(-30, 10), g: 40, life: rand(1, 1.8), col: pick(['#5CC46A', '#2F9A4E', '#A6EE96']), ph: rand(0, TAU) }); }
          break;
        }
        case 'spike': { const en = e[1]; if (en.flash <= 0) { Audio.sfx('spike'); shake(3); ball.face = 'dizzy'; ball.faceT = 1; en.flash = 0.4; popup(s.x, s.y - 26, 'Ai!', '#FF7FA8', 18, 0.7); buzz(30); } break; }
        case 'defeat': if (e[1].alive) defeat(e[1]); break;
      }
    }
    if (G.mode !== 'roll') return;
    if (ball.z < BOTTOM - 1.5) { outOfBounds('fall'); return; }
    const c = hole.cell(Math.floor(ball.x), Math.floor(ball.y));
    if (c && c.type === 'water' && ball.z <= surf(ball.x, ball.y) + 0.05) { outOfBounds('water'); return; }
    if (G.freeze > 0) break;
  }
  if (G.stone) { ball.vx = 0; ball.vy = 0; }
  const sp = Math.hypot(ball.vx, ball.vy);
  if (sp > 0.01 && !G.stone) {
    const V = [ball.vx * EXV[0] + ball.vy * EYV[0], ball.vx * EXV[1] + ball.vy * EYV[1], ball.vx * EXV[2] + ball.vy * EYV[2]];
    const w = [UPV[1] * V[2] - UPV[2] * V[1], UPV[2] * V[0] - UPV[0] * V[2], UPV[0] * V[1] - UPV[1] * V[0]];
    const wl = Math.hypot(...w);
    if (wl > 1e-6) ball.M = rotM(ball.M, w[0] / wl, w[1] / wl, w[2] / wl, (sp / RB) * dt * 0.9);
  }
  const s = toWorldPx(ball.x, ball.y, ball.z);
  if (ball.turbo > 0) { ball.turbo -= dt; addPart({ type: 'star', x: s.x + rand(-5, 5), y: s.y + rand(-5, 5), life: 0.35, col: '#FFB45C' }); }
  if (sp > 4) { ball.trail.push({ x: s.x, y: s.y, t: G.t }); if (ball.trail.length > 8) ball.trail.shift(); }
  if (sp > 3 && ball.onGround && Math.random() < sp / 25) addPart({ type: 'puff', x: s.x + rand(-4, 4), y: s.y + 8, vx: -ball.vx * 3, vy: rand(-12, -4), life: 0.35, col: 'rgba(255,255,255,0.85)', size: 2 });
  if (G.cup) {
    const d = Math.hypot(ball.x - G.cup.x, ball.y - G.cup.y);
    if (!G.cup.armed && d > 0.65) G.cup.armed = true;
    if (G.cup.armed && d < 0.3 && ball.z - G.cup.z < 0.25) {
      if (sp < 5.5) { sink(); return; }
      if (!ball.lipT || G.t - ball.lipT > 0.4) { ball.lipT = G.t; ball.vz = 2.6; ball.z += 0.02; Audio.sfx('lip'); popup(s.x, s.y - 26, 'Quase!', '#FFFFFF', 18, 0.8); }
    }
  }
  // enemies notice a fast ball coming
  for (const e of G.enemies) {
    if (!e.alive || e.t === 'ourico') continue;
    const d = Math.hypot(ball.x - e.x, ball.y - e.y);
    if (d < 1.8 && sp > 3) { if (e.scared <= 0) Audio.sfx('scared'); e.scared = 0.5; }
  }
  const c = hole.cell(Math.floor(ball.x), Math.floor(ball.y));
  if (ball.onGround && ball.vz === 0 && (sp < 0.16 || G.stone) && (!(c && c.slope) || G.stone)) {
    ball.vx = 0; ball.vy = 0; G.stone = 0;
    G.lastRest = { x: ball.x, y: ball.y };
    ball.brake = false; ball.trail = [];
    if (G.combo === 0 && foesLeft() > 0 && G.strokes > 0) { ball.face = 'sleepy'; ball.faceT = 0.6; }
    setMode('aim');
  }
}
function outOfBounds(kind) {
  setMode('out');
  G.strokes += 1; bumpStroke();
  const s = toWorldPx(ball.x, ball.y, Math.max(ball.z, BOTTOM));
  if (kind === 'water') { Audio.sfx('splash'); for (let i = 0; i < 26; i++) addPart({ type: 'drop', x: s.x, y: s.y, vx: rand(-60, 60), vy: rand(-150, -50), g: 400, life: 0.8, col: pick(['#A8E2FF', '#FFFFFF', '#3F9BEA']) }); addPart({ type: 'ring', x: s.x, y: s.y, life: 0.5, size: 20, col: '#A8E2FF' }); ball.hidden = true; }
  else Audio.sfx('fall');
  popup(s.x, Math.min(s.y, P(ball.x, ball.y, 0).y) - 30, kind === 'water' ? 'Splash! +1' : 'Caiu! +1', '#FF7FA8', 22, 1.2);
  buzz(50);
  const h0 = hole;
  setTimeout(() => {
    if (hole !== h0) return;
    Object.assign(ball, { x: G.lastRest.x, y: G.lastRest.y, vx: 0, vy: 0, vz: 0, hidden: false, M: ID3.slice(), trail: [] });
    ball.z = surf(ball.x, ball.y); ball.sq = -0.35;
    const p = toWorldPx(ball.x, ball.y, ball.z); burstStars(p.x, p.y, 8, ['#FFFFFF', '#B89CF0']);
    if (G.mode === 'out') setMode('aim');
  }, 1000);
}
function sink() {
  setMode('sink');
  Audio.sfx('sink'); confetti(80); shake(3); buzz([30, 40, 60]);
  G.flash = 0.7; G.slowT = 0.4;
  ball.vx = ball.vy = ball.vz = 0;
  G.scores[G.holeIdx] = G.strokes;
  const cp = toWorldPx(G.cup.x, G.cup.y, G.cup.z);
  popup(cp.x, cp.y - 40, rankName(G.strokes, hole.def.par), '#FFE36E', 30, 1.6);
  [200, 450, 700, 950].forEach((ms) => setTimeout(() => firework(cp.x + rand(-70, 70), cp.y - rand(50, 110)), ms));
  const h0 = hole; setTimeout(() => { if (hole === h0 && G.mode === 'sink') showResult(); }, 1700);
}

// ============================================================ rendering — sky
let sky = null;
function buildSky() {
  const c = document.createElement('canvas'); c.width = VW; c.height = VH;
  const ctx = c.getContext('2d'), img = ctx.createImageData(VW, VH), d = img.data;
  const stops = [[0, rgb('#110B30')], [0.32, rgb('#2A2066')], [0.6, rgb('#69409E')], [0.82, rgb('#D2689C')], [1, rgb('#FFB27A')]];
  const bands = 22;
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
  // dithered ringed planet
  const pr = Math.round(Math.min(VW, VH) * 0.16), pcx = Math.round(VW * 0.8), pcy = Math.round(VH * 0.15);
  for (let y = -pr; y <= pr; y++) for (let x = -pr; x <= pr; x++) {
    const d2 = (x * x + y * y) / (pr * pr); if (d2 > 1) continue;
    const X = pcx + x, Y = pcy + y; if (X < 0 || Y < 0 || X >= VW || Y >= VH) continue;
    const nz = Math.sqrt(1 - d2), l = ((-x * 0.6 - y * 0.5) / pr) * 0.6 + nz * 0.6;
    const v = l + (BAYER[Y & 3][X & 3] / 16 - 0.5) * 0.22;
    const col = v > 0.8 ? rgb('#FFEAF2') : v > 0.6 ? rgb('#FBBAD4') : v > 0.4 ? rgb('#E08EC0') : v > 0.2 ? rgb('#B070AE') : rgb('#6E4492');
    const band = Math.sin((y / pr) * 8 + (x / pr) * 1.5) > 0.6 && v > 0.25 ? 0.88 : 1;
    const j = (Y * VW + X) * 4; d[j] = col[0] * band; d[j + 1] = col[1] * band; d[j + 2] = col[2] * band;
  }
  ctx.putImageData(img, 0, 0);
  for (let a = 0; a < TAU; a += 0.006) {
    const x = Math.round(pcx + Math.cos(a) * pr * 1.75), y = Math.round(pcy + Math.sin(a) * pr * 0.3 + Math.cos(a) * pr * 0.12);
    if (Math.sin(a) > 0 || ((x - pcx) ** 2 + (y - pcy) ** 2) / (pr * pr) > 1) { ctx.fillStyle = Math.sin(a * 3) > 0 ? '#FFD7E6' : '#E8A8C8'; ctx.fillRect(x, y, 1, 1); }
  }
  sky = c;
}
const STARS = Array.from({ length: 120 }, (_, i) => [hash(i, 1), hash(i, 2) * 0.62, hash(i, 3)]);
const CLOUDS = Array.from({ length: 9 }, (_, i) => ({ x: hash(i, 9), y: 0.3 + hash(i, 10) * 0.7, s: 0.5 + hash(i, 11) * 0.9, sp: 3 + hash(i, 12) * 6, layer: i % 3 }));
function drawSky(t) {
  if (!sky) buildSky();
  g.drawImage(sky, 0, 0);
  for (const [sx0, sy0, ph] of STARS) {
    const tw = Math.sin(t * 2 + ph * 20);
    if (tw < -0.6) continue;
    const x = Math.round(sx0 * VW), y = Math.round(sy0 * VH);
    g.fillStyle = tw > 0.85 ? '#FFFFFF' : 'rgba(255,240,220,0.65)';
    g.fillRect(x, y, 1, 1);
    if (tw > 0.95) { g.fillRect(x - 2, y, 5, 1); g.fillRect(x, y - 2, 1, 5); }
  }
  for (const c of CLOUDS) {
    if (c.layer === 2) continue;
    const w = Math.round(46 * c.s + 16), x = Math.round(((c.x * (VW + 180) + t * c.sp - camX() * (c.layer ? 0.1 : 0.05)) % (VW + 180)) - 90), y = Math.round(c.y * VH - camY() * 0.06);
    drawCloud(x, y, w, c.layer);
  }
}
function drawFrontClouds(t) {
  for (const c of CLOUDS) {
    if (c.layer !== 2) continue;
    const w = Math.round(70 * c.s + 30), span = VW + 240;
    const x = Math.round((((c.x * span + t * c.sp * 1.6 - camX() * 0.25) % span) + span) % span - 120), y = Math.round(VH * (0.8 + c.y * 0.22) - camY() * 0.2);
    drawCloud(x, y, w, 2);
  }
}
function drawCloud(x, y, w, layer) {
  const cols = layer === 2 ? ['rgba(255,214,232,0.9)', 'rgba(255,240,246,0.95)', 'rgba(232,170,205,0.9)'] : layer ? ['#F2B2D0', '#FFDCEB', '#D890BA'] : ['#AE80C4', '#D8ACDC', '#8E62AA'];
  const h = Math.round(w * 0.28);
  g.fillStyle = cols[2]; g.fillRect(x + 2, y + h - 2, w - 4, 2);
  g.fillStyle = cols[0]; g.fillRect(x, y, w, h - 2); g.fillRect(x + 3, y - 3, w - 6, 3);
  g.fillStyle = cols[1];
  g.fillRect(x + Math.round(w * 0.14), y - Math.round(h * 0.7), Math.round(w * 0.34), Math.round(h * 0.8));
  g.fillRect(x + Math.round(w * 0.42), y - Math.round(h * 1.05), Math.round(w * 0.3), Math.round(h * 1.15));
  g.fillRect(x + 4, y - 2, w - 8, Math.round(h * 0.45));
}

// ============================================================ rendering — world
let treeSprites = {};
function drawWorld(t) {
  const ox = camX(), oy = camY();
  const objs = [];
  if (!ball.hidden) objs.push({ k: Math.floor(ball.x) + Math.floor(ball.y) + 0.5, draw: drawBall, depth: ball.x + ball.y });
  for (const e of G.enemies) if (e.alive || (e.die && e.die.t < 0.55)) objs.push({ k: Math.floor(e.x) + Math.floor(e.y) + 0.5 + (e.alive ? 0 : 50), draw: () => drawEnemy(e, t), depth: e.x + e.y });
  for (const bm of hole.bumpers) objs.push({ k: Math.floor(bm.x) + Math.floor(bm.y) + 0.5, draw: () => drawBumper(bm), depth: bm.x + bm.y - 0.01 });
  for (const tr of hole.trees) objs.push({ k: Math.floor(tr.x) + Math.floor(tr.y) + 0.5, draw: () => drawTree(tr, t), depth: tr.x + tr.y - 0.01 });
  if (G.cup) objs.push({ k: Math.floor(G.cup.x) + Math.floor(G.cup.y) + 0.5, draw: () => drawCup(t), depth: G.cup.x + G.cup.y - 0.02 });
  objs.sort((a, b) => a.k - b.k || a.depth - b.depth);
  let oi = 0;
  const maxK = hole.W + hole.H;
  for (let s = 0; s <= maxK; s++) {
    while (oi < objs.length && objs[oi].k < s) objs[oi++].draw();
    for (let x = Math.max(0, s - hole.H + 1); x <= Math.min(s, hole.W - 1); x++) {
      const y = s - x, c = hole.cell(x, y); if (!c) continue;
      const p = P(x, y, 0), spr = c.spr;
      const lift = c.pop > 0.01 ? Math.round(Math.sin((1 - c.pop) * Math.PI * 3) * c.pop * 4) : 0;
      const X = Math.round(p.x - TWH - ox), Y = Math.round(p.y - spr.K - oy) - lift;
      if (X > VW || X + 32 < 0 || Y > VH || Y + spr.cnv.height < 0) continue;
      g.drawImage(spr.cnv, X, Y);
      if (c.type === 'water') drawWater(c, X, Y + spr.K, t);
      else if (c.dash) drawDashArrows(c, X, Y + spr.K - c.h * HZ, t);
    }
  }
  while (oi < objs.length) objs[oi++].draw();
}
function drawWater(c, X, Y, t) {
  const top = Y - (c.h - 0.2) * HZ;
  for (let i = 0; i < 4; i++) {
    const ph = (t * 0.5 + hash(c.x, c.y, i)) % 1, row = Math.round(1 + ph * 14), half = row < 8 ? (row + 1) * 2 : (16 - row) * 2;
    const w = 4 + Math.round(Math.sin(t * 3 + i) * 2);
    if (half <= w + 2) continue;
    const xx = X + 16 - half + 1 + Math.round(hash(c.x, c.y, i + 4) * (half * 2 - w - 2));
    g.fillStyle = i & 1 ? '#A8E2FF' : '#7CC4F6';
    g.fillRect(xx, Math.round(top + row), w, 1);
  }
  if (((t * 1.5 + c.x * 0.37 + c.y * 0.71) % 3) < 0.12) { g.fillStyle = '#FFFFFF'; g.fillRect(X + 15, Math.round(top + 6), 1, 1); g.fillRect(X + 14, Math.round(top + 7), 3, 1); g.fillRect(X + 15, Math.round(top + 8), 1, 1); }
}
function drawDashArrows(c, X, top, t) {
  const ph = (t * 2.2) % 1, [dx, dy] = c.dash;
  const ex = (dx - dy) * TWH, ey = (dx + dy) * TH, L = Math.hypot(ex, ey), fx = ex / L, fy = ey / L;
  for (let k = 0; k < 2; k++) {
    const a = ((ph + k * 0.5) % 1) - 0.5, uu = 0.5 + dx * a * 0.7, vv = 0.5 + dy * a * 0.7;
    const sxp = X + TWH + (uu - vv) * TWH, syp = top + (uu + vv) * TH;
    g.fillStyle = Math.abs(a) < 0.3 ? '#FFFBE0' : '#FFD27A';
    for (let i = -4; i <= 4; i++) {
      const back = Math.abs(i) * 1.1;
      for (let th = 0; th < 2; th++) g.fillRect(Math.round(sxp - fx * (back + th) - fy * i * 1.2), Math.round(syp - fy * (back + th) + fx * i * 0.6), 1, 1);
    }
  }
}
function drawShadow(x, y, z, r) {
  const gz = surf(x, y); if (!Number.isFinite(gz)) return;
  const p = toScreen(x, y, gz), h = Math.max(0, z - gz), k = clamp(1 - h * 0.2, 0.4, 1);
  const rx = Math.round(r * k), ry = Math.max(1, Math.round(r * 0.45 * k));
  for (let yy = -ry; yy <= ry; yy++) for (let xx = -rx; xx <= rx; xx++) {
    const q = (xx * xx) / (rx * rx) + (yy * yy) / (ry * ry); if (q > 1) continue;
    if (q > 0.55 && ((xx + yy) & 1)) continue;
    g.fillStyle = q < 0.3 ? 'rgba(30,12,50,0.5)' : 'rgba(30,12,50,0.36)';
    g.fillRect(p.x + xx, p.y + yy, 1, 1);
  }
}

function ballFace() {
  if (G.stone) return 'angry';
  if (ball.faceT > 0) return ball.face;
  if (G.mode === 'aim' && aim.on) return aim.power > 0.85 ? 'angry' : 'focus';
  if (G.mode === 'aim' && G.idleT > 7) return 'sleepy';
  if (ball.blink > 0) return 'blink';
  return 'open';
}
function drawCharacter(cIdx, x, y, r, M, sq, face, mouth, upright, t, look) {
  const c = CHARS[cIdx];
  const spr = sphereSprite('ch' + r, { r, pal: G.stone && cIdx === G.charIdx && r < 16 ? STONE : c.body, M, sx: 1 + sq, sy: 1 - sq, eyes: face, mouth, blush: true, look });
  const X = Math.round(x - spr.width / 2), Y = Math.round(y - spr.height + 1);
  if (upright) {
    const fw = Math.max(3, Math.round(r * 0.55)), fh = Math.max(2, Math.round(r * 0.3)), fy = Y + spr.height - fh;
    for (const s of [-1, 1]) {
      const fx = Math.round(x + s * r * 0.5 - fw / 2);
      g.fillStyle = c.feet[0]; g.fillRect(fx, fy, fw, fh); g.fillRect(fx + 1, fy + fh, fw - 2, 1);
      g.fillStyle = c.feet[1]; g.fillRect(fx + 1, fy, fw - 2, fh - 1);
    }
  }
  g.drawImage(spr, X, Y);
  if (upright && !(G.stone && cIdx === G.charIdx)) {
    const frame = Math.floor(t * 6), f = PX[c.acc].f[0], aw = f[0].length, ah = f.length, sc = r >= 20 ? 2 : 1;
    if (sc === 1) drawPx(g, c.acc, Math.round(x - aw / 2 + 1), Y - ah + 3, frame);
    else { g.save(); g.translate(Math.round(x - aw + 2), Y - ah * 2 + 6); g.scale(2, 2); drawPx(g, c.acc, 0, 0, frame); g.restore(); }
  }
}
function drawTrail() {
  const c = ch().body, n = ball.trail.length;
  for (let i = 0; i < n; i++) {
    const p = ball.trail[i], age = G.t - p.t; if (age > 0.25) continue;
    const k = i / n, r = Math.round(BALL_R * (0.4 + k * 0.5)), x = Math.round(p.x - camX()), y = Math.round(p.y - camY());
    g.fillStyle = k > 0.6 ? c[3] : c[2];
    for (let yy = -r; yy <= r; yy++) for (let xx = -r; xx <= r; xx++) if (xx * xx + yy * yy <= r * r && ((xx + yy + i) & 1) === 0) g.fillRect(x + xx, y + yy, 1, 1);
  }
}
function drawBall() {
  const t = G.t;
  if (G.mode === 'sink' || (G.mode === 'clear' && G.cup)) {
    const k = clamp(G.mode === 'sink' ? G.modeT / 0.7 : 1, 0, 1); if (k >= 1) return;
    const a = k * TAU * 1.5, rad = (1 - k) * 0.35;
    const p = toScreen(G.cup.x + Math.cos(a) * rad, G.cup.y + Math.sin(a) * rad, G.cup.z);
    drawCharacter(G.charIdx, p.x, p.y + Math.round(k * 8), Math.max(3, Math.round(BALL_R * (1 - k * 0.75))), rotM(ball.M, 0, 0, 1, a), 0, 'happy', 'grin', false, t);
    return;
  }
  const z = ball.z, gzv = surf(ball.x, ball.y);
  drawShadow(ball.x, ball.y, z, 10);
  if (G.mode === 'roll') drawTrail();
  const p = toScreen(ball.x, ball.y, z);
  const upright = G.mode === 'title' || (ball.M[4] > 0.92 && ball.M[8] > 0.85 && G.mode !== 'roll');
  let sq = ball.sq;
  if (G.mode === 'aim' && aim.on) sq += -aim.power * 0.18 + Math.sin(t * 34) * aim.power * 0.035;
  else if (G.mode === 'aim') sq += Math.sin(t * 3) * 0.04;
  const air = z - (Number.isFinite(gzv) ? gzv : z);
  if (air > 0.2 && G.mode === 'roll') sq = Math.max(-0.22, sq - Math.min(air * 0.06, 0.16));
  const mouth = ball.faceT > 0 && ball.face === 'happy' ? 'grin' : ball.faceT > 0 && ball.face === 'dizzy' ? 'wavy' : air > 0.6 ? 'o' : G.mode === 'aim' && aim.on && aim.power > 0.6 ? 'grin' : G.mode === 'aim' || G.mode === 'title' ? 'smile' : 'none';
  let look = [0, 0];
  if (G.mode === 'aim' && aim.on) { const sd = aim.screenDir; look = [sd[0] * 0.8, sd[1] * 0.6]; }
  else if (G.mode === 'aim') {
    const e = G.enemies.find((en) => en.alive && en.t !== 'ourico'), tgt = G.cup || e;
    if (tgt) { const tp = toScreen(tgt.x, tgt.y, tgt.z), dx = tp.x - p.x, dy = tp.y - p.y, l = Math.hypot(dx, dy) || 1; look = [(dx / l) * 0.6, (dy / l) * 0.4]; }
  }
  drawCharacter(G.charIdx, p.x, p.y + 4, BALL_R, ball.M, sq, ballFace(), mouth, upright, t, look);
  if (ball.brake && G.mode === 'roll' && Math.random() < 0.6) addPart({ type: 'puff', x: p.x + camX() + rand(-6, 6), y: p.y + camY() + 4, vy: -15, life: 0.3, col: '#FFFFFF', size: 2 });
  if (G.mode === 'roll' && G.ability && Math.floor(t * 4) % 2) pixelCircle(p.x, p.y - 8, 18, '#6EE7A8', 2);
}

const ENEMY_PAL = {
  gota: ['#123A22', '#2A7A46', '#46B464', '#84E29A', '#D8FFE0'],
  cogu: ['#4E101C', '#B02E3C', '#EA5858', '#FF9A8E', '#FFE2DA'],
  piu: ['#24124E', '#5638A6', '#8868DE', '#BCA4FF', '#F2EAFF'],
  ourico: ['#100C28', '#2A265A', '#46428C', '#7874C0', '#CAC6F2'],
};
function drawEnemy(e, t) {
  let ox = 0, oy = 0, flash = false, M = ID3;
  if (!e.alive && e.die) {
    const d = e.die; if (d.t >= 0.55) return;
    ox = Math.round(d.vx * d.t); oy = Math.round(d.vy * d.t + 420 * d.t * d.t);
    flash = d.t < 0.08; M = rotM(ID3, 0, 0, 1, d.t * 18);
  }
  let z = e.z;
  const phase = t * 2 + e.id * 1.7;
  if (e.t === 'piu') z += (e.fly = 1.3 + Math.sin(phase * 1.5) * 0.15);
  if (e.alive) drawShadow(e.x, e.y, z, e.t === 'piu' ? 7 : 9);
  const p0 = toScreen(e.x, e.y, z), jit = e.alive && e.scared > 0 ? Math.round(Math.sin(t * 60)) : 0;
  const p = { x: p0.x + ox + jit, y: p0.y + oy };
  const bp = toScreen(ball.x, ball.y, ball.z), ldx = bp.x - p.x, ldy = bp.y - p.y, ll = Math.hypot(ldx, ldy) || 1;
  const look = [ldx / ll, (ldy / ll) * 0.6];
  const scared = e.alive && e.scared > 0;
  const eyes = scared ? 'wide' : !e.alive ? 'dizzy' : 'open';
  switch (e.t) {
    case 'gota': {
      const bob = Math.sin(phase * 2) * 0.12;
      const spr = sphereSprite('e' + e.id, { r: 10, pal: ENEMY_PAL.gota, sx: 1.12 + bob, sy: 0.84 - bob, cut: 0.6, eyes, mouth: scared || !e.alive ? 'o' : 'smile', eye: { x: 0.32, y: -0.08, rx: 0.13, ry: 0.22 }, look, flash, M });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(p.y - spr.height + 1 + spr.height * 0.18));
      break;
    }
    case 'cogu': {
      const step = Math.floor(phase * 3) % 2;
      if (e.alive) { g.fillStyle = '#4A2E22'; g.fillRect(p.x - 5 + step, p.y - 1, 4, 2); g.fillRect(p.x + 1 - step, p.y - 1, 4, 2); }
      g.fillStyle = '#5A3A2A'; g.fillRect(p.x - 7, p.y - 12, 14, 11);
      g.fillStyle = flash ? '#FFFFFF' : '#F2E2C4'; g.fillRect(p.x - 6, p.y - 12, 12, 10);
      g.fillStyle = flash ? '#FFFFFF' : '#FFF8EA'; g.fillRect(p.x - 6, p.y - 12, 3, 8);
      g.fillStyle = '#D9C49E'; g.fillRect(p.x + 3, p.y - 11, 3, 9);
      g.fillStyle = '#1B1030'; const ex = Math.round(look[0] * 1.5);
      g.fillRect(p.x - 4 + ex, p.y - 9, 2, scared ? 4 : 3); g.fillRect(p.x + 2 + ex, p.y - 9, 2, scared ? 4 : 3);
      g.fillStyle = '#FFFFFF'; g.fillRect(p.x - 4 + ex, p.y - 9, 1, 1); g.fillRect(p.x + 2 + ex, p.y - 9, 1, 1);
      const spr = sphereSprite('e' + e.id, { r: 12, pal: ENEMY_PAL.cogu, sx: 1.2, sy: 0.82, cut: 0.15, spots: [[-0.42, -0.5, 0.75, 0.22], [0.36, -0.66, 0.65, 0.2], [0.05, -0.3, 0.95, 0.16], [0.72, -0.2, 0.68, 0.16], [-0.8, -0.2, 0.55, 0.14]], flash, M });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(p.y - 10 - spr.height * 0.6));
      break;
    }
    case 'piu': {
      const fr = Math.floor(t * 12 + e.id) % 3;
      drawPx(g, 'wing', p.x - 15, p.y - 15, fr);
      drawPx(g, 'wing', p.x + 7, p.y - 15, fr, true);
      const spr = sphereSprite('e' + e.id, { r: 8, pal: ENEMY_PAL.piu, eyes, eye: { x: 0.3, y: -0.12, rx: 0.14, ry: 0.24 }, look, flash, M });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(p.y - spr.height));
      g.fillStyle = '#FFB13D'; g.fillRect(p.x - 2, p.y - 8, 4, 2); g.fillStyle = '#E07A1A'; g.fillRect(p.x - 1, p.y - 6, 2, 1);
      break;
    }
    case 'ourico': {
      const spin = t * 1.5, cy = p.y - 11;
      g.fillStyle = e.flash > 0 && (Math.floor(t * 20) & 1) ? '#FFFFFF' : '#E8E4FF';
      for (let i = 0; i < 10; i++) { const a = spin + (i / 10) * TAU; for (let k = 10; k <= 14; k++) g.fillRect(Math.round(p.x + Math.cos(a) * k), Math.round(cy + Math.sin(a) * k * 0.9), k < 12 ? 2 : 1, 1); }
      const spr = sphereSprite('e' + e.id, { r: 10, pal: ENEMY_PAL.ourico, eyes: 'angry', eye: { x: 0.32, y: -0.05, rx: 0.15, ry: 0.22 }, look });
      g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(cy - spr.height / 2));
      break;
    }
  }
  if (scared && e.t !== 'ourico') drawPx(g, 'sweat', p.x + 9, p.y - 22 + Math.round((t * 8) % 3));
  if (e.alive && e.ab) {
    const bob = Math.round(Math.sin(t * 4 + e.id) * 2), iy = p.y - (e.t === 'cogu' ? 40 : 34) + bob;
    g.fillStyle = 'rgba(27,16,48,0.75)'; g.fillRect(p.x - 7, iy - 2, 14, 13); g.fillRect(p.x - 6, iy - 3, 12, 15);
    drawPx(g, e.ab, p.x - 4, iy, 0);
  }
}
function drawBumper(bm) {
  bm.squash = Math.max(0, bm.squash - 0.05);
  const p = toScreen(bm.x, bm.y, bm.z), s = bm.squash;
  g.fillStyle = '#6A1A3E'; g.fillRect(p.x - 8, p.y - 7, 16, 8);
  g.fillStyle = '#C23A72'; g.fillRect(p.x - 7, p.y - 7, 14, 7);
  g.fillStyle = '#E25A8E'; g.fillRect(p.x - 7, p.y - 7, 5, 6);
  g.fillStyle = '#FFFFFF'; g.fillRect(p.x - 7, p.y - 4, 14, 1);
  const spr = sphereSprite('bump' + Math.round(s * 4), { r: 9, pal: ['#5A1236', '#C23A72', '#FF6FA2', '#FFA6C8', '#FFE6F0'], sx: 1.1 + s * 0.35, sy: 0.75 - s * 0.3, cut: 0.2 });
  g.drawImage(spr, Math.round(p.x - spr.width / 2), Math.round(p.y - 7 - spr.height * 0.62));
}
function drawTree(tr, t) {
  tr.shake = Math.max(0, tr.shake - 0.03);
  const p = toScreen(tr.x, tr.y, tr.z);
  drawShadow(tr.x, tr.y, tr.z, 13);
  g.fillStyle = '#4A2A20'; g.fillRect(p.x - 4, p.y - 18, 8, 18); g.fillRect(p.x - 6, p.y - 3, 12, 3);
  g.fillStyle = '#7A4A32'; g.fillRect(p.x - 3, p.y - 18, 4, 16);
  g.fillStyle = '#A06A48'; g.fillRect(p.x - 3, p.y - 16, 1, 12);
  const key = 'tree' + (tr.big ? 1 : 0);
  if (!treeSprites[key]) {
    const s = sphereSprite('tA', { r: tr.big ? 17 : 15, pal: ['#0E3020', '#1D6436', '#2E944C', '#5AC266', '#A8EE98'] });
    const c = document.createElement('canvas'); c.width = s.width; c.height = s.height; c.getContext('2d').drawImage(s, 0, 0);
    treeSprites[key] = c;
  }
  const spr = treeSprites[key];
  const sway = Math.round(Math.sin(t * 1.3 + tr.i) + Math.sin(G.t * 40) * tr.shake * 3);
  const tx = Math.round(p.x - spr.width / 2) + sway, ty = Math.round(p.y - 16 - spr.height + 6);
  g.drawImage(spr, tx, ty);
  g.fillStyle = '#C8F7B0'; g.fillRect(tx + 9, ty + 7, 3, 1); g.fillRect(tx + 7, ty + 9, 2, 1); g.fillRect(tx + 14, ty + 5, 2, 1);
  g.fillStyle = '#FF7FA8'; g.fillRect(tx + spr.width - 11, ty + 13, 2, 2); g.fillRect(tx + 12, ty + spr.height - 10, 2, 2);
}
function drawCup(t) {
  const c = G.cup; c.t += 1 / 60;
  const p = toScreen(c.x, c.y, c.z), k = clamp(c.t / 0.5, 0, 1);
  if (k < 1) pixelCircle(p.x, p.y, Math.round(26 * (1 - k) + 4), '#FFE36E');
  g.fillStyle = '#FFF4E0'; g.fillRect(p.x - 9, p.y - 3, 18, 7); g.fillRect(p.x - 7, p.y - 5, 14, 11);
  g.fillStyle = '#C9B8A4'; g.fillRect(p.x - 9, p.y + 2, 18, 2);
  g.fillStyle = '#140A24'; g.fillRect(p.x - 7, p.y - 2, 14, 5); g.fillRect(p.x - 5, p.y - 3, 10, 7);
  g.fillStyle = '#2E1A4A'; g.fillRect(p.x - 5, p.y - 3, 10, 1);
  const fh = Math.round(30 * k);
  g.fillStyle = '#FFFFFF'; g.fillRect(p.x + 5, p.y - fh, 2, fh); g.fillStyle = '#C9B8D8'; g.fillRect(p.x + 6, p.y - fh, 1, fh);
  if (k >= 1) {
    for (let i = 0; i < 12; i++) {
      const wv = Math.round(Math.sin(t * 7 - i * 0.6) * 1.5), hh = Math.max(1, 9 - Math.floor(i * 0.7));
      g.fillStyle = i < 2 ? '#C23A6A' : '#FF5A8A'; g.fillRect(p.x + 7 + i, p.y - 30 + wv + Math.floor((9 - hh) / 2), 1, hh);
    }
    g.fillStyle = '#FFE36E'; const sw = Math.round(Math.sin(t * 7 - 3) * 1.5);
    g.fillRect(p.x + 11, p.y - 27 + sw, 1, 3); g.fillRect(p.x + 10, p.y - 26 + sw, 3, 1);
    if (Math.random() < 0.15) addPart({ type: 'star', x: p.x + camX() + rand(-8, 8), y: p.y + camY() - rand(0, 16), vy: -20, life: 0.6, col: '#FFE36E' });
  }
}

// ============================================================ overlay (crisp UI layer)
const aim = { on: false, sx: 0, sy: 0, x: 0, y: 0, power: 0, dir: [1, 0], screenDir: [1, 0], pred: { pts: [] }, lastTick: 0 };
function screenDirToWorld(dx, dy) {
  const a = dx / TWH, b = dy / TH;
  const x = (a + b) / 2, y = (b - a) / 2, l = Math.hypot(x, y) || 1;
  return [x / l, y / l];
}
function updateAim() {
  const dx = aim.sx - aim.x, dy = aim.sy - aim.y, len = Math.hypot(dx, dy);
  const full = Math.min(VW, VH) * 0.36;
  aim.power = clamp(len / full, 0, 1);
  if (len > 2) { aim.dir = screenDirToWorld(dx, dy); aim.screenDir = [dx / len, dy / len]; }
  const v = shotVel(aim.dir[0], aim.dir[1], aim.power);
  aim.pred = predict(v[0], v[1], v[2]);
  const tick = Math.floor(aim.power * 12);
  if (tick !== aim.lastTick) { aim.lastTick = tick; Audio.sfx('tick', aim.power); }
}
const FONT = '"Pixelify Sans", "Silkscreen", ui-monospace, monospace';
function drawOverlay(dt) {
  u.setTransform(1, 0, 0, 1, 0, 0);
  u.clearRect(0, 0, ui.width, ui.height);
  const D = DPR;
  if (hole && G.mode === 'aim') {
    if (aim.on && aim.power > 0.03) drawAimUI(D);
    else if (G.holeIdx === 0 && G.strokes === 0 && !G.trans && G.modeT > 0.6) drawTutorial(D);
  }
  if (hole && ['aim', 'roll'].includes(G.mode)) drawOffscreen(D);
  for (let i = pops.length - 1; i >= 0; i--) {
    const p = pops[i]; p.t += dt; if (p.t >= p.life) { pops.splice(i, 1); continue; }
    const k = p.t / p.life, sc = p.t < 0.2 ? easeOutBack(p.t / 0.2) : 1, a = k > 0.75 ? (1 - k) / 0.25 : 1;
    let [x, y] = w2o(p.x, p.y - k * 18);
    u.font = `700 ${p.size * D}px ${FONT}`; u.textAlign = 'center'; u.textBaseline = 'middle';
    const hw = u.measureText(p.text).width / 2 + 10 * D;
    x = clamp(x, hw, ui.width - hw); y = clamp(y, 110 * D, ui.height - 130 * D);
    u.save(); u.globalAlpha = a; u.translate(x, y); u.scale(sc, sc);
    u.lineJoin = 'round'; u.lineWidth = 6 * D; u.strokeStyle = '#1B1030'; u.strokeText(p.text, 0, 0);
    u.fillStyle = p.color; u.fillText(p.text, 0, 0);
    u.restore();
  }
  if (G.flash > 0) { u.fillStyle = `rgba(255,250,235,${G.flash * 0.55})`; u.fillRect(0, 0, ui.width, ui.height); }
}
function drawAimUI(D) {
  const bp = P(ball.x, ball.y, ball.z), [bx, by0] = w2o(bp.x, bp.y), by = by0 - 6 * SCALE;
  const col = aim.power > 0.85 ? '#FF6A7E' : aim.power > 0.5 ? '#FFD45C' : '#6EE7A8';
  const fx = aim.x * SCALE, fy = aim.y * SCALE;
  u.lineCap = 'round';
  u.strokeStyle = 'rgba(27,16,48,0.45)'; u.lineWidth = 6 * D; u.beginPath(); u.moveTo(bx, by); u.lineTo(fx, fy); u.stroke();
  u.strokeStyle = 'rgba(255,244,224,0.75)'; u.lineWidth = 3 * D; u.setLineDash([4 * D, 5 * D]); u.beginPath(); u.moveTo(bx, by); u.lineTo(fx, fy); u.stroke(); u.setLineDash([]);
  u.fillStyle = 'rgba(255,244,224,0.9)'; u.beginPath(); u.arc(fx, fy, 7 * D, 0, TAU); u.fill();
  // trajectory: evenly spaced dots marching along the predicted path
  const pts = aim.pred.pts.map((p) => w2o(p.x, p.y - 6));
  if (pts.length > 1) {
    const segs = [0]; for (let i = 1; i < pts.length; i++) segs.push(segs[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
    const total = segs[segs.length - 1] * (G.holeIdx === 0 ? 0.85 : 0.6), gap = 14 * D, off = (G.t * 40 * D) % gap;
    let j = 1, lastDot = null;
    for (let s = off; s < total; s += gap) {
      while (j < segs.length - 1 && segs[j] < s) j++;
      const a = pts[j - 1], b = pts[j], f = (s - segs[j - 1]) / Math.max(1e-6, segs[j] - segs[j - 1]);
      const x = lerp(a[0], b[0], f), y = lerp(a[1], b[1], f), k = s / total;
      const r = lerp(5.5, 2.5, k) * D;
      u.globalAlpha = 1 - k * 0.7;
      u.fillStyle = '#1B1030'; u.beginPath(); u.arc(x, y + D, r + 1.5 * D, 0, TAU); u.fill();
      u.fillStyle = k < 0.15 ? col : '#FFFFFF'; u.beginPath(); u.arc(x, y, r, 0, TAU); u.fill();
      lastDot = [x, y, a, b];
    }
    u.globalAlpha = 1;
    if (lastDot) {
      const ang = Math.atan2(lastDot[3][1] - lastDot[2][1], lastDot[3][0] - lastDot[2][0]);
      u.save(); u.translate(lastDot[0], lastDot[1]); u.rotate(ang);
      u.fillStyle = '#1B1030'; u.beginPath(); u.moveTo(12 * D, 0); u.lineTo(-6 * D, -9 * D); u.lineTo(-6 * D, 9 * D); u.closePath(); u.fill();
      u.fillStyle = '#FFFFFF'; u.beginPath(); u.moveTo(9 * D, 0); u.lineTo(-4 * D, -6 * D); u.lineTo(-4 * D, 6 * D); u.closePath(); u.fill();
      u.restore();
    }
  }
  if (aim.pred.land) {
    const [lx, ly] = w2o(aim.pred.land.x, aim.pred.land.y);
    const pulse = 1 + Math.sin(G.t * 8) * 0.12;
    u.strokeStyle = '#1B1030'; u.lineWidth = 6 * D; u.beginPath(); u.ellipse(lx, ly, 14 * D * pulse, 7 * D * pulse, 0, 0, TAU); u.stroke();
    u.strokeStyle = '#FFE36E'; u.lineWidth = 3 * D; u.beginPath(); u.ellipse(lx, ly, 14 * D * pulse, 7 * D * pulse, 0, 0, TAU); u.stroke();
    u.fillStyle = '#FFE36E'; u.beginPath(); u.ellipse(lx, ly, 5 * D, 2.5 * D, 0, 0, TAU); u.fill();
  }
  // power ring
  const R = 22 * SCALE;
  u.lineWidth = 8 * D; u.strokeStyle = 'rgba(27,16,48,0.6)'; u.beginPath(); u.arc(bx, by, R, 0, TAU); u.stroke();
  u.lineWidth = 5 * D; u.strokeStyle = col; u.beginPath(); u.arc(bx, by, R, -Math.PI / 2, -Math.PI / 2 + aim.power * TAU); u.stroke();
  const label = `${Math.round(aim.power * 100)}%`;
  u.font = `700 ${16 * D}px ${FONT}`; u.textAlign = 'center'; u.textBaseline = 'middle';
  u.lineWidth = 5 * D; u.strokeStyle = '#1B1030'; u.strokeText(label, bx, by - R - 14 * D);
  u.fillStyle = col; u.fillText(label, bx, by - R - 14 * D);
}
function drawTutorial(D) {
  const bp = P(ball.x, ball.y, ball.z), [bx, by] = w2o(bp.x, bp.y - 6);
  const k = (G.t % 1.6) / 1.6, e = k < 0.7 ? k / 0.7 : 1, back = 70 * D * (1 - Math.pow(1 - e, 3));
  const fx = bx - back * 0.7, fy = by + back * 0.7;
  u.globalAlpha = k < 0.85 ? 1 : (1 - k) / 0.15;
  u.strokeStyle = 'rgba(255,244,224,0.8)'; u.lineWidth = 3 * D; u.setLineDash([4 * D, 5 * D]); u.beginPath(); u.moveTo(bx, by); u.lineTo(fx, fy); u.stroke(); u.setLineDash([]);
  u.fillStyle = '#FFFFFF'; u.strokeStyle = '#1B1030'; u.lineWidth = 3 * D;
  u.beginPath(); u.arc(fx, fy, 12 * D, 0, TAU); u.fill(); u.stroke();
  u.font = `700 ${15 * D}px ${FONT}`; u.textAlign = 'center'; u.lineWidth = 5 * D; u.strokeStyle = '#1B1030';
  u.strokeText('Puxe para trás e solte', bx, by - 40 * D); u.fillStyle = '#FFF4E0'; u.fillText('Puxe para trás e solte', bx, by - 40 * D);
  u.globalAlpha = 1;
}
function drawOffscreen(D) {
  const W = ui.width, H = ui.height, m = 26 * D, top = 100 * D, bottom = H - 120 * D;
  const targets = G.enemies.filter((e) => e.alive && e.t !== 'ourico').map((e) => ({ x: e.x, y: e.y, z: e.z + (e.t === 'piu' ? 1.3 : 0), col: '#6EE7A8' }));
  if (G.cup) targets.push({ x: G.cup.x, y: G.cup.y, z: G.cup.z, col: '#FFD45C' });
  for (const tg of targets) {
    const p = P(tg.x, tg.y, tg.z), [x, y] = w2o(p.x, p.y - 8);
    if (x > m && x < W - m && y > top && y < bottom) continue;
    const cx = clamp(x, m, W - m), cy = clamp(y, top, bottom), ang = Math.atan2(y - cy, x - cx);
    u.save(); u.translate(cx, cy);
    u.fillStyle = 'rgba(27,16,48,0.8)'; u.beginPath(); u.arc(0, 0, 13 * D, 0, TAU); u.fill();
    u.fillStyle = tg.col; u.beginPath(); u.arc(0, 0, 6 * D, 0, TAU); u.fill();
    u.rotate(ang); u.beginPath(); u.moveTo(20 * D, 0); u.lineTo(11 * D, -7 * D); u.lineTo(11 * D, 7 * D); u.closePath(); u.fill();
    u.restore();
  }
}

// ============================================================ HUD / DOM
function renderHud() {
  const playing = ['aim', 'roll', 'out', 'sink'].includes(G.mode);
  $('#hud').hidden = !playing;
  if (!hole || !playing) return;
  $('#hHole').textContent = `Buraco ${G.holeIdx + 1}`;
  $('#hPar').textContent = `Par ${hole.def.par}`;
  $('#hStrokes').textContent = G.strokes;
  $('.chip.strokes').classList.toggle('over', G.strokes > hole.def.par);
  const foes = G.enemies.filter((e) => e.t !== 'ourico');
  const el = $('#hFoes'), html = foes.map((e) => `<i class="${e.alive ? '' : 'done'}"></i>`).join('') + (G.cup ? '<i class="cup"></i>' : '');
  if (el.innerHTML !== html) el.innerHTML = html;
  $('#jumpBtn').setAttribute('aria-pressed', G.jump ? 'true' : 'false');
  $('#mapBtn').setAttribute('aria-pressed', G.overview ? 'true' : 'false');
  const slot = $('#abilitySlot');
  slot.hidden = !G.ability;
  if (G.ability) {
    $('#abilityName').textContent = ABIL_NAME[G.ability];
    const ac = $('#abilityIco').getContext('2d'); ac.clearRect(0, 0, 11, 11); drawPx(ac, G.ability, 1, 1, 0);
  }
  $('#hint').textContent = G.mode === 'roll' ? (G.ability ? 'Toque para usar a habilidade' : 'Segure para frear') : G.mode === 'aim' ? (G.jump ? 'Pulo ligado: puxe a bolinha' : 'Puxe a bolinha e solte') : '';
}
function bumpStroke() { const c = $('.chip.strokes'); c.classList.remove('bump'); void c.offsetWidth; c.classList.add('bump'); }
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
  G.holeIdx = i;
  loadHole(window.HOLES[i]);
  $('#iNum').textContent = `Buraco ${i + 1} de ${window.HOLES.length}`;
  $('#iName').textContent = hole.def.name;
  $('#iPar').textContent = `Par ${hole.def.par}`;
  $('#iTip').textContent = hole.def.tip || 'Derrube todos os inimigos. O último vira o buraco!';
  const foes = G.enemies.filter((e) => e.t !== 'ourico').length;
  $('#iFoes').textContent = `${foes} ${foes === 1 ? 'inimigo' : 'inimigos'} para derrubar`;
  setMode('intro'); resize();
  // start the camera over the far end of the course, then glide to the ball
  const far = G.enemies.reduce((a, e) => (Math.hypot(e.x - ball.x, e.y - ball.y) > Math.hypot(a.x - ball.x, a.y - ball.y) ? e : a), G.enemies[0] || ball);
  const fp = P(far.x, far.y, far.z || 0); cam.x = fp.x; cam.y = fp.y;
  showScreen('intro');
}
function beginPlay() {
  showScreen(null); setMode('aim');
  const s = toWorldPx(ball.x, ball.y, ball.z); burstStars(s.x, s.y, 10); ball.sq = -0.35; ball.sqv = 0; Audio.sfx('select');
  popup(s.x, s.y - 34, 'Vai!', '#FFE36E', 24, 1);
}
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
  confetti(100); Audio.sfx('sink');
}
function transition(cb) { G.trans = { t: 0, cb, done: false }; Audio.sfx('whoosh'); }
function toggleOverview(on = !G.overview) {
  G.overview = on; resize(); renderHud();
  if (on) { cam.x = hole.cx; cam.y = hole.cy; }
  Audio.sfx('select');
}

// ============================================================ input
function toInternal(e) { const r = cv.getBoundingClientRect(); return { x: (e.clientX - r.left) * CSS_K, y: (e.clientY - r.top) * CSS_K }; }
let pid = null;
const pan = { on: false, sx: 0, sy: 0, px: 0, py: 0 };
cv.addEventListener('pointerdown', (e) => {
  Audio.init(); if (Audio.musicOn) Audio.startMusic();
  if (pid !== null) return;
  pid = e.pointerId; try { cv.setPointerCapture(pid); } catch (_) { /* */ }
  const p = toInternal(e);
  G.idleT = 0;
  if (G.mode === 'aim') {
    const bp = toScreen(ball.x, ball.y, ball.z), near = Math.hypot(p.x - bp.x, p.y - (bp.y - 6)) < Math.max(34, Math.min(VW, VH) * 0.16);
    if (near || G.overview) { aim.on = true; aim.sx = bp.x; aim.sy = bp.y - 6; aim.x = p.x; aim.y = p.y; aim.power = 0; aim.pred = { pts: [] }; Audio.sfx('select'); }
    else { pan.on = true; pan.sx = p.x; pan.sy = p.y; pan.px = cam.panX; pan.py = cam.panY; }
  } else if (G.mode === 'roll') { if (!useAbility()) { ball.brake = true; Audio.sfx('brake'); } }
});
cv.addEventListener('pointermove', (e) => {
  if (e.pointerId !== pid) return;
  const p = toInternal(e);
  if (aim.on) { aim.x = p.x; aim.y = p.y; updateAim(); }
  else if (pan.on) { cam.panX = pan.px - (p.x - pan.sx); cam.panY = pan.py - (p.y - pan.sy); }
});
const release = (e) => {
  if (e.pointerId !== pid) return; pid = null;
  ball.brake = false; pan.on = false;
  if (aim.on) {
    aim.on = false;
    if (G.mode === 'aim' && aim.power > 0.06 && e.type === 'pointerup') { shoot(aim.dir[0], aim.dir[1], aim.power); save.tutorial = true; persist(); }
  }
};
cv.addEventListener('pointerup', release);
cv.addEventListener('pointercancel', release);
window.addEventListener('keydown', (e) => {
  if (e.key === ' ' && G.mode === 'roll') { if (!useAbility()) ball.brake = true; e.preventDefault(); }
  if ((e.key === 'j' || e.key === 'J') && G.mode === 'aim') { G.jump = !G.jump; renderHud(); }
  if ((e.key === 'm' || e.key === 'M') && ['aim', 'roll'].includes(G.mode)) toggleOverview();
  if (e.key === 'Escape' && ['aim', 'roll'].includes(G.mode)) openPause();
});
window.addEventListener('keyup', (e) => { if (e.key === ' ') ball.brake = false; });

const tap = (id, fn) => $(id).addEventListener('click', (e) => { Audio.init(); fn(e); });
tap('#jumpBtn', () => { if (G.mode !== 'aim') return; G.jump = !G.jump; Audio.sfx(G.jump ? 'jump' : 'select'); renderHud(); if (aim.on) updateAim(); });
tap('#mapBtn', () => { if (['aim', 'roll'].includes(G.mode)) toggleOverview(); });
tap('#prevChar', () => { G.charIdx = (G.charIdx + CHARS.length - 1) % CHARS.length; save.char = G.charIdx; persist(); Audio.sfx('select'); renderCharPicker(); ball.sq = -0.4; });
tap('#nextChar', () => { G.charIdx = (G.charIdx + 1) % CHARS.length; save.char = G.charIdx; persist(); Audio.sfx('select'); renderCharPicker(); ball.sq = -0.4; });
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
function goTitle() {
  G.holeIdx = 0; loadHole(window.TITLE_ISLAND); setMode('title'); resize();
  cam.x = hole.cx; cam.y = hole.cy + 30;
  showScreen('title'); renderCharPicker();
}

// ============================================================ loop
let last = performance.now();
function frame(now) {
  let dt = Math.min((now - last) / 1000, 1 / 20); last = now;
  const realDt = dt;
  G.t += realDt;
  if (G.slowT > 0) { G.slowT -= realDt; dt *= 0.35; }
  G.modeT += dt;
  G.flash = Math.max(0, G.flash - realDt * 2.2);
  if (G.mode === 'aim' && !aim.on) G.idleT += realDt;
  // simulation (hit-stop freezes it for a few frames)
  if (G.freeze > 0) G.freeze -= realDt;
  else if (G.mode === 'roll') updateBall(dt);
  for (const e of G.enemies) {
    if (e.die) {
      e.die.t += dt;
      if (!e.die.popped && e.die.t > 0.45) { e.die.popped = true; const p = P(e.x, e.y, e.z); burstStars(p.x + e.die.vx * 0.45, p.y + e.die.vy * 0.45 + 85, 8, ['#FFFFFF', '#FFE36E'], 0.7); }
    }
    if (!e.alive) continue;
    e.flash -= dt; e.scared -= dt;
    if (e.t === 'cogu' && e.range) {
      const s = Math.sin(G.t * 0.9 + e.id) * e.range;
      if (e.axis === 'x') e.x = e.bx + s; else e.y = e.by + s;
      e.z = groundZ(e.x, e.y);
    }
  }
  if (hole) for (const c of hole.cells) if (c && c.pop > 0) c.pop = Math.max(0, c.pop - realDt * 2.5);
  // squash spring & face
  ball.sqv += (-ball.sq * 260 - ball.sqv * 13) * dt; ball.sq += ball.sqv * dt;
  ball.faceT -= dt; ball.blinkT -= dt;
  if (ball.blinkT < 0) { ball.blink = 0.12; ball.blinkT = rand(2, 4.5); }
  ball.blink -= dt;
  if (G.mode === 'title' && hole) {
    // attract mode: the hero hops on the title island
    const ht = (G.t * 1.1) % 1, hop = ht < 0.45 ? Math.sin((ht / 0.45) * Math.PI) * 1.2 : 0;
    const gz = groundZ(ball.x, ball.y);
    if (hop === 0 && ball.z > gz + 0.05) { ball.sq = 0.3; const p = P(ball.x, ball.y, gz); dust(p.x, p.y + 6, 5); }
    ball.z = gz + hop;
    ball.M = rotM(ID3, 0, 1, 0, Math.sin(G.t * 1.3) * 0.5);
  } else if (G.mode !== 'roll') {
    // turn to face the shot while aiming, otherwise settle upright
    const tgt = G.mode === 'aim' && aim.on && aim.power > 0.05 ? rotM(ID3, 0, 1, 0, clamp(aim.screenDir[0], -1, 1) * 0.7) : ID3;
    const M = ball.M; for (let i = 0; i < 9; i++) M[i] = lerp(M[i], tgt[i], 1 - Math.exp(-realDt * 10)); ball.M = ortho(M);
  }
  // camera
  if (hole) {
    let tx, ty;
    const bp = P(ball.x, ball.y, ball.z);
    if (G.mode === 'title' || G.overview) { tx = hole.cx; ty = hole.cy + (G.mode === 'title' ? 30 : 0); }
    else if (G.focus && G.focus.t > 0) { G.focus.t -= realDt; const fp = P(G.focus.x, G.focus.y, G.focus.z); tx = fp.x; ty = fp.y; }
    else if (G.mode === 'roll') { const vp = P(ball.vx, ball.vy, 0); tx = bp.x + vp.x * 0.25; ty = bp.y + vp.y * 0.25; }
    else if (G.mode === 'intro') { tx = cam.x; ty = cam.y; }
    else {
      tx = bp.x + cam.panX; ty = bp.y + cam.panY;
      if (aim.on && aim.pred.pts.length) { const e = aim.pred.pts[Math.floor(aim.pred.pts.length * 0.5)]; tx += (e.x - bp.x) * 0.35; ty += (e.y - bp.y) * 0.35; }
    }
    if (!G.overview && G.mode !== 'title') {
      const fit = (lo, hi, view, at) => (hi - lo + 40 <= view ? (lo + hi) / 2 : clamp(at, lo - 20 + view / 2, hi + 20 - view / 2));
      tx = fit(hole.left, hole.right, VW, tx); ty = fit(hole.top, hole.bottom, VH * 0.75, ty);
    }
    const rate = G.mode === 'roll' ? 5 : 3.2;
    cam.x = lerp(cam.x, tx, 1 - Math.exp(-realDt * rate)); cam.y = lerp(cam.y, ty, 1 - Math.exp(-realDt * rate));
  }
  if (cam.shake > 0) { cam.shake = Math.max(0, cam.shake - realDt * 20); shakeX = Math.round(rand(-1, 1) * cam.shake); shakeY = Math.round(rand(-1, 1) * cam.shake); } else { shakeX = shakeY = 0; }
  updateParts(dt);
  if (G.mode === 'roll' && Math.floor(G.t * 4) !== Math.floor((G.t - realDt) * 4)) renderHud();
  if (hole && Math.random() < 0.15) addPart({ type: 'px', x: camX() + rand(0, VW), y: camY() + rand(VH * 0.3, VH), vx: rand(-6, 6), vy: rand(-14, -6), life: rand(2, 4), col: pick(['rgba(255,240,200,0.8)', 'rgba(255,190,220,0.8)']) });

  // draw
  drawSky(G.t);
  if (hole) { drawWorld(G.t); drawParts(true); drawFrontClouds(G.t); }
  drawParts(false);
  if (G.trans) {
    const tr = G.trans; tr.t += realDt / 0.42;
    if (!tr.done && tr.t >= 1) { tr.done = true; tr.cb(); }
    const k = tr.t < 1 ? tr.t : 2 - tr.t;
    if (tr.t >= 2) G.trans = null;
    else {
      const R = Math.max(VW, VH) * (1 - clamp(k, 0, 1)) * 0.8, cx = VW / 2, cy = VH / 2;
      g.fillStyle = '#110B30';
      for (let y = 0; y < VH; y += 2) {
        const dy = y - cy, half = R * R - dy * dy;
        if (half <= 0) { g.fillRect(0, y, VW, 2); continue; }
        const w = Math.sqrt(half); g.fillRect(0, y, Math.max(0, Math.round(cx - w)), 2); g.fillRect(Math.round(cx + w), y, VW, 2);
      }
    }
  }
  drawOverlay(realDt);
  requestAnimationFrame(frame);
}

// ============================================================ boot
new ResizeObserver(() => resize()).observe(wrap);
goTitle();
if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => renderHud());
requestAnimationFrame((t) => { last = t; frame(t); });
window.__estelar = { G, ball, get hole() { return hole; }, shoot, startIntro, beginPlay, defeat, showFinal, toggleOverview, ballCss: () => { const s = toScreen(ball.x, ball.y, ball.z), r = cv.getBoundingClientRect(); return { x: r.left + s.x / CSS_K, y: r.top + (s.y - 6) / CSS_K }; } };
})();
