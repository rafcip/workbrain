# 00 — Lineage: cosa WorkBrain eredita da Legal Agency

Ultimo aggiornamento: 2026-09-05

Questo documento dà a ogni futura sessione la **consapevolezza di Legal Agency** senza accesso al suo repo.
**Il repo `legal-agency-sysadmin` non è disponibile qui e non va richiesto: contiene PII.** Ciò che conta è distillato
qui: principi, regole e anti-pattern già pagati. WorkBrain è un progetto diverso e più piccolo — eredita il *metodo*,
non l'*architettura pesante*.

## Cos'è Legal Agency (contesto, non da replicare)
Sistema agentico multi-LLM in produzione (marzo→settembre 2026, ~70-85 casi attivi) che gestisce end-to-end la pratica
di uno studio di diritto militare: email → intake durabile → triage → analisi → strategia → atto → deposito, con gate
firmabili dall'avvocato. Stack: OpenClaw (agenti) + orchestrator DBOS (workflow durabili) + PostgreSQL/pgvector (SSOT)
+ QMD (memoria vettoriale) + cockpit + cron/systemd + restic.

## Cosa WorkBrain EREDITA (il metodo)
### Struttura dell'harness
- `CLAUDE.md` ≤100 righe (identità, stato, regole brevi, mappa, "dove trovare la verità").
- `.claude/rules/` una regola per tema; `.claude/agents/` subagent a contesto pulito; `.claude/skills/` con pattern SOTA;
  `.claude/hooks/` guardie deterministiche; `docs/` numerati; `knowledge/history/` + `knowledge/platform/`; `reports/` in file.

### Regole non negoziabili (in `CLAUDE.md`)
Diagnostica prima di agire; verifica su file/DB mai da memoria; permessi graduati (lettura libera, config→chiedi,
distruttivo→doppia conferma); **regola madre** (workaround fallito → STOP → ricerca SOTA); documentare ogni fix;
gate deterministici e canary sull'output finale; bug in prod → piano immediato; piani in BOZZA non si implementano
senza ok; sintesi oneste; backup + rollback + flag di disattivazione.

### Principi architetturali
- **L'LLM comprende, il determinismo garantisce**: il modello propone (classificazione, estrazione) con `confidence`+`evidence`;
  idempotenza, lingua, filtri di dominio, indici, validazioni sono **codice**. Mai patch per-caso.
- **Pipeline durabili e idempotenti** (run id = id registrazione), stato per step, ripresa dopo crash.
- **Tre livelli di conoscenza**: `raw/` immutabile → `vault/` markdown con frontmatter YAML canonico → **DB SSOT** con
  embedding e colonna `domain` filtrata in ogni query. `INDEX.md` sempre derivato dal DB.
- **Honest-act sopra honest-uncertainty**: con segnali convergenti si classifica; in dubbio → `inbox` + notifica.
- **Umano nei punti giusti**: revisione `inbox`; conferma prima di azioni verso l'esterno.
- Marker machine-readable a fine job + fallback deterministico sull'artefatto.

### Anti-pattern già pagati (ora vincoli — vedi `.claude/rules/bug-registry.md`)
- Frontmatter YAML: valori con `:` non quotati rompono il parser → **quoting difensivo** (PAT-01).
- File mixed-case invisibili all'indicizzatore → **naming lowercase** (PAT-02).
- Agenti che orchestrano con **exec sincroni** → rimosso a giugno 2026; orchestrazione = workflow durabili (PAT-03).
- Girare come root / più root dati → utente operativo non root, una root dati, DB in bind 127.0.0.1 (PAT-04).
- "Aggiungiamo un altro check" → workaround su workaround: STOP + SOTA (PAT-05).
- Validare gli ingredienti invece del risultato → il canary valida l'**output finale** (PAT-06).

## Cosa WorkBrain NON eredita (differenze deliberate)
- **Niente OpenClaw né DBOS in fase 1** (decisione Raf §2.5): single-user, volumi bassi. Claude Code + API +
  systemd/cron bastano. Si rivaluta solo se l'analisi dimostra che serve di più (e si motiva).
- **Niente multi-LLM agentico complesso**: la pipeline WorkBrain è lineare (sync → STT → distill → DB → query).
- **STT via API con diarizzazione**, non self-hosted (VPS piccolo) — Legal Agency non fa STT.
- **Dominio diverso**: qui la materia è la conoscenza di lavoro di Raf (meeting/idee), non pratiche legali di terzi.
  Nessun dato Legal Agency vive in WorkBrain e viceversa.
- Il DB SSOT potrebbe essere **SQLite+sqlite-vec** invece di PostgreSQL+pgvector (da decidere con misure, BRIEF-001):
  la scala non giustifica automaticamente Postgres.

## In una riga
Da Legal Agency prendiamo **la disciplina** (harness, regole, anti-pattern), non **la macchina** (stack agentico pesante).
