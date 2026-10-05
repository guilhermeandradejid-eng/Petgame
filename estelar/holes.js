/* Gramado Estelar — course data.
   Map tokens (one per tile, rows = y, columns = x):
     ..  void (fall)        gN grass at height N   sN sand   wN water   iN ice   bN bumper   tN tree
     XN  dash +x   xN dash -x   YN dash +y   yN dash -y
     AN  slope rising toward +x (from N to N+1)   BN  toward +y   CN  toward -x   DN  toward -y
   Enemies: gota (blob), cogu (walker, patrols), piu (flyer, needs a jump shot), ourico (spiky, can't be beaten).
   An enemy with `ab` hands its ability to the ball: rocha (stop dead), turbo (dash), mola (bounce). */
(() => {
  // the summit: rings of height 0, 1 and 2 with ramps between them
  function pyramid() {
    const N = 11, rows = [];
    for (let y = 0; y < N; y++) {
      const r = [];
      for (let x = 0; x < N; x++) {
        const d = Math.min(x, y, N - 1 - x, N - 1 - y);
        const h = d < 2 ? 0 : d < 4 ? 1 : 2;
        r.push('g' + h);
      }
      rows.push(r);
    }
    const set = (x, y, t) => { rows[y][x] = t; };
    set(5, 1, 'B0'); set(9, 5, 'C0'); set(5, 9, 'D0');
    set(3, 5, 'A1'); set(7, 5, 'C1');
    set(2, 2, 's1'); set(8, 2, 's1'); set(2, 8, 's1'); set(8, 8, 's1');
    set(5, 4, 'i2'); set(5, 6, 'i2');
    set(0, 0, 't0'); set(10, 0, 't0'); set(10, 10, 't0'); set(1, 6, 't0');
    return rows.map((r) => r.join(' '));
  }

  window.HOLES = [
    {
      name: 'Brisa da Manhã', par: 3, start: [1.5, 2.5],
      map: [
        'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
        'g0 g0 g0 g0 g0 t0 g0 g0 g0 g0 g0 g0',
        'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
        'g0 g0 g0 g0 g0 g0 g0 g0 t0 g0 g0 g0',
        'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
        'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
      ],
      enemies: [{ t: 'gota', x: 6.5, y: 4.3 }, { t: 'gota', x: 10.5, y: 1.5 }],
      tip: 'Puxe a bolinha para trás e solte. Arraste o cenário para olhar o campo',
    },
    {
      name: 'Degraus', par: 4, start: [1.5, 3.5],
      map: [
        'g0 g0 g0 g0 A0 g1 g1 g1 g1 A1 g2 g2',
        'g0 g0 g0 g0 A0 g1 s1 s1 g1 A1 g2 g2',
        'g0 g0 t0 g0 A0 g1 s1 s1 g1 g1 g2 g2',
        'g0 g0 g0 g0 g1 g1 g1 g1 g1 A1 g2 g2',
        'g0 g0 g0 g0 A0 g1 g1 g1 g1 A1 g2 g2',
        'g0 g0 g0 g0 A0 g1 t1 g1 g1 A1 g2 g2',
        'g0 g0 g0 g0 A0 g1 g1 g1 g1 g1 g2 t2',
      ],
      enemies: [{ t: 'cogu', x: 7.5, y: 4.5, axis: 'y', range: 1.2 }, { t: 'gota', x: 10.8, y: 3.5 }, { t: 'gota', x: 11.0, y: 0.6 }],
      tip: 'Rampas aceleram e freiam. A areia segura a bola',
    },
    {
      name: 'Lago Rosado', par: 5, start: [0.5, 4.5],
      map: [
        'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
        'g0 t0 g0 g0 g0 g0 g0 g0 g0 t0 g0',
        'g0 g0 g0 w0 w0 w0 w0 w0 g0 g0 g0',
        'g0 g0 w0 w0 w0 w0 w0 w0 w0 g0 g0',
        'g0 g0 w0 w0 w0 g0 g0 w0 w0 g0 g0',
        'g0 g0 w0 w0 w0 g0 g0 w0 w0 g0 g0',
        'g0 g0 g0 w0 w0 w0 w0 w0 g0 g0 g0',
        'g0 t0 g0 g0 g0 g0 g0 g0 g0 t0 g0',
        'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
      ],
      enemies: [{ t: 'piu', x: 5.5, y: 1.2 }, { t: 'gota', x: 10.3, y: 4.5 }, { t: 'gota', x: 5.5, y: 7.8 }, { t: 'gota', x: 6.0, y: 5.0 }],
      tip: 'O Piu voa: ligue o PULO. Há uma gotinha na ilhota do lago',
    },
    {
      name: 'Fliperama', par: 4, start: [0.5, 3.5],
      map: [
        'g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0 g0',
        'g0 X0 X0 g0 g0 b0 g0 g0 b0 g0 g0 g0',
        'g0 g0 g0 g0 b0 g0 g0 b0 g0 g0 b0 g0',
        'g0 X0 X0 g0 g0 g0 b0 g0 g0 b0 g0 g0',
        'g0 g0 g0 g0 b0 g0 g0 b0 g0 g0 i0 i0',
        'g0 X0 X0 g0 g0 b0 g0 g0 i0 i0 i0 i0',
        'g0 g0 g0 g0 g0 g0 g0 i0 i0 i0 i0 i0',
      ],
      enemies: [{ t: 'cogu', x: 6.5, y: 0.5, axis: 'x', range: 2, ab: 'rocha' }, { t: 'ourico', x: 3.5, y: 3.5 }, { t: 'gota', x: 11.4, y: 6.4 }, { t: 'gota', x: 10.5, y: 0.6 }],
      tip: 'Setas dão turbo. No gelo, use a ROCHA para parar',
    },
    {
      name: 'Ilhas no Céu', par: 6, start: [1.0, 3.5],
      map: [
        'g0 g0 g0 g0 .. .. g1 g1 g1 .. .. g2 g2',
        'g0 g0 g0 g0 .. .. g1 g1 g1 .. .. g2 g2',
        'g0 t0 g0 g0 .. .. g1 s1 g1 .. .. g2 g2',
        'g0 g0 g0 g0 g0 g0 A0 g1 g1 .. .. g2 g2',
        'g0 g0 g0 g0 .. .. g1 g1 g1 g1 g1 A1 g2',
        'g0 g0 g0 g0 .. .. g1 g1 t1 .. .. g2 g2',
        'g0 g0 g0 g0 .. .. g1 g1 g1 .. .. g2 t2',
      ],
      enemies: [{ t: 'gota', x: 2.5, y: 0.6, ab: 'mola' }, { t: 'piu', x: 5.0, y: 1.5 }, { t: 'ourico', x: 7.5, y: 1.5 }, { t: 'gota', x: 7.5, y: 5.6 }, { t: 'gota', x: 12.4, y: 0.6 }, { t: 'cogu', x: 11.8, y: 5.4, axis: 'y', range: 0.35 }],
      tip: 'Use as pontes ou pule os vãos. Cair custa uma tacada',
    },
    {
      name: 'Pico Estelar', par: 6, start: [0.6, 10.3],
      map: pyramid(),
      enemies: [{ t: 'cogu', x: 2.5, y: 2.6, axis: 'x', range: 0.4, ab: 'turbo' }, { t: 'piu', x: 8.5, y: 8.5 }, { t: 'ourico', x: 5.5, y: 2.6 }, { t: 'gota', x: 9.5, y: 1.0 }, { t: 'gota', x: 5.5, y: 5.5 }],
      tip: 'Suba as rampas até o topo do pico',
    },
  ];
  // the floating island on the title screen
  window.TITLE_ISLAND = {
    name: 'title', par: 0, start: [2.5, 2.5],
    map: ['t0 g0 g0 g0 g0', 'g0 g0 g0 g0 g0', 'g0 g0 g0 g0 g0', 'g0 g0 g0 g0 t0', 'w0 w0 g0 g0 g0'],
    enemies: [{ t: 'gota', x: 4.3, y: 1.0 }, { t: 'piu', x: 0.8, y: 3.2 }],
  };
})();
