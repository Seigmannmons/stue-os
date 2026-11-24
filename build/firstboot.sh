#!/usr/bin/env bash
# StueOS — First-boot setup
# Kjøres én gang etter første oppstart (via systemd oneshot eller manuelt).
# Håndterer Flatpak-installasjoner og brukerspesifikt oppsett.

set -euo pipefail

LOG="/var/log/stueos-firstboot.log"
exec > >(tee -a "$LOG") 2>&1

echo "[$(date)] StueOS first-boot starter..."

# ── Flatpak-remote ────────────────────────────────────────────────────
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo

# ── Installer Flatpak-apper ───────────────────────────────────────────
FLATPAKS=(
    tv.kodi.Kodi
    com.valvesoftware.Steam
    org.gnome.Platform//45
)

for app in "${FLATPAKS[@]}"; do
    if ! flatpak info "$app" &>/dev/null; then
        echo "Installerer Flatpak: $app"
        flatpak install -y flathub "$app" || echo "ADVARSEL: $app feilet"
    else
        echo "Allerede installert: $app"
    fi
done

# ── KDE-fargetema ─────────────────────────────────────────────────────
KDE_COLORS_DIR="$HOME/.local/share/color-schemes"
mkdir -p "$KDE_COLORS_DIR"
cp /usr/share/stueos/themes/stueos-kde.colors "$KDE_COLORS_DIR/StueOSFusion.colors"
echo "KDE-fargetema kopiert"

# ── Kodi Arctic Zephyr-fargetema ──────────────────────────────────────
# Skinn installeres manuelt via Kodi UI første gang.
# StueOS-farger kopieres hit så de er klare:
KODI_SKIN_COLORS="$HOME/.var/app/tv.kodi.Kodi/data/addons/skin.arctic.zephyr.2.reloaded/720p/includes/colors"
mkdir -p "$KODI_SKIN_COLORS"
cp /usr/share/stueos/themes/kodi/colors.xml "$KODI_SKIN_COLORS/stueos-fusion.xml" 2>/dev/null || \
    echo "Kodi-skinn ikke installert ennå — kopier colors.xml manuelt etter skinninstallasjon"

# ── Steam Big Picture CSS ─────────────────────────────────────────────
STEAM_SKINS="$HOME/.local/share/Steam/skins/stueos-fusion"
mkdir -p "$STEAM_SKINS"
cp /usr/share/stueos/themes/steam-bigpicture.css "$STEAM_SKINS/stueos-fusion.css"
cat > "$STEAM_SKINS/skin.json" <<'JSON'
{
  "name": "StueOS Fusion",
  "author": "StueOS",
  "Steam-WebKit": "stueos-fusion.css"
}
JSON
echo "Steam-skinn kopiert til $STEAM_SKINS"

# ── Marker som ferdig ─────────────────────────────────────────────────
touch /var/lib/stueos/firstboot-done
echo "[$(date)] First-boot fullført."
echo ""
echo "Neste steg: kjør veiviseren:"
echo "  bash /usr/share/stueos/setup.sh"
