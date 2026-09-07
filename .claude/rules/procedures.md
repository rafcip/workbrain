# Regola: procedure numerate (P-series)

Procedure operative riusabili. Ogni procedura ha ID stabile `P-NNN`, precondizioni, passi verificabili, esito atteso.
Le procedure complesse/ripetute diventano skill in `.claude/skills/`. Qui l'indice canonico.

## P-001 — Avvio sessione
Vedi `.claude/rules/continuity.md` §"All'avvio". Esito: conosci stato reale + bloccanti aperti.

## P-002 — Chiusura sessione / handoff
Vedi `.claude/rules/continuity.md` §"salva sessione". Esito: history aggiornata, stato aggiornato, bloccanti elencati.

## P-003 — Attivare il lockdown SSH (dopo chiave `ubuntu`) — **ESEGUITA il 2026-09-07**
Esito: `passwordauthentication no`, `permitrootlogin without-password`. Verificato con prova attiva
(`ssh -o PreferredAuthentications=password` → `Permission denied`), non leggendo la config. La console hPanel
continua a funzionare perché entra come root **via chiave**. Dettagli e rollback:
[[2026-09-07-remote-github-e-lockdown-ssh]].
Precondizione: chiave pubblica di Raf in `/home/ubuntu/.ssh/authorized_keys` **testata** da una seconda sessione SSH aperta.
Precondizione aggiunta il 2026-09-06: **leggere prima** `99-workbrain-lockdown.conf.disabled` e confermare che dica
`PermitRootLogin prohibit-password` e **non** `no`. Con `no` si perde anche la console di recupero di hPanel.
1. `sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf`
2. `sudo mv /etc/ssh/sshd_config.d/99-workbrain-lockdown.conf.disabled /etc/ssh/sshd_config.d/99-workbrain-lockdown.conf`
3. `sudo sshd -t && sudo systemctl reload ssh`
4. Verifica: `sshd -T | grep -iE 'passwordauthentication|permitrootlogin'` → `no` / `prohibit-password`.
5. **Non chiudere** la sessione SSH corrente finché non hai riconnesso con la chiave in una nuova sessione.

## P-004 — Login Plaud (richiede browser di Raf) — **eseguita con successo il 2026-09-05**
Precondizione: Raf ha un client SSH sul suo PC (PowerShell su Windows va bene). **Non serve la chiave SSH**:
il tunnel funziona con la password di root. Trappole della CLI: `knowledge/platform/plaud-cli-mcp.md`.
1. Raf apre dal suo PC e **lascia la finestra aperta**: `ssh -L 8199:localhost:8199 root@<ip-vps>`.
2. **Verifica il tunnel prima del login** (nessun timer addosso): sul VPS `python3 -m http.server 8199 --bind 127.0.0.1`,
   Raf apre `http://localhost:8199` dal browser → deve vedere la pagina; lato VPS deve comparire `GET / … 200`. Poi spegnere.
3. Predisporre il cattura-URL (la CLI non stampa l'URL su headless — vedi platform), in un path leggibile da `ubuntu`.
4. Lanciare **come `ubuntu`** (non root, altrimenti il token va in `/root/.plaud/`):
   `sudo -u ubuntu -H bash -c '. $HOME/.nvm/nvm.sh; BROWSER=<cattura-url> DISPLAY= plaud login'`
5. Consegnare l'URL a Raf, che lo apre e autorizza **entro 120 s**. Se scade: rilanciare (l'URL vecchio è morto).
6. Verifica: `plaud me` e `plaud recent --days 30` eseguiti **come `ubuntu`**.
7. Ripulire i file temporanei del cattura-URL.

## P-005 — Backup pre-modifica
Prima di toccare un file critico: `cp <file> <file>.bak-pre-<feature>-$(date +%F)`. Annota il rollback nella history.

## P-006 — Aggiungere una nuova procedura
Assegna il prossimo `P-NNN` libero, scrivi precondizioni + passi verificabili + esito atteso, linka dalla history che l'ha motivata.

## P-007 — Installare o riarmare le unit systemd utente
Precondizione: girare come `ubuntu` (mai root: sono unit **utente**) e avere `Linger=yes`
(`loginctl show-user ubuntu`). Le unit versionate stanno in `systemd/user/`; quelle attive sono symlink.
1. `bash scripts/install-units.sh` — crea/rinfresca i symlink in `~/.config/systemd/user/` e fa il `daemon-reload`.
   È idempotente e **non arma niente**: quali timer accendere è una decisione operativa, non un effetto collaterale.
2. Armare i timer voluti: `systemctl --user enable --now workbrain-backup.timer` (idem per
   `workbrain-docker-prune.timer` e le istanze `workbrain-step@<step>.timer`).
3. Verifica: `systemctl --user list-timers` mostra i timer con `NEXT` valorizzato, e
   `bash tests/run.sh` resta verde (un test controlla che l'unit attiva sia il symlink al repo).
⚠️ Con `Type=oneshot` il limite di durata è `TimeoutStartSec=`: `RuntimeMaxSec=` viene **ignorato** da systemd.
Motivata da [[2026-09-07-fase-c-container-rootless]].
