#!/usr/bin/env bash
# Backup di /srv/workbrain (dati veri) con restic. PLAN-001 D-07 / Fase B4.
#
# Cosa protegge OGGI: cancellazioni accidentali, corruzione, "ho sovrascritto il file sbagliato".
# Cosa NON protegge: la perdita del VPS. Il repository e' sulla STESSA macchina dei dati.
# Portarlo fuori richiede una destinazione e una decisione di riservatezza di Raf: finche' non c'e',
# questo backup e' meta' del lavoro, e va detto invece di lasciarlo credere completo.
#
# La cifratura di restic e' lato client: quando il repository uscira' dalla macchina, il fornitore
# vedra' solo blob opachi. E' la premessa che rende possibile quel passo, non il passo stesso.
#
# Uso:  bash scripts/backup.sh            (crea uno snapshot + verifica)
#       bash scripts/backup.sh --check    (solo verifica integrita', nessuno snapshot)
set -euo pipefail

REPO_DATA="/srv/workbrain"
RESTIC_REPO="${REPO_DATA}/backups/restic"
PASS_FILE="${REPO_DATA}/restic-pass"

# Politica di conservazione: abbondante sul recente, rada sul vecchio.
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

r() { restic -r "$RESTIC_REPO" --password-file "$PASS_FILE" "$@"; }

if [ ! -r "$PASS_FILE" ]; then
  echo "ERRORE: password del repository non leggibile ($PASS_FILE)." >&2
  exit 1
fi

if [ "${1:-}" = "--check" ]; then
  r check
  exit $?
fi

# I dati, non il backup di se stesso: escludere backups/ evita la ricorsione.
r backup \
  "${REPO_DATA}/raw" "${REPO_DATA}/vault" "${REPO_DATA}/db" \
  --exclude "${REPO_DATA}/backups" \
  --tag workbrain

r forget --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" --prune

# Verifica sull'ARTEFATTO, non sugli step (PAT-06): il comando e' andato a buon fine E lo snapshot esiste.
if ! r snapshots --json | grep -q '"short_id"'; then
  echo "ERRORE: il backup e' terminato senza errori ma non risulta alcuno snapshot." >&2
  exit 1
fi

r check --read-data-subset=5%
echo "BACKUP_OK $(date -Is)"
