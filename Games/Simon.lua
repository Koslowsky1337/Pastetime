-- Pastime: Totem-Simon – merk dir die Folge der Elementartotems
local ADDON, ns = ...
local L = ns.L

local SIZE, TS = 420, 116
local TOTEMS = {
    { name = L["Air"], icon = "Interface\\Icons\\Spell_Nature_Windfury", x = 152, y = 14, sound = "t1", keys = { UP = 1, W = 1, ["1"] = 1 } },
    { name = L["Fire"], icon = "Interface\\Icons\\Spell_Fire_SearingTotem", x = 290, y = 150, sound = "t2", keys = { RIGHT = 1, D = 1, ["2"] = 1 } },
    { name = L["Earth"], icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem", x = 152, y = 286, sound = "t3", keys = { DOWN = 1, S = 1, ["3"] = 1 } },
    { name = L["Water"], icon = "Interface\\Icons\\Spell_Nature_ManaRegenTotem", x = 14, y = 150, sound = "t4", keys = { LEFT = 1, A = 1, ["4"] = 1 } },
}
local KEYMAP = {}
for i, t in ipairs(TOTEMS) do for k in pairs(t.keys) do KEYMAP[k] = i end end

local Game = {}
Game.__index = Game

function Game:Light(i, on)
    local b = self.buttons[i]
    b.icon:SetDesaturated(not on)
    b.icon:SetAlpha(on and 1 or 0.55)
    b.glow:SetShown(on)
end

function Game:AllOff() for i = 1, 4 do self:Light(i, false) end end

function Game:Start()
    self.seq, self.pos, self.score = {}, 1, 0
    self.dead = false
    self:AllOff()
    self:NextRound()
end

function Game:NextRound()
    table.insert(self.seq, math.random(4))
    self.state, self.t, self.idx, self.on = "pause", 0.8, 0, false
    self.title:SetText((L["Round %d"]):format(#self.seq))
    self.sub:SetText(L["Watch closely …"])
end

function Game:OnTime() return math.max(0.25, 0.55 - #self.seq * 0.02) end

function Game:Press(i)
    if self.dead or self.state ~= "input" then return end
    self.host:Sound(TOTEMS[i].sound)
    self:AllOff()
    self:Light(i, true)
    self.flash = 0.2
    if self.seq[self.pos] ~= i then
        self.dead = true
        self.state = "over"
        self.score = #self.seq - 1
        self.title:SetText(L["|cffff6060Wrong!|r"])
        self.sub:SetText((L["It should have been %s."]):format(TOTEMS[self.seq[self.pos]].name))
        return self.host:Over({ score = self.score, text = (L["Wrong totem – it should have been %s.\nCompleted: %d rounds"])
            :format(TOTEMS[self.seq[self.pos]].name, self.score) })
    end
    self.pos = self.pos + 1
    if self.pos > #self.seq then
        self.score = #self.seq
        self.sub:SetText(L["|cff80ff80Correct!|r"])
        self:NextRound()
        self.t = 1.0
    end
end

function Game:Update(dt)
    if self.flash then
        self.flash = self.flash - dt
        if self.flash <= 0 then self.flash = nil; self:AllOff() end
    end
    if self.state == "pause" then
        self.t = self.t - dt
        if self.t <= 0 then self.state, self.idx, self.on, self.t = "show", 1, true, self:OnTime(); self:ShowStep() end
    elseif self.state == "show" then
        self.t = self.t - dt
        if self.t <= 0 then
            if self.on then
                self:AllOff()
                self.on, self.t = false, 0.15
            else
                self.idx = self.idx + 1
                if self.idx > #self.seq then
                    self.state, self.pos = "input", 1
                    self.sub:SetText(L["Your turn!"])
                else
                    self.on, self.t = true, self:OnTime()
                    self:ShowStep()
                end
            end
        end
    end
end

function Game:ShowStep()
    local i = self.seq[self.idx]
    self:AllOff()
    self:Light(i, true)
    self.host:Sound(TOTEMS[i].sound)
end

function Game:Key(k, down)
    local i = KEYMAP[k]
    if not i then return false end
    if down then self:Press(i) end
    return true
end

function Game:Info()
    return {
        { L["Round"], tostring(self.seq and #self.seq or 0) },
        { L["Completed"], tostring(self.score or 0) },
    }
end

local function Create(host, board)
    local g = setmetatable({ host = host, board = board, buttons = {}, seq = {}, score = 0 }, Game)
    local bg = ns.NewTexture(board, "BACKGROUND")
    bg:SetAllPoints()
    if CreateColor then bg:SetGradient("VERTICAL", CreateColor(0.08, 0.06, 0.04, 1), CreateColor(0.2, 0.15, 0.1, 1)) end
    for i, t in ipairs(TOTEMS) do
        local b = CreateFrame("Button", nil, board)
        b:SetSize(TS, TS)
        b:SetPoint("TOPLEFT", board, "TOPLEFT", t.x, -t.y)
        b:RegisterForClicks("LeftButtonDown")
        local slot = b:CreateTexture(nil, "BACKGROUND")
        slot:SetTexture(ns.TEX.slot)
        slot:SetPoint("TOPLEFT", -22, 22)
        slot:SetPoint("BOTTOMRIGHT", 22, -22)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        ns.SetIcon(b.icon, t.icon)
        b.glow = b:CreateTexture(nil, "OVERLAY")
        b.glow:SetTexture(ns.TEX.cellHi)
        b.glow:SetBlendMode("ADD")
        b.glow:SetAllPoints()
        b.glow:Hide()
        local label = ns.FontString(b, "GameFontNormal", "CENTER")
        label:SetPoint("TOP", b, "BOTTOM", 0, -2)
        label:SetText(t.name)
        b:SetScript("OnClick", function()
            if host:IsRunning() then ns.Safe("simon", g.Press, g, i) end
        end)
        g.buttons[i] = b
    end
    g.title = ns.FontString(board, "GameFontNormalHuge", "CENTER")
    g.title:SetPoint("CENTER", 0, 12)
    g.sub = ns.FontString(board, "GameFontHighlight", "CENTER")
    g.sub:SetPoint("TOP", g.title, "BOTTOM", 0, -6)
    g.sub:SetWidth(130)
    return g
end

ns.RegisterGame({
    id = "simon",
    name = L["Totem Echo"],
    short = L["Sequence memory"],
    aliases = { "simon", "totem", "totems", "echo", "totemecho" },
    category = "knobeln",
    length = "kurz",
    icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
    keyboard = true,
    width = SIZE, height = SIZE,
    desc = L["The elemental totems light up in a sequence – repeat it in the same order. Every round adds one more totem, and the spirits grow more impatient."],
    controls = L["Click the totems · or arrow keys/WASD (up Air, right Fire, down Earth, left Water) · 1–4"],
    controlsShort = L["Click or arrows/WASD\nup Air · right Fire\ndown Earth · left Water"],
    scoreLabel = L["Rounds"],
    Create = Create,
})
