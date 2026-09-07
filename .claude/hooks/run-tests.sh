#!/usr/bin/env bash
# PostToolUse (Write|Edit|MultiEdit): dopo una modifica a codice o guardie, ESEGUE i test.
# Gate deterministico (regola #6): niente deploy senza test verdi.
#
# Prima cercava `tests/test_*.py` o `tests/run.sh`, che non esistevano, mentre la suite reale si
# chiamava `tests/test_hooks.sh`: usciva sempre 0 dicendo "fase bootstrap". Un gate che non puo'
# fallire non e' un gate (AUDIT-001 R-02). Ora invoca `tests/run.sh`, che raccoglie tutte le suite.
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-/home/ubuntu/workbrain}"
input="$(cat || true)"
[ -z "$input" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "run-tests: manca 'jq', impossibile sapere quale file e' stato toccato." >&2
  exit 2
fi

fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"

# Codice della pipeline, suite di test, guardie, e gli artefatti dei container: toccarli deve far
# girare i test. La Fase C ha aggiunto Dockerfile/compose/systemd senza estendere questo elenco:
# 23 invarianti nuove esistevano ma non venivano mai eseguite quando si toccavano i file che
# proteggono. E' la stessa famiglia di R-02 — un gate che non si attiva non e' un gate.
case "$fp" in
  "$REPO"/scripts/*|"$REPO"/tests/*|"$REPO"/.claude/hooks/*) : ;;
  "$REPO"/Dockerfile|"$REPO"/.dockerignore|"$REPO"/compose.yaml) : ;;
  "$REPO"/docker/*|"$REPO"/systemd/*|"$REPO"/.githooks/*) : ;;
  *) exit 0 ;;
esac

if [ ! -f "$REPO/tests/run.sh" ]; then
  echo "run-tests: BLOCCATO — manca tests/run.sh, quindi il gate non e' operativo." >&2
  echo "Non si prosegue con un gate cieco (regola #6)." >&2
  exit 2
fi

out="$(bash "$REPO/tests/run.sh" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "run-tests: TEST FALLITI (rc=$rc). Non procedere al deploy (regola #6). Output:" >&2
  printf '%s\n' "$out" | tail -40 >&2
  exit 2
fi

printf '%s\n' "$out" | tail -2 >&2
exit 0
