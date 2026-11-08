-- Pastime: Grundlage für den Mehrspieler (in 1.0 noch abgeschaltet)
--
-- Addon-Nachrichten sind für Spieler unsichtbar. Pastime erkennt seine eigenen
-- an der Kennung PREFIX und am Protokoll-Kopf PROTO. Alles, was ankommt, gilt
-- als nicht vertrauenswürdig:
--   * nur bekannte Nachrichtentypen mit fester Feldanzahl, Länge und Wertebereich
--   * nie als Code ausgeführt, nie als Formatstring benutzt, Farbcodes/Steuerzeichen
--     werden entfernt, bevor ein Name irgendwo angezeigt wird
--   * Mengenbremse pro Absender und insgesamt; Ignorierte und fremde Kanäle fallen raus
--   * Spielzüge nur vom Partner einer laufenden Partie mit passender Sitzungs-ID
--   * Einladungen brauchen immer eine Bestätigung des Spielers, verfallen nach 60 s,
--     höchstens eine offene pro Absender; im Kampf wird nichts angenommen
--   * Senden läuft gedrosselt über eine Warteschlange
local ADDON, ns = ...

local Comm = {}
ns.Comm = Comm

Comm.ENABLED = false                 -- wird mit dem Mehrspieler-Update eingeschaltet
Comm.PREFIX = "PastimeMiniGames"     -- 16 Zeichen (Höchstlänge)
Comm.PROTO = "PT1"                   -- Protokollversion
Comm.SEP = "^"
Comm.MAX_LEN = 240                   -- unter der Grenze von 255 Byte

-- Erlaubte Kanäle für eingehende Nachrichten
local CHANNELS = { WHISPER = true, PARTY = true, RAID = true, GUILD = true, INSTANCE_CHAT = true }

-- Feldprüfer: geben den bereinigten Wert oder nil zurück
local function int(lo, hi)
    return function(s)
        if type(s) ~= "string" or not s:match("^%-?%d+$") or #s > 10 then return nil end
        local n = tonumber(s)
        if not n or n < lo or n > hi then return nil end
        return n
    end
end
local function word(maxLen)
    return function(s)
        if type(s) ~= "string" or #s == 0 or #s > maxLen or not s:match("^[%w_%-:]+$") then return nil end
        return s
    end
end
local SESSION = word(12)

-- Nachrichtentypen: Feldliste in fester Reihenfolge
Comm.TYPES = {
    HELLO  = { int(1, 9999) },                                  -- Addon-Version (z. B. 100 = 1.0.0)
    INVITE = { SESSION, word(16), int(0, 2147483647), int(1, 600) },  -- Sitzung, Spiel-ID, Startwert, Sekunden
    ACCEPT = { SESSION },
    DECLINE = { SESSION },
    ROLL   = { SESSION, int(1, 100) },
    MOVE   = { SESSION, int(1, 100000), int(-100000, 100000) }, -- Sitzung, laufende Nr., Zug
    RESULT = { SESSION, int(0, 100000000) },
    BYE    = { SESSION },
}

-- Farbcodes, Links, Texturen und Steuerzeichen aus fremden Texten entfernen
function Comm.Sanitize(s, maxLen)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|", ""):gsub("[%c]", "")
    if #s > (maxLen or 48) then s = s:sub(1, maxLen or 48) end
    return s
end

function Comm.Encode(kind, ...)
    local spec = Comm.TYPES[kind]
    if not spec then return nil, "unknown type" end
    local n = select("#", ...)
    if n ~= #spec then return nil, "field count" end
    local parts = { Comm.PROTO, kind }
    for i = 1, n do
        local v = tostring((select(i, ...)))
        if not spec[i](v) then return nil, "field " .. i end
        parts[#parts + 1] = v
    end
    local msg = table.concat(parts, Comm.SEP)
    if #msg > Comm.MAX_LEN then return nil, "too long" end
    return msg
end

-- Gibt kind, { Felder } zurück oder nil, Grund
function Comm.Decode(text)
    if type(text) ~= "string" or #text == 0 or #text > Comm.MAX_LEN then return nil, "size" end
    if text:find("[%c|]") then return nil, "characters" end
    local parts = {}
    for p in (text .. Comm.SEP):gmatch("(.-)%" .. Comm.SEP) do
        parts[#parts + 1] = p
        if #parts > 8 then return nil, "too many fields" end
    end
    if parts[1] ~= Comm.PROTO then return nil, "protocol" end
    local kind = parts[2]
    local spec = Comm.TYPES[kind]
    if not spec then return nil, "type" end
    if #parts - 2 ~= #spec then return nil, "field count" end
    local fields = {}
    for i, check in ipairs(spec) do
        local v = check(parts[i + 2])
        if v == nil then return nil, "field " .. i end
        fields[i] = v
    end
    return kind, fields
end

---------------------------------------------------------------------------
-- Mengenbremse (Token-Eimer): pro Absender und insgesamt
---------------------------------------------------------------------------
local Bucket = {}
Bucket.__index = Bucket
function Comm.NewBucket(capacity, perSecond)
    return setmetatable({ cap = capacity, rate = perSecond, n = capacity, t = GetTime() }, Bucket)
end
function Bucket:Take()
    local now = GetTime()
    self.n = math.min(self.cap, self.n + (now - self.t) * self.rate)
    self.t = now
    if self.n < 1 then return false end
    self.n = self.n - 1
    return true
end

local perSender, total = {}, nil
local MAX_SENDERS = 50

local function allowFrom(sender)
    total = total or Comm.NewBucket(30, 3)
    local b = perSender[sender]
    if not b then
        local count = 0
        for _ in pairs(perSender) do count = count + 1 end
        if count >= MAX_SENDERS then wipe(perSender) end
        b = Comm.NewBucket(6, 1)
        perSender[sender] = b
    end
    return b:Take() and total:Take()
end

local function isSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function isIgnored(name)
    if C_FriendList and C_FriendList.IsIgnored then
        local ok, res = pcall(C_FriendList.IsIgnored, name)
        return ok and res and true or false
    end
    return false
end

---------------------------------------------------------------------------
-- Sitzungen und Einladungen
---------------------------------------------------------------------------
Comm.session = nil       -- { id, partner, game, seed, seq }
Comm.invites = {}        -- [sender] = { id, game, seed, sec, t }
local INVITE_TTL, MAX_INVITES = 60, 3
Comm.handlers = {}       -- [kind] = function(sender, fields) – vom Spiel gesetzt

local function cleanInvites()
    local now, n = GetTime(), 0
    for who, inv in pairs(Comm.invites) do
        if now - inv.t > INVITE_TTL then Comm.invites[who] = nil else n = n + 1 end
    end
    return n
end

-- Prüft eine eingehende Nachricht vollständig. Rückgabe: kind, fields, sender oder nil, Grund
function Comm.Accept(prefix, text, channel, sender)
    if prefix ~= Comm.PREFIX then return nil, "prefix" end
    if isSecret(text) or isSecret(sender) or isSecret(channel) then return nil, "secret" end
    if not CHANNELS[channel] then return nil, "channel" end
    if type(sender) ~= "string" or sender == "" then return nil, "sender" end
    sender = Ambiguate and Ambiguate(sender, "none") or sender
    if sender == ns.playerName then return nil, "self" end
    if isIgnored(sender) then return nil, "ignored" end
    if not allowFrom(sender) then return nil, "rate" end
    local kind, fields = Comm.Decode(text)
    if not kind then return nil, fields end

    local s = Comm.session
    if kind == "INVITE" then
        if InCombatLockdown and InCombatLockdown() then return nil, "combat" end
        if s then return nil, "busy" end
        if not Comm.invites[sender] and cleanInvites() >= MAX_INVITES then return nil, "too many invites" end
        if not ns.gamesById[fields[2]] then return nil, "unknown game" end
        Comm.invites[sender] = { id = fields[1], game = fields[2], seed = fields[3], sec = fields[4], t = GetTime() }
    elseif kind == "ACCEPT" or kind == "DECLINE" then
        if not (s and s.pending and s.partner == sender and s.id == fields[1]) then return nil, "no invite" end
    elseif kind ~= "HELLO" then
        if not (s and s.partner == sender and s.id == fields[1]) then return nil, "not in session" end
        if kind == "MOVE" then
            if fields[2] <= (s.seq or 0) then return nil, "old move" end
            s.seq = fields[2]
        end
    end
    return kind, fields, sender
end

function Comm.OnMessage(prefix, text, channel, sender)
    local kind, fields, who = Comm.Accept(prefix, text, channel, sender)
    if not kind then
        ns.Log("D", "comm", "dropped (%s)", tostring(fields))
        return
    end
    local h = Comm.handlers[kind]
    if h then ns.Safe("comm-" .. kind, h, who, fields) end
end

---------------------------------------------------------------------------
-- Senden: Warteschlange, höchstens eine Nachricht alle 0,5 s
---------------------------------------------------------------------------
local queue, lastSend = {}, 0
local SEND_GAP = 0.5
local RESULT_OK, RESULT_THROTTLE, RESULT_CHANNEL_THROTTLE = 0, 3, 8

function Comm.Send(kind, channel, target, ...)
    if not Comm.ENABLED then return false end
    local msg, err = Comm.Encode(kind, ...)
    if not msg then ns.Log("W", "comm", "not sent: %s", tostring(err)); return false end
    if #queue >= 20 then return false end
    queue[#queue + 1] = { msg = msg, channel = channel, target = target, tries = 0 }
    return true
end

function Comm.Flush()
    local item = queue[1]
    if not item or GetTime() - lastSend < SEND_GAP then return end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then wipe(queue); return end
    lastSend = GetTime()
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, Comm.PREFIX, item.msg, item.channel, item.target)
    local code = ok and (type(res) == "number" and res or (res == true and RESULT_OK)) or -1
    if code == RESULT_THROTTLE or code == RESULT_CHANNEL_THROTTLE then
        item.tries = item.tries + 1
        if item.tries < 5 then return end      -- später erneut versuchen
    end
    if code ~= RESULT_OK then ns.Log("D", "comm", "send result %s", tostring(code)) end
    table.remove(queue, 1)
end

function Comm.Enable()
    if Comm.registered then return end
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
    C_ChatInfo.RegisterAddonMessagePrefix(Comm.PREFIX)
    Comm.registered = true
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", ns.Wrap("comm", function(_, _, ...) Comm.OnMessage(...) end))
    C_Timer.NewTicker(0.25, ns.Wrap("comm-send", Comm.Flush))
end

-- Nur zum Testen: Zustand zurücksetzen
function Comm._Reset()
    wipe(perSender); total = nil; wipe(queue); lastSend = 0
    Comm.session = nil; wipe(Comm.invites)
end
