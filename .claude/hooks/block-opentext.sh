#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): impedisce di scrivere CONTENUTO del dominio riservato del datore
# di lavoro (o i suoi marker) in QUALSIASI file del repo. La segregazione dei domini e' inviolabile.
#
# Copertura estesa a tutto il repo il 2026-09-06 (AUDIT-001 R-03): prima guardava solo docs/, reports/
# e tests/, lasciando scoperti knowledge/ (dove finiscono le history), CLAUDE.md e .claude/ — mentre la
# regola parla di tutto il repo e di ogni commit.
#
# Cosa NON blocca: il nome del dominio citato in prosa. Quello e' un metadato ed e' legittimo.
# Blocca i marker machine-readable, che denotano payload reale. Vedi .claude/hooks/lib/scanners.sh
set -uo pipefail

REPO="${CLAUDE_PROJECT_DIR:-/home/ubuntu/workbrain}"
LIB="$REPO/.claude/hooks/lib/scanners.sh"

input="$(cat || true)"
[ -z "$input" ] && exit 0

# FAIL-CLOSED: vedi block-secrets.sh. Una regola inviolabile non puo' avere un ramo che apre in silenzio.
if ! command -v jq >/dev/null 2>&1; then
  echo "BLOCCATO: manca 'jq', la guardia sulla segregazione dei domini non puo' esaminare nulla." >&2
  exit 2
fi
if [ ! -r "$LIB" ]; then
  echo "BLOCCATO: libreria scanner non leggibile ($LIB)." >&2
  exit 2
fi
# shellcheck source=lib/scanners.sh
. "$LIB"

fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
payload="$(printf '%s' "$input" | jq -r '
  [ .tool_input.content // empty,
    .tool_input.new_string // empty,
    ( .tool_input.edits // [] | map(.new_string // "") | join("\n") )
  ] | join("\n")')"

case "$fp" in
  "$REPO"/*) : ;;
  *) exit 0 ;;
esac

if ! wb_scan_domain "$payload"; then
  echo "BLOCCATO: file $fp" >&2
  exit 2
fi
exit 0
