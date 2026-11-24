# Fase 5 — Justfile, gjenoppretting og OTA-oppdateringer

Fase 5 fullfører driftsverktøyene: `just`-oppskrifter for daglig bruk, en komplett gjenopprettingsguide og automatiske OTA-oppdateringer.

---

## #27 — Justfile

`just` er installert som del av StueOS-imaget. Justfile-en ligger både i kildetreet (`build/Justfile`) og installert på systemet (`/usr/share/stueos/Justfile`).

### Installere just

```bash
# just er inkludert i StueOS-imaget; tilgjengelig etter installasjon
just --version
```

### Alle oppskrifter

```bash
just          # List alle tilgjengelige oppskrifter
```

| Oppskrift | Beskrivelse |
|-----------|-------------|
| `just firstboot` | Kjør første gangs oppsett (Flatpak-apper, temaer) |
| `just setup` | Kjør installeringsveiviseren på nytt |
| `just check` | Sjekk hardware: NVIDIA, Vulkan, iMon VFD, LIRC, Kodi |
| `just info` | Vis systeminfo: image-versjon, IP, tjenestestatus |
| `just status` | Detaljert status for alle StueOS-tjenester |
| `just restart` | Restart alle tjenester |
| `just restart-denon` | Restart Denon AVR-tjeneste |
| `just restart-bluesound` | Restart Bluesound-tjeneste |
| `just restart-homey` | Restart Homey-tjeneste |
| `just restart-kodi-notify` | Restart Kodi-notify-tjeneste |
| `just restart-go2tv` | Restart go2tv |
| `just restart-uxplay` | Restart UxPlay |
| `just logs` | Vis logg for alle tjenester (følg) |
| `just logs-denon` | Vis Denon-logg |
| `just logs-bluesound` | Vis Bluesound-logg |
| `just logs-homey` | Vis Homey-logg |
| `just logs-kodi-notify` | Vis kodi-notify-logg |
| `just logs-go2tv` | Vis go2tv-logg |
| `just logs-uxplay` | Vis UxPlay-logg |
| `just test` | Helsekontroll for alle tjenester |
| `just test-notify` | Send test-varsel til Kodi OSD |
| `just test-denon` | Test Denon AVR-tilkobling |
| `just test-bluesound` | Test Bluesound-tilkobling |
| `just test-homey` | Test Homey-tilkobling |
| `just kodi` | Start Kodi (Flatpak) |
| `just kodi-log` | Vis Kodi-logg (siste 100 linjer) |
| `just kodi-kill` | Stopp Kodi |
| `just kodi-reset` | Tilbakestill Kodi-brukerdata ⚠️ |
| `just backup` | Lag sikkerhetskopi |
| `just restore BACKUP` | Gjenopprett fra sikkerhetskopi |
| `just backups` | List tilgjengelige sikkerhetskopier |
| `just update-check` | Sjekk om OTA-oppdatering er tilgjengelig |
| `just update-now` | Last ned og installer OTA-oppdatering |
| `just rebase` | Rebase til siste image fra GHCR |
| `just reboot` | Start på nytt |
| `just rollback` | Angre siste OTA-oppdatering |
| `just enable-auto-update` | Aktiver ukentlig auto-oppdatering |
| `just disable-auto-update` | Deaktiver ukentlig auto-oppdatering |
| `just go2tv` | Åpne go2tv web UI |
| `just ports` | Vis alle StueOS-nettverkstjenester og porter |

---

## #28 — Gjenoppretting

### Sikkerhetskopier

StueOS tar ikke automatisk sikkerhetskopier — du må starte dem manuelt:

```bash
just backup
```

Dette lager en tidsstemplet tarball i `~/stueos-backups/` med:
- `~/.config/stueos/` — StueOS-konfigurasjon og stueos.env
- `~/.kodi/userdata/` — Kodi-brukerdata (bibliotek, addons, innstillinger)
- `~/.var/app/tv.kodi.Kodi/data/userdata/` — Kodi Flatpak-brukerdata

Anbefalt frekvens: etter hvert du konfigurerer noe nytt, og månedlig ellers.

```bash
just backups   # List alle sikkerhetskopier
```

### Gjenopprette fra sikkerhetskopi

```bash
just restore ~/stueos-backups/stueos-backup-20250101-120000.tar.gz
```

**Merk:** Eksisterende konfig overskrives. Restart tjenestene etterpå:

```bash
just restart
```

### Gjenopprette Kodi-bibliotek

Kodi-biblioteket (filmer, TV-serier) er lagret i databasefiler i `~/.kodi/userdata/Database/`. Disse er med i sikkerhetskopien.

Hvis biblioteket er korrupt uten sikkerhetskopi:
1. Kjør `just kodi-reset` for å slette brukerdata
2. Start Kodi og rekonfigurer kilder
3. La Kodi skanne biblioteket på nytt

### Nødsituasjon: Kodi starter ikke

```bash
# Sjekk loggen
just kodi-log

# Restart med fri grafikkminne
just kodi-kill
just kodi

# Tilbakestill alle innstillinger (siste utvei)
just kodi-reset
```

### Nødsituasjon: Tjeneste svarer ikke

```bash
# Oversikt over alle tjenester
just status

# Restart problemtjeneste
just restart-denon       # eller bluesound / homey / kodi-notify / go2tv / uxplay

# Sjekk detaljert logg
just logs-denon

# Sjekk om porten er i bruk
ss -tlnp | grep 8041
```

### Nødsituasjon: Kan ikke koble til Denon AVR

1. Sjekk at AVR er slått på og koblet til nettverket
2. Finn AVR-IP: `arp -n | grep -i denon` eller sjekk ruteren
3. Oppdater IP i `/etc/stueos/services/denon-control.env`
4. `just restart-denon`

### Nødsituasjon: Kan ikke koble til Bluesound

1. Sjekk at NODE er på nettverket: `ping <bluesound-ip>`
2. Test BluOS API direkte: `curl http://<bluesound-ip>:11000/Status`
3. Oppdater IP i `/etc/stueos/services/bluesound-control.env`
4. `just restart-bluesound`

### Systemnivå: Feil etter oppdatering

Hvis systemet oppfører seg feil etter en OTA-oppdatering:

```bash
# Boot til forrige image (kan gjøres fra terminalmenyen)
just rollback
just reboot
```

Etter reboot kjøres det forrige image. For å bekrefte:
```bash
rpm-ostree status
```

Rapporter problemet og vent på neste oppdatering før du rebaser tilbake.

### Systemnivå: Kritisk feil — reinstallasjon

Hvis systemet er ubrukbart og rollback ikke hjelper:

1. Last ned Bazzite ISO fra https://bazzite.gg
2. Boot fra USB
3. Installer Bazzite på nytt
4. Rebase til StueOS:
   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/seigmannmons/stueos:latest
   systemctl reboot
   ```
5. Kjør oppsett:
   ```bash
   just firstboot
   just setup
   ```
6. Gjenopprett konfig fra sikkerhetskopi:
   ```bash
   just restore ~/stueos-backups/stueos-backup-<dato>.tar.gz
   just restart
   ```

---

## #29 — OTA-oppdateringer

StueOS-imaget bygges automatisk på GitHub Actions når ny kode pushes til `main`. Oppdateringer distribueres som OCI-container-lag via GitHub Container Registry (GHCR).

### Manuell oppdatering

```bash
just update-check   # Sjekk om oppdatering finnes
just update-now     # Last ned og installer (krever omstart)
just reboot         # Aktiver ny versjon
```

### Automatisk oppdatering (opt-in)

Automatisk oppdatering er **ikke** aktivert som standard — det er uønsket at systemet endrer seg midt i en film. Aktiver det eksplisitt:

```bash
just enable-auto-update
```

Dette aktiverer `stueos-update.timer` som kjører **mandag kl. 03:00** (±30 min tilfeldig forsinkelse). Timeren:
1. Sjekker om ny versjon er tilgjengelig
2. Laster ned oppdatering stille i bakgrunnen
3. Sender ntfy-varsling: "StueOS: Oppdatering klar 🔄"
4. **Starter ikke på nytt automatisk** — du velger selv når du rebooter

```bash
just disable-auto-update   # Deaktiver igjen
systemctl status stueos-update.timer   # Sjekk timerstatus
```

### Rebase til siste image manuelt

```bash
just rebase    # rpm-ostree rebase ostree-unverified-registry:ghcr.io/seigmannmons/stueos:latest
just reboot
```

### Angre en oppdatering

rpm-ostree beholder alltid forrige image på disk:

```bash
just rollback   # Forbered oppstart fra forrige image
just reboot
```

### Sjekk hvilken versjon som kjører

```bash
just info
# eller:
rpm-ostree status --booted
```

### Bygg lokalt for testing

```bash
# Fra kildetreet:
podman build -t stueos-test -f build/Containerfile .

# Rebase til lokal build:
rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/stueos-test:latest
systemctl reboot
```
