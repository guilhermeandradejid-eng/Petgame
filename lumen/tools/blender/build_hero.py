"""build_hero.py: gera o heroi (rig + pecas + animacoes) em glb.

uso: python3 build_hero.py [--out caminho.glb] [--mods wd_hair,wd_hats] [--noanim] [clipes...]
Sem --out grava em assets/models/hero.glb e o manifesto hero_manifest.json ao lado.
"""
import glob
import importlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import lp  # noqa: E402
import anim  # noqa: E402
import hero_body as hb  # noqa: E402
import wd_base  # noqa: E402

DEFAULT_OUT = os.path.join(HERE, '..', '..', 'assets', 'models', 'hero.glb')


def main():
    args = sys.argv[1:]
    out = DEFAULT_OUT
    mods = None
    noanim = False
    only = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--out':
            out = args[i + 1]
            i += 1
        elif a == '--mods':
            mods = args[i + 1].split(',')
            i += 1
        elif a == '--noanim':
            noanim = True
        else:
            only.append(a)
        i += 1
    if mods is None:
        mods = sorted(os.path.basename(p)[:-3] for p in glob.glob(os.path.join(HERE, 'wd_*.py')))
        mods = [m for m in mods if m != 'wd_base']
    for m in mods:
        importlib.import_module(m)

    lp.reset_scene()
    arm = lp.make_armature('HeroRig', hb.BONES)

    def add(name, geo):
        ob = lp.to_object(geo, name)
        lp.skin_to(ob, arm)
        return ob

    add('base_head', lp.merge(hb.make_head(), hb.make_ears_human()))
    add('base_hands', hb.make_hands())
    for style in hb.EYE_STYLES:
        add('eyes_' + style, hb.make_face(style))
    manifest = {}
    total = 0
    for name, info in wd_base.PIECES.items():
        g = info['fn']()
        top = None
        if isinstance(g, tuple):
            g, top = g
        tris = g.tris() + (top.tris() if top else 0)
        total += tris
        add(name, g)
        entry = {k: v for k, v in info.items() if k != 'fn'}
        entry['tris'] = tris
        if top is not None and len(top.f) > 0:
            add(name + '__top', top)
            entry['has_top'] = True
        manifest[name] = entry
    slots = {info['slot'] for info in wd_base.PIECES.values()}
    if out != DEFAULT_OUT:
        # builds parciais (previews): completa com a roupa de referencia
        if 'top' not in slots:
            add('_ref_top', wd_base.ref_top())
        if 'bottom' not in slots:
            add('_ref_bottom', wd_base.ref_bottom())
        if 'hair' not in slots:
            rb, rt = wd_base.ref_hair()
            add('_ref_hair', lp.merge(rb, rt))
    if not noanim:
        import hero_anim
        rig = anim.Rig(arm, skip=hb.CODE_BONES)
        clips = hero_anim.build_clips()
        if only:
            clips = [c for c in clips if c.name in only]
        rig.bake_all(clips)
        print('animacoes:', len(clips))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    lp.export_glb(out, animations=not noanim)
    with open(os.path.splitext(out)[0] + '_manifest.json', 'w') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print('pecas:', len(manifest), 'tris nas pecas:', total, '->', out)


main()
