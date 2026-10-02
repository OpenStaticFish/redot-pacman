#!/usr/bin/env bash
set -euo pipefail

# Resolve the project next to this script, regardless of the current directory.
PROJECT_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
ENGINE="${REDOT_BIN:-redot}"

if ! command -v "$ENGINE" >/dev/null 2>&1; then
	printf 'Redot was not found. Add it to PATH or set REDOT_BIN to its executable.\n' >&2
	exit 127
fi

exec "$ENGINE" --path "$PROJECT_DIR" "$@"
