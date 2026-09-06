# 10 — Stato e backlog

Ultimo aggiornamento: 2026-09-05 (sera — login Plaud completato)

Il file aggiornato più spesso. Fonte di verità sullo stato operativo. All'avvio di ogni sessione si legge questo
(vedi `.claude/rules/continuity.md`).

## Stato operativo
- **Fase**: bootstrap dell'harness completato e **rivisto (verdetto GO del reviewer)**. Nessuna pipeline in esecuzione. Nessun servizio systemd WorkBrain attivo.
- Hook verificati con suite committata `tests/test_hooks.sh` (11/11 verdi, riverificati 2026-09-05 sera).
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
  - **Fase A**: A1 ✅ · A4 ✅ · A5 ✅ · A6 ✅ · **A2 rimandata** (migrazione sessione a `ubuntu`, serve handoff) ·
    **A3 bloccata** (manca la scelta GitHub/GitLab per il remote).
  - **Fase B**: ✅ **completata**. Gate dei test operativo, hook fail-closed e copertura estesa, hook git `pre-commit`
    provato end-to-end contro il bypass, backup restic con timer utente e **prova di ripristino riuscita**.
    Suite da 11 a 23 test. Vedi [[2026-09-06-fase-a-b-guardie-vere-e-backup]].
  - **Fase C**: da fare, **dopo** la migrazione a `ubuntu` (va installata per quell'utente).
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
2b. 🔴 **Dove mettere il remote git** (GitHub/GitLab, privato). Chiave di deploy generata sul VPS, Raf incolla solo
   la pubblica. Chiude AUDIT-001 R-01, il rilievo più grave.
2c. 🟡 **Ok a leggere** `/etc/ssh/sshd_config.d/99-workbrain-lockdown.conf.disabled` (una lettura sola, negata dalle
   deny-rule): serve a non eseguire P-003 alla cieca.
3. 🟡 **Rimuovere `CLAUDE_CODE_DISABLE_MOUSE=1`** da `/root/.bashrc` (riga 108): workaround mai dimostrato,
   inattivo oggi ma che si attiverà da solo alla prossima shell nuova. Config → serve l'ok di Raf (regola #3).
4. 🟡 **Precondizione mancante in P-003**: prima di eseguirla va letto `99-workbrain-lockdown.conf.disabled` e
   confermato che dica `PermitRootLogin prohibit-password` e **non** `no`. La console web di hPanel entra come
   root **via publickey** (verificato in `auth.log`, chiave iniettata da Hostinger e poi cancellata):
   con `PermitRootLogin no` si perderebbe anche quella via di recupero.
5. 🟡 Conferma dei **domini** e delle regole di segregazione come codificate in `.claude/rules/domini-riservatezza.md`.

## Tech debt / rischi noti
- Sessione di bootstrap girata come root (mitigato: file assegnati a `ubuntu`; sessioni future come `ubuntu`).
- `env.prod` è un **template senza valori**: le chiavi provider vanno inserite dopo BRIEF-001.
- Schema KB e scelta motore DB sono **BOZZA**: si consolidano in F3/F4.

## Metriche (placeholder — da popolare con BRIEF-001)
- WER per provider (IT/EN/mista): —. Costo €/ora audio: —. Tempo di processing: —. Qualità diarizzazione: —.

## Timeline / fasi del piano (dettaglio in BRIEF-001)
- **F1** sync audio · **F2** STT+diarizzazione · **F3** distill+vault · **F4** DB+query MCP · **F5** digest+azioni · **F6** hardening+backup.
- Oggi: pre-F1 (harness pronto, provider da scegliere).
