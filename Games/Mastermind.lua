-- Pastime: Edelstein-Code (Mastermind) – knack den Code des Juweliers
local ADDON, ns = ...
local L = ns.L

local W, H = 420, 426
local TRIES, LEN, ROWH = 10, 4, 31
local GEMS = {
    { L["Ruby"], "Interface\\Icons\\INV_Misc_Gem_Ruby_01" },
    { L["Emerald"], "Interface\\Icons\\INV_Misc_Gem_Emerald_01" },
    { L["Sapphire"], "Interface\\Icons\\INV_Misc_Gem_Sapphire_01" },
    { L["Topaz"], "Interface\\Icons\\INV_Misc_Gem_Topaz_01" },
    { L["Amethyst"], "Interface\\Icons\\INV_Misc_Gem_Amethyst_01" },
    { L["Diamond"], "Interface\\Icons\\INV_Misc_Gem_Diamond_01" },
}

local Game = {}
Game.__index = Game

-- exakt = richtiger Stein am richtigen Platz, teils = richtiger Stein woanders
function Game.Feedback(code, guess)
    local exact, cc, gc = 0, {}, {}
    for i = 1, LEN do
        if code[i] == guess[i] then
            exact = exact + 1
        else
            cc[code[i]] = (cc[code[i]] or 0) + 1
            gc[guess[i]] = (gc[guess[i]] or 0) + 1
        end
    end
    local partial = 0
    for color, n in pairs(gc) do partial = partial + math.min(n, cc[color] or 0) end
    return exact, partial
end

function Game:Start()
    self.code = {}
    for i = 1, LEN do self.code[i] = math.random(#GEMS) end
    self.rows = {}
    self.cur, self.try, self.done, self.score = {}, 1, false, 0
    self:Render()
end

function Game:Add(g)
    if self.done or #self.cur >= LEN then return end
    table.insert(self.cur, g)
    self.host:Sound("click")
    self:Render()
end

function Game:Back()
    if self.done or #self.cur == 0 then return end
    table.remove(self.cur)
    self:Render()
end

function Game:Check()
    if self.done or #self.cur < LEN then return end
    local exact, partial = Game.Feedback(self.code, self.cur)
    self.rows[self.try] = { guess = self.cur, exact = exact, partial = partial }
    self.cur = {}
    if exact == LEN then
        self.done = true
        self.score = (TRIES + 1 - self.try) * 100
        self:Render()
        return self.host:Over({ score = self.score, won = true, text = (L["Code cracked on try %d!"]):format(self.try) })
    end
    self.try = self.try + 1
    self.host:Sound(exact > 0 and "point" or "click")
    if self.try > TRIES then
        self.done = true
        self:Render()
        local names = {}
        for i = 1, LEN do names[i] = GEMS[self.code[i]][1] end
        return self.host:Over({ submit = false, title = L["Not cracked"], text = L["The code was: "] .. table.concat(names, ", ") })
    end
    self:Render()
end

function Game:Update() end

function Game:Key(k, down)
    local n = tonumber(k) or tonumber((k or ""):match("^NUMPAD(%d)$") or "")
    if n and n >= 1 and n <= #GEMS then
        if down then self:Add(n) end
        return true
    end
    if k == "BACKSPACE" or k == "DELETE" then
        if down then self:Back() end
        return true
    end
    if k == "ENTER" or k == "SPACE" or k == "NUMPADENTER" then
        if down then self:Check() end
        return true
    end
    return false
end

function Game:Render()
    for t = 1, TRIES do
        local row = self.rowFrames[t]
        local data = self.rows[t]
        local guess = data and data.guess or (t == self.try and self.cur) or {}
        for i = 1, LEN do
            local g = guess[i]
            row.slots[i]:SetShown(g ~= nil)
            if g then ns.SetIcon(row.slots[i], GEMS[g][2]) end
        end
        for p = 1, LEN do
            local peg = row.pegs[p]
            if data and p <= data.exact then
                peg:SetColorTexture(1, 0.82, 0, 1)
            elseif data and p <= data.exact + data.partial then
                peg:SetColorTexture(0.78, 0.78, 0.82, 1)
            else
                peg:SetColorTexture(0.12, 0.1, 0.08, 1)
            end
        end
        row.band:SetShown(t == self.try and not self.done)
    end
    for i = 1, LEN do
        if self.done then
            ns.SetIcon(self.secret[i], GEMS[self.code[i]][2])
        else
            self.secret[i]:SetTexture(ns.TEX.question)
            self.secret[i]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
    self.checkBtn:SetEnabled(#self.cur == LEN and not self.done)
end

function Game:Info()
    return { { L["Try"], ("%d/%d"):format(math.min(self.try or 1, TRIES), TRIES) } }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, rowFrames = {}, rows = {}, cur = {}, secret = {}, score = 0, try = 1 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    ns.Paint(bg, 0.1, 0.08, 0.06, 1)
    for t = 1, TRIES do
        local y = 6 + (t - 1) * ROWH
        local row = { slots = {}, pegs = {} }
        row.band = ns.Box(board, "BORDER", 1, 0.82, 0, 0.12)
        row.band:SetPoint("TOPLEFT", board, "TOPLEFT", 4, -y + 1)
        row.band:SetSize(236, ROWH - 2)
        local num = ns.FontString(board, "GameFontDisableSmall", "RIGHT")
        num:SetPoint("TOPRIGHT", board, "TOPLEFT", 26, -(y + 9))
        num:SetText(t)
        for i = 1, LEN do
            local hole = ns.Box(board, "BORDER", 0.04, 0.03, 0.02)
            hole:SetSize(26, 26)
            hole:SetPoint("TOPLEFT", board, "TOPLEFT", 34 + (i - 1) * 32, -(y + 2))
            local s = board:CreateTexture(nil, "ARTWORK")
            s:SetAllPoints(hole)
            s:Hide()
            row.slots[i] = s
        end
        for p = 1, LEN do
            local peg = board:CreateTexture(nil, "ARTWORK")
            peg:SetSize(9, 9)
            peg:SetPoint("TOPLEFT", board, "TOPLEFT", 176 + ((p - 1) % 2) * 13, -(y + 4 + math.floor((p - 1) / 2) * 13))
            row.pegs[p] = peg
        end
        g.rowFrames[t] = row
    end
    -- rechts: geheimer Code und Erklärung
    local title = ns.FontString(board, "GameFontNormal", "CENTER")
    title:SetPoint("TOP", board, "TOPLEFT", 335, -14)
    title:SetText(L["Secret code"])
    for i = 1, LEN do
        local s = board:CreateTexture(nil, "ARTWORK")
        s:SetSize(32, 32)
        s:SetPoint("TOPLEFT", board, "TOPLEFT", 262 + (i - 1) * 38, -36)
        g.secret[i] = s
    end
    local legend = ns.FontString(board, "GameFontHighlightSmall")
    legend:SetPoint("TOPLEFT", board, "TOPLEFT", 258, -84)
    legend:SetWidth(156)
    legend:SetText(L["|cffffd100Gold|r: right gem in the right place\n\n|cffc8c8d0Silver|r: right gem, but in another place\n\nGems may appear more than once."])
    -- unten: Auswahl
    for i, gem in ipairs(GEMS) do
        local b = ns.IconButton(board, 40, gem[2])
        b:SetPoint("TOPLEFT", board, "TOPLEFT", 8 + (i - 1) * 46, -(6 + TRIES * ROWH + 10))
        b:SetScript("OnClick", function() if host:IsRunning() then ns.Safe("edelsteincode", g.Add, g, i) end end)
        local key = ns.FontString(b, "GameFontHighlightSmall", "RIGHT")
        key:SetPoint("BOTTOMRIGHT", -2, 2)
        key:SetText(i)
    end
    local back = ns.CreateButton(board, L["Back"], 80, function() if host:IsRunning() then g:Back() end end)
    back:SetPoint("TOPLEFT", board, "TOPLEFT", 290, -(6 + TRIES * ROWH + 4))
    g.checkBtn = ns.CreateButton(board, L["Check"], 80, function() if host:IsRunning() then g:Check() end end)
    g.checkBtn:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -4)
    return g
end

ns.RegisterGame({
    id = "code",
    name = L["Gem Code"],
    short = L["Code breaker"],
    aliases = { "code", "mastermind", "edelsteincode", "gemcode" },
    category = "knobeln",
    length = "kurz",
    icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
    keyboard = true,
    width = W, height = H,
    desc = L["A jeweller has hidden four gems in a secret order. Guess the combination – after each try, gold and silver pegs tell you how close you are. You have ten tries."],
    controls = L["Click the gems or press 1–6 · Backspace: undo · Enter/Space: check"],
    controlsShort = L["1–6: place gem\nBackspace: undo\nEnter: check"],
    Create = Create,
})
