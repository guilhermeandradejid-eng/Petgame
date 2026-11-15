#!/bin/bash
# roda o jogo com video por software (para capturas automaticas). uso: tools/play.sh <args do jogo...>
cd "$(dirname "$0")/.."
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --resolution 1280x720 -- --nosound --windowed "$@" 2>&1 | grep -vE "ALSA|audio|^$|Vulkan|Godot Engine|snd_|   at: |status < 0"
