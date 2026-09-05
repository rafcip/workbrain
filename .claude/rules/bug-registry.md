# Regola: registro bug e pattern risolti

Ogni bug ha ID `BUG-NNN`: sintomo, causa radice, fix, stato, e (se generalizzabile) il **pattern** da non ripetere.
Consulta questo file **prima** di ogni fix (regola non negoziabile #1). I pattern qui sotto sono lezioni già pagate
in Legal Agency: valgono come vincoli di progettazione, non come bug aperti.

## Stato
Nessun bug di runtime aperto: la pipeline non esiste ancora (fase bootstrap). Sezione da popolare da F2 in poi.

## Pattern ereditati (lezioni Legal Agency — evitare a monte)
- **PAT-01 — YAML frontmatter e i due punti**: valori con `:` non quotati rompono il parser. Quoting difensivo
  su ogni valore di frontmatter generato dalla pipeline. Vedi `.claude/rules/schema-kb.md`.
- **PAT-02 — File mixed-case invisibili**: naming non-lowercase sul filesystem sfugge all'indicizzatore. Tutti i path
  generati in lowercase.
- **PAT-03 — Agenti che orchestrano con exec sincroni**: anti-pattern rimosso a giugno 2026. Orchestrazione = workflow
  durabili idempotenti, non exec sincroni dentro un agente.
- **PAT-04 — Girare come root / più root dati**: usare utente operativo non root, una sola root dati, DB in bind su 127.0.0.1.
- **PAT-05 — "Aggiungiamo un altro check"**: workaround su workaround. Un workaround che fallisce → STOP → ricerca SOTA.
- **PAT-06 — Validare gli ingredienti invece del risultato**: il canary valida l'**output finale** (la nota prodotta),
  non i singoli step intermedi.

## Formato di una entry
```
### BUG-NNN — <titolo>  [aperto|risolto YYYY-MM-DD]
- Sintomo:
- Causa radice:
- Fix:
- Verifica (esito reale):
- Pattern generalizzato (se c'è): PAT-xx
```
