# 2026-09-08 — HANDOFF: analisi del modello Legal Agency, rettifica di PAT-04, mandato piattaforma

Handoff dall'ultima sessione **root** (console hPanel) alla prossima sessione **`ubuntu`**.
Contiene cose nate in conversazione con Raf che **non sono altrove nel repo**: se si perde questo file,
si perdono. Il resto dello stato è già nei commit e in `docs/10-stato-e-backlog.md`.

---

## 0. Prima di tutto: una sola sessione alla volta

Il 2026-09-07 sono girate **due** sessioni Claude Code sullo stesso repo (una root, una `ubuntu`) e sono
divergute: la sessione `ubuntu` chiedeva a Raf il via libera per pushare la Fase C **mentre quella root
l'aveva già pushata**. Finita bene per caso, perché le due azioni andavano nella stessa direzione.

**Regola operativa**: una sola sessione Claude Code sul repo. Prima di aprirne una, chiudere l'altra.

---

## 1. Stato in questo momento (verificato)

- `main` = **`a86239b`**, allineato a `origin/main`, working tree pulito, 0 commit non pushati.
- Suite **come `ubuntu`**: `83 + 23 = 106 verdi, 0 falliti` (rc=0).
- PLAN-001: **Fasi A, B, C completate**. Qui il piano finisce, per volere di Raf.
- SSH in lockdown (solo chiave), backup restic con timer, Docker rootless sotto `ubuntu`.

⚠️ **Da fare subito**: questo file e le modifiche che porta **non sono committati** — la sessione root non
poteva committare (vedi §4). Committarli è il primo atto della sessione nuova.

---

## 2. `machinectl`: come si entra come `ubuntu` dalla console hPanel

**Non documentato altrove. Serve a Raf ogni giorno.**

Raf lavora dalla console web di hPanel, che entra come **root**. Con `su - ubuntu` si ottiene una shell
**degradata**: `XDG_RUNTIME_DIR` e `DBUS_SESSION_BUS_ADDRESS` vuoti, `systemctl --user` fallisce con
*"Failed to connect to bus"*. Quindi niente Docker rootless, niente timer utente — cioè niente Fase C.

Nella sessione root era stato erroneamente concluso che servisse per forza un login SSH da PowerShell.
**Non è vero.** È stato installato il pacchetto `systemd-container` e la soluzione è:

```bash
machinectl shell ubuntu@        # sessione VERA via systemd-logind
tmux new -A -s workbrain        # attacca se esiste, crea se non c'è
```

Misurato: `XDG_RUNTIME_DIR=/run/user/1000`, `DBUS=unix:path=/run/user/1000/bus`,
`systemctl --user is-system-running` → `running`.

**Da documentare** in `docs/05-infrastruttura-vps.md` e nella **P-007**, che oggi dice "girare come `ubuntu`"
senza spiegare come arrivarci dalla console: è esattamente l'inciampo in cui è finito Raf.
Da annotare anche l'installazione di `systemd-container` (modifica al sistema, reversibile con `apt remove`).

**Idea da valutare**: un controllo d'avvio che verifichi `XDG_RUNTIME_DIR`. Una sessione degradata non dà
errore subito: si manifesta più tardi, quando un timer non parte, con la causa ormai lontana.

---

## 3. 🔴 PAT-04 non è la lezione di Legal Agency: è una sua riscrittura

**È il rilievo più importante di questo handoff.**

Raf ha detto di **non riconoscere** PAT-04, e ha fornito il report del SysAdmin di Legal Agency
("Regola utenti e permessi per Claude Code su un VPS con container", 07/09/2026). Confronto:

| | |
|---|---|
| **PAT-04 nel nostro repo** | *"Girare come root / più root dati → utente operativo non root…"* |
| **Il report di Legal Agency** | *"La regola non è «non usare root», è «root scrive, poi restituisce la proprietà a uid 1000»."* |

Sono **conclusioni opposte**. Là Claude Code gira come root **di proposito**, e i processi applicativi come
uid 1000; il problema reale che hanno risolto è **l'allineamento degli uid fra host e container**, non
l'uso di root.

`docs/00-lineage-legal-agency.md` presenta PAT-04 come *"lezione già pagata"*. Non lo è: è un'ipotesi
presentata come esperienza. Ed è particolarmente insidioso, perché ciò che è etichettato "già pagato"
nessuno lo rimette in discussione — infatti è stato ereditato senza obiezioni e ci è stata costruita sopra
tutta la Fase C.

### Cosa fare
1. **Correggere PAT-04** in `bug-registry.md` e `docs/00-lineage-legal-agency.md`: la lezione vera è
   *l'allineamento uid host↔container*, e va attribuita alla fonte giusta.
2. **Passare in rassegna PAT-01…PAT-06 con Raf**, marcando ciascuno **"vissuto"** o **"dedotto"**.
   I dedotti restano se sono buone idee, ma perdono l'autorità dell'esperienza. Non è accademia: PAT-01
   decide come si scrive il frontmatter, PAT-06 decide cosa valida il canary.
   (PAT-07 è nostro, con evidenza reale: quello regge.)
3. Stesso trattamento di BRIEF-001, declassato dal 2026-09-06 per la stessa ragione.

### Nota onesta sulla scelta non-root
La decisione di girare come `ubuntu` è nata da PAT-04, cioè da una premessa sbagliata. Ma **regge lo stesso**,
per un motivo diverso e più modesto: se si usano container — e lo ha deciso Raf — il rootless è ciò che rende
il confine reale invece che decorativo. Il costo residuo è **un comando** (`machinectl shell ubuntu@`).
Va difesa così, non citando una lezione che non esiste. Raf ha anche precisato che **i dati di Legal Agency
sono più importanti** di quelli di WorkBrain: ogni argomento basato sulla sensibilità relativa è da buttare.

---

## 4. La nostra architettura NON ha la classe di incidente di Legal Agency (verificato)

Il loro report elenca tre incidenti, tutti della stessa famiglia: un file nasce con una proprietà che il
consumatore non può usare → `EACCES`. Il 07/09/2026 è costato una risposta *"problema tecnico, segnale non
inoltrato"* a un avvocato.

Loro riparano **a valle** (`chown` dopo ogni scrittura, con auto-fix nell'heartbeat) e al §6 ammettono un
**debito aperto**: quattro `docker exec … openclaw agent` senza `-u node` che continuano a ricreare file root.

Qui il problema è rimosso **a monte**. Prova reale, non ragionamento — file scritto da un container nel volume:

```
dentro il container:  uid=10001  gid=0                 mode=664
sull'host:            uid=110000 gid=1000(ubuntu)      -rw-rw-r--
```

e `ubuntu` lo modifica e lo cancella senza problemi. Funziona per tre scelte combinate:
`USER 10001:0` (gid 0 del container → gid 1000 sull'host), directory dati `drwxrws---` (**setgid** + gruppo
in scrittura), umask che lascia `g+w`. **Nessuna disciplina di `chown` da ricordare.**

⚠️ **Non copiare il §3 del loro report** ("Regola per CLAUDE.md"): comincia con *"Claude Code gira come root"*
ed è scritto per il loro modello. Incollarlo qui smonterebbe la Fase C.

### Cosa invece adottare, adattato
- **Controllo periodico dei permessi** (loro lo hanno nell'heartbeat). Il loro `find -not -user ubuntu`
  **qui non si trasferisce**: i nostri file hanno legittimamente uid 110000 e darebbe solo falsi positivi.
  La versione corretta cerca i file **non usabili dal gruppo**:
  ```bash
  find /srv/workbrain \( -not -group ubuntu -o \( -type f ! -perm -g+w \) \) -print
  ```
- **`EACCES` nei log = anomalia ATTIVA**, da cercare subito e non al controllo successivo. Vale identica.

### Da restituire a loro (se Raf vuole)
Il debito del §6 è correggibile alla radice con il loro stesso principio (*"la correzione è al produttore"*):
il loro `Config.User` è `root` e l'entrypoint fa `runuser -u node`, per questo un `docker exec` nudo entra
come root. Se l'immagine dichiarasse `USER node` come default, un `-u` dimenticato non farebbe più danni e i
quattro call-site smetterebbero di essere un debito da ricordare. L'entrypoint può ancora elevarsi se serve.

---

## 5. 🟡 Difetto della suite: 8 rossi falsi se girata come root

```
come ubuntu :  83 + 23 = 106 verdi, 0 falliti   (rc=0)
come root   :  8 falliti                        (rc=1)
```

Gli 8 riguardano i symlink delle unit utente e il daemon rootless: come root, `~/.config/systemd/user` è
quello di root e il daemon di `ubuntu` non è visibile. **La suite ha ragione**, ma li presenta come guasti.

Conseguenza concreta: **il gate `pre-commit` esegue la suite, quindi da root ogni commit viene rifiutato.**
È il motivo per cui questo handoff non è committato.

**Da fare**: far rilevare alla suite l'utente sbagliato e uscire con **una riga chiara** invece di otto rossi.
Otto rossi che non sono guasti insegnano a ignorare i rossi — la stessa dinamica di PAT-07.

---

## 6. Il mandato vero: analisi e piano della piattaforma, da zero

> Raf: *"Per pianificazione e sviluppo della piattaforma voglio che fai tu analisi e piano, non mi fido del brief."*

PLAN-001 è finito. **Il prossimo lavoro non è implementare: è analizzare e pianificare.**

Vincoli già decisi, da rispettare nel piano nuovo:
- [[2026-09-06-DECISIONE-prodotto-futuro]] — fondamenta da prodotto ma **non si costruisce un prodotto**:
  si pagano solo le porte a senso unico (`owner` nel modello dati, tassonomia come configurazione, registro
  accessi, vincoli legali come criterio **eliminatorio**, segreti con ambito).
- [[2026-09-06-DECISIONE-perimetro-opentext]] — il dominio riservato resta nel perimetro.
- Le tre decisioni del 2026-09-05 (bilingue senza traduzione, no subscription Plaud, STT via API con diarizzazione).
- ⚠️ **BRIEF-001 è solo una fonte di fatti misurati**, non di conclusioni né di default. In particolare la
  scelta "SQLite+sqlite-vec" era motivata **da utente singolo** e va ripesata.

**Bloccante da Raf**: mancano i campioni di prova (serve 1 registrazione IT multi-speaker con termini tecnici
e 1 mista IT/EN). Le 5 esistenti non bastano. Senza, le misure non sono rappresentative — ma **l'analisi e il
piano si possono scrivere lo stesso**, e devono dire esattamente quali misure servono e perché.

---

## 7. Verifica di ripresa (P-001)

```bash
whoami                                   # atteso: ubuntu   <-- se root, fermarsi
cd ~/workbrain
git log --oneline -3                     # atteso: a86239b in testa (o piu' recente)
git status                               # atteso: clean, salvo questo handoff da committare
git ls-remote origin main                # atteso: stesso hash del locale
bash tests/run.sh                        # atteso: 83 + 23 verdi, 0 falliti
git config core.hooksPath                # atteso: .githooks
echo $XDG_RUNTIME_DIR                    # atteso: /run/user/1000
systemctl --user list-timers             # atteso: backup, docker-prune, step@index
```

## 8. Riferimenti
`reports/PLAN-001-consolidamento-infrastruttura.md` · `reports/AUDIT-001-infrastruttura-e-harness.md` ·
[[2026-09-07-fase-c-container-rootless]] · [[2026-09-07-remote-github-e-lockdown-ssh]] ·
[[2026-09-06-fase-a-b-guardie-vere-e-backup]] · `.claude/rules/procedures.md` (P-007)
