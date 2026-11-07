// Teclado + controles touch (analógico que aponta a direção na tela, botões de turbo e drift).
export class Input {
  constructor() {
    this.keys = new Set();
    this.touch = false;
    this.stick = { id: null, ox: 0, oy: 0, dx: 0, dy: 0, mag: 0 };
    this.btn = { boost: false, drift: false, gas: false, brake: false };
    this.pressed = new Set();   // teclas apertadas neste frame

    addEventListener('keydown', (e) => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(e.code)) e.preventDefault();
      if (!this.keys.has(e.code)) this.pressed.add(e.code);
      this.keys.add(e.code);
    });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    addEventListener('blur', () => { this.keys.clear(); for (const k in this.btn) this.btn[k] = false; this.stick.id = null; this.stick.mag = 0; });

    const zone = document.getElementById('stickZone');
    const base = document.getElementById('stickBase');
    const knob = document.getElementById('stickKnob');
    const R = 56;
    const setKnob = () => {
      knob.style.transform = `translate(${this.stick.dx * R}px, ${this.stick.dy * R}px)`;
    };
    zone.addEventListener('pointerdown', (e) => {
      if (this.stick.id !== null) return;
      this.touch = true;
      document.body.classList.add('touching');
      zone.setPointerCapture(e.pointerId);
      this.stick.id = e.pointerId;
      this.stick.ox = e.clientX; this.stick.oy = e.clientY;
      this.stick.dx = this.stick.dy = this.stick.mag = 0;
      base.style.left = e.clientX + 'px'; base.style.top = e.clientY + 'px';
      base.classList.add('on');
      setKnob();
      e.preventDefault();
    });
    const move = (e) => {
      if (e.pointerId !== this.stick.id) return;
      let dx = (e.clientX - this.stick.ox) / R, dy = (e.clientY - this.stick.oy) / R;
      const m = Math.hypot(dx, dy);
      if (m > 1) {
        // a base acompanha o dedo quando passa do raio (fica confortável em telas pequenas)
        this.stick.ox += (dx / m) * (m - 1) * R; this.stick.oy += (dy / m) * (m - 1) * R;
        base.style.left = this.stick.ox + 'px'; base.style.top = this.stick.oy + 'px';
        dx /= m; dy /= m;
      }
      this.stick.dx = dx; this.stick.dy = dy; this.stick.mag = Math.min(1, m);
      setKnob();
    };
    const up = (e) => {
      if (e.pointerId !== this.stick.id) return;
      this.stick.id = null; this.stick.mag = 0; this.stick.dx = this.stick.dy = 0;
      base.classList.remove('on');
      setKnob();
    };
    zone.addEventListener('pointermove', move);
    zone.addEventListener('pointerup', up);
    zone.addEventListener('pointercancel', up);

    for (const [id, key] of [['btnBoost', 'boost'], ['btnDrift', 'drift'], ['btnBrake', 'brake']]) {
      const el = document.getElementById(id);
      const on = (e) => { e.preventDefault(); this.touch = true; document.body.classList.add('touching'); el.setPointerCapture?.(e.pointerId); this.btn[key] = true; el.classList.add('down'); if (navigator.vibrate) navigator.vibrate(8); };
      const off = (e) => { e.preventDefault(); this.btn[key] = false; el.classList.remove('down'); };
      el.addEventListener('pointerdown', on);
      el.addEventListener('pointerup', off);
      el.addEventListener('pointercancel', off);
      el.addEventListener('lostpointercapture', off);
    }
  }

  down(...codes) { return codes.some((c) => this.keys.has(c)); }
  hit(code) { return this.pressed.has(code); }
  endFrame() { this.pressed.clear(); }

  // Estado de controle. camBasis: {rx,rz,fx,fz} = direita/cima da tela no chão.
  read(camBasis) {
    const k = {
      steer: 0, throttle: 0, brake: 0, drift: false, boost: false, dir: null, dirMag: 0,
    };
    const left = this.down('ArrowLeft', 'KeyA'), right = this.down('ArrowRight', 'KeyD');
    k.steer = (left ? 1 : 0) - (right ? 1 : 0);
    k.throttle = this.down('ArrowUp', 'KeyW') ? 1 : 0;
    k.brake = this.down('ArrowDown', 'KeyS') ? 1 : 0;
    k.drift = this.down('Space');
    k.boost = this.down('ShiftLeft', 'ShiftRight', 'KeyN', 'KeyJ');

    if (this.touch) {
      // no touch o acelerador é automático; freio solta o acelerador
      if (!this.btn.brake) k.throttle = 1;
      if (this.btn.brake) k.brake = 1;
      k.drift = k.drift || this.btn.drift;
      k.boost = k.boost || this.btn.boost;
      if (this.stick.mag > 0.22) {
        // direção desejada no mundo (relativa à tela)
        const wx = camBasis.rx * this.stick.dx - camBasis.fx * this.stick.dy;
        const wz = camBasis.rz * this.stick.dx - camBasis.fz * this.stick.dy;
        const l = Math.hypot(wx, wz) || 1;
        k.dir = { x: wx / l, z: wz / l };
        k.dirMag = Math.min(1, (this.stick.mag - 0.22) / 0.5);
      }
    }
    return k;
  }
}
