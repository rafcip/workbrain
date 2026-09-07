#!/usr/bin/env bash
# Installa le unit systemd UTENTE di WorkBrain. PLAN-001 D-02 / Fase C.
#
# Le unit vivono nel repo (systemd/user/) e in ~/.config/systemd/user/ ci vanno dei SYMLINK,
# non delle copie. Con le copie il file versionato e quello attivo divergono in silenzio, e
# ci si accorge della differenza il giorno in cui qualcosa non parte. Un test lo verifica.
#
# Idempotente: si puo' rilanciare. Non abilita niente da solo — quali timer armare e' una
# decisione operativa, non un effetto collaterale di un'installazione.
#
# Uso:  bash scripts/install-units.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERRORE: queste sono unit UTENTE. Girano come 'ubuntu', non come root (PAT-04)." >&2
  exit 1
fi

mkdir -p "$DEST"
for src in "$REPO"/systemd/user/*; do
  name="$(basename "$src")"
  ln -sfn "$src" "$DEST/$name"
  echo "  -> $DEST/$name"
done

systemctl --user daemon-reload
echo
echo "Unit installate. Per armarle (esempi):"
echo "  systemctl --user enable --now workbrain-backup.timer"
echo "  systemctl --user enable --now workbrain-docker-prune.timer"
echo "  systemctl --user enable --now 'workbrain-step@index.timer'"
echo
echo "Perche' partano al boot senza login serve il linger, una volta sola:"
echo "  sudo loginctl enable-linger $USER"
