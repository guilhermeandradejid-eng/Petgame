#!/usr/bin/env bash
# Gera os modelos (Blender), os sons e exporta o APK de demonstração.
#
# Requisitos:
#   GODOT     -> executável do Godot 4.5 (com export templates Android instalados)
#   BLENDER_PY-> python com o módulo bpy (pip install bpy) ou "blender -b -P" (opcional)
#   Keystore  -> GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD
#               (sem isso, cria um keystore de debug em builds/debug.keystore)
#   Android SDK com build-tools (apksigner) configurado nas Editor Settings do Godot.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

if [ -n "${BLENDER_PY:-}" ]; then
  echo "== Modelos 3D (Blender)"
  "$BLENDER_PY" "$ROOT/blender/build_assets.py"
fi
echo "== Áudio"
python3 "$ROOT/tools/gen_audio.py"

mkdir -p "$ROOT/builds"
if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
  KS="$ROOT/builds/debug.keystore"
  if [ ! -f "$KS" ]; then
    keytool -genkeypair -keystore "$KS" -storepass android -alias androiddebugkey -keypass android \
      -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Smash na Areia Demo,O=Demo,C=BR"
  fi
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="androiddebugkey"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="android"
fi

echo "== Importando assets"
"$GODOT" --headless --path "$ROOT/godot" --import
echo "== Exportando APK"
"$GODOT" --headless --path "$ROOT/godot" --export-release "Android" "$ROOT/builds/SmashNaAreia-demo.apk"
ls -lh "$ROOT/builds/SmashNaAreia-demo.apk"
