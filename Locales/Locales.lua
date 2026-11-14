-- Pastime: Sprachen. Die englischen Texte sind zugleich die Schlüssel;
-- andere Sprachen überschreiben sie (siehe deDE.lua). Fehlt eine
-- Übersetzung, erscheint einfach der englische Text.
local ADDON, ns = ...

ns.LOCALE = GetLocale and GetLocale() or "enUS"
ns.L = setmetatable({}, { __index = function(_, key) return key end })

-- Zahlen und Datum: 1,054,000 und 2026-11-14 (deDE: 1.054.000 und 14.11.26)
ns.THOUSANDS = ","
ns.DATE_FORMAT = "%Y-%m-%d"

-- Tasten, die je nach Sprache anders belegt sind
ns.KEYS = { hit = "H", stand = "S", double = "D" }          -- Goblin-Blackjack
ns.KEYBOARD_ROWS = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }  -- Wortraten
