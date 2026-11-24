# StueOS Fase 2 — Medieserver og integrasjoner

Forutsetter at Fase 1 (Bazzite NVIDIA installert) er fullført.

---

## #11–#13 Radarr / Sonarr / qBittorrent — ekstern server

Radarr, Sonarr og qBittorrent kjører allerede på en annen maskin i nettverket.
StueOS trenger kun å koble til dem og vise varsler via Kodi OSD.

### Oppgi adresser i installeringsveiviseren

Fyll inn URL og API-nøkkel for Radarr og Sonarr i veiviseren (Steg 3 → Medieserver).
`setup.sh` registrerer kodi-notify som webhook automatisk.

**Hent API-nøkkel:**  
Radarr / Sonarr → Settings → General → Security → API Key

### Tilgang til fjernserver fra StueOS

| Tjeneste | URL (eksempel) |
|---|---|
| Radarr | http://192.168.1.X:7878 |
| Sonarr | http://192.168.1.X:8989 |
| qBittorrent | http://192.168.1.X:8080 |

Erstatt `192.168.1.X` med faktisk IP til medieserveren din.

### Lokale quadlets (valgfri, kun ved lokal kjøring)

Vil du kjøre Radarr/Sonarr lokalt på StueOS istedenfor, finner du quadlet-filer
under `containers/radarr/`, `containers/sonarr/` og `containers/qbittorrent/`.
Dette er ikke standardoppsettet — det forventes at disse tjenestene allerede kjører
på en dedikert server i nettverket.

---

## #14 Plex via Plexkodiconnect

```bash
# PKC installeres som zip-add-on i Kodi
# Last ned siste release:
curl -sL https://api.github.com/repos/croneter/PlexKodiConnect/releases/latest \
  | grep browser_download_url | grep -o '"[^"]*\.zip"' | head -1
```

1. Kodi → Innstillinger → Addons → Installer fra zip → velg nedlastet PKC.zip
2. Aktiver add-on → logg inn med Plex-konto
3. Kopiér innstillingsfil (valgfri):
   ```bash
   cp config/kodi/addon-settings/plexkodiconnect.xml \
     ~/.var/app/tv.kodi.Kodi/data/userdata/addon_data/plugin.video.plexkodiconnect/settings.xml
   ```

**4K Direct Play:** Konfigurer Plex Media Server til å tillate Direct Play for denne klienten. I Kodi/PKC-innstillinger: aldri transcoding, maks oppløsning 4K.

---

## #15 Jellyfin via JellyCon

```bash
# JellyCon installeres som zip:
# https://github.com/jellyfin/jellycon/releases
```

1. Installer JellyCon-zip via Kodi som over
2. Legg til server: `http://<jellyfin-server>:8096`
3. Innstillingsfil: `config/kodi/addon-settings/jellycon.xml`

**4K HDR uten transcoding — Jellyfin MPV Shim (anbefalt):**
```bash
pip3 install --user jellyfin-mpv-shim
# Legg til autostart:
systemctl --user enable --now jellyfin-mpv-shim
```
MPV Shim håndterer avspilling med lokal MPV + Vulkan → HDR pass-through, ingen transcoding.

---

## #16 ntfy push-varsler

ntfy-container kjøres allerede (se over). Nå koble til Radarr/Sonarr:

**Radarr:** Settings → Connect → ＋ ntfy  
- Server URL: `http://localhost:2586`  
- Topic: `stueos-stue`  
- Trigger: On Download, On Upgrade

**Sonarr:** samme oppsett.

**Telefon:** Installer ntfy-appen (iOS/Android) → abonner på `http://<maskin-IP>:2586/stueos-stue`

**Test:**
```bash
curl -d "Test fra StueOS" http://localhost:2586/stueos-stue
```

---

## #17 Kodi OSD-varsler via webhooks

Kodi-notify-tjenesten lytter på port 8085 og viser varsler i Kodi-OSD.

```bash
# Start tjenesten (etter at setup.sh er kjørt og kodi-notify.env er på plass)
systemctl start stueos-kodi-notify

# Test manuelt:
curl -X POST http://localhost:8085/notify \
  -H "Content-Type: application/json" \
  -d '{"eventType":"Download","movie":{"title":"Inception","year":2010},"movieFile":{"quality":{"quality":{"name":"4K"}}}}'

# Helsejekk:
curl http://localhost:8085/health
```

**Kodi JSONRPC-aktivering** (må gjøres én gang):  
Kodi → Innstillinger → Tjenester → Kontroll → Aktiver HTTP  
Port: 8080, Brukernavn: kodi

**Radarr/Sonarr Webhook** (registreres automatisk av `setup.sh`):  
Settings → Connect → ＋ Webhook  
- URL: `http://<stueos-ip>:8085/notify`  
- Metode: POST  
- Trigger: On Download, On Upgrade

> `setup.sh` finner StueOS-maskinens IP automatisk og registrerer webhooks via Radarr/Sonarr REST API.
> Manuell registrering er kun nødvendig om automatisk registrering feilet.

---

## #18 Blu-ray avspilling

libbluray er installert i StueOS-imaget. For standard BD:

```bash
# Test BD-avspilling med VLC
flatpak run org.videolan.VLC bluray:///dev/sr0

# Test med mpv
mpv bd:///dev/sr0
```

**MakeMKV (UHD ripping) — manuell installasjon:**
```bash
# MakeMKV er ikke åpen kildekode og kan ikke distribueres i image
# Last ned fra https://www.makemkv.com/download/
# Kjør AppImage:
chmod +x makemkv-*.appimage
./makemkv-*.appimage

# Etter installasjon av ASUS BW-16D1HT med LibreDrive-firmware:
# MakeMKV → Hjelp → Registreringsnøkkel (prøveperiode er gratis)
```

**libbluray-nøkler (KEYDB.cfg):**
```bash
mkdir -p ~/.config/aacs
# Last ned KEYDB.cfg fra https://vlc-bluray.whoknowsmy.name/
# Plasser i ~/.config/aacs/KEYDB.cfg
```
