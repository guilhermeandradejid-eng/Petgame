// Sons 100% sintetizados com Web Audio: motor com troca de marchas, pneu cantando, turbo, batidas.
export class Sfx {
  constructor() {
    this.ctx = null;
    this.muted = false;
    try { this.muted = localStorage.getItem('minifuria.mute') === '1'; } catch (e) { /* sem storage */ }
  }

  init() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    const ctx = this.ctx = new AC();
    this.master = ctx.createGain();
    this.master.gain.value = this.muted ? 0 : 0.7;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14; comp.ratio.value = 4;
    this.master.connect(comp); comp.connect(ctx.destination);

    // buffer de ruído compartilhado
    const len = ctx.sampleRate * 2;
    this.noise = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = this.noise.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;

    // motor: dente-de-serra + quadrada uma oitava abaixo, filtro passa-baixa
    this.eng = ctx.createGain(); this.eng.gain.value = 0;
    this.engF = ctx.createBiquadFilter(); this.engF.type = 'lowpass'; this.engF.frequency.value = 900; this.engF.Q.value = 3;
    this.o1 = ctx.createOscillator(); this.o1.type = 'sawtooth';
    this.o2 = ctx.createOscillator(); this.o2.type = 'square';
    const g2 = ctx.createGain(); g2.gain.value = 0.5;
    this.o1.connect(this.engF); this.o2.connect(g2); g2.connect(this.engF);
    this.engF.connect(this.eng); this.eng.connect(this.master);
    this.o1.start(); this.o2.start();

    // pneu: ruído em passa-banda
    this.tire = ctx.createGain(); this.tire.gain.value = 0;
    const ts = this.loopNoise();
    const tf = ctx.createBiquadFilter(); tf.type = 'bandpass'; tf.frequency.value = 1500; tf.Q.value = 6;
    this.tireF = tf;
    ts.connect(tf); tf.connect(this.tire); this.tire.connect(this.master);

    // turbo: ruído passa-baixa com ressonância
    this.boost = ctx.createGain(); this.boost.gain.value = 0;
    const bs = this.loopNoise();
    this.boostF = ctx.createBiquadFilter(); this.boostF.type = 'lowpass'; this.boostF.frequency.value = 600; this.boostF.Q.value = 8;
    bs.connect(this.boostF); this.boostF.connect(this.boost); this.boost.connect(this.master);

    // vento (velocidade)
    this.wind = ctx.createGain(); this.wind.gain.value = 0;
    const ws = this.loopNoise();
    const wf = ctx.createBiquadFilter(); wf.type = 'highpass'; wf.frequency.value = 2500;
    ws.connect(wf); wf.connect(this.wind); this.wind.connect(this.master);
  }

  loopNoise() {
    const s = this.ctx.createBufferSource();
    s.buffer = this.noise; s.loop = true;
    s.loopStart = Math.random(); s.start(0, Math.random());
    return s;
  }

  setMuted(m) {
    this.muted = m;
    try { localStorage.setItem('minifuria.mute', m ? '1' : '0'); } catch (e) { /* ok */ }
    if (this.master) this.master.gain.setTargetAtTime(m ? 0 : 0.7, this.ctx.currentTime, 0.05);
  }

  // speed01: 0..1(+), throttle 0..1, slip 0..1, boosting bool, timeScale para slow-mo
  update(speed01, throttle, slip, boosting, timeScale, active) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    // marchas: cada marcha sobe o giro e cai na troca
    const gears = 5;
    const g = Math.min(gears - 1, Math.floor(speed01 * gears * 0.999));
    const frac = speed01 * gears - g;
    const rpm = 0.25 + frac * 0.75 * (0.6 + throttle * 0.4) + g * 0.04;
    const pitch = timeScale < 0.6 ? 0.55 : 1;
    const f = (48 + rpm * 120 + (boosting ? 25 : 0)) * pitch;
    this.o1.frequency.setTargetAtTime(f, t, 0.04);
    this.o2.frequency.setTargetAtTime(f * 0.5, t, 0.04);
    this.engF.frequency.setTargetAtTime(500 + rpm * 1800 + throttle * 600, t, 0.05);
    this.eng.gain.setTargetAtTime(active ? 0.06 + throttle * 0.06 : 0, t, 0.08);
    this.tire.gain.setTargetAtTime(active ? Math.min(0.22, slip * 0.28) : 0, t, 0.05);
    this.tireF.frequency.setTargetAtTime(1200 + slip * 900, t, 0.1);
    this.boost.gain.setTargetAtTime(active && boosting ? 0.2 : 0, t, 0.08);
    this.boostF.frequency.setTargetAtTime(boosting ? 1400 : 400, t, 0.3);
    this.wind.gain.setTargetAtTime(active ? Math.max(0, speed01 - 0.3) * 0.12 : 0, t, 0.2);
  }

  // ---------- one-shots
  env(node, t, a, peak, dec) {
    node.gain.setValueAtTime(0.0001, t);
    node.gain.exponentialRampToValueAtTime(peak, t + a);
    node.gain.exponentialRampToValueAtTime(0.0001, t + a + dec);
  }

  noiseHit(dur, f0, f1, vol, type = 'lowpass', q = 1) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const s = this.ctx.createBufferSource(); s.buffer = this.noise;
    const f = this.ctx.createBiquadFilter(); f.type = type; f.Q.value = q;
    f.frequency.setValueAtTime(f0, t); f.frequency.exponentialRampToValueAtTime(Math.max(40, f1), t + dur);
    const g = this.ctx.createGain();
    this.env(g, t, 0.005, vol, dur);
    s.connect(f); f.connect(g); g.connect(this.master);
    s.start(t, Math.random()); s.stop(t + dur + 0.05);
  }

  tone(freq, dur, vol, type = 'square', slide = 0, delay = 0) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime + delay;
    const o = this.ctx.createOscillator(); o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t + dur);
    const g = this.ctx.createGain();
    this.env(g, t, 0.005, vol, dur);
    o.connect(g); g.connect(this.master);
    o.start(t); o.stop(t + dur + 0.05);
  }

  crash(power) {
    const p = Math.min(1, power);
    this.noiseHit(0.5 + p * 0.6, 3000, 120, 0.5 + p * 0.5);
    this.tone(90, 0.4 + p * 0.3, 0.5 * p + 0.2, 'sine', -60);
    this.noiseHit(0.25, 6000, 2000, 0.25 * p, 'highpass');  // vidro
  }
  bump(power) { this.noiseHit(0.15, 1600, 200, Math.min(0.5, 0.1 + power * 0.03)); this.tone(110, 0.12, 0.15, 'sine', -40); }
  scrape(power) { this.noiseHit(0.08, 4000, 2500, Math.min(0.12, power * 0.02), 'bandpass', 4); }
  whoosh() { this.noiseHit(0.35, 400, 3000, 0.35, 'bandpass', 3); }
  boostKick() { this.noiseHit(0.5, 200, 2400, 0.4, 'lowpass', 6); this.tone(160, 0.3, 0.15, 'sawtooth', 300); }
  pad() { this.tone(520, 0.08, 0.15, 'square'); this.tone(780, 0.08, 0.15, 'square', 0, 0.06); this.tone(1040, 0.12, 0.15, 'square', 0, 0.12); }
  land(power) { this.tone(70, 0.2, Math.min(0.5, 0.15 + power * 0.03), 'sine', -30); this.noiseHit(0.12, 900, 120, 0.2); }
  smash() { this.noiseHit(0.12, 2500, 400, 0.22); this.tone(300, 0.08, 0.08, 'triangle', -150); }
  takedown() {
    this.crash(1);
    [523, 659, 784, 1046].forEach((f, i) => this.tone(f, 0.18, 0.18, 'square', 0, 0.1 + i * 0.08));
  }
  beep(hi) { this.tone(hi ? 880 : 440, hi ? 0.5 : 0.18, 0.25, 'square'); }
  lap() { [659, 784, 988, 1318].forEach((f, i) => this.tone(f, 0.15, 0.16, 'triangle', 0, i * 0.07)); }
  combo(n) { this.tone(600 + n * 80, 0.1, 0.12, 'triangle', 200); }
}
