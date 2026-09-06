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
- `reports/PLAN-001-consolidamento-infrastruttura.md` — **BOZZA in attesa di ok**. Decisioni D-01…D-12 prese come
  owner, con alternativa scartata e condizione di cambio idea. Fasi A (sbloccare) → B (guardie vere) → C (fondamenta
  container) → D (piattaforma). **La Fase C non è eseguibile finché si gira come root.**
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
2. 🔴 **Chiave SSH pubblica** per l'utente `ubuntu` — **promossa a bloccante il 2026-09-06**. Non blocca la pipeline
   (il tunnel funziona con la password di root) ma **blocca PLAN-001 Fase C**: `ubuntu` ha la password bloccata
   (`passwd -S ubuntu` → `L`), quindi ogni sessione gira come root, e Docker rootless *per `ubuntu`* + i systemd
   user timer non sono installabili né provabili da root. È anche la causa della deriva di proprietà dei file.
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
