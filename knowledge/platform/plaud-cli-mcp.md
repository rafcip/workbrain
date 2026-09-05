# Platform: Plaud CLI e MCP — comportamenti osservati

Ultimo aggiornamento: 2026-09-05
Comportamenti non documentati / osservati direttamente. Verificare che valgano ancora prima di farci affidamento.

## Versioni (2026-09-05, VPS srv1958735)
- CLI: `@plaud-ai/cli` **0.3.11** (installato globale nel Node di `ubuntu`). `plaud --version` → "unknown option" (non supportato).
- MCP: `@plaud-ai/mcp` invocato on-demand via `.mcp.json` (`npx -y @plaud-ai/mcp@latest`).

## Autenticazione (login) — eseguito con successo il 2026-09-05
- `plaud login` è OAuth con PKCE. Apre un server di callback **sul VPS** su `127.0.0.1:8199` e attende. Il `redirect_uri`
  è **cablato nel codice** (`http://localhost:8199/auth/callback`, `dist/index.js` ~riga 20972): non è configurabile,
  quindi **serve per forza un tunnel** dal PC di Raf. Vedi procedura **P-004**.
- Il tunnel **non richiede la chiave SSH**: `ssh -L 8199:localhost:8199 root@<ip>` con la password di root funziona
  (il port forwarding è a livello di connessione, l'utente non conta). Il **comando** però va lanciato come `ubuntu`,
  altrimenti il token finisce in `/root/.plaud/` invece che in `/home/ubuntu/.plaud/`.
- Verifica: `plaud me` (identità), `plaud recent --days 30` (elenco registrazioni). Token in `~/.plaud/` (fuori dal repo, mai in git).

### ⚠️ Due trappole verificate (costate due login falliti)
1. **L'URL OAuth non viene mai stampato su un server headless.** Il codice fa `open(url)` e stampa l'URL solo nel
   `.catch()` ("Could not open browser. Open this URL manually: …"). Ma il pacchetto `open` risolve la promise
   **appena lancia il processo figlio**, non quando quello fallisce: il catch non scatta e l'URL resta invisibile.
   Non basta che manchi `xdg-open` di sistema — `open` si porta dietro il proprio.
   **Workaround che funziona**: passare `BROWSER=<script>` dove lo script scrive `"$@"` su un file ed esce 0.
   ```sh
   #!/bin/sh
   printf '%s\n' "$@" >> /percorso/url.txt
   exit 0
   ```
   Lo script deve stare in un path **attraversabile dall'utente `ubuntu`** (non nella scratchpad di root).
2. **Timeout fisso di 120 s** (`LOGIN_TIMEOUT_MS = 12e4`, `dist/index.js` ~riga 20992), che parte quando il server
   di callback si mette in ascolto — cioè **prima** che l'umano veda l'URL. Se serve più tempo si può alzare quella
   costante, ma è una modifica locale a `node_modules` che sparisce a ogni update: preferire un canale veloce per
   consegnare l'URL. **Ogni rilancio genera un URL nuovo** (PKCE + `state` diversi): i vecchi URL sono morti.
- **Diagnosticare il tunnel separatamente**, prima del login e senza timer addosso:
  `python3 -m http.server 8199 --bind 127.0.0.1` sul VPS, poi aprire `http://localhost:8199` dal browser.
  Isola "tunnel rotto" da "troppo lento" invece di indovinare.

## Comandi utili (osservati / attesi)
- `plaud recent --days N` — elenca le registrazioni recenti (id, durata, data).
- `plaud audio <id> -o <path>` — scarica l'audio (trasporto).
- `plaud transcript <id>` — esporta trascrizione nel formato `[mm:ss - mm:ss] Speaker N: …`.
- `plaud summary <id>` — summary markdown nella lingua dell'audio.

## Limiti noti (IMPORTANTE per la pipeline)
- **Errori sistematici sui termini tecnici** (test 2026-09-05): "Plaud me"→"PlanMe", "npm"→"NMP", "Claude"→"Cloud".
- `plaud summary` **propaga** questi errori nella sintesi. → NON usare transcript/summary Plaud come sorgente di verità;
  valgono solo come **benchmark**. La nostra STT usa glossario di dominio + step di correzione (vedi `schema-kb.md`).
- Piano gratuito: ~300 min/mese di trascrizione → non ci si affida (decisione [[2026-09-05-DECISIONE-no-subscription-plaud]]).

## Da verificare in BRIEF-001
- Formato esatto e flag di `plaud audio`/`transcript` sulla 0.3.11 (nomi output, codec audio scaricato).
- Cosa espone il Plaud MCP (tool disponibili) e se duplica o integra la CLI.
