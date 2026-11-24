"""
StueOS Denon AVR Control Service
Wraps denonavr library into a simple REST API for Kodi and other integrations.
"""
import asyncio
import os
from fastapi import FastAPI
import denonavr

app = FastAPI(title="StueOS Denon Control")
AVR_HOST = os.getenv("DENON_HOST", "192.168.1.X")
avr = None


@app.on_event("startup")
async def startup():
    global avr
    avr = denonavr.DenonAVR(AVR_HOST)
    await avr.async_setup()


@app.get("/status")
async def status():
    await avr.async_update()
    return {"power": avr.power, "volume": avr.volume, "muted": avr.muted, "input": avr.input_func}


@app.post("/power/{state}")
async def power(state: str):
    if state == "on":
        await avr.async_power_on()
    else:
        await avr.async_power_off()
    return {"ok": True}


@app.post("/volume/{level}")
async def set_volume(level: float):
    await avr.async_set_volume(level)
    return {"volume": level}


@app.post("/input/{source}")
async def set_input(source: str):
    await avr.async_set_input_func(source)
    return {"input": source}


@app.post("/mute/{state}")
async def mute(state: str):
    if state == "on":
        await avr.async_mute(True)
    else:
        await avr.async_mute(False)
    return {"ok": True}
