#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): impedisce di scrivere segreti in file DENTRO il repo.
# Feedback immediato. Il gate vero e' l'hook git pre-commit: questo si aggira scrivendo con Bash
# (dimostrato in AUDIT-001 R-03), quello no, perche' il commit e' un passaggio obbligato.
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-/home/ubuntu/workbrain}"
LIB="$REPO/.claude/hooks/lib/scanners.sh"

input="$(cat || true)"
[ -z "$input" ] && exit 0

# FAIL-CLOSED. Una guardia dichiarata inviolabile non lascia passare tutto quando i suoi strumenti
# mancano: prima faceva `exit 0` in silenzio, che e' il modo piu' elegante di non proteggere nulla.
if ! command -v jq >/dev/null 2>&1; then
  echo "BLOCCATO: manca 'jq', questa guardia non puo' esaminare nulla." >&2
  echo "Installa jq (apt install jq). Non si scrive nel repo con la guardia cieca." >&2
  exit 2
fi
if [ ! -r "$LIB" ]; then
  echo "BLOCCATO: libreria scanner non leggibile ($LIB)." >&2
  exit 2
fi
# shellcheck source=lib/scanners.sh
. "$LIB"

fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
# testo proposto: content (Write) + new_string (Edit) + edits[].new_string (MultiEdit)
payload="$(printf '%s' "$input" | jq -r '
  [ .tool_input.content // empty,
    .tool_input.new_string // empty,
    ( .tool_input.edits // [] | map(.new_string // "") | join("\n") )
  ] | join("\n")')"

# Solo file dentro il repo: i dati veri stanno in /srv/workbrain, fuori scope.
case "$fp" in
  "$REPO"/*) : ;;
  *) exit 0 ;;
esac

if ! wb_scan_secrets "$payload" "$fp"; then
  echo "BLOCCATO: file $fp" >&2
  exit 2
fi
exit 0
