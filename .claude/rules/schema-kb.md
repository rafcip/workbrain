# Regola: schema della Knowledge Base

Struttura canonica dei tre livelli di conoscenza. Le **chiavi** sono in inglese canonico; i **valori/contenuti**
restano nella lingua della registrazione (bilingue senza traduzione, §2.3). Questo schema è **BOZZA**: si consolida
in F3/F4 del piano (vedi `reports/BRIEF-001-analisi-soluzione.md`). Modifiche → passano da Raf.

## Livello 1 — `raw/` (immutabile, evidenza)
`/srv/workbrain/raw/<domain>/<recording-id>/` contiene: `audio.*`, `plaud-transcript.txt` (benchmark), `stt.json`
(output STT nostro con diarizzazione), `meta.json` (id, durata, lingua rilevata, hash). Mai modificato dopo la scrittura.

## Livello 2 — `vault/` (markdown per umani, Obsidian)
`/srv/workbrain/vault/<domain>/<yyyy>/<recording-id>-<slug>.md`. Naming **lowercase**. Frontmatter YAML canonico:
```yaml
---
id: "<recording-id>"          # stringa, sempre quotata
domain: "legal-agency"        # uno tra: legal-agency|opentext|personal|inbox — OBBLIGATORIO
lang: "it"                    # lingua della registrazione (it|en|mixed)
recorded_at: "2026-09-05T10:30:00+02:00"
duration_min: 42
title: "<titolo: quotare sempre — può contenere i due punti>"   # PAT-01
speakers: ["speaker 1", "speaker 2"]
source: "plaud"
confidence: 0.0               # confidenza di classificazione dominio (0..1)
tags: []
---
```
Regola di **quoting difensivo** (PAT-01): ogni valore che può contenere `:` `#` `[` va quotato. Il generatore di
frontmatter quota per default tutte le stringhe.

## Livello 3 — DB SSOT
Motore (SQLite+sqlite-vec vs PostgreSQL+pgvector) **da decidere** in BRIEF-001 con misure. Requisiti fissi:
- Colonna `domain` NOT NULL, **filtrata in ogni query** (vedi domini-riservatezza.md).
- Embedding **multilingue** (ricerca cross-lingua IT/EN senza traduzione).
- `id` = recording-id (idempotenza: run id = id registrazione).
- `INDEX.md` del vault **sempre derivato** dal DB, mai scritto a mano.

## Glossario di dominio (correzione termini)
Plaud sbaglia i termini tecnici e propaga l'errore nel summary (es. "Claude"→"Cloud", "npm"→"NMP"). La nostra STT
usa un **glossario/keyterms per dominio** + uno step di correzione deterministico. Il glossario vive in
`/srv/workbrain/` (fuori dal repo) e per dominio, così non mescola terminologia riservata.
