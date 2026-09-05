#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): impedisce di scrivere segreti in file DENTRO il repo.
# Guarantee (non un giudizio): un token con valore reale o env.prod non deve mai finire in un file tracciabile.
# Blocca con exit 2 (stderr torna al modello). Fail-safe: se manca l'input, non blocca.
set -euo pipefail
REPO="/home/ubuntu/workbrain"
input="$(cat || true)"
[ -z "$input" ] && exit 0
command -v jq >/dev/null || exit 0

fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
# testo proposto: content (Write) + new_string (Edit) + edits[].new_string (MultiEdit)
payload="$(printf '%s' "$input" | jq -r '
  [ .tool_input.content // empty,
    .tool_input.new_string // empty,
    ( .tool_input.edits // [] | map(.new_string // "") | join("\n") )
  ] | join("\n")')"

# Solo file dentro il repo (i dati veri stanno in /srv/workbrain, fuori scope)
case "$fp" in
  "$REPO"/*) : ;;
  *) exit 0 ;;
esac

# 1) env.prod non entra mai nel repo
if [ "$(basename "$fp")" = "env.prod" ]; then
  echo "BLOCCATO: env.prod non deve stare nel repo (deve vivere in /srv/workbrain, 600)." >&2
  exit 2
fi

# 2) segreti con VALORE reale (i placeholder vuoti tipo API_KEY= passano)
if printf '%s' "$payload" | grep -nEq \
  '((API|SECRET|ACCESS|PRIVATE|AUTH)_?(KEY|TOKEN|SECRET)|PASSWORD)[[:space:]]*[:=][[:space:]]*[^[:space:]"'"'"']+|sk-[A-Za-z0-9]{16,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
  echo "BLOCCATO: sembra un segreto con valore reale in un file del repo ($fp)." >&2
  echo "I segreti vanno in /srv/workbrain/env.prod (600) o ~/.plaud/, mai in git." >&2
  exit 2
fi
exit 0
