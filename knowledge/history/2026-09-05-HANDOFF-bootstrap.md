# 2026-09-05 — HANDOFF: dalla sessione di bootstrap alla prossima

Handoff per la **prossima sessione**, che gira come **`ubuntu` da `~/workbrain`** (agents/MCP/hook caricati dal progetto).
La sessione di bootstrap è girata come `root` da `/root/bootstrap`: da qui in poi si lavora come `ubuntu`.

## Stato esatto in questo momento
- Harness completo e committato: git `main`, 2 commit (`52defbb` bootstrap, `43648df` test hook + review GO), 30 file tracciati.
- VPS in ordine: utente `ubuntu` (sudo NOPASSWD), UFW active (solo OpenSSH), fail2ban active (jail sshd), Node v20.20.2,
  `@plaud-ai/cli` 0.3.11, Claude Code 2.1.197. Dettaglio: `docs/05-infrastruttura-vps.md`.
- Dati fuori dal repo: `/srv/workbrain/{raw,vault,db,backups}` + `env.prod` (600, **template senza segreti**).
- Reviewer indipendente: verdetto **GO**. Hook: `tests/test_hooks.sh` → 11/11 verdi.
- Pipeline: **non implementata** (corretto — fase bootstrap).

## Verifica di ripresa (esegui all'avvio — P-001)
```bash
cd ~/workbrain
git log --oneline -3           # atteso: 43648df, 52defbb
git status                      # atteso: clean
wc -l CLAUDE.md                 # atteso: 64
CLAUDE_PROJECT_DIR=$PWD bash tests/test_hooks.sh   # atteso: 11 verdi, 0 falliti
systemctl is-active fail2ban && ufw status | head -1
/agents                         # atteso: ricercatore-sota, reviewer, curatore-kb
/mcp                            # atteso: server 'plaud'
plaud me                        # se fallisce -> login non ancora fatto (P-004)
```

## Bloccanti aperti verso Raf (i due che fermano l'avanzamento)
1. 🔴 **Chiave SSH pubblica di Raf per `ubuntu`.** Appena disponibile: installarla in `/home/ubuntu/.ssh/authorized_keys`,
   testarla da una **seconda** sessione SSH, poi eseguire **P-003** (lockdown: `PasswordAuthentication no` +
   `PermitRootLogin prohibit-password`). File già pronto: `/etc/ssh/sshd_config.d/99-workbrain-lockdown.conf.disabled`.
   Finché manca, l'accesso al VPS resta via **password di root**.
2. 🔴 **`plaud login`** (sblocca BRIEF-001). Procedura **P-004**: Raf apre `ssh -L 8199:localhost:8199 root@82.25.112.26`,
   poi si lancia `plaud login` (come `ubuntu`) e Raf completa nel browser. Verifica: `plaud me`, `plaud recent --days 30`.

## Prossimo passo concreto (dopo i bloccanti)
Eseguire `reports/BRIEF-001-analisi-soluzione.md`: **Step 0** (misure reali su 3 registrazioni IT/EN/mista × 2-3 provider STT:
costo/tempo/WER/diarizzazione/glossario), poi decidere provider STT, motore DB, embedding, runner, MCP, sync Obsidian,
sicurezza — con il piano a fasi F1–F6 e i test di accettazione già definiti nel brief. Le scelte tecniche interne al brief
approvato sono autonome; le scelte di prodotto tornano a Raf.

## Rischi / cose da non dimenticare
- Non disabilitare la password SSH **prima** di aver testato la chiave di `ubuntu` (lockout).
- Non usare contenuti reali `opentext` né PII dello studio nei test/report (hook `block-opentext` attivo; è guardia sui
  marker, non un classificatore semantico: la riservatezza in prosa resta responsabilità umana).
- `env.prod` è un template: inserire le chiavi provider solo dopo la scelta in BRIEF-001, e **mai** nel repo.
- Schema KB e motore DB sono **BOZZA**: si consolidano in F3/F4, passano da Raf.

## Riferimenti
[[2026-09-05-bootstrap-harness]] · `docs/05-infrastruttura-vps.md` · `docs/10-stato-e-backlog.md` ·
`.claude/rules/procedures.md` (P-003, P-004) · `reports/BRIEF-001-analisi-soluzione.md`
