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


LOADER = """<style>
@font-face{font-family:Bungee;src:url(bungee.woff2) format('woff2');font-display:block}
#status,#status-splash,#status-progress{background:transparent!important}
#status-splash,#status-progress{display:none!important}
#mf{position:fixed;inset:0;z-index:5;background:#0f0d1c;color:#f4f2ff;font-family:Bungee,system-ui,sans-serif;overflow:hidden;
  display:flex;flex-direction:column;align-items:center;justify-content:center;transition:opacity .45s}
#mf.out{opacity:0;pointer-events:none}
#mf .ttl{font-size:clamp(34px,8vw,84px);line-height:.9;transform:skewX(-12deg);text-shadow:4px 4px 0 #a33a00;letter-spacing:1px}
#mf .ttl b{color:#ffb21a;font-weight:400}
#mf .chk{width:min(330px,60vw);height:10px;margin:14px 0 4px;transform:skewX(-12deg);
  background:repeating-linear-gradient(90deg,#fff 0 10px,transparent 10px 20px),repeating-linear-gradient(90deg,transparent 0 10px,#fff 10px 20px);
  background-size:20px 5px;background-position:0 0,0 5px;background-repeat:repeat-x;opacity:.85}
#mf .lines i{position:absolute;height:2px;background:rgba(255,255,255,.07);animation:mfl linear infinite}
@keyframes mfl{from{transform:translateX(110vw)}to{transform:translateX(-40vw)}}
#mf .road{position:relative;width:100%;height:70px;margin:110px 0 30px;background:#25222f}
#mf .road:before,#mf .road:after{content:"";position:absolute;left:0;right:0;height:6px;
  background:repeating-linear-gradient(90deg,#e8352b 0 24px,#fff 24px 48px);background-size:48px 6px;animation:mfr .09s linear infinite}
#mf .road:before{top:-6px}#mf .road:after{bottom:-6px}
#mf .dash{position:absolute;top:33px;left:0;right:0;height:4px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.75) 0 46px,transparent 46px 90px);
  background-size:90px 4px;animation:mfd .17s linear infinite}
@keyframes mfr{from{background-position:0 0}to{background-position:-48px 0}}
@keyframes mfd{from{background-position:0 0}to{background-position:-90px 0}}
#mf .car{position:absolute;left:50%;bottom:-22px;width:200px;margin-left:-100px;transform-origin:bottom;scale:1.6;animation:mfb .22s ease-in-out infinite alternate,mfs 3.2s ease-in-out infinite}
@keyframes mfb{from{transform:translateY(0)}to{transform:translateY(-3px)}}
@keyframes mfs{0%,100%{margin-left:-130px}50%{margin-left:-70px}}
#mf .cimg{position:relative;width:200px;height:93px}#mf .cimg img{position:absolute;left:0;top:0}#mf .whl{animation:mfw .3s linear infinite}
@keyframes mfw{to{transform:rotate(360deg)}}
#mf .puff{position:absolute;left:-14px;bottom:18px;width:14px;height:14px;border-radius:50%;background:rgba(200,196,210,.4);animation:mfp .9s linear infinite}
#mf .puff:nth-child(2){animation-delay:.3s}#mf .puff:nth-child(3){animation-delay:.6s}
@keyframes mfp{from{transform:translate(0,0) scale(.6);opacity:.8}to{transform:translate(-90px,-24px) scale(2.2);opacity:0}}
#mf .lbl{font-size:16px;margin-bottom:10px;letter-spacing:1px}
#mf .bar{width:min(520px,72vw);height:14px;background:rgba(255,255,255,.1);transform:skewX(-35deg)}
#mf .bar div{height:100%;width:0;background:#ffb21a;transition:width .25s}
#mf .tip{margin-top:26px;font:italic 600 16px system-ui,sans-serif;color:#a49ec4;text-align:center;padding:0 20px}
#mf .err{margin-top:16px;font:600 15px system-ui,sans-serif;color:#ff7a7a;text-align:center;padding:0 20px}
</style>
<div id="mf"><div class="lines"></div>
<div class="ttl">WRECK 'N' <b>ROLL</b></div><div class="chk"></div>
<div class="road"><div class="dash"></div><div class="car"><span class="puff"></span><span class="puff"></span><span class="puff"></span>
<div class="cimg"><img src="load_car.png" width="200" height="93"><img class="whl" src="load_wheel.png" style="left:124.8px;top:40.6px;width:24.3px;height:24.3px"><img class="whl" src="load_wheel.png" style="left:50.1px;top:39.3px;width:25.7px;height:25.7px"></div></div></div>
<div class="lbl" id="mf-lbl">BAIXANDO A PISTA 0%</div><div class="bar"><div id="mf-bar"></div></div>
<div class="tip" id="mf-tip"></div><div class="err" id="mf-err"></div></div>
<script>
(function(){
  var tips=["Cada volta recarrega munição e nitro.","Placas de turbo laranja dão um tranco de velocidade.","Até 4 pessoas na mesma tela, cada uma com seu controle.",
    "Online: até 8 por sala, com voz que fica mais alta quando os carros estão perto.","Foguetes perseguem quem está na frente: fuja com nitro.","Preso na mureta? R (ou BACK no controle) volta à pista."];
  var t=document.getElementById('mf-tip'); var k=Math.floor(Math.random()*tips.length); t.textContent=tips[k];
  setInterval(function(){k=(k+1)%tips.length;t.textContent=tips[k];},4000);
  var L=document.querySelector('#mf .lines');
  for(var i=0;i<22;i++){var e=document.createElement('i');e.style.top=(Math.random()*100)+'%';e.style.width=(60+Math.random()*180)+'px';
    e.style.animationDuration=(0.9+Math.random()*1.6)+'s';e.style.animationDelay=(-Math.random()*2)+'s';L.appendChild(e);}
  window.__mfProgress=function(p,label){document.getElementById('mf-bar').style.width=Math.round(p*100)+'%';
    document.getElementById('mf-lbl').textContent=(label||'BAIXANDO A PISTA')+' '+Math.round(p*100)+'%';};
  window.__mfError=function(m){document.getElementById('mf-err').textContent=m;};
  // o Godot remove o #status quando o jogo começa a desenhar: aí o carregamento some
  var obs=new MutationObserver(function(){ if(!document.getElementById('status')){ setTimeout(function(){document.getElementById('mf').classList.add('out');
    setTimeout(function(){var m=document.getElementById('mf'); if(m) m.remove();},600);},500); obs.disconnect(); } });
  obs.observe(document.body,{childList:true,subtree:true});
}());
</script>
"""

CHUNK = 4_000_000
PCK_CHUNK = 8_000_000

SHIM = """<script>
// O motor (.wasm) e o .pck vêm em pedaços (eNN.wasm / packNN.wasm); aqui eles são remontados.
(function () {
  const parts = %s;
  const packs = %s;
  const total = %d;
  let got = 0;
  const origFetch = window.fetch.bind(window);
  function report(msg) {
    console.error(msg);
    if (window.__mfError) window.__mfError(msg);
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
        if (r.ok) {
          // lê em pedaços para a barra de progresso andar suave
          if (r.body && r.body.getReader) {
            const rd = r.body.getReader(); const chunks = []; let n = 0;
            for (;;) { const s = await rd.read(); if (s.done) break; chunks.push(s.value); n += s.value.length; got += s.value.length;
              if (window.__mfProgress) window.__mfProgress(Math.min(1, got / total), got >= total ? 'LIGANDO OS MOTORES' : 'BAIXANDO A PISTA'); }
            const out = new Uint8Array(n); let o = 0; for (const c of chunks) { out.set(c, o); o += c.length; }
            return out.buffer;
          }
          const ab = await r.arrayBuffer(); got += ab.byteLength;
          if (window.__mfProgress) window.__mfProgress(Math.min(1, got / total));
          return ab;
        }
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
    here = os.path.dirname(os.path.abspath(__file__))
    open(os.path.join(dst, "bungee.woff2"), "wb").write(open(os.path.join(here, "..", "fonts", "Bungee.woff2"), "rb").read())
    for f in ("load_car.png", "load_wheel.png"):
        open(os.path.join(dst, f), "wb").write(open(os.path.join(here, "..", "ui", f), "rb").read())
    html = open(os.path.join(src, "index.html"), encoding="utf-8").read()
    style = re.search(r"<style>(.*?)</style>", html, re.S).group(1)
    body = re.search(r"<body>(.*)</body>", html, re.S).group(1)
    page = ("<title>Wreck 'n' Roll</title>\n<style>:root{color-scheme:dark}html,body{height:100%%;background:#0f0d1c}%s</style>\n%s\n%s\n%s"
            % (style, SHIM % (str(parts), str(packs), len(wasm) + len(pck)), body, LOADER))
    # versão "fragmento" (para hosts que montam o <html>) e versão completa (GitHub Pages, itch.io)
    open(os.path.join(dst, "fragment.html"), "w", encoding="utf-8").write(page)
    full = ('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no,viewport-fit=cover"></head><body>'
            + page + "</body></html>")
    open(os.path.join(dst, "index.html"), "w", encoding="utf-8").write(full)
    print("ok:", len(parts), "pedaços do motor e", len(packs), "do pck em", dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
