# StueOS Fase 1 — Grunnoppsett

Følg stegene i rekkefølge. Kjør `scripts/check-hardware.sh` etter hvert steg for å bekrefte.

---

## #4 Installere Bazzite NVIDIA

1. Last ned **Bazzite NVIDIA ISO** fra https://bazzite.gg → velg `bazzite-nvidia`
2. Flash til USB med Balena Etcher eller `dd`:
   ```bash
   sudo dd if=bazzite-nvidia-*.iso of=/dev/sdX bs=4M status=progress
   ```
3. Boot fra USB, velg "Install to Hard Drive" (Anaconda)
4. Velg SSD som mål, sett norsk tastaturoppsett
5. Etter installasjon og første oppstart — oppdater:
   ```bash
   rpm-ostree update && systemctl reboot
   ```
6. Bekreft NVIDIA-driver:
   ```bash
   nvidia-smi
   # Skal vise: GTX 1660 Super, driver-versjon
   ```

---

## #5 Konfigurere 4K HDR output via NVIDIA

GTX 1660 Super støtter 4K@60Hz via HDMI 2.0b med HDR10.

**KDE Display Settings:**
- Systeminnstillinger → Skjermer → 3840×2160 @ 60 Hz
- Skala: 150 % anbefalt for TV-avstand

**HDR i KDE Plasma 6:**
```bash
# Aktiver HDR for primær skjerm (krever Plasma 6.1+)
kscreen-doctor output.HDMI-0.hdr.enable
```

**Test med mpv:**
```bash
mpv --vo=gpu --gpu-api=vulkan --target-colorspace-hint test-hdr.mkv
```

**NVIDIA Vulkan / color settings:**
```bash
# Sjekk Vulkan-støtte
vulkaninfo | grep -A2 "GPU id"

# Sett colorspace via xrandr (fallback):
xrandr --output HDMI-0 --set "Broadcast RGB" "Full"
```

---

## #6 Installere Kodi 21 med Arctic Zephyr: Reloaded

```bash
# Installer Kodi via Flatpak
flatpak install flathub tv.kodi.Kodi

# Start Kodi
flatpak run tv.kodi.Kodi
```

**Installer Arctic Zephyr: Reloaded-skinn:**
1. Kodi → Innstillinger → Interface → Skin → Hent mer...
2. Søk "Arctic Zephyr" → Installer → Aktiver

**Kopier StueOS-fargetema:**
```bash
KODI_SKIN_DIR="$HOME/.var/app/tv.kodi.Kodi/data/addons/skin.arctic.zephyr.2.reloaded"
mkdir -p "$KODI_SKIN_DIR/720p/includes/colors"
cp config/themes/kodi/colors.xml "$KODI_SKIN_DIR/720p/includes/colors/stueos-fusion.xml"
```

**Kopier IR-keymap:**
```bash
mkdir -p "$HOME/.var/app/tv.kodi.Kodi/data/userdata/keymaps"
cp config/kodi/keymaps/remote.xml "$HOME/.var/app/tv.kodi.Kodi/data/userdata/keymaps/"
```

**Norsk språk:**
Kodi → Innstillinger → Interface → Språk → Norsk

**Mediekilder (NFS-eksempel):**
Kodi → Videoer → Legg til video... → `nfs://192.168.1.X/media/filmer`

---

## #7 iMon VFD-display (Antec Fusion Remote)

Bazzite inkluderer `imon`-driver. Verifiser:

```bash
# Sjekk at driver er lastet
lsmod | grep imon

# Sjekk device-noder
ls /dev/lcd* /dev/vfd* 2>/dev/null || echo "Ikke funnet"

# iMon eksponeres vanligvis som input-device
ls /dev/input/by-id/ | grep -i imon
```

**Kodi LCD-addon:**
1. Kodi → Innstillinger → Addons → Installer fra zip / Repository
2. Søk `service.xbmc.lcd` → Installer
3. Addon-innstillinger:
   - Type: iMon
   - Device: `/dev/lcd0` (eller det `ls` viser over)
   - Port: USB

---

## #8 IR-fjernkontroll (iMon)

iMon-mottakeren eksponeres som `/dev/lirc0`:

```bash
# Bekreft LIRC-device
ls -la /dev/lirc*

# Test IR-mottak (pek fjernkontroll, trykk knapper)
mode2 -d /dev/lirc0
# Skal vise pulser: space/pulse-linjer

# Alternativt med irw:
irw /dev/lirc0
```

**Kodi LIRC-aktivering:**
Kodi → Innstillinger → System → Input → Peripheral → iMon  
Aktiver "Fjernkontroll via LIRC"

Keymap ligger i `config/kodi/keymaps/remote.xml`.  
Juster knappekoder etter faktisk `irw`-output fra din fjernkontroll.

---

## #9 Steam Game Mode og EmuDeck

**Steam Game Mode (Gamescope):**
```bash
# Bazzite starter automatisk i Game Mode ved TV-modus.
# For å bytte til Desktop Mode:
# Hold Steam-knappen → Skrivebordsmoduse
```

**Test Proton:**
1. Åpne Steam i Game Mode
2. Velg et spill → Spill av (Proton aktiveres automatisk)
3. Bekreft FPS i Steam-overlegget

**EmuDeck:**
```bash
# Last ned og kjør EmuDeck-installasjonsscript
bash <(curl -Ls https://raw.githubusercontent.com/dragoonDorise/EmuDeck/main/install.sh)
```

**Test EmulationStation-DE:**
1. Start ES-DE fra Steam Library
2. Legg til én ROM i `~/Emulation/roms/<system>/`
3. Oppdater spillbibliotek i ES-DE

**Xbox-kontroller:**
```bash
# Sjekk at kontroller oppdages (koble til via USB eller Bluetooth)
ls /dev/input/js*
jstest /dev/input/js0
```

---

## #10 CEC (TV-kontroll via HDMI)

```bash
# Installer libcec (rpm-ostree = persistent på Bazzite)
rpm-ostree install libcec

# Reboot etter installasjon
systemctl reboot

# Test CEC-enheter
cec-client -l
# Skal vise TV og eventuelle andre CEC-enheter

# Interaktiv test
echo "scan" | cec-client -s -d 1
```

**Kodi CEC:**
Kodi → Innstillinger → System → Input → Peripherals → CEC Adapter  
- Aktiver CEC
- "Send inaktiv kilde" ved avslutning: På
- TV-av ved Kodi-avslutning: Valgfri

---

## Hardware-verifisering

```bash
bash scripts/check-hardware.sh
```

Kjøres etter at alle steg er fullført.
