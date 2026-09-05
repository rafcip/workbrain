# 2026-09-05 — Copia testo dalla console web Hostinger: mouse tracking di Claude Code

> ⚠️ **RETTIFICA (stessa giornata, sessione serale)** — la causa qui sotto è **sbagliata**, o quantomeno
> non dimostrata. Il fix `CLAUDE_CODE_DISABLE_MOUSE=1` **non è mai entrato in funzione**: la variabile è
> stata scritta in `.bashrc` dopo l'avvio del processo Claude Code, quindi quel processo non l'ha mai avuta
> (verificato su `/proc/<pid>/environ`). La causa reale era l'impostazione `"tui": "fullscreen"` scelta al
> primo avvio; risolta con `/tui default`. Storia completa: [[2026-09-05-login-plaud-e-fix-copia-tui]].
> Lezione: un fix che richiede un riavvio non è verificato finché il riavvio non è avvenuto — e "da
> confermare da Raf" in fondo a una history è un esito mancante, non un esito.

## Sintomo
Raf, collegato dalla **console web di Hostinger hPanel**, non riesce a copiare testo: selezione col mouse +
tasto destro non danno il menu "Copia" del browser. Compare invece il messaggio
`copied N chars to tmux buffer · paste with prefix + ]`. Su un altro VPS la stessa operazione funziona.

## Causa radice (verificata, non ipotizzata)
**Non è tmux.** Diagnostica: `tmux list-sessions -F '#{mouse}'` → `0`, `show -g mouse` e `show -s mouse` → off,
una sola sessione (`SysAdmin`), un solo client. Il mouse lo cattura la **TUI di Claude Code**, che attiva il
mouse tracking: il terminale del browser le inoltra gli eventi invece di lasciar selezionare la pagina.
Prova sul binario (`bin/claude.exe`): stringhe `mouseTracking` e la funzione di scelta strategia di copia —
su Linux ritorna `native` **solo se** trova un tool di clipboard installato, altrimenti dentro tmux ripiega su
`"tmux-buffer"`. Sull'altro VPS funziona perché lì la shell è nuda: nessuna app che intercetta il mouse.

## Fix applicato
`export CLAUDE_CODE_DISABLE_MOUSE=1` in `/root/.bashrc` (riga 108), con commento esplicativo.
Backup: `/root/.bashrc.bak-pre-disable-mouse-2026-09-05` (P-005). Richiede riavvio di Claude Code
(`claude --continue` per riprendere la conversazione). Variante meno invasiva se si vuole tenere lo scroll:
`CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1`.

## Verifica (esito reale)
- `grep CLAUDE_CODE_DISABLE_MOUSE /root/.bashrc` → presente.
- `bash -ic 'echo $CLAUDE_CODE_DISABLE_MOUSE'` → `1`.
- Effetto sulla copia col tasto destro: **da confermare da Raf dopo il riavvio di Claude Code.**

## Tentativi scartati lungo la strada
- `set -g mouse on` in tmux (richiesto da Raf, poi **rimesso off**): peggiora il problema, tmux ruba il mouse
  al browser. `~/.tmux.conf` ora documenta perché deve restare off.
- `Shift+drag` (bypass standard del mouse tracking): **provato da Raf, non funziona** in questa console web.

## Lezione
La console web di hPanel è un canale di lavoro povero: clipboard inaffidabile, niente tunnel SSH (quindi
**P-004 login Plaud non è eseguibile da qui**). Sbloccare la chiave SSH per l'utente `ubuntu` non è solo
hardening: è il prerequisito per lavorare in modo decente. Vedi `docs/10-stato-e-backlog.md`.

## Riferimenti
`docs/05-infrastruttura-vps.md` · `.claude/rules/procedures.md` (P-004, P-005) · [[2026-09-05-HANDOFF-bootstrap]]
