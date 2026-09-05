# 10 — Stato e backlog

Ultimo aggiornamento: 2026-09-05

Il file aggiornato più spesso. Fonte di verità sullo stato operativo. All'avvio di ogni sessione si legge questo
(vedi `.claude/rules/continuity.md`).

## Stato operativo
- **Fase**: bootstrap dell'harness completato e **rivisto (verdetto GO del reviewer)**. Nessuna pipeline in esecuzione. Nessun servizio systemd WorkBrain attivo.
- Hook verificati con suite committata `tests/test_hooks.sh` (11/11 verdi).
- **VPS**: in ordine (utente `ubuntu`, UFW+fail2ban attivi, tool e CLI installati). Dettaglio: `docs/05-infrastruttura-vps.md`.
- **Provider STT / storage / embedding / runner**: **non ancora scelti** → si decidono in `reports/BRIEF-001-analisi-soluzione.md`.

## Sorveglianze / canary
- Nessun canary attivo (non c'è ancora pipeline). Il **primo canary** sarà la prima registrazione **vera** processata
  end-to-end (valida l'output finale, non gli ingredienti — regola #6), previsto in F2/F3.

## Lavori approvati (pronti da eseguire)
- Eseguire **BRIEF-001**: Step 0 di misure reali su 3 registrazioni (IT/EN/mista) e 2-3 provider STT, poi scelte.
  (Le decisioni tecniche dentro un brief approvato sono autonome; le scelte di prodotto tornano a Raf.)

## In attesa di decisione / azione di Raf (BLOCCANTI)
1. 🔴 **Chiave SSH pubblica** per l'utente `ubuntu` → poi procedura P-003 (lockdown password SSH).
   Finché manca, l'accesso al VPS resta via **password di root** (non ideale). Serve solo la pubkey di Raf.
2. 🔴 **`plaud login`** via tunnel (P-004): `ssh -L 8199:localhost:8199 ubuntu@<ip>` poi `plaud login`.
   Finché manca, non si può scaricare audio né misurare i provider su registrazioni reali.
3. 🟡 Conferma dei **domini** e delle regole di segregazione come codificate in `.claude/rules/domini-riservatezza.md`.

## Tech debt / rischi noti
- Sessione di bootstrap girata come root (mitigato: file assegnati a `ubuntu`; sessioni future come `ubuntu`).
- `env.prod` è un **template senza valori**: le chiavi provider vanno inserite dopo BRIEF-001.
- Schema KB e scelta motore DB sono **BOZZA**: si consolidano in F3/F4.

## Metriche (placeholder — da popolare con BRIEF-001)
- WER per provider (IT/EN/mista): —. Costo €/ora audio: —. Tempo di processing: —. Qualità diarizzazione: —.

## Timeline / fasi del piano (dettaglio in BRIEF-001)
- **F1** sync audio · **F2** STT+diarizzazione · **F3** distill+vault · **F4** DB+query MCP · **F5** digest+azioni · **F6** hardening+backup.
- Oggi: pre-F1 (harness pronto, provider da scegliere).
