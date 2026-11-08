-- Pastime: Sprachen. Die englischen Texte sind zugleich die Schlüssel;
-- andere Sprachen überschreiben sie (siehe deDE.lua). Fehlt eine
-- Übersetzung, erscheint einfach der englische Text.
local ADDON, ns = ...

ns.LOCALE = GetLocale and GetLocale() or "enUS"
ns.L = setmetatable({}, { __index = function(_, key) return key end })

-- Tasten, die je nach Sprache anders belegt sind
ns.KEYS = { hit = "H", stand = "S", double = "D" }          -- Goblin-Blackjack
ns.KEYBOARD_ROWS = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }  -- Wortraten
