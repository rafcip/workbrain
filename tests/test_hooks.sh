#!/usr/bin/env bash
# Test delle guardie deterministiche di WorkBrain. Rende riproducibile il claim "N/N verdi".
# Uso: bash tests/test_hooks.sh   (exit 0 se tutti verdi, 1 altrimenti)  ·  entry point: tests/run.sh
#
# NOTA sulle fixture composte a runtime (OT/DOMMARK/SENT/KEY/TOK).
# Questo file deve contenere finti segreti e marker di dominio: sono il materiale dei test. Ma le
# guardie ora coprono TUTTO il repo, quindi in forma letterale bloccherebbero la propria suite — e
# infatti hanno bloccato la prima stesura di questo file, il 2026-09-06. La via comoda sarebbe esentare
# questo file dal controllo: sarebbe un punto cieco permanente proprio dove si verifica la guardia.
# Comporre le stringhe a runtime risolve alla radice senza esentare niente.
# Stessa tecnica, stessa ragione, in .claude/hooks/lib/scanners.sh
set -uo pipefail
REPO="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
H="$REPO/.claude/hooks"
pass=0; fail=0

OT="open""text"
DOMMARK="domain: ${OT}"
SENT="OPEN""TEXT-CONFIDENTIAL"
KEY="STT_API""_KEY"
TOK="sk-""abcdefeghijklmnop1234567890"

check() { # check <desc> <hook> <exit-atteso> <json-stdin>
  local desc="$1" hook="$2" want="$3" json="$4" rc
  printf '%s' "$json" | "$H/$hook" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then
    printf "  PASS  [%s] %s (rc=%s)\n" "$hook" "$desc" "$rc"; pass=$((pass+1))
  else
    printf "  FAIL  [%s] %s (atteso rc=%s, ottenuto rc=%s)\n" "$hook" "$desc" "$want" "$rc"; fail=$((fail+1))
  fi
}

assert() { # assert <desc> <atteso> <ottenuto>
  if [ "$3" = "$2" ]; then printf "  PASS  %s (rc=%s)\n" "$1" "$3"; pass=$((pass+1))
  else printf "  FAIL  %s (atteso rc=%s, ottenuto rc=%s)\n" "$1" "$2" "$3"; fail=$((fail+1)); fi
}

ok() { # ok <desc> <comando...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then printf "  PASS  %s\n" "$desc"; pass=$((pass+1))
  else printf "  FAIL  %s\n" "$desc"; fail=$((fail+1)); fi
}

j()  { printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"; }
jf() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1"; }
jb() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

echo "== block-secrets =="
check "chiave con valore in file del repo -> BLOCK" block-secrets.sh 2 "$(j "$REPO/scripts/x.py" "${KEY}=${TOK}")"
check "placeholder vuoto -> PASS"                   block-secrets.sh 0 "$(j "$REPO/docs/x.md" "${KEY}=")"
check "filename env.prod nel repo -> BLOCK"         block-secrets.sh 2 "$(j "$REPO/env.prod" 'foo')"
check "token sk- nudo -> BLOCK"                     block-secrets.sh 2 "$(j "$REPO/scripts/y.py" "k = ${TOK}")"
check "file fuori dal repo -> PASS (fuori scope)"   block-secrets.sh 0 "$(j "/srv/workbrain/env.prod" "${KEY}=${TOK}")"

# Fail-closed: senza jq la guardia deve BLOCCARE, non lasciar passare in silenzio (AUDIT-001 R-03).
tmpbin="$(mktemp -d)"
for b in cat basename grep tail; do p="$(command -v "$b" 2>/dev/null)"; [ -n "$p" ] && ln -sf "$p" "$tmpbin/$b"; done
# Invocato con /bin/bash esplicito: con PATH svuotato, `#!/usr/bin/env bash` non troverebbe nemmeno
# l'interprete e otterremmo 127 — misurando uno script che non parte, non la guardia che blocca.
rc_nojq=$(printf '%s' "$(j "$REPO/docs/x.md" 'testo innocuo')" | PATH="$tmpbin" /bin/bash "$H/block-secrets.sh" >/dev/null 2>&1; echo $?)
rm -rf "$tmpbin"
assert "[block-secrets.sh] senza jq -> BLOCCA (fail-closed)" 2 "$rc_nojq"

echo "== block-opentext =="
check "frontmatter di dominio riservato in docs/ -> BLOCK" block-opentext.sh 2 "$(j "$REPO/docs/nota.md" "---\\n${DOMMARK}\\n---\\ntesto")"
check "nome del dominio in prosa -> PASS"                  block-opentext.sh 0 "$(j "$REPO/docs/x.md" "Il dominio ${OT} ha regole di riservatezza.")"
check "sentinella in reports/ -> BLOCK"                    block-opentext.sh 2 "$(j "$REPO/reports/r.md" "${SENT} meeting notes")"
# Copertura estesa a tutto il repo (AUDIT-001 R-03): i due seguenti PRIMA erano dei PASS, ed erano il buco.
check "frontmatter di dominio in knowledge/ -> BLOCK"      block-opentext.sh 2 "$(j "$REPO/knowledge/history/x.md" "---\\n${DOMMARK}\\n---")"
check "frontmatter di dominio in CLAUDE.md -> BLOCK"       block-opentext.sh 2 "$(j "$REPO/CLAUDE.md" "---\\n${DOMMARK}\\n---")"
check "fuori dal repo -> PASS (fuori scope)"               block-opentext.sh 0 "$(j "/srv/workbrain/vault/x.md" "---\\n${DOMMARK}\\n---")"

echo "== block-bash-writes =="
check "comando Bash che scrive un segreto -> BLOCK" block-bash-writes.sh 2 "$(jb "printf '${KEY}=${TOK}' > docs/x.md")"
check "comando Bash che scrive un marker -> BLOCK"  block-bash-writes.sh 2 "$(jb "echo '${DOMMARK}' >> docs/x.md")"
check "comando Bash innocuo -> PASS"                block-bash-writes.sh 0 "$(jb "git status --short")"
check "segreto ma senza scrittura -> PASS"          block-bash-writes.sh 0 "$(jb "grep -r ${KEY}=${TOK} /srv")"

echo "== run-tests (gate deterministico) =="
# Fixture isolate: il gate esegue tests/run.sh, che esegue questa suite. Senza isolamento, ricorsione.
fx="$(mktemp -d)"; mkdir -p "$fx/scripts" "$fx/tests"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fx/tests/run.sh"
rc_ok=$(jf "$fx/scripts/a.py" | CLAUDE_PROJECT_DIR="$fx" "$H/run-tests.sh" >/dev/null 2>&1; echo $?)
printf '#!/usr/bin/env bash\nexit 1\n' > "$fx/tests/run.sh"
rc_ko=$(jf "$fx/scripts/a.py" | CLAUDE_PROJECT_DIR="$fx" "$H/run-tests.sh" >/dev/null 2>&1; echo $?)
rm -f "$fx/tests/run.sh"
rc_missing=$(jf "$fx/scripts/a.py" | CLAUDE_PROJECT_DIR="$fx" "$H/run-tests.sh" >/dev/null 2>&1; echo $?)
rm -rf "$fx"
assert "[run-tests.sh] suite verde -> PASS"    0 "$rc_ok"
# Il test che PRIMA sarebbe stato impossibile: fino al 2026-09-06 il gate usciva sempre 0.
assert "[run-tests.sh] suite ROSSA -> BLOCCA"  2 "$rc_ko"
assert "[run-tests.sh] run.sh assente -> BLOCCA" 2 "$rc_missing"
check "file fuori da scripts/tests/hooks -> PASS no-op" run-tests.sh 0 "$(j "$REPO/docs/x.md" 'ciao')"

echo "== gate sul commit =="
ok "libreria scanner presente"        test -r "$REPO/.claude/hooks/lib/scanners.sh"
ok "hook pre-commit eseguibile"       test -x "$REPO/.githooks/pre-commit"
ok "core.hooksPath punta a .githooks" bash -c "[ \"\$(git -C '$REPO' config core.hooksPath)\" = '.githooks' ]"

echo
echo "Risultato: ${pass} verdi, ${fail} falliti."
[ "$fail" -eq 0 ]
