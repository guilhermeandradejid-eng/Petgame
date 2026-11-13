"""Troca `var x :=` por `var x =` nas linhas onde o Godot não consegue inferir o tipo."""
import re, subprocess, sys, os
GAME = os.path.join(os.path.dirname(__file__), "..", "game")
for it in range(12):
    out = subprocess.run([os.path.expanduser("~/.local/bin/godot"), "--headless", "--path", GAME, "res://tests/check.tscn"],
                         capture_output=True, text=True, timeout=120); out = out.stdout + out.stderr
    errs = re.findall(r'Cannot infer the type of "(\w+)" variable.*?\n\s+at: GDScript::reload \(res://([^:]+):(\d+)\)', out)
    if not errs:
        print(out[-3000:])
        break
    for name, path, line in errs:
        fp = os.path.join(GAME, path)
        L = open(fp).read().split("\n")
        i = int(line) - 1
        L[i] = re.sub(r'\bvar %s :=' % name, 'var %s =' % name, L[i], count=1)
        L[i] = re.sub(r'\bfor %s :=' % name, 'for %s =' % name, L[i], count=1)
        open(fp, "w").write("\n".join(L))
    print("iter", it, "corrigidos", len(errs))
