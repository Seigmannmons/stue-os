#!/usr/bin/env bash
# StueOS Fase 1 — Hardware-verifisering
# Kjøres etter installasjon for å bekrefte at alt er i orden.

RED='\033[0;31m'; GRN='\033[0;32m'; AMB='\033[0;33m'; RST='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "  ${GRN}✓${RST} $*"; }
fail() { echo -e "  ${RED}✗${RST} $*"; FAILED=$((FAILED+1)); }
warn() { echo -e "  ${AMB}?${RST} $*"; }
hdr()  { echo -e "\n${BOLD}${AMB}── $* ──${RST}"; }

FAILED=0

hdr "NVIDIA GPU"
if nvidia-smi &>/dev/null; then
  GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)
  ok "NVIDIA-driver lastet: $GPU"
else
  fail "nvidia-smi feilet — driver ikke lastet?"
fi

if vulkaninfo 2>/dev/null | grep -q "GTX\|NVIDIA"; then
  ok "Vulkan: NVIDIA GPU oppdaget"
else
  warn "Vulkan: kjør 'vulkaninfo' manuelt for å verifisere"
fi

hdr "HDMI / Display"
if xrandr 2>/dev/null | grep -q "3840x2160"; then
  ok "4K-modus tilgjengelig (3840×2160)"
else
  warn "4K ikke oppgitt av xrandr — sjekk KDE Display Settings"
fi

hdr "iMon VFD-display og IR"
if lsmod | grep -q imon; then
  ok "imon-driver lastet"
else
  fail "imon-driver ikke lastet — prøv: sudo modprobe imon"
fi

if ls /dev/lirc* &>/dev/null; then
  ok "LIRC-device funnet: $(ls /dev/lirc*)"
else
  fail "Ingen /dev/lirc* — IR-mottaker ikke oppdaget"
fi

LCD=$(ls /dev/lcd* /dev/vfd* 2>/dev/null | head -1)
if [[ -n "$LCD" ]]; then
  ok "VFD/LCD-device funnet: $LCD"
else
  warn "Ingen /dev/lcd* eller /dev/vfd* — sjekk imon-device i /dev/input/by-id/"
fi

hdr "CEC"
if command -v cec-client &>/dev/null; then
  ok "cec-client installert"
  CECS=$(cec-client -l 2>/dev/null | grep -c "device" || true)
  [[ "$CECS" -gt 0 ]] && ok "CEC-enheter funnet" || warn "Ingen CEC-enheter — sjekk HDMI-tilkobling"
else
  fail "cec-client ikke installert — kjør: rpm-ostree install libcec && reboot"
fi

hdr "Kodi (Flatpak)"
if flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi"; then
  ok "Kodi installert via Flatpak"
  KEYMAP="$HOME/.var/app/tv.kodi.Kodi/data/userdata/keymaps/remote.xml"
  [[ -f "$KEYMAP" ]] && ok "IR-keymap på plass" || warn "Mangler keymap — kopier config/kodi/keymaps/remote.xml"
else
  fail "Kodi ikke installert — kjør: flatpak install flathub tv.kodi.Kodi"
fi

hdr "Steam / EmuDeck"
if flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam"; then
  ok "Steam installert"
else
  warn "Steam ikke funnet via Flatpak (kan være system-installert på Bazzite)"
fi

if [[ -d "$HOME/Emulation" ]]; then
  ok "EmuDeck-mappe finnes ($HOME/Emulation)"
else
  warn "EmuDeck ikke installert ennå"
fi

hdr "Xbox-kontroller"
if ls /dev/input/js* &>/dev/null; then
  ok "Joystick/kontroller funnet: $(ls /dev/input/js*)"
else
  warn "Ingen kontroller oppdaget — koble til og kjør igjen"
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GRN}${BOLD}Fase 1-hardware OK — klar for Fase 2!${RST}"
else
  echo -e "${RED}${BOLD}$FAILED feil funnet — se ovenfor.${RST}"
fi
echo ""
