# StueOS Fase 4 — AirPlay 2, Chromecast og Kodi-profiler

Forutsetter at Fase 1–3 er fullført.

---

## #23 AirPlay 2 — UxPlay

UxPlay er installert i StueOS-imaget og kjøres som systemtjeneste. Maskinen vises
som **"StueOS"** på alle Apple-enheter i nettverket.

### Slik bruker du det

1. iPhone/iPad/Mac: Trykk på AirPlay-ikonet i Kontrollsenter eller en app
2. Velg **StueOS** fra listen
3. Video, musikk og speiling streames til TV-en

### Konfigurasjon (drop-in)

Innstillingene ligger i `/usr/lib/systemd/system/uxplay.service.d/10-stueos.conf`:

```ini
ExecStart=/usr/bin/uxplay -n "StueOS" -nh -async 2 -fps 60
```

Bytt ut `StueOS` med ønsket visningsnavn. For å endre etter installasjon:

```bash
# Rediger drop-in midlertidig (tilbakestilles ved OTA-oppdatering):
sudo systemctl edit uxplay.service

# Legg til:
[Service]
ExecStart=
ExecStart=/usr/bin/uxplay -n "Stue-TV" -nh -async 2
```

### Feilsøking

```bash
# Status:
systemctl status uxplay

# Logg:
journalctl -u uxplay -f

# Restart:
sudo systemctl restart uxplay

# Test mDNS-annonsering (må være synlig):
avahi-browse -at | grep uxplay
```

**Vanlige problemer:**
- Ikke synlig på Apple-enheter → sjekk `avahi-daemon` kjører: `systemctl status avahi-daemon`
- Dårlig lyd-synk → prøv `-async 0` eller `-async 4` i drop-in-konfigen
- 4K HDR → UxPlay støtter ikke 4K fra iPhone; bruk Kodi/Plex for 4K

---

## #24 Chromecast — go2tv

go2tv lar deg caste lokal video og musikk fra StueOS til en Chromecast-enhet
(TV med Chromecast built-in, Google TV, Chromecast-dongle, o.l.).

### Web-grensesnitt

go2tv kjører som tjeneste med et web-grensesnitt:

```
http://<stueos-ip>:3000
```

Åpne dette i en nettleser (telefon, nettbrett eller PC i nettverket) for å
bla gjennom og caste filer fra mediebiblioteket.

### Bruk fra kommandolinje

```bash
# List tilgjengelige Chromecast-enheter:
go2tv -l

# Cast en fil direkte:
go2tv -t "<Enhetsnavn>" -v "/mnt/media/filmer/Inception.mkv"

# Cast med undertekster:
go2tv -t "<Enhetsnavn>" -v "/mnt/media/filmer/film.mkv" -s "/mnt/media/filmer/film.srt"
```

### Tjenestestatus

```bash
systemctl status go2tv
journalctl -u go2tv -f
```

### Støttede filformater

go2tv støtter alle formater Chromecast-enheten kan spille nativt:
MP4 (H.264), WebM, Ogg. For MKV/HEVC/HDR — bruk Kodi eller Plex istedenfor.

---

## #25 Kodi brukerprofiler med PIN

Kodi støtter opptil 4 profiler med egne bibliotek, addons og PIN-lås.

### Oppsett via veiviseren

1. Kjør veiviseren (Steg 5 → Profiler) og opprett profilene dine
2. Kopier `profiles.xml` fra "Ferdig"-fanen til `~/.config/stueos/profiles.xml`
3. Kjør `setup.sh` — det kopierer profiles.xml til `~/.kodi/userdata/`

### Manuell installasjon

```bash
# Plasser profiles.xml:
cp profiles.xml ~/.kodi/userdata/profiles.xml

# Restart Kodi for å aktivere profiler:
systemctl --user restart kodi  # eller start Kodi manuelt
```

### PIN-låsing i Kodi

Etter at profiles.xml er aktivert:  
Kodi → Brukerprofiler → Velg profil → Innstillinger → Sett låsetype: Numerisk PIN

**Obs:** PIN-kode satt i veiviseren lagres direkte i profiles.xml som klartekst (Kodi-standard).
Ikke bruk bankpinkoder eller andre sensitive kombinasjoner.

### Automatisk profilvalg ved oppstart

Kodi kan vise profilvalg ved oppstart (nyttig for barnevennlig modus):

Kodi → Innstillinger → Profiler → Lås tidsavbrudd: "Alltid be om profil"

### Profil-spesifikke Kodi-innstillinger

Hver profil lagrer egne innstillinger under `~/.kodi/userdata/<profilnavn>/`:

```
~/.kodi/userdata/
  masterprofile/          ← Admin-profil (Profil 1)
  Barn/                   ← Eksempel: barneprofil med 7+ filter
  Hjem/                   ← Standard-profil
```

---

## Tjenesteoversikt — Fase 4

| Tjeneste | Type | Beskrivelse |
|---|---|---|
| uxplay | system | AirPlay 2-mottaker — vises som "StueOS" på Apple-enheter |
| avahi-daemon | system | mDNS — nødvendig for at AirPlay og go2tv er synlige |
| go2tv | system | Chromecast-caster, web UI: port 3000 |

```bash
# Sjekk alle:
systemctl status uxplay avahi-daemon go2tv

# UxPlay test: åpne AirPlay på iPhone og se etter "StueOS"
# go2tv test: åpne http://<stueos-ip>:3000 i nettleser
```
