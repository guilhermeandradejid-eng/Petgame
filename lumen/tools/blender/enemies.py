"""enemies.py: gera os inimigos do Lumen (rig + malha + clipes) em assets/models/enemy_<id>.glb
e o manifesto assets/models/enemies_manifest.json.

uso: python3 tools/blender/enemies.py [id ...] [--out pasta] [--noanim] [--check]
Sem ids gera todos. Cada inimigo mora num modulo en_<id>.py com:
  ID, NAME, RADIUS, HEIGHT, BONES, model() -> Geo, clips(sk, geo) -> [(Clip, quadro_do_acerto|None)]
"""
import importlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402,F401

import anim  # noqa: E402
import lp  # noqa: E402
import en_base as eb  # noqa: E402

MODELS = os.path.join(HERE, '..', '..', 'assets', 'models')
ALL = ['broto', 'cogu', 'fagulha', 'cascudo', 'sentinela', 'guardiao']


def build(eid, out_dir, noanim=False, check=False):
    mod = importlib.import_module('en_' + eid)
    lp.reset_scene()
    arm = lp.make_armature(eid + '_rig', mod.BONES)
    geo = mod.model()
    names = {b[0] for b in mod.BONES}
    for i, ws in enumerate(geo.w):
        if not ws:
            raise SystemExit('%s: vertice %d sem peso (%s)' % (eid, i, tuple(geo.v[i])))
        for b in ws:
            if b not in names:
                raise SystemExit('%s: osso desconhecido %s' % (eid, b))
    ob = lp.to_object(geo, eid)
    lp.skin_to(ob, arm)
    entry = {'name': mod.NAME, 'radius': mod.RADIUS, 'height': mod.HEIGHT, 'anims': {}}
    sk = eb.Skel(mod.BONES)
    if not noanim:
        clips = mod.clips(sk, geo)
        rig = anim.Rig(arm)
        rig.bake_all([c for c, _ in clips])
        for c, hit in clips:
            unknown = [ch for ch in c.tracks if anim.channel_bone(ch.replace('.pos', '').replace('.scale', ''))
                       not in names and ch != 'lift' and not ch.endswith(('.ik', '.pole', '.wrot'))]
            if unknown:
                print('  AVISO %s/%s: canais sem osso: %s' % (eid, c.name, unknown))
            a = {'len': round(c.length / float(eb.FPS), 3)}
            if hit is not None:
                a['hit'] = round(hit / float(eb.FPS), 3)
            entry['anims'][c.name] = a
            if check:
                lows = [eb.mesh_low(sk, geo, c, f) for f in range(c.length + 1)]
                fwd = [-(sk.fk(sk.vals(c, f))[mod.BONES[1][0]] @ sk.head[mod.BONES[1][0]]).y +
                       sk.head[mod.BONES[1][0]].y for f in range(c.length + 1)]
                print('  %-14s len %2d  min z %+.3f (q%d)  fim z %+.3f  frente max %+.2f fim %+.2f' % (
                    c.name, c.length, min(lows), lows.index(min(lows)), lows[-1], max(fwd, key=abs), fwd[-1]))
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, 'enemy_%s.glb' % eid)
    lp.export_glb(path, animations=not noanim)
    b0, b1 = geo.bounds()
    print('%s: %d tris, %d ossos, %d clipes, caixa x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f -> %s' % (
        eid, geo.tris(), len(mod.BONES), len(entry['anims']), b0[0], b1[0], b0[1], b1[1], b0[2], b1[2], path))
    entry['tris'] = geo.tris()
    return entry


def main():
    args = sys.argv[1:]
    out_dir = MODELS
    noanim = False
    check = False
    ids = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--out':
            out_dir = args[i + 1]
            i += 1
        elif a == '--noanim':
            noanim = True
        elif a == '--check':
            check = True
        else:
            ids.append(a)
        i += 1
    ids = ids or ALL
    mpath = os.path.join(out_dir, 'enemies_manifest.json')
    manifest = {}
    if os.path.exists(mpath):
        with open(mpath) as f:
            manifest = json.load(f)
    for eid in ids:
        entry = build(eid, out_dir, noanim, check)
        if noanim and eid in manifest:
            entry['anims'] = manifest[eid].get('anims', {})
        manifest[eid] = entry
    manifest = {k: manifest[k] for k in ALL if k in manifest}
    with open(mpath, 'w') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
