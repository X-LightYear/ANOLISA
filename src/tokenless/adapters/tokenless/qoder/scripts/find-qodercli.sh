#!/usr/bin/env bash
# Shared Qoder CLI discovery for the detector and lifecycle scripts.
# This file is sourced by Bash scripts; compgen is intentionally used instead
# of an unquoted glob so HOME paths containing spaces remain one candidate.

find_qodercli() {
    local qoder_home="${HOME:-}" versioned_glob latest_versioned candidate
    latest_versioned=""

    if [ -n "$qoder_home" ]; then
        versioned_glob="$qoder_home/.qoder/bin/qodercli/qodercli-${ANOLISA_QODER_VERSION:-*}"
        latest_versioned="$(compgen -G "$versioned_glob" 2>/dev/null | sort -V | tail -1 || true)"
    fi

    for candidate in "$latest_versioned" \
                     "${qoder_home:+$qoder_home/.qoder/bin/qodercli/qodercli}" \
                     "qodercli"; do
        [ -n "$candidate" ] || continue
        if [ -x "$candidate" ] || command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}
