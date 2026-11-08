"""
Empacota o export Web do Godot para hospedagens com limite de tamanho por arquivo (ex.: 15 MB).

O .wasm do motor (~40 MB) é dividido em pedaços de 4 MB (eNN.wasm) e o .pck (jogo + músicas) em
pedaços de 8 MB (packNN.wasm).
Um pequeno script no HTML intercepta o fetch do Godot, baixa os pedaços em sequência (com novas
tentativas) e remonta os arquivos no navegador. Erros aparecem na tela.

Uso (dentro de minifuria/):
    godot --headless --export-release "Web" build/web/index.html
    python3 tools/pack_web.py build/web build/web_split
"""
import os
import re
import sys

CHUNK = 4_000_000
PCK_CHUNK = 8_000_000

SHIM = """<script>
// O motor (.wasm) e o .pck vêm em pedaços (eNN.wasm / packNN.wasm); aqui eles são remontados.
(function () {
  const parts = %s;
  const packs = %s;
  const origFetch = window.fetch.bind(window);
  function report(msg) {
    console.error(msg);
    window.__loadError = msg;
    const n = document.getElementById('status-notice');
    if (n) { n.textContent = msg; n.style.display = 'block'; document.getElementById('status').style.visibility = 'visible'; }
  }
  async function getOne(name) {
    const url = new URL(name, document.baseURI).href;
    let last = '';
    for (let i = 0; i < 4; i++) {
      try {
        const r = await origFetch(url, { cache: 'force-cache' });
        if (r.ok) return await r.arrayBuffer();
        last = 'HTTP ' + r.status;
      } catch (e) { last = String(e && e.message || e); }
      await new Promise((ok) => setTimeout(ok, 600 * (i + 1)));
    }
    throw new Error('Falha ao baixar ' + name + ' (' + last + ')');
  }
  async function joined(names, type) {
    const bufs = [];
    for (const n of names) bufs.push(await getOne(n));
    const blob = new Blob(bufs, { type });
    return new Response(blob, { status: 200, headers: { 'Content-Type': type, 'Content-Length': String(blob.size) } });
  }
  window.fetch = function (input, init) {
    const url = typeof input === 'string' ? input : (input && input.url) || '';
    const path = url.split('?')[0];
    if (path.endsWith('index.wasm')) return joined(parts, 'application/wasm').catch((e) => { report(e.message); throw e; });
    if (path.endsWith('index.pck')) return joined(packs, 'application/octet-stream').catch((e) => { report(e.message); throw e; });
    return origFetch(input, init);
  };
  window.addEventListener('error', (e) => report('Erro: ' + (e.message || e)));
  window.addEventListener('unhandledrejection', (e) => report('Erro: ' + (e.reason && e.reason.message || e.reason)));
}());
</script>"""


def main(src: str, dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if re.fullmatch(r"e\d\d\.wasm", f) or re.fullmatch(r"pack(\d\d)?\.wasm", f):
            os.remove(os.path.join(dst, f))
    wasm = open(os.path.join(src, "index.wasm"), "rb").read()
    parts = []
    for i in range(0, len(wasm), CHUNK):
        name = "e%02d.wasm" % (i // CHUNK)
        open(os.path.join(dst, name), "wb").write(wasm[i:i + CHUNK])
        parts.append(name)
    pck = open(os.path.join(src, "index.pck"), "rb").read()
    packs = []
    for i in range(0, len(pck), PCK_CHUNK):
        name = "pack%02d.wasm" % (i // PCK_CHUNK)
        open(os.path.join(dst, name), "wb").write(pck[i:i + PCK_CHUNK])
        packs.append(name)
    for f in ("index.js", "index.audio.worklet.js", "index.audio.position.worklet.js", "index.png"):
        open(os.path.join(dst, f), "wb").write(open(os.path.join(src, f), "rb").read())
    html = open(os.path.join(src, "index.html"), encoding="utf-8").read()
    style = re.search(r"<style>(.*?)</style>", html, re.S).group(1)
    body = re.search(r"<body>(.*)</body>", html, re.S).group(1)
    page = ("<title>Mini Fúria</title>\n<style>:root{color-scheme:dark}html,body{height:100%%;background:#1b1530}%s</style>\n%s\n%s"
            % (style, SHIM % (str(parts), str(packs)), body))
    # versão "fragmento" (para hosts que montam o <html>) e versão completa (GitHub Pages, itch.io)
    open(os.path.join(dst, "fragment.html"), "w", encoding="utf-8").write(page)
    full = ('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no,viewport-fit=cover"></head><body>'
            + page + "</body></html>")
    open(os.path.join(dst, "index.html"), "w", encoding="utf-8").write(full)
    print("ok:", len(parts), "pedaços do motor e", len(packs), "do pck em", dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
