# docs/ — indice e protocollo

Documentazione di progetto WorkBrain. **Italiano** nei testi, **chiavi tecniche in inglese** canonico.
Ogni documento porta in testa "Ultimo aggiornamento: YYYY-MM-DD". I documenti numerati sono stabili;
il file aggiornato più spesso è `10-stato-e-backlog.md`.

## Protocollo
- I **report** (analisi SOTA, brief, piani) vivono in `reports/`, non in chat.
- Ogni fix/decisione/incidente → una entry datata in `knowledge/history/` (non qui).
- Un piano si implementa **solo** dopo ok esplicito di Raf; i piani in BOZZA restano BOZZA.
- Prima di modificare un documento numerato, verifica che non contenga già la verità (evita duplicati).

## Indice
| doc | contenuto |
|---|---|
| `00-lineage-legal-agency.md` | Cosa WorkBrain eredita (e cosa NO) dal sistema Legal Agency. Consapevolezza per ogni sessione. |
| `02-architettura-target.md` **[BOZZA]** | Flusso end-to-end come lo capiamo oggi + decisioni aperte. |
| `05-infrastruttura-vps.md` | Setup e stato reale del VPS (utente, hardening, tool, cartelle). |
| `10-stato-e-backlog.md` | Stato operativo, sorveglianze/canary, lavori approvati/in attesa, tech debt, metriche, timeline. |

(Numerazione con salti volutamente lasciati liberi: 01, 03-04, 06-09 disponibili per documenti futuri —
es. 01-visione, 03-pipeline, 04-schema-dati — man mano che le fasi li richiedono.)

## Fuori da docs/
- `CLAUDE.md` (root) — identità, stato, regole brevi. `.claude/rules/` — regole operative per tema.
- `reports/BRIEF-001-analisi-soluzione.md` — il brief della prossima sessione (misure → scelte).
- `knowledge/platform/` — comportamenti non documentati delle piattaforme.
