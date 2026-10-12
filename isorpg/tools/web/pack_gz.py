"""Shrink a Godot web export for static hosts with small file limits.

    python3 pack_gz.py build/web out_dir

Gzips the .wasm and .pck (39 MB -> ~10 MB) and injects a tiny fetch shim into index.html
that downloads the .gz files and inflates them in the browser with DecompressionStream.
"""
import gzip
import os
import shutil
import sys

SHIM = """<script>
(function () {
  const orig = window.fetch.bind(window);
  window.fetch = async function (input, init) {
    const url = typeof input === 'string' ? input : input.url;
    const m = /\\.(wasm|pck)(\\?.*)?$/.exec(url);
    if (!m || !('DecompressionStream' in window)) return orig(input, init);
    const res = await orig(url.replace(/\\.(wasm|pck)/, '.$1.gz'), init);
    if (!res.ok) return orig(input, init);
    const body = res.body.pipeThrough(new DecompressionStream('gzip'));
    const type = m[1] === 'wasm' ? 'application/wasm' : 'application/octet-stream';
    return new Response(body, { status: 200, headers: { 'Content-Type': type } });
  };
})();
</script>
"""


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    for name in os.listdir(src):
        p = os.path.join(src, name)
        if name.endswith((".wasm", ".pck")):
            with open(p, "rb") as f, gzip.open(os.path.join(dst, name + ".gz"), "wb", compresslevel=9) as g:
                shutil.copyfileobj(f, g)
        elif name == "index.html":
            html = open(p, encoding="utf-8").read()
            html = html.replace("<head>", "<head>\n" + SHIM, 1)
            open(os.path.join(dst, name), "w", encoding="utf-8").write(html)
        else:
            shutil.copy(p, os.path.join(dst, name))
    for name in sorted(os.listdir(dst)):
        print(f"{os.path.getsize(os.path.join(dst, name)) / 1e6:8.2f} MB  {name}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
