#!/usr/bin/env bash
# StueOS OTA-oppdateringssjekk
# Kjøres av stueos-update.timer (mandag 03:00).
# Laster ned oppdatering stille og varsler via ntfy at en omstart er klar.

set -euo pipefail

CONF="/etc/stueos/services/ntfy.env"
LOG_TAG="stueos-update"

_log()  { logger -t "$LOG_TAG" "$*"; }
_ntfy() {
    local title="$1" msg="$2" prio="${3:-default}"
    local server topic
    # Last inn ntfy-konfig om tilgjengelig
    if [[ -f "$CONF" ]]; then
        # shellcheck disable=SC1090
        source "$CONF"
    fi
    server="${NTFY_SERVER:-https://ntfy.sh}"
    topic="${NTFY_TOPIC:-stueos-stue}"
    curl -sf \
        -H "Title: ${title}" \
        -H "Priority: ${prio}" \
        -d "$msg" \
        "${server}/${topic}" >/dev/null 2>&1 || true
}

# ── Sjekk om oppdatering er tilgjengelig ──────────────────────────────────
_log "Sjekker etter StueOS-oppdateringer..."

UPDATE_OUTPUT=$(rpm-ostree upgrade --check 2>&1) || true

if echo "$UPDATE_OUTPUT" | grep -q "No upgrade available\|No updates available"; then
    _log "Ingen oppdateringer tilgjengelig."
    exit 0
fi

if echo "$UPDATE_OUTPUT" | grep -q "error\|Error"; then
    _log "Oppdateringssjekk feilet: ${UPDATE_OUTPUT}"
    exit 1
fi

# Oppdatering er tilgjengelig — hent den stille i bakgrunnen
_log "Oppdatering tilgjengelig — laster ned..."
_ntfy "StueOS: Oppdatering" "Ny versjon lastes ned i bakgrunnen. Start på nytt for å aktivere (just reboot)" "low"

if rpm-ostree upgrade --download-only 2>&1 | tee -a /dev/fd/1 | logger -t "$LOG_TAG"; then
    _log "Oppdatering lastet ned og klar."
    _ntfy "StueOS: Oppdatering klar 🔄" \
        "Ny StueOS-versjon er klar. Start på nytt når det passer: 'just reboot' eller velg Restart i KDE." \
        "default"
else
    _log "Nedlasting feilet — prøver igjen neste uke."
    exit 1
fi
