# 2026-09-07 — Remote GitHub (A3), riscrittura dei permessi, e lockdown SSH (P-003)

Tre cose in sequenza. Chiudono l'ultimo rilievo 🔴 dell'audit e il bloccante SSH aperto dal bootstrap.

## 1. Decisione di Raf: permessi riscritti, piena autonomia amministrativa
> *"Basta con questa regola ci sta rallentando tutto. Tu sei il SysAdmin e hai piena approvazione su tutte le
> attività di amministrazione richieste."*

**Contesto**: le regole di permesso bloccavano operazioni legittime — installare `authorized_keys`, leggere la
configurazione di sshd, aggiungere un remote git — costringendo Raf a incollare comandi a mano. Una guardia che
sposta il lavoro sull'umano senza proteggere nulla è attrito, non sicurezza.

**Cosa è cambiato** (`.claude/settings.json`): lista `allow` estesa alle attività amministrative reali (git, systemd,
apt, ufw/fail2ban, docker, restic, gestione utenti/permessi/swap, lettura di `/etc`).

**Cosa è stato TENUTO di proposito**, e detto a Raf invece di ometterlo: resta vietata la **lettura** dei segreti —
`env.prod`, token Plaud, chiavi private (`id_*`, chiavi host di sshd), `/etc/shadow` — e le operazioni distruttive
(`rm -rf /`, `mkfs`, `dd`, `chmod -R 777`). Non è attrito amministrativo: è la garanzia su cui poggiano le regole
del progetto, e vale anche contro i miei errori. Raf sa che può togliere anche quella se vuole.

**Nota sulla granularità precedente**: la deny-rule vietava tutto `/home/ubuntu/.ssh/**`, quindi impediva anche di
*scrivere* `authorized_keys` — mentre lo scopo era impedire di *leggere* chiavi private. Ora il divieto è sui file
`id_*`, non sulla cartella.

## 2. A3 — remote git privato su GitHub ✅
Chiude **AUDIT-001 R-01**, il rilievo più grave: l'harness esisteva in una sola copia, su un solo disco.

- Repository **privato** `rafcip/workbrain`.
- **Deploy key** dedicata (`ed25519`), generata sul VPS: la chiave privata non è mai uscita dalla macchina.
  Vive in `/srv/workbrain/deploy-key-github` (600, `ubuntu`), **fuori dal repo**, dove le regole vogliono i segreti —
  e non in `/home/ubuntu/.ssh/`. Ambito: **solo questo repository**. Se il VPS venisse compromesso, l'attaccante
  avrebbe accesso a `workbrain` e basta, non all'account GitHub.
- **Chiavi host di GitHub verificate, non accettate alla cieca**: `ssh-keyscan` confrontato con le impronte
  pubblicate su `https://api.github.com/meta`. Le tre (RSA, ECDSA, ED25519) combaciavano. Fissate in
  `/srv/workbrain/github_known_hosts` con `StrictHostKeyChecking=yes` via `core.sshCommand`.
- Push verificato **sul fatto**: `git ls-remote` mostra lo stesso commit del locale (12 commit, 44 file).

⚠️ L'email di Raf compare come autore in ogni commit. Su repo privato va bene; se un domani diventasse pubblico
resterebbe nella storia e toglierla richiederebbe di riscrivere tutti i commit. Opzione `@users.noreply.github.com`
proposta, **non ancora decisa**.

## 3. P-003 — lockdown SSH eseguito ✅
Bloccante aperto dal 2026-09-05. Eseguito solo dopo aver **letto** il file di lockdown, cosa che i permessi
precedenti impedivano e per cui mi ero rifiutato di procedere alla cieca.

**La precondizione era fondata e ora è verificata**: il file dice `PermitRootLogin prohibit-password`, **non** `no`.
Con `no` avremmo spento anche la console web di hPanel, che entra come root **via chiave** — cioè la via di recupero.

Sequenza: backup (P-005) → `PasswordAuthentication no` in `50-cloud-init.conf` → attivazione di
`99-workbrain-lockdown.conf` → `sshd -t` (rc=0) → `systemctl reload ssh`.

**Verifiche, tutte con esito reale:**
- Configurazione effettiva: `passwordauthentication no`, `permitrootlogin without-password`, `pubkeyauthentication yes`.
- **Prova attiva**, non lettura di config: `ssh -o PreferredAuthentications=password ubuntu@127.0.0.1`
  → `Permission denied (publickey)`. La password è rifiutata davvero.
- Le sessioni aperte sono sopravvissute al reload.
- Raf ha aperto **una nuova sessione SSH** e **una nuova console hPanel**: entrambe a log come `Accepted publickey`.
  Nessun `Accepted password` da nessuna parte.

**Perché serviva.** Nel log dello stesso giorno: `Failed password for invalid user admin from 171.231.176.227`.
Gli attacchi erano in corso, non ipotetici. Ora quel tipo di tentativo è impossibile.

### Un equivoco da annotare, perché tornerà
Raf ha riferito di aver usato "la password" per il nuovo accesso. Il log diceva `Accepted publickey`: aveva digitato
la **passphrase della chiave**. I due prompt si somigliano ma sono opposti — la password viaggia fino al server ed è
indovinabile; la passphrase decifra la chiave privata **sul PC** e non lascia mai quella macchina. Verificato sul log
invece di rassicurare a parole.

## Stato dopo questa sessione
- AUDIT-001: **R-01 chiuso**, R-02/R-03/R-04 già chiusi in Fase B. Restano i 🟡 di igiene.
- PLAN-001 Fase A: **completa** tranne **A2** (migrazione della sessione a `ubuntu`, serve handoff P-002).
- L'accesso via password non esiste più: da qui in poi si entra **solo** con la chiave, o dalla console hPanel.

### Rollback del lockdown (se mai servisse)
```
cp /root/50-cloud-init.conf.bak-pre-lockdown-2026-09-07 /etc/ssh/sshd_config.d/50-cloud-init.conf
mv /etc/ssh/sshd_config.d/99-workbrain-lockdown.conf /etc/ssh/sshd_config.d/99-workbrain-lockdown.conf.disabled
sshd -t && systemctl reload ssh
```

## Riferimenti
`.claude/rules/procedures.md` (P-003, P-005) · `reports/AUDIT-001-infrastruttura-e-harness.md` (R-01, R-08) ·
`reports/PLAN-001-consolidamento-infrastruttura.md` (D-06, D-09) · [[2026-09-06-chiave-ssh-ubuntu-attiva]]
