---
name: sync-plaud
description: Procedura riusabile per ispezionare e scaricare l'audio dal cloud Plaud verso raw/, in modo idempotente e con dominio esplicito. Usala ogni volta che devi portare registrazioni Plaud dentro WorkBrain.
---

# Skill: sync-plaud (device Plaud → raw/)

Porta l'audio dal cloud Plaud a `/srv/workbrain/raw/<domain>/<recording-id>/`, in modo **idempotente** (run id = id
registrazione) e con il **dominio esplicito**. Plaud è solo trasporto (decisione §2.1): niente subscription, la
trascrizione la fa la nostra STT. La trascrizione Plaud si scarica solo come **benchmark**.

## Step 0 — OBBLIGATORIO prima di qualsiasi azione
Esegui e leggi l'esito reale, poi decidi:
```bash
plaud me                        # sei loggato? (se no: procedura P-004, richiede il tunnel di Raf)
plaud recent --days 30          # cosa c'è di nuovo nel cloud (id, durata, data)
ls /srv/workbrain/raw/*/        # cosa è GIÀ stato scaricato (idempotenza: non riscaricare)
test -f /srv/workbrain/env.prod && echo "env presente"   # NON fare `cat`: le deny-rule lo rifiutano, ed e' giusto
```
Se `plaud me` fallisce → STOP, non proseguire: manca il login (P-004). Non inventare workaround.

## Scenari
- **A. Nuova registrazione singola** → conosci l'`<id>` da `plaud recent`. Scarichi audio + transcript benchmark.
- **B. Sync periodico** → confronti `plaud recent` con i path già presenti in `raw/`; scarichi solo i mancanti.
- **C. Dominio incerto** → NON forzare: scarichi in `raw/inbox/<id>/` e segnali a Raf (honest-act, domini-riservatezza).

## Template positivo (scenario A)
```bash
ID="<recording-id>"; DOMAIN="<legal-agency|opentext|personal|inbox>"
DST="/srv/workbrain/raw/${DOMAIN}/${ID}"
mkdir -p "$DST"
plaud audio "$ID"      -o "$DST/audio"            # audio (trasporto)
plaud transcript "$ID" -o "$DST/plaud-transcript.txt"   # solo benchmark, NON è la nostra STT
# meta minima, id sempre quotato nel frontmatter/JSON a valle (PAT-01)
```
Verifica finale sull'**artefatto** (non sugli step): `test -s "$DST/audio"* && echo "SYNC_OK $ID"`.

## Counter-example reale (perché questa skill esiste)
Test del 2026-09-05: `plaud transcript` produce `[mm:ss - mm:ss] Speaker N: …` ma sbaglia i termini tecnici —
"Plaud me" → "PlanMe", "npm" → "NMP", "Claude" → "Cloud" — e `plaud summary` **propaga** l'errore nella sua sintesi.
Chi in passato ha preso il transcript/summary Plaud come sorgente di verità ha ereditato quegli errori a valle.
Lezione codificata qui: il transcript Plaud entra in `raw/` **solo come benchmark**; la verità la produce la nostra STT
con glossario di dominio + step di correzione (vedi `.claude/rules/schema-kb.md` §glossario).

## Checklist pre-action
- [ ] `plaud me` OK (altrimenti P-004, STOP).
- [ ] `<id>` verificato in `plaud recent`, non a memoria.
- [ ] `<domain>` deciso con evidenza; in dubbio → `inbox` + notifica Raf.
- [ ] La destinazione `raw/<domain>/<id>` non esiste già (idempotenza).
- [ ] Naming lowercase; nessun segreto scritto in file tracciati.
- [ ] Verifica finale sull'artefatto prodotto, non sui singoli comandi.
