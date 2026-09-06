# AUDIT-001 — Infrastruttura VPS e harness WorkBrain

Data: 2026-09-06 · Autore: SysAdmin/Architetto · Stato: **completato, in attesa di decisioni di Raf**
Perimetro: VPS `srv1958735` (Hostinger, Ubuntu 24.04.4) + repo harness `/home/ubuntu/workbrain` (33 file tracciati).
Metodo: tutto verificato con comandi eseguiti oggi. Dove non ho potuto verificare, lo dico. Nessun rilievo "a memoria".

---

## Verdetto in una riga

**L'harness è progettato bene e l'infrastruttura è sana**, ma ha **tre difetti strutturali** che lo rendono più
fragile di quanto sembri: il repo esiste in **una sola copia al mondo**, il **gate dei test non gira**, e gli hook
di segregazione **si aggirano scrivendo con Bash** (dimostrato, non ipotizzato). Nessuno dei tre è visibile finché
non serve. Vanno chiusi prima di scrivere una riga di pipeline.

---

## Parte 1 — Cosa è in ordine (verificato)

Non solo problemi: questo funziona e non va toccato.

| Area | Esito reale |
|---|---|
| Sistema operativo | Ubuntu 24.04.4, kernel 6.8.0-139. **0 aggiornamenti pendenti**, 0 di sicurezza, nessun reboot richiesto |
| Aggiornamenti automatici | `unattended-upgrades` **enabled + active**, liste e upgrade giornalieri |
| Unità systemd | **nessuna unità fallita** |
| Firewall | UFW active, default `deny (incoming)`. **Solo OpenSSH** aperto |
| Porte in ascolto | Solo `:22` verso l'esterno. Il resto è su loopback (DNS di systemd). Nessun servizio esposto per errore |
| fail2ban | Attivo, jail `sshd`, `bantime 3600 / findtime 600 / maxretry 5`. **Funziona davvero: 9 tentativi falliti, 1 IP bannato** |
| Hardening sshd | `maxauthtries 3`, `logingracetime 20`, `x11forwarding no`, `permitemptypasswords no` |
| Orologio | NTP attivo e sincronizzato, RTC in UTC |
| Dati fuori dal repo | `/srv/workbrain/{raw,vault,db,backups}` `750 ubuntu:ubuntu`, `env.prod` **600**. Regola rispettata |
| `.gitignore` | Copre `env.prod`, `*.env`, `*.key`, `*.pem`, `id_rsa*`, le root dati, i `.bak-pre-*` |
| Nessun segreto tracciato | Verificato sui file in git |
| Agenti e skill | Ben scritti. `sync-plaud` ha un **counter-example reale** (errori termini Plaud): è il pattern giusto |
| Risorse | 4 vCPU AMD EPYC 9354P, **15 Gi RAM** (1 Gi in uso), **190 G liberi** su 193 G, inode all'1% |

### Nota sul dimensionamento (utile per BRIEF-001)
Le risorse sono **abbondanti** per il carico previsto: STT via API + SQLite/pgvector + embedding stanno larghi.
190 G liberi reggono anni di audio. Il vincolo non sarà la macchina, sarà il costo per ora audio del provider STT.
Unica cautela: **niente swap** (sotto), quindi un picco di memoria non ha rete di sicurezza.

---

## Parte 2 — Rilievi 🔴 (strutturali, da chiudere prima della pipeline)

### R-01 — Il repo esiste in una sola copia al mondo
```
$ git remote -v
(vuoto)
$ find /srv/workbrain/backups -type f | wc -l
0
```
**Nessun remote git. Nessun backup. Di niente.** Tutto l'harness — regole, decisioni, history, i tre file
`DECISIONE-*` che codificano scelte di Raf — vive solo su `/dev/sda1` di questo VPS. Un disco perso, un VPS
riprovisionato, un `rm` sbagliato, e non c'è nulla da cui ripartire.

È il rilievo più grave del documento, ed è quello che costa meno a chiudere.

> Il piano prevede backup in **F6**, cioè alla fine. Ma F6 protegge i *dati*; il *lavoro* va protetto da subito,
> perché è già tutto qui. La regola #10 (backup prima di toccare) oggi non ha dove appoggiarsi.

**Proposta**: (a) remote git **privato** (GitHub/GitLab) con push a ogni commit — il repo non contiene segreti né
dati, per costruzione, quindi è sicuro da spingere; (b) per `/srv/workbrain/` (che invece contiene dati riservati)
un backup **locale + cifrato**, e la decisione se possa uscire dalla macchina la prende Raf, non io.

### R-02 — Il gate dei test non esegue i test che esistono
`.claude/hooks/run-tests.sh` cerca i test così:
```sh
if ! ls tests/test_*.py >/dev/null 2>&1 && [ ! -f tests/run.sh ]; then
  echo "run-tests: nessun test in tests/ (fase bootstrap) — nulla da eseguire."
  exit 0
fi
```
Ma l'unica suite esistente è **`tests/test_hooks.sh`**: non è `test_*.py`, non è `run.sh`.
```
$ ls tests/test_*.py   → No such file or directory
$ test -f tests/run.sh → ASSENTE
```
**Il gate esce sempre 0 dicendo "fase bootstrap"**, anche adesso che una suite verde esiste. La regola #6
("test verdi prima del deploy") oggi è dichiarata ma non applicata. Peggio: `tests/test_hooks.sh` **verifica come
corretto** questo comportamento a vuoto, quindi la suite conferma il buco invece di segnalarlo.

### R-03 — Gli hook di segregazione si aggirano scrivendo con Bash
Gli hook sono agganciati al solo matcher `Write|Edit|MultiEdit` (`.claude/settings.json`). Una scrittura fatta con
Bash non li attraversa. **Dimostrato oggi**, non dedotto: ho creato via Bash un file in `docs/` contenente una riga
con una chiave finta (nome tipo API_KEY seguito da un valore inventato) e

```
esito: file creato — hook block-secrets NON ha bloccato
(file rimosso subito dopo)
```

Controprova nello stesso audit: **la prima stesura di questo report è stata bloccata** dallo stesso hook, perché
scritta con lo strumento `Write`. Stessa stringa, esito opposto a seconda dello strumento: è esattamente
l'asimmetria da chiudere.

Non è teorico: una guida di sessione può suggerire di preferire Bash per modificare i file, e in quel momento
**entrambe** le guardie — segreti e segregazione domini — smettono di esistere senza dire nulla.

Tre debolezze minori sullo stesso tema:
- **Fail-open su `jq`**: `command -v jq >/dev/null || exit 0`. Se `jq` manca, la guardia "inviolabile" lascia
  passare tutto in silenzio. Per una regola inviolabile il default giusto è fallire **chiuso**.
- **Path cablato**: `REPO="/home/ubuntu/workbrain"` in tutti e tre gli hook invece di `$CLAUDE_PROJECT_DIR`.
  Se il repo si sposta, gli hook non proteggono più nulla e non lo dicono.
- **Copertura parziale**: `block-opentext.sh` guarda solo `docs/`, `reports/`, `tests/`. Restano scoperti
  `knowledge/` (dove finiscono le history), `CLAUDE.md` e `.claude/` — la regola invece parla di tutto il repo
  e dei commit.

### R-04 — Metà del repo appartiene a root
```
$ find /home/ubuntu/workbrain -user root -not -path '*/.git/*' | wc -l
10
$ find /home/ubuntu/workbrain/.git -user root | wc -l
41
```
`CLAUDE.md`, `docs/05`, `docs/10`, `procedures.md`, quattro history, `plaud-cli-mcp.md` — più 41 oggetti dentro
`.git/`. È il debito "sessione girata come root" che si è materializzato: **l'utente `ubuntu` oggi non riuscirebbe
a lavorare su questo repo**, e la migrazione a `ubuntu` che l'architettura richiede (PAT-04) fallirebbe al primo
commit. Ogni sessione fatta come root peggiora il problema.

---

## Parte 3 — Rilievi 🟡 (proposte, non tocco senza il tuo ok)

### R-05 — Docker gira a vuoto
```
$ docker ps -a     → nessun container
$ docker images    → nessuna immagine
```
`docker.service` + `containerd.service` attivi, più due cron (`docker-builder-prune`, `docker-image-prune`)
installati il 2026-09-05 alle 19:21. Consumano RAM e CPU per nulla e allargano la superficie d'attacco (il gruppo
`docker` equivale a root; oggi è vuoto, e va bene così). **Proposta**: disabilitare i due servizi. Se in futuro
servisse containerizzare, si riaccendono in dieci secondi. Non li rimuovo, li spengo.

### R-06 — Monarx Agent: scanner di terze parti con privilegi di root
`monarx-agent.service` — *"Monarx Agent - Security Scanner"*, `ExecStart=/usr/bin/monarx-agent`, più il cron
`monarx-update`. È preinstallato da Hostinger, non è stato messo da noi, e **non è documentato in `docs/05`**.

Non lo tocco e non lo definisco un problema di sicurezza: fa il suo mestiere. Ma è un agente di un fornitore, con
accesso al filesystem, su una macchina che ospiterà **PII di clienti dello studio** e materiale riservato del
dominio riservato del datore di lavoro. È una decisione di riservatezza, quindi è tua, non mia. **Proposta**:
prenderne atto consapevolmente e annotarlo in `docs/05`; eventualmente verificare con Hostinger cosa esce dalla
macchina. Attenzione: rimuoverlo potrebbe violare le condizioni dell'hosting — da verificare prima, non dopo.

### R-07 — Nessuna swap
```
$ swapon --show  → (vuoto)     $ free -h → Swap: 0B
```
Con 15 Gi di RAM e 1 Gi in uso non è un problema oggi. Ma senza swap **un picco di memoria non degrada: viene
ucciso dall'OOM killer**, e un job di trascrizione o di embedding a metà strada muore senza preavviso.
**Proposta**: swapfile da 4 G con `vm.swappiness=10` (usata solo come rete di sicurezza, non per rallentare).

### R-08 — SSH: root con password, e gli attacchi sono già cominciati
Stato effettivo: `permitrootlogin yes`, `passwordauthentication yes`, `port 22`.
Ieri sera fail2ban segnava 0. **Adesso: 9 tentativi falliti, 1 IP bannato.** Non è più un rischio teorico.

Resta valido quanto già stabilito: **il tunnel non richiede la chiave**, quindi questo non blocca la pipeline.
Ma `ubuntu` ha la password **bloccata** (`passwd -S ubuntu` → `L`): senza chiave non ci si può collegare come
`ubuntu`, e finché è così **ogni sessione gira come root** — che è esattamente PAT-04, e che è la causa di R-04.

⚠️ **Precondizione di P-003 non ancora verificata**: la console web di hPanel entra come root **via publickey**
(verificato in `auth.log`: Hostinger inietta una chiave effimera e poi svuota `authorized_keys`, oggi 0 byte).
Se il file di lockdown dicesse `PermitRootLogin no` invece di `prohibit-password`, il lockdown **ucciderebbe anche
la console di recupero**. La lettura di `/etc/ssh/` mi è preclusa dalle deny-rule dell'harness: serve il tuo ok
per leggerlo prima di eseguire P-003.

### R-09 — Node installato due volte, e le versioni sono già divergenti
```
claude-code in /root         : 2.1.263
claude-code in /home/ubuntu  : 2.1.197
```
Due nvm completi (401 M + 457 M) e due cache npm (345 M + 99 M): ~1,3 G, metà ridondante. Lo spazio non è il
problema; **la divergenza sì**, ed è già avvenuta in un giorno. In più `@plaud-ai/cli` esiste **solo** per `ubuntu`:
una sessione come root non ha `plaud` nel PATH. `docs/05` documenta 2.1.197 e oggi è già sbagliato per root.
**Proposta**: consolidare su `ubuntu` (che è dove il progetto deve girare) e smettere di aggiornare quello di root.

### R-10 — `loginctl enable-linger ubuntu` manca, e serve all'architettura
```
$ loginctl show-user ubuntu → User ID 1000 is not logged in or lingering
```
BRIEF-001 sceglie **systemd user services + timer** come runner (default motivato). Senza *lingering*, i servizi
utente di `ubuntu` **non partono al boot e muoiono al logout**: la pipeline non girerebbe. Non è un problema oggi
(non c'è pipeline) ma è una precondizione di F1/F4 che nessuno ha ancora messo nel piano.

### R-11 — Il server MCP Plaud non è pinnato
`.mcp.json`: `npx -y @plaud-ai/mcp@latest`. Ogni invocazione **scarica ed esegue l'ultima versione pubblicata**,
con `-y` (nessuna conferma), su una macchina che tratterà dati riservati. È una dipendenza di supply chain non
controllata, oltre che una fonte di non riproducibilità: due sessioni a due giorni di distanza possono girare
codice diverso. **Proposta**: pinnare una versione esatta e aggiornarla deliberatamente.

### R-12 — `.claude/settings.local.json` è protetto solo per caso
```
$ git check-ignore -v .claude/settings.local.json
/root/.config/git/ignore:1:**/.claude/settings.local.json
```
È escluso dal **gitignore globale di root**, non dal `.gitignore` del repo. Quando si lavorerà come `ubuntu`
(o su un'altra macchina) quella protezione **non esiste più** e il file diventa committabile. Va nel `.gitignore`
del repo, dove appartiene.

### R-13 — Residui e piccole incoerenze
- `export CLAUDE_CODE_DISABLE_MOUSE=1` è ancora in `/root/.bashrc` (riga 108): workaround **mai dimostrato**,
  oggi inattivo, che si attiverà da solo alla prossima shell nuova disattivando lo scroll senza che si sappia perché.
- La skill `sync-plaud` prescrive in Step 0 un `cat` di `env.prod` — comando che **le deny-rule dell'harness
  rifiutano**. Va sostituito con un `test -f`: una procedura che l'harness blocca è una procedura rotta.
- `docs/05-infrastruttura-vps.md` **non menziona**: Docker, Monarx, l'assenza di swap, l'assenza di backup e remote,
  l'installazione Node lato root. Il documento descrive una macchina più semplice di quella reale.

---

## Parte 4 — Cosa propongo di fare, in ordine

Priorità per **rischio × costo**, non per gusto.

| # | Azione | Perché ora | Chi decide |
|---|---|---|---|
| 1 | Riparare la proprietà del repo (`chown -R ubuntu:ubuntu`) | Sblocca il lavoro come `ubuntu`; peggiora a ogni sessione root | **fatto salvo tuo stop** — è ripristino dell'intento documentato |
| 2 | `.claude/settings.local.json` nel `.gitignore` del repo | Una riga, toglie una protezione accidentale | **fatto salvo tuo stop** |
| 3 | Allineare `docs/05` alla macchina reale | Un documento che mente è peggio di nessun documento | **fatto salvo tuo stop** |
| 4 | **Remote git privato + push** | R-01: oggi un guasto cancella tutto | **serve la tua decisione** (dove: GitHub? GitLab?) |
| 5 | Far funzionare il gate dei test (R-02) | Regola #6 oggi è finta | **serve ok** (è un hook) |
| 6 | Chiudere il bypass Bash + fail-closed + `$CLAUDE_PROJECT_DIR` (R-03) | Le guardie inviolabili non lo sono | **serve ok** (sono hook) |
| 7 | Chiave SSH → P-003, previa verifica del file di lockdown (R-08) | Attacchi in corso; sblocca il lavoro come `ubuntu` | **serve la tua chiave** |
| 8 | Spegnere Docker (R-05), swapfile 4 G (R-07) | Igiene e rete di sicurezza | **serve ok** (servizi/sistema) |
| 9 | Pinnare il MCP Plaud (R-11), `enable-linger` (R-10), consolidare Node (R-09) | Precondizioni di F1/F4 | **serve ok** |
| 10 | Backup di `/srv/workbrain/` cifrato (R-01b) | Quando ci saranno dati veri | **serve la tua decisione** (può uscire dalla macchina?) |

### Cosa NON propongo
- Non propongo di toccare Monarx senza prima capire le condizioni dell'hosting (R-06).
- Non propongo di eseguire P-003 finché non ho letto il file di lockdown: il rischio di perdere anche la console
  di recupero è reale e non verificabile alla cieca.
- Non propongo micro-ottimizzazioni di performance: la macchina è sovradimensionata per il carico previsto, e
  ottimizzare prima di avere misure sarebbe esattamente l'errore che BRIEF-001 vieta.

---

## Appendice — Come ho verificato
`lscpu`, `free -h`, `df -hT`, `swapon --show`, `apt-get -s upgrade`, `systemctl --failed`,
`systemctl list-units --state=running`, `systemctl list-timers`, `ufw status numbered`, `ss -tulnp`,
`fail2ban-client status sshd`, `sshd -T`, `passwd -S`, `loginctl show-user`, `docker ps -a`/`images`,
`find -user root`, `git remote -v`, `git check-ignore -v`, `journalctl --disk-usage`, lettura diretta di
hook/agenti/skill/settings, e una prova pratica di bypass degli hook (file creato e rimosso).

Non verificato per limiti dell'harness (deny-rule, corrette): contenuto di `/etc/ssh/**`, di `/home/ubuntu/.ssh/**`,
di `/home/ubuntu/.plaud/**` e di `env.prod`. Per R-08 serve un tuo ok esplicito a leggere il file di lockdown.
