-- Pastime: Hauptfenster (Spielauswahl + Spielansicht), Tastatur, Pause, Flug/Kampf
local ADDON, ns = ...
local L = ns.L

local W, H = 720, 500
local LIST_W = 240
local BOARD_W, BOARD_H = 444, 454

ns.run = nil          -- laufende Partie: { def, mode, game, state = running|paused|over, t }
ns.selected = nil     -- in der Auswahl markiertes Spiel

---------------------------------------------------------------------------
-- Schnittstelle für die Spiele
---------------------------------------------------------------------------
local host = {}
ns.host = host

function host:IsRunning() return ns.run ~= nil and ns.run.state == "running" and not ns.run.countdown end

-- Countdown nach „Weiter“ (def.resumeDelay): Spiel steht, Eingaben werden geschluckt
function ns.SetCountdown(sec)
    if ns.run then ns.run.countdown = sec end
    local fs = ns.gameView and ns.gameView.countdown
    if fs then
        fs:SetText(sec and tostring(math.ceil(sec)) or "")
        fs:SetShown(sec ~= nil)
    end
end
function host:Sound(kind) ns.PlaySound(kind) end
function host:Refresh() if ns.UpdateSidePanel then ns.UpdateSidePanel() end end
function host:Over(res) ns.GameOver(res) end

---------------------------------------------------------------------------
-- Tastatur: Während einer Partie (und auf dem Endbildschirm) gehen ALLE
-- Tasten ans Spiel – keine Bewegung, kein Springen, keine Zauber. Durch
-- kommen nur Modifikatortasten und harmlose Bindungen (Chat, Screenshot,
-- Lautstärke, die eigene Pastime-Taste). In der Pause und im Kampf ist die
-- Tastatur frei. Wie RegionUtil.RunStandardKeybind bei Blizzard.
---------------------------------------------------------------------------
local kbOn = false
local downTaken = {}      -- Tasten, deren Drücken wir geschluckt haben

local PASS_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, PRINTSCREEN = true,
}
local PASS_BINDINGS = {
    OPENCHAT = true, OPENCHATSLASH = true, REPLY = true, REPLY2 = true,
    CHATPAGEUP = true, CHATPAGEDOWN = true, CHATBOTTOM = true,
    SCREENSHOT = true, TOGGLEMUSIC = true, TOGGLESOUND = true, MASTERVOLUMEUP = true, MASTERVOLUMEDOWN = true,
    PASTIME_TOGGLE = true, RELOADUI = true, FSTACK = true,
}
ns.PASS_BINDINGS = PASS_BINDINGS

local function bindingFor(key)
    local fn = GetBindingFromInput or GetBindingFromClick
    if not fn then return nil end
    local ok, action = pcall(fn, key)
    return ok and action or nil
end

function ns.UpdateKeyboard()
    local gv = ns.gameView
    if not gv then return end
    local run = ns.run
    local want = run ~= nil and gv:IsVisible()
        and (run.state == "running" or run.state == "over") and not InCombatLockdown()
    want = want and true or false
    if want ~= kbOn then
        pcall(gv.EnableKeyboard, gv, want)
        kbOn = want
        gv.kbOn = want
        wipe(downTaken)
        if not want and run and run.game.ClearKeys then run.game:ClearKeys() end
    end
end

-- Gibt true zurück, wenn die Taste geschluckt wird (nicht an WoW geht)
function ns.HandleKey(key, down)
    local run = ns.run
    if not down then
        -- Loslassen nur schlucken, wenn wir auch das Drücken hatten – sonst
        -- bliebe z. B. ein vor dem Spiel gedrücktes W in WoW „hängen“.
        local taken = downTaken[key]
        downTaken[key] = nil
        if run and run.state == "running" and run.game.Key then run.game:Key(key, false) end
        return taken and true or false
    end
    if not run or PASS_KEYS[key] then return false end
    local used = false
    if key == "ESCAPE" then
        if run.state == "running" then ns.Pause(); used = true
        elseif run.state == "over" then ns.ShowLauncher(); used = true end
    elseif run.state == "over" and key == "SPACE" then
        -- kurze Sperre: wer beim Absturz noch hämmert, soll das Ergebnis erst sehen
        if GetTime() - (run.overAt or 0) >= 1.5 then ns.Restart() end
        used = true
    elseif run.state == "running" and key == "P" and not run.def.textInput then
        ns.Pause(); used = true
    elseif run.countdown then
        -- Countdown läuft: nicht ans Spiel geben (wird unten geschluckt, Chat & Co. kommen durch)
    elseif run.state == "running" and run.game.Key and run.game:Key(key, true) then
        used = true
    end
    if not used and PASS_BINDINGS[bindingFor(key) or ""] then return false end
    downTaken[key] = true      -- alles andere schlucken
    return true
end

---------------------------------------------------------------------------
-- Partie starten / pausieren / beenden
---------------------------------------------------------------------------
local function GetBoard(def)
    if not def._board then
        local b = CreateFrame("Frame", nil, ns.boardArea)
        b:SetSize(def.width, def.height)
        b:SetPoint("CENTER")
        if b.SetClipsChildren then b:SetClipsChildren(true) end
        def._board = b
        def._game = def.Create(host, b)
    end
    return def._board
end

-- Partie verlassen. Abgebrochene Partien werden nie gewertet.
function ns.EndRun()
    local run = ns.run
    if not run then return end
    if run.state ~= "over" then ns.Log("D", "spiel", "Abort %s (not scored)", run.def.id) end
    if run.game.Stop then run.game:Stop() end
    ns.run = nil
end

function ns.StartGame(def, mode)
    if not ns.frame then ns.CreateMainFrame() end
    if InCombatLockdown() then
        ns.Print(L["Not possible in combat – finish the fight first."])
        return
    end
    ns.EndRun()
    mode = mode or ns.DefaultMode(def)
    if mode then ns.DB.modes[def.id] = mode end
    ns.DB.lastGame = def.id
    ns.selected = def
    GetBoard(def)
    for _, d in ipairs(ns.games) do
        if d._board then d._board:SetShown(d == def) end
    end
    local trip = ns.trip
    ns.run = { def = def, mode = mode, game = def._game, state = "running", t = 0,
        tripId = trip.active and trip.id or nil }
    ns.SetCountdown(nil)
    def._game:Start(mode)          -- erst starten, dann anzeigen (die Seitenleiste fragt sofort ab)
    ns.frame:Show()
    ns.ShowView("game")
    ns.HideOverlay()
    ns.CountGame(def.id)
    if trip.active then trip.played = true end
    ns.PlaySound("start")
    ns.Log("D", "spiel", "Start %s %s", def.id, tostring(mode))
    ns.UpdateKeyboard()
    ns.UpdateSidePanel()
end

function ns.Restart()
    local run = ns.run
    if run then ns.StartGame(run.def, run.mode) end
end

function ns.Pause(reason)
    local run = ns.run
    if not run or run.state ~= "running" then return end
    run.state = "paused"
    ns.SetCountdown(nil)
    if run.game.OnPause then run.game:OnPause() end
    local text = (reason and reason ~= "") and (reason .. "\n\n") or ""
    ns.ShowOverlay("pause", L["Paused"], text .. L["|cffbbbbbbYour keys are free – you can move.\nClick or press “Resume” to continue. “Quit” does not score the round.|r"])
    ns.UpdateKeyboard()
    ns.UpdateSidePanel()
end

function ns.Resume()
    local run = ns.run
    if not run or run.state ~= "paused" then return end
    if InCombatLockdown() then
        ns.Print(L["Not possible in combat."])
        return
    end
    run.state = "running"
    run.landed = nil
    ns.HideOverlay()
    ns.SetCountdown(run.def.resumeDelay)
    if run.game.OnResume then run.game:OnResume() end
    if ns.trip.active then ns.trip.played = true end
    ns.UpdateKeyboard()
    ns.UpdateSidePanel()
end

function ns.GameOver(res)
    local run = ns.run
    if not run or run.state == "over" then return end
    res = res or {}
    run.state = "over"
    run.overAt = GetTime()
    local def = run.def
    local rank, personal, routeRank, route
    if res.score and res.submit ~= false then
        rank, personal = ns.SubmitScore(def, run.mode, res.score)
        routeRank, route = ns.TripResult(run, res.score)
    end
    local lines = {}
    if res.text then table.insert(lines, res.text) end
    if res.score and res.submit ~= false then
        table.insert(lines, ("%s: |cffffffff%s|r"):format(def.scoreLabel or L["Points"], ns.FormatScore(def, res.score)))
    end
    if rank == 1 then
        table.insert(lines, L["|cff80ff80New record!|r"])
    elseif personal and rank then
        table.insert(lines, L["|cff80ff80Your personal best!|r"])
    elseif rank then
        table.insert(lines, (L["Rank %d on the leaderboard"]):format(rank))
    end
    if routeRank == "vorgemerkt" then
        table.insert(lines, L["|cff80ff80Counts for the route once you arrive.|r"])
    elseif routeRank and route then
        table.insert(lines, routeRank == 1 and (L["|cff80ff80Route record %s!|r"]):format(ns.RouteLabel(route))
            or (L["Route %s: rank %d"]):format(ns.RouteLabel(route), routeRank))
    end
    table.insert(lines, L["|cffbbbbbbSpace: play again · Esc: back to games|r"])
    ns.ShowOverlay("over", res.won and L["Victory!"] or (res.title or L["Game over"]), table.concat(lines, "\n"))
    ns.PlaySound(rank == 1 and "record" or (res.won and "big" or "over"))
    ns.UpdateKeyboard()
    ns.UpdateSidePanel()
end

---------------------------------------------------------------------------
-- Overlay über dem Spielfeld (Pause / Spielende)
---------------------------------------------------------------------------
local function CreateOverlay(parent)
    local o = ns.AutoWrap(CreateFrame("Frame", nil, parent), "overlay")
    o:SetPoint("TOPLEFT", 4, -4)
    o:SetPoint("BOTTOMRIGHT", -4, 4)
    o:SetFrameLevel(parent:GetFrameLevel() + 30)
    o:EnableMouse(true)
    o.shade = o:CreateTexture(nil, "BACKGROUND")
    o.shade:SetAllPoints()
    o.shade:SetColorTexture(0, 0, 0, 0.7)
    local box = CreateFrame("Frame", nil, o, "BackdropTemplate")
    box:SetBackdrop(BACKDROP_DIALOG_32_32 or ns.TOOLTIP_BACKDROP)
    ns.TintDialog(box)
    box:SetSize(340, 170)
    box:SetPoint("CENTER")
    o.box = box
    o.title = ns.FontString(box, "GameFontNormalHuge", "CENTER")
    o.title:SetPoint("TOP", 0, -22)
    o.text = ns.FontString(box, "GameFontHighlight", "CENTER")
    o.text:SetPoint("TOP", o.title, "BOTTOM", 0, -10)
    o.text:SetWidth(300)
    o.btn1 = ns.CreateButton(box, L["Resume"], 130)
    o.btn1:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -4, 20)
    o.btn2 = ns.CreateButton(box, L["Back to games"], 130)
    o.btn2:SetPoint("BOTTOMLEFT", box, "BOTTOM", 4, 20)
    o:SetScript("OnMouseUp", function(self)
        if self.kind == "pause" and ns.run and ns.run.state == "paused" then ns.Resume() end
    end)
    o:Hide()
    return o
end

function ns.ShowOverlay(kind, title, text)
    local o = ns.overlay
    if not o then return end
    o.kind = kind
    o.title:SetText(title or "")
    o.text:SetText(text or "")
    o.btn2:SetScript("OnClick", function() ns.ShowLauncher() end)
    if kind == "pause" then
        o.shade:SetColorTexture(0, 0, 0, 0.78)
        o.btn1:SetText(L["Resume"])
        o.btn1:SetScript("OnClick", function() ns.Resume() end)
        o.btn2:SetText(L["Quit"])
    elseif kind == "landed" then
        local LV = ns.run and ns.run.landed
        o.shade:SetColorTexture(0, 0, 0, 0.78)
        o.btn1:SetText(L["Keep playing"])
        o.btn1:SetScript("OnClick", function() ns.Resume() end)
        if LV and LV.score then
            o.btn2:SetText(L["Finish & score"])
            o.btn2:SetScript("OnClick", function() ns.FinishLanded() end)
        else
            o.btn2:SetText(L["Quit"])
        end
    else
        o.shade:SetColorTexture(0, 0, 0, 0.35)
        o.btn1:SetText(L["Play again"])
        o.btn1:SetScript("OnClick", function() ns.Restart() end)
        o.btn2:SetText(L["Back to games"])
    end
    local th = o.text:GetStringHeight() or 40
    o.box:SetHeight(math.max(150, 112 + th))
    o:Show()
end

function ns.HideOverlay()
    if ns.overlay then ns.overlay:Hide() end
end

-- Ankunft während einer Partie: weiterspielen oder beenden und werten
function ns.ShowLandedOverlay()
    local run = ns.run
    local LV = run and run.landed
    if not LV then return end
    local K = ns.KINDS[LV.kind] or ns.KINDS.flug
    local def = run.def
    local lines = {}
    if LV.bound then
        if LV.score and LV.route then
            local place = LV.rank == 1 and L["|cff80ff80new route record!|r"]
                or (LV.rank and (L["rank %d"]):format(LV.rank) or L["not in the top 5"])
            table.insert(lines, (L["Route score %s:\n|cffffffff%s|r %s – %s"]):format(ns.RouteLabel(LV.route),
                ns.FormatScore(def, LV.score), def.scoreLabel or L["Points"], place))
        elseif not LV.route then
            table.insert(lines, L["Unknown route – no route score."])
        elseif def.lowerIsBetter then
            table.insert(lines, L["This game only counts when solved – no route score."])
        else
            table.insert(lines, L["No points yet – no route score."])
        end
    end
    if LV.score then
        table.insert(lines, L["|cffbbbbbbKeep playing: your final result will then only count for the leaderboard.|r"])
    end
    ns.ShowOverlay("landed", LV.dest and (L["%s in %s!"]):format(K.arrive, LV.dest) or (K.arrive .. "!"),
        table.concat(lines, "\n\n"))
end

function ns.FinishLanded()
    local run = ns.run
    if not (run and run.landed) then return end
    local score = run.landed.score
    run.landed = nil
    ns.GameOver({ score = score, title = L["Scored"], text = L["Finished on arrival."] })
end

---------------------------------------------------------------------------
-- Spielauswahl (links Liste nach Kategorien, rechts Pergament mit Details)
---------------------------------------------------------------------------
local function ListItems()
    local items = {}
    for _, cat in ipairs(ns.CATEGORIES) do
        local games = {}
        for _, g in ipairs(ns.games) do
            if g.category == cat.id then table.insert(games, g) end
        end
        table.sort(games, function(a, b)
            if a.length ~= b.length then return a.length == "kurz" end
            return a.order < b.order
        end)
        if #games > 0 then
            table.insert(items, { header = true, cat = cat, count = #games })
            if not ns.DB.collapsed[cat.id] then
                for _, g in ipairs(games) do table.insert(items, { def = g }) end
            end
        end
    end
    return items
end

local function CreateListRow(parent)
    local row = ns.CreateRow(parent)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(16, 16)
    row.toggle:SetPoint("LEFT", 4, 0)
    row.htext = ns.FontString(row, "GameFontNormal")
    row.htext:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 22, 0)
    row.name = ns.FontString(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", -36, 0)
    row.name:SetWordWrap(false)
    row.best = ns.FontString(row, "GameFontNormalSmall", "RIGHT")   -- Markierung kurz/lang
    row.best:SetPoint("RIGHT", -4, 0)
    row:SetScript("OnClick", function(self)
        if self.item.header then
            local id = self.item.cat.id
            ns.DB.collapsed[id] = not ns.DB.collapsed[id]
            ns.PlaySound("click")
        else
            ns.selected = self.item.def
            ns.PlaySound("click")
        end
        ns.UpdateUI()
    end)
    row:SetScript("OnDoubleClick", function(self)
        if not self.item.header then ns.StartGame(self.item.def) end
    end)
    row:SetScript("OnEnter", function(self)
        local def = self.item and self.item.def
        if not def then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(def.name, 1, 0.82, 0)
        local LV = ns.LENGTHS[def.length]
        if LV then GameTooltip:AddLine(L["Mainly "] .. LV.desc .. ".", 1, 1, 1, true) end
        local best = ns.BestScore(def, ns.DefaultMode(def))
        if best then
            GameTooltip:AddLine((L["Record: %s (%s)"]):format(ns.FormatScore(def, best.s), best.p or "?"), 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(L["Double-click to start the game."], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function BindListRow(row, item)
    row.item = item
    local header = item.header and true or false
    row.toggle:SetShown(header)
    row.htext:SetShown(header)
    row.icon:SetShown(not header)
    row.name:SetShown(not header)
    row.best:SetShown(not header)
    if header then
        row.toggle:SetTexture(ns.DB.collapsed[item.cat.id] and ns.TEX.plus or ns.TEX.minus)
        row.htext:SetText(item.cat.name)
        row.selected:Hide()
    else
        local def = item.def
        ns.SetIcon(row.icon, def.icon)
        row.name:SetText(def.name)
        local LV = ns.LENGTHS[def.length] or ns.LENGTHS.kurz
        -- Auf einer Reise mit wenig Restzeit lange Spiele abschwächen
        local left = ns.TripRemaining()
        local dim = left and left < 150 and def.length == "lang"
        row.best:SetText(("|cff%s%s|r"):format(dim and "777777" or LV.color, LV.label))
        row.selected:SetShown(ns.selected == def)
        row.name:SetTextColor(ns.selected == def and 1 or 0.9, ns.selected == def and 0.82 or 0.9, ns.selected == def and 0 or 0.9)
    end
end

local function Ink(fs, kind, dark)
    if dark then
        if kind == "head" then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(0.9, 0.9, 0.9) end
    else
        if kind == "head" then fs:SetTextColor(0.25, 0.12, 0) elseif kind == "soft" then fs:SetTextColor(0.3, 0.22, 0.1)
        else fs:SetTextColor(0.1, 0.06, 0.02) end
    end
end

local function CreateLauncher(parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()

    -- Liste
    local list = ns.CreateInset(v)
    list:SetPoint("TOPLEFT", 16, -30)
    list:SetPoint("BOTTOMLEFT", 16, 64)
    list:SetWidth(LIST_W)
    v.list = ns.CreateScrollList(list, 22, CreateListRow)
    v.list.scroll:SetPoint("TOPLEFT", 6, -6)
    v.list.scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    v.listFrame = list

    -- Details auf Pergament
    local d = ns.CreateParchment(v)
    d:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
    d:SetPoint("BOTTOMRIGHT", -16, 64)
    v.detail = d
    local dark = d.dark
    local textW = W - 16 - LIST_W - 6 - 16 - 36

    d.slot = ns.CreateIconSlot(d, 44)
    d.slot:SetPoint("TOPLEFT", 18, -18)
    d.title = ns.FontString(d, "QuestTitleFont")
    d.title:SetPoint("TOPLEFT", d.slot, "TOPRIGHT", 12, -2)
    d.title:SetPoint("RIGHT", -16, 0)
    Ink(d.title, "head", dark)
    d.cat = ns.FontString(d, "QuestFontNormalSmall")
    d.cat:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4)
    Ink(d.cat, "soft", dark)
    d.desc = ns.FontString(d, "QuestFont")
    d.desc:SetPoint("TOPLEFT", d.slot, "BOTTOMLEFT", 0, -14)
    d.desc:SetWidth(textW)
    Ink(d.desc, "text", dark)

    d.ctrlHead = ns.FontString(d, "QuestFont")
    d.ctrlHead:SetPoint("TOPLEFT", d.desc, "BOTTOMLEFT", 0, -12)
    d.ctrlHead:SetText(L["Controls"])
    Ink(d.ctrlHead, "head", dark)
    d.ctrl = ns.FontString(d, "QuestFontNormalSmall")
    d.ctrl:SetPoint("TOPLEFT", d.ctrlHead, "BOTTOMLEFT", 0, -4)
    d.ctrl:SetWidth(textW)
    Ink(d.ctrl, "text", dark)

    d.modeHead = ns.FontString(d, "QuestFont")
    d.modeHead:SetText(L["Difficulty"])
    Ink(d.modeHead, "head", dark)
    d.modeButtons = {}
    for i = 1, 3 do
        local b = ns.CreateButton(d, "", 120, function(self)
            ns.DB.modes[ns.selected.id] = self.modeId
            ns.PlaySound("click")
            ns.UpdateUI()
        end)
        b:SetHeight(20)
        if i == 1 then b:SetPoint("TOPLEFT", d.modeHead, "BOTTOMLEFT", 0, -4)
        else b:SetPoint("LEFT", d.modeButtons[i - 1], "RIGHT", 6, 0) end
        d.modeButtons[i] = b
    end

    d.scoreHead = ns.FontString(d, "QuestFont")
    d.scoreHead:SetText(L["Leaderboard"])
    Ink(d.scoreHead, "head", dark)
    d.scoreLines = {}
    for i = 1, 5 do
        local left = ns.FontString(d, "QuestFontNormalSmall")
        local right = ns.FontString(d, "QuestFontNormalSmall", "RIGHT")
        if i == 1 then left:SetPoint("TOPLEFT", d.scoreHead, "BOTTOMLEFT", 6, -5)
        else left:SetPoint("TOPLEFT", d.scoreLines[i - 1].left, "BOTTOMLEFT", 0, -3) end
        right:SetPoint("TOP", left, "TOP")
        right:SetPoint("RIGHT", d, "RIGHT", -40, 0)
        Ink(left, "text", dark)
        Ink(right, "text", dark)
        d.scoreLines[i] = { left = left, right = right }
    end

    d.stats = ns.FontString(d, "QuestFontNormalSmall")
    d.stats:SetPoint("BOTTOMLEFT", 18, 18)
    Ink(d.stats, "soft", dark)
    d.route = ns.FontString(d, "QuestFontNormalSmall")
    -- eigene Zeile über den Knöpfen, volle Textbreite (lange Ortsnamen)
    d.route:SetPoint("BOTTOMLEFT", 18, 46)
    d.route:SetWidth(textW)
    d.route:SetWordWrap(false)
    Ink(d.route, "head", dark)
    d.play = ns.CreateButton(d, L["Play"], 130, function()
        if ns.selected then ns.StartGame(ns.selected) end
    end)
    d.play:SetHeight(26)
    d.play:SetPoint("BOTTOMRIGHT", -16, 14)
    d.resume = ns.CreateButton(d, L["Continue"], 110, function()
        ns.ShowView("game")
    end)
    d.resume:SetHeight(26)
    d.resume:SetPoint("RIGHT", d.play, "LEFT", -6, 0)

    -- Fußzeile: Status + Einstellungen
    v.status = ns.FontString(v, "GameFontNormalSmall")
    v.status:SetPoint("BOTTOMLEFT", 22, 44)
    v.status:SetPoint("RIGHT", -22, 0)
    v.checks = {}
    local SETTINGS = {
        { "autoOpen", L["Open when travelling"], L["Opens the game collection when you take off from a flight master and while you wait at a zeppelin tower or boat dock. If you didn't play, it closes again when you arrive."] },
        { "landAlarm", L["Landing alarm"], L["On landing or arrival: pause the game, play a sound and show a large notice – then keep playing or finish and score."] },
        { "hideInCombat", L["Hide in combat"], L["The window hides as soon as you enter combat (the game always pauses)."] },
        { "sound", L["Game sounds"], L["Sounds for points, lines and game over."] },
    }
    for i, s in ipairs(SETTINGS) do
        local c = ns.CreateCheck(v, s[2], function(_, on)
            ns.DB.settings[s[1]] = on
            ns.UpdateUI()
            if ns.RefreshSettings then ns.RefreshSettings() end
        end)
        c:SetPoint("BOTTOMLEFT", 18 + (i - 1) * 172, 14)
        c.key = s[1]
        ns.SetTooltip(c, s[2], s[3])
        v.checks[i] = c
    end
    return v
end

function ns.UpdateLauncher()
    local v = ns.launcher
    if not (v and v:IsShown()) then return end
    if not ns.selected then ns.selected = ns.gamesById[ns.DB.lastGame or ""] or ns.games[1] end

    -- Liste
    v.list:SetData(ListItems(), BindListRow)

    -- Details
    local d, def = v.detail, ns.selected
    if def then
        local mode = ns.DefaultMode(def)
        ns.SetIcon(d.slot.icon, def.icon)
        d.title:SetText(def.name)
        local catName = ""
        for _, c in ipairs(ns.CATEGORIES) do if c.id == def.category then catName = c.name end end
        local LV = ns.LENGTHS[def.length] or ns.LENGTHS.kurz
        d.cat:SetText(catName .. (def.short and (" · " .. def.short) or "") .. "\n" .. LV.short)
        d.desc:SetText(def.desc or "")
        d.ctrl:SetText(def.controls or "")

        local anchor = d.ctrl
        if def.modes then
            d.modeHead:Show()
            d.modeHead:ClearAllPoints()
            d.modeHead:SetPoint("TOPLEFT", d.ctrl, "BOTTOMLEFT", 0, -12)
            for i, b in ipairs(d.modeButtons) do
                local m = def.modes[i]
                b:SetShown(m ~= nil)
                if m then
                    b:SetText(m.name)
                    b.modeId = m.id
                    if m.id == mode then b:LockHighlight() else b:UnlockHighlight() end
                end
            end
            anchor = d.modeButtons[1]
        else
            d.modeHead:Hide()
            for _, b in ipairs(d.modeButtons) do b:Hide() end
        end
        d.scoreHead:ClearAllPoints()
        d.scoreHead:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
        local modeName = ns.ModeName(def, mode)
        d.scoreHead:SetText(L["Leaderboard"] .. (modeName and (" – " .. modeName) or ""))
        local scores = ns.GetScores(def, mode)
        local tbest, troute = ns.TripBest(def, mode)
        local showRoute = troute or (ns.trip.active and ns.trip.from and ns.trip.to)
        -- mit Schwierigkeitsknöpfen und Streckenzeile reicht der Platz nur für vier Plätze
        local maxLines = (showRoute and def.modes) and 4 or 5
        for i, line in ipairs(d.scoreLines) do
            local e = i <= maxLines and scores[i]
            if e then
                line.left:SetText(("%d. %s  |cff6b5a3a%s|r"):format(i, e.p or "?", e.d or ""))
                line.right:SetText(ns.FormatScore(def, e.s))
            elseif i == 1 then
                line.left:SetText(L["No entries yet – be the first!"])
                line.right:SetText("")
            else
                line.left:SetText("")
                line.right:SetText("")
            end
        end
        local gs = ns.DB.stats.games[def.id]
        d.stats:SetText(gs and gs.n > 0 and (L["Played: %d× · %s"]):format(gs.n, ns.FormatTime(gs.t)) or L["Never played"])
        if showRoute then
            local label = troute and ns.RouteLabel(troute) or ns.RouteLabel(ns.trip)
            d.route:SetText(tbest and (L["Route %s: %s · %s"]):format(label, ns.FormatScore(def, tbest.s), tbest.p or "?")
                or (L["Route %s: no entry yet"]):format(label))
            d.route:Show()
        else
            d.route:Hide()
        end
        local unfinished = ns.run and ns.run.def == def and ns.run.state == "paused"
        d.resume:SetShown(unfinished and true or false)
        d.play:SetText(unfinished and L["New game"] or L["Play"])
    end

    -- Fußzeile
    local prefix = ""
    local errs = ns.SessionErrors()
    if errs > 0 then prefix = (L["|cffff6060%d error(s) – /pastime log|r · "]):format(errs) end
    if ns.DebugOn() then prefix = prefix .. "|cffffb040Debug|r · " end
    local fs = ns.TripStatus()
    if fs then
        v.status:SetText(prefix .. fs)
        v.status:SetTextColor(0.5, 1, 0.5)
    else
        local st = ns.DB.stats
        v.status:SetText(prefix .. (L["Total play time: %s · while travelling: %s"]):format(ns.FormatTime(st.total), ns.FormatTime(st.flight)))
        v.status:SetTextColor(0.75, 0.75, 0.75)
    end
    for _, c in ipairs(v.checks) do c:SetChecked(ns.DB.settings[c.key] and true or false) end
end

---------------------------------------------------------------------------
-- Spielansicht (links Spielfeld, rechts Seitenleiste)
---------------------------------------------------------------------------
local function CreateGameView(parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()

    local area = ns.CreateInset(v, 0.85)
    area:SetPoint("TOPLEFT", 16, -30)
    area:SetSize(BOARD_W, BOARD_H)
    ns.boardArea = area

    local side = ns.CreateInset(v, 0.6)
    side:SetPoint("TOPLEFT", area, "TOPRIGHT", 6, 0)
    side:SetPoint("BOTTOMRIGHT", -16, 16)
    v.side = side

    side.title = ns.FontString(side, "GameFontNormalLarge", "CENTER")
    side.title:SetPoint("TOPLEFT", 8, -14)
    side.title:SetPoint("TOPRIGHT", -8, -14)
    side.mode = ns.FontString(side, "GameFontDisableSmall", "CENTER")
    side.mode:SetPoint("TOP", side.title, "BOTTOM", 0, -3)

    side.scoreLabel = ns.FontString(side, "GameFontNormal", "CENTER")
    side.scoreLabel:SetPoint("TOP", 0, -50)
    side.score = ns.FontString(side, "GameFontHighlightHuge", "CENTER")
    side.score:SetPoint("TOP", side.scoreLabel, "BOTTOM", 0, -4)
    side.best = ns.FontString(side, "GameFontHighlightSmall", "CENTER")
    side.best:SetPoint("TOP", side.score, "BOTTOM", 0, -6)
    side.route = ns.FontString(side, "GameFontHighlightSmall", "CENTER")
    side.route:SetPoint("TOP", side.best, "BOTTOM", 0, -3)
    side.route:SetTextColor(0.5, 1, 0.5)

    side.info = {}
    for i = 1, 4 do
        local l = ns.FontString(side, "GameFontNormalSmall")
        l:SetPoint("TOPLEFT", 16, -138 - (i - 1) * 18)
        local r = ns.FontString(side, "GameFontHighlight", "RIGHT")
        r:SetPoint("TOPRIGHT", -16, -136 - (i - 1) * 18)
        side.info[i] = { l = l, r = r }
    end

    -- Vorschaufläche (z. B. nächster Stein)
    side.previewLabel = ns.FontString(side, "GameFontNormalSmall", "CENTER")
    side.previewLabel:SetPoint("TOP", 0, -212)
    local pv = ns.CreateInset(side, 0.8)
    pv:SetSize(96, 72)
    pv:SetPoint("TOP", side.previewLabel, "BOTTOM", 0, -4)
    host.preview = pv

    side.flight = ns.FontString(side, "GameFontNormalSmall", "CENTER")
    side.flight:SetPoint("BOTTOMLEFT", 10, 72)
    side.flight:SetPoint("BOTTOMRIGHT", -10, 72)
    side.flight:SetTextColor(0.5, 1, 0.5)
    side.controls = ns.FontString(side, "GameFontDisableSmall", "CENTER")
    side.controls:SetPoint("BOTTOMLEFT", side.flight, "TOPLEFT", 0, 8)
    side.controls:SetPoint("BOTTOMRIGHT", side.flight, "TOPRIGHT", 0, 8)

    side.pause = ns.CreateButton(side, L["Pause"], 100, function()
        if not ns.run then return end
        if ns.run.state == "running" then ns.Pause() elseif ns.run.state == "paused" then ns.Resume() end
    end)
    side.pause:SetPoint("BOTTOMRIGHT", side, "BOTTOM", -3, 42)
    side.restart = ns.CreateButton(side, L["Restart"], 100, function() ns.Restart() end)
    side.restart:SetPoint("BOTTOMLEFT", side, "BOTTOM", 3, 42)
    ns.SetTooltip(side.restart, L["Restart"], L["A running round is abandoned and not scored."])
    side.back = ns.CreateButton(side, L["Back to games"], 206, function() ns.ShowLauncher() end)
    side.back:SetPoint("BOTTOM", 0, 14)
    ns.SetTooltip(side.back, L["Back to games"], L["A running round is abandoned and not scored."])

    ns.overlay = CreateOverlay(area)

    -- großer Countdown über dem Spielfeld (unter den Overlays, klickdurchlässig)
    local cd = CreateFrame("Frame", nil, area)
    cd:SetAllPoints()
    cd:SetFrameLevel(area:GetFrameLevel() + 20)
    v.countdown = ns.FontString(cd, "GameFontNormalHuge", "CENTER")
    v.countdown:SetPoint("CENTER")
    if v.countdown.SetTextScale then v.countdown:SetTextScale(2.5) end
    v.countdown:Hide()

    -- Tastatur (bewusst ohne AutoWrap, damit die Weitergabe immer gesetzt wird)
    v:SetScript("OnKeyDown", function(self, key)
        local used = ns.Safe("taste", ns.HandleKey, key, true) and true or false
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not used) end
    end)
    v:SetScript("OnKeyUp", function(self, key)
        local used = ns.Safe("taste", ns.HandleKey, key, false) and true or false
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not used) end
    end)

    local acc = 0
    v:SetScript("OnUpdate", function(_, elapsed)
        local run = ns.run
        if run and run.state == "running" and run.countdown then
            local left = run.countdown - elapsed
            ns.SetCountdown(left > 0 and left or nil)
        elseif run and run.state == "running" then
            local dt = math.min(elapsed, 0.1)
            run.t = run.t + dt
            ns.AddPlayTime(run.def.id, dt)
            local ok, err = true, nil
            if run.game.Update then ok, err = pcall(run.game.Update, run.game, dt) end
            if not ok then
                ns.Log("E", "spiel:" .. run.def.id, "%s", tostring(err))
                local eh = geterrorhandler and geterrorhandler()
                if eh then pcall(eh, err) end
                ns.Pause(L["|cffff6060Error in the game – see /pastime log|r"])
            end
        end
        acc = acc + elapsed
        if acc >= 0.2 then
            acc = 0
            ns.Safe("seitenleiste", ns.UpdateSidePanel)
        end
    end)
    v:SetScript("OnHide", function() ns.Safe("spielansicht", ns.UpdateKeyboard) end)
    v:SetScript("OnShow", function() ns.Safe("spielansicht", ns.UpdateKeyboard) end)
    return v
end

function ns.UpdateSidePanel()
    local v = ns.gameView
    local run = ns.run
    if not (v and v:IsShown() and run) then return end
    local side, def, game = v.side, run.def, run.game
    side.title:SetText(def.name)
    side.mode:SetText(ns.ModeName(def, run.mode) or (def.short or ""))
    side.scoreLabel:SetText(def.scoreLabel or L["Points"])
    side.score:SetText(ns.FormatScore(def, game.score or 0))
    local best = ns.BestScore(def, run.mode)
    side.best:SetText(best and (L["Record: %s · %s"]):format(ns.FormatScore(def, best.s), best.p or "?") or L["No record yet"])
    local trip = ns.trip
    if run.tripId and trip.active and run.tripId == trip.id and trip.from and trip.to then
        local tbest = ns.TripBest(def, run.mode)
        side.route:SetText(tbest and (L["Route: %s · %s"]):format(ns.FormatScore(def, tbest.s), tbest.p or "?")
            or L["Route: no entry yet"])
    else
        side.route:SetText("")
    end
    local info = game.Info and game:Info() or {}
    for i, row in ipairs(side.info) do
        local e = info[i]
        row.l:SetText(e and e[1] or "")
        row.r:SetText(e and e[2] or "")
    end
    side.previewLabel:SetText(def.previewLabel or "")
    side.previewLabel:SetShown(def.previewLabel ~= nil)
    host.preview:SetShown(def.previewLabel ~= nil)
    -- Pause-Hinweis für alle Spiele gleich (bei Texteingabe ist P ein Buchstabe)
    local pause = def.textInput and L["Esc: pause"] or L["P/Esc: pause"]
    side.controls:SetText(def.controlsShort and (def.controlsShort .. "\n" .. pause) or pause)
    side.flight:SetText(ns.TripStatus() or "")
    side.pause:SetText(run.state == "paused" and L["Resume"] or L["Pause"])
    side.pause:SetEnabled(run.state ~= "over")
end

---------------------------------------------------------------------------
-- Hauptfenster
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Reiserekorde (Strecken mit Platz 1–3 je Spiel)
---------------------------------------------------------------------------
local MEDAL = { "996f00", "6e6e6e", "8a4b1c" }

local function RouteItems()
    local groups = {}
    for key, r in pairs(ns.DB.routes) do
        if type(r) == "table" and r.kind then
            groups[r.kind] = groups[r.kind] or {}
            table.insert(groups[r.kind], { key = key, route = r })
        end
    end
    local items = {}
    for _, kind in ipairs(ns.KIND_ORDER) do
        local list = groups[kind]
        if list then
            table.sort(list, function(a, b)
                local ta, tb = a.route.lastT or 0, b.route.lastT or 0
                if ta ~= tb then return ta > tb end
                return ns.RouteLabel(a.route) < ns.RouteLabel(b.route)
            end)
            table.insert(items, { header = true, kind = kind, count = #list })
            if not ns.DB.collapsed["route:" .. kind] then
                for _, e in ipairs(list) do table.insert(items, e) end
            end
        end
    end
    return items
end

local function CreateRouteRow(parent)
    local row = ns.CreateRow(parent)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(16, 16)
    row.toggle:SetPoint("LEFT", 4, 0)
    row.htext = ns.FontString(row, "GameFontNormal")
    row.htext:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 20, 0)
    row.name = ns.FontString(row, "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", -40, 0)
    row.name:SetWordWrap(false)
    row.info = ns.FontString(row, "GameFontDisableSmall", "RIGHT")
    row.info:SetPoint("RIGHT", -4, 0)
    row:SetScript("OnClick", function(self)
        if self.item.header then
            local id = "route:" .. self.item.kind
            ns.DB.collapsed[id] = not ns.DB.collapsed[id]
        else
            ns.selectedRoute = self.item.key
        end
        ns.PlaySound("click")
        ns.UpdateRecords()
    end)
    return row
end

local function BindRouteRow(row, item)
    row.item = item
    local header = item.header and true or false
    row.toggle:SetShown(header)
    row.htext:SetShown(header)
    row.icon:SetShown(not header)
    row.name:SetShown(not header)
    row.info:SetShown(not header)
    if header then
        row.toggle:SetTexture(ns.DB.collapsed["route:" .. item.kind] and ns.TEX.plus or ns.TEX.minus)
        row.htext:SetText(("%s (%d)"):format(ns.KINDS[item.kind].name, item.count))
        row.selected:Hide()
    else
        local r = item.route
        local tex = ns.TEX.kind[r.kind] or ns.TEX.question
        ns.SetIcon(row.icon, tex, tex:find("Icons") ~= nil)
        local current = ns.trip.active and ns.trip.from == r.from and ns.trip.to == r.to and ns.trip.kind == r.kind
        row.name:SetText((current and "|cff80ff80" or "") .. ns.RouteLabel(r) .. (current and "|r" or ""))
        row.info:SetText(r.t and ns.FormatTime(r.t) or "")
        row.selected:SetShown(ns.selectedRoute == item.key)
    end
end

local function RouteBody(r, dark)
    local head = dark and "ffd100" or "3f1f00"
    local soft = dark and "aaaaaa" or "6b5a3a"
    local lines = {}
    for _, def in ipairs(ns.games) do
        for _, m in ipairs(def.modes or { { id = nil } }) do
            local list = r.scores[ns.ScoreKey(def, m.id)]
            if list and #list > 0 then
                table.insert(lines, ("|cff%s%s%s|r"):format(head, def.name, m.name and (" – " .. m.name) or ""))
                for i = 1, math.min(3, #list) do
                    local e = list[i]
                    table.insert(lines, ("   |cff%s%d.|r  %s  ·  %s  |cff%s(%s)|r"):format(dark and "ffffff" or MEDAL[i], i,
                        ns.FormatScore(def, e.s), e.p or "?", soft, e.d or ""))
                end
                table.insert(lines, " ")
            end
        end
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

local function CreateRecords(parent)
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    local list = ns.CreateInset(v)
    list:SetPoint("TOPLEFT", 16, -30)
    list:SetPoint("BOTTOMLEFT", 16, 16)
    list:SetWidth(LIST_W + 30)
    v.list = ns.CreateScrollList(list, 22, CreateRouteRow)
    v.list.scroll:SetPoint("TOPLEFT", 6, -6)
    v.list.scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local d = ns.CreateParchment(v)
    d:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
    d:SetPoint("BOTTOMRIGHT", -16, 16)
    v.detail = d
    local dark = d.dark
    d.icon = ns.CreateIconSlot(d, 36)
    d.icon:SetPoint("TOPLEFT", 18, -18)
    d.title = ns.FontString(d, "QuestTitleFont")
    d.title:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, 0)
    d.title:SetPoint("RIGHT", -16, 0)
    d.title:SetWordWrap(false)
    Ink(d.title, "head", dark)
    d.sub = ns.FontString(d, "QuestFontNormalSmall")
    d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4)
    d.sub:SetPoint("RIGHT", -16, 0)
    Ink(d.sub, "soft", dark)
    d.rules = ns.FontString(d, "QuestFontNormalSmall")
    d.rules:SetPoint("BOTTOMLEFT", 18, 14)
    d.rules:SetPoint("BOTTOMRIGHT", -18, 14)
    d.rules:SetText(L["Rounds count if they were started and finished while travelling, or scored on arrival. Abandoned rounds never count."])
    Ink(d.rules, "soft", dark)
    local sf = CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 18, -72)
    sf:SetPoint("BOTTOMRIGHT", -34, 46)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(300, 10)
    sf:SetScrollChild(child)
    d.body = ns.FontString(child, "QuestFont")
    d.body:SetPoint("TOPLEFT", 0, 0)
    d.body:SetWidth(W - 16 - (LIST_W + 30) - 6 - 16 - 56)
    d.body:SetSpacing(3)
    Ink(d.body, "text", dark)
    d.scroll, d.child = sf, child
    return v
end

function ns.UpdateRecords()
    local v = ns.records
    if not (v and v:IsShown()) then return end
    local items = RouteItems()
    local t = ns.trip
    local curKey = (t.active and t.from and t.to) and ns.RouteKey(t.kind, t.from, t.to) or nil
    if not (ns.selectedRoute and ns.DB.routes[ns.selectedRoute]) then
        ns.selectedRoute = (curKey and ns.DB.routes[curKey]) and curKey or nil
        if not ns.selectedRoute then
            for _, it in ipairs(items) do if not it.header then ns.selectedRoute = it.key; break end end
        end
    end
    v.list:SetData(items, BindRouteRow)
    local d = v.detail
    local r = ns.selectedRoute and ns.DB.routes[ns.selectedRoute]
    if not r then
        ns.SetIcon(d.icon.icon, ns.TEX.dice)
        d.title:SetText(L["No journeys yet"])
        d.sub:SetText("")
        d.body:SetText(L["Take a flight path, a zeppelin or a boat. Whatever you play on the way ends up here – with first, second and third place for every game on each route."])
    else
        local K = ns.KINDS[r.kind] or ns.KINDS.flug
        local tex = ns.TEX.kind[r.kind] or ns.TEX.question
        ns.SetIcon(d.icon.icon, tex, tex:find("Icons") ~= nil)
        d.title:SetText(ns.RouteLabel(r))
        local sub = (L["%s · duration %s · travelled %d× · last %s"]):format(K.one, r.t and ns.FormatTime(r.t) or L["unknown"],
            r.n or 0, r.last or "–")
        if ns.selectedRoute == curKey then sub = sub .. L["\n|cff1a7a1aYou are travelling this route right now.|r"] end
        d.sub:SetText(sub)
        d.body:SetText(RouteBody(r, d.dark) or L["Nothing has been scored on this route yet."])
    end
    d.child:SetHeight((d.body:GetStringHeight() or 100) + 10)
end

---------------------------------------------------------------------------
-- Hauptfenster
---------------------------------------------------------------------------
local function SavePosition(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    ns.DB.frame = { point = point, relPoint = relPoint, x = x, y = y }
end

local TABS = { { "spiele", L["Games"] }, { "records", L["Route records"] } }

function ns.CreateMainFrame()
    if ns.frame then return ns.frame end
    local f = ns.AutoWrap(CreateFrame("Frame", "PastimeFrame", UIParent, "BackdropTemplate"), "fenster")
    f:SetBackdrop(BACKDROP_DIALOG_32_32 or ns.TOOLTIP_BACKDROP)
    ns.TintDialog(f)
    f:SetSize(W, H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self) end)
    local pos = ns.DB.frame
    if type(pos) == "table" and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", 0, 30)
    end
    f:Hide()

    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture(ns.TEX.header)
    header:SetSize(300, 64)
    header:SetPoint("TOP", 0, 12)
    local tb = ns.THEME.border
    header:SetVertexColor(tb[1], tb[2], tb[3])
    local title = ns.FontString(f, "GameFontNormal", "CENTER")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("Pastime")
    -- Wappen der Fraktion links neben dem Titel
    local crest = f:CreateTexture(nil, "OVERLAY")
    crest:SetSize(18, 18)
    crest:SetPoint("RIGHT", title, "LEFT", -6, 0)
    ns.SetIcon(crest, ns.THEME.crest)
    ns.CreateCloseButton(f):SetPoint("TOPRIGHT", -4, -4)

    ns.frame = f
    ns.launcher = CreateLauncher(f)
    ns.gameView = CreateGameView(f)
    ns.gameView:Hide()
    ns.records = CreateRecords(f)
    ns.records:Hide()

    -- Reiter unten (wie im Charakterfenster)
    f.tabs = {}
    for i, tdef in ipairs(TABS) do
        local tab = CreateFrame("Button", "PastimeFrameTab" .. i, f, "PanelTabButtonTemplate")
        if i == 1 then tab:SetPoint("BOTTOMLEFT", 12, -30) else tab:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", 4, 0) end
        tab:SetID(i)
        tab.key = tdef[1]
        if tab.Text then tab.Text:SetText(tdef[2]) else tab:SetText(tdef[2]) end
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
        tab:SetScript("OnClick", ns.Wrap("reiter", function(self)
            ns.PlaySound("click")
            if self.key == "records" then
                ns.ShowView("records")
            else
                ns.ShowView((ns.run and ns.run.state ~= "over") and "game" or "launcher")
            end
        end))
        f.tabs[i] = tab
    end

    f:SetScript("OnShow", function()
        ns.PlaySound("click")
        ns.UpdateUI()
    end)
    f:SetScript("OnHide", function()
        if ns.run and ns.run.state == "running" then ns.Pause() end
        ns.UpdateKeyboard()
    end)
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc >= 1 then
            acc = 0
            if ns.launcher:IsShown() then ns.Safe("auswahl", ns.UpdateLauncher) end
        end
    end)
    tinsert(UISpecialFrames, "PastimeFrame")
    return f
end

function ns.ShowView(which)
    if not ns.frame then return end
    if which ~= "game" and ns.run and ns.run.state == "running" then ns.Pause() end
    ns.launcher:SetShown(which == "launcher")
    ns.gameView:SetShown(which == "game")
    ns.records:SetShown(which == "records")
    ns.view = which
    for _, tab in ipairs(ns.frame.tabs) do
        local active = (tab.key == "records") == (which == "records")
        if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
            if active then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end
    ns.UpdateUI()
end

function ns.ShowLauncher()
    if ns.run and ns.run.state ~= "over" then ns.EndRun() end
    ns.run = nil
    ns.HideOverlay()
    ns.ShowView("launcher")
end

function ns.ShowFrame(view)
    local f = ns.CreateMainFrame()
    local unfinished = ns.run and ns.run.state ~= "over"
    if view == "records" then
        ns.ShowView("records")
    else
        ns.ShowView(unfinished and "game" or "launcher")
        if not unfinished then ns.run = nil end
    end
    f:Show()
end

function ns.ToggleFrame()
    if ns.frame and ns.frame:IsShown() then ns.frame:Hide() else ns.ShowFrame() end
end

function ns.UpdateUI()
    if not ns.frame then return end
    ns.Safe("auswahl", ns.UpdateLauncher)
    ns.Safe("seitenleiste", ns.UpdateSidePanel)
    ns.Safe("reiserekorde", ns.UpdateRecords)
    ns.UpdateKeyboard()
end

---------------------------------------------------------------------------
-- Reisen: Öffnen, Ankunft, Kampf
---------------------------------------------------------------------------
function ns.OpenForTrip()
    if ns.frame and ns.frame:IsShown() then return end
    ns.ShowFrame()
    ns.trip.autoOpened = true
end

function ns.OnTripTick()
    if ns.frame and ns.frame:IsShown() then
        ns.Safe("reise", ns.UpdateLauncher)
    end
end

-- Aufgerufen von ns.EndTrip, solange die Reise noch gilt
function ns.OnTripEnded(trip, arrived, route)
    local visible = ns.frame and ns.frame:IsShown()
    if not arrived then
        -- am Anleger gewartet und wieder gegangen
        if trip.autoOpened and not trip.played and visible then ns.frame:Hide() end
        return
    end
    local K = ns.KINDS[trip.kind] or ns.KINDS.flug
    local dest = ns.ShortName(trip.to)
    local run = ns.run
    local wasRunning = run ~= nil and run.state == "running"
    local unfinished = run ~= nil and run.state ~= "over"
    local bound = unfinished and run.tripId == trip.id
    if unfinished and (bound or wasRunning) then
        local score = ns.CurrentScore(run)
        local rank
        if bound and score and route then rank = ns.SubmitRouteScore(route, run.def, run.mode, score) end
        run.tripId = nil      -- ab jetzt zählt die Partie nur noch für die Bestenliste
        if run.state == "running" then
            run.state = "paused"
            if run.game.OnPause then run.game:OnPause() end
        end
        run.landed = { score = score, rank = rank, route = route, bound = bound, dest = dest, kind = trip.kind }
        ns.ShowLandedOverlay()
        ns.UpdateKeyboard()
    end
    if trip.autoOpened and not trip.played and visible then
        ns.frame:Hide()       -- automatisch geöffnet und nicht gespielt: wieder zu
        visible = false
    end
    if ns.DB.settings.landAlarm and (wasRunning or visible) then
        ns.Alert(K.arrive .. "!", dest)
        ns.PlaySound("alarm")
        if FlashClientIcon then pcall(FlashClientIcon) end
        ns.Print(("|cff80ff80%s%s!|r%s"):format(K.arrive, dest and (L[" in "] .. dest) or "",
            wasRunning and L[" Game paused – keep playing or finish & score."] or ""))
    end
    ns.UpdateUI()
end

function ns.OnCombat()
    local run = ns.run
    if run and run.state == "running" then ns.Pause(L["|cffff6060Combat!|r"]) end
    ns.UpdateKeyboard()
    if ns.DB.settings.hideInCombat and ns.frame and ns.frame:IsShown() then
        ns.frame:Hide()
        ns.Print(L["Combat – game collection hidden. |cffffffff/pastime|r brings it back."])
    end
end

---------------------------------------------------------------------------
-- Minimap-Knopf
---------------------------------------------------------------------------
local function PositionMinimap()
    local b = ns.minimapButton
    if not (b and Minimap) then return end
    local angle = math.rad(ns.DB.minimap.angle or 235)
    local r = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function ns.CreateMinimapButton()
    if ns.minimapButton or not Minimap then return end
    local b = ns.AutoWrap(CreateFrame("Button", "PastimeMinimapButton", Minimap), "minimap")
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    ns.SetIcon(icon, ns.TEX.dice)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", -1, 1)

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" and ns.OpenSettings then ns.OpenSettings() else ns.ToggleFrame() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Pastime", 1, 0.82, 0)
        local fs = ns.TripStatus()
        if fs then GameTooltip:AddLine(fs, 0.5, 1, 0.5, true) end
        if ns.run and ns.run.state == "paused" then
            GameTooltip:AddLine(ns.run.def.name .. L[" is paused"], 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Left-click: open/close"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Right-click: settings"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Drag: move"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.DB.minimap.angle = math.deg(math.atan2(y / scale - my, x / scale - mx))
            PositionMinimap()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    ns.minimapButton = b
    PositionMinimap()
    ns.UpdateMinimapButton()
end

function ns.UpdateMinimapButton()
    if ns.minimapButton then ns.minimapButton:SetShown(not ns.DB.minimap.hidden) end
end
