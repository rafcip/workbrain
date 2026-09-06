# 2026-09-06 — PLAN-001 Fasi A e B: le guardie diventano vere, e nasce il backup

Esecuzione delle prime due fasi del piano, dopo il via di Raf ("dopo fase C ci fermiamo").
Tutto verificato con esito reale; dove un test è fallito, è scritto qui sotto.

## Fase A — sbloccare e mettere in sicurezza

| | Azione | Esito verificato |
|---|---|---|
| A1 | Chiave SSH per `ubuntu` | ✅ vedi [[2026-09-06-chiave-ssh-ubuntu-attiva]] |
| A2 | Lavorare come `ubuntu` | ⏸️ **rimandata**: la sessione Claude Code gira ancora come root (vedi §Aperti) |
| A3 | Remote git privato | ⏸️ **bloccata**: manca la scelta di Raf fra GitHub e GitLab |
| A4 | Swapfile 4 G | ✅ attivo, `vm.swappiness=10`. Entry di `fstab` **provata** con `swapoff` + `swapon -a`; `systemctl` vede `swapfile.swap` attiva |
| A5 | `enable-linger ubuntu` | ✅ `Linger=yes`, e verificato che il **gestore systemd utente è active/running** — non solo il flag |
| A6 | Igiene | ✅ MCP Plaud pinnato a `0.3.10` (era `@latest`: scaricava ed eseguiva l'ultima pubblicata a ogni invocazione); `CLAUDE_CODE_DISABLE_MOUSE` rimosso da `/root/.bashrc` (backup `.bak-pre-rm-mouse-2026-09-06`); `.tmux.conf` replicato per `ubuntu`; skill `sync-plaud` corretta (prescriveva un `cat` di `env.prod` che le deny-rule rifiutano) |

## Fase B — rendere vere le guardie che erano finte

### B1 — il gate dei test ora può fallire
Creato `tests/run.sh` come entry point unico che raccoglie tutte le suite. `run-tests.sh` lo invoca, e
**blocca** se i test sono rossi o se `run.sh` manca. Prima cercava `test_*.py` o `run.sh` — nessuno dei
due esisteva — e usciva sempre 0 dicendo "fase bootstrap" (AUDIT-001 R-02).

### B2 — fail-closed e path non cablato
Gli hook ora escono **2** se manca `jq` o la libreria scanner, invece di `exit 0` in silenzio: una regola
inviolabile non può avere un ramo che apre quando i suoi strumenti mancano. E usano `$CLAUDE_PROJECT_DIR`
invece di `/home/ubuntu/workbrain` scritto a mano.
Copertura di `block-opentext` estesa a **tutto il repo**: prima guardava solo `docs/`, `reports/`, `tests/`,
lasciando scoperti `knowledge/`, `CLAUDE.md` e `.claude/`.

### B3 — il gate vero: hook git `pre-commit`
Nuovo `.githooks/pre-commit` (attivato con `git config core.hooksPath .githooks`) che rilancia gli stessi
scanner sul **contenuto in staging**. È la risposta alla regola madre: inseguire ogni modo di scrivere un
file è "aggiungere un altro check"; il commit invece è un collo di bottiglia unico.
Aggiunto anche `block-bash-writes.sh` (matcher `Bash`) per i casi ovvi — con il suo limite scritto dentro:
non può coprirli tutti, la shell è troppo espressiva.

**Prova end-to-end del bypass** (l'attacco di AUDIT-001 R-03, in versione realistica con il segreto
composto da variabili, così nemmeno la guardia sui comandi lo vede):
```
$ printf '%s%s=%s%s\n' "$K" "$S" "$V" "$W" > docs/_test-gate.md   # guardie PreToolUse aggirate
$ git add docs/_test-gate.md && git commit -m "..."
COMMIT RIFIUTATO dal gate di WorkBrain.
```
Verificato **sul fatto**, non sul messaggio: `git log` mostrava ancora il commit precedente, il file era
rimasto in staging. Nessun commit creato.

### B4 — backup con prova di ripristino
`restic` 0.16.4, repository in `/srv/workbrain/backups/restic`, password in `/srv/workbrain/restic-pass`
(600, `ubuntu`, **fuori dal repo**). Script `scripts/backup.sh` con retention 7/4/6 e verifica
sull'**artefatto** (lo snapshot esiste), non sugli step (PAT-06).
Automatizzato con **servizio + timer utente systemd** (`workbrain-backup.timer`, `Persistent=true` così
recupera se la macchina era spenta). Avviato a mano una volta: `Result=success`, `ExecMainStatus=0`,
`BACKUP_OK` nel journal.

**Prova di ripristino** (un backup mai ripristinato non è un backup): creato un file canary, cancellato,
ripristinato da snapshot, contenuto confrontato → identico.

⚠️ **Onestà su cosa protegge**: il repository sta sulla **stessa macchina** dei dati. Protegge da
cancellazioni accidentali e corruzione, **non dalla perdita del VPS**. È metà del lavoro, ed è scritto
anche in testa a `scripts/backup.sh` per non lasciar credere il contrario.

### Suite: da 11 a 23 test
Due dei vecchi test **certificavano come corretti i difetti trovati dall'audit** (il gate inerte, la
copertura parziale): sono stati invertiti. Aggiunti i test su fail-closed, guardia sui comandi Bash,
gate che fallisce su suite rossa, e presenza/attivazione del `pre-commit`.

## Due inciampi, e come sono stati risolti (non nascosti)
1. **Le guardie hanno bloccato la propria suite.** Estesa la copertura a tutto il repo, le fixture di
   test — che per natura contengono finti segreti e marker di dominio — sono diventate illegali.
   La via comoda era esentare quei file dal controllo: un punto cieco permanente proprio nella guardia.
   Scelta invece la composizione dei marker **a runtime** (`"open""text"`), così i file non li contengono
   mai in forma letterale e non si esenta nulla. Stessa tecnica in `scanners.sh` e nella suite.
2. **Due test scritti male, scoperti dal gate stesso.** Il test del fail-closed dava `rc=127`: con `PATH`
   svuotato, `#!/usr/bin/env bash` non trova l'interprete — misurava uno script che non parte, non la
   guardia che blocca. E il marker di dominio in una riga di comando non veniva visto perché il pattern è
   ancorato a inizio riga (giusto per un frontmatter, sbagliato per `echo '...' >> f`): aggiunta una
   modalità `loose` **esplicita**, usata solo dalla guardia sui comandi, invece di allentare il pattern per tutti.

## Cosa resta aperto
- **A2** — migrare la sessione Claude Code a `ubuntu`. `claude` è installato per `ubuntu` ma **senza
  credenziali**: serve un nuovo login e questa conversazione non prosegue. Da fare con un handoff (P-002)
  prima della Fase C, che va installata *per* `ubuntu`.
- **A3** — remote git: attende la scelta di Raf. Finché manca, AUDIT-001 R-01 resta aperto per il repo.
- **Backup fuori dalla macchina** — attende una destinazione e una decisione di riservatezza.
- `core.hooksPath` è configurazione **locale**: su un clone nuovo va reimpostata. Un test lo verifica.

## Riferimenti
`reports/PLAN-001-consolidamento-infrastruttura.md` (Fasi A e B) · `reports/AUDIT-001-infrastruttura-e-harness.md`
(R-01, R-02, R-03) · [[2026-09-06-chiave-ssh-ubuntu-attiva]]
