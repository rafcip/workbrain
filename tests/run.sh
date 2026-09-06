#!/usr/bin/env bash
# Entry point UNICO delle suite di test di WorkBrain.
#
# Esiste perche' il gate cercava `tests/test_*.py` o `tests/run.sh`, mentre l'unica suite si chiamava
# `tests/test_hooks.sh`: il gate usciva sempre 0 dicendo "fase bootstrap" e la regola #6 era dichiarata
# ma non applicata (AUDIT-001 R-02). Da qui in poi si aggiunge una suite e viene raccolta da sola.
#
# Uso: bash tests/run.sh   (exit 0 se tutto verde, 1 altrimenti)
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
rc=0
found=0

for suite in "$REPO"/tests/test_*.sh; do
  [ -e "$suite" ] || continue
  found=1
  echo "### $(basename "$suite")"
  if ! bash "$suite"; then rc=1; fi
  echo
done

if ls "$REPO"/tests/test_*.py >/dev/null 2>&1; then
  found=1
  if command -v pytest >/dev/null 2>&1; then
    echo "### pytest"
    if ! pytest -q "$REPO/tests"; then rc=1; fi
  else
    echo "ERRORE: ci sono test Python ma manca pytest. Un runner assente non e' un test verde." >&2
    rc=1
  fi
fi

if [ "$found" -eq 0 ]; then
  echo "ERRORE: nessuna suite trovata in tests/. Se il gate e' attivo, questo non deve succedere." >&2
  exit 1
fi

exit "$rc"
