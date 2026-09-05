#!/usr/bin/env bash
# PostToolUse (Write|Edit|MultiEdit): dopo una modifica a codice in scripts/ o tests/, esegue i test.
# Gate deterministico (regola #6): niente deploy senza test verdi. In fase bootstrap non c'e' ancora codice:
# in tal caso esce 0 informando, senza bloccare.
set -uo pipefail
REPO="/home/ubuntu/workbrain"
input="$(cat || true)"
[ -z "$input" ] && exit 0
command -v jq >/dev/null || exit 0

fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
case "$fp" in
  "$REPO"/scripts/*|"$REPO"/tests/*) : ;;
  *) exit 0 ;;
esac

cd "$REPO" || exit 0
# Nessun test presente ancora → no-op informativo.
if ! ls tests/test_*.py >/dev/null 2>&1 && [ ! -f tests/run.sh ]; then
  echo "run-tests: nessun test in tests/ (fase bootstrap) — nulla da eseguire." >&2
  exit 0
fi

if [ -f tests/run.sh ]; then
  bash tests/run.sh; rc=$?
elif command -v pytest >/dev/null 2>&1; then
  pytest -q; rc=$?
else
  echo "run-tests: trovati test ma manca il runner (pytest). Installa il runner." >&2
  exit 0
fi

if [ "$rc" -ne 0 ]; then
  echo "run-tests: TEST FALLITI (rc=$rc). Non procedere al deploy finche' non sono verdi (regola #6)." >&2
  exit 2
fi
echo "run-tests: test verdi." >&2
exit 0
