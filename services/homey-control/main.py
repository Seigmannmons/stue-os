"""
StueOS Homey Control Service
Trigger Homey-flyt via Homey Pro lokal REST API.

Konfigurasjon via miljøvariabler (fra homey-control.env):
  HOMEY_HOST              = IP-adresse til Homey Hub
  HOMEY_TOKEN             = Personlig tilgangstoken (my.homey.app → Developer)
  HOMEY_FLOW_FILM_START   = Flow-ID: kjøres når film starter i Kodi
  HOMEY_FLOW_FILM_STOPP   = Flow-ID: kjøres når film stoppes
  HOMEY_FLOW_PAUSE        = Flow-ID: kjøres ved pause
  HOMEY_FLOW_RESUME       = Flow-ID: kjøres ved fortsett
  SERVICE_PORT            = 8043

Kodi kaller disse endepunktene via event-script eller HTTP-addon:
  POST /kodi/play    — film/episode starter
  POST /kodi/stop    — film/episode stoppes
  POST /kodi/pause   — satt på pause
  POST /kodi/resume  — fortsetter etter pause
  POST /flow/{id}    — trigger vilkårlig flow direkte
"""

import logging
import os

import httpx
from fastapi import FastAPI, HTTPException

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("homey-control")

HOMEY_HOST   = os.getenv("HOMEY_HOST", "")
HOMEY_TOKEN  = os.getenv("HOMEY_TOKEN", "")
SERVICE_PORT = int(os.getenv("SERVICE_PORT", "8043"))

FLOW_MAP = {
    "play":   os.getenv("HOMEY_FLOW_FILM_START", ""),
    "stop":   os.getenv("HOMEY_FLOW_FILM_STOPP", ""),
    "pause":  os.getenv("HOMEY_FLOW_PAUSE", ""),
    "resume": os.getenv("HOMEY_FLOW_RESUME", ""),
}

app = FastAPI(title="StueOS Homey Control")


async def _trigger_flow(flow_id: str) -> dict:
    """Trigger en Homey-flyt via lokal REST API."""
    if not HOMEY_HOST:
        raise HTTPException(503, "HOMEY_HOST ikke konfigurert")
    if not HOMEY_TOKEN:
        raise HTTPException(503, "HOMEY_TOKEN ikke konfigurert")
    if not flow_id:
        raise HTTPException(422, "Flow-ID er tomt")

    url = f"http://{HOMEY_HOST}/api/flow/flow/{flow_id}/trigger"
    headers = {"Authorization": f"Bearer {HOMEY_TOKEN}"}

    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.post(url, headers=headers)
            if r.status_code == 404:
                raise HTTPException(404, f"Flow {flow_id} ikke funnet på Homey")
            r.raise_for_status()
        log.info("Flow trigget: %s", flow_id)
        return {"ok": True, "flow_id": flow_id}
    except httpx.ConnectError:
        raise HTTPException(503, f"Homey ikke tilgjengelig på {HOMEY_HOST}")
    except HTTPException:
        raise
    except Exception as exc:
        log.warning("Flow-trigger feilet: %s", exc)
        raise HTTPException(502, str(exc))


# ── Direkte flow-trigger ───────────────────────────────────────────────────

@app.post("/flow/{flow_id}")
async def trigger_flow(flow_id: str):
    """Trigger vilkårlig Homey-flyt via ID."""
    return await _trigger_flow(flow_id)


# ── Kodi-hendelser ─────────────────────────────────────────────────────────

@app.post("/kodi/play")
async def kodi_play(title: str = "", media_type: str = ""):
    """Kalles når Kodi starter avspilling. Trigger 'film starter'-flyten."""
    flow_id = FLOW_MAP["play"]
    if not flow_id:
        log.debug("Ingen flow konfigurert for play — hopper over")
        return {"ok": True, "skipped": True, "reason": "HOMEY_FLOW_FILM_START ikke satt"}
    log.info("Kodi play: %s (%s)", title, media_type)
    return await _trigger_flow(flow_id)


@app.post("/kodi/stop")
async def kodi_stop(title: str = ""):
    """Kalles når Kodi stopper avspilling. Trigger 'film stopper'-flyten."""
    flow_id = FLOW_MAP["stop"]
    if not flow_id:
        return {"ok": True, "skipped": True, "reason": "HOMEY_FLOW_FILM_STOPP ikke satt"}
    log.info("Kodi stop: %s", title)
    return await _trigger_flow(flow_id)


@app.post("/kodi/pause")
async def kodi_pause(title: str = ""):
    """Kalles ved Kodi-pause. Trigger 'pause'-flyten."""
    flow_id = FLOW_MAP["pause"]
    if not flow_id:
        return {"ok": True, "skipped": True, "reason": "HOMEY_FLOW_PAUSE ikke satt"}
    log.info("Kodi pause: %s", title)
    return await _trigger_flow(flow_id)


@app.post("/kodi/resume")
async def kodi_resume(title: str = ""):
    """Kalles når Kodi fortsetter etter pause. Trigger 'fortsett'-flyten."""
    flow_id = FLOW_MAP["resume"]
    if not flow_id:
        return {"ok": True, "skipped": True, "reason": "HOMEY_FLOW_RESUME ikke satt"}
    log.info("Kodi resume: %s", title)
    return await _trigger_flow(flow_id)


# ── Status ─────────────────────────────────────────────────────────────────

@app.get("/status")
async def status():
    """Vis konfigurerte flows og tilkoblingsstatus."""
    configured_flows = {k: bool(v) for k, v in FLOW_MAP.items()}
    connected = False
    if HOMEY_HOST and HOMEY_TOKEN:
        try:
            async with httpx.AsyncClient(timeout=3) as client:
                r = await client.get(
                    f"http://{HOMEY_HOST}/api/",
                    headers={"Authorization": f"Bearer {HOMEY_TOKEN}"},
                )
                connected = r.status_code < 400
        except Exception:
            pass
    return {
        "homey_host":       HOMEY_HOST,
        "connected":        connected,
        "configured_flows": configured_flows,
    }


@app.get("/health")
async def health():
    return {"status": "ok", "homey": HOMEY_HOST}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=SERVICE_PORT)
