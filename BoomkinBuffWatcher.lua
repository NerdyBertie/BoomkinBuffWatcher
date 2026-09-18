-- Boomkin Buff Watcher
-- Displays Astral Power and the current Eclipse window (Solar/Lunar/Celestial) for Balance Druids.
--
-- Aura data (spellId/name on a unit's buffs) is restricted in current API versions,
-- so Eclipse state is not read from the buff itself. Instead, entering an Eclipse is
-- inferred from the cast that triggers it, and a local countdown is run from there.

local ADDON_NAME = ...

local BALANCE_SPEC_ID = 1 -- Balance is spec index 1 for Druids (Balance, Feral, Guardian, Restoration)

local function IsBalanceSpec()
    local specIndex = GetSpecialization()
    return specIndex == BALANCE_SPEC_ID
end

-- Mark of the Wild is available to every Druid spec, not just Balance — a
-- player who respecs into Restoration, Guardian, or Feral still wants to know
-- if it's up. So this checks class rather than spec, separately from the
-- Balance-only checks used everywhere else in this file.
local function IsDruid()
    local _, class = UnitClass("player")
    return class == "DRUID"
end

local SOLAR_TRIGGER = "Wrath"
local LUNAR_TRIGGER = "Starfire"
local CELESTIAL_TRIGGERS = {
    ["Celestial Alignment"] = 15,
    ["Incarnation: Chosen of Elune"] = 20,
}
local ECLIPSE_DURATION = 15

-- The "or {}" below only helps a brand-new install with no saved table at
-- all. An EXISTING saved table (from a version before this field existed)
-- keeps its old contents as-is and never gets new keys added automatically
-- — so any field added after the addon's first release needs to be
-- explicitly backfilled here too, or it stays nil for existing users forever.
local DEFAULTS = {
    point = "CENTER",
    x = 0,
    y = -150,
    motwPoint = "CENTER",
    motwX = 110,
    motwY = -100,
    hideOutOfCombat = true,
}

BoomkinBuffWatcherDB = BoomkinBuffWatcherDB or {}
for key, value in pairs(DEFAULTS) do
    if BoomkinBuffWatcherDB[key] == nil then
        BoomkinBuffWatcherDB[key] = value
    end
end

local RefreshOnHideCombatChanged -- forward declaration; assigned after RefreshVisibility is defined below

-- ============================================================
-- Settings panel
-- ============================================================
-- Built as a plain manual CheckButton with a direct read/write to
-- BoomkinBuffWatcherDB, matching the pattern already proven working in
-- ItemWatch's published options panel — rather than the newer
-- Settings.RegisterAddOnSetting/CreateCheckbox auto-binding API, which
-- did not reliably write through to the saved table in testing.

local settingsPanel = CreateFrame("Frame")
settingsPanel.name = "Boomkin Buff Watcher"

local settingsTitle = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
settingsTitle:SetPoint("TOPLEFT", 16, -16)
settingsTitle:SetText("Boomkin Buff Watcher")

local hideCombatCheck = CreateFrame("CheckButton", "BoomkinBuffWatcherHideCombatCheck", settingsPanel, "UICheckButtonTemplate")
hideCombatCheck:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", -2, -16)
_G["BoomkinBuffWatcherHideCombatCheckText"]:SetText("Hide outside of combat")

local hideCombatHint = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hideCombatHint:SetPoint("TOPLEFT", hideCombatCheck, "BOTTOMLEFT", 4, -4)
hideCombatHint:SetWidth(420)
hideCombatHint:SetJustifyH("LEFT")
hideCombatHint:SetWordWrap(true)
hideCombatHint:SetText("When on, the Astral Power/Eclipse HUD only appears in combat. Turn this off if you want it visible all the time -- useful for repositioning it without needing to be in a fight, e.g. with a controller. The Mark of the Wild reminder is unaffected either way, since it's meant to be checked before combat starts.")

hideCombatCheck:SetScript("OnClick", function(self)
    BoomkinBuffWatcherDB.hideOutOfCombat = self:GetChecked() and true or false
    RefreshOnHideCombatChanged()
end)

-- Sync the checkbox's displayed state from the saved value every time the
-- panel is opened, rather than trying to keep it continuously live-bound
settingsPanel:SetScript("OnShow", function()
    hideCombatCheck:SetChecked(BoomkinBuffWatcherDB.hideOutOfCombat)
end)

local settingsCategory
if Settings and Settings.RegisterCanvasLayoutCategory then
    settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
    Settings.RegisterAddOnCategory(settingsCategory)
end

-- ============================================================
-- Frame setup
-- ============================================================

local frame = CreateFrame("Frame", "BoomkinBuffWatcherFrame", UIParent, "BackdropTemplate")
frame:SetSize(200, 46)
frame:SetPoint(BoomkinBuffWatcherDB.point, UIParent, BoomkinBuffWatcherDB.point, BoomkinBuffWatcherDB.x, BoomkinBuffWatcherDB.y)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    BoomkinBuffWatcherDB.point = point
    BoomkinBuffWatcherDB.x = x
    BoomkinBuffWatcherDB.y = y
end)

frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
frame:SetBackdropColor(0, 0, 0, 0.6)
frame:SetBackdropBorderColor(0, 0, 0, 1)

-- Top row: Eclipse window label, its own line so it never collides with the AP text
local eclipseText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
eclipseText:SetPoint("TOP", frame, "TOP", 0, -4)

-- Small radial cooldown-swipe timer, the same visual Blizzard uses for action
-- bar cooldowns. This is NOT reading any secret/restricted data — the Eclipse
-- window's start time and duration are values this addon generates itself by
-- watching your own casts, so there's nothing here Blizzard's aura
-- restrictions apply to.
-- A plain backing square behind the swipe so it reads clearly as an icon-sized
-- timer rather than an empty transparent wedge
local eclipseCooldownBG = frame:CreateTexture(nil, "ARTWORK")
eclipseCooldownBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
eclipseCooldownBG:SetSize(20, 20)
eclipseCooldownBG:SetColorTexture(0.3, 0.3, 0.3, 0.8)
eclipseCooldownBG:Hide()

local eclipseCooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
eclipseCooldown:SetSize(20, 20)
eclipseCooldown:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
eclipseCooldown:SetHideCountdownNumbers(true) -- eclipseText already shows the seconds
eclipseCooldown:SetReverse(true) -- countdown sweep drains from full to empty
eclipseCooldown:Hide()

-- Bottom row: the Astral Power bar itself
local powerBar = CreateFrame("StatusBar", nil, frame)
powerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
powerBar:SetHeight(20)
powerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
powerBar:SetStatusBarColor(0.4, 0.3, 0.8) -- pale lavender, matches the Astral Power bar

local powerText = powerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
powerText:SetPoint("CENTER", powerBar, "CENTER", 0, 0)

-- Above 90% Astral Power, a gold overlay fills in and pulses. This never compares
-- the secret power value directly: the same secret number that already goes into
-- the main bar's SetValue() is handed to this second bar too, but its range is
-- only the top 10% (90..max) — below that it clamps to zero width and draws
-- nothing, above it fills proportionally, all via the widget's own native
-- rendering rather than any Lua-side math or comparison on the secret value.
local AP_WARNING_PERCENT = 90

local apGlowBar = CreateFrame("StatusBar", nil, powerBar)
apGlowBar:SetAllPoints(powerBar)
apGlowBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
apGlowBar:GetStatusBarTexture():SetBlendMode("ADD")
apGlowBar:SetStatusBarColor(1, 0.85, 0.1, 0.7)

-- ============================================================
-- Mark of the Wild reminder
-- ============================================================
-- Available to every Druid spec, not just Balance, so this is gated on class
-- rather than spec (see IsDruid() above) — a Restoration or Guardian Druid
-- still wants to know if it's missing.
--
-- This also deliberately does NOT follow the main frame's combat-only
-- visibility. The whole point of a pre-buff reminder is to catch it BEFORE
-- combat starts, so it's its own small, independently draggable frame.
--
-- Outside combat, buff data is readable normally. In combat, most aura data
-- goes secret, but some buffs (raid buffs among them) are explicitly kept
-- readable. Either way, every check goes through pcall: a failed check means
-- "can't tell right now", not "missing" — so this never flashes a false
-- warning, it just quietly skips until it can check again.

local MOTW_SPELL_ID = 1126 -- Mark of the Wild

local motwFrame = CreateFrame("Frame", "BoomkinBuffWatcherMotwFrame", UIParent)
motwFrame:SetSize(45, 45)
motwFrame:SetPoint(BoomkinBuffWatcherDB.motwPoint, UIParent, BoomkinBuffWatcherDB.motwPoint, BoomkinBuffWatcherDB.motwX, BoomkinBuffWatcherDB.motwY)
motwFrame:SetMovable(true)
motwFrame:EnableMouse(true)
motwFrame:RegisterForDrag("LeftButton")
motwFrame:SetScript("OnDragStart", motwFrame.StartMoving)
motwFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    BoomkinBuffWatcherDB.motwPoint = point
    BoomkinBuffWatcherDB.motwX = x
    BoomkinBuffWatcherDB.motwY = y
end)

local motwIcon = motwFrame:CreateTexture(nil, "OVERLAY")
motwIcon:SetAllPoints(motwFrame)
motwIcon:SetTexture("Interface\\Icons\\Spell_Nature_Regeneration")
motwIcon:SetDesaturated(true)
motwIcon:SetVertexColor(1, 0.2, 0.2)
motwIcon:Hide()

local function CheckMarkOfTheWild()
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, MOTW_SPELL_ID)
    if not ok then
        return -- couldn't tell this time, leave the icon as it was
    end

    if aura then
        motwIcon:Hide()
    else
        motwIcon:Show()
    end
end

local function RefreshMotwFrameVisibility()
    if IsDruid() then
        motwFrame:Show()
        CheckMarkOfTheWild()
    else
        motwFrame:Hide()
    end
end

-- ============================================================
-- Reactive proc row (bottom): shows an icon ONLY while a watched buff is up
-- ============================================================
-- Edit this list yourself once you've confirmed exact spell IDs with
-- /bbw learn (see below) — talent picks change which procs you actually have,
-- so this intentionally ships empty rather than guessing wrong.
--
-- Format: { spellID, "icon path (optional, falls back to the buff's own icon)" }
local WATCHED_PROCS = {
    -- { 202770, nil }, -- example: Fury of Elune ready, once you know your real IDs
}

local procIcons = {}
for i, entry in ipairs(WATCHED_PROCS) do
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", (i - 1) * 26, -4)
    icon:Hide()
    procIcons[i] = icon
end

local function CheckWatchedProcs()
    for i, entry in ipairs(WATCHED_PROCS) do
        local spellID = entry[1]
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if not ok then
            -- can't tell right now, leave it as it was
        elseif aura then
            local iconPath = entry[2] or aura.icon
            if iconPath then
                procIcons[i]:SetTexture(iconPath)
            end
            procIcons[i]:Show()
        else
            procIcons[i]:Hide()
        end
    end
end

-- Learn mode: prints the spell ID of every buff you gain, so you can copy real
-- values into WATCHED_PROCS above instead of guessing. Only reliable out of
-- combat, same as the rest of this file's aura reads.
local learnModeActive = false
local learnFrame = CreateFrame("Frame")
learnFrame:RegisterEvent("UNIT_AURA")
learnFrame:SetScript("OnEvent", function(self, event, unit)
    if not learnModeActive or unit ~= "player" then
        return
    end
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
        if not ok or not aura then
            break
        end
        print("|cff9370DBBoomkinBuffWatcher|r Buff: " .. tostring(aura.name) .. " (spellID " .. tostring(aura.spellId) .. ")")
    end
end)

-- ============================================================
-- Astral Power (plain resource read, not restricted)
-- ============================================================

local function UpdateAstralPower()
    local current = UnitPower("player", Enum.PowerType.LunarPower)
    local max = UnitPowerMax("player", Enum.PowerType.LunarPower)

    if max <= 0 then
        return
    end

    powerBar:SetMinMaxValues(0, max)
    powerBar:SetValue(current)
    powerText:SetText(current .. " / " .. max)

    -- max is not secret for the player, so this arithmetic is safe; current is
    -- still handed straight to SetValue() without ever being inspected.
    local warnFloor = max * AP_WARNING_PERCENT / 100
    apGlowBar:SetMinMaxValues(warnFloor, max)
    apGlowBar:SetValue(current)
end

-- ============================================================
-- Eclipse window (event-driven, not read from the buff)
-- ============================================================

local windowType = nil     -- "SOLAR" | "LUNAR" | "CELESTIAL"
local windowStart = 0        -- GetTime() value the window began
local windowExpiry = 0      -- GetTime() value the window ends

local function StartWindow(kind, duration)
    -- Celestial Alignment / Incarnation override whatever's running and
    -- always win the display, since they cover both eclipses at once.
    if windowType == "CELESTIAL" and kind ~= "CELESTIAL" and GetTime() < windowExpiry then
        return
    end
    windowType = kind
    windowStart = GetTime()
    windowExpiry = windowStart + duration

    eclipseCooldownBG:Show()
    eclipseCooldown:Show()
    eclipseCooldown:SetCooldown(windowStart, duration)
end

local function RefreshEclipseText()
    if windowType and GetTime() < windowExpiry then
        local remaining = math.max(0, math.floor(windowExpiry - GetTime()))
        local label = (windowType == "SOLAR" and "Solar")
            or (windowType == "LUNAR" and "Lunar")
            or "Celestial"
        eclipseText:SetText(label .. " (" .. remaining .. "s)")

        if windowType == "SOLAR" then
            eclipseText:SetTextColor(1, 0.8, 0.2)
        elseif windowType == "LUNAR" then
            eclipseText:SetTextColor(0.5, 0.6, 1)
        else
            eclipseText:SetTextColor(0.9, 0.5, 1)
        end
    else
        windowType = nil
        eclipseText:SetText("")
        eclipseCooldownBG:Hide()
        eclipseCooldown:Hide()
    end
end

local function OnCastSucceeded(spellName)
    if spellName == SOLAR_TRIGGER then
        StartWindow("SOLAR", ECLIPSE_DURATION)
    elseif spellName == LUNAR_TRIGGER then
        StartWindow("LUNAR", ECLIPSE_DURATION)
    elseif CELESTIAL_TRIGGERS[spellName] then
        StartWindow("CELESTIAL", CELESTIAL_TRIGGERS[spellName])
    end
    RefreshEclipseText()
end

-- ============================================================
-- Visibility: main HUD shows while playing Balance, and either in combat
-- or the "hide outside of combat" setting is turned off
-- ============================================================

local function RefreshVisibility()
    local shouldShow = IsBalanceSpec() and (InCombatLockdown() or not BoomkinBuffWatcherDB.hideOutOfCombat)
    if shouldShow then
        frame:Show()
        UpdateAstralPower()
        RefreshEclipseText()
    else
        frame:Hide()
    end
end
RefreshOnHideCombatChanged = RefreshVisibility

-- Re-check overall visibility every second, independent of the frame's own
-- shown/hidden state (a frame's OnUpdate script does not fire while that frame
-- is hidden, so this uses a timer instead — otherwise this could never recover
-- from being stuck hidden). This self-corrects if a transition event was ever
-- missed, e.g. the addon loading mid-combat, so PLAYER_REGEN_DISABLED never
-- fires that session.
C_Timer.NewTicker(1, function()
    RefreshVisibility()
    RefreshMotwFrameVisibility()
end)

-- Tick the eclipse countdown text once a second, pulse the glow bar's alpha every
-- frame, and re-check watched procs a few times a second. This one is safe to
-- leave on the main frame's own OnUpdate, since it's only meant to run while
-- that frame is actually visible anyway (Mark of the Wild has its own
-- independent frame and ticker above, precisely because it needs to keep
-- working even while this frame is hidden).
local tickElapsed = 0
local procElapsed = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    local pulse = 0.5 + 0.5 * math.abs(math.sin(GetTime() * 3))
    apGlowBar:SetAlpha(pulse)

    procElapsed = procElapsed + elapsed
    if procElapsed >= 0.5 then
        procElapsed = 0
        CheckWatchedProcs()
    end

    if not windowType then
        return
    end
    tickElapsed = tickElapsed + elapsed
    if tickElapsed >= 1 then
        tickElapsed = 0
        RefreshEclipseText()
    end
end)

-- ============================================================
-- Event handling
-- ============================================================

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- leaving combat

print("|cff9370DBBoomkinBuffWatcher|r v" .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?") .. " loaded")

frame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        RefreshVisibility()
        RefreshMotwFrameVisibility()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
        RefreshVisibility()
        RefreshMotwFrameVisibility()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        RefreshVisibility()
    elseif event == "UNIT_POWER_UPDATE" and unit == "player" then
        UpdateAstralPower()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        local castGUID, spellID = ...
        local spellName = spellID and C_Spell.GetSpellName(spellID)
        if spellName then
            OnCastSucceeded(spellName)
        end
    end
end)

-- ============================================================
-- Slash commands
-- ============================================================

SLASH_BOOMKINBUFFWATCHER1 = "/bbw"
SlashCmdList["BOOMKINBUFFWATCHER"] = function(msg)
    msg = msg:lower():trim()

    if msg == "debug" then
        local current = UnitPower("player", Enum.PowerType.LunarPower)
        local max = UnitPowerMax("player", Enum.PowerType.LunarPower)
        print("|cff9370DBBoomkinBuffWatcher|r AP: " .. current .. "/" .. max)
        if windowType and GetTime() < windowExpiry then
            local remaining = math.max(0, math.floor(windowExpiry - GetTime()))
            print("|cff9370DBBoomkinBuffWatcher|r Window: " .. windowType .. " (" .. remaining .. "s left)")
        else
            print("|cff9370DBBoomkinBuffWatcher|r Window: none")
        end
        print("|cff9370DBBoomkinBuffWatcher|r Spec check: " .. tostring(IsBalanceSpec()) .. " | In combat: " .. tostring(InCombatLockdown()) .. " | Hide outside combat: " .. tostring(BoomkinBuffWatcherDB.hideOutOfCombat) .. " | Frame shown: " .. tostring(frame:IsShown()))
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, MOTW_SPELL_ID)
        if ok then
            print("|cff9370DBBoomkinBuffWatcher|r Mark of the Wild: " .. (aura and "present" or "MISSING"))
        else
            print("|cff9370DBBoomkinBuffWatcher|r Mark of the Wild: couldn't check right now")
        end
    elseif msg == "learn" then
        learnModeActive = not learnModeActive
        if learnModeActive then
            print("|cff9370DBBoomkinBuffWatcher|r Learn mode ON - gain a buff and I'll print its spell ID. Best done out of combat. Run '/bbw learn' again to turn off.")
        else
            print("|cff9370DBBoomkinBuffWatcher|r Learn mode OFF.")
        end
    elseif msg == "reset" then
        BoomkinBuffWatcherDB.point = "CENTER"
        BoomkinBuffWatcherDB.x = 0
        BoomkinBuffWatcherDB.y = -150
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
        BoomkinBuffWatcherDB.motwPoint = "CENTER"
        BoomkinBuffWatcherDB.motwX = 110
        BoomkinBuffWatcherDB.motwY = -100
        motwFrame:ClearAllPoints()
        motwFrame:SetPoint("CENTER", UIParent, "CENTER", 110, -100)
        print("|cff9370DBBoomkinBuffWatcher|r Position reset.")
    elseif msg == "config" then
        if Settings and Settings.OpenToCategory and settingsCategory then
            Settings.OpenToCategory(settingsCategory:GetID())
        else
            print("|cff9370DBBoomkinBuffWatcher|r couldn't open settings automatically - check Options > AddOns > Boomkin Buff Watcher manually.")
        end
    else
        print("|cff9370DBBoomkinBuffWatcher|r Commands: /bbw debug, /bbw learn, /bbw reset, /bbw config")
    end
end
