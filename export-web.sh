#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REDOT_BIN="${REDOT_BIN:-redot}"
OUTPUT_DIR="$PROJECT_DIR/build/web"

mkdir -p "$OUTPUT_DIR"
touch "$PROJECT_DIR/build/.gdignore"
"$REDOT_BIN" --headless --path "$PROJECT_DIR" --import
"$REDOT_BIN" --headless --path "$PROJECT_DIR" --export-release Web "$OUTPUT_DIR/index.html"
cp "$PROJECT_DIR/deploy/Dockerfile" "$OUTPUT_DIR/Dockerfile"
cp "$PROJECT_DIR/deploy/default.conf.template" "$OUTPUT_DIR/default.conf.template"
cp "$PROJECT_DIR/deploy/railway.json" "$OUTPUT_DIR/railway.json"
