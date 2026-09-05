# 2026-09-05 — Bootstrap dell'harness WorkBrain

## Contesto
Prima sessione. VPS Hostinger appena creato (`srv1958735`, Ubuntu 24.04.4). Obiettivo (BRIEF-000): mettere in ordine il
VPS come SysAdmin e costruire l'harness Claude Code di WorkBrain, senza implementare pipeline.

## Fatto (con esito reale verificato)
### Setup VPS (§0)
- Creato utente `ubuntu` con sudo senza password (`/etc/sudoers.d/90-ubuntu`, `visudo -c` OK).
- `apt upgrade`: 0 pacchetti da aggiornare (già allineato). Installati: `jq`, `unzip`, `fail2ban`, `python3-venv`, `pip`.
- **UFW** attivo: deny incoming / allow outgoing / solo OpenSSH aperto. **fail2ban** attivo con jail `sshd` (verificato `active`).
- Hardening SSH sicuro applicato (`99-workbrain-hardening.conf`: MaxAuthTries 3, LoginGraceTime 20, X11 off, keepalive).
- Per `ubuntu`: nvm 0.40.1 → Node v20.20.2; installati globalmente `@plaud-ai/cli` 0.3.11 e `@anthropic-ai/claude-code` 2.1.197.
- Cartelle dati fuori dal repo: `/srv/workbrain/{raw,vault,db,backups}` (owner `ubuntu`, 750) + `env.prod` (600, template senza segreti).

### Harness (§4)
- Repo in `/home/ubuntu/workbrain`: `CLAUDE.md` (64 righe, ≤100), `.claude/{rules,agents,skills,hooks}`, `docs/`,
  `knowledge/{history,platform}`, `reports/`, `scripts/`, `tests/`, `.mcp.json` (Plaud MCP), `.gitignore`.
- Rules: continuity, procedures (P-001..P-006), bug-registry (PAT-01..06), domini-riservatezza, schema-kb.
- Agents: ricercatore-sota, reviewer, curatore-kb. Skill: sync-plaud (pattern SOTA con counter-example reale).
- Hook: `block-secrets`, `block-opentext`, `run-tests` — **testati con 9 input di prova, tutti con l'esito atteso**.
- Docs: 00-lineage-legal-agency, 02-architettura-target (BOZZA), 05-infrastruttura-vps, 10-stato-e-backlog, README.
- Report: BRIEF-001 (Step 0 misure reali → scelte provider/storage/embedding/runner → fasi F1-F6 con test di accettazione).

## Deviazione dal brief (motivata)
Il brief assumeva accesso root **via chiave SSH**. **Verificato il contrario**: `/root/.ssh/authorized_keys` vuoto,
`PasswordAuthentication yes` forzato da cloud-init. Disabilitare la password ora = **lockout permanente**. Perciò il passo
"password SSH disabilitata" **NON è stato eseguito**: è stato preparato ma lasciato `.disabled` (procedura P-003), da
attivare dopo aver installato e testato la chiave pubblica di Raf. Segnalato come bloccante.
Inoltre la sessione di bootstrap è girata **come root** (non era possibile cambiare utente a processo avviato): i file sono
stati creati e poi `chown -R ubuntu`. Le sessioni future vanno aperte come `ubuntu`.

## Verifiche
- `wc -l CLAUDE.md` = 64. Hook: 9/9 test con esito atteso (block su segreti/env.prod/marker opentext; pass su prosa e placeholder).
- UFW `active`, fail2ban `active`, Node/CLI installati (versioni sopra).

## Bloccanti aperti verso Raf
1. Chiave SSH pubblica per `ubuntu` → poi P-003 (lockdown password).
2. `plaud login` via tunnel (P-004) → sblocca BRIEF-001.

## Prossimo passo
Eseguire `reports/BRIEF-001-analisi-soluzione.md` dopo `plaud login`. Nessuna pipeline implementata (corretto: fase bootstrap).
