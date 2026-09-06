#!/usr/bin/env bash
# PreToolUse (Bash): chiude il caso ovvio del bypass dimostrato in AUDIT-001 R-03 —
#   printf 'CHIAVE=valore' > docs/file.md
# passava indisturbato, perche' gli hook erano agganciati solo a Write|Edit|MultiEdit.
#
# ONESTA' SUI LIMITI: questo hook NON puo' intercettare ogni modo di scrivere un file. La shell e'
# troppo espressiva (variabili, base64, heredoc, script generati, editor). Non ci prova nemmeno:
# fa una cosa sola: se il TESTO DEL COMANDO contiene un segreto o un marker di dominio e il comando
# ha la forma di una scrittura, blocca. Il gate vero e' l'hook git pre-commit (PLAN-001 D-04):
# quello non si aggira, perche' per entrare in un commit si passa comunque di li'.
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-/home/ubuntu/workbrain}"
LIB="$REPO/.claude/hooks/lib/scanners.sh"

input="$(cat || true)"
[ -z "$input" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "BLOCCATO: manca 'jq', la guardia sui comandi non puo' esaminare nulla." >&2
  exit 2
fi
if [ ! -r "$LIB" ]; then
  echo "BLOCCATO: libreria scanner non leggibile ($LIB)." >&2
  exit 2
fi
# shellcheck source=lib/scanners.sh
. "$LIB"

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

# Ha la forma di una scrittura? (redirezione, tee, sed -i, dd)
case "$cmd" in
  *'>'*|*tee\ *|*'sed -i'*|*'dd '*) : ;;
  *) exit 0 ;;
esac

if ! wb_scan_secrets "$cmd"; then
  echo "BLOCCATO: il comando Bash contiene un segreto e scrive su file." >&2
  echo "Nota: questa guardia copre i casi ovvi, non tutti. Il gate vero e' l'hook git pre-commit." >&2
  exit 2
fi
if ! wb_scan_domain "$cmd" loose; then
  echo "BLOCCATO: il comando Bash contiene un marker di dominio riservato e scrive su file." >&2
  exit 2
fi
exit 0
