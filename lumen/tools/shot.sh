#!/bin/bash
# uso: tools/shot.sh <args do preview.gd...>
cd "$(dirname "$0")/.."
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan -s tools/preview.gd -- "$@" 2>&1 | grep -vE "ALSA|audio|^$|Vulkan|Godot Engine|snd_|at: " 
