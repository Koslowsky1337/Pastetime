-- Pastime: Angeln – auf den Biss warten und im richtigen Moment anschlagen
local ADDON, ns = ...
local L = ns.L

local SIZE = 420
local WATER_TOP, SHORE = 120, 360
local CASTS = 10
local ICON_POLE = "Interface\\Icons\\INV_Fishingpole_02"

local QCOLOR = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
}
local FISH = {
    [0] = { { L["Old Boot"], "Interface\\Icons\\INV_Boots_01", 1 } },
    [1] = { { L["Barrens Pike"], "Interface\\Icons\\INV_Misc_Fish_02", 10 },
            { L["Mud Perch"], "Interface\\Icons\\INV_Misc_Fish_05", 12 } },
    [2] = { { L["Stonescale Eel"], "Interface\\Icons\\INV_Misc_Fish_14", 25 },
            { L["Oily Blackmouth"], "Interface\\Icons\\INV_Misc_Fish_09", 25 } },
    [3] = { { L["Firefin Snapper"], "Interface\\Icons\\INV_Misc_Fish_16", 50 } },
    [4] = { { L["Giant Moonfish"], "Interface\\Icons\\INV_Misc_Fish_18", 100 } },
    [5] = { { L["Ancient Turtle"], "Interface\\Icons\\INV_Misc_Fish_Turtle_01", 250 } },
}

local Game = {}
Game.__index = Game

-- Schnelle Reaktion = bessere Chancen auf seltene Fische
function Game.RollQuality(speed)
    local roll = math.random() ^ (1 + speed * 1.5)
    if roll < 0.012 then return 5 elseif roll < 0.05 then return 4 elseif roll < 0.15 then return 3
    elseif roll < 0.38 then return 2 elseif roll < 0.85 then return 1 end
    return 0
end

function Game:Message(title, sub)
    self.msg:SetText(title or "")
    self.sub:SetText(sub or "")
end

function Game:PlaceBobber(dy)
    self.bobber:SetPoint("CENTER", self.board, "TOPLEFT", self.bx, -(self.by + (dy or 0)))
end

function Game:Start()
    self.score, self.casts, self.caught, self.streak, self.bestStreak = 0, 0, 0, 0, 0
    self.state, self.t, self.lastMs = "ready", 0, nil
    self.log = {}
    self.bobber:Hide()
    self.splash:Hide()
    self:RenderLog()
    self:Message(L["Space or click: cast"], (L["%d casts – strike as soon as the bobber dips!"]):format(CASTS))
end

function Game:Cast()
    self.casts = self.casts + 1
    self.state = "wait"
    self.bx = 140 + math.random() * 220
    self.by = WATER_TOP + 50 + math.random() * (SHORE - WATER_TOP - 100)
    self.t = 1.5 + math.random() * 4
    self.nibbles = {}
    for _ = 1, math.random(0, 2) do table.insert(self.nibbles, 0.5 + math.random() * (self.t - 0.8)) end
    self.waited = 0
    self.bobber:Show()
    self.splash:Hide()
    self:PlaceBobber(0)
    self:Message("", (L["Cast %d of %d – wait for a bite …"]):format(self.casts, CASTS))
end

function Game:Window() return math.max(0.45, 0.9 - self.streak * 0.04) end

function Game:Result(title, sub)
    self.state, self.t = "result", 1.1
    self.splash:Hide()
    self:Message(title, sub)
    if self.casts >= CASTS then self.t = 1.6 end
end

function Game:Hook()
    if self.state == "ready" then return self:Cast() end
    if self.state == "wait" then
        self.streak = 0
        self.host:Sound("bad")
        return self:Result(L["|cffff6060Too early!|r"], L["The fish got away – wait until the bobber really goes under."])
    end
    if self.state == "bite" then
        local r = self.biteT
        local W = self:Window()
        local q = Game.RollQuality(math.max(0, 1 - r / W))
        local list = FISH[q]
        local fish = list[math.random(#list)]
        self.streak = self.streak + 1
        self.bestStreak = math.max(self.bestStreak, self.streak)
        local pts = math.floor(fish[3] * (1 + 0.1 * (self.streak - 1)) + 0.5)
        self.score = self.score + pts
        self.caught = self.caught + 1
        self.lastMs = math.floor(r * 1000 + 0.5)
        table.insert(self.log, 1, { fish = fish, q = q, pts = pts })
        if #self.log > 5 then table.remove(self.log) end
        self:RenderLog()
        self.host:Sound(q >= 3 and "big" or "point")
        local c = QCOLOR[q]
        return self:Result(("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, fish[1]),
            (L["+%d points · reaction %d ms · streak %d"]):format(pts, self.lastMs, self.streak))
    end
end

function Game:Update(dt)
    if self.state == "wait" then
        self.waited = self.waited + dt
        local twitch = 0
        for _, n in ipairs(self.nibbles) do
            if self.waited >= n and self.waited < n + 0.12 then twitch = 2 end
        end
        self:PlaceBobber(twitch)
        if self.waited >= self.t then
            self.state, self.biteT = "bite", 0
            self:PlaceBobber(7)
            self.splash:SetPoint("CENTER", self.board, "TOPLEFT", self.bx, -(self.by + 6))
            self.splash:Show()
            self:Message("|cffffffff!|r", "")
            self.host:Sound("click")
        end
    elseif self.state == "bite" then
        self.biteT = self.biteT + dt
        if self.biteT > self:Window() then
            self.streak = 0
            self:Result(L["|cffaaaaaaGot away …|r"], L["Too slow – the fish broke free."])
        end
    elseif self.state == "result" then
        self.t = self.t - dt
        if self.t <= 0 then
            if self.casts >= CASTS then
                self.state = "over"
                self.host:Over({ score = self.score, won = self.score >= 300,   -- „Sieg!“ erst für eine gute Runde
                    text = (L["%d fish caught · best streak %d"]):format(self.caught, self.bestStreak) })
            else
                self.state = "ready"
                self.bobber:Hide()
                self:Message(L["Space or click: cast"], (L["%d casts left"]):format(CASTS - self.casts))
            end
        end
    end
end

function Game:Key(k, down)
    if k ~= "SPACE" and k ~= "ENTER" and k ~= "UP" and k ~= "W" then return false end
    if down then self:Hook() end
    return true
end

function Game:RenderLog()
    for i, row in ipairs(self.logRows) do
        local e = self.log[i]
        if e then
            ns.SetIcon(row.icon, e.fish[2])
            row.icon:Show()
            local c = QCOLOR[e.q]
            row.text:SetText(("%s |cffffffff+%d|r"):format(e.fish[1], e.pts))
            row.text:SetTextColor(c[1], c[2], c[3])
        else
            row.icon:Hide()
            row.text:SetText("")
        end
    end
end

function Game:Info()
    return {
        { L["Cast"], ("%d/%d"):format(self.casts or 0, CASTS) },
        { L["Fish"], tostring(self.caught or 0) },
        { L["Streak"], tostring(self.streak or 0) },
        { L["Reaction"], self.lastMs and (self.lastMs .. " ms") or "–" },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, score = 0, log = {}, logRows = {}, streak = 0 }, Game)
    local sky = ns.NewTexture(board, "BACKGROUND")
    sky:SetPoint("TOPLEFT")
    sky:SetPoint("TOPRIGHT")
    sky:SetHeight(WATER_TOP)
    if CreateColor then sky:SetGradient("VERTICAL", CreateColor(0.85, 0.55, 0.35, 1), CreateColor(0.2, 0.25, 0.45, 1)) end
    local water = ns.NewTexture(board, "BACKGROUND")
    water:SetPoint("TOPLEFT", 0, -WATER_TOP)
    water:SetPoint("TOPRIGHT", 0, -WATER_TOP)
    water:SetHeight(SHORE - WATER_TOP)
    if CreateColor then water:SetGradient("VERTICAL", CreateColor(0.03, 0.12, 0.25, 1), CreateColor(0.12, 0.32, 0.48, 1)) end
    local shore = ns.NewTexture(board, "BACKGROUND", 1)
    shore:SetPoint("BOTTOMLEFT")
    shore:SetPoint("BOTTOMRIGHT")
    shore:SetHeight(SIZE - SHORE)
    ns.Paint(shore, 0.35, 0.28, 0.14, 1, 0.65)
    local pole = board:CreateTexture(nil, "ARTWORK")
    pole:SetSize(48, 48)
    pole:SetPoint("BOTTOMLEFT", 14, 8)
    ns.SetIcon(pole, ICON_POLE)

    -- Schwimmer: rot oben, weiß unten
    local bobber = CreateFrame("Frame", nil, board)
    bobber:SetSize(14, 16)
    local top = ns.Box(bobber, "ARTWORK", 0.85, 0.12, 0.1)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(8)
    local bot = ns.Box(bobber, "ARTWORK", 0.95, 0.95, 0.9)
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(8)
    bobber:Hide()
    g.bobber = bobber
    -- Spritzer
    local splash = CreateFrame("Frame", nil, board)
    splash:SetSize(44, 12)
    for i, w in ipairs({ 44, 30, 16 }) do
        local t = ns.Box(splash, "OVERLAY", 0.85, 0.95, 1, 0.75 - i * 0.15)
        t:SetSize(w, 2)
        t:SetPoint("CENTER", 0, (i - 2) * 4)
    end
    splash:Hide()
    g.splash = splash

    g.msg = ns.FontString(board, "GameFontNormalHuge", "CENTER")
    g.msg:SetPoint("TOP", 0, -30)
    g.sub = ns.FontString(board, "GameFontHighlight", "CENTER")
    g.sub:SetPoint("TOP", g.msg, "BOTTOM", 0, -8)
    g.sub:SetWidth(380)
    -- Fangliste (die letzten fünf) am Ufer neben der Angel
    for i = 1, 5 do
        local icon = board:CreateTexture(nil, "OVERLAY")
        icon:SetSize(10, 10)
        icon:SetPoint("TOPLEFT", board, "TOPLEFT", 80, -(SHORE + 4 + (i - 1) * 11))
        icon:Hide()
        local text = ns.FontString(board, "GameFontNormalSmall")
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        g.logRows[i] = { icon = icon, text = text }
    end

    board:EnableMouse(true)
    board:SetScript("OnMouseDown", function()
        if host:IsRunning() then ns.Safe("angeln", g.Hook, g) end
    end)
    return g
end

ns.RegisterGame({
    id = "angeln",
    name = L["Fishing"],
    short = L["Reaction"],
    aliases = { "angeln", "fischen", "angel", "fishing", "fish" },
    category = "geschick",
    length = "kurz",
    icon = ICON_POLE,
    keyboard = true,
    width = SIZE, height = SIZE,
    desc = L["Cast ten times and strike as soon as the bobber dips – but not at the first twitch! The faster you react, the rarer the catch. Catch several in a row for a streak bonus."],
    controls = L["Space or click: cast and strike"],
    controlsShort = L["Space/click:\ncast & strike"],
    Create = Create,
})
