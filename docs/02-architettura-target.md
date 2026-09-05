# 02 — Architettura target — **BOZZA**

Ultimo aggiornamento: 2026-09-05
Stato: **BOZZA** — non si implementa nulla finché Raf non approva il piano (regola #8). Le scelte tecniche marcate
"TBD" si decidono con misure reali in `reports/BRIEF-001-analisi-soluzione.md`.

## Obiettivo
Portare l'audio di un **Plaud Pro** (meeting, call, idee a voce, talk) a **conoscenza strutturata**, bilingue IT/EN,
**segregata per dominio**, interrogabile in linguaggio naturale (Claude Code/Desktop/mobile) e leggibile come markdown
Obsidian. Plaud = **solo trasporto** dell'audio (device → cloud → download). La trascrizione la facciamo noi.

## Flusso end-to-end (come lo capiamo oggi)
```
[Plaud Pro] --registra--> [cloud Plaud]
     │  (trasporto, no subscription: §2.1)
     ▼
F1  sync audio      plaud recent/audio ──> raw/<domain>/<id>/audio.*  (+ plaud-transcript come BENCHMARK)
     ▼                                       └─ idempotente: run id = recording id
F2  STT+diarizza    STT API (EU, no-training, glossario/keyterms) ──> raw/<domain>/<id>/stt.json
     │                 └─ diarizzazione (speaker N) + step di CORREZIONE termini (glossario di dominio)
     ▼
F3  distill         LLM propone: dominio(+confidence/evidence), lingua, decisioni, azioni, titolo, tag
     │                 └─ determinismo: idempotenza, filtro dominio, quoting frontmatter, lowercase, lingua
     ▼                 └─ scrive vault/<domain>/<yyyy>/<id>-<slug>.md  (frontmatter YAML canonico)
F4  DB SSOT         upsert riga (id, domain, lang, embedding multilingue, ...) ──> INDEX.md DERIVATO dal DB
     ▼                 └─ colonna domain filtrata in OGNI query
F5  query/digest    MCP WorkBrain (ricerca cross-lingua) + digest periodico + azioni proposte (reminder/calendar/...)
     ▼                 └─ conferma umana prima di azioni verso l'esterno
F6  hardening       backup (restic/borg TBD), monitoraggio, retention, canary sulla prima registrazione vera
```

## Componenti e stato delle decisioni
| Componente | Scelta | Stato |
|---|---|---|
| Trasporto audio | CLI Plaud `@plaud-ai/cli` + MCP `@plaud-ai/mcp` | **deciso** (§2.6) |
| STT + diarizzazione | provider API con glossario, EU, no-training | **TBD** — BRIEF-001 (misure WER/costo/tempo/speaker) |
| Correzione termini | glossario per dominio + step deterministico | principio deciso; impl TBD |
| Storage conoscenza | raw/ (immutabile) → vault/ (md) → DB SSOT | struttura decisa; **motore DB TBD** (SQLite+sqlite-vec vs PostgreSQL+pgvector) |
| Embedding | multilingue (cross-lingua IT/EN senza traduzione) | **TBD** — BRIEF-001 |
| Runner/orchestrazione | systemd/cron + script idempotenti (no OpenClaw/DBOS in F1) | **deciso** (§2.5), rivedibile con motivazione |
| Query interface | MCP server WorkBrain | **TBD** design in F4 |
| Sync vault → Obsidian | vault markdown Obsidian-compatibile | meccanismo di sync **TBD** — BRIEF-001 |
| Backup | restic/borg su /srv/workbrain | **TBD** — F6 |

## Invarianti (non "TBD" — valgono comunque)
- **Segregazione domini inviolabile**: `domain` obbligatoria, filtrata in ogni query; mai mescolare; dubbio → `inbox`.
- **Determinismo garantisce, LLM comprende**: classificazione/estrazione propositive con confidence+evidence; il resto è codice.
- **Idempotenza**: run id = recording id; ripresa sicura dopo crash; nessun doppio-processing.
- **Tre livelli**: raw immutabile, vault leggibile con frontmatter canonico (quoting difensivo), DB SSOT come verità.
- **Dati fuori dal repo** (`/srv/workbrain/`), segreti in env.prod/`~/.plaud`; naming lowercase; `INDEX.md` derivato.
- **Canary sull'output finale**, non sugli ingredienti; marker machine-readable a fine job + fallback sull'artefatto.

## Decisioni aperte (da chiudere in BRIEF-001)
1. Provider STT (con diarizzazione + glossario + EU + no-training): quale, a quale costo/qualità misurati.
2. Motore DB SSOT: SQLite+sqlite-vec (semplicità, single-user) vs PostgreSQL+pgvector (robustezza). Misurare, non assumere.
3. Modello di embedding multilingue e dimensione/costo.
4. Come classificare il dominio in modo affidabile (segnali, soglie di confidence, quando cade in `inbox`).
5. Meccanismo di sync vault→Obsidian (git? syncthing? cartella montata?) e su quale device.
6. F5: quali azioni verso l'esterno (reminder/calendar/Notion/Slack) e con quale gate di conferma.
7. Strategia di backup e retention di `raw/` (audio pesante) vs `vault/`+`db/`.

## Cosa NON è questa architettura
Non è il sistema agentico multi-LLM di Legal Agency. È una **pipeline lineare, durabile, idempotenta**, single-user.
Se in analisi emerge che serve orchestrazione durabile (DBOS-like), va **motivato** e riportato a Raf, non introdotto di default.
