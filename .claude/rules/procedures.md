# Regola: procedure numerate (P-series)

Procedure operative riusabili. Ogni procedura ha ID stabile `P-NNN`, precondizioni, passi verificabili, esito atteso.
Le procedure complesse/ripetute diventano skill in `.claude/skills/`. Qui l'indice canonico.

## P-001 — Avvio sessione
Vedi `.claude/rules/continuity.md` §"All'avvio". Esito: conosci stato reale + bloccanti aperti.

## P-002 — Chiusura sessione / handoff
Vedi `.claude/rules/continuity.md` §"salva sessione". Esito: history aggiornata, stato aggiornato, bloccanti elencati.

## P-003 — Attivare il lockdown SSH (dopo chiave `ubuntu`)
Precondizione: chiave pubblica di Raf in `/home/ubuntu/.ssh/authorized_keys` **testata** da una seconda sessione SSH aperta.
1. `sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf`
2. `sudo mv /etc/ssh/sshd_config.d/99-workbrain-lockdown.conf.disabled /etc/ssh/sshd_config.d/99-workbrain-lockdown.conf`
3. `sudo sshd -t && sudo systemctl reload ssh`
4. Verifica: `sshd -T | grep -iE 'passwordauthentication|permitrootlogin'` → `no` / `prohibit-password`.
5. **Non chiudere** la sessione SSH corrente finché non hai riconnesso con la chiave in una nuova sessione.

## P-004 — Login Plaud (richiede browser di Raf)
1. Raf apre dal suo PC: `ssh -L 8199:localhost:8199 ubuntu@<ip-vps>`.
2. Nella sessione VPS: `plaud login` → completa nel browser di Raf sull'URL localhost:8199.
3. Verifica: `plaud me` (identità) e `plaud recent --days 30` (elenco registrazioni).

## P-005 — Backup pre-modifica
Prima di toccare un file critico: `cp <file> <file>.bak-pre-<feature>-$(date +%F)`. Annota il rollback nella history.

## P-006 — Aggiungere una nuova procedura
Assegna il prossimo `P-NNN` libero, scrivi precondizioni + passi verificabili + esito atteso, linka dalla history che l'ha motivata.
