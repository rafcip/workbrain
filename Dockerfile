# Immagine base di WorkBrain. PLAN-001 D-03 / Fase C3.
#
# COS'E' E COSA NON E': e' lo *scheletro* che dimostra i vincoli di D-03 (digest pinnato,
# utente non-root, rootfs sola lettura). Non contiene ancora codice di pipeline: linguaggio,
# dipendenze e step veri si decidono nel piano nuovo della piattaforma (Fase D), e questo file
# e' fatto per essere sostituito, non per fissare quelle scelte.
#
# Perche' Python: e' la base con l'ecosistema piu' diretto per STT/embedding/DB, ma la scelta
# NON e' vincolante — cambiare la riga FROM e' l'intero costo di cambiare idea.
#
# Immagine pinnata per DIGEST, mai per tag: un tag e' un puntatore mobile e rende il build
# irriproducibile nel momento esatto in cui la riproducibilita' servirebbe (indagine su un bug).
# Per aggiornare: `docker pull python:3.13-slim-bookworm` e rileggere il RepoDigest.
FROM python@sha256:ed86c82274b3c69b52fb5820f358f0bd7df0b603332063cb5c6e32bd220c3e6e
# tag corrispondente al digest: python:3.13-slim-bookworm (Python 3.13.15) — verificato 2026-09-07

# PYTHONDONTWRITEBYTECODE: il rootfs e' in sola lettura, i .pyc non avrebbero dove andare.
# PYTHONUNBUFFERED: senza, i log del container arrivano a blocchi e journalctl mente sui tempi.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Questa label e' cio' che salva l'immagine dal prune notturno, e non e' un dettaglio estetico.
# `docker image prune -a` cancella ogni immagine TAGGATA ma non referenziata da un container: siccome
# tutti gli step sono `--rm` one-shot, fuori da un'esecuzione nessuna immagine e' referenziata e
# `workbrain-base` verrebbe cancellata dopo 24h. Il canary si sarebbe messo a ricostruire l'immagine
# a ogni scatto, di notte, con pull anonimo da Docker Hub — e avrebbe smesso di misurare cio' che deve.
# `scripts/docker-prune.sh` esclude questa label; un test verifica che le due parti restino allineate.
LABEL com.workbrain.keep="true"

# --- Identita' del processo: uid 10001, gid 0 -------------------------------------------------
# Due confini distinti, non uno solo:
#   * fuori dal container il rootless garantisce che tutto giri come `ubuntu` (D-01);
#   * dentro il container l'uid 10001 impedisce di essere root nel proprio namespace (D-03).
#
# Il gid 0 non e' una svista ed e' la parte non ovvia. Nel rootless la mappatura e':
#   uid/gid 0 nel container -> 1000 sull'host (`ubuntu`);  uid/gid N>0 -> 100000+N-1.
# Un processo con gid 10001 avrebbe gid host 110000 e NON potrebbe scrivere in /srv/workbrain,
# che appartiene a `ubuntu:ubuntu`. Con gid 0 il gruppo torna a essere `ubuntu` sull'host:
# lo step scrive nei mount previsti restando non-root dentro. Verificato, non assunto (Fase C3).
RUN groupadd --gid 10001 workbrain \
 && useradd --uid 10001 --gid 0 --groups workbrain \
            --create-home --shell /usr/sbin/nologin workbrain

WORKDIR /app

# Le dipendenze verranno da requirements.txt quando ci saranno: il layer sta qui, prima del
# codice, perche' cambia molto piu' di rado (cache del builder).
# COPY requirements.txt ./
# RUN pip install --no-cache-dir -r requirements.txt

# Nell'immagine entra solo cio' che serve a uno step. `scripts/` contiene utilita' operative
# dell'HOST (backup, prune, installazione unit): dentro il container sono superficie inutile.
COPY --chown=10001:0 docker/entrypoint.sh /usr/local/bin/workbrain-entrypoint

USER 10001:0

# L'entrypoint fissa solo la umask (vedi docker/entrypoint.sh) e poi esegue il comando ricevuto:
# ogni step della pipeline resta un container one-shot con il proprio comando esplicito (D-03),
# non un processo generico dietro un nome unico.
ENTRYPOINT ["/usr/local/bin/workbrain-entrypoint"]
CMD ["python3", "-c", "import sys, os; print(f'workbrain base ok - python {sys.version.split()[0]} - uid={os.getuid()} gid={os.getgid()}')"]
