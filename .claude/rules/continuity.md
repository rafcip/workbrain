# Regola: continuità di sessione

## All'avvio di ogni sessione (in ordine)
1. Leggi `CLAUDE.md` (identità, stato, regole brevi).
2. Leggi `docs/10-stato-e-backlog.md` — è il file aggiornato più spesso: stato operativo, canary/sorveglianze,
   lavori approvati, in attesa di decisione, tech debt, metriche, timeline.
3. Scorri gli ultimi 3-5 file di `knowledge/history/` (ordine data) e ogni `*-HANDOFF-*.md` non chiuso.
4. Se stai per fixare qualcosa: leggi `.claude/rules/bug-registry.md` **prima** di toccare codice.
5. Verifica lo stato reale con comandi (non fidarti della memoria): `git -C ~/workbrain status`,
   `systemctl --user status` dei servizi WorkBrain quando esisteranno, `plaud me`.

## Durante la sessione
- Ogni fix/deploy/incidente/decisione di Raf → una entry datata in `knowledge/history/` (`YYYY-MM-DD-titolo.md`).
- Decisioni di Raf → file `YYYY-MM-DD-DECISIONE-<slug>.md`. Lavoro lasciato a metà → `YYYY-MM-DD-HANDOFF-<slug>.md`.
- Aggiorna `docs/10-stato-e-backlog.md` a ogni cambiamento di stato operativo.

## Quando Raf dice "salva sessione" (handoff di chiusura)
1. Scrivi/aggiorna la history del giorno con: cosa fatto, cosa verificato (con esito reale), cosa resta aperto.
2. Se resta lavoro a metà → `*-HANDOFF-*.md` con: stato esatto, prossimo passo concreto, comandi di ripresa, rischi.
3. Aggiorna la sezione "Stato corrente" di `CLAUDE.md` e `docs/10-stato-e-backlog.md`.
4. Se hai toccato config/hook/infra → annota in `docs/05-infrastruttura-vps.md`.
5. Chiudi elencando a Raf i bloccanti che richiedono una sua azione o decisione.
