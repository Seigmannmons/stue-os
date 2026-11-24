"""
StueOS Kodi Notify — webhook-mottaker for Radarr/Sonarr
Tar imot JSON-webhooks og viser OSD-varsler i Kodi via JSONRPC.

Konfigurasjon via miljøvariabler (fra kodi-notify.env):
  KODI_HOST    = localhost
  KODI_PORT    = 8080   (Kodi JSONRPC HTTP-port)
  KODI_USER    = kodi
  KODI_PASS    = (tomt = ingen autentisering)
  SERVICE_PORT = 8085

Radarr/Sonarr: Settings → Connect → Webhook
  URL: http://localhost:8085/notify
  Trigger: On Download, On Upgrade
"""

import os
import httpx
import logging
from fastapi import FastAPI, Request

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("kodi-notify")

KODI_HOST = os.getenv("KODI_HOST", "localhost")
KODI_PORT = int(os.getenv("KODI_PORT", "8080"))
KODI_USER = os.getenv("KODI_USER", "kodi")
KODI_PASS = os.getenv("KODI_PASS", "")
SERVICE_PORT = int(os.getenv("SERVICE_PORT", "8085"))

KODI_RPC = f"http://{KODI_HOST}:{KODI_PORT}/jsonrpc"

app = FastAPI(title="StueOS Kodi Notify")


def _rpc_auth() -> tuple[str, str] | None:
    return (KODI_USER, KODI_PASS) if KODI_PASS else None


async def show_notification(title: str, message: str, image: str = "DefaultVideoPlaylists.png") -> bool:
    payload = {
        "jsonrpc": "2.0",
        "method": "GUI.ShowNotification",
        "params": {
            "title": title,
            "message": message,
            "image": image,
            "displaytime": 6000,
        },
        "id": 1,
    }
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            auth = _rpc_auth()
            r = await client.post(KODI_RPC, json=payload, auth=auth)
            r.raise_for_status()
            log.info("Kodi-varsel sendt: %s — %s", title, message)
            return True
    except Exception as exc:
        log.warning("Kodi JSONRPC feilet: %s", exc)
        return False


def _parse_radarr(body: dict) -> tuple[str, str]:
    event = body.get("eventType", "")
    movie = body.get("movie", {}).get("title", "Ukjent film")
    year = body.get("movie", {}).get("year", "")
    quality = body.get("movieFile", {}).get("quality", {}).get("quality", {}).get("name", "")

    if event == "Download":
        title = "Film klar 🎬"
        msg = f"{movie} ({year})"
        if quality:
            msg += f" — {quality}"
    elif event == "Grab":
        title = "Film lastes ned"
        msg = f"{movie} ({year})"
    else:
        title = f"Radarr: {event}"
        msg = movie

    return title, msg


def _parse_sonarr(body: dict) -> tuple[str, str]:
    event = body.get("eventType", "")
    series = body.get("series", {}).get("title", "Ukjent serie")
    ep = body.get("episodes", [{}])[0] if body.get("episodes") else {}
    ep_title = ep.get("title", "")
    season = ep.get("seasonNumber", "")
    episode = ep.get("episodeNumber", "")

    ep_ref = f"S{season:02d}E{episode:02d}" if season and episode else ""

    if event == "Download":
        title = "Episode klar 📺"
        msg = f"{series} {ep_ref}"
        if ep_title:
            msg += f" — {ep_title}"
    elif event == "Grab":
        title = "Episode lastes ned"
        msg = f"{series} {ep_ref}"
    else:
        title = f"Sonarr: {event}"
        msg = series

    return title, msg


@app.post("/notify")
async def notify(request: Request):
    body = await request.json()
    source = request.headers.get("X-Webhook-Source", "").lower()
    user_agent = request.headers.get("User-Agent", "").lower()

    if "radarr" in source or "radarr" in user_agent or "movie" in body:
        title, msg = _parse_radarr(body)
    elif "sonarr" in source or "sonarr" in user_agent or "series" in body:
        title, msg = _parse_sonarr(body)
    else:
        title = body.get("eventType", "Varsel")
        msg = str(body.get("movie", body.get("series", {})).get("title", ""))

    log.info("Webhook mottatt — %s: %s", title, msg)
    ok = await show_notification(title, msg)
    return {"ok": ok, "title": title, "message": msg}


@app.get("/health")
async def health():
    return {"status": "ok", "kodi": f"{KODI_HOST}:{KODI_PORT}"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=SERVICE_PORT)
