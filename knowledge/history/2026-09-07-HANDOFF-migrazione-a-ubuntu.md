# 2026-09-07 — HANDOFF: dalla sessione root alla sessione `ubuntu` (verso la Fase C)

Handoff per la **prossima sessione**, che gira come **`ubuntu` da `~/workbrain`**.
Le sessioni 2026-09-05 → 2026-09-07 sono girate come **root** dalla console web di hPanel: da qui in poi si lavora
come `ubuntu` via SSH con chiave, ed è una precondizione, non una preferenza (vedi §Perché la migrazione).

---

## 1. Stato esatto in questo momento

### Repo
- git `main`, **13 commit**, 45 file tracciati. **Remote privato attivo**: `git@github.com:rafcip/workbrain.git`,
  locale e remoto allineati. Working tree pulito, proprietà interamente `ubuntu:ubuntu`.
- **Suite: 23 verdi, 0 falliti** (`bash tests/run.sh`).

### Piano in corso
`reports/PLAN-001-consolidamento-infrastruttura.md`, **approvato** da Raf ("dopo fase C ci fermiamo").
- **Fase A** ✅ tranne **A2** (questa migrazione).
- **Fase B** ✅ completa.
- **Fase C** ⏭️ **è il prossimo lavoro**. Non era eseguibile da root.
- **Fase D**: ci si ferma prima. Vedi §5.

### Infrastruttura
- **SSH in lockdown (P-003 eseguita)**: solo chiave. `passwordauthentication no`,
  `permitrootlogin without-password`. Console hPanel ancora valida (entra come root **via chiave iniettata**).
- Swap 4 G attiva, `vm.swappiness=10`, persistente in `fstab` (provata con `swapoff`/`swapon -a`).
- `loginctl` **linger attivo** per `ubuntu`; gestore systemd utente `active/running`.
- **Backup restic** operativo: repository in `/srv/workbrain/backups/restic`, timer utente
  `workbrain-backup.timer` (giornaliero, `Persistent=true`), **ripristino già verificato**.
- Docker **rootful** attivo ma inutilizzato: va sostituito da rootless in Fase C.
- Plaud: **loggato**, token in `/home/ubuntu/.plaud/`. MCP pinnato a `@plaud-ai/mcp@0.3.10`.
- Claude Code per `ubuntu`: **2.1.263**, allineata a quella di root.

### Permessi dell'harness
Riscritti su decisione di Raf: **piena autonomia amministrativa**. Resta vietata la **lettura** dei segreti
(`env.prod`, `restic-pass`, deploy key, token Plaud, chiavi private, `/etc/shadow`) e le operazioni distruttive.

---

## 2. Perché la migrazione a `ubuntu` è una precondizione, non un'igiene

1. **Fase C va installata *per* `ubuntu`.** Docker rootless gira nello user namespace di quell'utente e i systemd
   **user** timer sono i suoi. Da root non sono né installabili né verificabili davvero.
2. **La proprietà dei file derivava a ogni modifica.** Lavorando come root, `chown -R` è stato necessario più volte
   in un giorno. Come `ubuntu` il problema sparisce alla radice.
3. È PAT-04 (mai come root), che è una lezione già pagata in Legal Agency.

---

## 3. Verifica di ripresa (esegui all'avvio — P-001)

```bash
whoami                                   # atteso: ubuntu   <-- se dice root, fermati: la migrazione non e' avvenuta
cd ~/workbrain
git log --oneline -3                     # atteso: 13 commit, HEAD allineato a origin/main
git status                               # atteso: clean
git ls-remote origin main                # atteso: stesso hash del locale
bash tests/run.sh                        # atteso: 23 verdi, 0 falliti
git config core.hooksPath                # atteso: .githooks   <-- se vuoto, il gate sul commit NON e' attivo
plaud me                                 # atteso: identita' di Raf
loginctl show-user ubuntu | grep Linger  # atteso: Linger=yes
systemctl --user list-timers             # atteso: workbrain-backup.timer
swapon --show                            # atteso: /swapfile 4G
sshd -T | grep -iE 'passwordauth|permitroot'   # atteso: no / without-password
```

⚠️ **`core.hooksPath` è configurazione locale, non versionata.** Su un clone nuovo va reimpostata
(`git config core.hooksPath .githooks`), altrimenti il gate sul commit non esiste. Un test lo verifica.

---

## 4. Prossimo passo concreto: PLAN-001 Fase C

Obiettivo: fondamenta container per la piattaforma. Dettaglio e motivazioni in PLAN-001 §D-01, D-02, D-03.

| # | Azione | Test di uscita |
|---|---|---|
| C1 | `apt install uidmap`; `dockerd-rootless-setuptool.sh install` come `ubuntu`; gestire la restrizione AppArmor di 24.04 | `docker info` come `ubuntu` mostra rootless; `docker run hello-world` OK |
| C2 | Disabilitare `docker.service` e `containerd.service` rootful + i cron `docker-*-prune` | i servizi `disabled`; il rootless continua a funzionare |
| C3 | `Dockerfile` base + `compose.yaml` scheletro, immagini **pinnate per digest**, `USER` non-root | build riproducibile; il container non gira come root |
| C4 | Un servizio+timer utente d'esempio che lancia un container one-shot | il timer scatta, `journalctl --user` lo registra, sopravvive a reboot |

**Fattibilità già verificata** (non riverificare da zero):
- `/etc/subuid` e `/etc/subgid`: `ubuntu:100000:65536` ✅
- `kernel.unprivileged_userns_clone` = 1 ✅ · `dockerd-rootless-setuptool.sh` presente ✅
- Docker 29.8.0, Compose v5.5.1 ✅ · pacchetto `uidmap` **assente** ❌ → da installare
- `kernel.apparmor_restrict_unprivileged_userns` = 1 ⚠️ → **è il punto di attrito probabile**

**Se AppArmor diventa una battaglia**: PLAN-001 D-01 prevede già il fallback — Docker rootful con `ubuntu`
**fuori** dal gruppo `docker` e comandi espliciti via `sudo`. **Non** aggiungere `ubuntu` al gruppo `docker`:
è il workaround comodo che la regola madre vieta (equivale a dare root).

**Nota di fiducia**: il timer del backup (Fase B4) è già un servizio utente systemd che gira e funziona
(`Result=success`). Il rischio principale della Fase C — "i timer utente funzionano su questa macchina?" — è
quindi già sciolto.

---

## 5. Dopo la Fase C **ci si ferma** (decisione di Raf)

Per la piattaforma, Raf ha chiesto **analisi e piano nuovi, fatti da noi**:
> *"Per pianificazione e sviluppo della piattaforma voglio che fai tu analisi e piano, non mi fido del brief."*

⚠️ **`reports/BRIEF-001-analisi-soluzione.md` NON è più il piano di riferimento.** È stato declassato a input da
riesaminare: restano validi i **fatti misurati** (es. gli errori di Plaud sui termini tecnici), **non** le conclusioni
né i default (la scelta SQLite era motivata da utente singolo — vedi sotto).

Vincoli da tenere nel piano nuovo, già decisi:
- [[2026-09-06-DECISIONE-prodotto-futuro]] — fondamenta da prodotto ma **non si costruisce un prodotto**: si pagano
  solo le "porte a senso unico" (`owner` nel modello dati, tassonomia come configurazione, registro accessi,
  vincoli legali come criterio **eliminatorio**, segreti con ambito).
- [[2026-09-06-DECISIONE-perimetro-opentext]] — il dominio riservato resta nel perimetro, rischio accettato consapevolmente.
- Le tre decisioni del 2026-09-05 (bilingue senza traduzione, no subscription Plaud, STT via API con diarizzazione).

**Manca ancora il materiale di prova**: serve 1 registrazione IT multi-speaker con termini tecnici e 1 mista IT/EN.
Le 5 esistenti non bastano (una sola IT da 1m06s, tre demo EN). È un'azione di Raf.

---

## 6. Rischi e cose da non dimenticare

- **Non aggiungere `ubuntu` al gruppo `docker`.** Equivale a dare root e annulla il senso di D-01.
- **`core.hooksPath`** non è versionato: senza, il gate sul commit non esiste (vedi §3).
- **Le guardie contengono marker composti a runtime** (`"open""text"`): è deliberato, serve a non far bloccare
  agli scanner la propria suite di test. Non "semplificare" scrivendoli in chiaro.
- **Il backup è locale**: protegge da cancellazioni e corruzione, **non** dalla perdita del VPS. Portarlo fuori
  richiede una destinazione e una decisione di Raf.
- **L'email di Raf è autore di ogni commit**: su repo privato va bene, ma se diventasse pubblico resterebbe nella
  storia. Opzione `@users.noreply.github.com` proposta, **non decisa**.
- La console web di hPanel spezza i comandi lunghi su più righe: **comandi corti, uno per volta**.
- Rilievi 🟡 di AUDIT-001 ancora aperti: Node installato due volte (versioni ora allineate), Monarx documentato e
  accettato, cron `docker-*-prune` da rimuovere con C2.

---

## 7. Riferimenti
`reports/PLAN-001-consolidamento-infrastruttura.md` (il piano) · `reports/AUDIT-001-infrastruttura-e-harness.md`
(i rilievi) · [[2026-09-06-fase-a-b-guardie-vere-e-backup]] · [[2026-09-07-remote-github-e-lockdown-ssh]] ·
[[2026-09-06-chiave-ssh-ubuntu-attiva]] · `.claude/rules/procedures.md` (P-001…P-006)
