# 10 — Stato e backlog

Ultimo aggiornamento: 2026-09-07 (sera — PLAN-001 Fase C completata: container rootless e timer utente)

Il file aggiornato più spesso. Fonte di verità sullo stato operativo. All'avvio di ogni sessione si legge questo
(vedi `.claude/rules/continuity.md`).

## Stato operativo
- **Fase**: **PLAN-001 completato fino alla Fase C compresa** — qui ci si ferma per volere di Raf. L'harness ha
  guardie vere, backup, remote e ora fondamenta container. Nessuna pipeline in esecuzione: gli step di
  `compose.yaml` sono segnaposto.
- Suite: **106 verdi, 0 falliti** (`bash tests/run.sh`) = 23 hook + 83 invarianti di Fase C, questi ultimi letti
  dalla configurazione **effettiva** (non dalle righe dei file) e provati per mutazione, comprese quelle
  **additive**: un servizio ostile aggiunto a `compose.yaml` fa fallire 9 test.
- Il **`pre-commit` ora esegue la suite** oltre agli scanner, ed è fail-closed: suite rossa o assente → commit
  rifiutato. È un cambio di comportamento del gate, introdotto per chiudere un bloccante del reviewer.
- **Sessione come `ubuntu`** (A2 chiusa): mai più root. Prima sessione non-root il 2026-09-07.
- **Container**: Docker **rootless** sotto `ubuntu`, daemon rootful spento, `ubuntu` fuori dal gruppo `docker`.
  Tre timer utente attivi: backup, prune di Docker, e `workbrain-step@index` come canary del runtime.
  Dettaglio e prove: [[2026-09-07-fase-c-container-rootless]].
- **VPS**: in ordine (utente `ubuntu`, UFW+fail2ban attivi, tool e CLI installati). Dettaglio: `docs/05-infrastruttura-vps.md`.
- ✅ **`plaud login` completato** (2026-09-05 sera, P-004). Token in `/home/ubuntu/.plaud/`, `plaud me` risponde
  con l'identità corretta. **BRIEF-001 Step 0 è ora eseguibile.**
- ✅ **Copia testo dalla console web risolta**: era `"tui": "fullscreen"` in `~/.claude/settings.json`, non il mouse
  tracking. Fix: `/tui default`. Vedi [[2026-09-05-login-plaud-e-fix-copia-tui]].
- **Provider STT / storage / embedding / runner**: **non ancora scelti** → si decidono in `reports/BRIEF-001-analisi-soluzione.md`.

## Sorveglianze / canary
- Nessun canary attivo (non c'è ancora pipeline). Il **primo canary** sarà la prima registrazione **vera** processata
  end-to-end (valida l'output finale, non gli ingredienti — regola #6), previsto in F2/F3.

## Lavori approvati (pronti da eseguire)
- Eseguire **BRIEF-001**: Step 0 di misure reali su 3 registrazioni (IT/EN/mista) e 2-3 provider STT, poi scelte.
  (Le decisioni tecniche dentro un brief approvato sono autonome; le scelte di prodotto tornano a Raf.)
  - ✅ **Step 0.1 inventario** fatto (2026-09-05): 5 registrazioni in 30 giorni, nessuna riconducibile a `opentext`
    o a clienti dello studio → si lavora in `personal`. Dettaglio in [[2026-09-05-login-plaud-e-fix-copia-tui]].
  - ⏸️ **Step 0.2-0.4 fermi**: manca il materiale di prova rappresentativo (vedi bloccante #1 qui sotto).
  - ▶️ **Eseguibile subito senza nuovi campioni**: `plaud audio`/`transcript`/`summary` su una registrazione demo
    per fissare formati e flag reali della 0.3.11, e la baseline degli errori sui termini tecnici.

## Piano di consolidamento (2026-09-06)
- `reports/AUDIT-001-infrastruttura-e-harness.md` — audit eseguito. 3 rilievi 🔴 strutturali (nessun backup/remote,
  gate dei test inerte, hook aggirabili via Bash) + 1 riparato (proprietà del repo).
- `reports/PLAN-001-consolidamento-infrastruttura.md` — **APPROVATO da Raf il 2026-09-06** ("dopo fase C ci fermiamo").
  Decisioni D-01…D-12 prese come owner. Stato di esecuzione:
  - **Fase A**: A1 ✅ · A3 ✅ · A4 ✅ · A5 ✅ · A6 ✅ · **A2 rimandata** (migrazione sessione a `ubuntu`, serve handoff).
    A3: remote privato `rafcip/workbrain` su GitHub con deploy key dedicata; chiavi host verificate contro
    `api.github.com/meta`. **AUDIT-001 R-01 chiuso.** Vedi [[2026-09-07-remote-github-e-lockdown-ssh]].
  - **P-003 lockdown SSH eseguita** il 2026-09-07: l'accesso via password non esiste più. Si entra solo con la
    chiave, o dalla console hPanel (che usa una chiave iniettata da Hostinger).
  - **Permessi dell'harness riscritti** (decisione di Raf): piena autonomia amministrativa; resta vietata la
    **lettura** dei segreti e le operazioni distruttive.
  - **Fase B**: ✅ **completata**. Gate dei test operativo, hook fail-closed e copertura estesa, hook git `pre-commit`
    provato end-to-end contro il bypass, backup restic con timer utente e **prova di ripristino riuscita**.
    Suite da 11 a 23 test. Vedi [[2026-09-06-fase-a-b-guardie-vere-e-backup]].
  - **Fase C**: ✅ **completata il 2026-09-07** (C1-C4). Docker rootless per `ubuntu`; daemon rootful e cron di
    prune spenti; `Dockerfile` pinnato per digest con `USER 10001:0`; `compose.yaml` che applica la matrice dei
    permessi di D-03 (mount **e** rete provati per ogni step); template `workbrain-step@.service`/`.timer` con timer verificato
    "in volo". L'attrito temuto su AppArmor **non si è presentato**: il fallback di D-01 non è servito.
    Difetto trovato e corretto lungo la strada: `RuntimeMaxSec=` è ignorato con `Type=oneshot` — il guard-rail
    anti-hang del backup (Fase B) era dichiarato ma inesistente. Ora è `TimeoutStartSec=`, con test.
    Le unit systemd sono state portate **nel repo** (`systemd/user/`, symlink dalle unit attive): prima erano
    fuori dal versionamento e fuori dal backup. Fa eccezione `docker.service` utente, rimasto fuori: è
    rigenerabile con `dockerd-rootless-setuptool.sh install`.
  - **Review indipendente: NO-GO iniziale, 4 bloccanti, tutti chiusi prima del commit.** Il prune notturno
    avrebbe cancellato l'immagine del progetto entro 48 h trasformando il canary in una build giornaliera (B1);
    lo step `query` aveva Internet piena dove D-03 dice "solo loopback", ed è quello che vede tutti i domini (B2);
    i test dei confini erano `grep` sui file e non rilevavano un servizio ostile aggiunto — PAT-07 commesso nella
    stessa sessione in cui è stato registrato (B3); il gate non eseguiva mai quei test sui file che proteggono (B4).
    Dettaglio e prove in [[2026-09-07-fase-c-container-rootless]].
  - **Fase D**: BRIEF-001 **non è più il piano di riferimento** (vedi sotto). Analisi e piano della piattaforma
    vanno rifatti da zero.
- ⚠️ **BRIEF-001 declassato il 2026-09-06 per decisione di Raf** ("non mi fido del brief"): da piano approvato a
  semplice input da riesaminare. Per la piattaforma si produce un'analisi e un piano nuovi. Restano validi come
  *fatti misurati* solo gli esiti verificati (es. errori sui termini tecnici di Plaud), non le conclusioni.
- Decisioni di Raf del 2026-09-06: [[2026-09-06-DECISIONE-perimetro-opentext]] (D-11 chiusa, nessun cambio di
  architettura) e [[2026-09-06-DECISIONE-prodotto-futuro]] (fondamenta da prodotto, prodotto no).
- Da fare quando PLAN-001 è approvato: aggiungere `owner` a `.claude/rules/schema-kb.md` (frontmatter + colonna DB)
  e i criteri eliminatori a BRIEF-001 (uso commerciale, accordo sul trattamento). Lo schema è BOZZA e non ci sono
  ancora dati: costo zero adesso, migrazione dopo.

## In attesa di decisione / azione di Raf
1. 🔴 **Campioni di prova per lo Step 0 di BRIEF-001.** L'inventario (`plaud recent --days 30` → 5 registrazioni)
   **non basta**: c'è 1 sola registrazione IT da 1m06s, 3 demo Plaud in EN, e **nessun campione misto IT/EN**.
   Servono 2-3 registrazioni `personal` fatte apposta: una **IT multi-speaker** con termini tecnici, una **mista
   IT/EN**. Senza, le misure di WER/glossario/diarizzazione non sono rappresentative. È il bloccante numero uno adesso.
2. ~~Chiave SSH per `ubuntu`~~ ✅ **CHIUSA il 2026-09-06**: chiave dedicata `id_workbrain` installata e login
   verificato sul log (`Accepted publickey for ubuntu … ED25519 SHA256:S1HP1AGX…`).
   Vedi [[2026-09-06-chiave-ssh-ubuntu-attiva]]. Sblocca PLAN-001 A2 e la Fase C.
2b. ~~Remote git~~ ✅ **CHIUSO il 2026-09-07**: `rafcip/workbrain` privato su GitHub, push verificato.
2c. ~~Lettura del file di lockdown~~ ✅ **CHIUSA**: diceva `prohibit-password`, quindi P-003 era sicura ed è stata eseguita.
2d. 🟡 **Email nei commit**: oggi l'autore è `raffaele.cipro@gmail.com`. Su repo privato va bene; se il repo
   diventasse pubblico resterebbe nella storia. Opzione `@users.noreply.github.com` proposta, **non ancora decisa**.
2e. 🟡 **Riavvio di prova del VPS non fatto.** Che daemon rootless e timer utente ripartano da soli dopo un
   reboot è sostenuto dall'evidenza strutturale (`Linger=yes`, unit `enabled` nei `.wants` — è esattamente ciò
   che systemd legge all'avvio), **non** da un riavvio vero. Il riavvio interrompe la sessione: serve l'ok di Raf.
3. 🟡 **Rimuovere `CLAUDE_CODE_DISABLE_MOUSE=1`** da `/root/.bashrc` (riga 108): workaround mai dimostrato,
   inattivo oggi ma che si attiverà da solo alla prossima shell nuova. Config → serve l'ok di Raf (regola #3).
4. 🟡 **Precondizione mancante in P-003**: prima di eseguirla va letto `99-workbrain-lockdown.conf.disabled` e
   confermato che dica `PermitRootLogin prohibit-password` e **non** `no`. La console web di hPanel entra come
   root **via publickey** (verificato in `auth.log`, chiave iniettata da Hostinger e poi cancellata):
   con `PermitRootLogin no` si perderebbe anche quella via di recupero.
5. 🟡 Conferma dei **domini** e delle regole di segregazione come codificate in `.claude/rules/domini-riservatezza.md`.

## Tech debt / rischi noti
- ~~Sessione girata come root~~ ✅ risolto: dal 2026-09-07 le sessioni girano come `ubuntu`.
- Gli step di `compose.yaml` sono **segnaposto** che stampano il proprio perimetro: i confini sono veri, il
  contenuto no. Vanno riempiti dal piano nuovo della piattaforma, non prima.
- Il `Dockerfile` sceglie Python come base: è una **comodità dello scheletro**, non una decisione di piattaforma.
  Cambiare la riga `FROM` è l'intero costo di cambiare idea.
- **Vincolo per la Fase D**: `umask 002` non basta. Codice che fissa i permessi in modo esplicito
  (`mkstemp` → 0600, writer atomici, `os.chmod`) produce file di proprietà host `110000` che `ubuntu` **non può
  modificare né chown-are**. Sul `vault/`, che Raf apre con Obsidian, è il danno peggiore.
- Le unit systemd sono **symlink al working tree**: `git checkout`/`stash`/cambio di branch cambiano la
  configurazione systemd viva senza `daemon-reload`.
- 🟡 `block-bash-writes.sh` dà **falsi positivi** sui comandi di sola lettura che contengono un pattern-segreto e
  un `2>/dev/null`: ostacola proprio i comandi di audit. Pre-esistente.
- `env.prod` è un **template senza valori**: le chiavi provider vanno inserite dopo BRIEF-001.
- Schema KB e scelta motore DB sono **BOZZA**: si consolidano in F3/F4.

## Metriche (placeholder — da popolare con BRIEF-001)
- WER per provider (IT/EN/mista): —. Costo €/ora audio: —. Tempo di processing: —. Qualità diarizzazione: —.

## Timeline / fasi del piano (dettaglio in BRIEF-001)
- **F1** sync audio · **F2** STT+diarizzazione · **F3** distill+vault · **F4** DB+query MCP · **F5** digest+azioni · **F6** hardening+backup.
  ⚠️ Questa timeline viene da BRIEF-001, che è **declassato**: va riesaminata nel piano nuovo, non ereditata.
- Oggi: **pre-F1**. L'infrastruttura è pronta e ferma; il prossimo lavoro è **analisi e piano nuovi della
  piattaforma**, che Raf ha chiesto di rifare da zero. Restano bloccanti i campioni di prova (punto 1).
