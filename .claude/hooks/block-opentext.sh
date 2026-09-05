#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): impedisce di scrivere CONTENUTO di dominio `opentext`
# (o marker riservati) in docs/, reports/, tests/. La segregazione dei domini e' inviolabile.
# Nota: il semplice nome "opentext" come parola in prosa e' ammesso (e' un metadato); qui si bloccano
# solo i MARKER machine-readable che denotano payload reale di quel dominio, che non deve mai stare
# nel repo (le note vere vivono in /srv/workbrain/vault, fuori dal repo).
set -euo pipefail
REPO="/home/ubuntu/workbrain"
input="$(cat || true)"
[ -z "$input" ] && exit 0
command -v jq >/dev/null || exit 0

fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
payload="$(printf '%s' "$input" | jq -r '
  [ .tool_input.content // empty,
    .tool_input.new_string // empty,
    ( .tool_input.edits // [] | map(.new_string // "") | join("\n") )
  ] | join("\n")')"

# Solo percorsi sensibili del repo
case "$fp" in
  "$REPO"/docs/*|"$REPO"/reports/*|"$REPO"/tests/*) : ;;
  *) exit 0 ;;
esac

# Marker di payload opentext: assegnazione di dominio nel frontmatter, o sentinella riservata.
if printf '%s' "$payload" | grep -nEiq '^[[:space:]]*domain:[[:space:]]*["'"'"']?opentext|OPENTEXT-CONFIDENTIAL'; then
  echo "BLOCCATO: contenuto/marker di dominio 'opentext' in $fp." >&2
  echo "Segregazione domini inviolabile: le note opentext vivono solo in /srv/workbrain/vault (fuori dal repo)." >&2
  echo "Se stai solo citando il NOME del dominio in prosa, non usare un frontmatter 'domain: opentext'." >&2
  exit 2
fi
exit 0
