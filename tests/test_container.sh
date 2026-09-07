#!/usr/bin/env bash
# Test degli invarianti della Fase C (fondamenta container). Entry point: tests/run.sh
#
# Cosa protegge: le scelte di PLAN-001 D-01/D-02/D-03 sono facili da annullare con una riga
# distratta — un tag al posto di un digest, un `ports:`, un servizio `privileged`, `ubuntu`
# nel gruppo docker. Questi test fanno fallire il commit invece di lasciarlo passare in silenzio.
#
# PERCHE' NON SI USA `grep` SUI FILE (lezione PAT-07).
# La prima stesura di questa suite controllava le stringhe di compose.yaml. Un review l'ha rotta
# in trenta secondi: bastava AGGIUNGERE un servizio con `privileged: true` e `user: "0:0"` e i test
# restavano verdi, perche' le stringhe cercate esistevano comunque nell'anchor condiviso. Un test
# che vede la riga giusta da qualche parte nel file non e' un test: e' PAT-07 in azione, scritto
# nella stessa sessione in cui PAT-07 e' stato registrato.
# Qui si legge la configurazione EFFETTIVA (`docker compose config --format json`, `systemctl show`),
# servizio per servizio, e ogni servizio presente deve soddisfare gli invarianti — anche uno nuovo.
set -uo pipefail
REPO="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
pass=0; fail=0

p() { printf "  PASS  %s\n" "$1"; pass=$((pass+1)); }
f() { printf "  FAIL  %s\n" "$1"; fail=$((fail+1)); }
ok() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then p "$d"; else f "$d"; fi; }
no() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then f "$d"; else p "$d"; fi; }
eq() { # eq <desc> <atteso> <ottenuto>
  if [ "$2" = "$3" ]; then p "$1"; else printf "  FAIL  %s (atteso '%s', ottenuto '%s')\n" "$1" "$2" "$3"; fail=$((fail+1)); fi
}

echo "== immagine base (D-03) =="
ok "Dockerfile presente"                    test -r "$REPO/Dockerfile"
ok "FROM pinnato per digest"                grep -Eq '^FROM [^ ]+@sha256:[0-9a-f]{64}' "$REPO/Dockerfile"
no "nessun tag :latest nel Dockerfile"      grep -Eq '^FROM .*:latest' "$REPO/Dockerfile"
ok "USER non-root dichiarato"               grep -Eq '^USER 10001' "$REPO/Dockerfile"
no "USER root non dichiarato"               grep -Eq '^USER (root|0)$' "$REPO/Dockerfile"
ok "il contesto di build esclude i segreti" grep -q 'env.prod' "$REPO/.dockerignore"
# La label e' cio' che salva l'immagine dal prune notturno: se le due parti divergono, il canary
# si trasforma in una ricostruzione ogni notte. Si controlla che combacino, non che esistano.
LBL="$(grep -oP '^LABEL com\.workbrain\.keep="\K[^"]+' "$REPO/Dockerfile" 2>/dev/null)"
KEEP="$(grep -oP '^KEEP_LABEL="com\.workbrain\.keep=\K[^"]+' "$REPO/scripts/docker-prune.sh" 2>/dev/null)"
eq "label di protezione = filtro del prune" "${LBL:-assente}" "${KEEP:-assente}"
ok "il prune esclude la label protetta"     grep -q 'label!=\${KEEP_LABEL}' "$REPO/scripts/docker-prune.sh"

echo "== confini degli step: configurazione EFFETTIVA, servizio per servizio (D-03) =="
CFG="$(cd "$REPO" && docker compose config --format json 2>/dev/null)"
if [ -z "$CFG" ]; then
  f "docker compose config non produce nulla (tutti i test dei confini saltati)"
else
  svcs="$(printf '%s' "$CFG" | jq -r '.services | keys[]')"
  # Matrice attesa, dalla tabella di D-03. Un servizio non elencato qui e' un servizio non previsto:
  # deve far fallire la suite, non passare per omissione.
  want_mounts() { case "$1" in
      sync)    echo "/srv/workbrain/raw:rw" ;;
      stt)     echo "/srv/workbrain/raw:rw" ;;
      distill) echo "/srv/workbrain/raw:ro /srv/workbrain/vault:rw" ;;
      index)   echo "/srv/workbrain/vault:ro /srv/workbrain/db:rw" ;;
      query)   echo "/srv/workbrain/vault:ro /srv/workbrain/db:ro" ;;
      *) return 1 ;; esac; }
  want_net() { case "$1" in
      index|query) echo "none" ;;
      sync|stt|distill) echo "default" ;;
      *) return 1 ;; esac; }

  for s in $svcs; do
    q() { printf '%s' "$CFG" | jq -r --arg s "$s" "$1"; }
    eq "[$s] gira come uid non-root 10001:0" "10001:0"            "$(q '.services[$s].user // "assente"')"
    eq "[$s] rootfs in sola lettura"         "true"               "$(q '.services[$s].read_only // false')"
    eq "[$s] capability azzerate"            "ALL"                "$(q '.services[$s].cap_drop // [] | join(",")')"
    eq "[$s] no-new-privileges"              "no-new-privileges:true" "$(q '.services[$s].security_opt // [] | join(",")')"
    eq "[$s] non privilegiato"               "false"              "$(q '.services[$s].privileged // false')"
    eq "[$s] nessuna porta pubblicata"       "0"                  "$(q '.services[$s].ports // [] | length')"
    eq "[$s] non scarica da un registry"     "never"              "$(q '.services[$s].pull_policy // "assente"')"
    # Ogni mount deve stare sotto /srv/workbrain: un bind su / o su ~ svuoterebbe la matrice.
    eq "[$s] monta solo /srv/workbrain"      "0" \
       "$(q '[.services[$s].volumes // [] | .[] | select(.source | startswith("/srv/workbrain/") | not)] | length')"
    got="$(q '[.services[$s].volumes // [] | .[] | "\(.source):\(if .read_only then "ro" else "rw" end)"] | join(" ")')"
    if exp="$(want_mounts "$s")"; then eq "[$s] mount e permessi come da D-03" "$exp" "$got"
    else f "[$s] servizio non previsto dalla matrice di D-03 (mount: $got)"; fi
    gotn="$(q '.services[$s].network_mode // "default"')"
    if expn="$(want_net "$s")"; then eq "[$s] rete come da D-03" "$expn" "$gotn"
    else f "[$s] servizio non previsto dalla matrice di D-03 (rete: $gotn)"; fi
  done
  # I cinque step devono esserci tutti: se qualcuno sparisce, i test sopra non hanno niente da bocciare.
  eq "i cinque step di D-03 sono tutti presenti" "distill index query stt sync" "$(echo $svcs | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"
fi

echo "== unit systemd: valori EFFETTIVI, non righe di config (D-02, PAT-07) =="
for u in workbrain-backup.service workbrain-backup.timer \
         workbrain-docker-prune.service workbrain-docker-prune.timer \
         'workbrain-step@.service' 'workbrain-step@.timer'; do
  ok "unit versionata nel repo: $u"  test -r "$REPO/systemd/user/$u"
  # Le unit vive sono symlink al repo: con le copie il file attivo e quello versionato divergono
  # in silenzio, e ci si accorge della differenza il giorno in cui qualcosa non parte.
  ok "unit attiva = symlink al repo: $u" \
     bash -c "[ \"\$(readlink -f \"\$HOME/.config/systemd/user/$u\")\" = '$REPO/systemd/user/$u' ]"
done
# RuntimeMaxSec con Type=oneshot viene IGNORATO da systemd: il limite vero e' TimeoutStartSec.
# Il difetto (backup senza guard-rail, Fase B) si controlla sul VALORE, non sulla riga.
no "nessun RuntimeMaxSec con oneshot"  grep -rEq '^RuntimeMaxSec=' "$REPO/systemd/user/"
for u in workbrain-backup.service workbrain-docker-prune.service 'workbrain-step@index.service'; do
  v="$(systemctl --user show "$u" -p TimeoutStartUSec --value 2>/dev/null)"
  case "$v" in ""|infinity) f "[$u] limite di durata effettivo assente (TimeoutStartUSec=${v:-vuoto})" ;;
               *) p "[$u] limite di durata effettivo: $v" ;; esac
done
# Un timer in recupero dopo un reboot non deve fallire perche' il daemon non e' ancora su:
# Requires lo tira su, Requisite lo farebbe fallire. After ordina, ma non attiva.
ok "lo step tira su il daemon, non fallisce" grep -q '^Requires=docker.service' "$REPO/systemd/user/workbrain-step@.service"

echo "== dati e runtime rootless (D-01) =="
# Tutta la strada scelta in C3 (uid 10001 + gid 0) poggia su questi bit: setgid + scrittura di
# gruppo. Se una dir viene ricreata a mano diventa 0755 e i container smettono di scrivere.
for d in raw vault db; do
  m="$(stat -c '%a' "/srv/workbrain/$d" 2>/dev/null)"
  eq "/srv/workbrain/$d e' 2770 (setgid + gruppo in scrittura)" "2770" "${m:-assente}"
done
ok "il daemon docker risponde"           docker version
ok "il daemon e' in modalita' rootless"  bash -c "docker info 2>/dev/null | grep -q '^  rootless$'"
# Mettere `ubuntu` nel gruppo docker equivale a dargli root: e' il workaround che D-01 vieta.
no "l'utente NON e' nel gruppo docker"   bash -c "id -nG | tr ' ' '\n' | grep -qx docker"
# Il daemon rootful e' stato spento in C2: se torna su, il confine di privilegio salta.
no "il daemon rootful e' spento"         systemctl is-active --quiet docker.service

echo
echo "Risultato: ${pass} verdi, ${fail} falliti."
[ "$fail" -eq 0 ]
