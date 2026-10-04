/* Mochi Pet — 3D jelly pet renderer.
   Three.js scene with a custom "jelly" ShaderMaterial:
   - vertex: soft-body bend (top lags behind the base) + poke ripple travelling over the surface
   - fragment: height gradient, wrap diffuse, fake subsurface/translucency, fresnel rim,
     studio softbox reflections and a face decal projected onto the front of the body. */

const VERT = /* glsl */`
uniform float uTime, uHeight, uPokeT, uPokeAmp, uBend, uRipple;
uniform vec2 uWobble;
uniform vec3 uOrigin, uPokePos;
varying vec3 vN;
varying vec3 vV;
varying vec3 vObj;
varying vec3 vObjN;
void main() {
  vObj = position;
  vObjN = normal;
#ifdef USE_INSTANCING
  vec4 lp = instanceMatrix * vec4(position, 1.0);
  vec3 ln = mat3(instanceMatrix) * normal;
#else
  vec4 lp = vec4(position, 1.0);
  vec3 ln = normal;
#endif
  vec4 wp = modelMatrix * lp;
  vec3 wn = normalize(mat3(modelMatrix) * ln);
  // poke ripple: a damped wave spreading from the touch point
  float d = distance(wp.xyz, uPokePos);
  float rip = uPokeAmp * exp(-uPokeT * 4.5) * exp(-d * d * 2.2) * cos(uPokeT * 26.0 - d * 10.0);
  wp.xyz -= wn * rip * 0.11 * uRipple;
  // jelly bend: higher vertices follow the wobble more
  float hh = clamp((wp.y - uOrigin.y) / uHeight, 0.0, 1.7);
  wp.xz += uWobble * hh * hh * uBend;
  vN = normalize(normalMatrix * ln);
  vec4 mv = viewMatrix * wp;
  vV = -mv.xyz;
  gl_Position = projectionMatrix * mv;
}`;

const FRAG = /* glsl */`
uniform vec3 uLight, uBase, uDeep;
uniform float uGradMin, uGradMax, uHasFace, uGloss, uStripes, uAO, uAlpha;
uniform vec3 uFaceRect;
uniform sampler2D uFace;
varying vec3 vN;
varying vec3 vV;
varying vec3 vObj;
varying vec3 vObjN;
void main() {
  vec3 N = normalize(vN);
  if (!gl_FrontFacing) N = -N;
  vec3 V = normalize(vV);
  float h = clamp((vObj.y - uGradMin) / max(uGradMax - uGradMin, 0.0001), 0.0, 1.0);
  vec3 alb = mix(uDeep, uBase, smoothstep(0.0, 0.6, h));
  alb = mix(alb, uLight, smoothstep(0.5, 1.0, h));
  if (uStripes > 0.5) {
    float a = atan(vObj.z, vObj.x) / 6.2831853 + 0.5;
    float seg = mod(floor(a * 6.0), 3.0);
    float shade = 0.82 + 0.18 * h;
    if (seg > 0.5 && seg < 1.5) alb = vec3(1.0, 0.53, 0.74) * shade;
    else if (seg > 1.5) alb = vec3(0.58, 0.83, 1.0) * shade;
  }
  vec3 L = normalize(vec3(-0.45, 0.75, 0.55));
  float diff = clamp((dot(N, L) + 0.65) / 1.65, 0.0, 1.0);
  vec3 col = alb * (0.6 + 0.52 * diff);
  float NV = clamp(dot(N, V), 0.0, 1.0);
  float fres = pow(1.0 - NV, 3.0);
  // translucency: back light scattering through thin edges
  vec3 Lb = normalize(vec3(0.25, 0.45, -0.85));
  float tr = pow(clamp(dot(V, -normalize(Lb + N * 0.6)), 0.0, 1.0), 3.0);
  col += uLight * tr * 0.4;
  // inner glow towards the bottom (light bouncing inside the jelly)
  col += uLight * (1.0 - h) * 0.12 * (1.0 - fres);
  col = mix(col, mix(uLight, vec3(1.0), 0.45), fres * 0.6);
  col += uBase * clamp(-N.y, 0.0, 1.0) * 0.12;
  col *= mix(1.0, smoothstep(-0.02, 0.16, vObj.y) * 0.25 + 0.75, uAO);
  if (uHasFace > 0.5) {
    vec2 uv = (vObj.xy - uFaceRect.xy) / uFaceRect.z + 0.5;
    float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
    float m = smoothstep(0.05, 0.45, vObjN.z) * inside;
    vec4 f = texture2D(uFace, uv);
    col = mix(col, f.rgb, f.a * m);
  }
  // studio reflections: big softbox, sharp key glint, side strip
  vec3 R = reflect(-V, N);
  float sb = smoothstep(0.78, 0.97, dot(R, normalize(vec3(-0.5, 0.72, 0.5))));
  float sp = pow(clamp(dot(R, normalize(vec3(-0.36, 0.55, 0.75))), 0.0, 1.0), 240.0);
  float rb = smoothstep(0.88, 0.975, dot(R, normalize(vec3(0.85, 0.12, 0.5))));
  col += vec3(1.0) * (sb * 0.34 + sp * 1.1 + rb * 0.22) * uGloss;
  gl_FragColor = vec4(col, uAlpha);
}`;

export function createPet3D(THREE, api) {
  const { SPEC, SKINS, SK, drawFace, drawDirt } = api;
  THREE.ColorManagement.enabled = false;

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
  renderer.setClearColor(0x000000, 0);
  renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
  const canvas = renderer.domElement;
  canvas.className = 'gl';
  canvas.setAttribute('aria-hidden', 'true');

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(26, 1, 0.1, 200);
  const root = new THREE.Group();
  const body = new THREE.Group();
  body.rotation.order = 'YXZ';
  root.add(body); scene.add(root);

  const U = {
    uTime: { value: 0 }, uWobble: { value: new THREE.Vector2() }, uOrigin: { value: new THREE.Vector3() },
    uHeight: { value: 1.4 }, uPokePos: { value: new THREE.Vector3(0, -99, 0) }, uPokeT: { value: 10 }, uPokeAmp: { value: 0 },
  };

  // face decal
  const FACE_N = 512;
  const FACE_LIFT = { mochi: 0.12, coelho: 0.02, gato: 0.06 };
  const faceCanvas = document.createElement('canvas');
  faceCanvas.width = faceCanvas.height = FACE_N;
  const fctx = faceCanvas.getContext('2d');
  const faceTex = new THREE.CanvasTexture(faceCanvas);
  faceTex.colorSpace = THREE.NoColorSpace;
  faceTex.anisotropy = 4;
  let faceKey = '';

  function mat(sk, o = {}) {
    const m = new THREE.ShaderMaterial({
      uniforms: {
        ...U,
        uLight: { value: new THREE.Color(sk.light) }, uBase: { value: new THREE.Color(sk.base) }, uDeep: { value: new THREE.Color(sk.deep) },
        uGradMin: { value: 0 }, uGradMax: { value: 1 }, uHasFace: { value: 0 }, uFaceRect: { value: new THREE.Vector3(0, 0, 1) }, uFace: { value: faceTex },
        uGloss: { value: o.gloss ?? 1 }, uStripes: { value: o.stripes ? 1 : 0 }, uAO: { value: o.ao ? 1 : 0 },
        uBend: { value: o.bend ?? 1 }, uRipple: { value: o.ripple ?? 0.35 }, uAlpha: { value: o.alpha ?? 1 },
      },
      vertexShader: VERT, fragmentShader: FRAG,
      side: o.side ?? THREE.FrontSide, transparent: (o.alpha ?? 1) < 1,
    });
    m.userData.skinned = !!o.skinned;
    return m;
  }
  function fitGrad(m, geo) {
    geo.computeBoundingBox();
    m.uniforms.uGradMin.value = geo.boundingBox.min.y; m.uniforms.uGradMax.value = geo.boundingBox.max.y;
  }
  function mesh(geo, m, parent) {
    fitGrad(m, geo);
    const me = new THREE.Mesh(geo, m);
    if (parent) parent.add(me);
    return me;
  }
  function blob(rx, ry, rz, sk, o) {
    const g = new THREE.SphereGeometry(1, 32, 20); g.scale(rx, ry, rz);
    return mesh(g, mat(sk, o));
  }

  // ---------- profiles (from the same bezier outlines used by the 2D renderer)
  function bezierPts(segs, n = 14) {
    const out = [];
    segs.forEach((s, si) => {
      for (let i = si ? 1 : 0; i <= n; i++) {
        const t = i / n, u = 1 - t;
        const x = u * u * u * s[0][0] + 3 * u * u * t * s[1][0] + 3 * u * t * t * s[2][0] + t * t * t * s[3][0];
        const y = u * u * u * s[0][1] + 3 * u * u * t * s[1][1] + 3 * u * t * t * s[2][1] + t * t * t * s[3][1];
        out.push(new THREE.Vector2(Math.max(0, x), -y));
      }
    });
    out[0].x = 0; out[out.length - 1].x = 0;
    return out;
  }
  const PROFILES = {
    mochi: { zs: 0.9, segs: [[[0, 0], [0.76, 0], [1.12, -0.04], [1.12, -0.44]], [[1.12, -0.44], [1.12, -1.06], [0.66, -1.42], [0, -1.42]]] },
    coelho: { zs: 0.86, segs: [[[0, 0], [0.45, 0], [0.72, -0.02], [0.72, -0.26]], [[0.72, -0.26], [0.72, -0.55], [0.62, -0.74], [0.58, -0.88]], [[0.58, -0.88], [0.84, -1.08], [0.82, -1.92], [0, -1.92]]] },
    gato: { zs: 0.8, segs: [[[0, 0], [0.7, 0], [0.96, -0.02], [0.96, -0.32]], [[0.96, -0.32], [0.96, -0.72], [0.86, -0.96], [0.74, -1.06]], [[0.74, -1.06], [0.6, -1.15], [0.3, -1.18], [0, -1.18]]] },
  };

  let cur = null; // current built pet
  const pickables = [];

  function radiusAt(prof, y) {
    const p = prof.pts;
    for (let i = 1; i < p.length; i++) {
      const a = p[i - 1], b = p[i];
      if ((y >= a.y && y <= b.y) || (y <= a.y && y >= b.y)) { const t = (y - a.y) / ((b.y - a.y) || 1e-6); return a.x + (b.x - a.x) * t; }
    }
    return 0;
  }
  function surfaceZ(prof, x, y) { const r = radiusAt(prof, y); return Math.sqrt(Math.max(r * r - x * x, 0)) * prof.zs; }
  function heightAtRadius(prof, r) { // highest point of the outline at this radius
    const p = prof.pts;
    for (let i = p.length - 1; i > 0; i--) { const a = p[i], b = p[i - 1]; if (r >= a.x && r <= b.x) { const t = (r - a.x) / ((b.x - a.x) || 1e-6); return a.y + (b.y - a.y) * t; } }
    return 0;
  }

  function build(species, skinId) {
    if (cur) { body.remove(cur.group); cur.group.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); }); }
    pickables.length = 0;
    const sk = SKINS[skinId] || SKINS.pessego, d = SPEC[species], P = PROFILES[species];
    P.pts = bezierPts(P.segs);
    const group = new THREE.Group();
    const g = new THREE.LatheGeometry(P.pts, 72); g.scale(1, 1, P.zs);
    const bm = mat(sk, { skinned: true, ao: true, ripple: 1 });
    bm.uniforms.uHasFace.value = 1;
    const H = -P.segs[P.segs.length - 1][3][1];
    const faceSize = species === 'coelho' ? 1.25 : species === 'gato' ? 1.45 : 1.6;
    const faceCy = -d.eye.y - 0.06;
    bm.uniforms.uFaceRect.value.set(0, faceCy, faceSize);
    const bodyMesh = mesh(g, bm, group);
    pickables.push(bodyMesh);
    const light = { light: '#FFFFFF', base: sk.light, deep: sk.base };
    const built = { group, prof: P, h: H, face: { cy: faceCy, size: faceSize }, ears: [], tail: null, stem: null, mats: [bm], species, skinId, hatGroup: null, hatId: null };
    const skinMat = (o = {}) => { const m = mat(sk, { skinned: true, ...o }); built.mats.push(m); return m; };

    if (species === 'mochi') {
      const stem = new THREE.Group(); stem.position.set(0.02, H - 0.02, 0.02); group.add(stem);
      const nub = blob(0.13, 0.08, 0.11, { light: '#FFE08A', base: '#FFB43D', deep: '#FF9330' }); nub.position.y = 0.04; stem.add(nub);
      const leaf = blob(0.13, 0.025, 0.065, SK.green); leaf.position.set(0.12, 0.07, -0.02); leaf.rotation.set(0, 0.5, 0.35); stem.add(leaf);
      built.stem = stem;
    } else if (species === 'coelho') {
      for (const s of [-1, 1]) {
        const pivot = new THREE.Group(); pivot.position.set(s * 0.3, 1.74, -0.04); group.add(pivot);
        const eg = new THREE.CapsuleGeometry(0.17, 0.52, 10, 24); eg.scale(1, 1, 0.62); eg.translate(0, 0.42, 0);
        const ear = mesh(eg, skinMat({ bend: 1 }), pivot);
        const ig = new THREE.CapsuleGeometry(0.08, 0.36, 8, 16); ig.scale(1, 1, 0.4); ig.translate(0, 0.42, 0.085);
        mesh(ig, mat({ light: '#FFD6E6', base: '#FFB2CE', deep: '#FF8DB6' }, { gloss: 0.6 }), pivot);
        built.ears.push({ pivot, s, base: -s * 0.16 });
        pickables.push(ear);
      }
      for (const s of [-1, 1]) {
        const paw = mesh(new THREE.SphereGeometry(1, 24, 16).scale(0.13, 0.1, 0.1), mat(light, { skinned: false }), group);
        paw.position.set(s * 0.2, 0.62, surfaceZ(P, s * 0.2, 0.62) - 0.03);
        const foot = mesh(new THREE.SphereGeometry(1, 24, 16).scale(0.2, 0.09, 0.22), mat(light), group);
        foot.position.set(s * 0.36, 0.07, 0.36);
      }
    } else if (species === 'gato') {
      const earProf = [new THREE.Vector2(0, 0), new THREE.Vector2(0.24, 0), new THREE.Vector2(0.2, 0.12), new THREE.Vector2(0.09, 0.32), new THREE.Vector2(0.03, 0.4), new THREE.Vector2(0, 0.41)];
      for (const s of [-1, 1]) {
        const pivot = new THREE.Group(); pivot.position.set(s * 0.55, 0.98, 0); pivot.rotation.z = -s * 0.38; group.add(pivot);
        const eg = new THREE.LatheGeometry(earProf, 32); eg.scale(1, 1, 0.55);
        const ear = mesh(eg, skinMat(), pivot);
        const ig = new THREE.LatheGeometry(earProf, 24); ig.scale(0.55, 0.62, 0.2); ig.translate(0, 0.04, 0.09);
        mesh(ig, mat({ light: '#FFD6E6', base: '#FFB2CE', deep: '#FF9CC0' }, { gloss: 0.5 }), pivot);
        built.ears.push({ pivot, s, base: -s * 0.38 });
        pickables.push(ear);
      }
      const tail = new THREE.Group(); tail.position.set(0.62, 0.16, -0.38); group.add(tail);
      const curve = new THREE.CatmullRomCurve3([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0.32, 0.02, -0.08), new THREE.Vector3(0.48, 0.3, -0.1), new THREE.Vector3(0.36, 0.62, -0.05), new THREE.Vector3(0.22, 0.72, 0)]);
      const tg = new THREE.TubeGeometry(curve, 48, 0.1, 16, false);
      const tm = skinMat();
      mesh(tg, tm, tail);
      const cap = mesh(new THREE.SphereGeometry(0.1, 16, 12), tm, tail); cap.position.copy(curve.getPoint(1));
      built.tail = tail;
      for (const s of [-1, 1]) {
        const paw = mesh(new THREE.SphereGeometry(1, 24, 16).scale(0.18, 0.1, 0.14), mat({ light: '#FFFFFF', base: '#FFFFFF', deep: sk.light }), group);
        paw.position.set(s * 0.25, 0.08, surfaceZ(P, s * 0.25, 0.1) + 0.02);
      }
    }
    // foam bubbles live on the body so they squash with it
    const foamGeo = new THREE.SphereGeometry(1, 16, 12);
    const foamMat = mat({ light: '#FFFFFF', base: '#F4FBFF', deep: '#D6EEFB' }, { gloss: 1.2, bend: 1 });
    const foam = new THREE.InstancedMesh(foamGeo, foamMat, 60); foam.count = 0; foam.frustumCulled = false;
    fitGrad(foamMat, foamGeo); group.add(foam);
    built.foam = foam;
    body.add(group);
    cur = built;
    U.uHeight.value = H;
    faceKey = '';
  }

  // ---------- hats (3D versions of the 2D accessories)
  function buildHat(id) {
    if (cur.hatGroup) { cur.group.remove(cur.hatGroup); cur.hatGroup.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); }); cur.hatGroup = null; }
    cur.hatId = id;
    if (!id || id === 'none') return;
    const P = cur.prof, H = cur.h, k = SPEC[cur.species].hatW / 0.8;
    const hat = new THREE.Group(); cur.group.add(hat); cur.hatGroup = hat;
    const add = (geo, sk, o) => mesh(geo, mat(sk, o), hat);
    switch (id) {
      case 'coroa': {
        const r = Math.max(0.2, Math.min(radiusAt(P, H - 0.12) * 0.8, 0.34 * k));
        hat.position.y = H - 0.13;
        const band = add(new THREE.CylinderGeometry(r, r * 1.06, 0.16, 48, 1, true), SK.gold, { side: THREE.DoubleSide }); band.position.y = 0.08;
        for (let i = 0; i < 5; i++) {
          const a = (i / 5) * Math.PI * 2;
          const sp = add(new THREE.ConeGeometry(0.065, 0.2, 16), SK.gold); sp.position.set(Math.sin(a) * r, 0.25, Math.cos(a) * r);
          const tip = add(new THREE.SphereGeometry(0.038, 12, 10), SK.gold); tip.position.set(Math.sin(a) * r, 0.36, Math.cos(a) * r);
        }
        [[0, SK.pink, 0.05], [-0.55, SK.sky, 0.035], [0.55, SK.mint, 0.035]].forEach(([a, sk, s]) => { const gem = add(new THREE.SphereGeometry(s, 16, 12), sk); gem.position.set(Math.sin(a) * r * 1.03, 0.08, Math.cos(a) * r * 1.03); });
        break;
      }
      case 'gorro': {
        const y0 = H - 0.22, r = radiusAt(P, y0) * 1.06;
        hat.position.y = y0;
        const dome = add(new THREE.SphereGeometry(r, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2).scale(1, 0.82, P.zs * 1.04), SK.lav);
        const band = add(new THREE.TorusGeometry(r, 0.075, 14, 48).rotateX(Math.PI / 2).scale(1, 1, P.zs * 1.04), { light: '#D9CCFF', base: '#A68BFA', deep: '#8466E6' });
        band.position.y = 0.02;
        const pom = add(new THREE.SphereGeometry(0.12, 20, 14), SK.white); pom.position.y = r * 0.82 + 0.06;
        hat.userData.pom = pom; void dome;
        break;
      }
      case 'festa': {
        hat.position.y = H - 0.05; hat.rotation.z = -0.15;
        const cone = add(new THREE.ConeGeometry(0.21, 0.6, 40, 1), SK.mint); cone.position.y = 0.3;
        for (let i = 0; i < 3; i++) { const ring = add(new THREE.TorusGeometry(0.19 - i * 0.055, 0.022, 8, 32).rotateX(Math.PI / 2), SK.pink); ring.position.y = 0.1 + i * 0.16; }
        const pom = add(new THREE.SphereGeometry(0.075, 16, 12), SK.yellow); pom.position.y = 0.62;
        break;
      }
      case 'folha': {
        hat.position.y = H - 0.02;
        const stem = add(new THREE.CylinderGeometry(0.022, 0.03, 0.24, 10), SK.green); stem.position.y = 0.11;
        const l1 = add(new THREE.SphereGeometry(1, 20, 12).scale(0.16, 0.03, 0.08), SK.green); l1.position.set(-0.13, 0.25, 0); l1.rotation.z = 0.45;
        const l2 = add(new THREE.SphereGeometry(1, 20, 12).scale(0.17, 0.03, 0.085), SK.green); l2.position.set(0.14, 0.27, 0); l2.rotation.z = -0.45;
        hat.userData.sway = true;
        break;
      }
      case 'laco': {
        const x = 0.36 * k; hat.position.set(x, heightAtRadius(P, x) - 0.02, 0.06); hat.rotation.set(0.2, 0, -0.4);
        for (const s of [-1, 1]) { const lobe = add(new THREE.SphereGeometry(1, 24, 16).scale(0.19, 0.13, 0.09), SK.pink); lobe.position.x = s * 0.17; lobe.rotation.z = s * 0.25; }
        add(new THREE.SphereGeometry(0.085, 16, 12), SK.pink);
        break;
      }
      case 'flor': {
        const x = -0.4 * k; hat.position.set(x, heightAtRadius(P, Math.abs(x)) - 0.02, 0.1); hat.rotation.set(-0.55, 0, 0.35);
        for (let i = 0; i < 5; i++) { const a = (i / 5) * Math.PI * 2; const pe = add(new THREE.SphereGeometry(1, 20, 12).scale(0.1, 0.075, 0.035), SK.white); pe.position.set(Math.cos(a) * 0.1, Math.sin(a) * 0.1, 0); pe.rotation.z = a; }
        const c = add(new THREE.SphereGeometry(0.065, 16, 12), SK.yellow); c.position.z = 0.03;
        hat.userData.spin = true;
        break;
      }
    }
  }

  // ---------- ball
  const ballMesh = mesh(new THREE.SphereGeometry(1, 40, 24), mat(SK.yellow, { stripes: true, bend: 0, ripple: 0 }), scene);
  ballMesh.visible = false;

  // ---------- camera layout: R px per world unit at the pet, base at (petX, groundY)
  const L = { W: 0, H: 0, gy: 0, R: 0, dpr: 0 };
  function layout(W, H, gy, R) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    if (L.W === W && L.H === H && L.gy === gy && L.R === R && L.dpr === dpr) return;
    Object.assign(L, { W, H, gy, R, dpr });
    renderer.setPixelRatio(dpr); renderer.setSize(W, H, false);
    camera.aspect = W / H;
    const D = (H / R) / (2 * Math.tan((camera.fov * Math.PI) / 360));
    const tilt = 0.17, target = new THREE.Vector3(0, 0.7, 0);
    camera.position.set(0, target.y + Math.sin(tilt) * D, Math.cos(tilt) * D);
    camera.lookAt(target);
    camera.clearViewOffset(); camera.updateProjectionMatrix(); camera.updateMatrixWorld();
    const v = new THREE.Vector3(0, 0, 0).project(camera);
    camera.setViewOffset(W, H, 0, (1 - v.y) / 2 * H - gy, W, H);
    camera.updateProjectionMatrix();
  }

  const tmp = new THREE.Vector3();
  function toScreen(v) { tmp.copy(v).project(camera); return { x: (tmp.x + 1) / 2 * L.W, y: (1 - tmp.y) / 2 * L.H }; }
  function localToScreen(x, y, z) { body.updateMatrixWorld(true); return toScreen(cur.group.localToWorld(new THREE.Vector3(x, y, z))); }
  const raycaster = new THREE.Raycaster();
  function raycast(sx, sy) {
    if (!cur) return null;
    root.updateMatrixWorld(true);
    raycaster.setFromCamera(new THREE.Vector2(sx / L.W * 2 - 1, -(sy / L.H) * 2 + 1), camera);
    const hit = raycaster.intersectObjects(pickables, false)[0];
    if (!hit) return null;
    const local = cur.group.worldToLocal(hit.point.clone());
    return { world: hit.point.clone(), local };
  }
  function screenOnPlane(sx, sy, z) {
    raycaster.setFromCamera(new THREE.Vector2(sx / L.W * 2 - 1, -(sy / L.H) * 2 + 1), camera);
    const r = raycaster.ray, t = (z - r.origin.z) / r.direction.z;
    return r.origin.clone().addScaledVector(r.direction, t);
  }

  // ---------- face texture
  function paintFace(o) {
    const d = SPEC[cur.species];
    const key = [cur.species, o.eyes, o.mouth, o.blink.toFixed(2), o.look.x.toFixed(2), o.look.y.toFixed(2), o.mouthOpen.toFixed(2), o.dirt.toFixed(2), o.eyes === 'swirl' ? o.t.toFixed(2) : ''].join('|');
    if (key === faceKey) return;
    faceKey = key;
    const k = FACE_N / cur.face.size;
    fctx.setTransform(1, 0, 0, 1, 0, 0); fctx.clearRect(0, 0, FACE_N, FACE_N);
    fctx.setTransform(k, 0, 0, k, FACE_N / 2, FACE_N / 2 + cur.face.cy * k);
    fctx.translate(0, -FACE_LIFT[cur.species]); // seen from slightly above, the face reads better a bit higher
    if (o.dirt > 0.01) drawDirt(fctx, d, o.dirt);
    if (cur.species === 'gato') {
      fctx.strokeStyle = 'rgba(60,40,70,0.35)'; fctx.lineWidth = 0.016; fctx.lineCap = 'round';
      for (const s of [-1, 1]) { fctx.beginPath(); fctx.moveTo(s * 0.56, -0.62); fctx.lineTo(s * 0.8, -0.66); fctx.moveTo(s * 0.56, -0.56); fctx.lineTo(s * 0.8, -0.54); fctx.stroke(); }
    }
    drawFace(fctx, d, o);
    faceTex.needsUpdate = true;
  }

  // ---------- per-frame
  const foamM = new THREE.Matrix4(), foamQ = new THREE.Quaternion(), foamS = new THREE.Vector3(), foamP = new THREE.Vector3();
  function update(o) {
    if (!cur || cur.species !== o.species) { build(o.species, o.skin); buildHat(o.hat); }
    if (cur.skinId !== o.skin) { build(o.species, o.skin); buildHat(o.hat); }
    if (cur.hatId !== o.hat) buildHat(o.hat);
    layout(o.W, o.H, o.groundY, o.R);
    const R = o.R;
    root.position.set((o.x - o.W / 2) / R, -o.hop / R, 0);
    const sq = Math.max(-0.4, Math.min(0.5, o.sq));
    body.scale.set(1 + sq - o.breathe * 0.6, 1 - sq + o.breathe, 1 + sq * 0.8 - o.breathe * 0.6);
    body.rotation.set(o.pitch || 0, (o.yaw || 0) + (o.spin || 0), -o.rot);
    U.uTime.value = o.t;
    U.uWobble.value.set(o.wobX || 0, o.wobZ || 0);
    root.updateMatrixWorld(true);
    U.uOrigin.value.setFromMatrixPosition(cur.group.matrixWorld);
    U.uHeight.value = cur.h * body.scale.y;
    U.uPokeT.value += o.dt || 0;
    for (const e of cur.ears) {
      if (cur.species === 'coelho') e.pivot.rotation.set(-0.12 + Math.sin(o.t * 1.3 + e.s) * 0.04, 0, e.base - e.s * o.ear + Math.sin(o.t * 1.7 + e.s) * 0.03);
      else e.pivot.rotation.set(0, 0, e.base + e.s * o.ear * 0.5);
    }
    if (cur.tail) cur.tail.rotation.set(0, Math.sin(o.t * (o.happy ? 7 : 2.6)) * (o.happy ? 0.45 : 0.25), Math.sin(o.t * 1.9) * 0.08 - o.ear * 0.4);
    if (cur.stem) cur.stem.rotation.set(0, 0, Math.sin(o.t * 2.1) * 0.12 + o.ear * 0.8);
    if (cur.hatGroup) {
      if (cur.hatGroup.userData.sway) cur.hatGroup.rotation.z = Math.sin(o.t * 2.2) * 0.12 + o.ear * 0.6;
      if (cur.hatGroup.userData.pom) cur.hatGroup.userData.pom.position.x = Math.sin(o.t * 2.4) * 0.02 + o.ear * 0.2;
    }
    // foam
    const foam = cur.foam; let n = 0;
    if (o.foam) for (const b of o.foam) {
      if (n >= 60) break;
      const grow = b.pop != null ? 1 + (1 - b.pop) * 0.5 : Math.min(1, (o.t - b.born) * 6);
      const s = b.r * grow * (b.pop != null ? Math.max(0.01, b.pop) : 1);
      const y = -b.y, x = b.x + Math.sin(o.t * 3 + b.ph) * 0.01;
      foamP.set(x, y, (b.z != null ? b.z : surfaceZ(cur.prof, x, y)) + s * 0.25);
      foamS.set(s, s, s * 0.8);
      foamM.compose(foamP, foamQ, foamS); foam.setMatrixAt(n++, foamM);
    }
    foam.count = n; foam.instanceMatrix.needsUpdate = true;
    // ball
    if (o.ball) {
      const z = 1.05, p = screenOnPlane(o.ball.x, o.ball.y, z);
      const dist = camera.position.distanceTo(p), base = camera.position.length();
      ballMesh.visible = true; ballMesh.position.copy(p);
      const s = (o.ball.r / R) * (dist / base); ballMesh.scale.setScalar(s);
      ballMesh.rotation.set(0.35, 0, -o.ball.spin);
    } else ballMesh.visible = false;
    paintFace(o);
  }
  function render() { renderer.render(scene, camera); }
  function poke(world, amp = 1) { U.uPokePos.value.copy(world); U.uPokeT.value = 0; U.uPokeAmp.value = amp; }
  function mouthScreen() { const d = SPEC[cur.species], y = -d.mouthY + FACE_LIFT[cur.species]; return localToScreen(0, y, surfaceZ(cur.prof, 0, y)); }
  function topScreen() { return localToScreen(0, cur.h, 0); }
  function baseScreen() { return toScreen(new THREE.Vector3(root.position.x, 0, 0)); }
  function attach(parent, before) { if (canvas.parentNode !== parent || canvas.nextSibling !== before) parent.insertBefore(canvas, before || null); L.W = 0; }
  function surfaceAt(x, y) { return cur ? surfaceZ(cur.prof, x, y) : 0; }

  return { canvas, update, render, poke, raycast, mouthScreen, topScreen, baseScreen, attach, surfaceAt, renderer };
}
