"""
StueOS Homey Integration for Kodi
Kaller homey-control-tjenesten (port 8043) ved Kodi avspillingshendelser.
Tjenesten håndterer Homey-kommunikasjon og konfigurasjon.
"""
import urllib.request
import xbmc

HOMEY_SVC = "http://localhost:8043"


def _post(path: str) -> None:
    try:
        req = urllib.request.Request(
            f"{HOMEY_SVC}{path}",
            method="POST",
            headers={"Content-Type": "application/json"},
            data=b"{}",
        )
        urllib.request.urlopen(req, timeout=2)
    except Exception as exc:
        xbmc.log(f"[StueOS] homey-control {path} feilet: {exc}", xbmc.LOGWARNING)


class StueOSPlayer(xbmc.Player):
    def onPlayBackStarted(self):
        _post("/kodi/play")

    def onPlayBackStopped(self):
        _post("/kodi/stop")

    def onPlayBackPaused(self):
        _post("/kodi/pause")

    def onPlayBackResumed(self):
        _post("/kodi/resume")


monitor = xbmc.Monitor()
player = StueOSPlayer()

while not monitor.abortRequested():
    monitor.waitForAbort(10)
