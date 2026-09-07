#!/usr/bin/env bash
# Pulizia periodica del daemon Docker ROOTLESS di `ubuntu`. PLAN-001 D-01 / Fase C2.
#
# Sostituisce i due cron di sistema che giravano come root contro il daemon rootful
# (/etc/cron.d/docker-builder-prune, /etc/cron.d/docker-image-prune), spenti in C2.
# Quei cron sono conservati in /srv/workbrain/backups/etc-cron.d/ per il rollback.
#
# Differenza deliberata rispetto ai cron sostituiti: la cache del builder veniva potata
# una volta a settimana senza filtro di eta'. Qui la si pota ogni giorno ma solo per la
# parte piu' vecchia di 7 giorni: stesso effetto sullo spazio, senza buttare via ogni
# sabato la cache di un build fatto il venerdi'.
#
# Non tocca MAI volumi e container: cancellare un volume e' distruttivo sui dati e non
# e' un lavoro da timer automatico (regola #3).
#
# Uso:  bash scripts/docker-prune.sh
set -euo pipefail

# Il daemon e' quello dell'utente, non quello di sistema: senza questa riga un servizio
# systemd utente senza ambiente interattivo cercherebbe /var/run/docker.sock, che non esiste piu'.
export DOCKER_HOST="${DOCKER_HOST:-unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock}"

IMAGE_MAX_AGE="24h"
BUILDER_MAX_AGE="168h"   # 7 giorni

# L'immagine del progetto NON si pota. Con step tutti `--rm`, fuori da un'esecuzione nessuna
# immagine risulta referenziata, quindi `prune -a` cancellerebbe anche `workbrain-base` e il timer
# di ogni step si trasformerebbe in una ricostruzione notturna con pull anonimo da Docker Hub.
# La label e' dichiarata nel Dockerfile; un test verifica che le due parti non divergano.
KEEP_LABEL="com.workbrain.keep=true"

echo "== docker-prune $(date -Is) — host: ${DOCKER_HOST}"

if ! docker version >/dev/null 2>&1; then
  echo "ERRORE: il daemon Docker rootless non risponde su ${DOCKER_HOST}" >&2
  exit 1
fi

echo "-- immagini non usate piu' vecchie di ${IMAGE_MAX_AGE} (escluse quelle con ${KEEP_LABEL})"
docker image prune -af --filter "until=${IMAGE_MAX_AGE}" --filter "label!=${KEEP_LABEL}"

echo "-- cache del builder piu' vecchia di ${BUILDER_MAX_AGE}"
docker builder prune -f --filter "until=${BUILDER_MAX_AGE}"

echo "-- spazio dopo la pulizia"
docker system df

echo "== docker-prune completato"
