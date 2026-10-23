#!/usr/bin/env bash
# detect.sh — Check whether Qoder CLI supports the native plugin lifecycle.
set -euo pipefail

AGENT="${ANOLISA_TARGET:-qoder}"
COMPONENT="${ANOLISA_COMPONENT:-tokenless}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./find-qodercli.sh
. "$SCRIPT_DIR/find-qodercli.sh"
QODERCLI="$(find_qodercli || true)"

if [ -z "$QODERCLI" ]; then
    echo "[${COMPONENT}] ${AGENT}: qodercli not found in standard locations" >&2
    exit 1
fi

for subcommand in install list uninstall; do
    if ! "$QODERCLI" plugins "$subcommand" --help >/dev/null 2>&1; then
        echo "[${COMPONENT}] ${AGENT}: qodercli lacks 'plugins ${subcommand}' support" >&2
        exit 1
    fi
done

echo "[${COMPONENT}] ${AGENT}: detected compatible qodercli at ${QODERCLI}"
