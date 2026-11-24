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
header "KODI-NOTIFY OG TJENESTER"
# ═══════════════════════════════════════

# Homey-tjeneste
if [[ -n "${HOMEY_HOST:-}" && -n "${HOMEY_TOKEN:-}" ]]; then
  cat > "${SERVICES_DIR}/homey-control.env" <<EOF
HOMEY_HOST=${HOMEY_HOST}
HOMEY_TOKEN=${HOMEY_TOKEN}
HOMEY_FLOW_FILM_START=${HOMEY_FLOW_FILM_START:-}
HOMEY_FLOW_FILM_STOPP=${HOMEY_FLOW_FILM_STOPP:-}
HOMEY_FLOW_PAUSE=${HOMEY_FLOW_PAUSE:-}
HOMEY_FLOW_RESUME=${HOMEY_FLOW_RESUME:-}
SERVICE_PORT=8043
EOF
  ok "Homey konfigurert (${HOMEY_HOST})"
fi

# kodi-notify konfig (Kodi OSD-varsler fra Radarr/Sonarr på fjernserver)
cat > "${SERVICES_DIR}/kodi-notify.env" <<EOF
KODI_HOST=localhost
KODI_PORT=8080
KODI_USER=kodi
KODI_PASS=
SERVICE_PORT=8085
EOF
ok "kodi-notify konfigurert"

# Start systemd-tjenester (installert i OCI-imaget)
systemctl --user daemon-reload
systemctl --user enable --now stueos-kodi-notify.service 2>/dev/null && ok "kodi-notify startet" || warn "kodi-notify: se journalctl"
if [[ -n "${DENON_HOST:-}" ]]; then
  systemctl --user enable --now stueos-denon.service 2>/dev/null && ok "Denon-tjeneste startet" || warn "Denon: se journalctl"
fi
if [[ -n "${BLUESOUND_HOST:-}" ]]; then
  systemctl --user enable --now stueos-bluesound.service 2>/dev/null && ok "Bluesound-tjeneste startet" || warn "Bluesound: se journalctl"
fi
if [[ -n "${HOMEY_HOST:-}" && -n "${HOMEY_TOKEN:-}" ]]; then
  systemctl --user enable --now stueos-homey.service 2>/dev/null && ok "Homey-tjeneste startet" || warn "Homey: se journalctl"
fi

# ═══════════════════════════════════════
header "WEBHOOK-REGISTRERING"
# ═══════════════════════════════════════

# Registrer kodi-notify som webhook på fjern-Radarr/Sonarr
STUEOS_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
KODI_NOTIFY_URL="http://${STUEOS_IP}:8085/notify"
info "StueOS IP: ${STUEOS_IP} — webhook URL: ${KODI_NOTIFY_URL}"

_register_webhook() {
  local service_name="$1" base_url="$2" api_key="$3"
  local endpoint="${base_url}/api/v3/notification"

  local existing
  existing=$(curl -sf --max-time 5 -H "X-Api-Key: ${api_key}" "${endpoint}" 2>/dev/null) \
    || { warn "${service_name}: kan ikke nå ${base_url} — registrer webhook manuelt"; return; }

  if echo "$existing" | grep -q '"stueos-kodi"'; then
    ok "${service_name}: webhook allerede registrert"
    return
  fi

  local payload
  payload=$(printf '{
  "name": "stueos-kodi",
  "implementation": "Webhook",
  "configContract": "WebhookSettings",
  "fields": [
    {"name": "url", "value": "%s"},
    {"name": "method", "value": 1}
  ],
  "onDownload": true,
  "onUpgrade": true,
  "onGrab": false,
  "includeHealthWarnings": false,
  "tags": []
}' "$KODI_NOTIFY_URL")

  if curl -sf --max-time 10 -X POST \
       -H "Content-Type: application/json" \
       -H "X-Api-Key: ${api_key}" \
       -d "$payload" "${endpoint}" >/dev/null 2>&1; then
    ok "${service_name}: webhook registrert (${KODI_NOTIFY_URL})"
  else
    warn "${service_name}: webhook-registrering feilet — gjør det manuelt under Settings → Connect → Webhook"
  fi
}

if [[ -n "${RADARR_URL:-}" && -n "${RADARR_API_KEY:-}" ]]; then
  _register_webhook "Radarr" "${RADARR_URL}" "${RADARR_API_KEY}"
fi
if [[ -n "${SONARR_URL:-}" && -n "${SONARR_API_KEY:-}" ]]; then
  _register_webhook "Sonarr" "${SONARR_URL}" "${SONARR_API_KEY}"
fi

# ═══════════════════════════════════════
header "FERDIG"
# ═══════════════════════════════════════

echo ""
echo -e "${GRN}${BOLD}StueOS Fusion er klar!${RST}"
echo ""
echo -e "  ${AMB}Neste steg:${RST}"
echo "  1. Start Kodi → Innstillinger → Tjenester → Kontroll → Aktiver HTTP (port 8080)"
echo "  2. Test Kodi-varsler: curl -X POST http://localhost:8085/notify -H 'Content-Type: application/json' -d '{\"eventType\":\"Download\",\"movie\":{\"title\":\"Test\",\"year\":2024}}'"
[[ -n "${RADARR_URL:-}" ]] && echo "  3. Radarr: ${RADARR_URL}"
[[ -n "${SONARR_URL:-}" ]] && echo "  4. Sonarr: ${SONARR_URL}"
[[ -n "${DENON_HOST:-}" ]] && echo "  5. Test Denon: curl http://localhost:8041/status"
[[ -n "${BLUESOUND_HOST:-}" ]] && echo "  6. Test Bluesound: curl http://localhost:8042/status"
echo ""
echo -e "  ${BLU}Logg:${RST} ${LOG}"
echo ""
