#!/bin/bash
# roda o jogo sem janela por alguns quadros e mostra erros de script com arquivo e linha
cd "$(dirname "$0")/.."
timeout 90 godot --headless --path . --quit-after ${1:-3} 2>&1 | grep -A3 -E "SCRIPT ERROR|^ERROR" | grep -vE "^--$|GDScript backtrace|Failed to compile depended|gdscript_resource_format|Failed to load script" | head -${2:-40}
