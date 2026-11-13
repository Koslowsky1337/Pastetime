-- Layout-Rechner für die WoW-Attrappe (nur Tests, kommt nicht ins Addon-Zip)
-- Rechnet Anker und Größen wie WoW aus (y wächst nach oben, UIParent 1920×1080),
-- schätzt Textbreiten je Schrift und bildet Umbruch und Abschneiden nach.
-- Damit findet ns.LayoutCheck auch in den Tests überstehende, abgeschnittene und
-- überlappende Texte – in allen Sprachen und für beide Fraktionen.
local M = MOCK_METHODS

local FONT_SIZE = {
    GameFontNormal = 12, GameFontHighlight = 12, GameFontDisable = 12,
    GameFontNormalSmall = 10, GameFontHighlightSmall = 10, GameFontDisableSmall = 10,
    GameFontNormalLarge = 16, GameFontHighlightLarge = 16, GameFontNormalHuge = 20, GameFontHighlightHuge = 20,
    ChatFontNormal = 14, QuestFont = 13, QuestTitleFont = 17, QuestFontNormalSmall = 12,
    ZoneTextFont = 32, SubZoneTextFont = 24, Game30Font = 30, Game24Font = 24, Game20Font = 20,
}
for n in pairs(FONT_SIZE) do if _G[n] then _G[n].__name = n end end
UIParent.w, UIParent.h = 1920, 1080

-- Breite eines Zeichens in Schriftgrößen-Einheiten (grob nach Friz Quadrata)
local NARROW = {}
for c in ("il.,:;'!|ftjI()[]1 "):gmatch(".") do NARROW[c] = true end
local function charWidth(ch)
    if ch == " " then return 0.28 end
    if NARROW[ch] then return 0.3 end
    if #ch == 1 and (ch:match("%u") or ch == "m" or ch == "w") then return 0.72 end
    if ch == "Ä" or ch == "Ö" or ch == "Ü" then return 0.72 end
    return 0.55
end
local function plainText(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  "))
end
local function textWidth(s, size)
    local w = 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do w = w + charWidth(ch) end
    return w * size
end

local function fontSize(o) return o.fontSize or FONT_SIZE[o.font or ""] or 12 end
local function lineHeight(o) return fontSize(o) * 1.15 + (o.spacing or 0) end

-- Zeilen eines Textes bei gegebener Breite (nil = ohne Umbruch)
local function layoutLines(o, width)
    local size = fontSize(o)
    local lines, widest = 0, 0
    for para in (plainText(o.text) .. "\n"):gmatch("(.-)\n") do
        local pw = textWidth(para, size)
        if not width or o.wrap == false or pw <= width + 0.5 then
            lines = lines + 1
            widest = math.max(widest, width and o.wrap ~= false and math.min(pw, width) or pw)
        else
            local cur = 0
            lines = lines + 1
            for word in para:gmatch("%S+") do
                local ww = textWidth(word, size)
                local add = (cur > 0 and textWidth(" ", size) or 0) + ww
                if cur > 0 and cur + add > width then
                    lines, cur = lines + 1, ww
                else
                    cur = cur + add
                end
                widest = math.max(widest, math.min(cur, width))
            end
        end
    end
    return lines, widest
end

-- Objekte anlegen: Eltern kennen ihre Kinder und Regionen ----------------------
local function adopt(parent, obj, list)
    if parent then
        parent[list] = parent[list] or {}
        table.insert(parent[list], obj)
    end
end
local origCreateFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local f = origCreateFrame(kind, name, parent, template)
    adopt(parent, f, "__children")
    template = template or ""
    if template:find("UIPanelButtonTemplate") then
        f.Text = Mock("FontString", nil, f)
        f.Text.font = "GameFontNormal"
        adopt(f, f.Text, "__regions")
        f.Text:SetPoint("CENTER")
    elseif f.Text then
        adopt(f, f.Text, "__regions")
        f.Text.font = "GameFontNormalSmall"
        if template == "UICheckButtonTemplate" then
            f.Text:SetPoint("LEFT", f, "RIGHT", 0, 1)
        else
            f.Text:SetPoint("CENTER")
            f.w, f.h = 120, 32          -- Reiter: Blizzard passt die Breite an den Text an
        end
    end
    return f
end
function M:CreateTexture() local t = Mock("Texture", nil, self); adopt(self, t, "__regions"); return t end
function M:CreateFontString(_, _, font)
    local t = Mock("FontString", nil, self)
    t.font = type(font) == "table" and font.__name or font or "GameFontNormal"
    adopt(self, t, "__regions")
    return t
end
function M:SetFontObject(f) self.font = type(f) == "table" and f.__name or f end
function M:SetFont(_, size) self.fontSize = size; return true end
function M:SetSpacing(s) self.spacing = s end
function M:SetWordWrap(v) self.wrap = v and true or false end
function M:SetMaxLines(n) self.maxLines = n end
function M:SetJustifyH(j) self.justifyH = j end
function M:GetJustifyH() return self.justifyH or "CENTER" end
function M:GetJustifyV() return self.justifyV or "MIDDLE" end
function M:SetJustifyV(j) self.justifyV = j end
function M:GetRegions() return unpack(self.__regions or {}) end
function M:GetChildren() return unpack(self.__children or {}) end
function M:GetObjectType() return self.__kind end
function M:GetDebugName() return self.__name or self.__kind end
local origSetText = M.SetText
function M:SetText(t)
    origSetText(self, t)
    if self.Text and self.Text ~= self and self.__kind ~= "FontString" then self.Text:SetText(t) end
end

-- Größen und Anker ---------------------------------------------------------------
function M:SetSize(w, h) self.w, self.h = w, h end
function M:SetWidth(w) self.w = w end
function M:SetHeight(h) self.h = h end
local function norm(self, p, a, b, c, d)
    if type(a) == "string" then a = _G[a] end
    if a == nil or type(a) == "number" then return self.__parent, p, a or 0, b or 0 end
    if type(b) == "string" then return a, b, c or 0, d or 0 end
    return a, p, b or 0, c or 0
end
function M:SetPoint(p, a, b, c, d)
    self.points[p] = { a, b, c, d }          -- wie bisher (einige Tests lesen das)
    self.anchors = self.anchors or {}
    local rel, rp, x, y = norm(self, p, a, b, c, d)
    self.anchors[p] = { rel = rel, rp = rp, x = x, y = y }
end
function M:ClearAllPoints() self.points, self.anchors = {}, {} end
function M:SetAllPoints(rel)
    rel = rel or self.__parent
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0)
end
-- Scroll-Kind bekommt die Breite des Scrollbereichs (wie OnSizeChanged im Spiel)
function M:SetScrollChild(child)
    child:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    child:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
end

local FX = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local FY = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0 }

local depth = 0
local rect
-- eine Achse: Grenzwerte aus den Ankern, Größe fest oder aus zwei Ankern
-- Wie WoW: Größe nur aus zwei gegenüberliegenden Kanten; ein zusätzlicher Mittel-Anker
-- (z. B. „RIGHT“ für die Breite) ändert die Höhe nicht.
local function axis(cons, size)
    local lo, hi, mid
    for _, c in ipairs(cons) do
        if c[1] == 0 then lo = c elseif c[1] == 1 then hi = c else mid = c end
    end
    if lo and hi then return lo[2], hi[2] - lo[2], true end
    local c = lo or hi or mid
    if not c then return nil end
    size = size or 0
    return c[2] - size * c[1], size, false
end

rect = function(o)
    if o == UIParent then return 0, 0, 1920, 1080 end
    depth = depth + 1
    if depth > 60 then depth = depth - 1; return nil end
    local xs, ys = {}, {}
    for p, a in pairs(o.anchors or {}) do
        local rl, rb, rw, rh = rect(a.rel or o.__parent or UIParent)
        if rl then
            xs[#xs + 1] = { FX[p], rl + rw * FX[a.rp] + a.x }
            ys[#ys + 1] = { FY[p], rb + rh * FY[a.rp] + a.y }
        end
    end
    local isText = o.__kind == "FontString"
    local w = o.w
    if isText and not w then
        local _, widest = layoutLines(o, nil)
        w = widest
    end
    local l, width, fromAnchors = axis(xs, w)
    if not l then depth = depth - 1; return nil end
    if isText and (fromAnchors or o.w) then o.__wrapW = width else o.__wrapW = nil end
    local h = o.h
    if isText and not h then
        local lines = layoutLines(o, o.__wrapW)
        if o.maxLines then lines = math.min(lines, o.maxLines) end
        h = lines * lineHeight(o)
    end
    local b, height = axis(ys, h)
    depth = depth - 1
    if not b then return nil end
    return l, b, width, height
end

function M:GetLeft() local l = rect(self); return l end
function M:GetRight() local l, _, w = rect(self); return l and l + w end
function M:GetTop() local _, b, _, h = rect(self); return b and b + h end
function M:GetBottom() local _, b = rect(self); return b end
function M:GetWidth() local _, _, w = rect(self); return w or self.w or 0 end
function M:GetHeight() local _, _, _, h = rect(self); return h or self.h or 0 end
function M:GetCenter()
    local l, b, w, h = rect(self)
    if not l then return 0, 0 end
    return l + w / 2, b + h / 2
end
function M:GetStringWidth()
    rect(self)
    local _, widest = layoutLines(self, self.__wrapW)
    return widest
end
function M:GetStringHeight()
    rect(self)
    local lines = layoutLines(self, self.__wrapW)
    if self.maxLines then lines = math.min(lines, self.maxLines) end
    return lines * lineHeight(self)
end
-- abgeschnitten: einzeilig zu breit, oder mehr Zeilen als Höhe/Zeilenzahl erlaubt
function M:IsTruncated()
    if (self.text or "") == "" then return false end
    local _, _, w, h = rect(self)
    if not w then return false end
    if self.wrap == false or not self.__wrapW then
        local _, widest = layoutLines(self, nil)
        if (self.wrap == false or self.w) and widest > w + 1 then return true end
    end
    local lines = layoutLines(self, self.__wrapW)
    if self.maxLines and lines > self.maxLines then return true end
    if self.h and lines * lineHeight(self) > self.h + 1 then return true end
    return false
end
