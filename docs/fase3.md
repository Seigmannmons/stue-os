# StueOS Fase 3 — AVR, Bluesound, Homey og Deezer

Forutsetter at Fase 1 (Bazzite NVIDIA installert) og Fase 2 (Kodi + varsler) er fullført.

---

## #19 Denon AVR model mapping

Denon AVR Control-tjenesten kjører på **port 8041** og styrer mottakeren via
`denonavr`-biblioteket. Kildene varierer mellom modeller — bruk `/sources`
for å hente riktige navn.

### Oppstart og test

```bash
# Status:
curl http://localhost:8041/status

# List tilgjengelige inngangskilder (modellspesifikt):
curl http://localhost:8041/sources

# List surroundmodi:
curl http://localhost:8041/sound-modes

# Helsejekk:
curl http://localhost:8041/health
```

### Eksempelkommandoer

```bash
# Skru på AVR:
curl -X POST http://localhost:8041/power/on

# Bytt til HDMI 1 (eksempel — se /sources for faktisk navn):
curl -X POST http://localhost:8041/input/HDMI1

# Sett volum til 40 % (-48 dB):
curl -X POST http://localhost:8041/volume/pct/40

# Juster volum opp/ned:
curl -X POST http://localhost:8041/volume/up
curl -X POST http://localhost:8041/volume/down

# Aktiver DTS:X surroundlyd:
curl -X POST "http://localhost:8041/sound-mode/DTS%3AX"

# Demp:
curl -X POST http://localhost:8041/mute/on
```

### Inngangskilder — vanlige Denon-navn

| Skjermvisning | API-navn (hentes fra /sources) |
|---|---|
| TV / HDMI ARC | TV Audio |
| Blu-ray spilleren | Blu-ray |
| Xbox / PS5 | Game |
| MediaPlayer / NAS | Media Player |
| Nettverkslyd | Online Music |

> **Tips:** Installer Kodi-addon `script.denon.avr` eller bruk Arctic Zephyr-widgeten
> for volumkontroll fra fjernkontrollen.

---

## #20 Bluesound Node Control

Bluesound Control-tjenesten kjører på **port 8042** og returnerer JSON-svar.

### Oppstart og test

```bash
# Status (nåværende spor, volum, tilstand):
curl http://localhost:8042/status

# Helsejekk:
curl http://localhost:8042/health
```

### Avspillingskontroll

```bash
# Spill/pause:
curl -X POST http://localhost:8042/play
curl -X POST http://localhost:8042/pause

# Neste/forrige:
curl -X POST http://localhost:8042/skip
curl -X POST http://localhost:8042/back

# Volum (0–100):
curl -X POST http://localhost:8042/volume/55
curl -X POST http://localhost:8042/volume/up
curl -X POST http://localhost:8042/volume/down

# Shuffle og repeat:
curl -X POST http://localhost:8042/shuffle/on
curl -X POST "http://localhost:8042/repeat/1"   # 0=av, 1=alle, 2=ett spor
```

### Forhåndsvalg (Presets)

```bash
# List alle presets:
curl http://localhost:8042/presets

# Start preset 1:
curl -X POST http://localhost:8042/preset/1
```

---

## #22 Deezer via Bluesound

Bluesound har innebygd Deezer-støtte via BluOS. Forutsetter at Deezer er
koblet til Bluesound-appen på telefonen.

```bash
# Bla gjennom Deezer-biblioteket:
curl http://localhost:8042/deezer/browse

# Start Deezer Flow (personlig mikseplass):
curl -X POST http://localhost:8042/deezer/play-flow

# Start spesifikt innhold (URL fra browse-svar):
curl -X POST "http://localhost:8042/deezer/play-url?url=deezer://playlist/12345"
```

**Hent Deezer-URL-er:**  
Bla i `/deezer/browse` og finn `play_url`-feltet på albumet/spillelisten du vil starte.

---

## #21 Homey Flow-integrasjon

Homey Control-tjenesten kjører på **port 8043** og trigger Homey-flyt via
Homey Pro lokal REST API.

### Forutsetninger

1. Oppgi Homey-IP og token i installeringsveiviseren (Steg 2 → Homey)
2. `setup.sh` oppretter `homey-control.env` automatisk

**Hent personlig token:**  
[my.homey.app](https://my.homey.app) → Developer → API → Opprett token

**Hent flow-IDer:**  
Homey Developer Tools (F12 → Console):
```javascript
await Homey.flow.getFlows().then(flows => Object.entries(flows).map(([id,f]) => `${id}: ${f.name}`).join('\n'))
```

### Test

```bash
# Se konfigurerte flows og tilkoblingsstatus:
curl http://localhost:8043/status

# Helsejekk:
curl http://localhost:8043/health

# Trigger manuelt (bytt ut med faktisk flow-ID):
curl -X POST "http://localhost:8043/flow/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Simuler Kodi-hendelser:
curl -X POST "http://localhost:8043/kodi/play?title=Inception"
curl -X POST http://localhost:8043/kodi/pause
curl -X POST http://localhost:8043/kodi/resume
curl -X POST http://localhost:8043/kodi/stop
```

### Kodi → Homey automatisk

For å trigger Homey fra Kodi automatisk trenger vi et Kodi event-script.

**Enkel tilnærming — konfigurer i Kodi:**  
Innstillinger → Services → HTTP → Aktiver ekstern kontroll  
Sett opp flows til å kjøre via Kodi JSONRPC `addons.ExecuteAddon` eller
lag et lite Python-script som legges i `~/.kodi/userdata/addon_data/`.

**Eksempel `~/.kodi/scripts/stueos-events.py`:**
```python
import xbmc
import requests

class KodiMonitor(xbmc.Monitor):
    def onNotification(self, sender, method, data):
        url = "http://localhost:8043"
        if method == "Player.OnPlay":
            requests.post(f"{url}/kodi/play", timeout=2)
        elif method == "Player.OnStop":
            requests.post(f"{url}/kodi/stop", timeout=2)
        elif method == "Player.OnPause":
            requests.post(f"{url}/kodi/pause", timeout=2)
        elif method == "Player.OnResume":
            requests.post(f"{url}/kodi/resume", timeout=2)

monitor = KodiMonitor()
while not monitor.abortRequested():
    monitor.waitForAbort(10)
```

---

## Tjenesteoversikt — Fase 3

| Tjeneste | Port | Avhenger av |
|---|---|---|
| stueos-denon | 8041 | DENON_HOST i stueos.env |
| stueos-bluesound | 8042 | BLUESOUND_HOST i stueos.env |
| stueos-homey | 8043 | HOMEY_HOST + HOMEY_TOKEN i stueos.env |
| stueos-kodi-notify | 8085 | RADARR_URL/SONARR_URL (fra Fase 2) |

```bash
# Sjekk status på alle Fase 3-tjenester:
systemctl --user status stueos-denon stueos-bluesound stueos-homey

# Logg:
journalctl --user -u stueos-denon -f
journalctl --user -u stueos-bluesound -f
journalctl --user -u stueos-homey -f
```
