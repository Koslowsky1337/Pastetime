-- Mehrspieler-Grundlage: Kodierung, Prüfung, Mengenbremse, Sitzungsregeln
local ns = KW
local C = ns.Comm
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. msg) end
end
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "Pastime")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")

check(C.ENABLED == false and not C.registered, "multiplayer is off in 1.0")
check(#C.PREFIX <= 16, "prefix fits 16 characters")
check(C.Send("HELLO", "WHISPER", "Thrall", 100) == false, "nothing is sent while disabled")

-- Kodieren / Dekodieren
local m = C.Encode("INVITE", "s1", "snake", 12345, 120)
check(m == "PT1^INVITE^s1^snake^12345^120", "encode invite: " .. tostring(m))
local kind, f = C.Decode(m)
check(kind == "INVITE" and f[2] == "snake" and f[3] == 12345, "decode invite")
check(C.Encode("INVITE", "s1", "sn|ake", 1, 1) == nil, "no escape codes in fields")
check(C.Encode("MOVE", "s1", 1) == nil, "wrong field count refused")
check(C.Encode("EVIL", "x") == nil, "unknown type refused")

-- Bösartige oder kaputte Eingaben
local bad = {
    "", "PT1", "PT2^HELLO^100", "PT1^HELLO", "PT1^HELLO^abc", "PT1^HELLO^100^1", "PT1^RUN^os.exit()",
    "PT1^HELLO^99999", "PT1^MOVE^s1^0^1", "PT1^INVITE^s1^snake^1^9999", "PT1^INVITE^s1^|cffff0000x^1^1",
    "PT1^RESULT^s1^-5", "PT1^HELLO^1e9", ("PT1^HELLO^" .. string.rep("1", 300)), "PT1^HELLO^10\n0",
    "PT1^ROLL^s1^0", "PT1^ROLL^s1^101", "PT1^INVITE^s1^snake^0x10^5",
}
for _, b in ipairs(bad) do
    check(C.Decode(b) == nil, "rejects " .. b:sub(1, 40))
end
check(C.Sanitize("|cffff0000Böse|r\nZeile") == "cffff0000Böserrzeile" or not C.Sanitize("|cff|r"):find("|"), "sanitize removes |")
check(not C.Sanitize("a\0b\tc"):find("%c"), "sanitize removes control characters")

-- Kanal, Absender, Mengenbremse
C._Reset()
local hello = C.Encode("HELLO", 100)
check(C.Accept("OtherAddon", hello, "WHISPER", "Thrall") == nil, "foreign prefix")
check(C.Accept(C.PREFIX, hello, "CHANNEL", "Thrall") == nil, "public channels ignored")
check(C.Accept(C.PREFIX, hello, "WHISPER", "Guenther") == nil, "own messages ignored")
C_FriendList = { IsIgnored = function(n) return n == "Troll" end }
check(C.Accept(C.PREFIX, hello, "WHISPER", "Troll") == nil, "ignored players dropped")
local okCount = 0
for _ = 1, 20 do if C.Accept(C.PREFIX, hello, "WHISPER", "Spammer") then okCount = okCount + 1 end end
check(okCount == 6, "per-sender limit (6 burst), got " .. okCount)
NOW = NOW + 3
check(C.Accept(C.PREFIX, hello, "WHISPER", "Spammer") ~= nil, "bucket refills over time")
local many = 0
for i = 1, 60 do if C.Accept(C.PREFIX, hello, "PARTY", "P" .. i) then many = many + 1 end end
check(many < 40, "global limit holds against many senders: " .. many)

-- Einladungen und Sitzung
C._Reset()
local inv = C.Encode("INVITE", "abc", "snake", 7, 60)
check(C.Accept(C.PREFIX, inv, "WHISPER", "Thrall") == "INVITE" and C.invites.Thrall, "invite stored, waits for the player")
check(C.Accept(C.PREFIX, C.Encode("INVITE", "abc", "doesnotexist", 7, 60), "WHISPER", "Jaina") == nil, "unknown game refused")
COMBAT = true
check(C.Accept(C.PREFIX, C.Encode("INVITE", "x1", "snake", 1, 60), "WHISPER", "Rexxar") == nil, "no invites in combat")
COMBAT = false
for i = 1, 5 do C.Accept(C.PREFIX, C.Encode("INVITE", "i" .. i, "snake", 1, 60), "WHISPER", "Inv" .. i) end
local open = 0
for _ in pairs(C.invites) do open = open + 1 end
check(open <= 3, "at most 3 open invites, are " .. open)
NOW = NOW + 61
check(C.Accept(C.PREFIX, C.Encode("INVITE", "late", "snake", 1, 60), "WHISPER", "Late") == "INVITE", "expired invites free up space")

C._Reset()
C.session = { id = "s9", partner = "Thrall", seq = 0 }
check(C.Accept(C.PREFIX, C.Encode("MOVE", "s9", 1, 5), "WHISPER", "Jaina") == nil, "moves from strangers dropped")
check(C.Accept(C.PREFIX, C.Encode("MOVE", "zz", 1, 5), "WHISPER", "Thrall") == nil, "wrong session id dropped")
check(C.Accept(C.PREFIX, C.Encode("MOVE", "s9", 1, 5), "WHISPER", "Thrall") == "MOVE", "partner move accepted")
check(C.Accept(C.PREFIX, C.Encode("MOVE", "s9", 1, 5), "WHISPER", "Thrall") == nil, "replayed move dropped")
check(C.Accept(C.PREFIX, C.Encode("INVITE", "q", "snake", 1, 60), "WHISPER", "Garrosh") == nil, "no invites during a session")

-- Handler-Fehler bleiben eingefangen
C.handlers.MOVE = function() error("boom") end
C.OnMessage(C.PREFIX, C.Encode("MOVE", "s9", 2, 1), "WHISPER", "Thrall")
check(#ERRORS_FORWARDED >= 1, "handler error caught and logged")

print(("Comm tests: %d ok, %d failed"):format(passes, fails))
