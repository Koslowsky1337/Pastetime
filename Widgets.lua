-- Pastime: Bausteine im Classic-Stil (Rahmen, Knöpfe, Pergament, Raster, Landealarm)
local ADDON, ns = ...
local L = ns.L

ns.TEX = {
    highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    header    = "Interface\\DialogFrame\\UI-DialogBox-Header",
    parchment = "Interface\\QuestFrame\\QuestBG",
    slot      = "Interface\\Buttons\\UI-Quickslot2",
    plus      = "Interface\\Buttons\\UI-PlusButton-Up",
    minus     = "Interface\\Buttons\\UI-MinusButton-Up",
    plusHi    = "Interface\\Buttons\\UI-PlusButton-Hilight",
    closeUp   = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
    closeDown = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down",
    closeHi   = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
    cellHi    = "Interface\\Buttons\\ButtonHilight-Square",
    question  = "Interface\\Icons\\INV_Misc_QuestionMark",
    dice      = "Interface\\Icons\\INV_Misc_Dice_01",
    kind      = {
        flug = "Interface\\Minimap\\Tracking\\FlightMaster",
        zeppelin = "Interface\\Icons\\INV_HordeZeppelinMountClassic",
        schiff = "Interface\\Icons\\INV_Misc_Anchor",
        test = "Interface\\Icons\\Trade_Engineering",
    },
}

local TOOLTIP_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
ns.TOOLTIP_BACKDROP = TOOLTIP_BACKDROP

function ns.SetIcon(tex, path, crop)
    local ok = tex:SetTexture(path)
    if ok == false then tex:SetTexture(ns.TEX.question) end
    if crop ~= false then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end

-- Fensterfarben je Fraktion: Horde rot, Allianz blau (ns.ApplyFaction wählt beim Login)
ns.THEMES = {
    Horde = { border = { 1, 0.55, 0.45 }, bg = { 1, 0.82, 0.8 }, inset = { 0.72, 0.42, 0.36 },
        crest = "Interface\\Icons\\Achievement_PVP_H_H" },
    Alliance = { border = { 0.55, 0.72, 1 }, bg = { 0.8, 0.88, 1 }, inset = { 0.42, 0.55, 0.8 },
        crest = "Interface\\Icons\\Achievement_PVP_A_A" },
}
ns.THEME = ns.THEMES.Horde

-- Dialograhmen (Hauptfenster, Overlays, Hinweise) in der Fraktionsfarbe tönen
function ns.TintDialog(f)
    local t = ns.THEME
    f:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)
    f:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 1)
end

function ns.CreateInset(parent, alpha)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(TOOLTIP_BACKDROP)
    f:SetBackdropColor(0, 0, 0, alpha or 0.6)
    local c = ns.THEME.inset
    f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    return f
end

-- Pergament wie im Questlog; ohne Textur bleibt ein dunkler Rahmen
function ns.CreateParchment(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop(TOOLTIP_BACKDROP)
    f:SetBackdropColor(0.1, 0.08, 0.05, 1)
    local c = ns.THEME.inset
    f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    if bg:SetTexture(ns.TEX.parchment) == false then
        bg:Hide()
        f.dark = true
    else
        -- QuestBG ist nur links (~60 %) Pergament, rechts dunkel: nur das Papier zeigen
        bg:SetTexCoord(0, 0.58, 0, 0.62)
    end
    f.bg = bg
    return f
end

function ns.CreateButton(parent, text, width, onClick)
    local b = ns.AutoWrap(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"), "knopf:" .. tostring(text))
    b:SetSize(width or 100, 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- Klassischer Schließen-Knopf (das alte „X“)
function ns.CreateCloseButton(parent, onClick)
    local b = ns.AutoWrap(CreateFrame("Button", nil, parent), "schliessen")
    b:SetSize(32, 32)
    b:SetNormalTexture(ns.TEX.closeUp)
    b:SetPushedTexture(ns.TEX.closeDown)
    b:SetHighlightTexture(ns.TEX.closeHi, "ADD")
    b:SetScript("OnClick", onClick or function(self) self:GetParent():Hide() end)
    return b
end

function ns.CreateCheck(parent, label, onClick)
    local c = ns.AutoWrap(CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate"), "haken:" .. label)
    c:SetSize(24, 24)
    local text = c.Text or c.text
    if text then
        text:SetText(label)
        text:SetFontObject(GameFontNormalSmall)
    end
    c:SetScript("OnClick", function(self)
        ns.PlaySound(self:GetChecked() and "flag" or "click")
        if onClick then onClick(self, self:GetChecked() and true or false) end
    end)
    return c
end

function ns.SetTooltip(widget, title, ...)
    local lines = { ... }
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(type(title) == "function" and title(self) or title, 1, 0.82, 0)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.FontString(parent, font, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- Icon in einem klassischen Taschenplatz-Rahmen
function ns.CreateIconSlot(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local slot = f:CreateTexture(nil, "BACKGROUND")
    slot:SetTexture(ns.TEX.slot)
    slot:SetSize(size * 1.6, size * 1.6)
    slot:SetPoint("CENTER", 0, -size * 0.02)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    return f
end

-- Scrollbare Liste mit festen Zeilenhöhen
function ns.CreateScrollList(parent, rowHeight, createRow)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
    local obj = { scroll = sf, child = child, rows = {}, rowHeight = rowHeight }
    function obj:SetData(items, bind)
        child:SetWidth(sf:GetWidth())
        for i, item in ipairs(items) do
            local row = self.rows[i]
            if not row then
                row = createRow(child)
                row:SetHeight(rowHeight)
                row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * rowHeight)
                row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
                self.rows[i] = row
            end
            row:Show()
            bind(row, item, i)
        end
        for i = #items + 1, #self.rows do self.rows[i]:Hide() end
        child:SetHeight(math.max(1, #items * rowHeight))
    end
    return obj
end

-- Zeile mit Questlog-Hervorhebung
function ns.CreateRow(parent)
    local row = ns.AutoWrap(CreateFrame("Button", nil, parent), "zeile")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture(ns.TEX.highlight, "ADD")
    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetTexture(ns.TEX.highlight)
    sel:SetBlendMode("ADD")
    sel:SetAllPoints()
    sel:Hide()
    row.selected = sel
    return row
end

---------------------------------------------------------------------------
-- Farbflächen mit leichtem Verlauf (wirkt wie ein Stein statt flach)
---------------------------------------------------------------------------
local hasGradient = (CreateColor ~= nil)

function ns.Paint(tex, r, g, b, a, shade)
    a = a or 1
    if shade and hasGradient and tex.SetGradient then
        local k = shade == true and 0.62 or shade
        tex:SetGradient("VERTICAL", CreateColor(r * k, g * k, b * k, a),
            CreateColor(math.min(1, r * 1.08 + 0.04), math.min(1, g * 1.08 + 0.04), math.min(1, b * 1.08 + 0.04), a))
    elseif hasGradient and tex.SetGradient then
        local c = CreateColor(r, g, b, a)
        tex:SetGradient("VERTICAL", c, c)
    else
        tex:SetVertexColor(r, g, b, a)
    end
end

function ns.NewTexture(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetColorTexture(1, 1, 1, 1)
    return t
end

-- Raster aus Farbzellen mit Zwischenspeicher (nur Geändertes wird neu gemalt)
function ns.CreateGrid(parent, cols, rows, size, gap, layer)
    local grid = { cols = cols, rows = rows, size = size, cells = {}, cache = {} }
    gap = gap or 1
    for y = 1, rows do
        for x = 1, cols do
            local t = ns.NewTexture(parent, layer or "ARTWORK")
            t:SetSize(size - gap, size - gap)
            t:SetPoint("TOPLEFT", parent, "TOPLEFT", (x - 1) * size, -(y - 1) * size)
            grid.cells[(y - 1) * cols + x] = t
        end
    end
    function grid:Set(x, y, r, g, b, shade)
        local i = (y - 1) * self.cols + x
        local key = math.floor(r * 255) * 65536 + math.floor(g * 255) * 256 + math.floor(b * 255) + (shade and 0.5 or 0)
        if self.cache[i] ~= key then
            self.cache[i] = key
            ns.Paint(self.cells[i], r, g, b, 1, shade)
        end
    end
    function grid:Cell(x, y) return self.cells[(y - 1) * self.cols + x] end
    function grid:Invalidate() wipe(self.cache) end
    return grid
end

-- Einfarbige Fläche
function ns.Box(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- Aufsteigende Texte („+10“) – das Spiel ruft :Update(dt) auf
-- Fraktion des Spielers (neutral zählt als Horde): für Flaggen, Wappen, Kartenrücken
function ns.IsAlliance()
    local ok, f = pcall(UnitFactionGroup, "player")
    return ok and f == "Alliance"
end

-- Text über allem, was auf dem Spielfeld liegt (Kacheln, Knöpfe): Texte direkt auf
-- dem Spielfeld lägen unter dessen Kind-Frames. Bleibt unter Countdown und Overlays.
function ns.BoardText(board, font, justify)
    if not board.textLayer then
        local f = CreateFrame("Frame", nil, board)
        f:SetAllPoints()
        f:SetFrameLevel(board:GetFrameLevel() + 10)
        board.textLayer = f
    end
    return ns.FontString(board.textLayer, font, justify)
end

function ns.CreateFloaters(parent, n)
    local f = { pool = {} }
    for i = 1, n or 6 do
        local fs = ns.BoardText(parent, "GameFontNormalLarge", "CENTER")
        fs:Hide()
        f.pool[i] = { fs = fs, t = 0 }
    end
    function f:Spawn(text, x, y, r, g, b)
        local slot = self.pool[1]
        for _, p in ipairs(self.pool) do if p.t <= 0 then slot = p; break end end
        slot.t, slot.x, slot.y = 0.8, x, y
        slot.fs:SetText(text)
        slot.fs:SetTextColor(r or 1, g or 0.82, b or 0)
        slot.fs:SetAlpha(1)
        slot.fs:ClearAllPoints()
        slot.fs:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
        slot.fs:Show()
    end
    function f:Update(dt)
        for _, p in ipairs(self.pool) do
            if p.t > 0 then
                p.t = p.t - dt
                if p.t <= 0 then
                    p.fs:Hide()
                else
                    p.fs:SetAlpha(math.min(1, p.t / 0.4))
                    p.fs:SetPoint("CENTER", parent, "TOPLEFT", p.x, -(p.y - (0.8 - p.t) * 40))
                end
            end
        end
    end
    function f:Clear()
        for _, p in ipairs(self.pool) do p.t = 0; p.fs:Hide() end
    end
    return f
end

-- Knopf mit Symbol (für Spielfelder)
function ns.IconButton(parent, size, icon)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    if icon then ns.SetIcon(b.icon, icon) end
    b:SetHighlightTexture(ns.TEX.cellHi, "ADD")
    return b
end

---------------------------------------------------------------------------
-- Kopierfenster (für /pastime log)
---------------------------------------------------------------------------
function ns.ShowCopy(title, text)
    local f = ns.copyFrame
    if not f then
        f = CreateFrame("Frame", "PastimeCopyFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop(BACKDROP_DIALOG_32_32 or TOOLTIP_BACKDROP)
        ns.TintDialog(f)
        f:SetSize(560, 320)
        f:SetPoint("CENTER", 0, 60)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f.title = ns.FontString(f, "GameFontNormal", "CENTER")
        f.title:SetPoint("TOP", 0, -18)
        local hint = ns.FontString(f, "GameFontDisableSmall", "CENTER")
        hint:SetPoint("BOTTOM", 0, 18)
        hint:SetText(L["The text is selected: |cffffffffCtrl+C|r copies, |cffffffffEsc|r closes."])
        local inset = ns.CreateInset(f)
        inset:SetPoint("TOPLEFT", 18, -38)
        inset:SetPoint("BOTTOMRIGHT", -18, 38)
        local sf = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 8, -8)
        sf:SetPoint("BOTTOMRIGHT", -28, 8)
        local edit = CreateFrame("EditBox", nil, sf)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal or GameFontHighlight)
        edit:SetWidth(480)
        sf:SetScrollChild(edit)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        edit:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(f.text or ""); self:HighlightText() end
        end)
        f.edit = edit
        ns.CreateCloseButton(f):SetPoint("TOPRIGHT", -4, -4)
        tinsert(UISpecialFrames, "PastimeCopyFrame")
        ns.copyFrame = f
    end
    f.text = text or ""
    f.title:SetText(title or L["Copy"])
    f.edit:SetText(f.text)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Großer Hinweistext in der Bildschirmmitte („Gelandet!“)
---------------------------------------------------------------------------
function ns.Alert(title, sub)
    local a = ns.alertFrame
    if not a then
        a = CreateFrame("Frame", "PastimeAlertFrame", UIParent)
        a:SetSize(700, 110)
        a:SetPoint("TOP", 0, -150)
        a:SetFrameStrata("HIGH")
        a.title = a:CreateFontString(nil, "OVERLAY", "ZoneTextFont")
        a.title:SetPoint("TOP")
        a.sub = a:CreateFontString(nil, "OVERLAY", "SubZoneTextFont")
        a.sub:SetPoint("TOP", a.title, "BOTTOM", 0, -6)
        a:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            if self.t > 5 then self:Hide()
            elseif self.t > 3.5 then self:SetAlpha(1 - (self.t - 3.5) / 1.5) end
        end)
        ns.alertFrame = a
    end
    a.title:SetText(title or "")
    a.title:SetTextColor(1, 0.82, 0)
    a.sub:SetText(sub or "")
    a.sub:SetTextColor(1, 1, 1)
    a.t = 0
    a:SetAlpha(1)
    a:Show()
end
