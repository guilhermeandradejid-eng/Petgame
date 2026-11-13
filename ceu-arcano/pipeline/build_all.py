"""Regenera todos os assets do Céu Arcano.

    python3 pipeline/build_all.py              # tudo
    python3 pipeline/build_all.py chars        # só personagens
    python3 pipeline/build_all.py stage audio  # cenário e áudio

Etapas:
  chars  -> pipeline/characters/build_characters.py  (rig de pixel art em Python)
  stage  -> pipeline/blender/build_stage.py           (Blender/bpy: cenário + VFX 3D)
  audio  -> pipeline/audio/build_audio.py             (síntese de efeitos e músicas)
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
STEPS = {
    "chars": ("characters", "build_characters.py"),
    "stage": ("blender", "build_stage.py"),
    "audio": ("audio", "build_audio.py"),
}


def run(name):
    folder, script = STEPS[name]
    t0 = time.time()
    print(f"==> {name}")
    subprocess.run([sys.executable, script], cwd=os.path.join(HERE, folder), check=True)
    print(f"<== {name} ({time.time() - t0:.0f}s)")


if __name__ == "__main__":
    for step in sys.argv[1:] or list(STEPS):
        run(step)
