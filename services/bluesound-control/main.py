"""
StueOS Bluesound / BluOS Control Service
REST API proxy for Bluesound player control via BluOS HTTP API (port 11000).
"""
import os
import httpx
from fastapi import FastAPI

app = FastAPI(title="StueOS Bluesound Control")
BLUESOUND_HOST = os.getenv("BLUESOUND_HOST", "192.168.1.Y")
BLUOS_BASE = f"http://{BLUESOUND_HOST}:11000"


async def bluos(path: str, params: dict = None):
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{BLUOS_BASE}/{path}", params=params, timeout=5)
        return r.text


@app.get("/status")
async def status():
    return {"xml": await bluos("Status")}


@app.post("/play")
async def play():
    return {"xml": await bluos("Play")}


@app.post("/pause")
async def pause():
    return {"xml": await bluos("Pause")}


@app.post("/volume/{level}")
async def volume(level: int):
    return {"xml": await bluos("Volume", {"level": level})}


@app.get("/browse")
async def browse(service: str = "Deezer"):
    return {"xml": await bluos("Browse", {"service": service})}


@app.post("/play-url")
async def play_url(url: str):
    return {"xml": await bluos("Play", {"url": url})}
