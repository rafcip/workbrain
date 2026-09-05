#!/usr/bin/env bash
# Test degli hook deterministici di WorkBrain. Rende riproducibile il claim "N/N verdi".
# Uso: bash tests/test_hooks.sh   (exit 0 se tutti verdi, 1 altrimenti)
set -uo pipefail
REPO="${CLAUDE_PROJECT_DIR:-/home/ubuntu/workbrain}"
H="$REPO/.claude/hooks"
pass=0; fail=0

# check <descrizione> <hook> <exit-atteso> <json-stdin>
check() {
  local desc="$1" hook="$2" want="$3" json="$4" rc
  printf '%s' "$json" | "$H/$hook" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then
    printf "  PASS  [%s] %s (rc=%s)\n" "$hook" "$desc" "$rc"; pass=$((pass+1))
  else
    printf "  FAIL  [%s] %s (atteso rc=%s, ottenuto rc=%s)\n" "$hook" "$desc" "$want" "$rc"; fail=$((fail+1))
  fi
}

j() { # costruisce {"tool_name":"Write","tool_input":{"file_path":F,"content":C}}
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"
}

echo "== block-secrets =="
check "API key con valore in file repo -> BLOCK" block-secrets.sh 2 "$(j "$REPO/scripts/x.py" 'STT_API_KEY=sk-abcdefeghijklmnop1234567890')"
check "placeholder vuoto -> PASS"                block-secrets.sh 0 "$(j "$REPO/docs/x.md" 'STT_API_KEY=')"
check "filename env.prod nel repo -> BLOCK"      block-secrets.sh 2 "$(j "$REPO/env.prod" 'foo')"
check "token sk- -> BLOCK"                       block-secrets.sh 2 "$(j "$REPO/scripts/y.py" 'k = \"sk-abcdefeghijklmnop1234567890\"')"
check "file fuori dal repo -> PASS (fuori scope)" block-secrets.sh 0 "$(j "/srv/workbrain/env.prod" 'STT_API_KEY=sk-realrealrealreal1234567890')"

echo "== block-opentext =="
check "frontmatter domain: opentext in docs/ -> BLOCK" block-opentext.sh 2 "$(j "$REPO/docs/nota.md" '---\ndomain: opentext\n---\ntesto')"
check "nome 'opentext' in prosa in docs/ -> PASS"      block-opentext.sh 0 "$(j "$REPO/docs/x.md" 'Il dominio opentext ha regole di riservatezza.')"
check "OPENTEXT-CONFIDENTIAL in reports/ -> BLOCK"      block-opentext.sh 2 "$(j "$REPO/reports/r.md" 'OPENTEXT-CONFIDENTIAL meeting notes')"
check "domain: opentext fuori da docs/reports/tests -> PASS" block-opentext.sh 0 "$(j "$REPO/knowledge/history/x.md" '---\ndomain: opentext\n---')"

echo "== run-tests =="
check "edit in scripts/ senza test -> PASS informativo" run-tests.sh 0 "$(j "$REPO/scripts/pipeline.py" 'print(1)')"
check "edit fuori da scripts/tests -> PASS no-op"        run-tests.sh 0 "$(j "$REPO/docs/x.md" 'ciao')"

echo
echo "Risultato: ${pass} verdi, ${fail} falliti."
[ "$fail" -eq 0 ]
