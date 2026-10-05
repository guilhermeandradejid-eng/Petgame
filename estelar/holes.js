/* Gramado Estelar — course data.
   Map tokens (one per tile, rows = y, columns = x):
     ..  void (fall)        gN grass at height N   sN sand   wN water   iN ice   bN bumper on grass
     XN  dash +x   xN dash -x   YN dash +y   yN dash -y
     AN  slope rising toward +x (from N to N+1)   BN  toward +y   CN  toward -x   DN  toward -y
   Enemies: gota (blob), cogu (walker, patrols), piu (flyer, needs a jump shot), ourico (spiky, can't be beaten).
   An enemy with `ab` hands its ability to the ball: rocha (stop dead), turbo (dash), mola (bounce). */
window.HOLES = [
  {
    name: 'Brisa da Manhã', par: 2, start: [1.5, 1.5],
    map: [
      'g0 g0 g0 g0 g0 g0 g0',
      'g0 g0 g0 g0 g0 g0 g0',
      'g0 g0 g0 g0 g0 g0 g0',
      'g0 g0 g0 g0 g0 g0 g0',
    ],
    enemies: [{ t: 'gota', x: 5.5, y: 2.5 }],
    tip: 'Arraste para trás e solte para tacar',
  },
  {
    name: 'Degraus', par: 3, start: [1.5, 2.5],
    map: [
      'g0 g0 g0 g0 A0 g1 s1 g1 g1',
      'g0 g0 g0 g0 A0 g1 s1 g1 g1',
      'g0 g0 g0 g0 A0 g1 g1 g1 g1',
      'g0 g0 g0 g0 A0 g1 g1 g1 g1',
      'g0 g0 g0 g0 A0 g1 g1 g1 g1',
    ],
    enemies: [{ t: 'cogu', x: 7.5, y: 1.5, axis: 'y', range: 1.2 }, { t: 'gota', x: 7.5, y: 3.8 }],
    tip: 'Rampas aceleram e freiam. Areia segura a bola',
  },
  {
    name: 'Lago Rosado', par: 4, start: [0.5, 3.5],
    map: [
      'g0 g0 g0 g0 g0 g0 g0 g0 g0',
      'g0 g0 g0 g0 g0 g0 g0 g0 g0',
      'g0 g0 w0 w0 w0 w0 w0 g0 g0',
      'g0 g0 w0 w0 w0 w0 w0 g0 g0',
      'g0 g0 w0 w0 w0 w0 w0 g0 g0',
      'g0 g0 g0 g0 g0 g0 g0 g0 g0',
      'g0 g0 g0 g0 g0 g0 g0 g0 g0',
    ],
    enemies: [{ t: 'piu', x: 4.5, y: 0.9 }, { t: 'gota', x: 8.2, y: 3.5 }, { t: 'gota', x: 4.5, y: 5.6 }],
    tip: 'O Piu voa: ligue o PULO para acertá-lo',
  },
  {
    name: 'Fliperama', par: 3, start: [0.5, 2.5],
    map: [
      'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
      'g0 X0 X0 g0 g0 b0 g0 g0 b0 g0',
      'g0 g0 g0 g0 b0 g0 g0 b0 g0 g0',
      'g0 X0 X0 g0 g0 b0 g0 g0 i0 i0',
      'g0 g0 g0 g0 g0 g0 g0 i0 i0 i0',
    ],
    enemies: [{ t: 'cogu', x: 6.5, y: 0.5, axis: 'x', range: 1.5, ab: 'rocha' }, { t: 'ourico', x: 3.5, y: 2.5 }, { t: 'gota', x: 9.4, y: 4.4 }],
    tip: 'Setas dão turbo. No gelo, use a ROCHA para parar',
  },
  {
    name: 'Ilhas no Céu', par: 4, start: [1.0, 2.0],
    map: [
      'g0 g0 g0 g0 .. .. g1 g1 g1',
      'g0 g0 g0 g0 .. .. g1 g1 g1',
      'g0 g0 g0 g0 .. .. g1 s1 g1',
      'g0 g0 g0 g0 g0 g0 A0 g1 g1',
    ],
    enemies: [{ t: 'gota', x: 2.5, y: 0.5, ab: 'mola' }, { t: 'piu', x: 5.0, y: 1.2 }, { t: 'ourico', x: 7.5, y: 1.5 }, { t: 'gota', x: 8.4, y: 0.5 }],
    tip: 'Cuidado com o vão: cair custa uma tacada',
  },
  {
    name: 'Pico Estelar', par: 5, start: [0.5, 8.4],
    map: [
      'g0 g0 g0 g0 g0 g0 g0 g0 g0',
      'g0 g1 g1 g1 B0 g1 g1 g1 g0',
      'g0 g1 s1 g1 B1 g1 s1 g1 g0',
      'g0 g1 g1 g2 g2 g2 g1 g1 g0',
      'g0 A0 g1 g2 g2 g2 g1 C0 g0',
      'g0 g1 g1 g2 g2 g2 g1 g1 g0',
      'g0 g1 s1 g1 g1 g1 s1 g1 g0',
      'g0 g1 g1 g1 D0 g1 g1 g1 g0',
      'g0 g0 g0 g0 g0 g0 g0 g0 g0',
    ],
    enemies: [{ t: 'cogu', x: 1.5, y: 1.5, axis: 'x', range: 0.9, ab: 'turbo' }, { t: 'piu', x: 7.5, y: 7.5 }, { t: 'ourico', x: 2.5, y: 4.5 }, { t: 'gota', x: 4.5, y: 4.5 }],
    tip: 'Suba as rampas até o topo do pico',
  },
];
