# 05 — Infrastruttura VPS

Ultimo aggiornamento: 2026-09-05

Stato reale del VPS che ospita WorkBrain, verificato con comandi durante il bootstrap del 2026-09-05.
Ogni voce riporta l'esito reale, non l'intenzione.

## Macchina
- Provider: Hostinger. Hostname: `srv1958735`. OS: **Ubuntu 24.04.4 LTS** (noble), kernel 6.8.
- Ruolo: host unico di WorkBrain (single-user, volumi bassi).

## Utente operativo
- Creato utente **`ubuntu`** con sudo **senza password** (`/etc/sudoers.d/90-ubuntu`, `visudo -c` OK).
- Regola: tutto il lavoro gira come `ubuntu`, **mai come root** (lezione Legal Agency, PAT-04).
- ⚠️ Nota: la sessione Claude Code del bootstrap è partita **come root** da `/root/bootstrap`; non è possibile
  cambiare utente a un processo già avviato. I file sono stati creati e poi assegnati a `ubuntu` (`chown -R`).
  Le sessioni successive vanno aperte come `ubuntu` (vedi §Riconnessione).

## Accesso SSH — ATTENZIONE (deviazione dal brief)
- Il brief assumeva "accesso root con chiave SSH". **Realtà verificata**: `/root/.ssh/authorized_keys` era **vuoto**
  (0 chiavi) e `50-cloud-init.conf` forza `PasswordAuthentication yes`. L'unico accesso è la **password di root**.
- Perciò il passo "password SSH disabilitata" **NON è stato eseguito**: senza alcuna chiave installata, disabilitare
  la password causerebbe un **lockout permanente** (recuperabile solo da console Hostinger). Deviazione motivata.
- **Applicato ora (sicuro):** hardening non-distruttivo in `/etc/ssh/sshd_config.d/99-workbrain-hardening.conf`
  (`MaxAuthTries 3`, `LoginGraceTime 20`, `X11Forwarding no`, `AllowAgentForwarding no`, keepalive).
- **Preparato ma DISATTIVATO:** `/etc/ssh/sshd_config.d/99-workbrain-lockdown.conf.disabled` che imposta
  `PasswordAuthentication no` + `PermitRootLogin prohibit-password`. Si attiva con la **procedura P-003**, solo dopo
  aver installato e testato la chiave pubblica di Raf per `ubuntu`. **Bloccante aperto → serve la chiave di Raf.**

## Hardening applicato
- `apt update && apt upgrade`: sistema già aggiornato (0 pacchetti da aggiornare).
- **UFW attivo**: default deny incoming / allow outgoing; unico servizio aperto **OpenSSH (22/tcp)** IPv4+IPv6.
- **fail2ban attivo**: jail `sshd` abilitata (backend systemd, bantime 1h, maxretry 5). `systemctl is-active` = active.

## Strumenti installati
- Sistema: `git`, `jq`, `curl`, `unzip`, `tmux` 3.4, `python3` 3.12 + `python3-venv` + `pip`.
- Per l'utente `ubuntu`: **nvm** v0.40.1 → **Node v20.20.2** (default), npm 10.8.2.
- Globali (node di `ubuntu`): **`@plaud-ai/cli` 0.3.11**, **`@anthropic-ai/claude-code` 2.1.197**.
- Plaud MCP: non installato staticamente; invocato on-demand via `.mcp.json` (`npx -y @plaud-ai/mcp@latest`).
- `tmux`: `/root/.tmux.conf` con **`set -g mouse off`** (2026-09-05). Provato `mouse on` su richiesta di Raf e
  **rimesso off**: l'accesso avviene dalla **console web di Hostinger hPanel**, dove `mouse on` fa catturare a tmux
  gli eventi del mouse e impedisce la selezione testo del browser (niente copia). Non riattivare senza prima
  verificare da quale canale ci si collega. ⚠️ Config del solo utente `root`: da replicare in
  `/home/ubuntu/.tmux.conf` quando si opererà come `ubuntu`.
- `CLAUDE_CODE_DISABLE_MOUSE=1` in `/root/.bashrc` (2026-09-05): la TUI di Claude Code attiva il mouse tracking e
  nella console web hPanel impedisce la selezione/copia del browser. Backup `.bak-pre-disable-mouse-2026-09-05`.
  Diagnosi completa in `knowledge/history/2026-09-05-copia-testo-console-web-hostinger.md`.

## Cartelle e dati (fuori dal repo)
- Repo harness: **`/home/ubuntu/workbrain`** (git). Dati veri **fuori dal repo**:
- `/srv/workbrain/{raw,vault,db,backups}` — owner `ubuntu:ubuntu`, `750`.
- Segreti: **`/srv/workbrain/env.prod`** (`600`, owner `ubuntu`, **template senza valori reali**) e `~/.plaud/` (dopo login).
- Nulla di segreto entra in git (vedi `.gitignore` + hook `block-secrets.sh`).

## Bloccanti aperti verso Raf
1. **Chiave SSH pubblica** per `ubuntu` (poi P-003 per il lockdown password). Finché manca, l'accesso resta a password root.
2. **`plaud login`**: richiede il browser di Raf via tunnel (P-004). Finché manca, la pipeline audio non parte.

## Riconnessione (sessioni future)
Aprire la sessione come `ubuntu`, non root:
`ssh ubuntu@<ip-vps>` → `cd ~/workbrain` → `claude`. (Per il login Plaud: `ssh -L 8199:localhost:8199 ubuntu@<ip-vps>`.)
