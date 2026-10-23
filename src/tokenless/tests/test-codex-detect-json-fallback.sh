#!/usr/bin/env bash
# Regression test for the codex detect.sh no-jq JSON fallback (GH #8671).
# The restricted PATH contains grep and head but no jq, so every case exercises
# the fallback branch rather than depending on the host's jq installation.
# Keep this file LF-only: it is executed directly by Bash in CI.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$HERE/../adapters/tokenless/codex/scripts/detect.sh"
BASH_BIN="$(command -v bash)"
GREP_BIN="$(command -v grep)"
HEAD_BIN="$(command -v head)"
PYTHON_BIN="$(command -v python3 2>/dev/null || true)"
FAIL=0

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1" >&2; FAIL=1; }

# run_case <label> <directory suffix> <expected JSON escape>
run_case() {
    local label="$1" suffix="$2" expected="$3" sandbox bin stub out
    sandbox="$(mktemp -d)"
    bin="$sandbox/dir$suffix"
    stub="$sandbox/stub"
    mkdir -p "$bin" "$stub"
    printf '#!%s\nprintf "%%s\\n" "tokenless 1.2.3"\n' "$BASH_BIN" > "$bin/tokenless"
    chmod +x "$bin/tokenless"
    ln -s "$GREP_BIN" "$stub/grep"
    ln -s "$HEAD_BIN" "$stub/head"

    if out="$(PATH="$stub:$bin" HOME="$sandbox" "$BASH_BIN" "$DETECT" 2>"$sandbox/stderr")"; then
        if [[ "$out" != *"$expected"* ]]; then
            fail "$label: expected JSON escape $expected (output: $out)"
        elif [ -n "$PYTHON_BIN" ] && ! printf '%s\n' "$out" | "$PYTHON_BIN" -c 'import json, sys; json.load(sys.stdin)'; then
            fail "$label: fallback output is not valid JSON"
        else
            pass "$label"
        fi
    else
        fail "$label: detector failed (stderr: $(cat "$sandbox/stderr"))"
    fi
    rm -rf "$sandbox"
}

run_case "plain path" "" '"path": "'
run_case "quote" '"' '\"'
run_case "backslash" '\' '\\'
run_case "bell-0x07" $'\a' '\u0007'
run_case "vertical-tab-0x0b" $'\v' '\u000b'
run_case "escape-0x1b" $'\e' '\u001b'
run_case "delete-0x7f" $'\177' '\u007f'
run_case "percent-s" '%s' '%s'

no_home_sandbox="$(mktemp -d)"
no_home_bin="$no_home_sandbox/bin"
no_home_stub="$no_home_sandbox/stub"
mkdir -p "$no_home_bin" "$no_home_stub"
printf '#!%s\nprintf "%%s\\n" "tokenless 1.2.3"\n' "$BASH_BIN" > "$no_home_bin/tokenless"
chmod +x "$no_home_bin/tokenless"
ln -s "$GREP_BIN" "$no_home_stub/grep"
ln -s "$HEAD_BIN" "$no_home_stub/head"
if out="$(env -u HOME PATH="$no_home_stub:$no_home_bin" "$BASH_BIN" "$DETECT" 2>"$no_home_sandbox/stderr")" &&
        [[ "$out" == *'"installed": true'* ]] &&
        [[ "$out" == *'"path": "'* ]]; then
    pass "unset HOME remains supported"
else
    fail "unset HOME broke detection (output: ${out:-<none>}, stderr: $(cat "$no_home_sandbox/stderr"))"
fi
rm -rf "$no_home_sandbox"

if [ "$FAIL" -ne 0 ]; then
    echo "codex detect.sh JSON fallback: FAILED" >&2
    exit 1
fi
echo "codex detect.sh JSON fallback: OK"
