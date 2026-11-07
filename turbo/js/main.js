// Mini Fúria: corrida isométrica de mini carros com batidas, takedowns e turbo.
import * as THREE from 'three';
import { GLTFLoader } from '../../vendor/jsm/loaders/GLTFLoader.js';
import { Track, makeTextures, WALL, LANES_FWD, LANES_ONC, ROAD_W } from './track.js';
import { Car, wrap } from './car.js';
import { Particles, Ribbons, Debris, Shake, makePost, COL, burstSparks, puff, explosion } from './fx.js';
import { Sfx } from './audio.js';
import { Input } from './input.js';

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const rand = (a, b) => a + Math.random() * (b - a);
const pick = (a) => a[Math.floor(Math.random() * a.length)];
const LAPS = 3;
const $ = (id) => document.getElementById(id);

// ---------------------------------------------------------------- renderer / cena
const canvas = $('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
let pixelRatio = Math.min(devicePixelRatio || 1, 2);
renderer.setPixelRatio(pixelRatio);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
scene.background = new THREE.Color('#a9d8ff');
scene.fog = new THREE.Fog('#a9d8ff', 160, 300);

const camera = new THREE.OrthographicCamera(-20, 20, 20, -20, 1, 600);
const CAM_YAW = Math.PI / 4, CAM_PITCH = 0.62, CAM_DIST = 150;
const camOff = new THREE.Vector3(Math.sin(CAM_YAW) * Math.cos(CAM_PITCH), Math.sin(CAM_PITCH), Math.cos(CAM_YAW) * Math.cos(CAM_PITCH)).multiplyScalar(CAM_DIST);

const hemi = new THREE.HemisphereLight('#d6ecff', '#6f9d5a', 1.25);
scene.add(hemi);
const sun = new THREE.DirectionalLight('#fff0d4', 2.6);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
const SH = 48;
Object.assign(sun.shadow.camera, { left: -SH, right: SH, top: SH, bottom: -SH, near: 1, far: 220 });
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.03;
scene.add(sun, sun.target);

let W = 1, H = 1, viewH = 36;
const post = makePost(renderer, scene, camera, 512, 512);
function resize() {
  W = innerWidth; H = innerHeight;
  renderer.setSize(W, H, false);
  post.composer.setPixelRatio(pixelRatio);
  post.composer.setSize(W, H);
}
addEventListener('resize', resize);
resize();

// ---------------------------------------------------------------- sistemas
const sfx = new Sfx();
const input = new Input();
const track = new Track();
const tex = makeTextures(renderer);
const P = {
  add: new Particles(scene, 2500, true),
  smoke: new Particles(scene, 2500, false),
};
const skids = new Ribbons(scene, 2400, { color: '#1a1a1e', life: 14 });
const trails = new Ribbons(scene, 700, { color: '#ff4060', life: 0.45, additive: true, vertical: true });
const streaks = new Ribbons(scene, 200, { color: '#ffffff', life: 0.22, additive: true });
const debris = new Debris(scene);
const shake = new Shake();

// ---------------------------------------------------------------- estado
const G = {
  mode: 'loading', time: 0, real: 0,
  timeScale: 1, tsTarget: 1, slowT: 0, hitstop: 0,
  cars: [], traffic: [], rivals: [], player: null, props: [],
  camPos: new THREE.Vector3(), camFocus: null, zoomKick: 0, focusT: 0,
  raceT: 0, countdown: 0, lapStart: 0, bestLap: Infinity,
  stats: null, finishT: 0,
};
window.__game = G;

// ---------------------------------------------------------------- carregamento
const loader = new GLTFLoader();
loader.load('assets/minicars.glb', (gltf) => {
  G.assets = gltf.scene;
  buildWorld();
  newRace();
  G.mode = 'menu';
  $('loading').classList.add('hide');
  $('menu').classList.remove('hide');
}, (ev) => {
  if (ev.total) $('loadBar').style.width = (ev.loaded / ev.total * 100).toFixed(0) + '%';
}, (err) => {
  console.error(err);
  $('loadMsg').textContent = 'Erro ao carregar os modelos. Rode por um servidor (não file://).';
});

function asset(name) {
  const o = G.assets.getObjectByName(name).clone(true);
  o.position.set(0, 0, 0);
  o.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
  return o;
}

// gerador determinístico para o cenário
let seed = 1337;
const srand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

function buildWorld() {
  // chão
  tex.grass.repeat.set(120, 120);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(900, 900), new THREE.MeshStandardMaterial({ map: tex.grass, roughness: 1 }));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);

  // rampas e boost pads
  track.addRamp(96, -5.5);
  track.addRamp(476, 5.5);
  track.addPad(200, -5.5);
  track.addPad(330, 5.5);
  track.addPad(540, -5.5);
  track.addPad(30, -2.75);
  track.rebuildGrid();
  track.buildMeshes(scene, tex);

  for (const r of track.ramps) {
    const m = asset('prop_ramp');
    m.position.set(r.x, 0.02, r.z);
    m.rotation.y = Math.atan2(-r.tx, -r.tz);
    scene.add(m);
  }
  G.padMeshes = [];
  for (const p of track.pads) {
    const g = new THREE.Group();
    const t = tex.pad.clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(1, 1.5);
    const m = new THREE.Mesh(new THREE.PlaneGeometry(p.wid, p.len), new THREE.MeshBasicMaterial({ map: t, color: new THREE.Color(1.6, 1.6, 1.6) }));
    m.rotation.x = -Math.PI / 2;
    g.add(m);
    g.position.set(p.x, 0.06, p.z);
    g.rotation.y = p.heading + Math.PI;
    scene.add(g);
    G.padMeshes.push(t);
  }

  // portal de largada e arquibancada
  const s0 = track.at(0);
  const gate = asset('prop_gate');
  gate.position.set(s0.x, 0, s0.z); gate.rotation.y = s0.heading;
  scene.add(gate);
  for (const [s, lat] of [[18, -(WALL + 4)], [44, -(WALL + 4)], [-20, WALL + 4]]) {
    const p = track.at(s, lat);
    const st = asset('prop_stand');
    st.position.set(p.x, 0, p.z);
    const toTrack = lat < 0 ? 1 : -1;
    st.rotation.y = Math.atan2(p.tz * toTrack, -p.tx * toTrack);
    scene.add(st);
  }
  // postes de luz
  for (let s = 0; s < track.length; s += 34) {
    for (const side of [1, -1]) {
      if ((s / 34 + (side > 0 ? 0 : 1)) % 2) continue;
      const p = track.at(s, side * (WALL + 1.3));
      const l = asset('prop_lamp');
      l.position.set(p.x, 0, p.z);
      l.rotation.y = Math.atan2(-side * p.tz, side * p.tx);
      scene.add(l);
    }
  }
  // árvores, pedras, prédios fora da pista
  const placeOk = (x, z, clear) => {
    const pr = track.project(x, z);
    return Math.abs(pr.lat) > WALL + clear;
  };
  const deco = ['prop_tree', 'prop_tree', 'prop_pine', 'prop_pine', 'prop_rock'];
  let placed = 0;
  for (let i = 0; i < 900 && placed < 260; i++) {
    const x = (srand() - 0.5) * 330, z = (srand() - 0.5) * 260;
    if (!placeOk(x, z, 3.5)) continue;
    const m = asset(deco[Math.floor(srand() * deco.length)]);
    m.position.set(x, 0, z);
    m.rotation.y = srand() * 6.28;
    m.scale.setScalar(0.8 + srand() * 0.7);
    scene.add(m);
    placed++;
  }
  placed = 0;
  for (let i = 0; i < 400 && placed < 26; i++) {
    const x = (srand() - 0.5) * 360, z = (srand() - 0.5) * 300;
    const inside = Math.abs(x) < 70 && Math.abs(z) < 30;
    if (!placeOk(x, z, 12) || inside) continue;
    const m = asset(pick(['prop_bldgA', 'prop_bldgB', 'prop_bldgC']));
    m.position.set(x, 0, z);
    m.rotation.y = Math.round(srand() * 4) * Math.PI / 2;
    scene.add(m);
    placed++;
  }

  // props destrutíveis na pista
  const addProp = (name, s, lat, opts = {}) => {
    const p = track.at(s, lat);
    const m = asset(name);
    m.position.set(p.x, 0, p.z);
    m.rotation.y = p.heading + (opts.rot || 0);
    scene.add(m);
    G.props.push({
      mesh: m, name, x: p.x, y: 0, z: p.z, vx: 0, vy: 0, vz: 0, ax: 0, ay: 0, az: 0,
      r: opts.r || 0.5, mass: opts.mass || 0.1, home: { x: p.x, z: p.z, h: m.rotation.y }, hit: false, t: 0,
    });
  };
  // cones em zigue-zague no começo e na chicane
  for (let i = 0; i < 7; i++) addProp('prop_cone', 60 + i * 5, -2.75 + (i % 2 ? 3 : -3), { r: 0.35, mass: 0.05 });
  for (let i = 0; i < 10; i++) addProp('prop_cone', 300 + i * 4, -9 + i * 2, { r: 0.35, mass: 0.05 });
  // barris nas curvas fechadas (lado de fora)
  for (const [s, lat] of [[287, 10], [290, 9], [293, 10.5], [347, -10], [350, -9.5], [408, 10], [411, 9.5], [414, 10.3]]) addProp('prop_barrel', s, lat, { r: 0.5, mass: 0.25 });
  // caixotes depois das rampas
  for (let i = 0; i < 6; i++) addProp('prop_crate', 130 + (i % 3) * 1.3, -5.5 + Math.floor(i / 3) * 1.3 - 0.6, { r: 0.6, mass: 0.3 });
  for (let i = 0; i < 6; i++) addProp('prop_crate', 508 - (i % 3) * 1.3, 5.5 + Math.floor(i / 3) * 1.3 - 0.6, { r: 0.6, mass: 0.3 });
  // pneus empilhados
  for (const [s, lat] of [[150, 10.6], [152, 10.6], [250, -10.6], [252, -10.6], [440, 10.6], [560, -10.6]]) addProp('prop_tires', s, lat, { r: 0.55, mass: 0.3 });

  // minimapa
  buildMinimap();
}

// ---------------------------------------------------------------- corrida
const RIVALS = [
  { kind: 'trovao', color: '#2f6fd6', name: 'Trovão' },
  { kind: 'vespa', color: '#ffb31a', name: 'Vespa' },
  { kind: 'trovao', color: '#8a5cd6', name: 'Corisco' },
];
const TRAFFIC = [
  ['sedan', ['#5cc26b', '#f08a7a', '#7fc8d9', '#e6e1d6', '#9a7cf0']],
  ['taxi', ['#ffcf33']],
  ['policia', ['#f4f4f4']],
  ['picape', ['#8a5cd6', '#e2553b', '#3d8bd6']],
  ['van', ['#f08a7a', '#ffd23a', '#7fc8d9']],
];

function clearCars() {
  for (const c of G.cars) scene.remove(c.group);
  G.cars = []; G.traffic = []; G.rivals = [];
}

function placeCar(c, s, lat) {
  const p = track.at(s, lat);
  const heading = c.oncoming ? p.heading + Math.PI : p.heading;
  c.reset(p.x, p.z, heading, c.role === 'traffic' ? c.cruise : 0);
  const pr = track.project(p.x, p.z);
  c.ti = pr.i; c.s = pr.s; c.lat = pr.lat;
  c.lane = lat; c.laneT = lat; c.laneCur = lat;
}

function newRace() {
  clearCars();
  const L = track.length;
  const grid = [[-9, -2.75], [-9, -8.25], [-18, -2.75], [-18, -8.25]];
  RIVALS.forEach((r, i) => {
    const c = new Car(G.assets, r.kind, 'rival', r.color);
    c.name = r.name; c.seed = i * 2.1 + 0.5; c.cruise = 39 + i * 0.7; c.rubber = 1; c.nextBash = 6 + i * 3;
    placeCar(c, L + grid[i][0], grid[i][1]);
    G.rivals.push(c); G.cars.push(c); scene.add(c.group);
  });
  const p = new Car(G.assets, 'faisca', 'player', '#e8352b');
  p.name = 'Você';
  placeCar(p, L + grid[3][0], grid[3][1]);
  G.player = p; G.cars.push(p); scene.add(p.group);
  hookPlayer(p);
  // tráfego espalhado pela pista, nos dois sentidos
  for (let i = 0; i < 16; i++) {
    const [kind, cols] = TRAFFIC[i % TRAFFIC.length];
    const c = new Car(G.assets, kind, 'traffic', pick(cols));
    c.oncoming = i % 5 === 1 || i % 5 === 3;
    c.cruise = c.oncoming ? rand(15, 20) : rand(13, 19);
    const s = 50 + (i / 16) * (L - 90) + rand(-8, 8);
    placeCar(c, s, pick(c.oncoming ? LANES_ONC : LANES_FWD));
    G.traffic.push(c); G.cars.push(c); scene.add(c.group);
  }
  for (const c of G.cars) {
    const pr = track.project(c.x, c.z);
    c.dist = pr.s > L / 2 ? pr.s - L : pr.s;
    c.prevS = pr.s; c.lap = 0; c.finished = false;
  }
  // props de volta para casa
  for (const pr of G.props) resetProp(pr);
  G.stats = { takedowns: 0, nearMiss: 0, bestDrift: 0, oncoming: 0, air: 0, crashes: 0, smash: 0, score: 0 };
  G.raceT = 0; G.lapStart = 0; G.bestLap = Infinity; G.lapTimes = [];
  G.timeScale = G.tsTarget = 1; G.slowT = 0; G.hitstop = 0; G.camFocus = null; G.crash = null;
  G.finishT = 0; G.place = 4;
  G.camPos.set(p.x, 0, p.z);
  for (const c of G.cars) c.updateVisual(0, 0);
  $('results').classList.add('hide');
}

function hookPlayer(p) {
  p.onDriftStart = () => { sfx.noiseHit(0.2, 2000, 800, 0.15, 'bandpass', 3); };
  p.onDriftEnd = (t) => {
    if (t > 0.8) {
      const pts = Math.round(t * 120);
      popup(`DRIFT ${t.toFixed(1)}s`, 'drift', `+${pts}`);
      G.stats.score += pts;
      G.stats.bestDrift = Math.max(G.stats.bestDrift, t);
      addBoost(Math.min(0.15, t * 0.04));
    }
  };
  p.onTakeoff = () => { G.zoomKick += 3; };
  p.onLand = (air, impact) => {
    shake.add(Math.min(0.45, impact * 0.025));
    sfx.land(impact);
    for (const w of p.wheels) {
      const v = p.local(w.x, 0.1, w.z, _v);
      puff(P.smoke, v.x, 0.2, v.z, 4, COL.dust, 1.3, 4, 0.9, 1.5);
    }
    if (air > 0.5) {
      popup(`PULÃO ${air.toFixed(1)}s`, 'air', `+${Math.round(air * 150)}`);
      G.stats.score += Math.round(air * 150);
      G.stats.air = Math.max(G.stats.air, air);
      addBoost(0.12);
    }
    G.hitstop = Math.max(G.hitstop, 0.04);
  };
}

function addBoost(a) {
  const p = G.player;
  const was = p.boost;
  p.boost = Math.min(1, p.boost + a);
  if (was < 1 && p.boost >= 1) { popup('TURBO CHEIO!', 'boost'); sfx.combo(6); }
  $('boostBar').classList.remove('gain'); void $('boostBar').offsetWidth; $('boostBar').classList.add('gain');
}

// ---------------------------------------------------------------- props
function resetProp(pr) {
  pr.x = pr.home.x; pr.z = pr.home.z; pr.y = 0; pr.vx = pr.vy = pr.vz = 0; pr.hit = false; pr.t = 0;
  pr.mesh.position.set(pr.x, 0, pr.z);
  pr.mesh.rotation.set(0, pr.home.h, 0);
  pr.mesh.scale.setScalar(1);
  pr.mesh.visible = true;
}

function stepProps(dt) {
  for (const pr of G.props) {
    if (pr.hit) {
      pr.t += dt;
      pr.vy -= 26 * dt;
      pr.x += pr.vx * dt; pr.y += pr.vy * dt; pr.z += pr.vz * dt;
      if (pr.y < 0) {
        pr.y = 0;
        if (pr.vy < -4) { puff(P.smoke, pr.x, 0.2, pr.z, 2, COL.dust, 1, 2, 0.6, 1); }
        pr.vy = -pr.vy * 0.3; pr.vx *= 0.75; pr.vz *= 0.75; pr.ax *= 0.7; pr.az *= 0.7; pr.ay *= 0.7;
      }
      if (pr.y < 0.05) { const f = Math.exp(-3 * dt); pr.vx *= f; pr.vz *= f; pr.ax *= f; pr.ay *= f; pr.az *= f; }
      const m = pr.mesh;
      m.position.set(pr.x, pr.y, pr.z);
      m.rotation.x += pr.ax * dt; m.rotation.y += pr.ay * dt; m.rotation.z += pr.az * dt;
      // some e volta depois de um tempo, longe do jogador
      if (pr.t > 9) {
        const s = Math.max(0, 1 - (pr.t - 9));
        m.scale.setScalar(Math.max(0.001, s));
        const p = G.player;
        if (s <= 0 && Math.hypot(p.x - pr.home.x, p.z - pr.home.z) > 70) resetProp(pr);
      }
      continue;
    }
    for (const c of G.cars) {
      if (c.y > 1.2) continue;
      const dx = pr.x - c.x, dz = pr.z - c.z;
      if (dx * dx + dz * dz > (c.len / 2 + 1.2) ** 2) continue;
      for (let i = 0; i < 3; i++) {
        const [cx, cz] = c.circle(i);
        const ex = pr.x - cx, ez = pr.z - cz, d = Math.hypot(ex, ez);
        if (d < c.r + pr.r) {
          const sp = Math.hypot(c.vx, c.vz);
          const nx = ex / (d || 1), nz = ez / (d || 1);
          pr.hit = true; pr.t = 0;
          pr.vx = c.vx * 1.15 + nx * (3 + sp * 0.25); pr.vz = c.vz * 1.15 + nz * (3 + sp * 0.25);
          pr.vy = 4 + sp * 0.32 + rand(0, 3);
          pr.ax = rand(-12, 12); pr.ay = rand(-8, 8); pr.az = rand(-12, 12);
          const slow = 1 - pr.mass * 0.15;
          c.vx *= slow; c.vz *= slow;
          if (c === G.player) {
            sfx.smash();
            shake.add(0.12 + pr.mass * 0.4);
            G.stats.smash++; G.stats.score += 25;
            addBoost(0.02);
            if (pr.name !== 'prop_cone') G.hitstop = Math.max(G.hitstop, 0.03);
            if (G.stats.smash % 5 === 0) popup('DESTRUIÇÃO!', 'smash', `x${G.stats.smash}`);
          }
          burstSparks(P.add, pr.x, 0.6, pr.z, nx, nz, 0.3, pr.name === 'prop_cone' ? 4 : 10);
          puff(P.smoke, pr.x, 0.4, pr.z, 3, pr.name === 'prop_crate' ? COL.dust : COL.smoke, 1.2, 3, 0.7, 2);
          break;
        }
      }
      if (pr.hit) break;
    }
  }
}

// ---------------------------------------------------------------- colisões
const _segs = [];
const events = [];
function collideWalls(car) {
  const r = car.r * 0.98;
  for (let i = 0; i < 3; i++) {
    const [cx0, cz0] = car.circle(i);
    track.segsNear(cx0, cz0, r + 0.6, _segs);
    for (const k of _segs) {
      const s = track.segs[k];
      if (s.low && car.y > 0.8) continue;
      const [cx, cz] = car.circle(i);
      const ex = s.bx - s.ax, ez = s.bz - s.az;
      const t = clamp(((cx - s.ax) * ex + (cz - s.az) * ez) / (ex * ex + ez * ez), 0, 1);
      const qx = s.ax + ex * t, qz = s.az + ez * t;
      const dx = cx - qx, dz = cz - qz, d2 = dx * dx + dz * dz;
      if (d2 >= r * r) continue;
      const d = Math.sqrt(d2) || 1e-4;
      const nx = dx / d, nz = dz / d, pen = r - d;
      car.x += nx * pen; car.z += nz * pen;
      const [vpx, vpz] = car.pointVel(qx, qz);
      const vn = vpx * nx + vpz * nz;
      if (vn < 0) {
        const rx = qx - car.x, rz = qz - car.z;
        const cr = rz * nx - rx * nz;
        const kk = 1 / car.mass + (cr * cr) / car.inertia;
        const j = (-(1 + 0.3) * vn) / kk;
        car.impulse(qx, qz, nx, nz, j);
        let tx = vpx - nx * vn, tz = vpz - nz * vn;
        const vt = Math.hypot(tx, tz);
        if (vt > 0.01) {
          tx /= vt; tz /= vt;
          const crt = rz * tx - rx * tz;
          const kt = 1 / car.mass + (crt * crt) / car.inertia;
          car.impulse(qx, qz, -tx, -tz, Math.min(vt / kt, 0.22 * j));
        }
        events.push({ type: 'wall', car, vn: -vn, vt, nx, nz, x: qx, z: qz });
      }
    }
  }
}

function collideCars(a, b) {
  if (Math.abs(a.y - b.y) > 1.6) return;
  const dx = a.x - b.x, dz = a.z - b.z, R = (a.len + b.len) / 2 + 0.5;
  if (dx * dx + dz * dz > R * R) return;
  let best = null;
  for (let i = 0; i < 3; i++) {
    const [ax, az] = a.circle(i);
    for (let j = 0; j < 3; j++) {
      const [bx, bz] = b.circle(j);
      const ex = ax - bx, ez = az - bz, rr = a.r + b.r, d2 = ex * ex + ez * ez;
      if (d2 < rr * rr) {
        const d = Math.sqrt(d2) || 1e-4, pen = rr - d;
        if (!best || pen > best.pen) best = { pen, nx: ex / d, nz: ez / d, px: (ax + bx) / 2, pz: (az + bz) / 2 };
      }
    }
  }
  if (!best) return;
  const { pen, nx, nz, px, pz } = best;
  const ima = 1 / a.mass, imb = 1 / b.mass, im = ima + imb;
  a.x += nx * pen * ima / im; a.z += nz * pen * ima / im;
  b.x -= nx * pen * imb / im; b.z -= nz * pen * imb / im;
  const [vax, vaz] = a.pointVel(px, pz), [vbx, vbz] = b.pointVel(px, pz);
  const vn = (vax - vbx) * nx + (vaz - vbz) * nz;
  if (vn >= 0) return;
  const rax = px - a.x, raz = pz - a.z, rbx = px - b.x, rbz = pz - b.z;
  const cra = raz * nx - rax * nz, crb = rbz * nx - rbx * nz;
  const k = ima + imb + (cra * cra) / a.inertia + (crb * crb) / b.inertia;
  const j = (-(1 + 0.35) * vn) / k;
  a.impulse(px, pz, nx, nz, j);
  b.impulse(px, pz, -nx, -nz, j);
  events.push({ type: 'car', a, b, vn: -vn, nx, nz, x: px, z: pz });
}

// ---------------------------------------------------------------- eventos de batida
const _v = new THREE.Vector3();
let scrapeT = 0;
function frontness(car, nx, nz) { return -(nx * Math.sin(car.h) + nz * Math.cos(car.h)); }

function handleEvents() {
  for (const e of events) {
    if (e.type === 'wall') onWall(e); else onCar(e);
  }
  events.length = 0;
}

function onWall(e) {
  const c = e.car;
  if (c.wrecked) {
    if (e.vn > 4) burstSparks(P.add, e.x, 0.5, e.z, e.nx, e.nz, 0.5, 8);
    return;
  }
  const front = frontness(c, e.nx, e.nz);
  if (c.role === 'player') {
    if (G.mode !== 'race') return;
    if (e.vn > 21 && front > 0.55 && c.invuln <= 0) { crashPlayer(e.vn, e.nx, e.nz, e.x, e.z); return; }
    if (e.vn > 5) {
      shake.add(Math.min(0.55, e.vn * 0.025));
      burstSparks(P.add, e.x, 0.5, e.z, e.nx, e.nz, Math.min(1, e.vn / 20), 12);
      sfx.bump(e.vn);
      if (e.vn > 11) { c.stun = 0.25; G.hitstop = Math.max(G.hitstop, 0.05); flash(1, 1, 1, 0.12); }
    }
    if (e.vt > 9 && G.real > scrapeT) {
      scrapeT = G.real + 0.03;
      burstSparks(P.add, e.x, 0.45, e.z, e.nx * 0.3 - c.vx * 0.04, e.nz * 0.3 - c.vz * 0.04, 0.2, 3);
      sfx.scrape(e.vt);
      shake.add(0.02);
    }
  } else if (c.role === 'rival') {
    if (e.vn > 12 && G.time - c.lastHitT < 1.6 && c.lastHitBy === G.player) takedown(c, e.vn, e.nx, e.nz);
    else if (e.vn > 27 && front > 0.6) wreckCar(c, e.vn, e.nx, e.nz, false);
  } else if (e.vn > 15) {
    if (G.time - c.lastHitT < 1.6 && c.lastHitBy === G.player) trafficCheck(c, e.vn, e.nx, e.nz);
    else wreckCar(c, e.vn, e.nx, e.nz, false);
  }
}

function onCar(e) {
  const { a, b } = e;
  const p = a.role === 'player' ? a : b.role === 'player' ? b : null;
  if (p) {
    const o = p === a ? b : a;
    const nx = p === a ? e.nx : -e.nx, nz = p === a ? e.nz : -e.nz;   // normal apontando para o jogador
    o.lastHitBy = p; o.lastHitT = G.time;
    if (G.mode !== 'race') return;
    burstSparks(P.add, e.x, 0.6, e.z, nx, nz, Math.min(1, e.vn / 15), 10 + Math.floor(e.vn));
    if (o.wrecked) { shake.add(0.1); sfx.bump(e.vn); return; }
    const front = frontness(p, nx, nz);
    if (o.role === 'traffic' && p.invuln <= 0 && front > 0.6 && (e.vn > 27 || (e.vn > 20 && o.oncoming))) {
      crashPlayer(e.vn, nx, nz, e.x, e.z);
      wreckCar(o, e.vn, -nx, -nz, false);
      return;
    }
    if (o.role === 'rival' && e.vn > 12.5 && o.invuln <= 0) { takedown(o, e.vn, -nx, -nz); return; }
    if (o.role === 'traffic' && e.vn > 13) { trafficCheck(o, e.vn, -nx, -nz); return; }
    // encostou: troca de tinta
    shake.add(Math.min(0.4, 0.06 + e.vn * 0.02));
    sfx.bump(e.vn);
    if (e.vn > 4 && o.role === 'rival') { addBoost(0.04); popup('ENCOSTOU!', 'bump'); }
    if (e.vn > 6) G.hitstop = Math.max(G.hitstop, 0.035);
  } else {
    for (const [c, o, s] of [[a, b, 1], [b, a, -1]]) {
      if (c.wrecked) continue;
      if (c.role === 'rival' && G.time - c.lastHitT < 1.6 && c.lastHitBy === G.player && e.vn > 10) { takedown(c, e.vn, e.nx * s, e.nz * s); continue; }
      if (e.vn > 22 && c.mass <= o.mass) wreckCar(c, e.vn, e.nx * s, e.nz * s, false);
    }
    if (e.vn > 6 && onScreen(e.x, e.z)) burstSparks(P.add, e.x, 0.6, e.z, e.nx, e.nz, 0.4, 8);
  }
}

function onScreen(x, z) {
  const p = G.camPos;
  return Math.hypot(x - p.x, z - p.z) < viewH * 1.2;
}

function wreckCar(c, power, nx, nz, big) {
  if (c.wrecked) return;
  c.wreck(power, nx, nz);
  const vis = onScreen(c.x, c.z);
  if (vis) {
    explosion(P.add, P.smoke, c.x, c.y, c.z, big ? 1.2 : 0.7);
    spawnDebris(c, big ? 10 : 6);
    shake.add(big ? 0.9 : 0.35);
    sfx.crash(big ? 1 : 0.5);
  }
}

function spawnDebris(c, n) {
  const sp = Math.hypot(c.vx, c.vz);
  for (let i = 0; i < n; i++) {
    const kind = i % 3 === 0 ? 'debris_glass' : i % 3 === 1 ? 'debris_panel' : 'debris_bolt';
    const m = asset(kind);
    if (kind === 'debris_panel') m.traverse((o) => { if (o.isMesh) o.material = c.paint || o.material; });
    debris.add(m, c.x + rand(-1, 1), c.y + 1, c.z + rand(-1, 1),
      c.vx * 0.7 + rand(-6, 6), rand(5, 12), c.vz * 0.7 + rand(-6, 6), 14, rand(2.5, 4.5));
  }
  // solta uma roda!
  const w = pick(c.wheels);
  if (w && w.mesh.visible && sp > 8) {
    w.mesh.visible = false;
    const m = w.mesh.clone(true); m.visible = true; m.scale.setScalar(1);
    const v = c.local(w.x, 0.5, w.z, _v);
    debris.add(m, v.x, v.y + 0.5, v.z, c.vx * 0.8 + rand(-5, 5), rand(7, 12), c.vz * 0.8 + rand(-5, 5), 18, 4);
  }
}

function takedown(c, power, nx, nz) {
  if (c.wrecked) return;
  wreckCar(c, Math.max(power, 22), nx, nz, true);
  G.stats.takedowns++;
  G.stats.score += 1000;
  const p = G.player;
  p.boost = 1;
  bigText('TAKEDOWN!', 'takedown');
  popup(c.name, 'takedown-sub', '+1000');
  sfx.takedown();
  flash(1, 0.9, 0.6, 0.45);
  G.hitstop = 0.09;
  slowmo(0.28, 1.0);
  G.camFocus = c; G.focusT = 1.0;
  G.zoomKick -= 8;
  if (navigator.vibrate) navigator.vibrate([30, 40, 60]);
}

function trafficCheck(c, power, nx, nz) {
  wreckCar(c, power, nx, nz, false);
  G.stats.score += 150;
  popup('TRÂNSITO!', 'traffic', '+150');
  addBoost(0.08);
  G.hitstop = Math.max(G.hitstop, 0.05);
}

function crashPlayer(power, nx, nz, x, z) {
  const p = G.player;
  if (p.wrecked) return;
  p.boost = Math.max(0, p.boost - 0.25);
  wreckCar(p, Math.max(power, 26), nx, nz, true);
  G.stats.crashes++;
  bigText('BATIDA!', 'crash');
  flash(1, 1, 1, 0.7);
  G.hitstop = 0.12;
  slowmo(0.25, 1.6);
  G.crash = { t: 0 };
  G.zoomKick -= 12;
  if (navigator.vibrate) navigator.vibrate([60, 30, 120]);
}

function respawnPlayer() {
  const p = G.player;
  const pr = track.project(p.x, p.z, p.ti ?? -1);
  const s = pr.s - 4;
  const lat = pr.lat > 0 ? 2.75 : -2.75;
  const oldDist = p.dist;
  for (const w of p.wheels) w.mesh.visible = true;
  placeCar(p, s, Math.min(lat, -2.75));
  p.vx = Math.sin(p.h) * 16; p.vz = Math.cos(p.h) * 16; p.vF = 16;
  p.invuln = 2.2;
  p.dist = oldDist; p.prevS = track.project(p.x, p.z).s;
  G.crash = null;
  G.zoomKick += 6;
  puff(P.smoke, p.x, 0.3, p.z, 10, COL.white, 1.4, 4, 0.7, 2);
}

function slowmo(ts, realDur) { G.tsTarget = ts; G.slowT = realDur; G.timeScale = Math.min(G.timeScale, ts + 0.15); }

// ---------------------------------------------------------------- tráfego / rivais: reciclagem
function recycle(dt) {
  const p = G.player, L = track.length;
  for (const c of G.traffic) {
    const rel = wrap((c.s - p.s) / L * Math.PI * 2) / (Math.PI * 2) * L; // distância ao longo da pista
    const far = rel < -70 || rel > 260;
    if ((c.wrecked && c.wreckT > 4 && !onScreen(c.x, c.z)) || (far && !onScreen(c.x, c.z))) {
      scene.add(c.group);
      for (const w of c.wheels) w.mesh.visible = true;
      // reaparece à frente do jogador, fora da tela
      for (let tries = 0; tries < 6; tries++) {
        const s = p.s + rand(110, 250);
        const lat = pick(c.oncoming ? LANES_ONC : LANES_FWD);
        const pt = track.at(s, lat);
        if (G.cars.some((o) => o !== c && Math.hypot(o.x - pt.x, o.z - pt.z) < 8)) continue;
        placeCar(c, s, lat);
        break;
      }
      c.nm = null;
    }
  }
  for (const c of G.rivals) {
    if (c.wrecked && c.wreckT > 3.2) {
      for (const w of c.wheels) w.mesh.visible = true;
      const oldS = c.s;
      const s = p.s - rand(26, 40);
      placeCar(c, s, pick(LANES_FWD));
      c.vx = Math.sin(c.h) * 24; c.vz = Math.cos(c.h) * 24;
      c.dist += wrap((c.s - oldS) / L * Math.PI * 2) / (Math.PI * 2) * L;
      c.prevS = c.s;
      c.invuln = 1.5;
    }
  }
}

// ---------------------------------------------------------------- loop de física
const STEP = 1 / 120;
let acc = 0;
function physics(dt) {
  acc += dt;
  let n = 0;
  while (acc >= STEP && n < 12) {
    acc -= STEP; n++;
    G.time += STEP;
    for (const c of G.cars) {
      if (c.role !== 'player' && !c.wrecked) c.ai(track, G, STEP);
      c.step(STEP, track);
    }
    for (const c of G.cars) collideWalls(c);
    for (let i = 0; i < G.cars.length; i++) for (let j = i + 1; j < G.cars.length; j++) collideCars(G.cars[i], G.cars[j]);
    handleEvents();
    stepProps(STEP);
    // boost pads
    for (const c of G.cars) {
      if (c.wrecked || c.y > 0.5) continue;
      const pad = track.padAt(c.x, c.z);
      if (pad && G.time > (c.padT || 0)) {
        c.padT = G.time + 0.8;
        const v = Math.max(Math.hypot(c.vx, c.vz), c.boostV * 0.95);
        c.vx = Math.sin(c.h) * v; c.vz = Math.cos(c.h) * v;
        if (c === G.player) {
          addBoost(0.2); sfx.pad(); sfx.boostKick();
          popup('TURBO!', 'boost'); G.zoomKick += 5; shake.add(0.2);
          flash(0.5, 0.9, 1, 0.18);
        }
      }
    }
  }
  if (n === 12) acc = 0;
}

// ---------------------------------------------------------------- regras de jogo por frame
function gameRules(dt) {
  const p = G.player, L = track.length;
  // progresso de volta para todos
  for (const c of G.cars) {
    const pr = track.project(c.x, c.z, c.ti ?? -1);
    c.ti = pr.i; c.lat = pr.lat; c.s = pr.s;
    if (c.role === 'traffic') continue;
    let d = pr.s - c.prevS;
    if (d > L / 2) d -= L; else if (d < -L / 2) d += L;
    c.dist += d; c.prevS = pr.s;
    const lap = Math.floor(c.dist / L);
    if (lap > c.lap) {
      c.lap = lap;
      if (c === p && G.mode === 'race') {
        const lt = G.raceT - G.lapStart; G.lapStart = G.raceT;
        G.lapTimes.push(lt);
        if (lt < G.bestLap) G.bestLap = lt;
        if (lap >= LAPS) finishRace();
        else { bigText(lap === LAPS - 1 ? 'ÚLTIMA VOLTA!' : `VOLTA ${lap + 1}`, 'lap'); sfx.lap(); confetti(p); }
      }
    }
  }
  if (G.mode !== 'race') return;
  // posição
  const order = [p, ...G.rivals].sort((a, b) => b.dist - a.dist);
  G.place = order.indexOf(p) + 1;
  // rubber band dos rivais
  for (const r of G.rivals) {
    const gap = p.dist - r.dist;
    r.rubber = clamp(1 + gap * 0.0035, 0.86, 1.2);
  }
  if (p.wrecked) return;
  const sp = Math.hypot(p.vx, p.vz);
  const fwd = p.vF;
  // contramão: dá turbo
  const along = p.vx * track.tx[p.ti] + p.vz * track.tz[p.ti];
  if (p.lat > 0.8 && along > 14 && p.onGround) {
    p.boost = Math.min(1, p.boost + dt * 0.11 * (sp / p.vmax));
    G.oncomingDist = (G.oncomingDist || 0) + along * dt;
    G.stats.oncoming += along * dt;
    $('oncoming').classList.add('on');
  } else {
    if (G.oncomingDist > 40) { popup(`CONTRAMÃO ${Math.round(G.oncomingDist)}m`, 'oncoming', `+${Math.round(G.oncomingDist)}`); G.stats.score += Math.round(G.oncomingDist); }
    G.oncomingDist = 0;
    $('oncoming').classList.remove('on');
  }
  // drift dá turbo continuamente
  if (p.drifting && fwd > 12) p.boost = Math.min(1, p.boost + dt * 0.1 * Math.min(1, p.driftSlip * 2));
  // no ar também
  if (!p.onGround) p.boost = Math.min(1, p.boost + dt * 0.06);
  // quase batidas
  for (const c of G.traffic) {
    if (c.wrecked) { c.nm = null; continue; }
    const d = Math.hypot(c.x - p.x, c.z - p.z);
    const rel = Math.hypot(c.vx - p.vx, c.vz - p.vz);
    if (d < 4.6 && rel > 12) {
      if (!c.nm) c.nm = { t: G.time, touched: false };
    }
    if (c.nm) {
      if (G.time - c.lastHitT < 0.5) c.nm.touched = true;
      if (d > 7.5) {
        if (!c.nm.touched) nearMiss(c);
        c.nm = null;
      }
    }
  }
}

function nearMiss(c) {
  G.stats.nearMiss++;
  const combo = (G.real - (G.lastNm || -9) < 2.5) ? (G.nmCombo = (G.nmCombo || 1) + 1) : (G.nmCombo = 1);
  G.lastNm = G.real;
  const pts = 50 * combo;
  G.stats.score += pts;
  addBoost(0.07 + (c.oncoming ? 0.05 : 0));
  popup(c.oncoming ? 'POR UM TRIZ!' : 'QUASE!', 'near', combo > 1 ? `x${combo} +${pts}` : `+${pts}`);
  sfx.whoosh(); sfx.combo(combo);
  G.zoomKick += 1.5;
  shake.add(0.05);
}

function finishRace() {
  G.mode = 'finish';
  G.finishT = 0;
  const p = G.player;
  p.finished = true;
  bigText(G.place === 1 ? 'VITÓRIA!' : `${G.place}º LUGAR`, 'finish');
  sfx.lap(); confetti(p); confetti(p);
  slowmo(0.35, 1.2);
  setTimeout(showResults, 1800);
}

function confetti(c) {
  for (let i = 0; i < 60; i++) {
    P.add.emit({ x: c.x + rand(-2, 2), y: 2, z: c.z + rand(-2, 2), vx: rand(-9, 9), vy: rand(8, 16), vz: rand(-9, 9),
      life: rand(1, 1.8), size: rand(0.35, 0.6), size1: 0.2, color: pick(COL.confetti), drag: 1.2, grav: 14 });
  }
}

// ---------------------------------------------------------------- efeitos contínuos por carro
const _a = new THREE.Vector3(), _b = new THREE.Vector3();
function carFx(c, dt) {
  if (c.wrecked) {
    // fumaça e fogo no destroço
    if (Math.random() < dt * 30 && onScreen(c.x, c.z)) {
      P.smoke.emit({ x: c.x + rand(-0.5, 0.5), y: c.wy + 0.4, z: c.z + rand(-0.5, 0.5), vx: rand(-0.5, 0.5), vy: rand(2, 4), vz: rand(-0.5, 0.5),
        life: rand(1.2, 2.2), size: 1.2, size1: 3.2, color: COL.smokeDark, color1: COL.smoke, alpha: 0.7, drag: 1 });
      if (c.wreckT < 2.5) P.add.emit({ x: c.x, y: c.wy + 0.3, z: c.z, vx: rand(-1, 1), vy: rand(2, 5), vz: rand(-1, 1),
        life: rand(0.3, 0.6), size: rand(0.8, 1.4), size1: 0.2, color: COL.fire, color1: COL.fireEnd, drag: 1 });
    }
    if (c.bounced > 3 && onScreen(c.x, c.z)) {
      burstSparks(P.add, c.x, 0.3, c.z, 0, 0, Math.min(1, c.bounced / 10), 12);
      puff(P.smoke, c.x, 0.3, c.z, 4, COL.dust, 1.5, 4, 0.8, 2);
      if (c === G.player || c === G.camFocus) { shake.add(Math.min(0.5, c.bounced * 0.05)); sfx.bump(c.bounced * 2); }
      c.bounced = 0;
    }
    return;
  }
  if (!onScreen(c.x, c.z)) return;
  const sp = Math.hypot(c.vx, c.vz);
  // marcas de pneu e fumaça: drift, freada forte ou deslize lateral
  const slip = Math.abs(c.vS);
  const braking = c.ctrl.brake && c.vF > 10;
  const skidding = c.onGround && (c.drifting || slip > 3.5 || braking);
  const intensity = c.drifting ? 1 : clamp((slip - 3) / 6, 0, 1) + (braking ? 0.6 : 0);
  for (const w of c.wheels) {
    if (!w.front || braking || slip > 6) {
      const pos = c.local(w.x, 0, w.z, _a);
      pos.y = 0.035 + c.y;
      if (skidding && c.y < 0.05) {
        if (w.last) skids.add(w.last, pos, 0.42, Math.min(0.65, 0.25 + intensity * 0.45), null, G.time);
        w.last = { x: pos.x, y: pos.y, z: pos.z };
        if (Math.random() < dt * 22 * intensity) {
          P.smoke.emit({ x: pos.x, y: 0.3, z: pos.z, vx: -c.vx * 0.08 + rand(-1, 1), vy: rand(0.5, 1.6), vz: -c.vz * 0.08 + rand(-1, 1),
            life: rand(0.7, 1.3), size: 0.9, size1: rand(2.4, 3.4), color: COL.smoke, alpha: 0.6, drag: 2 });
        }
      } else w.last = null;
    }
  }
  // turbo: chamas no escapamento + rastro das lanternas
  if (c.boosting) {
    const ex = c.local(c.wid * 0.28, 0.45, -(c.len / 2 + 0.25), _a);
    for (let i = 0; i < 2; i++) {
      P.add.emit({ x: ex.x, y: ex.y, z: ex.z, vx: -Math.sin(c.h) * 8 + rand(-1, 1) + c.vx * 0.7, vy: rand(0, 1), vz: -Math.cos(c.h) * 8 + rand(-1, 1) + c.vz * 0.7,
        life: rand(0.1, 0.22), size: rand(0.7, 1.1), size1: 0.15, color: COL.boost, color1: COL.boostEnd, drag: 4 });
    }
    for (const s of [-1, 1]) {
      const tl = c.local(s * c.wid * 0.32, 0.75, -c.len / 2, _b);
      const key = s < 0 ? 'trailL' : 'trailR';
      if (c[key]) trails.add(c[key], tl, 0.28, 0.9, null, G.time);
      c[key] = { x: tl.x, y: tl.y, z: tl.z };
    }
  } else { c.trailL = c.trailR = null; }
  // poeira ao andar pela zebra/acostamento
  if (Math.abs(c.lat) > 10.5 && sp > 10 && Math.random() < dt * 20) {
    puff(P.smoke, c.x, 0.2, c.z, 1, COL.dust, 1.2, 1.5, 0.8, 1);
  }
}

function speedStreaks(dt) {
  const p = G.player;
  const sp = Math.hypot(p.vx, p.vz);
  if (p.wrecked || sp < 30) return;
  const k = (sp - 30) / 25;
  if (Math.random() < dt * 60 * k) {
    const dirx = p.vx / sp, dirz = p.vz / sp;
    const side = rand(-14, 14), ahead = rand(-6, 20);
    const x = p.x + dirx * ahead + dirz * side, z = p.z + dirz * ahead - dirx * side;
    const l = rand(4, 9);
    streaks.add({ x, y: rand(0.5, 3), z }, { x: x - dirx * l, y: 1, z: z - dirz * l }, 0.12, 0.5 * Math.min(1, k), null, G.time);
  }
}

// ---------------------------------------------------------------- câmera
const camBasis = { rx: 0, rz: 0, fx: 0, fz: 0 };
function updateCamera(dt) {
  const p = G.player;
  let tx = p.x + p.vx * 0.38, tz = p.z + p.vz * 0.38;
  let focusH = 0;
  if (G.camFocus && G.focusT > 0) {
    const f = G.camFocus;
    tx = (f.x + p.x) / 2; tz = (f.z + p.z) / 2;
    focusH = -6;
  }
  if (p.wrecked) { tx = p.x; tz = p.z; }
  const k = 1 - Math.exp(-dt * (p.wrecked ? 3 : 4.5));
  G.camPos.x += (tx - G.camPos.x) * k;
  G.camPos.z += (tz - G.camPos.z) * k;
  // zoom: mais longe com velocidade e turbo; perto na batida
  const sp = Math.hypot(p.vx, p.vz);
  const aspect = W / H;
  const base = aspect < 1 ? Math.max(32, 30 / aspect) : 32;
  let target = base + clamp(sp / 55, 0, 1) * 9 + (p.boosting ? 4 : 0) + focusH + (p.wrecked ? -12 : 0);
  G.zoomKick *= Math.exp(-dt * 4);
  viewH += (target + G.zoomKick - viewH) * (1 - Math.exp(-dt * 3));
  const s = shake.update(dt);
  camera.top = viewH / 2; camera.bottom = -viewH / 2;
  camera.left = -viewH * aspect / 2; camera.right = viewH * aspect / 2;
  camera.updateProjectionMatrix();
  camera.position.set(G.camPos.x + camOff.x, camOff.y, G.camPos.z + camOff.z);
  camera.up.set(0, 1, 0);
  camera.lookAt(G.camPos.x, 0, G.camPos.z);
  // tremor no plano da tela
  camera.translateX(s.x); camera.translateY(s.y);
  camera.rotateZ(s.r);
  // base da tela no chão (para o analógico)
  _a.setFromMatrixColumn(camera.matrixWorld, 0); _a.y = 0; _a.normalize();
  camBasis.rx = _a.x; camBasis.rz = _a.z;
  camera.getWorldDirection(_b); _b.y = 0; _b.normalize();
  camBasis.fx = _b.x; camBasis.fz = _b.z;
  // sombra acompanha
  sun.position.set(G.camPos.x - 40, 80, G.camPos.z + 25);
  sun.target.position.set(G.camPos.x, 0, G.camPos.z);
  // tamanho das partículas em px
  const px = (renderer.domElement.height) / viewH;
  P.add.mat.uniforms.uPx.value = px; P.smoke.mat.uniforms.uPx.value = px;
}

// ---------------------------------------------------------------- pós
let flashA = 0; const flashC = new THREE.Vector3(1, 1, 1);
function flash(r, g, b, a) { flashC.set(r, g, b); flashA = Math.max(flashA, a); }
function updatePost(dt) {
  const p = G.player;
  const sp = Math.hypot(p.vx, p.vz);
  const f = post.final.uniforms;
  const blurT = (p.boosting ? 0.75 : 0) + clamp((sp - 32) / 30, 0, 0.4) + (G.timeScale < 0.6 ? 0.5 : 0);
  f.uBlur.value += (blurT - f.uBlur.value) * Math.min(1, dt * 6);
  f.uAberr.value += ((p.boosting ? 1 : 0) + shake.trauma * 2 + (G.timeScale < 0.6 ? 0.8 : 0) - f.uAberr.value) * Math.min(1, dt * 8);
  flashA *= Math.exp(-dt * 7);
  f.uFlash.value.set(flashC.x, flashC.y, flashC.z, flashA);
  f.uSat.value = G.timeScale < 0.6 ? 0.75 : 1.15;
  f.uVig.value = 0.3 + (p.boosting ? 0.25 : 0) + (G.timeScale < 0.6 ? 0.3 : 0);
  // centro do blur = carro na tela
  _a.set(p.x, p.y + 0.6, p.z).project(camera);
  f.uCenter.value.set(_a.x * 0.5 + 0.5, _a.y * 0.5 + 0.5);
}

// ---------------------------------------------------------------- HUD / UI
const popWrap = $('popups');
function popup(text, cls = '', sub = '') {
  const d = document.createElement('div');
  d.className = 'pop ' + cls;
  d.innerHTML = `<b>${text}</b>${sub ? `<small>${sub}</small>` : ''}`;
  popWrap.prepend(d);
  while (popWrap.children.length > 4) popWrap.lastChild.remove();
  setTimeout(() => d.remove(), 1600);
}
function bigText(text, cls) {
  const el = $('big');
  el.className = 'big ' + cls;
  el.textContent = text;
  void el.offsetWidth;
  el.classList.add('show');
}

let hudT = 0;
function updateHud(dt) {
  hudT -= dt;
  const p = G.player;
  $('boostFill').style.transform = `scaleX(${p.boost.toFixed(3)})`;
  $('boostBar').classList.toggle('full', p.boost >= 0.999);
  $('boostBar').classList.toggle('active', p.boosting);
  $('btnBoost').classList.toggle('ready', p.boost > 0.05);
  $('btnBoost').style.setProperty('--b', p.boost.toFixed(3));
  if (hudT > 0) return;
  hudT = 0.06;
  const kmh = Math.round(Math.hypot(p.vx, p.vz) * 3.6 * 1.25);
  $('speed').textContent = kmh;
  $('pos').innerHTML = `${G.place}<sup>º</sup><small>/4</small>`;
  $('lap').textContent = `VOLTA ${clamp(p.lap + 1, 1, LAPS)}/${LAPS}`;
  $('time').textContent = fmt(G.raceT);
  $('score').textContent = G.stats.score.toLocaleString('pt-BR');
  $('tdCount').textContent = G.stats.takedowns;
  drawMinimap();
}
const fmt = (t) => {
  if (!isFinite(t)) return '--:--.--';
  const m = Math.floor(t / 60), s = t - m * 60;
  return `${m}:${s < 10 ? '0' : ''}${s.toFixed(2)}`;
};

// minimapa
let mm, mmCtx, mmScale, mmOff;
function buildMinimap() {
  mm = $('minimap'); mmCtx = mm.getContext('2d');
  const xs = [...track.px], zs = [...track.pz];
  const minX = Math.min(...xs) - 15, maxX = Math.max(...xs) + 15, minZ = Math.min(...zs) - 15, maxZ = Math.max(...zs) + 15;
  // gira o mapa para bater com a vista isométrica (45°)
  const rot = (x, z) => [(x - z) * Math.SQRT1_2, (x + z) * Math.SQRT1_2];
  const pts = [];
  for (let i = 0; i < track.n; i++) pts.push(rot(track.px[i], track.pz[i]));
  const rx = pts.map((q) => q[0]), rz = pts.map((q) => q[1]);
  const a = [Math.min(...rx), Math.max(...rx), Math.min(...rz), Math.max(...rz)];
  mmScale = Math.min((mm.width - 16) / (a[1] - a[0]), (mm.height - 16) / (a[3] - a[2]));
  mmOff = [mm.width / 2 - (a[0] + a[1]) / 2 * mmScale, mm.height / 2 - (a[2] + a[3]) / 2 * mmScale];
  G.mmRot = rot;
  G.mmPath = new Path2D();
  pts.forEach((q, i) => {
    const X = q[0] * mmScale + mmOff[0], Y = q[1] * mmScale + mmOff[1];
    if (i) G.mmPath.lineTo(X, Y); else G.mmPath.moveTo(X, Y);
  });
  G.mmPath.closePath();
  void minX; void maxX; void minZ; void maxZ;
}
function drawMinimap() {
  if (!mmCtx) return;
  const c = mmCtx;
  c.clearRect(0, 0, mm.width, mm.height);
  c.lineJoin = 'round';
  c.strokeStyle = 'rgba(20,20,40,0.55)'; c.lineWidth = 9; c.stroke(G.mmPath);
  c.strokeStyle = '#f3f0ff'; c.lineWidth = 5; c.stroke(G.mmPath);
  const dot = (car, col, r) => {
    const [x, z] = G.mmRot(car.x, car.z);
    c.fillStyle = col; c.beginPath(); c.arc(x * mmScale + mmOff[0], z * mmScale + mmOff[1], r, 0, 7); c.fill();
  };
  for (const t of G.traffic) if (!t.wrecked) dot(t, 'rgba(90,90,110,0.6)', 2);
  for (const r of G.rivals) dot(r, '#' + r.color.getHexString(), 4.5);
  c.strokeStyle = '#fff'; c.lineWidth = 2;
  dot(G.player, '#ff2d3d', 6);
}

function showResults() {
  const s = G.stats;
  $('resTitle').textContent = G.place === 1 ? 'VITÓRIA!' : `${G.place}º LUGAR`;
  $('resList').innerHTML = [
    ['Tempo total', fmt(G.raceT)], ['Melhor volta', fmt(G.bestLap)], ['Takedowns', s.takedowns],
    ['Quase-batidas', s.nearMiss], ['Maior drift', s.bestDrift.toFixed(1) + 's'], ['Contramão', Math.round(s.oncoming) + 'm'],
    ['Maior pulo', s.air.toFixed(1) + 's'], ['Batidas', s.crashes], ['Pontos', s.score.toLocaleString('pt-BR')],
  ].map(([k, v]) => `<li><span>${k}</span><b>${v}</b></li>`).join('');
  $('results').classList.remove('hide');
}

// ---------------------------------------------------------------- fluxo
function startCountdown() {
  sfx.init();
  newRace();
  $('menu').classList.add('hide');
  $('hud').classList.remove('hide');
  G.mode = 'countdown';
  G.countdown = 3.0;
  G.lastBeep = 4;
}
$('playBtn').addEventListener('click', startCountdown);
$('againBtn').addEventListener('click', startCountdown);
$('menuBtn').addEventListener('click', () => { $('results').classList.add('hide'); $('hud').classList.add('hide'); $('menu').classList.remove('hide'); G.mode = 'menu'; newRace(); });
$('pauseBtn').addEventListener('click', () => togglePause());
$('resumeBtn').addEventListener('click', () => togglePause(false));
$('restartBtn').addEventListener('click', () => { $('pause').classList.add('hide'); startCountdown(); });
const muteBtn = $('muteBtn');
const syncMute = () => muteBtn.classList.toggle('off', sfx.muted);
muteBtn.addEventListener('click', () => { sfx.init(); sfx.setMuted(!sfx.muted); syncMute(); });
syncMute();
function togglePause(force) {
  if (!['race', 'countdown', 'paused'].includes(G.mode)) return;
  const pause = force ?? G.mode !== 'paused';
  if (pause) { G.prevMode = G.mode; G.mode = 'paused'; $('pause').classList.remove('hide'); if (sfx.ctx) sfx.ctx.suspend(); }
  else { G.mode = G.prevMode; $('pause').classList.add('hide'); if (sfx.ctx) sfx.ctx.resume(); }
}
document.addEventListener('visibilitychange', () => { if (document.hidden && G.mode === 'race') togglePause(true); });

// ---------------------------------------------------------------- frame
let last = performance.now();
let fpsAcc = 0, fpsN = 0, lowFps = 0;
function frame(now) {
  requestAnimationFrame(frame);
  const rdt = Math.min(0.05, (now - last) / 1000);
  last = now;
  if (G.mode === 'loading') return;
  tick(rdt, true);
}
// simulação sem render (testes automatizados): window.__game.advance(segundos)
G.input = input; G.track = track;
G.advance = (sec) => { for (let t = 0; t < sec; t += 1 / 60) tick(1 / 60, false); };
function tick(rdt, render) {
  G.real += rdt;

  // desempenho adaptativo
  if (render) { fpsAcc += rdt; fpsN++; }
  if (fpsAcc > 2 && !location.search.includes('fixed')) {
    const fps = fpsN / fpsAcc; fpsAcc = 0; fpsN = 0;
    if (fps < 42 && pixelRatio > 1) { pixelRatio = Math.max(1, pixelRatio - 0.5); renderer.setPixelRatio(pixelRatio); resize(); }
    else if (fps < 35 && ++lowFps > 1) { post.bloom.enabled = false; renderer.shadowMap.enabled = false; }
  }

  if (input.hit('Escape') || input.hit('KeyP')) togglePause();
  if (input.hit('KeyM')) { sfx.init(); sfx.setMuted(!sfx.muted); syncMute(); }
  if (input.hit('Enter') && G.mode === 'menu') startCountdown();
  if (input.hit('KeyR') && G.mode === 'race' && !G.player.wrecked) respawnPlayer();

  if (G.mode === 'paused') { input.endFrame(); return; }

  // tempo: hitstop congela, slow-mo desacelera
  if (G.slowT > 0) { G.slowT -= rdt; if (G.slowT <= 0) G.tsTarget = 1; }
  G.timeScale += (G.tsTarget - G.timeScale) * Math.min(1, rdt * (G.tsTarget < G.timeScale ? 12 : 3));
  let dt = rdt * G.timeScale;
  if (G.hitstop > 0) { G.hitstop -= rdt; dt = 0; }
  if (G.focusT > 0) { G.focusT -= rdt; if (G.focusT <= 0) G.camFocus = null; }

  const p = G.player;
  // controles
  const k = input.read(camBasis);
  if (G.mode === 'race' && !p.wrecked) {
    Object.assign(p.ctrl, k);
  } else {
    Object.assign(p.ctrl, { steer: 0, throttle: G.mode === 'finish' ? 0.6 : 0, brake: 0, drift: false, boost: false, dir: null });
    if (G.mode === 'finish') { p.ctrl.steer = 0; }
  }
  if (G.mode === 'countdown') {
    G.countdown -= rdt;
    const n = Math.ceil(G.countdown);
    if (n < G.lastBeep && n > 0) { G.lastBeep = n; bigText(String(n), 'count'); sfx.beep(false); shake.add(0.1); }
    // acelerar na contagem faz o motor roncar e soltar fumaça
    if (k.throttle && Math.random() < 0.5) {
      const ex = p.local(p.wid * 0.28, 0.4, -(p.len / 2 + 0.2), _a);
      P.smoke.emit({ x: ex.x, y: 0.4, z: ex.z, vx: rand(-1, 1), vy: rand(0.5, 1.5), vz: rand(-1, 1), life: 0.8, size: 0.6, size1: 1.6, color: COL.smoke, alpha: 0.5 });
    }
    if (G.countdown <= 0) {
      G.mode = 'race'; bigText('VAI!', 'go'); sfx.beep(true); shake.add(0.3); G.zoomKick += 4;
      // largada perfeita: quem estava acelerando ganha um empurrão
      if (k.throttle) { p.vx = Math.sin(p.h) * 14; p.vz = Math.cos(p.h) * 14; addBoost(0.15); popup('LARGADA PERFEITA!', 'boost'); }
    }
  }

  const frozen = G.mode === 'countdown' || G.mode === 'menu';
  if (!frozen) {
    physics(dt);
    if (G.mode === 'race') G.raceT += dt;
  } else {
    // IA parada no grid
    for (const c of G.cars) if (c.role !== 'traffic') { c.vx = c.vz = 0; }
    physics(dt);
    for (const c of G.cars) if (c.role !== 'traffic') { c.vx = c.vz = 0; c.omega = 0; }
  }
  gameRules(dt);
  recycle(dt);

  // batida do jogador: espera e volta para a pista
  if (G.crash) {
    G.crash.t += rdt;
    if (G.crash.t > 2.1) respawnPlayer();
  }

  // visuais
  for (const c of G.cars) { c.updateVisual(dt, G.time); carFx(c, dt); }
  speedStreaks(dt);
  P.add.update(dt); P.smoke.update(dt);
  skids.update(G.time); trails.update(G.time); streaks.update(G.time);
  debris.update(dt, (pos, v) => { if (v > 6) burstSparks(P.add, pos.x, 0.2, pos.z, 0, 0, 0.2, 3); });
  for (const t of G.padMeshes) t.offset.y = (t.offset.y - rdt * 1.6) % 1;
  if (G.mode === 'finish') { G.finishT += rdt; if (Math.random() < rdt * 6) confetti(p); }

  // áudio
  const sp01 = Math.hypot(p.vx, p.vz) / p.vmax;
  sfx.update(clamp(sp01, 0, 1.3), p.ctrl.throttle, p.drifting ? 1 : clamp((Math.abs(p.vS) - 3) / 8, 0, 1) + (p.ctrl.brake && p.vF > 10 ? 0.5 : 0),
    p.boosting, G.timeScale, G.mode === 'race' || G.mode === 'countdown' || G.mode === 'finish');
  if (p.boosting && !G.wasBoosting) { sfx.boostKick(); G.zoomKick += 4; shake.add(0.15); }
  G.wasBoosting = p.boosting;

  updateCamera(rdt);
  if (!render) { input.endFrame(); return; }
  updatePost(rdt);
  if (G.mode !== 'menu') updateHud(rdt);
  post.composer.render();
  input.endFrame();
}
requestAnimationFrame(frame);
