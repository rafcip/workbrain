# BRIEF-001 — Analisi e scelta della soluzione

Ultimo aggiornamento: 2026-09-05
Autore: SysAdmin WorkBrain (Claude Code). Committente: Raf. Stato: **da eseguire nella sessione successiva**.
Prerequisito bloccante: **`plaud login` completato** (procedura P-004) — senza, lo Step 0 non è eseguibile.

> Questo brief dice COSA misurare e COSA decidere. Il COME lo decidi tu con le misure. Le scelte tecniche interne
> a questo brief (approvato) sono **autonome** ("decidi con SOTA, non chiedere"); le scelte di prodotto tornano a Raf.
> Regola madre: se un approccio fallisce, STOP + ricerca SOTA, non "aggiungo un altro check".

---

## STEP 0 — Misure reali PRIMA di ogni opinione (obbligatorio)
Numeri prima di aggettivi. Esegui e **scrivi gli esiti in questo file** (tabelle sotto), poi decidi.

### 0.1 Inventario sorgente
```bash
plaud me
plaud recent --days 30          # elenco reale: id, durata, data, lingua presunta
```
### 0.2 Campione di prova (3 registrazioni rappresentative)
Scegli da `plaud recent` **3 registrazioni**: una **IT**, una **EN**, una **mista IT/EN**. Preferibile materiale
`personal` o sintetico per non toccare contenuti riservati in fase di test (segregazione). Scaricale in `raw/` con la
skill `sync-plaud`. Per ognuna nota: durata, presenza di più speaker, densità di **termini tecnici** (dove Plaud sbaglia).
### 0.3 Benchmark Plaud (baseline da battere)
Per ogni campione, esporta `plaud transcript` e `plaud summary`. Annota gli **errori sistematici** sui termini tecnici
(es. osservati il 2026-09-05: "Claude"→"Cloud", "npm"→"NMP", "Plaud me"→"PlanMe"). Questa è la baseline: la nostra STT
+ glossario deve fare **meglio**, misurato.
### 0.4 Prova di 2-3 provider STT sugli stessi 3 campioni
Candidati da valutare (verifica SOTA aggiornato al momento dell'esecuzione, non fidarti di questa lista):
- provider con **diarizzazione** nativa, **residenza dati EU**, **clausola no-training**, supporto **glossario/keyterms**.
- Esempi tipici da confrontare (verificare termini/prezzi correnti): Deepgram (nova, diarize, keyterms), AssemblyAI
  (diarization, word boost), Speechmatics (EU, diarization), Azure Speech (EU region, phrase list), ElevenLabs Scribe.
  **Non è una raccomandazione**: è la lista di partenza da misurare.
Per ciascun provider e ciascun campione misura e riporta:

| provider | campione | lingua | costo €/ora | tempo proc. | WER | diarizzazione (speaker giusti?) | glossario funziona? | EU/no-training |
|---|---|---|---|---|---|---|---|---|
| (baseline Plaud) | IT | it | 0 | — | — | — | no | — |
| … | … | … | … | … | … | … | … | … |

WER: calcola contro una trascrizione di riferimento (correggi a mano un estratto di ~2-3 min per campione).
Diarizzazione: conta gli speaker rilevati vs reali e gli scambi di turno errati. Glossario: verifica che i termini
tecnici del campione vengano resi correttamente **con** e **senza** keyterms.
### 0.5 Prova embedding multilingue (ricerca cross-lingua)
Su 5-10 frasi IT e la loro corrispondente EN, verifica che un modello multilingue le avvicini nello spazio vettoriale
(query IT trova nota EN e viceversa). Candidati da misurare: modelli multilingue di OpenAI/Cohere/Voyage o locali
(es. multilingual-e5) se il costo/latency lo giustifica. Misura: recall@k cross-lingua, costo, dimensione vettore.

---

## DECISIONI DA CHIUDERE (dopo lo Step 0, con i numeri)
1. **Provider STT** + configurazione glossario. Criterio: miglior WER sui termini tecnici a costo/tempo accettabili,
   con diarizzazione affidabile, EU + no-training. Documenta la matrice e la scelta.
2. **Motore DB SSOT**: SQLite+sqlite-vec (semplicità, single-user, backup = un file) vs PostgreSQL+pgvector (robustezza,
   query concorrenti). Default ragionevole per single-user/volumi bassi = SQLite+sqlite-vec, **da confermare** con la
   prova di ricerca; se emergono limiti reali (concorrenza, dimensione), motiva il passaggio a Postgres.
3. **Embedding**: modello multilingue scelto, dimensione, costo, dove gira (API vs locale).
4. **Runner**: systemd timer (idempotente, stato per step) vs cron. Default: **systemd** user services + timer.
5. **MCP WorkBrain**: forma della query interface (ricerca semantica + filtro `domain` obbligatorio), read-only in F4.
6. **Sync vault→Obsidian**: git privato vs syncthing vs cartella montata; su quale device di Raf; direzione (read-only?).
7. **Sicurezza**: chiudere il bloccante chiave SSH (P-003), retention/backup di `raw/` (audio pesante), cifratura a riposo.

---

## PIANO A FASI (con test di accettazione — nessuna fase si chiude senza test verde reale)
> Ogni fase: backup pre-modifica (P-005), flag env per disattivare, rollback esplicito. Canary sull'**output finale**.

### F1 — Sync audio (device → raw/)
- Deliverable: script/skill idempotente che porta le nuove registrazioni in `raw/<domain>/<id>/` senza riscaricare.
- **Test di accettazione**: eseguito due volte di fila, la seconda non riscarica nulla; `raw/` contiene audio+meta
  per ogni id di `plaud recent`; nessun file mixed-case; `SYNC_OK <id>` emesso per ognuno.

### F2 — STT + diarizzazione + correzione termini
- Deliverable: `stt.json` per ogni campione con speaker etichettati e termini corretti via glossario di dominio.
- **Test di accettazione**: sui 3 campioni, WER e correttezza termini **migliori della baseline Plaud** (numeri in tabella);
  speaker corretti sul campione multi-speaker; idempotente (rilancio non ricalcola se `stt.json` esiste).

### F3 — Distill + vault
- Deliverable: nota `vault/<domain>/<yyyy>/<id>-<slug>.md` con frontmatter canonico (quoting difensivo), lingua originale,
  decisioni/azioni estratte con confidence+evidence, dominio classificato (o `inbox`).
- **Test di accettazione**: frontmatter valido (parser non rompe su `:`); `domain` presente e coerente col path;
  nessun cross-dominio; naming lowercase; una registrazione ambigua finisce in `inbox` con notifica.

### F4 — DB SSOT + query MCP
- Deliverable: DB con embedding multilingue, colonna `domain` filtrata in ogni query; `INDEX.md` **derivato**; MCP read-only.
- **Test di accettazione**: query IT trova nota EN (cross-lingua); una query non può restituire risultati di un dominio
  diverso da quello richiesto (test di segregazione); `INDEX.md` rigenerato coincide col DB; idempotenza upsert su `id`.

### F5 — Digest + azioni
- Deliverable: digest periodico per dominio; azioni proposte (reminder/calendar/…) con **gate di conferma umana**.
- **Test di accettazione**: nessuna azione verso l'esterno parte senza conferma; il digest non mescola domini; marker
  machine-readable a fine job + fallback sull'artefatto.

### F6 — Hardening + backup
- Deliverable: backup di `vault/`+`db/` (e policy per `raw/` pesante), retention, monitoraggio, chiusura P-003.
- **Test di accettazione**: restore di prova ripristina vault+db in una dir temporanea e le query funzionano; lockdown
  SSH attivo e riconnessione con chiave verificata; UFW/fail2ban attivi.

---

## Rischi e note
- Senza `plaud login` lo Step 0 è bloccato: è il primo bloccante da chiudere con Raf (P-004).
- Non usare contenuti reali `opentext` o PII dello studio nei test: usa `personal` o campioni sintetici (hook attivo).
- Se un provider "sembra" migliore ma non offre EU/no-training, pesa il vincolo di riservatezza prima del WER.
- Le decisioni di prodotto (quali azioni in F5, quale device per Obsidian) tornano a Raf; le tecniche interne no.
