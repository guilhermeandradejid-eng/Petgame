#!/bin/bash
# checa a sintaxe dos scripts do projeto Godot
cd /tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/provas/tralha-da-cheia
for s in vfx cenario boneco mola main; do timeout 60 /tmp/claude-0/-home-user-Petgame/d82ab3ff-e832-5e99-9156-5bd6d07186e0/scratchpad/pesquisa-render-vfx/bin/Godot_v4.7.2-stable_linux.x86_64 --path proj --headless --check-only --script res://$s.gd 2>&1 | grep -i "error" | grep -v "Failed to compile depended\|Failed to load script" | head -6 | sed "s/^/$s: /"; done
