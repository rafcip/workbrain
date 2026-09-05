# 2026-09-05 — Login Plaud completato + causa reale del blocco "non riesco a copiare"

Sessione serale. Chiude il **bloccante #2** (`plaud login`) e, soprattutto, il blocco di workflow che lo
teneva fermo: l'impossibilità di copiare testo dalla console web di Hostinger hPanel.

## 1. La copia: la diagnosi di ieri era incompleta

Ieri ([[2026-09-05-copia-testo-console-web-hostinger]]) la causa era stata attribuita al **mouse tracking**
della TUI di Claude Code, con fix `CLAUDE_CODE_DISABLE_MOUSE=1` in `/root/.bashrc`.

**Quel fix non è mai stato attivo.** Verificato leggendo l'ambiente reale del processo:

```
$ tr '\0' '\n' < /proc/11148/environ | grep -i MOUSE
(nessun risultato)
```

Claude Code era nato alle 20:03; la riga in `.bashrc` è stata scritta alle ~20:19. Le variabili d'ambiente
si leggono alla nascita del processo. Quindi la copia non funzionava perché il fix non era in funzione —
ma non è nemmeno dimostrato che quel fix fosse la soluzione.

### Causa reale
Impostazione scelta al **primo avvio** di Claude Code, in `/root/.claude/settings.json`:

```json
{ "tui": "fullscreen" }
```

`fullscreen` usa lo **schermo alternato** del terminale (come `vim`/`less`): disegna su un buffer separato
che il terminale dentro una pagina web non tratta come testo selezionabile. Un terminale nativo lo gestisce
bene — per questo "da terminale funzionava".

### Fix applicato (da Raf, comando nella TUI)
```
/tui default
```
Il renderer torna al buffer normale con scrollback vero. Il comando salva la preferenza e **riavvia
riprendendo la sessione** (nessun `--continue` necessario).

### Verifica (esito reale)
- `/root/.claude/settings.json` → `"tui": "default"`.
- Raf ha selezionato e copiato una stringa di test dalla console web: **funziona**. Confermato da lui.

### Tech debt lasciato
`export CLAUDE_CODE_DISABLE_MOUSE=1` è **ancora** in `/root/.bashrc` (riga 108) ed è un workaround mai
dimostrato. Alla prossima shell nuova diventerà attivo e disattiverà lo scroll con la rotella senza che
nessuno ricordi perché. **Da decidere con Raf**: rimuoverlo (config → serve il suo ok, regola #3).

## 2. `plaud login` — completato

Procedura P-004, con una variante rispetto a quanto scritto: il tunnel **non richiede la chiave SSH**.
Raf si è collegato dal suo PC con `ssh -L 8199:localhost:8199 root@<ip>` e la password di root.

- Tunnel verificato **prima** del login, separatamente e senza timer: listener HTTP di prova sulla 8199 del
  VPS, Raf ha aperto `http://localhost:8199` dal browser → pagina vista, e `GET / HTTP/1.1 200` nel log lato VPS.
  Questo ha isolato "tunnel rotto" da "troppo lento", invece di indovinare.
- Login eseguito **come utente `ubuntu`** (`sudo -u ubuntu -H`), così il token finisce in `/home/ubuntu/.plaud/`,
  dove puntano `.mcp.json` e le deny-rule dell'harness. Girare il comando da root l'avrebbe messo in `/root/.plaud/`.
- Esito: `✔ Logged in successfully!` · `plaud me` come `ubuntu` → identità corretta, workspace presente.

### Comportamenti non documentati della CLI Plaud (v0.3.11)
Due ostacoli reali, costati due tentativi falliti. Dettaglio in `knowledge/platform/`.

1. **L'URL OAuth non viene mai stampato su server headless.** Il codice fa `open(url)` e stampa l'URL solo
   nel `.catch()`. Ma il pacchetto `open` risolve la promise **appena lancia il processo figlio**, non quando
   quello fallisce — quindi il catch non scatta mai e l'URL resta invisibile.
   *Workaround usato*: `BROWSER=<script>` che scrive `$1` su file invece di aprire il browser. La CLI passa
   l'URL al finto browser e noi lo leggiamo.
2. **Timeout fisso di 120s** (`LOGIN_TIMEOUT_MS = 12e4` in `dist/index.js`), che parte quando il server di
   callback si mette in ascolto — cioè prima che l'umano veda l'URL. Con la copia funzionante 2 minuti bastano.
   *Non abbiamo patchato la CLI*: la modifica era stata proposta a Raf ma è diventata inutile una volta
   risolta la copia. Meglio così: nessuna modifica locale a `node_modules` da riapplicare a ogni update.

## 3. Inventario sorgente (BRIEF-001 Step 0.1)

`plaud recent --days 30` → **5 registrazioni**. Composizione (solo metadati, nessun contenuto):

| tipo | quante | durata | note |
|---|---|---|---|
| materiale demo di Plaud | 3 | 1h21m, 4m13s, 3m46s | EN; una è multi-speaker (utile per la diarizzazione) |
| registrazione reale di Raf | 1 | 1m06s | IT, tema tecnico |
| registrazione di prova | 1 | 7s | trascurabile |

Nessun contenuto riconducibile a `opentext` o a clienti dello studio: si può lavorare in `personal`.

### Gap che blocca lo Step 0.2
Il brief chiede **3 campioni rappresentativi: IT, EN, misto IT/EN**, con più speaker e densità di termini
tecnici. Oggi mancano:
- un campione **misto IT/EN** — non esiste;
- un campione **IT multi-speaker** e di durata utile (l'unico IT è 1m06s);
- materiale IT con **densità di termini tecnici** sufficiente a misurare il glossario.

→ **Azione per Raf**: registrare 2-3 campioni di prova (`personal`), vedi `docs/10-stato-e-backlog.md`.

## Riferimenti
[[2026-09-05-copia-testo-console-web-hostinger]] · [[2026-09-05-HANDOFF-bootstrap]] ·
`.claude/rules/procedures.md` (P-004) · `reports/BRIEF-001-analisi-soluzione.md`
