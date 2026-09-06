#!/usr/bin/env bash
# Libreria condivisa degli scanner di WorkBrain.
#
# Un solo posto in cui vive la definizione di "cosa non deve entrare nel repo". La usano:
#   - gli hook PreToolUse  -> feedback immediato mentre si scrive (comodo, ma aggirabile: la shell e' troppo espressiva)
#   - l'hook git pre-commit -> il gate VERO, perche' il commit e' un passaggio obbligato (PLAN-001 D-04)
# Duplicare i pattern in due posti significherebbe vederli divergere. Qui stanno insieme.
#
# NOTA sui marker composti a runtime (WB_OT, WB_SENTINEL): non e' un vezzo.
# Se questo file contenesse i marker in forma letterale, gli scanner bloccherebbero se stessi e le
# proprie fixture di test non appena la copertura si estende a tutto il repo. L'alternativa sarebbe
# una lista di file esentati dal controllo, cioe' un punto cieco permanente proprio nella guardia.
# Comporli a runtime toglie il problema alla radice senza esentare nulla.

WB_OT="open""text"
WB_SENTINEL="OPEN""TEXT-CONFIDENTIAL"

# wb_scan_secrets <payload> [file_path]
#   0 = pulito · 1 = trovato qualcosa (il motivo va su stderr)
# Garanzia, non giudizio: un valore di chiave reale, o env.prod, non deve finire in un file tracciabile.
wb_scan_secrets() {
  local payload="${1-}" fp="${2-}"

  if [ -n "$fp" ] && [ "$(basename "$fp")" = "env.prod" ]; then
    printf 'env.prod non deve stare nel repo (deve vivere in /srv/workbrain, permessi 600).\n' >&2
    return 1
  fi

  # Valori VERI. I placeholder vuoti (CHIAVE=) passano di proposito: servono nei template.
  if printf '%s' "$payload" | grep -qE \
    '((API|SECRET|ACCESS|PRIVATE|AUTH)_?(KEY|TOKEN|SECRET)|PASSWORD)[[:space:]]*[:=][[:space:]]*[^[:space:]"'"'"']+|sk-[A-Za-z0-9]{16,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
    printf 'sembra un segreto con un valore reale.\n' >&2
    printf 'I segreti vanno in /srv/workbrain/env.prod (600) o in ~/.plaud/, mai in git.\n' >&2
    return 1
  fi

  return 0
}

# wb_scan_domain <payload> [mode]
#   0 = pulito · 1 = trovato un marker di dominio riservato
# Blocca i MARKER machine-readable (assegnazione di dominio nel frontmatter, sentinella), non la prosa:
# citare il nome del dominio in un documento e' legittimo, e' un metadato. Vedi .claude/rules/domini-riservatezza.md
#
# mode="loose": toglie l'ancora di inizio riga. Serve SOLO per esaminare una riga di comando, dove il
# marker sta in mezzo (`echo 'domain: ...' >> f`) e non a inizio riga. Non va usato sul contenuto dei
# file: li' l'ancora e' cio' che distingue un frontmatter vero da una frase che ne parla.
wb_scan_domain() {
  local payload="${1-}" mode="${2-strict}" anchor='^[[:space:]]*'
  [ "$mode" = "loose" ] && anchor=''

  if printf '%s' "$payload" | grep -qEi "${anchor}domain:[[:space:]]*[\"']?${WB_OT}|${WB_SENTINEL}"; then
    printf 'contenuto o marker del dominio riservato del datore di lavoro.\n' >&2
    printf 'Segregazione domini inviolabile: quelle note vivono solo in /srv/workbrain/vault, fuori dal repo.\n' >&2
    printf 'Se stai solo citando il NOME del dominio in prosa, non usare un frontmatter che lo assegna.\n' >&2
    return 1
  fi

  return 0
}
