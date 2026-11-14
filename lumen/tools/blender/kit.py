"""kit.py: registro e exportacao de kits de objetos estaticos (cenario, props, coletaveis).

Cada objeto e uma funcao decorada com @prop(...) que devolve uma Geo centrada na origem,
com a base em z=0, olhando para -Y. O kit vira um unico .glb com uma malha por objeto
(todas na origem; o jogo instancia por nome) e um manifesto json ao lado.

    from kit import Kit
    kit = Kit('env_forest')

    @kit.prop('rock_a', collider=('cyl', 0.6, 0.8), tags=['rock', 'small'])
    def rock_a():
        return lp.icosphere(...)

    if __name__ == '__main__':
        kit.build()        # python3 env_forest.py [--out caminho.glb] [--only rock_a,tree_b]

collider: None | ('cyl', raio, altura) | ('box', largura_x, profundidade_y, altura_z)
tags: lista livre de etiquetas usadas pelo gerador de salas (ex.: 'tree', 'wall', 'deco').
Outros metadados (ex.: light=dict(color='#ffcc88', energy=1.5, height=1.2, range=5)) vao
direto para o manifesto.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lp  # noqa: E402

MODELS = os.path.join(HERE, '..', '..', 'assets', 'models')


class Kit:
    def __init__(self, name):
        self.name = name
        self.props = {}

    def prop(self, name, collider=None, tags=(), **meta):
        def deco(fn):
            self.props[name] = dict(fn=fn, collider=collider, tags=list(tags), **meta)
            return fn
        return deco

    def build(self, argv=None):
        argv = sys.argv[1:] if argv is None else argv
        out = os.path.join(MODELS, self.name + '.glb')
        only = None
        i = 0
        while i < len(argv):
            if argv[i] == '--out':
                out = argv[i + 1]
                i += 1
            elif argv[i] == '--only':
                only = argv[i + 1].split(',')
                i += 1
            i += 1
        lp.reset_scene()
        manifest = {}
        total = 0
        for name, info in self.props.items():
            if only and name not in only:
                continue
            g = info['fn']()
            b0, b1 = g.bounds()
            total += g.tris()
            lp.to_object(g, name)
            entry = {k: v for k, v in info.items() if k != 'fn'}
            col = entry.pop('collider')
            if col is None:
                entry['collider'] = None
            elif col[0] == 'cyl':
                entry['collider'] = {'type': 'cyl', 'r': col[1], 'h': col[2]}
            else:
                entry['collider'] = {'type': 'box', 'w': col[1], 'd': col[2], 'h': col[3]}
            entry['tris'] = g.tris()
            entry['size'] = [round(b1[0] - b0[0], 3), round(b1[1] - b0[1], 3), round(b1[2], 3)]
            manifest[name] = entry
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        lp.export_glb(out, animations=False)
        with open(os.path.splitext(out)[0] + '_manifest.json', 'w') as f:
            json.dump(manifest, f, ensure_ascii=False, indent=1)
        print('objetos:', len(manifest), 'tris:', total, '->', out)
