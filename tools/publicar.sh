#!/usr/bin/env bash
# Publica una actualización: sube version.txt en uno, exporta el juego y deja
# en la rama `descargas` el paquete que la pantalla de inicio baja sola.
#   tools/publicar.sh            -> solo actualización automática (juego.pck)
#   tools/publicar.sh --exe      -> además genera el .exe y su .zip
set -euo pipefail
GODOT="${GODOT:-/home/claude/tools/Godot_v4.3-stable_linux.x86_64}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
cd "$ROOT"

VERSION=$(( $(cat version.txt) + 1 ))
echo "$VERSION" > version.txt
"$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
"$GODOT" --headless --export-pack "Windows Desktop" "$OUT/juego.pck" >/dev/null 2>&1
echo "$VERSION" > "$OUT/version.txt"

git clone -q --depth 1 --branch descargas "$(git remote get-url origin)" "$OUT/descargas" 2>/dev/null || {
  mkdir -p "$OUT/descargas"; git -C "$OUT/descargas" init -q; git -C "$OUT/descargas" checkout -q --orphan descargas
  git -C "$OUT/descargas" remote add origin "$(git remote get-url origin)"; }
cp "$OUT/juego.pck" "$OUT/version.txt" "$OUT/descargas/"

if [[ "${1:-}" == "--exe" ]]; then
  mkdir -p build
  "$GODOT" --headless --export-release "Windows Desktop" build/CronicaDelHeroeAtrapado.exe >/dev/null 2>&1
  rm -f "$OUT/descargas/"*.zip
  (cd build && zip -9 -q "$OUT/descargas/CronicaDelHeroeAtrapado.zip" CronicaDelHeroeAtrapado.exe)
fi

cat > "$OUT/descargas/README.md" <<MD
# Descargas

Versión actual: **$VERSION**

- Juego para Windows (64 bits): [CronicaDelHeroeAtrapado.zip](https://github.com/keurymanuel368/cronica-heroe-atrapado/raw/descargas/CronicaDelHeroeAtrapado.zip).
  Se descarga una sola vez: al abrirlo busca aquí la versión más nueva y se actualiza solo.
- \`juego.pck\` y \`version.txt\` son la actualización automática; no hace falta bajarlos a mano.
MD

cd "$OUT/descargas"
git add -A
git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit -q -m "Versión $VERSION"
# Rama de descargas: se reescribe en un solo commit para no acumular binarios.
git reset -q --soft "$(git commit-tree HEAD^{tree} -m "Versión $VERSION")"
git push -q -f origin HEAD:descargas
echo "Publicada la versión $VERSION"
