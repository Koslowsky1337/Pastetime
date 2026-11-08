local ns = KW
PastimeDB = PastimeDB or {}
PastimeDB.flights = { ["Das Wegekreuz, Brachland > Orgrimmar, Durotar"] = { t = 118, d = "08.11.26" } }
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Pastime")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")
local r = PastimeDB.routes["flug:Das Wegekreuz, Brachland > Orgrimmar, Durotar"]
print("Migration:", r and r.t == 118 and PastimeDB.flights == nil and "OK" or "FEHLER")
print("Einstellungen erhalten:", PastimeDB.settings.autoOpen, PastimeDB.settings.landAlarm, "Sitzung", PastimeDB.logSession)
SlashCmdList.PASTIME("")
print("Fenster:", ns.frame:IsShown(), "Fehler:", #ERRORS_FORWARDED)
