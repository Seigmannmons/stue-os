#!/usr/bin/env bash
# StueOS Fusion — Oppsettscript
# Kjøres etter første oppstart på StueOS-maskinen.
# Krav: stueos.env ligger i ~/.config/stueos/stueos.env
#
# Bruk: bash /usr/share/stueos/setup.sh
#       eller: bash setup.sh (fra prosjektmappen)

set -euo pipefail

CONF="${HOME}/.config/stueos/stueos.env"
STUEOS_HOME="${HOME}/.config/stueos"
LOG="${STUEOS_HOME}/setup.log"

# ── Farger ──
RED='\033[0;31m'; GRN='\033[0;32m'; AMB='\033[0;33m'
BLU='\033[0;34m'; RST='\033[0m'; BOLD='\033[1m'

info()  { echo -e "${BLU}→${RST} $*" | tee -a "$LOG"; }
ok()    { echo -e "${GRN}✓${RST} $*" | tee -a "$LOG"; }
warn()  { echo -e "${AMB}⚠${RST} $*" | tee -a "$LOG"; }
err()   { echo -e "${RED}✗${RST} $*" | tee -a "$LOG"; exit 1; }
header(){ echo -e "\n${BOLD}${AMB}══ $* ══${RST}" | tee -a "$LOG"; }

# ── Sjekk konfig ──
if [[ ! -f "$CONF" ]]; then
  err "Finner ikke ${CONF}. Kjør installeringsveiviseren først."
fi

mkdir -p "$STUEOS_HOME"
: > "$LOG"

echo -e "${BOLD}${AMB}"
echo " ___  _             ___  ___ "
echo "/ __|| |_  _  _  __/ _ \/ __|"
echo "\__ \|  _|| || |/ -_)  _/\__ \\"
echo "|___/ \__| \_,_|\___|_|  |___/"
echo -e "${RST}${AMB} StueOS Fusion — Oppsett${RST}"
echo ""

# ── Last inn konfig ──
# shellcheck disable=SC1090
source "$CONF"
ok "Konfigurasjon lastet fra ${CONF}"

# ═══════════════════════════════════════
header "TJENESTEKONFIGURASJON"
# ═══════════════════════════════════════

SERVICES_DIR="${HOME}/.config/stueos/services"
mkdir -p "$SERVICES_DIR"

# Denon-tjeneste
if [[ -n "${DENON_HOST:-}" ]]; then
  cat > "${SERVICES_DIR}/denon-control.env" <<EOF
DENON_HOST=${DENON_HOST}
DENON_PORT=23
SERVICE_PORT=8041
EOF
  ok "Denon AVR konfigurert (${DENON_HOST})"
fi

# Bluesound-tjeneste
if [[ -n "${BLUESOUND_HOST:-}" ]]; then
  cat > "${SERVICES_DIR}/bluesound-control.env" <<EOF
BLUESOUND_HOST=${BLUESOUND_HOST}
BLUESOUND_PORT=11000
SERVICE_PORT=8042
EOF
  ok "Bluesound konfigurert (${BLUESOUND_HOST})"
fi

# Homey Kodi add-on innstillinger
if [[ -n "${HOMEY_HOST:-}" && -n "${HOMEY_TOKEN:-}" ]]; then
  KODI_ADDON_DIR="${HOME}/.kodi/userdata/addon_data/script.stueos.homey"
  mkdir -p "$KODI_ADDON_DIR"
  cat > "${KODI_ADDON_DIR}/settings.xml" <<EOF
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<settings version="2">
  <setting id="homey_host">${HOMEY_HOST}</setting>
  <setting id="homey_token">${HOMEY_TOKEN}</setting>
  <setting id="flow_film_start">${HOMEY_FLOW_FILM_START:-}</setting>
  <setting id="flow_film_stopp">${HOMEY_FLOW_FILM_STOPP:-}</setting>
  <setting id="flow_pause">${HOMEY_FLOW_PAUSE:-}</setting>
  <setting id="flow_resume">${HOMEY_FLOW_RESUME:-}</setting>
</settings>
EOF
  ok "Homey add-on konfigurert (${HOMEY_HOST})"
fi

# ntfy-konfig
if [[ -n "${NTFY_TOPIC:-}" ]]; then
  cat > "${STUEOS_HOME}/ntfy.env" <<EOF
NTFY_SERVER=${NTFY_SERVER:-https://ntfy.sh}
NTFY_TOPIC=${NTFY_TOPIC}
EOF
  ok "ntfy konfigurert (${NTFY_TOPIC})"
fi

# ═══════════════════════════════════════
header "KODI KONFIGURASJON"
# ═══════════════════════════════════════

KODI_UDATA="${HOME}/.kodi/userdata"
mkdir -p "$KODI_UDATA"

# Avanserte innstillinger (cacheinnstillinger for 4K)
if [[ ! -f "${KODI_UDATA}/advancedsettings.xml" ]]; then
  cat > "${KODI_UDATA}/advancedsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<advancedsettings>
  <!-- Økt buffer for 4K HiDef streaming -->
  <cache>
    <buffermode>1</buffermode>
    <memorysize>157286400</memorysize>
    <readfactor>4</readfactor>
  </cache>
  <!-- Prioriter norsk undertekstspråk -->
  <subtitles>
    <defaultLanguage>nor</defaultLanguage>
    <languages>nor,nob,eng</languages>
  </subtitles>
</advancedsettings>
EOF
  ok "Kodi advancedsettings.xml opprettet"
else
  warn "Kodi advancedsettings.xml finnes allerede — hopper over"
fi

# Kopi av sources.xml maler (mediebiblioteker)
if [[ -n "${FILMS_DIR:-}" || -n "${TV_DIR:-}" ]]; then
  cat > "${KODI_UDATA}/sources.xml" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sources>
  <video>
    <default pathversion="1"></default>
    $(if [[ -n "${FILMS_DIR:-}" ]]; then
      echo "<source><name>Filmer</name><path pathversion=\"1\">${FILMS_DIR}/</path><allowsharing>true</allowsharing></source>"
    fi)
    $(if [[ -n "${TV_DIR:-}" ]]; then
      echo "<source><name>Serier</name><path pathversion=\"1\">${TV_DIR}/</path><allowsharing>true</allowsharing></source>"
    fi)
  </video>
  <music>
    <default pathversion="1"></default>
    $(if [[ -n "${MUSIC_DIR:-}" ]]; then
      echo "<source><name>Musikk</name><path pathversion=\"1\">${MUSIC_DIR}/</path><allowsharing>true</allowsharing></source>"
    fi)
  </music>
</sources>
EOF
  ok "Kodi sources.xml opprettet"
fi

# ═══════════════════════════════════════
header "SYSTEMINNSTILLINGER"
# ═══════════════════════════════════════

# Tidssone
if [[ -n "${TIMEZONE:-}" ]]; then
  if timedatectl set-timezone "$TIMEZONE" 2>/dev/null; then
    ok "Tidssone satt til ${TIMEZONE}"
  else
    warn "Kunne ikke sette tidssone — prøv manuelt: timedatectl set-timezone ${TIMEZONE}"
  fi
fi

# Locale
if [[ -n "${LANGUAGE:-}" ]]; then
  LOCALE_CONF="/etc/locale.conf"
  if [[ -w "$LOCALE_CONF" ]] || sudo -n true 2>/dev/null; then
    echo "LANG=${LANGUAGE}.UTF-8" | sudo tee "$LOCALE_CONF" > /dev/null
    ok "Språk satt til ${LANGUAGE}"
  else
    warn "Kan ikke skrive til ${LOCALE_CONF} uten sudo — sett manuelt"
  fi
fi

# ═══════════════════════════════════════
header "SYSTEMD-TJENESTER"
# ═══════════════════════════════════════

QUAD_DIR="${HOME}/.config/containers/systemd"
UNITS_SRC="/usr/share/stueos/quadlets"

if [[ -d "$UNITS_SRC" ]]; then
  mkdir -p "$QUAD_DIR"
  cp -v "$UNITS_SRC"/*.container "$QUAD_DIR/" && ok "Podman quadlets kopiert"
  systemctl --user daemon-reload
  systemctl --user enable --now radarr.service  2>/dev/null && ok "Radarr startet" || warn "Radarr: se journalctl"
  systemctl --user enable --now sonarr.service  2>/dev/null && ok "Sonarr startet" || warn "Sonarr: se journalctl"
  systemctl --user enable --now bazarr.service  2>/dev/null && ok "Bazarr startet" || warn "Bazarr: se journalctl"
else
  warn "Quadlet-maler ikke funnet på ${UNITS_SRC} — start containere manuelt"
fi

# Start Python-tjenester
if [[ -f "${HOME}/.config/systemd/user/denon-control.service" ]]; then
  systemctl --user enable --now denon-control.service 2>/dev/null && ok "Denon-tjeneste startet" || warn "Denon: se journalctl"
fi
if [[ -f "${HOME}/.config/systemd/user/bluesound-control.service" ]]; then
  systemctl --user enable --now bluesound-control.service 2>/dev/null && ok "Bluesound-tjeneste startet" || warn "Bluesound: se journalctl"
fi

# ═══════════════════════════════════════
header "FERDIG"
# ═══════════════════════════════════════

echo ""
echo -e "${GRN}${BOLD}StueOS Fusion er klar!${RST}"
echo ""
echo -e "  ${AMB}Neste steg:${RST}"
echo "  1. Start Kodi og konfigurer Plexkodiconnect / JellyCon add-ons"
echo "  2. Åpne Radarr på http://localhost:7878 og Sonarr på http://localhost:8989"
echo "  3. Test Denon-integrasjon: curl http://localhost:8041/status"
[[ -n "${BLUESOUND_HOST:-}" ]] && \
  echo "  4. Test Bluesound-integrasjon: curl http://localhost:8042/status"
echo ""
echo -e "  ${BLU}Logg:${RST} ${LOG}"
echo ""
