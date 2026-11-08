-- Layout-Prüfer (/pastime layout) mit nachgebauten Rahmen (die Attrappe kennt keine Positionen)
-- Aufruf: python3 tests/run.py . tests/layout.lua
local ns = KW
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Pastime")

local function obj(kind, l, r, t, b, extra)
    local o = { kind = kind, l = l, r = r, t = t, b = b, regions = {}, children = {} }
    for k, v in pairs(extra or {}) do o[k] = v end
    function o:GetLeft() return self.l end
    function o:GetRight() return self.r end
    function o:GetTop() return self.t end
    function o:GetBottom() return self.b end
    function o:GetObjectType() return self.kind end
    function o:IsVisible() return true end
    function o:GetText() return self.text end
    function o:GetStringWidth() return self.sw or (self.r - self.l) end
    function o:GetStringHeight() return self.sh or (self.t - self.b) end
    function o:GetJustifyH() return self.jh or "CENTER" end
    function o:GetJustifyV() return "MIDDLE" end
    function o:IsTruncated() return self.trunc end
    function o:GetRegions() return unpack(self.regions) end
    function o:GetChildren() return unpack(self.children) end
    return o
end

local root = obj("Frame", 0, 400, 400, 0)
-- Zeile: Beschriftung links, Wert rechts in voller Breite -> keine Überlappung
table.insert(root.regions, obj("FontString", 10, 390, 300, 286, { text = "Länge", sw = 40, jh = "LEFT" }))
table.insert(root.regions, obj("FontString", 10, 390, 300, 286, { text = "12", sw = 14, jh = "RIGHT" }))
-- ragt rechts hinaus
table.insert(root.regions, obj("FontString", 300, 420, 200, 186, { text = "zu lang" }))
-- abgeschnitten
table.insert(root.regions, obj("FontString", 10, 100, 150, 136, { text = "gekürzt", trunc = true }))
-- Knopf mit zu langem Text
local btn = obj("Button", 100, 230, 60, 38, { text = "Beenden & werten" })
table.insert(btn.regions, obj("FontString", 90, 240, 56, 42, { text = "Beenden & werten" }))
table.insert(root.children, btn)
-- Text überdeckt den Knopf
table.insert(root.regions, obj("FontString", 120, 200, 70, 50, { text = "Hinweis" }))
-- Scrollbereich: unten herauslaufen ist erlaubt
local sf = obj("ScrollFrame", 0, 400, 380, 320)
local child = obj("Frame", 0, 400, 380, 0)
table.insert(child.regions, obj("FontString", 10, 390, 340, 100, { text = "lange Beschreibung" }))
table.insert(sf.children, child)
table.insert(root.children, sf)

local f = ns.LayoutCheck({ root })
local all = table.concat(f, "\n")
check(not all:find("Länge") and not all:find('"12"'), "Zeile links/rechts ohne Fehlalarm")
check(all:find('sticks out of [^\n]*"zu lang"'), "überstehender Text erkannt")
check(all:find('truncated: "gekürzt"'), "abgeschnittener Text erkannt")
check(all:find('sticks out of "Beenden & werten": "Beenden & werten"'), "Knopftext zu breit erkannt")
check(all:find('overlap: "Hinweis" / "Beenden & werten"'), "Überlappung erkannt")
check(not all:find("lange Beschreibung"), "Scrollbereich darf nach unten weiterlaufen")
check(#f == 4, "genau 4 Funde (" .. #f .. "):\n" .. all)
local logged = 0
for _, e in ipairs(PastimeDB.log) do if e.c == "layout" and e.l == "W" then logged = logged + 1 end end
check(logged == 4, "4 Warnungen im Protokoll")
print(("Layout-Tests: %d ok, %d Fehler"):format(passes, fails))
