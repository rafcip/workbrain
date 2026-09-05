# Platform: Plaud CLI e MCP — comportamenti osservati

Ultimo aggiornamento: 2026-09-05
Comportamenti non documentati / osservati direttamente. Verificare che valgano ancora prima di farci affidamento.

## Versioni (2026-09-05, VPS srv1958735)
- CLI: `@plaud-ai/cli` **0.3.11** (installato globale nel Node di `ubuntu`). `plaud --version` → "unknown option" (non supportato).
- MCP: `@plaud-ai/mcp` invocato on-demand via `.mcp.json` (`npx -y @plaud-ai/mcp@latest`).

## Autenticazione (login)
- `plaud login` richiede un **browser** e apre/attende su **localhost:8199**. Sul VPS headless serve un tunnel dal PC di Raf:
  `ssh -L 8199:localhost:8199 ubuntu@<ip-vps>` e poi completare nel browser locale. Vedi procedura **P-004**.
- Verifica: `plaud me` (identità), `plaud recent --days 30` (elenco registrazioni). Token in `~/.plaud/` (fuori dal repo, mai in git).

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
