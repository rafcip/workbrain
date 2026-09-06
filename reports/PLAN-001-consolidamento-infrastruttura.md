# PLAN-001 — Consolidamento infrastruttura e harness, verso la piattaforma containerizzata

Data: 2026-09-06 · Autore: SysAdmin/Architetto · Stato: **BOZZA — non si implementa senza ok di Raf (regola #8)**
Origine: `reports/AUDIT-001-infrastruttura-e-harness.md` + decisione di Raf: *la piattaforma WorkBrain girerà in container*.

> Qui **decido io** e me ne prendo la responsabilità, come chiesto. Ogni scelta ha motivazione, alternativa scartata
> e condizione che me la farebbe cambiare. Quello che resta a Raf sono le decisioni **non tecniche**: dove mettere
> il codice, se e dove i dati possono uscire dalla macchina, e una questione di policy aziendale (§D-11) che non è
> mia da decidere.

---

## 0. Rettifica dell'audit

**AUDIT-001 R-05 è annullato.** Avevo proposto di spegnere Docker perché girava a vuoto. Con la decisione di
containerizzare la piattaforma, Docker non è cruft: è infrastruttura. Restano validi due punti sotto quel rilievo —
il gruppo `docker` equivale a root, e i due cron di prune erano lì senza che nessuno li avesse voluti — e li
riprendo dentro **D-01**, dove hanno un senso diverso.

Cambia anche il quadro di **R-10** (`enable-linger`): non è più un dettaglio del runner, diventa **una precondizione
architetturale**, perché la scelta del runtime container che propongo poggia sui servizi utente di systemd.

---

## 1. Le decisioni tecniche (D-01 … D-11)

### D-01 — Runtime container: **Docker rootless sotto l'utente `ubuntu`**, daemon rootful spento

**Decisione.** Installo `uidmap`, attivo Docker **rootless** per `ubuntu`, e **disabilito il daemon di sistema**
(`docker.service` + `containerd.service`) che non serve più. I due cron di prune vengono sostituiti da un timer
utente equivalente.

**Perché.** Il daemon Docker classico gira come root, e chiunque possa parlargli è **root sulla macchina**: mettere
`ubuntu` nel gruppo `docker` significa annullare la separazione dei privilegi che PAT-04 impone. Su una macchina che
ospiterà PII di clienti dello studio, regalare root a un processo di pipeline non è accettabile. In rootless, i
container girano dentro lo user namespace di `ubuntu`: un'evasione dal container atterra su un utente non
privilegiato, non su root.

**Fattibilità verificata oggi** (non assunta):
| Requisito | Esito |
|---|---|
| `/etc/subuid`, `/etc/subgid` per `ubuntu` | ✅ `ubuntu:100000:65536` già allocati |
| `kernel.unprivileged_userns_clone` | ✅ `1` |
| `dockerd-rootless-setuptool.sh` | ✅ presente |
| Docker / Compose | ✅ 29.8.0 / v5.5.1 |
| pacchetto `uidmap` (`newuidmap`) | ❌ **assente** → da installare |
| `kernel.apparmor_restrict_unprivileged_userns` | ⚠️ `1` → va gestito (profilo AppArmor per `rootlesskit`) |

**Trade-off onesti.** Rootless non può legare porte < 1024 (a noi non serve: nessun servizio pubblico). Ha qualche
attrito in più in setup. Su kernel 6.8 l'overlay nativo rootless funziona, quindi niente `fuse-overlayfs` lento.

**Cosa mi farebbe cambiare idea.** Se la restrizione AppArmor di Ubuntu 24.04 si rivelasse una battaglia (è il punto
di attrito più probabile), **non insisto**: fallback a Docker rootful con `ubuntu` **fuori** dal gruppo `docker`, e
comandi container espliciti via `sudo`. Il confine resta visibile invece che nascosto in un gruppo. Non abbasso la
guardia aggiungendo `ubuntu` al gruppo `docker`: quello è il *workaround* che la regola madre vieta.

### D-02 — Runner: **systemd user timer** che lanciano container one-shot

**Decisione.** Ogni step della pipeline è un container `--rm` avviato da un servizio utente di `ubuntu`, innescato da
un timer. Niente cron. Serve `loginctl enable-linger ubuntu`.

**Perché.** systemd dà quello che a una pipeline durabile serve davvero e che cron non ha: `Persistent=true` (se la
macchina era spenta all'orario, il job recupera), stato ed exit code per unità, log in journal correlati, dipendenze
ordinate, `RuntimeMaxSec` per non lasciare job appesi. E i servizi **utente** combaciano con D-01: stesso utente,
stesso user namespace, nessun privilegio in più.

**Alternativa scartata.** Un container long-running con uno scheduler interno (cron dentro il container, o APScheduler):
concentra tutto in un processo che, se muore, porta via l'intera pipeline, e nasconde lo stato dentro il container
invece di esporlo a `systemctl`/`journalctl`. Contrario a PAT-03 (orchestrazione = workflow durabili, non un
supervisore sincrono).

### D-03 — Confini dei container: **un'immagine, più step, permessi diversi per step**

**Decisione.** Una sola immagine base del progetto (build locale da `Dockerfile` nel repo, dipendenze pinnate), e
step diversi che montano `/srv/workbrain` con **il minimo permesso necessario**:

| Step | `raw/` | `vault/` | `db/` | rete |
|---|---|---|---|---|
| sync (Plaud → raw) | rw | — | — | uscita verso Plaud |
| stt + correzione | rw | — | — | uscita verso provider STT |
| distill → vault | ro | rw | — | uscita verso LLM |
| index → DB | — | ro | rw | nessuna |
| query / MCP | — | ro | ro | solo loopback |

**Perché.** È il vero guadagno dei container in questo progetto, più della portabilità: il passo che parla con
Internet non è lo stesso che può scrivere nel vault, e il passo che indicizza non può toccare gli audio originali.
La segregazione dei domini resta **codice** (colonna `domain` filtrata in ogni query) — questa è una seconda linea,
non un sostituto.

**Regole dure.** Container con `USER` non-root anche dentro il namespace; nessuna porta pubblicata (il DB si
raggiunge dalla rete compose o da socket, mai da `0.0.0.0`); `--read-only` sul rootfs dove possibile; immagini
**pinnate per digest**, mai `:latest`.

### D-04 — Gate di sicurezza dell'harness: **spostarlo al confine del commit**

**Decisione.** Tengo gli hook `PreToolUse` come feedback immediato, li correggo (fail-**closed** se manca `jq`,
`$CLAUDE_PROJECT_DIR` invece del path cablato, copertura estesa a `knowledge/` e `.claude/`), aggiungo un matcher
`Bash` per i casi ovvi di scrittura nel repo — **e sposto l'applicazione vera su un hook git `pre-commit`**,
versionato nel repo via `core.hooksPath`, che rilancia gli stessi scanner sul **contenuto in staging**.

**Perché.** La regola dice "mai in un commit". Oggi la si prova a far rispettare intercettando *ogni possibile modo
di scrivere un file*, che è una battaglia persa: AUDIT-001 R-03 lo dimostra, una `printf >` con Bash passa
indisturbata. Un hook `PreToolUse` su `Bash` può coprire i casi ovvi, mai tutti: la shell è troppo espressiva.
Il commit invece è **un collo di bottiglia unico**: qualunque strada abbia preso il file, lì deve passare.

Questo è il punto in cui applico la regola madre: il workaround "aggiungo un altro check sul modo di scrivere"
ha già fallito una volta, quindi **STOP** e si cambia livello, non si aggiunge un check.

### D-05 — Test: `tests/run.sh` come entry point unico, e il gate lo esegue davvero

**Decisione.** Creo `tests/run.sh` che esegue tutte le suite (oggi `test_hooks.sh`, domani quelle della pipeline).
`run-tests.sh` lo invoca. Aggiungo alla suite un test che **fallisce se il gate torna a essere inerte**.

**Perché.** R-02: oggi la regola #6 è dichiarata e non applicata, e la suite certifica come corretto il
comportamento a vuoto. Un gate che non può fallire non è un gate.

### D-06 — Il codice esce dalla macchina: **remote git privato**

**Decisione.** Repository **privato** su GitHub, con **deploy key SSH generata sul VPS** (la chiave privata non
lascia la macchina; Raf incolla solo la pubblica su GitHub). Push a ogni commit.

**Perché.** R-01 è il rilievo più grave e il più economico da chiudere. Il repo, **per costruzione**, non contiene
segreti né dati: `.gitignore` esclude `env.prod`, chiavi e le root dati, e gli hook lo verificano. Quindi spingerlo
su un remote privato non sposta informazione riservata — sposta solo il lavoro al sicuro.

**Cosa serve da Raf**: dire dove (GitHub, GitLab, altro) e incollare una chiave pubblica. Ora che la copia dal
terminale funziona, è un'operazione da due minuti.

### D-07 — I dati **non** escono dalla macchina finché non lo decidi tu

**Decisione.** Backup di `/srv/workbrain/` con **restic** (deduplica, snapshot, cifratura lato client), **repository
locale** su disco come primo passo, immediato e senza dipendenze esterne.

**Perché fermarsi lì.** Un backup locale protegge da `rm` sbagliati e da corruzione, **non** dalla perdita del VPS.
Dirlo chiaramente è parte del lavoro: finché il backup è locale, il rischio "perdo la macchina" resta aperto.
Portarlo fuori richiede una destinazione, un costo, e soprattutto una decisione di riservatezza che non è tecnica
(§D-11). Con restic la cifratura è lato client, quindi il fornitore vedrebbe solo blob opachi: è la premessa che
rende la scelta *possibile*, non che la prende al posto tuo.

### D-08 — Swap: **4 G, `vm.swappiness=10`**

**Decisione.** Swapfile da 4 G, swappiness bassa.

**Perché.** Con 15 Gi liberi non serve a "avere più memoria": serve perché senza swap un picco non degrada, **viene
ucciso dall'OOM killer**. Un job di trascrizione o di embedding che muore a metà è precisamente il tipo di guasto
che una pipeline idempotente deve poter riprendere, ma è meglio non provocarlo. Swappiness 10 = usala come rete,
non come memoria.

### D-09 — SSH: la chiave di Raf è il **primo** passo, non l'ultimo

**Decisione.** Prima di tutto il resto: chiave pubblica di Raf in `/home/ubuntu/.ssh/authorized_keys`, testata da
una seconda sessione, e da lì in poi **si lavora come `ubuntu`**. P-003 (lockdown password) **dopo**, e solo dopo
aver letto il file di lockdown.

**Perché è il primo passo e non un'igiene rimandabile.** Non è (solo) sicurezza: è la precondizione di quasi tutto
il resto di questo piano. `ubuntu` ha la password bloccata, quindi oggi **ogni sessione gira come root** — e questo
(a) ricrea di continuo la deriva di proprietà dei file (l'ho vista riaccadere durante l'audit stesso), (b) rende
impossibile installare Docker rootless *per `ubuntu`*, (c) rende impossibile provare i systemd user timer.
D-01 e D-02 **non sono eseguibili** finché si gira come root.

E nel frattempo gli attacchi sono cominciati: 9 tentativi falliti e 1 IP bannato nelle ultime ore.

⚠️ **Precondizione bloccante di P-003**: leggere `99-workbrain-lockdown.conf.disabled` e confermare
`PermitRootLogin prohibit-password` e **non** `no`. La console web di hPanel entra come root **via publickey**: con
`no` si perderebbe anche quella via di recupero. Le deny-rule dell'harness mi negano `/etc/ssh/**` — serve un ok
esplicito di Raf per quella singola lettura. **Non eseguo P-003 alla cieca.**

### D-10 — Igiene: pin, consolidamento, residui

**Decisione**, tutte a basso rischio, da fare in blocco quando si lavora come `ubuntu`:
- **Pinnare il MCP Plaud** a `@plaud-ai/mcp@0.3.10` (oggi `@latest` risolve a 0.3.10: il pin non cambia
  comportamento, cambia la **riproducibilità** e toglie un'esecuzione di codice non controllata a ogni invocazione).
- **Consolidare Node su `ubuntu`**: smettere di aggiornare quello di root e poi rimuoverlo. Le versioni sono già
  divergenti in un giorno (root 2.1.263 vs ubuntu 2.1.197); due installazioni sono due verità.
- **Rimuovere `CLAUDE_CODE_DISABLE_MOUSE=1`** da `/root/.bashrc`: workaround mai dimostrato, oggi inattivo, che si
  riattiverebbe da solo a shell nuova.
- **Correggere la skill `sync-plaud`**: il suo Step 0 prescrive un `cat` di `env.prod` che le deny-rule rifiutano.
  Una procedura che l'harness blocca è una procedura rotta.
- **Replicare `.tmux.conf`** in `/home/ubuntu/`.

### D-11 — ✅ CHIUSA il 2026-09-06: il dominio del datore di lavoro resta nel perimetro

**Risposta di Raf: nessun problema di policy.** Il dominio resta dentro WorkBrain, `monarx-agent` resta e non si
tocca, l'architettura **non cambia**. Verbale in [[2026-09-06-DECISIONE-perimetro-opentext]].
Contestualmente Raf ha posto il requisito *"che la piattaforma sia sicura"* → confluisce in **D-12**.

Resta agli atti l'analisi che ha motivato la domanda, perché il rischio descritto non sparisce con la risposta:

Il dominio `opentext` contiene, per definizione, **informazione riservata di un datore di lavoro**. Oggi quella
informazione andrebbe a vivere su un VPS Hostinger su cui gira **`monarx-agent` come root** — un agente di sicurezza
del fornitore, con accesso al filesystem. Va detto con precisione: **la cifratura a riposo non protegge da questo**.
Un processo root sulla macchina vede i dati in chiaro nel momento in cui la pipeline li elabora. Non è un difetto da
correggere: è una proprietà di dove abbiamo scelto di girare.

Il rischio resta reale ed è ora **accettato consapevolmente**, che è cosa diversa dall'essere ignorato. Non lo
mitigo con teatro tecnico (cifrare a riposo contro un agente che gira come root non serve): lo mitigo con le stesse
scelte che valgono per tutto il resto — privilegio minimo per step (D-03), rootless (D-01), niente porte pubblicate.

### D-12 — Fondamenta compatibili con un prodotto: **porte a senso unico sì, prodotto no**

**Contesto.** Raf: *"un'idea futura è trasformarla in un prodotto da commercializzare, quindi dobbiamo cominciare a
mettere le fondamenta anche se in questo momento abbiamo uno scopo solo di WorkBrain personale."*
Verbale completo in [[2026-09-06-DECISIONE-prodotto-futuro]].

**Decisione.** **Non costruisco un prodotto adesso.** Multi-tenancy, autenticazione, billing e pannelli per un
utente solo sarebbero lavoro sprecato, contrari ai principi del progetto, e il modo più rapido per non finire mai
WorkBrain. Quello che faccio è pagare il **piccolo** prezzo solo dove il prezzo *dopo* sarebbe enorme.

**Il criterio: porte a senso unico vs porte a doppio senso.**

*A senso unico — le progetto già compatibili, perché si infilano in ogni riga di codice e di DB:*
1. **`owner` nel modello dati** (DB + frontmatter), oggi sempre valorizzato uguale. Una colonna adesso; una
   migrazione di ogni tabella e la revisione di **ogni query** dopo. ⚠️ `owner` è **ortogonale** a `domain` e non lo
   sostituisce: `domain` resta obbligatorio e filtrato ovunque.
2. **Motore DB**: il default "SQLite+sqlite-vec" di BRIEF-001 era motivato *da utente singolo*. Il criterio cambia.
   Non lo ribalto per principio — si decide con le misure, aggiungendo al confronto il costo di migrare dopo.
3. **Tassonomia dei domini come configurazione, non `enum` nel codice.**
4. **Vincoli legali come criterio eliminatorio** in BRIEF-001: uso commerciale consentito (anche per le licenze dei
   pesi dei modelli) e disponibilità di un accordo sul trattamento dati, oltre a EU + no-training.
5. **Segreti con ambito** fin da subito: niente chiavi globali assunte come uniche.
6. **Registro degli accessi** dal primo giorno: impossibile ricostruirlo a posteriori.

*A doppio senso — restano semplici:* interfaccia, superficie API, provider di identità, billing, topologia di deploy.

**Il requisito "sicura" non aggiunge fasi**, perché è già dentro: D-01 (rootless), D-03 (privilegio minimo per step),
D-04 (gate al commit), D-07 (backup cifrati). Aggiunge solo il punto 6 qui sopra, e sposta i criteri di BRIEF-001.

**Cosa mi farebbe cambiare idea.** Se il prodotto smettesse di essere un'ipotesi e diventasse una scadenza, la
conversazione cambia: a quel punto multi-tenancy e identità vanno progettate sul serio, non anticipate di sguincio.

---

## 2. Sequenza di esecuzione

Ordinata per **dipendenza reale**, non per gusto. Ogni fase ha un test di uscita: se non passa, non si prosegue.

### Fase A — Sbloccare e mettere in sicurezza (nessuna dipendenza dai container)
| # | Azione | Test di uscita |
|---|---|---|
| A1 | Chiave SSH di Raf per `ubuntu` (D-09) | `ssh ubuntu@<ip>` da una **seconda** sessione, con la prima ancora aperta |
| A2 | Da qui in poi si lavora come `ubuntu` | `whoami` = ubuntu; `git status` pulito senza `chown` |
| A3 | Remote git privato + primo push (D-06) | `git push` OK; `git ls-remote` elenca `main` |
| A4 | Swapfile 4 G (D-08) | `swapon --show` mostra 4 G; `free -h` conferma; sopravvive a reboot |
| A5 | `enable-linger ubuntu` (D-02) | `loginctl show-user ubuntu` → `Linger=yes` |
| A6 | Igiene D-10 (pin MCP, tmux, residui, skill) | suite verde; `/mcp` carica il server pinnato |

### Fase B — Rendere vere le guardie che oggi sono finte
| # | Azione | Test di uscita |
|---|---|---|
| B1 | `tests/run.sh` + gate che lo esegue (D-05) | una modifica in `scripts/` fa **davvero** girare la suite |
| B2 | Hook fail-closed, `$CLAUDE_PROJECT_DIR`, copertura estesa (D-04) | test negativo: senza `jq` l'hook **blocca**, non passa |
| B3 | Hook git `pre-commit` via `core.hooksPath` (D-04) | un file con un finto segreto scritto **via Bash** viene **rifiutato al commit** |
| B4 | Backup restic locale di `/srv/workbrain/` (D-07) | `restic snapshots` mostra uno snapshot; **restore di prova verificato** |

> B3 è il test che oggi fallirebbe. È la ragione d'essere della fase.

### Fase C — Fondamenta container (richiede A completata)
| # | Azione | Test di uscita |
|---|---|---|
| C1 | `apt install uidmap`; Docker rootless per `ubuntu`; gestione AppArmor (D-01) | `docker info` come `ubuntu` mostra rootless; `docker run hello-world` OK |
| C2 | Spegnere `docker.service`/`containerd.service` rootful + cron di prune | i servizi sono `disabled`; il rootless continua a funzionare |
| C3 | `Dockerfile` base + `compose.yaml` scheletro, immagini pinnate per digest (D-03) | build riproducibile; container gira come utente non-root |
| C4 | Un servizio+timer utente d'esempio che lancia un container one-shot (D-02) | il timer scatta, il job gira, `journalctl --user` lo registra; sopravvive a reboot |

### Fase D — Solo dopo: la piattaforma
Con A+B+C chiuse, si torna a **BRIEF-001**: misure sui campioni (che oggi mancano — servono 1 IT multi-speaker e
1 misto IT/EN), scelta provider STT, motore DB, embedding. E si progetta la piattaforma **dentro** le fondamenta
appena costruite, invece di costruirle mentre si progetta.

---

## 3. Cosa serve da Raf per partire

Tre cose, in ordine di quanto bloccano:

1. **La chiave pubblica SSH** (A1). Senza, la Fase C è proprio impossibile e la Fase A resta a metà.
2. **Dove mettere il remote git** (A3): GitHub? GitLab? Serve solo che tu incolli una chiave pubblica.
3. **L'ok a leggere `/etc/ssh/99-workbrain-lockdown.conf.disabled`** — una singola lettura, per non eseguire P-003 alla cieca.

**D-11 è chiusa** (2026-09-06): nessun blocco di policy, l'architettura non cambia. Al suo posto entra **D-12**,
che non richiede nulla da te adesso — sposta criteri in BRIEF-001 e aggiunge `owner` allo schema, che è ancora BOZZA
e quindi modificabile a costo zero: non ci sono ancora dati da migrare.

## 4. Cosa non faccio in questo piano
- Non tocco **Monarx**: rischio ora **accettato consapevolmente** (D-11), non ignorato.
- **Non costruisco un prodotto** (D-12): pago solo le porte a senso unico.
- Non eseguo **P-003** finché non ho letto il file di lockdown.
- Non porto backup fuori dalla macchina senza una tua decisione esplicita.
- Non ottimizzo performance: la macchina è sovradimensionata e non ho misure. Ottimizzare adesso sarebbe
  esattamente l'errore che BRIEF-001 vieta.
