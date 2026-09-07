# 2026-09-07 — PLAN-001 Fase C: fondamenta container (Docker rootless + timer utente)

Prima sessione girata come **`ubuntu`** (A2 chiusa da sé: la migrazione era la precondizione della Fase C).
Fase C completata su C1-C4. Piano: `reports/PLAN-001-consolidamento-infrastruttura.md` (D-01, D-02, D-03).

## Verifica di ripresa (P-001)
Gli 11 controlli del §3 di [[2026-09-07-HANDOFF-migrazione-a-ubuntu]] sono tornati tutti. Unico scostamento:
**14 commit invece di 13** — l'handoff dichiarava il conteggio *prima* di committare sé stesso. Locale e remoto
sullo stesso hash `ef1ec9d`, che è ciò che il controllo voleva davvero accertare.

## C1 — Docker rootless per `ubuntu`
- Installato `uidmap` (unico requisito mancante).
- **L'attrito previsto non c'è stato**: Ubuntu 24.04 spedisce già `/etc/apparmor.d/rootlesskit` con `userns`,
  quindi `kernel.apparmor_restrict_unprivileged_userns=1` non blocca nulla. `dockerd-rootless-setuptool.sh check`
  → *Requirements are satisfied*. Il fallback previsto da D-01 (rootful + `sudo`) **non è servito**.
- `dockerd` e `containerd` girano come `ubuntu`; `docker info` → `Security Options: rootless`;
  root dir in `~/.local/share/docker`; storage driver `overlayfs` nativo (niente `fuse-overlayfs`).
- Prova di merito: dentro un container `/proc/self/uid_map` dice `0 → 1000 (1)`, cioè root nel container
  **è** `ubuntu` sull'host.

## C2 — Spento il daemon rootful
- Prima di spegnere ho guardato cosa conteneva: **0 container, 0 immagini, 0 volumi**, solo le tre reti di default.
  Non si è perso niente. (Regola #2: verificato, non assunto.)
- `docker.socket`, `docker.service`, `containerd.service` → `disabled` + `inactive`. Rimosso anche il file di
  socket rimasto orfano in `/var/run/docker.sock`: nessun listener, root stesso non riusciva a connettersi.
- I due cron di sistema (`/etc/cron.d/docker-builder-prune`, `docker-image-prune`) rimossi — giravano come root
  contro un daemon che non esiste più. Copia di sicurezza in `/srv/workbrain/backups/etc-cron.d/` (P-005).
- Sostituiti da `workbrain-docker-prune.timer` (utente, giornaliero, `Persistent=true`) →
  `scripts/docker-prune.sh`. Differenza deliberata: la cache del builder si pota ogni giorno ma solo oltre i
  7 giorni, invece che azzerarla ogni sabato.
- `ubuntu` **non** è nel gruppo `docker` (verificato con `id`): il confine di D-01 regge.

## Difetto trovato e corretto: `RuntimeMaxSec` con `Type=oneshot`
systemd ha avvisato che **`RuntimeMaxSec=` viene ignorato con `Type=oneshot`**: il limite giusto è
`TimeoutStartSec=`. Lo stesso errore era nel `workbrain-backup.service` scritto in Fase B, con tanto di commento
"un backup appeso non deve restare in esecuzione all'infinito": il guard-rail era **dichiarato ma inesistente**
(`RuntimeMaxUSec=infinity`). Corretti entrambi; ora `TimeoutStartUSec=1h` sul backup e `10min` sul prune.
Un test lo impedisce da qui in poi. Backup del file originale in `/srv/workbrain/backups/`.

## C3 — Immagine base e confini degli step
- `Dockerfile`: base pinnata **per digest** (`python@sha256:ed86c822…`, = `python:3.13-slim-bookworm`, 3.13.15),
  `USER 10001:0`, nessun entrypoint applicativo. `.dockerignore` tiene segreti e storia fuori dal contesto.
- `compose.yaml`: la tabella di D-03 diventa configurazione applicata — `read_only: true`, `cap_drop: [ALL]`,
  `no-new-privileges`, `tmpfs` per `/tmp`, nessun `ports:`, `network_mode: none` per `index`.
- **Il punto non ovvio: uid/gid nei bind mount del rootless.** La mappatura è `0 → 1000` e `N>0 → 100000+N-1`.
  Un container con uid *e* gid 10001 diventa `110000:110000` sull'host e **non può scrivere** in `/srv/workbrain`
  (provato: `Permission denied`). Tre strade valutate, non impilate:
  1. `--mount …,idmap` → **l'opzione non esiste** in questa build di Docker (provato, errore del CLI). Scartata.
  2. `chown` alle uid mappate + ACL per ridare accesso a `ubuntu` → `setfacl` non è nemmeno installato, e avrebbe
     lasciato il vault di proprietà di `110000`, illeggibile senza ACL da chi lo apre con Obsidian. Scartata.
  3. **uid 10001 + gid 0** — nel rootless il gid 0 mappa sul *gruppo* `ubuntu`. Il processo resta non-root dentro
     il namespace e scrive lo stesso. Scelta. Richiede le dir dati `2770` (setgid + scrittura di gruppo) e
     `umask 002` nel container (`docker/entrypoint.sh`), altrimenti i file nascono `0644` e `ubuntu` può leggerli
     ma non modificarli più.
  Verificato dai due lati: il container scrive, e `ubuntu` rilegge **e riscrive** ciò che il container ha prodotto.
- Confini provati uno per uno (esito reale, non atteso): `sync` scrive in `raw` ✅ · `distill` **non** scrive in
  `raw` ✅ · `distill` scrive in `vault` ✅ · `distill` non vede `db` ✅ · `index` **non** scrive in `vault` ✅ ·
  `index` scrive in `db` ✅ · `query` **non** scrive in `db` ✅ · `index` non risolve DNS mentre `distill` sì ✅.
- I `command` degli step sono **segnaposto**: stampano il proprio perimetro ed escono. Il codice vero è Fase D.

## C4 — Servizio e timer utente che lanciano un container one-shot
- `workbrain-step@.service` / `.timer`: unit **template**, una istanza per step (`workbrain-step@index`).
  `Requisite=docker.service` (se il daemon non c'è lo step non parte, invece di fallire a metà),
  `DOCKER_HOST=unix://%t/docker.sock`, `docker compose run --rm -T`.
- Prova reale con drop-in temporaneo a 30 s: il timer è **scattato due volte da solo** (20:47:49 e 20:48:30),
  con l'output del container nel journal. Drop-in rimosso, cadenza riportata a giornaliera.
- `workbrain-step@index.timer` resta armato: finché non c'è la pipeline fa da **canary del runtime** — una riga
  al giorno che dimostra che rootless + timer utente funzionano ancora dopo aggiornamenti e riavvii.

## Unit portate nel repo
Vivevano solo in `~/.config/systemd/user/`: fuori dal versionamento **e** fuori dal backup restic (che copre
`raw`, `vault`, `db`). Ora stanno in `systemd/user/` e le unit attive sono **symlink** al repo — con le copie i
due file divergono in silenzio. `scripts/install-units.sh` rifà l'installazione da zero, ed è idempotente.

## Test
Nuova suite `tests/test_container.sh`: **83 test** sugli invarianti di Fase C, letti dalla configurazione
**effettiva** (`docker compose config --format json` servizio per servizio, `systemctl --user show`, `stat`),
non dalle righe dei file. Totale repo: **106 verdi, 0 falliti** (23 hook + 83 container).
Provata per mutazione, comprese le mutazioni **additive**: un servizio ostile aggiunto a `compose.yaml`
(`privileged: true`, `user: "0:0"`, `read_only: false`) fa fallire **9 test**.

## Review indipendente: NO-GO, quattro bloccanti, tutti chiusi prima del commit
Il reviewer ha confermato la sostanza (rootless, rootful spento, confini dei mount, timer scattato, PAT-07
corretto sul valore effettivo) e ha bocciato quattro cose. Erano tutte vere — verificate da me una per una prima
di toccare qualsiasi cosa — e sono state corrette, non declassate.

**B1 — il prune notturno si sarebbe mangiato l'immagine del progetto.** `docker image prune -a` cancella ogni
immagine *taggata ma non referenziata*; con tutti gli step `--rm`, fuori da un'esecuzione nessuna immagine è
referenziata. Entro 48 h `workbrain-base:dev` sarebbe sparita e il canary si sarebbe messo a **ricostruire
l'immagine ogni notte** con pull anonimo da Docker Hub: avrebbe smesso di misurare rootless+timer e cominciato a
misurare la raggiungibilità di un registry. Fix: `LABEL com.workbrain.keep="true"` nel Dockerfile +
`--filter "label!=…"` nel prune, con `pull_policy: never` in compose come seconda linea.
Prova: `docker image prune -af --filter until=0h` ha cancellato tutto **tranne** `workbrain-base:dev`.

**B2 — `query` aveva Internet piena** dove la tabella di D-03 dice "solo loopback". Era l'unico step che monta
`vault/` **e** `db/` insieme, cioè vede tutti i domini, PII dello studio comprese: il buco con le conseguenze
peggiori dell'intera matrice. Fix: `network_mode: none`. Prova: DNS negato per `query`, ancora risolto per
`distill`. La sintesi che avevo scritto ("matrice provata step per step") era **più larga dei fatti**: avevo
provato i mount di tutti gli step ma la rete solo di `index`. Corretta anche quella (regola #9).

**B3 — i test dei confini erano `grep` sui file, cioè PAT-07 in azione** — scritto da me nella stessa sessione in
cui registravo PAT-07. Aggiungendo un servizio ostile a `compose.yaml` la suite restava verde, perché le stringhe
cercate esistevano comunque nell'anchor condiviso. Riscritti sui **valori effettivi per servizio**; ora includono
anche una matrice attesa esplicita, così un servizio *non previsto* fallisce invece di passare per omissione.

**B4 — il gate non eseguiva mai quei test.** `run-tests.sh` copriva solo `scripts/`, `tests/`, `.claude/hooks/`:
la Fase C ha aggiunto `Dockerfile`, `compose.yaml`, `docker/`, `systemd/` senza estendere l'elenco. E il
`pre-commit` eseguiva solo gli scanner, mai la suite. Quindi si poteva aggiungere `privileged: true` e committare
con le invarianti mai eseguite — di nuovo la famiglia di R-02. Fix: scope esteso ai nuovi path, **e** il
`pre-commit` ora esegue `tests/run.sh` ed è fail-closed (suite rossa o assente → commit rifiutato).
Provato su un repo finto: suite rossa → rifiuta, verde → passa, assente → rifiuta.

**M7 (dal reviewer) — corsa al boot.** `Requisite=docker.service` avrebbe fatto **fallire** un timer in recupero
(`Persistent=true`) scattato prima che il daemon utente fosse su, e `After=` ordina ma non attiva. Passato a
`Requires=`. È uno dei modi concreti in cui il reboot mai provato si sarebbe rotto.
**M8** — tolto `COPY scripts/` dal Dockerfile: le utilità operative dell'host non hanno da stare negli step.

## Aperto (rilievi 🟡 del reviewer, non chiusi qui)
- **`~/.config/systemd/user/docker.service` non è versionato**: è l'unica delle 7 unit rimasta un file normale,
  ed è quella da cui dipendono le altre. È rigenerata da `dockerd-rootless-setuptool.sh install`, quindi è
  ricostruibile, ma la frase "unit portate nel repo" vale per 6 su 7 e va letta così.
- **`umask 002` non basta a garantire che il vault resti scrivibile da `ubuntu`**: codice che fissa i permessi
  in modo esplicito (`mkstemp` → 0600, writer atomici, `os.chmod`) produrrà file di proprietà host `110000` che
  `ubuntu` **non può modificare né chown-are**. È un vincolo da tenere in Fase D, non da scoprire lì.
- **`2770` + setgid sulle dir dati è il perno di tutta la strada scelta in C3**: ora c'è un test che lo controlla,
  ma se una dir viene ricreata a mano (`mkdir` → 0755) i container smettono di scrivere.
- **Le unit sono symlink al working tree**: un `git checkout`/`stash`/cambio di branch cambia la configurazione
  systemd viva senza `daemon-reload`. Il drift si sposta, non sparisce.
- **`block-bash-writes.sh` ha falsi positivi sui comandi di sola lettura** che contengono un pattern-segreto e una
  redirezione `2>/dev/null`: ostacola proprio i comandi di audit. Pre-esistente, non di Fase C.
- **Sopravvivenza a un reboot vero**: non provata. C'è l'evidenza strutturale (`Linger=yes`, `docker.service` in
  `default.target.wants`, i tre timer in `timers.target.wants`, tutti `enabled`), che è esattamente ciò che
  systemd legge all'avvio — ma un riavvio del VPS interrompe la sessione e va deciso da Raf.
- Rilievi 🟡 di AUDIT-001 ancora aperti: `CLAUDE_CODE_DISABLE_MOUSE=1` in `/root/.bashrc`, email nei commit,
  Node installato due volte. Il backup resta **locale**.

## Riferimenti
`reports/PLAN-001-consolidamento-infrastruttura.md` · [[2026-09-07-HANDOFF-migrazione-a-ubuntu]] ·
[[2026-09-06-fase-a-b-guardie-vere-e-backup]] · [[2026-09-07-remote-github-e-lockdown-ssh]]
