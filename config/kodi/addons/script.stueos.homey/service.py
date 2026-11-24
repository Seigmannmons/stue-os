"""
StueOS Homey Integration for Kodi
Triggers Homey flows on Player.OnPlay, Player.OnStop, Player.OnPause events.

Configure HOMEY_HOST and flow IDs in addon settings.
"""
import xbmc
import xbmcaddon
import xbmcgui
import requests

ADDON = xbmcaddon.Addon()


def get_setting(key):
    return ADDON.getSetting(key)


def trigger_flow(flow_id: str):
    host = get_setting("homey_host")
    token = get_setting("homey_token")
    if not host or not flow_id:
        return
    try:
        requests.put(
            f"http://{host}/api/flow/{flow_id}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=3
        )
    except Exception as e:
        xbmc.log(f"StueOS Homey: failed to trigger flow {flow_id}: {e}", xbmc.LOGWARNING)


class PlayerMonitor(xbmc.Player):
    def onPlayBackStarted(self):
        media_type = xbmc.getInfoLabel("Player.Content")
        if "movie" in media_type.lower():
            trigger_flow(get_setting("flow_movie_start"))
            xbmc.log("StueOS Homey: triggered movie-start flow", xbmc.LOGDEBUG)
        elif "episode" in media_type.lower():
            trigger_flow(get_setting("flow_series_start"))
            xbmc.log("StueOS Homey: triggered series-start flow", xbmc.LOGDEBUG)

    def onPlayBackStopped(self):
        trigger_flow(get_setting("flow_playback_stop"))

    def onPlayBackPaused(self):
        trigger_flow(get_setting("flow_playback_pause"))

    def onPlayBackResumed(self):
        trigger_flow(get_setting("flow_playback_resume"))


monitor = xbmc.Monitor()
player = PlayerMonitor()

while not monitor.abortRequested():
    monitor.waitForAbort(10)
