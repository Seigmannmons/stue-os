"""
StueOS Denon AVR Control Service
REST API for Denon/Marantz AVR via denonavr library.

Konfigurasjon via miljøvariabler (fra denon-control.env):
  DENON_HOST    = IP-adresse til AVR
  DENON_PORT    = 23 (Telnet, brukes ikke direkte — denonavr bruker HTTP)
  SERVICE_PORT  = 8041
"""

import asyncio
import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
import denonavr

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("denon-control")

DENON_HOST    = os.getenv("DENON_HOST", "")
SERVICE_PORT  = int(os.getenv("SERVICE_PORT", "8041"))

avr: denonavr.DenonAVR | None = None


async def _connect(retries: int = 5, delay: float = 5.0) -> denonavr.DenonAVR:
    for attempt in range(1, retries + 1):
        try:
            a = denonavr.DenonAVR(DENON_HOST)
            await a.async_setup()
            await a.async_update()
            log.info("Koblet til Denon AVR på %s (modell: %s)", DENON_HOST, a.model_name)
            return a
        except Exception as exc:
            log.warning("Forsøk %d/%d feilet: %s", attempt, retries, exc)
            if attempt < retries:
                await asyncio.sleep(delay)
    raise RuntimeError(f"Kunne ikke koble til Denon AVR på {DENON_HOST} etter {retries} forsøk")


@asynccontextmanager
async def lifespan(app: FastAPI):
    global avr
    if not DENON_HOST:
        log.warning("DENON_HOST ikke satt — tjenesten starter i hodeløs modus")
    else:
        try:
            avr = await _connect()
        except RuntimeError as exc:
            log.error("%s", exc)
    yield


app = FastAPI(title="StueOS Denon Control", lifespan=lifespan)


def _require_avr():
    if avr is None:
        raise HTTPException(503, "AVR ikke tilgjengelig")


async def _refresh():
    """Oppdater AVR-tilstand, prøv å koble til på nytt om nødvendig."""
    global avr
    try:
        await avr.async_update()
    except Exception:
        log.warning("AVR-oppdatering feilet — prøver å koble til på nytt")
        try:
            avr = await _connect(retries=2, delay=2.0)
        except RuntimeError:
            raise HTTPException(503, "AVR ikke tilgjengelig")


# ── Statusendepunkter ──────────────────────────────────────────────────────

@app.get("/status")
async def status():
    _require_avr()
    await _refresh()
    return {
        "power":        avr.power,
        "volume_db":    avr.volume,
        "volume_pct":   _db_to_pct(avr.volume),
        "muted":        avr.muted,
        "input":        avr.input_func,
        "sound_mode":   avr.sound_mode,
        "model":        avr.model_name,
        "serial":       avr.serial_number,
    }


@app.get("/sources")
async def sources():
    """List tilgjengelige inngangskilder (modellspesifikt)."""
    _require_avr()
    await _refresh()
    return {
        "current":    avr.input_func,
        "available":  sorted(avr.input_func_list),
    }


@app.get("/sound-modes")
async def sound_modes():
    """List tilgjengelige surroundmodi."""
    _require_avr()
    await _refresh()
    return {
        "current":   avr.sound_mode,
        "available": sorted(avr.sound_mode_list) if hasattr(avr, "sound_mode_list") else [],
    }


# ── Strømkontroll ──────────────────────────────────────────────────────────

@app.post("/power/{state}")
async def power(state: str):
    _require_avr()
    if state == "on":
        await avr.async_power_on()
    elif state == "off":
        await avr.async_power_off()
    else:
        raise HTTPException(400, "state må være 'on' eller 'off'")
    return {"ok": True, "power": state}


@app.post("/mute/{state}")
async def mute(state: str):
    _require_avr()
    if state == "on":
        await avr.async_mute(True)
    elif state == "off":
        await avr.async_mute(False)
    else:
        raise HTTPException(400, "state må være 'on' eller 'off'")
    return {"ok": True, "muted": state == "on"}


# ── Volum ──────────────────────────────────────────────────────────────────

@app.post("/volume/db/{level}")
async def volume_db(level: float):
    """Sett volum i dB (typisk -80 til 0, faktisk maks varierer per modell)."""
    _require_avr()
    await avr.async_set_volume(level)
    return {"volume_db": level, "volume_pct": _db_to_pct(level)}


@app.post("/volume/pct/{pct}")
async def volume_pct(pct: int):
    """Sett volum som prosent (0–100)."""
    _require_avr()
    if not 0 <= pct <= 100:
        raise HTTPException(400, "Prosent må være 0–100")
    db = _pct_to_db(pct)
    await avr.async_set_volume(db)
    return {"volume_pct": pct, "volume_db": db}


@app.post("/volume/up")
async def volume_up():
    _require_avr()
    await avr.async_volume_up()
    await _refresh()
    return {"volume_db": avr.volume, "volume_pct": _db_to_pct(avr.volume)}


@app.post("/volume/down")
async def volume_down():
    _require_avr()
    await avr.async_volume_down()
    await _refresh()
    return {"volume_db": avr.volume, "volume_pct": _db_to_pct(avr.volume)}


# ── Inngang og surroundlyd ─────────────────────────────────────────────────

@app.post("/input/{source}")
async def set_input(source: str):
    _require_avr()
    await avr.async_set_input_func(source)
    return {"input": source}


@app.post("/sound-mode/{mode}")
async def set_sound_mode(mode: str):
    _require_avr()
    try:
        await avr.async_set_sound_mode(mode)
    except Exception as exc:
        raise HTTPException(400, f"Ugyldig surroundmodus: {exc}")
    return {"sound_mode": mode}


# ── Hjelpefunksjoner ───────────────────────────────────────────────────────

def _db_to_pct(db: float | None) -> int | None:
    """Konverter dB (−80–0) til prosent (0–100)."""
    if db is None:
        return None
    return max(0, min(100, int((db + 80) / 80 * 100)))


def _pct_to_db(pct: int) -> float:
    """Konverter prosent (0–100) til dB (−80–0)."""
    return round(-80 + pct * 80 / 100, 1)


@app.get("/health")
async def health():
    return {"status": "ok", "avr": DENON_HOST, "connected": avr is not None}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=SERVICE_PORT)
