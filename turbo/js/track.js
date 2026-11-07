// Pista de teste: spline fechada, malhas da pista, muros (colisão), rampas e boost pads.
import * as THREE from 'three';

export const ROAD_W = 22;          // largura do asfalto
export const HALF = ROAD_W / 2;
export const WALL = HALF + 1.6;    // distância do centro até o muro
export const LANES_FWD = [-2.75, -8.25];   // mão (lado direito de quem anda no sentido da pista)
export const LANES_ONC = [2.75, 8.25];     // contramão

// pontos de controle (x, z). Sentido da corrida: na ordem.
const CTRL = [
  [-70, 52], [-20, 60], [30, 58], [78, 50], [104, 24], [104, -12], [84, -40],
  [56, -46], [32, -28], [6, -18], [-18, -36], [-36, -62], [-74, -66], [-104, -40], [-108, 2], [-98, 34],
];

export class Track {
  constructor() {
    const curve = new THREE.CatmullRomCurve3(CTRL.map(([x, z]) => new THREE.Vector3(x, 0, z)), true, 'centripetal');
    this.length = curve.getLength();
    const n = Math.round(this.length / 2);
    this.ds = this.length / n;
    const pts = curve.getSpacedPoints(n).slice(0, n);
    this.n = n;
    this.px = new Float32Array(n); this.pz = new Float32Array(n);
    this.tx = new Float32Array(n); this.tz = new Float32Array(n);
    this.nx = new Float32Array(n); this.nz = new Float32Array(n);
    this.curv = new Float32Array(n);
    for (let i = 0; i < n; i++) { this.px[i] = pts[i].x; this.pz[i] = pts[i].z; }
    for (let i = 0; i < n; i++) {
      const a = (i - 1 + n) % n, b = (i + 1) % n;
      let tx = this.px[b] - this.px[a], tz = this.pz[b] - this.pz[a];
      const l = Math.hypot(tx, tz); tx /= l; tz /= l;
      this.tx[i] = tx; this.tz[i] = tz;
      this.nx[i] = tz; this.nz[i] = -tx;   // normal à esquerda do sentido da pista
    }
    for (let i = 0; i < n; i++) {
      const b = (i + 1) % n;
      const cross = this.tx[i] * this.tz[b] - this.tz[i] * this.tx[b];
      this.curv[i] = cross / this.ds;  // >0: curva para a direita (sentido horário visto de cima)
    }
    this.buildWalls();
    this.ramps = [];
    this.pads = [];
  }

  idx(i) { return ((i % this.n) + this.n) % this.n; }

  // ponto da pista na distância s, deslocado lateralmente (lat > 0 = esquerda)
  at(s, lat = 0) {
    const f = ((s / this.ds) % this.n + this.n) % this.n;
    const i = Math.floor(f), j = (i + 1) % this.n, t = f - i;
    const x = this.px[i] + (this.px[j] - this.px[i]) * t;
    const z = this.pz[i] + (this.pz[j] - this.pz[i]) * t;
    let tx = this.tx[i] + (this.tx[j] - this.tx[i]) * t, tz = this.tz[i] + (this.tz[j] - this.tz[i]) * t;
    const l = Math.hypot(tx, tz); tx /= l; tz /= l;
    return { x: x + tz * lat, z: z - tx * lat, tx, tz, heading: Math.atan2(tx, tz) };
  }

  // projeta (x,z) na pista. hint = índice anterior (busca local), -1 = busca completa
  project(x, z, hint = -1) {
    let best = 1e18, bi = 0;
    if (hint < 0) {
      for (let i = 0; i < this.n; i++) {
        const d = (x - this.px[i]) ** 2 + (z - this.pz[i]) ** 2;
        if (d < best) { best = d; bi = i; }
      }
    } else {
      for (let k = -24; k <= 24; k++) {
        const i = this.idx(hint + k);
        const d = (x - this.px[i]) ** 2 + (z - this.pz[i]) ** 2;
        if (d < best) { best = d; bi = i; }
      }
    }
    const dx = x - this.px[bi], dz = z - this.pz[bi];
    const along = dx * this.tx[bi] + dz * this.tz[bi];
    const lat = dx * this.nx[bi] + dz * this.nz[bi];
    let s = bi * this.ds + along;
    s = ((s % this.length) + this.length) % this.length;
    return { i: bi, s, lat };
  }

  buildWalls() {
    this.segs = [];
    for (const side of [1, -1]) {
      const off = WALL * side;
      for (let i = 0; i < this.n; i++) {
        const j = (i + 1) % this.n;
        this.addSeg(this.px[i] + this.nx[i] * off, this.pz[i] + this.nz[i] * off,
          this.px[j] + this.nx[j] * off, this.pz[j] + this.nz[j] * off, side);
      }
    }
    this.rebuildGrid();
  }

  addSeg(ax, az, bx, bz, side = 0, low = false) {
    this.segs.push({ ax, az, bx, bz, side, low });
  }

  rebuildGrid() {
    this.cell = 10;
    this.grid = new Map();
    this.segs.forEach((s, k) => {
      const x0 = Math.floor(Math.min(s.ax, s.bx) / this.cell), x1 = Math.floor(Math.max(s.ax, s.bx) / this.cell);
      const z0 = Math.floor(Math.min(s.az, s.bz) / this.cell), z1 = Math.floor(Math.max(s.az, s.bz) / this.cell);
      for (let gx = x0; gx <= x1; gx++) for (let gz = z0; gz <= z1; gz++) {
        const key = gx * 10007 + gz;
        if (!this.grid.has(key)) this.grid.set(key, []);
        this.grid.get(key).push(k);
      }
    });
  }

  segsNear(x, z, r, out) {
    out.length = 0;
    const x0 = Math.floor((x - r) / this.cell), x1 = Math.floor((x + r) / this.cell);
    const z0 = Math.floor((z - r) / this.cell), z1 = Math.floor((z + r) / this.cell);
    for (let gx = x0; gx <= x1; gx++) for (let gz = z0; gz <= z1; gz++) {
      const arr = this.grid.get(gx * 10007 + gz);
      if (arr) for (const k of arr) if (!out.includes(k)) out.push(k);
    }
    return out;
  }

  addRamp(s, lat) {
    const p = this.at(s, lat);
    const r = { x: p.x, z: p.z, tx: p.tx, tz: p.tz, nx: p.tz, nz: -p.tx, len: 6, wid: 7, h: 1.6, heading: p.heading };
    this.ramps.push(r);
    // a parede de trás da rampa é sólida para quem vem na contramão
    const bx = r.x + r.tx * 3, bz = r.z + r.tz * 3;
    this.addSeg(bx + r.nx * 3.5, bz + r.nz * 3.5, bx - r.nx * 3.5, bz - r.nz * 3.5, 0, true);
    return r;
  }

  addPad(s, lat) {
    const p = this.at(s, lat);
    const pad = { x: p.x, z: p.z, tx: p.tx, tz: p.tz, heading: p.heading, len: 6, wid: 4.6 };
    this.pads.push(pad);
    return pad;
  }

  // altura do chão (rampas) em (x,z)
  groundAt(x, z) {
    for (const r of this.ramps) {
      const dx = x - r.x, dz = z - r.z;
      const a = dx * r.tx + dz * r.tz, b = dx * r.nx + dz * r.nz;
      if (Math.abs(b) < r.wid / 2 && a > -r.len / 2 && a < r.len / 2) {
        return { h: r.h * (a + r.len / 2) / r.len, slope: r.h / r.len };
      }
    }
    return { h: 0, slope: 0 };
  }

  padAt(x, z) {
    for (const p of this.pads) {
      const dx = x - p.x, dz = z - p.z;
      const a = dx * p.tx + dz * p.tz, b = dx * p.tz - dz * p.tx;
      if (Math.abs(a) < p.len / 2 && Math.abs(b) < p.wid / 2) return p;
    }
    return null;
  }

  // ------------------------------------------------------------ malhas
  buildMeshes(scene, tex) {
    const g = new THREE.Group();
    // asfalto
    const pos = [], uv = [], idx = [];
    for (let i = 0; i <= this.n; i++) {
      const k = i % this.n;
      for (const side of [1, -1]) {
        pos.push(this.px[k] + this.nx[k] * HALF * side, 0, this.pz[k] + this.nz[k] * HALF * side);
        uv.push(side > 0 ? 0 : 1, (i * this.ds) / ROAD_W);
      }
      if (i < this.n) {
        const a = i * 2;
        idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
      }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    geo.setIndex(idx);
    geo.computeVertexNormals();
    const road = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ map: tex.road, roughness: 0.92 }));
    road.receiveShadow = true;
    road.position.y = 0.01;
    g.add(road);

    // zebras (curbs) e acostamento até o muro, com cores alternadas por vértice
    const cp = [], cc = [];
    const red = new THREE.Color('#e8432f'), white = new THREE.Color('#f7f2e8'), shoulder = new THREE.Color('#8f8a84');
    const quad = (k, j, in0, in1, y, col) => {
      const p = (i, o) => [this.px[i] + this.nx[i] * o, y, this.pz[i] + this.nz[i] * o];
      const a = p(k, in0), b = p(j, in0), c = p(j, in1), d = p(k, in1);
      cp.push(...a, ...c, ...b, ...a, ...d, ...c);
      for (let q = 0; q < 6; q++) cc.push(col.r, col.g, col.b);
    };
    for (let k = 0; k < this.n; k++) {
      const j = (k + 1) % this.n;
      const col = (k % 2) ? red : white;
      for (const side of [1, -1]) {
        // ordem dos vértices para a face ficar para cima nos dois lados
        if (side > 0) {
          quad(k, j, HALF + 1.1, HALF, 0.05, col);
          quad(k, j, WALL, HALF + 1.1, 0.02, shoulder);
        } else {
          quad(k, j, -HALF, -HALF - 1.1, 0.05, col);
          quad(k, j, -HALF - 1.1, -WALL, 0.02, shoulder);
        }
      }
    }
    const cgeo = new THREE.BufferGeometry();
    cgeo.setAttribute('position', new THREE.Float32BufferAttribute(cp, 3));
    cgeo.setAttribute('color', new THREE.Float32BufferAttribute(cc, 3));
    cgeo.computeVertexNormals();
    const curbs = new THREE.Mesh(cgeo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.8 }));
    curbs.receiveShadow = true;
    g.add(curbs);

    // muros: faixa vertical com topo, listrada (pneus/concreto)
    const wp = [], wc = [];
    const wallCol = [new THREE.Color('#f5f1ea'), new THREE.Color('#2e6fe0')];
    const H = 1.1;
    for (let k = 0; k < this.n; k++) {
      const j = (k + 1) % this.n;
      const col = wallCol[Math.floor(k / 2) % 2];
      for (const side of [1, -1]) {
        const o = WALL * side, o2 = (WALL + 0.6) * side;
        const P = (i, off, y) => [this.px[i] + this.nx[i] * off, y, this.pz[i] + this.nz[i] * off];
        const face = (a, b, c, d) => {
          if (side < 0) { wp.push(...a, ...c, ...b, ...a, ...d, ...c); } else { wp.push(...a, ...b, ...c, ...a, ...c, ...d); }
          for (let q = 0; q < 6; q++) wc.push(col.r, col.g, col.b);
        };
        face(P(k, o, 0), P(k, o, H), P(j, o, H), P(j, o, 0));                  // face interna
        face(P(k, o, H), P(k, o2, H), P(j, o2, H), P(j, o, H));                // topo
      }
    }
    const wgeo = new THREE.BufferGeometry();
    wgeo.setAttribute('position', new THREE.Float32BufferAttribute(wp, 3));
    wgeo.setAttribute('color', new THREE.Float32BufferAttribute(wc, 3));
    wgeo.computeVertexNormals();
    const walls = new THREE.Mesh(wgeo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.6, side: THREE.DoubleSide }));
    walls.castShadow = true; walls.receiveShadow = true;
    g.add(walls);

    // linha de chegada xadrez
    const start = this.at(0);
    const fin = new THREE.Mesh(new THREE.PlaneGeometry(ROAD_W, 3), new THREE.MeshStandardMaterial({ map: tex.checker, roughness: 0.8 }));
    fin.rotation.x = -Math.PI / 2;
    const finG = new THREE.Group();
    finG.add(fin);
    finG.position.set(start.x, 0.04, start.z);
    finG.rotation.y = start.heading;
    fin.receiveShadow = true;
    g.add(finG);

    scene.add(g);
    return g;
  }
}

// ---------------------------------------------------------------- texturas procedurais (canvas)
export function makeTextures(renderer) {
  const aniso = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  const mk = (w, h, draw, repeat = true) => {
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    draw(c.getContext('2d'), w, h);
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = aniso;
    if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
    return t;
  };
  const noise = (ctx, w, h, base, amp, n = 9000, size = 2) => {
    ctx.fillStyle = base; ctx.fillRect(0, 0, w, h);
    for (let i = 0; i < n; i++) {
      const v = (Math.random() - 0.5) * amp;
      ctx.fillStyle = v > 0 ? `rgba(255,255,255,${v})` : `rgba(0,0,0,${-v})`;
      ctx.fillRect(Math.random() * w, Math.random() * h, size, size);
    }
  };
  const road = mk(512, 512, (ctx, w, h) => {
    noise(ctx, w, h, '#4a4c55', 0.16, 26000, 2);
    // manchas
    for (let i = 0; i < 18; i++) {
      ctx.fillStyle = `rgba(0,0,0,${0.04 + Math.random() * 0.05})`;
      ctx.beginPath(); ctx.ellipse(Math.random() * w, Math.random() * h, 20 + Math.random() * 50, 10 + Math.random() * 30, Math.random() * 3, 0, 7); ctx.fill();
    }
    const px = (m) => (m / ROAD_W) * w; // metros -> px na largura
    // bordas brancas
    ctx.fillStyle = '#efece4';
    ctx.fillRect(px(0.5), 0, px(0.35), h);
    ctx.fillRect(w - px(0.85), 0, px(0.35), h);
    // linha dupla amarela central
    ctx.fillStyle = '#ffc531';
    ctx.fillRect(w / 2 - px(0.42), 0, px(0.22), h);
    ctx.fillRect(w / 2 + px(0.2), 0, px(0.22), h);
    // faixas tracejadas
    ctx.fillStyle = '#efece4';
    for (const m of [5.5, ROAD_W - 5.5]) {
      for (let y = 0; y < h; y += h / 2) ctx.fillRect(px(m) - px(0.12), y, px(0.24), h * 0.26);
    }
  });
  const grass = mk(256, 256, (ctx, w, h) => {
    noise(ctx, w, h, '#78c25a', 0.12, 9000, 3);
    for (let i = 0; i < 300; i++) {
      ctx.fillStyle = Math.random() < 0.5 ? 'rgba(40,120,40,0.25)' : 'rgba(200,240,140,0.22)';
      ctx.fillRect(Math.random() * w, Math.random() * h, 2, 5);
    }
  });
  const checker = mk(256, 32, (ctx, w, h) => {
    const s = 16;
    for (let x = 0; x < w / s; x++) for (let y = 0; y < h / s; y++) {
      ctx.fillStyle = (x + y) % 2 ? '#1b1b20' : '#f4f4f4';
      ctx.fillRect(x * s, y * s, s, s);
    }
  }, false);
  const pad = mk(128, 128, (ctx, w, h) => {
    ctx.fillStyle = '#16c8ff'; ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = '#eaffff'; ctx.lineWidth = 14; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    for (let k = 0; k < 2; k++) {
      const y = 20 + k * 64;
      ctx.beginPath(); ctx.moveTo(22, y + 36); ctx.lineTo(64, y); ctx.lineTo(106, y + 36); ctx.stroke();
    }
  });
  return { road, grass, checker, pad };
}
