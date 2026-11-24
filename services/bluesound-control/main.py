"""
StueOS Bluesound / BluOS Control Service
REST API proxy for Bluesound player control via BluOS HTTP API (port 11000).
Returnerer JSON-svar (parser BluOS XML internt).

Konfigurasjon via miljøvariabler:
  BLUESOUND_HOST = IP-adresse til Bluesound-spilleren
  SERVICE_PORT   = 8042
"""

import logging
import os
from xml.etree import ElementTree as ET

import httpx
from fastapi import FastAPI, HTTPException

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("bluesound-control")

BLUESOUND_HOST = os.getenv("BLUESOUND_HOST", "")
SERVICE_PORT   = int(os.getenv("SERVICE_PORT", "8042"))
BLUOS_BASE     = f"http://{BLUESOUND_HOST}:11000"

app = FastAPI(title="StueOS Bluesound Control")


async def _bluos_get(path: str, params: dict | None = None) -> ET.Element:
    """Utfør GET til BluOS API og returner parsert XML-element."""
    url = f"{BLUOS_BASE}/{path}"
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(url, params=params)
            r.raise_for_status()
        return ET.fromstring(r.text)
    except httpx.ConnectError:
        raise HTTPException(503, f"Bluesound ikke tilgjengelig på {BLUESOUND_HOST}")
    except ET.ParseError as exc:
        raise HTTPException(502, f"Ugyldig svar fra Bluesound: {exc}")


def _xml_to_dict(el: ET.Element) -> dict:
    """Konverter XML-element til flat dict."""
    return {child.tag: child.text for child in el}


# ── Status ─────────────────────────────────────────────────────────────────

@app.get("/status")
async def status():
    el = await _bluos_get("Status")
    return {
        "state":    el.findtext("state"),
        "title":    el.findtext("title1"),
        "artist":   el.findtext("title2"),
        "album":    el.findtext("title3"),
        "service":  el.findtext("service"),
        "volume":   _safe_int(el.findtext("volume")),
        "muted":    el.findtext("mute") == "1",
        "shuffle":  el.findtext("shuffle") == "1",
        "repeat":   el.findtext("repeat"),
        "quality":  el.findtext("quality"),
        "can_seek": el.findtext("canSeek") == "1",
        "secs":     _safe_int(el.findtext("secs")),
        "total_secs": _safe_int(el.findtext("totlen")),
    }


# ── Avspillingskontroll ────────────────────────────────────────────────────

@app.post("/play")
async def play():
    el = await _bluos_get("Play")
    return {"state": el.findtext("state", "play")}


@app.post("/pause")
async def pause():
    el = await _bluos_get("Pause")
    return {"state": el.findtext("state", "pause")}


@app.post("/stop")
async def stop():
    el = await _bluos_get("Stop")
    return {"state": "stop"}


@app.post("/skip")
async def skip():
    """Hopp til neste spor."""
    el = await _bluos_get("Skip")
    return {"ok": True}


@app.post("/back")
async def back():
    """Hopp tilbake til forrige spor."""
    el = await _bluos_get("Back")
    return {"ok": True}


@app.post("/seek/{seconds}")
async def seek(seconds: int):
    """Søk til posisjon i sekunder."""
    el = await _bluos_get("Play", {"seek": seconds})
    return {"secs": seconds}


# ── Volum ──────────────────────────────────────────────────────────────────

@app.post("/volume/{level}")
async def volume(level: int):
    """Sett volum (0–100)."""
    if not 0 <= level <= 100:
        raise HTTPException(400, "Volum må være 0–100")
    el = await _bluos_get("Volume", {"level": level})
    return {"volume": _safe_int(el.findtext("volume"), level)}


@app.post("/volume/up")
async def volume_up():
    st = await _bluos_get("Status")
    cur = _safe_int(st.findtext("volume"), 50)
    new = min(100, cur + 5)
    el = await _bluos_get("Volume", {"level": new})
    return {"volume": _safe_int(el.findtext("volume"), new)}


@app.post("/volume/down")
async def volume_down():
    st = await _bluos_get("Status")
    cur = _safe_int(st.findtext("volume"), 50)
    new = max(0, cur - 5)
    el = await _bluos_get("Volume", {"level": new})
    return {"volume": _safe_int(el.findtext("volume"), new)}


@app.post("/mute/{state}")
async def mute(state: str):
    mute_val = "1" if state == "on" else "0"
    el = await _bluos_get("Volume", {"mute": mute_val})
    return {"muted": state == "on"}


# ── Shuffle og repeat ──────────────────────────────────────────────────────

@app.post("/shuffle/{state}")
async def shuffle(state: str):
    val = "1" if state == "on" else "0"
    el = await _bluos_get("Shuffle", {"state": val})
    return {"shuffle": state == "on"}


@app.post("/repeat/{mode}")
async def repeat(mode: str):
    """Mode: 0=av, 1=alle, 2=ett spor."""
    el = await _bluos_get("Repeat", {"state": mode})
    return {"repeat": mode}


# ── Forhåndsvalg (Presets) ─────────────────────────────────────────────────

@app.get("/presets")
async def presets():
    """Hent alle lagrede forhåndsvalg."""
    el = await _bluos_get("Presets")
    items = []
    for preset in el.findall("preset"):
        items.append({
            "id":    preset.get("id"),
            "name":  preset.get("name"),
            "image": preset.get("image"),
        })
    return {"presets": items}


@app.post("/preset/{preset_id}")
async def play_preset(preset_id: int):
    """Start forhåndsvalg (1-basert indeks)."""
    el = await _bluos_get("Preset", {"id": preset_id})
    return {"ok": True, "preset": preset_id}


# ── Deezer via BluOS ───────────────────────────────────────────────────────

@app.get("/deezer/browse")
async def deezer_browse(section: str = ""):
    """Bla gjennom Deezer-biblioteket via BluOS."""
    params = {"service": "Deezer"}
    if section:
        params["id"] = section
    el = await _bluos_get("Browse", params)
    items = []
    for item in el.findall("item"):
        items.append({
            "id":       item.get("serviceID") or item.get("id"),
            "name":     item.get("text") or item.findtext("title"),
            "type":     item.get("type"),
            "image":    item.get("image"),
            "play_url": item.get("playURL"),
        })
    return {"service": "Deezer", "items": items}


@app.post("/deezer/play-flow")
async def deezer_flow():
    """Start Deezer Flow (personlig mikseplass)."""
    el = await _bluos_get("Play", {"url": "deezer://flow"})
    return {"ok": True, "source": "deezer-flow"}


@app.post("/deezer/play-url")
async def deezer_play_url(url: str):
    """Start Deezer-innhold via URL (deezer://playlist/xxx, deezer://album/xxx)."""
    el = await _bluos_get("Play", {"url": url})
    return {"ok": True, "url": url}


# ── Queue ──────────────────────────────────────────────────────────────────

@app.get("/queue")
async def queue():
    el = await _bluos_get("Playlist")
    items = []
    for song in el.findall("song"):
        items.append({
            "id":     song.get("id"),
            "title":  song.findtext("title"),
            "artist": song.findtext("artist"),
            "album":  song.findtext("album"),
            "image":  song.findtext("image"),
            "secs":   _safe_int(song.findtext("secs")),
        })
    return {"queue": items}


# ── URL-avspilling ─────────────────────────────────────────────────────────

@app.post("/play-url")
async def play_url(url: str):
    """Start avspilling fra en URL (stream, lokal fil)."""
    el = await _bluos_get("Play", {"url": url})
    return {"ok": True, "url": url}


# ── Helse ──────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    try:
        el = await _bluos_get("Status")
        return {"status": "ok", "bluesound": BLUESOUND_HOST, "player_state": el.findtext("state")}
    except HTTPException:
        return {"status": "unavailable", "bluesound": BLUESOUND_HOST}


# ── Hjelpefunksjoner ───────────────────────────────────────────────────────

def _safe_int(val: str | None, default: int = 0) -> int | None:
    if val is None:
        return None
    try:
        return int(val)
    except ValueError:
        return default


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=SERVICE_PORT)
