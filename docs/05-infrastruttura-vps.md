# 05 — Infrastruttura VPS

Ultimo aggiornamento: 2026-09-06 (audit completo — vedi `reports/AUDIT-001-infrastruttura-e-harness.md`)

Stato reale del VPS che ospita WorkBrain, verificato con comandi. Ogni voce riporta l'esito reale, non l'intenzione.

## Macchina
- Provider: Hostinger. Hostname: `srv1958735`. OS: **Ubuntu 24.04.4 LTS** (noble), kernel 6.8.0-139.
- Ruolo: host unico di WorkBrain (single-user, volumi bassi).
- **Risorse** (2026-09-06): 4 vCPU AMD EPYC 9354P · **15 Gi RAM** (~1 Gi in uso) · disco 193 G ext4 con **190 G liberi**
  (uso 2%, inode 1%). Dimensionamento **abbondante** per il carico previsto: il vincolo sarà il costo del provider STT.
- ⚠️ **Nessuna swap** (`swapon --show` vuoto). Un picco di memoria non degrada: viene ucciso dall'OOM killer.
  Proposta aperta (AUDIT-001 R-07): swapfile 4 G + `vm.swappiness=10`.
- Aggiornamenti: **0 pendenti**, 0 di sicurezza. `unattended-upgrades` **enabled + active**. Nessuna unità systemd fallita.
- Orologio: NTP attivo e sincronizzato, timezone `Etc/UTC`, RTC in UTC (corretto: si conserva UTC, si rende in locale).

## Servizi di terze parti (preinstallati dal provider, NON messi da noi)
- **`monarx-agent.service`** — *"Monarx Agent - Security Scanner"* di Hostinger, gira **come root**, più il cron
  `monarx-update`. È un agente di un fornitore con accesso al filesystem, su una macchina che ospiterà PII di
  clienti dello studio e materiale riservato. Decisione di riservatezza aperta verso Raf (AUDIT-001 R-06).
  ⚠️ Rimuoverlo potrebbe violare le condizioni dell'hosting: verificare **prima**.
- ~~**`docker.service` + `containerd.service`** preinstallati dal provider~~ ✅ **spenti il 2026-09-07**
  (PLAN-001 Fase C2, AUDIT-001 R-05 chiuso): erano attivi ma a vuoto (0 container, 0 immagini, 0 volumi —
  verificato prima di spegnere). Ora `disabled` + `inactive`, sostituiti dal runtime rootless di `ubuntu`.
  I due cron `docker-builder-prune` e `docker-image-prune` sono stati rimossi (copia in
  `/srv/workbrain/backups/etc-cron.d/`) e sostituiti dal timer utente `workbrain-docker-prune.timer`.
- `qemu-guest-agent` (normale su VM), `sysstat` (raccolta metriche).

## Container: Docker rootless sotto `ubuntu` (dal 2026-09-07)
Runtime della piattaforma. Dettaglio e prove: [[2026-09-07-fase-c-container-rootless]] · PLAN-001 D-01/D-02/D-03.
- `dockerd` e `containerd` girano **come `ubuntu`**, non come root. Socket `/run/user/1000/docker.sock`,
  root dir `~/.local/share/docker`, storage driver `overlayfs` nativo. Context CLI `rootless` (default).
- `ubuntu` **non** è nel gruppo `docker` e non deve entrarci: equivarrebbe a dargli root e annullerebbe D-01.
- Abilitato da `dockerd-rootless-setuptool.sh` + pacchetto `uidmap`. La restrizione AppArmor di 24.04
  (`kernel.apparmor_restrict_unprivileged_userns=1`) **non** ha dato problemi: esiste già
  `/etc/apparmor.d/rootlesskit` con `userns`.
- Mappatura degli id (serve saperla per i bind mount): `0 → 1000` (`ubuntu`), `N>0 → 100000+N-1`.
  Perciò i container girano `10001:0` — non-root dentro, gruppo `ubuntu` fuori — e `/srv/workbrain/{raw,vault,db}`
  sono `2770` (setgid + scrittura di gruppo). Senza questo un container non-root non scrive nei dati.
- Il daemon rootless parte al boot grazie a `docker.service` (utente) + `Linger=yes`.

## Timer utente di WorkBrain
Le unit stanno in `~/workbrain/systemd/user/` e in `~/.config/systemd/user/` ci sono **symlink**
(`bash scripts/install-units.sh` li rifà, idempotente).
| unit | cosa fa | cadenza |
|---|---|---|
| `workbrain-backup.timer` | backup restic di `/srv/workbrain` | giornaliero, `Persistent=true` |
| `workbrain-docker-prune.timer` | pulizia immagini/cache del daemon rootless | giornaliero |
| `workbrain-step@<step>.timer` | template: uno step di pipeline in un container one-shot | per istanza |
⚠️ Con `Type=oneshot` il limite di durata è **`TimeoutStartSec=`**: `RuntimeMaxSec=` viene ignorato da systemd
(difetto trovato e corretto nel servizio di backup il 2026-09-07). Un test lo impedisce.
⚠️ Il prune **non deve** toccare l'immagine del progetto. `docker image prune -a` cancella ogni immagine taggata
non referenziata, e con step tutti `--rm` nessuna immagine lo è mai: senza protezione `workbrain-base` sparirebbe
dopo 24 h. Perciò il `Dockerfile` dichiara `LABEL com.workbrain.keep="true"` e `scripts/docker-prune.sh` esclude
quella label. Le due parti devono restare allineate — un test lo verifica.

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

### Come entra la console web di hPanel (verificato 2026-09-05, importante per il recupero)
Non entra con la password: entra **come root via publickey** da `169.254.0.1` (indirizzo link-local dell'host).
Hostinger **inietta una chiave effimera**, la usa, e poi svuota il file — `/root/.ssh/authorized_keys` risulta
**0 byte** a sessione in corso, e le fingerprint in `auth.log` cambiano a ogni sessione.

Conseguenze pratiche:
- La console resta una via di recupero **anche dopo** `PasswordAuthentication no`, perché usa una chiave.
- ⚠️ **Precondizione di P-003**: prima di eseguirla va letto `99-workbrain-lockdown.conf.disabled` e confermato che
  dica `PermitRootLogin prohibit-password` e **non** `no`. Con `no` si perderebbe **anche la console di recupero**.
  La lettura di `/etc/ssh/**` è preclusa dalle deny-rule dell'harness: serve un ok esplicito di Raf.

### Gli attacchi sono in corso (non è un rischio teorico)
`fail2ban-client status sshd` il 2026-09-05 sera: 0 tentativi. Il **2026-09-06 mattina: 9 tentativi falliti, 1 IP
bannato**. Con `permitrootlogin yes` + `passwordauthentication yes` la superficie è reale e sotto sondaggio.

### L'utente `ubuntu` non ha password
`passwd -S ubuntu` → **`L`** (locked); `passwd -S root` → `P`. Quindi **senza chiave SSH non ci si può collegare
come `ubuntu`**, e ogni sessione finisce per girare come root — che è esattamente PAT-04, e la causa della deriva
di proprietà dei file riparata il 2026-09-06.

## Hardening applicato
- `apt update && apt upgrade`: sistema già aggiornato (0 pacchetti da aggiornare).
- **UFW attivo**: default deny incoming / allow outgoing; unico servizio aperto **OpenSSH (22/tcp)** IPv4+IPv6.
- **fail2ban attivo**: jail `sshd` abilitata (backend systemd, bantime 1h, maxretry 5). `systemctl is-active` = active.

## Strumenti installati
- Sistema: `git`, `jq`, `curl`, `unzip`, `tmux` 3.4, `python3` 3.12 + `python3-venv` + `pip`.
- Per l'utente `ubuntu`: **nvm** v0.40.1 → **Node v20.20.2** (default), npm 10.8.2.
- Globali (node di `ubuntu`): **`@plaud-ai/cli` 0.3.11**, **`@anthropic-ai/claude-code` 2.1.197**.
- ⚠️ **Node è installato due volte** (AUDIT-001 R-09): esiste un nvm+Node v20.20.2 anche per **root**, con un
  proprio `@anthropic-ai/claude-code`. Le versioni **sono già divergenti**: root **2.1.263** vs ubuntu **2.1.197**
  (rilevato 2026-09-06, un giorno dopo l'installazione). In più `@plaud-ai/cli` esiste **solo** per `ubuntu`: una
  sessione come root non ha `plaud` nel PATH senza caricare l'nvm di `ubuntu`. Ingombro ~1,3 G fra i due nvm e le
  due cache npm. Proposta aperta: consolidare su `ubuntu` e smettere di aggiornare quello di root.
- Plaud MCP: non installato staticamente; invocato on-demand via `.mcp.json` (`npx -y @plaud-ai/mcp@latest`).
  ⚠️ **Versione non pinnata** (`@latest` + `-y`): scarica ed esegue l'ultima pubblicata a ogni invocazione, su una
  macchina che tratterà dati riservati. Proposta aperta: pinnare (AUDIT-001 R-11).
- **`loginctl enable-linger ubuntu` NON attivo** (`loginctl show-user ubuntu` → not lingering). Senza lingering i
  systemd **user** services di `ubuntu` non partono al boot e muoiono al logout: è una **precondizione di F1/F4**,
  visto che BRIEF-001 sceglie systemd user timer come runner (AUDIT-001 R-10).
- `tmux`: `/root/.tmux.conf` con **`set -g mouse off`** (2026-09-05). Provato `mouse on` su richiesta di Raf e
  **rimesso off**: l'accesso avviene dalla **console web di Hostinger hPanel**, dove `mouse on` fa catturare a tmux
  gli eventi del mouse e impedisce la selezione testo del browser (niente copia). Non riattivare senza prima
  verificare da quale canale ci si collega. ⚠️ Config del solo utente `root`: da replicare in
  `/home/ubuntu/.tmux.conf` quando si opererà come `ubuntu`.
- **Copia testo dalla console web hPanel — risolta il 2026-09-05 sera.** La causa **non** era il mouse tracking:
  era `"tui": "fullscreen"` in `/root/.claude/settings.json`, scelta al primo avvio di Claude Code. `fullscreen` usa
  lo schermo alternato del terminale, che un terminale dentro una pagina web non tratta come testo selezionabile.
  **Fix: `/tui default`** (salva la preferenza e riavvia riprendendo la sessione). Verificato da Raf: copia funziona.
- ⚠️ Residuo da rimuovere: `export CLAUDE_CODE_DISABLE_MOUSE=1` è **ancora** in `/root/.bashrc` (riga 108). Era il
  fix tentato per lo stesso sintomo e **non è mai entrato in funzione** (la variabile è stata scritta dopo l'avvio
  del processo — verificato su `/proc/<pid>/environ`), quindi non è mai stato dimostrato. Oggi è inattivo ma si
  attiverà da solo alla prossima shell nuova, disattivando lo scroll con la rotella senza che se ne sappia il perché.
  Config → serve l'ok di Raf per toglierlo (regola #3). Storia: `knowledge/history/2026-09-05-login-plaud-e-fix-copia-tui.md`.

## Cartelle e dati (fuori dal repo)
- Repo harness: **`/home/ubuntu/workbrain`** (git). Dati veri **fuori dal repo**:
- `/srv/workbrain/{raw,vault,db,backups}` — owner `ubuntu:ubuntu`, `750`.
- Segreti: **`/srv/workbrain/env.prod`** (`600`, owner `ubuntu`, **template senza valori reali**) e `~/.plaud/`
  (token Plaud presente dal 2026-09-05, in **`/home/ubuntu/.plaud/`**).
- Nulla di segreto entra in git (vedi `.gitignore` + hook `block-secrets.sh`).
- **Proprietà del repo riparata il 2026-09-06**: 10 file + 41 oggetti in `.git/` erano finiti a `root:root` per via
  delle sessioni girate come root. `chown -R ubuntu:ubuntu` eseguito; verificato che `ubuntu` usa git sul repo.

## 🔴 Nessun backup, nessun remote (AUDIT-001 R-01)
- `git remote -v` → **vuoto**. `/srv/workbrain/backups` → **0 file**.
- Tutto l'harness (regole, decisioni, history) esiste in **una sola copia**, su questo disco. Il piano prevede i
  backup in F6, ma quella fase protegge i *dati*: il *lavoro* è già tutto qui e va protetto adesso.
- Proposte aperte: remote git **privato** per il repo (non contiene segreti né dati, per costruzione) + backup
  **locale cifrato** per `/srv/workbrain/`, con la decisione se possa uscire dalla macchina in capo a Raf.

## Bloccanti aperti verso Raf
1. ~~Chiave SSH pubblica per `ubuntu`~~ ✅ **chiusa il 2026-09-06**; ~~lockdown P-003~~ ✅ **eseguito il 2026-09-07**.
2. ~~`plaud login`~~ ✅ **completato il 2026-09-05** (P-004). Token in `/home/ubuntu/.plaud/`, `plaud me` OK.
3. ~~Decisioni AUDIT-001: remote git, backup, hook (R-02/R-03), Docker, swap, pin MCP, linger~~ ✅ tutte chiuse
   con PLAN-001 Fasi A/B/C. **Restano aperte**: Monarx (rischio accettato consapevolmente, D-11), il backup fuori
   dalla macchina, l'email negli autori dei commit, e `CLAUDE_CODE_DISABLE_MOUSE=1` in `/root/.bashrc`.
4. **Riavvio di prova non ancora fatto**: che i timer utente e il daemon rootless ripartano da soli dopo un reboot
   è sostenuto dall'evidenza strutturale (`Linger=yes`, unit `enabled` nei `.wants`), non da un riavvio vero.
   Serve una finestra decisa da Raf: il riavvio interrompe la sessione.

## Riconnessione (sessioni future)
Aprire la sessione come `ubuntu`, non root:
`ssh ubuntu@<ip-vps>` → `cd ~/workbrain` → `claude`. (Per il login Plaud: `ssh -L 8199:localhost:8199 ubuntu@<ip-vps>`.)
✅ **È la via normale dal 2026-09-07**: la chiave `id_workbrain` è installata e l'accesso a password non esiste
più (P-003). Per sessioni lunghe conviene comunque `tmux attach -d -t SysAdmin`.
Via di recupero se la chiave si perde: la console web di hPanel, che entra come root con una chiave iniettata da
Hostinger — è il motivo per cui il lockdown usa `prohibit-password` e non `no`.
