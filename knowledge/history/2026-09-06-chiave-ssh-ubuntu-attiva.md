# 2026-09-06 — Chiave SSH per `ubuntu` installata e funzionante (PLAN-001 A1)

Chiude il bloccante aperto dalla sessione di bootstrap del 2026-09-05. Raf può ora collegarsi come `ubuntu`.

## Esito (verificato sul log, non riferito)
```
Accepted publickey for ubuntu from <ip-di-raf> port 1656 ssh2: ED25519 SHA256:S1HP1AGX…
```
`who` mostra la sessione `ubuntu pts/3`. Impronta della chiave installata **identica** a quella generata sul PC di Raf.

## Come si è arrivati (e i due errori di percorso, per non ripeterli)
1. Raf **aveva già** una chiave di default. Non l'abbiamo sovrascritta (avrebbe potuto autorizzare altri servizi):
   ne è stata creata una **dedicata**, `id_workbrain`. Una chiave per scopo → revocarne una non tocca le altre.
2. Primo tentativo di login: **fallito**. Il log diceva `Failed password for ubuntu`, **senza** alcuna riga
   `Failed publickey`. Lettura corretta: la chiave non era stata *rifiutata*, non era stata *usata*. E poiché
   `ubuntu` ha la password bloccata (`passwd -S` → `L`), quel tentativo non poteva riuscire per definizione.
3. Diagnosi divisa in due lati invece che per tentativi:
   - **client** — `ssh -v` mostrava `Offering public key: … id_workbrain … explicit` → il client faceva la sua parte;
   - **server** — home `drwxr-x--- ubuntu:ubuntu` (ok), nessun `AllowUsers`, `authorizedkeysfile` standard → restava
     solo l'ipotesi "il file non c'è". Era così: il comando di installazione non era mai stato eseguito.

## Trappole incontrate (utili per le prossime sessioni)
- **Le deny-rule dell'harness bloccano `/home/ubuntu/.ssh/**` anche per operazioni legittime.** L'installazione
  l'ha eseguita Raf. Non è stata aggirata né indebolita la regola. ⚠️ La granularità è però sbagliata: vieta anche
  la *scrittura* di `authorized_keys`, mentre lo scopo è impedire la *lettura* di chiavi private. Da restringere
  (rilievo aggiunto a PLAN-001). Nota: `ssh-keygen -lf` sullo stesso file **passa**, quindi la verifica dell'impronta
  resta possibile dall'agente.
- **La console web spezza i comandi lunghi.** Un one-liner con più `;` è arrivato troncato su più righe: `chown`
  senza argomento, un path eseguito come comando. Nulla di grave, ma da qui in avanti: **comandi corti, uno per volta**.
- Su Windows l'espansione di `$env:USERPROFILE` in una riga di comando ha dato percorso vuoto. Rimedio robusto:
  spostarsi nella cartella e usare il nome nudo, oppure `~/` con barre normali.

## Cosa sblocca
- **PLAN-001 Fase A2**: si può lavorare come `ubuntu`, quindi cessa la deriva di proprietà dei file (riparata due
  volte in un giorno mentre si girava come root).
- **PLAN-001 Fase C**: Docker rootless e i systemd user timer vanno installati *per* `ubuntu` — da root non erano
  né installabili né verificabili. Ora lo sono.

## Cosa NON è stato fatto (di proposito)
- **P-003 (lockdown password SSH) non eseguita.** La chiave funziona anche con la password ancora attiva: sono due
  passi separati. La precondizione resta aperta: leggere `99-workbrain-lockdown.conf.disabled` e confermare
  `PermitRootLogin prohibit-password` e **non** `no`, perché la console di recupero di hPanel entra come root via
  chiave. Non si esegue alla cieca.
- Migrazione della sessione Claude Code a `ubuntu`: `claude` è installato per `ubuntu` ma **senza credenziali**
  (`/home/ubuntu/.claude/.credentials.json` assente) → servirebbe un nuovo login e questa conversazione non
  proseguirebbe. Da fare con un handoff (P-002), prima della Fase C.

## Riferimenti
`reports/PLAN-001-consolidamento-infrastruttura.md` §D-09, Fase A · `.claude/rules/procedures.md` (P-003) ·
[[2026-09-05-HANDOFF-bootstrap]]
