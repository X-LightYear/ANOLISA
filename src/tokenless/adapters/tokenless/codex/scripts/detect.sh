#!/usr/bin/env bash
# Detect whether the tokenless CLI is installed and functional.
#
# Output:
#   JSON on stdout:  {"installed": true, "version": "0.1.0", "path": "/usr/bin/tokenless"}
#                    or {"installed": false}
# Exit code: 0 either way (fail-open — plugin activation is controlled by capabilities)

set -euo pipefail

TOKENLESS_BIN=""
USER_HOME="${HOME:-}"

# Search PATH first
if command -v tokenless >/dev/null 2>&1; then
    TOKENLESS_BIN="$(command -v tokenless)"
fi

# Fallback paths
if [[ -z "$TOKENLESS_BIN" ]]; then
    FALLBACK_PATHS=(
        "/usr/local/bin/tokenless"
        "/usr/bin/tokenless"
    )
    if [[ -n "$USER_HOME" ]]; then
        FALLBACK_PATHS=(
            "$USER_HOME/.local/bin/tokenless"
            "${FALLBACK_PATHS[@]}"
            "$USER_HOME/.local/share/anolisa/tokenless/tokenless"
            "$USER_HOME/.local/lib/anolisa/tokenless/tokenless"
        )
    fi
    for fp in "${FALLBACK_PATHS[@]}"; do
        if [[ -f "$fp" && -x "$fp" ]]; then
            TOKENLESS_BIN="$fp"
            break
        fi
    done
fi

if [[ -z "$TOKENLESS_BIN" ]]; then
    echo '{"installed": false}'
    exit 0
fi

# Verify it actually runs
VERSION="$("$TOKENLESS_BIN" --version 2>/dev/null || true)"
if [[ -z "$VERSION" ]]; then
    echo '{"installed": false}'
    exit 0
fi

# Extract version number
VERSION_CLEAN="$(echo "$VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")"

json_escape() {
  local value="$1" out="" i ch esc
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  for ((i = 0; i < ${#value}; i++)); do
    ch="${value:i:1}"
    case "$ch" in
      $'\b') esc='\b' ;;
      $'\f') esc='\f' ;;
      $'\n') esc='\n' ;;
      $'\r') esc='\r' ;;
      $'\t') esc='\t' ;;
      *)
        if [[ "$ch" == [[:cntrl:]] ]]; then
          printf -v esc '\\u%04x' "'$ch"
        else
          esc="$ch"
        fi
        ;;
    esac
    out+="$esc"
  done
  printf '%s' "$out"
}

# Use jq --arg to safely embed variables into JSON — avoids broken output
# when paths contain characters that need JSON escaping.
if command -v jq &>/dev/null; then
  jq -n --arg ver "$VERSION_CLEAN" --arg p "$TOKENLESS_BIN" \
    '{installed: true, version: $ver, path: $p}'
else
  VERSION_JSON="$(json_escape "$VERSION_CLEAN")"
  PATH_JSON="$(json_escape "$TOKENLESS_BIN")"
  printf '{\n  "installed": true,\n  "version": "%s",\n  "path": "%s"\n}\n' \
    "$VERSION_JSON" "$PATH_JSON"
fi
