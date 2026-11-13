-- Pastime: Spielkarten (für Blackjack und Solitär)
-- Farben mit Zeichen (♥♦♠♣ aus ARIALN) und zusätzlich einem Edelstein-Symbol,
-- damit sie auch ohne die Zeichen unterscheidbar bleiben.
local ADDON, ns = ...
local L = ns.L

local Cards = {}
ns.Cards = Cards

Cards.SUITS = {
    { name = L["Hearts"], glyph = "\226\153\165", red = true, icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01" },
    { name = L["Diamonds"], glyph = "\226\153\166", red = true, icon = "Interface\\Icons\\INV_Misc_Gem_Topaz_01" },
    { name = L["Spades"], glyph = "\226\153\160", red = false, icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01" },
    { name = L["Clubs"], glyph = "\226\153\163", red = false, icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01" },
}
-- Ass, Bube, Dame und König: Kürzel je nach Sprache (deDE: A, B, D, K)
Cards.RANKS = { L["A"], "2", "3", "4", "5", "6", "7", "8", "9", "10", L["J"], L["Q"], L["K"] }
local FONT = "Fonts\\ARIALN.TTF"

function Cards.NewDeck()
    local deck = {}
    for s = 1, 4 do
        for r = 1, 13 do deck[#deck + 1] = { rank = r, suit = s } end
    end
    return deck
end

function Cards.Shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function Cards.Name(card)
    return Cards.SUITS[card.suit].name .. " " .. Cards.RANKS[card.rank]
end

local function setFont(fs, size)
    if not (fs.SetFont and fs:SetFont(FONT, size, "")) then fs:SetFontObject(GameFontNormal) end
end

local CardMethods = {}

function CardMethods:SetCard(card, faceUp)
    self.card = card
    if not card then
        self:Hide()
        return
    end
    self:Show()
    local up = faceUp and true or false
    self.face:SetShown(up)
    self.rank:SetShown(up)
    self.suit:SetShown(up)
    self.icon:SetShown(up)
    self.back:SetShown(not up)
    self.emblem:SetShown(not up)
    if up then
        local s = Cards.SUITS[card.suit]
        local r, g, b = 0.08, 0.08, 0.1
        if s.red then r, g, b = 0.75, 0.08, 0.06 end
        self.rank:SetText(Cards.RANKS[card.rank])
        self.rank:SetTextColor(r, g, b)
        self.suit:SetText(s.glyph)
        self.suit:SetTextColor(r, g, b)
        ns.SetIcon(self.icon, s.icon)
    end
end

function CardMethods:SetSelected(on)
    self.sel:SetShown(on and true or false)
end

function Cards.Create(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.edge = ns.Box(b, "BACKGROUND", 0.08, 0.06, 0.04)
    b.edge:SetAllPoints()
    b.face = ns.NewTexture(b, "BORDER")
    b.face:SetPoint("TOPLEFT", 1, -1)
    b.face:SetPoint("BOTTOMRIGHT", -1, 1)
    ns.Paint(b.face, 0.96, 0.93, 0.85, 1, 0.9)
    b.back = ns.NewTexture(b, "BORDER", 1)
    b.back:SetPoint("TOPLEFT", 2, -2)
    b.back:SetPoint("BOTTOMRIGHT", -2, 2)
    ns.Paint(b.back, 0.5, 0.1, 0.08, 1, 0.55)
    b.emblem = b:CreateTexture(nil, "ARTWORK")
    b.emblem:SetSize(w * 0.55, w * 0.55)
    b.emblem:SetPoint("CENTER")
    ns.SetIcon(b.emblem, "Interface\\Icons\\INV_BannerPVP_01")
    b.emblem:SetAlpha(0.4)
    local size = w >= 60 and 16 or 14
    b.rank = b:CreateFontString(nil, "OVERLAY")
    setFont(b.rank, size)
    b.rank:SetPoint("TOPLEFT", 4, -3)
    b.suit = b:CreateFontString(nil, "OVERLAY")
    setFont(b.suit, size)
    -- neben dem Wert, damit beides auch bei überdeckten Karten sichtbar bleibt
    b.suit:SetPoint("LEFT", b.rank, "RIGHT", 1, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(w * 0.42, w * 0.42)
    b.icon:SetPoint("CENTER", 4, -6)
    b.sel = ns.Box(b, "OVERLAY", 1, 0.82, 0, 0.35)
    b.sel:SetAllPoints()
    b.sel:Hide()
    for k, fn in pairs(CardMethods) do b[k] = fn end
    return b
end

-- Leerer Platz (gestrichelter Rahmen)
function Cards.CreateSlot(parent, w, h, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local edge = ns.Box(b, "BACKGROUND", 1, 1, 1, 0.12)
    edge:SetAllPoints()
    local inner = ns.Box(b, "BORDER", 0, 0, 0, 0.35)
    inner:SetPoint("TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", -2, 2)
    if label then
        b.label = ns.FontString(b, "GameFontDisableSmall", "CENTER")
        b.label:SetPoint("CENTER")
        b.label:SetText(label)
    end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(w * 0.45, w * 0.45)
    b.icon:SetPoint("CENTER")
    b.icon:SetAlpha(0.35)
    b.icon:Hide()
    return b
end
