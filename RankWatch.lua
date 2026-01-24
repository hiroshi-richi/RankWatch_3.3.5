-- RankWatch: Highlights action bar buttons with lower rank spells
local addonName, RankWatch = ...

-- Data structures
RankWatch.HighestRanks = {}     -- { ["fireball"] = 12, ["heal"] = 4 }
RankWatch.ActionBarSpells = {}  -- { [slot] = { name, rank, spellID } }
RankWatch.Overlays = {}         -- { ["ActionButton1"] = TextureObject }
RankWatch.IgnoredSpells = {}    -- { ["fireball"] = true } for intentional downranking

-- Saved variables (loaded on ADDON_LOADED)
RankWatchDB = RankWatchDB or {}

-- Slot to button frame mapping
local SlotToButton = {}

-- Create a hidden tooltip for scanning
local scanTooltip = CreateFrame("GameTooltip", "RankWatchScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Build the slot-to-button mapping table
local function BuildSlotMapping()
    -- Main Action Bar (slots 1-12)
    for i = 1, 12 do
        SlotToButton[i] = "ActionButton" .. i
    end

    -- Slots 13-24 are page 2 of main bar (same buttons, different page)
    -- We handle this through the bonus bar system

    -- MultiBarRight (slots 25-36)
    for i = 1, 12 do
        SlotToButton[24 + i] = "MultiBarRightButton" .. i
    end

    -- MultiBarLeft (slots 37-48)
    for i = 1, 12 do
        SlotToButton[36 + i] = "MultiBarLeftButton" .. i
    end

    -- MultiBarBottomRight (slots 49-60)
    for i = 1, 12 do
        SlotToButton[48 + i] = "MultiBarBottomRightButton" .. i
    end

    -- MultiBarBottomLeft (slots 61-72)
    for i = 1, 12 do
        SlotToButton[60 + i] = "MultiBarBottomLeftButton" .. i
    end

    -- BonusActionBar / Stance bar (slots 73-84)
    for i = 1, 12 do
        SlotToButton[72 + i] = "BonusActionButton" .. i
    end

    -- Additional pages (85-120) map back to ActionButton1-12
    for page = 2, 5 do
        local baseSlot = 12 * page
        for i = 1, 12 do
            -- These share ActionButton frames but different action slots
            -- We'll handle via GetActionInfo on the actual slot
        end
    end
end

-- Parse rank number from rank text like "Rank 3" or "Rank 12"
local function ParseRankNumber(rankText)
    if not rankText then return nil end
    local rank = rankText:match("Rank (%d+)")
    return rank and tonumber(rank) or nil
end

-- Scan the spellbook and build HighestRanks table
function RankWatch:ScanSpellbook()
    wipe(self.HighestRanks)

    local i = 1
    while true do
        local spellName, spellRank = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not spellName then break end

        local rankNum = ParseRankNumber(spellRank)
        if rankNum then
            local nameLower = spellName:lower()
            if not self.HighestRanks[nameLower] or rankNum > self.HighestRanks[nameLower] then
                self.HighestRanks[nameLower] = rankNum
            end
        end

        i = i + 1
    end
end

-- Get spell info from an action slot using tooltip scanning
local function GetActionSpellInfo(slot)
    if not HasAction(slot) then
        return nil, nil, nil
    end

    local actionType, id, subType = GetActionInfo(slot)

    -- Only process spell actions (skip macros, items, etc.)
    if actionType ~= "spell" then
        return nil, nil, nil
    end

    -- Use tooltip scanning to get accurate spell name and rank
    scanTooltip:ClearLines()
    scanTooltip:SetAction(slot)

    local spellName = _G["RankWatchScanTooltipTextLeft1"] and _G["RankWatchScanTooltipTextLeft1"]:GetText()
    local spellRank = _G["RankWatchScanTooltipTextRight1"] and _G["RankWatchScanTooltipTextRight1"]:GetText()

    if not spellName then
        return nil, nil, nil
    end

    return spellName, spellRank, id
end

-- Scan a single action slot
function RankWatch:ScanActionSlot(slot)
    local spellName, spellRank, spellID = GetActionSpellInfo(slot)

    if spellName and spellRank then
        self.ActionBarSpells[slot] = {
            name = spellName,
            rank = spellRank,
            spellID = spellID
        }
    else
        self.ActionBarSpells[slot] = nil
    end

    return spellName, spellRank, spellID
end

-- Scan all action bar slots (1-120)
function RankWatch:ScanAllActionBars()
    for slot = 1, 120 do
        self:ScanActionSlot(slot)
    end
end

-- Get or create overlay texture for a button
function RankWatch:GetOrCreateOverlay(buttonName)
    if self.Overlays[buttonName] then
        return self.Overlays[buttonName]
    end

    local button = _G[buttonName]
    if not button then
        return nil
    end

    -- Create a frame to hold the overlay (ensures proper layering)
    local overlayFrame = CreateFrame("Frame", buttonName .. "RankWatchFrame", button)
    overlayFrame:SetFrameStrata("HIGH")
    overlayFrame:SetFrameLevel(button:GetFrameLevel() + 10)

    -- Make the overlay slightly larger than the button for a border effect
    overlayFrame:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    overlayFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)

    -- Create edge textures for a visible border using WHITE8X8 texture
    local edgeTexture = "Interface\\BUTTONS\\WHITE8X8"

    -- Top edge
    local top = overlayFrame:CreateTexture(nil, "OVERLAY")
    top:SetTexture(edgeTexture)
    top:SetVertexColor(1.0, 0.3, 0.0, 1.0)  -- Orange-red
    top:SetHeight(3)
    top:SetPoint("TOPLEFT", overlayFrame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", overlayFrame, "TOPRIGHT", 0, 0)

    -- Bottom edge
    local bottom = overlayFrame:CreateTexture(nil, "OVERLAY")
    bottom:SetTexture(edgeTexture)
    bottom:SetVertexColor(1.0, 0.3, 0.0, 1.0)
    bottom:SetHeight(3)
    bottom:SetPoint("BOTTOMLEFT", overlayFrame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", overlayFrame, "BOTTOMRIGHT", 0, 0)

    -- Left edge
    local left = overlayFrame:CreateTexture(nil, "OVERLAY")
    left:SetTexture(edgeTexture)
    left:SetVertexColor(1.0, 0.3, 0.0, 1.0)
    left:SetWidth(3)
    left:SetPoint("TOPLEFT", overlayFrame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", overlayFrame, "BOTTOMLEFT", 0, 0)

    -- Right edge
    local right = overlayFrame:CreateTexture(nil, "OVERLAY")
    right:SetTexture(edgeTexture)
    right:SetVertexColor(1.0, 0.3, 0.0, 1.0)
    right:SetWidth(3)
    right:SetPoint("TOPRIGHT", overlayFrame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", overlayFrame, "BOTTOMRIGHT", 0, 0)

    overlayFrame:Hide()
    self.Overlays[buttonName] = overlayFrame

    return overlayFrame
end

-- Check if a spell should be highlighted (is lower than max rank)
function RankWatch:IsLowerRank(spellName, spellRank)
    if not spellName or not spellRank then
        return false
    end

    local nameLower = spellName:lower()

    -- Check if spell is ignored (intentional downranking)
    if self.IgnoredSpells[nameLower] then
        return false
    end

    local currentRank = ParseRankNumber(spellRank)
    local highestRank = self.HighestRanks[nameLower]

    if not currentRank or not highestRank then
        return false
    end

    return currentRank < highestRank
end

-- Update overlay for a single slot
function RankWatch:UpdateSlotOverlay(slot)
    local buttonName = SlotToButton[slot]
    if not buttonName then
        -- Handle main bar paging (slots 13-24 map to ActionButton1-12)
        if slot >= 13 and slot <= 24 then
            buttonName = "ActionButton" .. (slot - 12)
        else
            return
        end
    end

    local spellData = self.ActionBarSpells[slot]
    local overlay = self:GetOrCreateOverlay(buttonName)

    if not overlay then
        return
    end

    if spellData and self:IsLowerRank(spellData.name, spellData.rank) then
        overlay:Show()
    else
        overlay:Hide()
    end
end

-- Update all overlays
function RankWatch:UpdateAllOverlays()
    -- First hide all existing overlays
    for buttonName, overlay in pairs(self.Overlays) do
        overlay:Hide()
    end

    -- Then update each slot
    for slot = 1, 120 do
        self:UpdateSlotOverlay(slot)
    end
end

-- Full refresh: scan spellbook, scan bars, update overlays
function RankWatch:FullRefresh()
    self:ScanSpellbook()
    self:ScanAllActionBars()
    self:UpdateAllOverlays()
end

-- Get list of outdated spells on action bars
function RankWatch:GetOutdatedSpells()
    local outdated = {}

    for slot, spellData in pairs(self.ActionBarSpells) do
        if self:IsLowerRank(spellData.name, spellData.rank) then
            local currentRank = ParseRankNumber(spellData.rank)
            local highestRank = self.HighestRanks[spellData.name:lower()]

            -- Avoid duplicates
            local key = spellData.name:lower()
            if not outdated[key] then
                outdated[key] = {
                    name = spellData.name,
                    currentRank = currentRank,
                    highestRank = highestRank
                }
            end
        end
    end

    return outdated
end

-- Print outdated spells to chat
function RankWatch:PrintOutdatedSpells()
    local outdated = self:GetOutdatedSpells()
    local count = 0

    for _, data in pairs(outdated) do
        print(string.format("|cffff6600RankWatch:|r %s is Rank %d (max is Rank %d)",
            data.name, data.currentRank, data.highestRank))
        count = count + 1
    end

    if count == 0 then
        print("|cff00ff00RankWatch:|r All action bar spells are at maximum rank!")
    else
        print(string.format("|cffff6600RankWatch:|r Found %d outdated spell(s) on your action bars.", count))
    end
end

-- Ignore a spell (for intentional downranking)
function RankWatch:IgnoreSpell(spellName)
    if not spellName or spellName == "" then
        print("|cffff6600RankWatch:|r Usage: /rw ignore <spell name>")
        return
    end

    local nameLower = spellName:lower()
    self.IgnoredSpells[nameLower] = true
    RankWatchDB.IgnoredSpells = RankWatchDB.IgnoredSpells or {}
    RankWatchDB.IgnoredSpells[nameLower] = true

    print(string.format("|cff00ff00RankWatch:|r Now ignoring '%s' (intentional downranking).", spellName))
    self:UpdateAllOverlays()
end

-- Unignore a spell
function RankWatch:UnignoreSpell(spellName)
    if not spellName or spellName == "" then
        print("|cffff6600RankWatch:|r Usage: /rw unignore <spell name>")
        return
    end

    local nameLower = spellName:lower()
    self.IgnoredSpells[nameLower] = nil
    if RankWatchDB.IgnoredSpells then
        RankWatchDB.IgnoredSpells[nameLower] = nil
    end

    print(string.format("|cff00ff00RankWatch:|r No longer ignoring '%s'.", spellName))
    self:UpdateAllOverlays()
end

-- List ignored spells
function RankWatch:ListIgnoredSpells()
    local count = 0
    print("|cffff6600RankWatch:|r Ignored spells (intentional downranking):")

    for spellName, _ in pairs(self.IgnoredSpells) do
        print("  - " .. spellName)
        count = count + 1
    end

    if count == 0 then
        print("  (none)")
    end
end

-- Slash command handler
local function SlashHandler(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()

    if cmd == "" then
        -- Default: rescan all
        RankWatch:FullRefresh()
        print("|cff00ff00RankWatch:|r Rescanned spellbook and action bars.")
    elseif cmd == "list" then
        RankWatch:PrintOutdatedSpells()
    elseif cmd == "ignore" then
        RankWatch:IgnoreSpell(arg)
    elseif cmd == "unignore" then
        RankWatch:UnignoreSpell(arg)
    elseif cmd == "ignored" then
        RankWatch:ListIgnoredSpells()
    elseif cmd == "show" then
        -- Manually show overlay on a slot for testing
        local slot = tonumber(arg)
        if not slot then
            print("|cffff6600RankWatch:|r Usage: /rw show <slot number>")
            return
        end
        local buttonName = SlotToButton[slot]
        if not buttonName then
            print("|cffff6600RankWatch:|r No button mapped for slot " .. slot)
            return
        end
        local overlay = RankWatch:GetOrCreateOverlay(buttonName)
        if overlay then
            overlay:Show()
            print(string.format("|cff00ff00RankWatch:|r Showing overlay on %s (slot %d)", buttonName, slot))
        else
            print("|cffff6600RankWatch:|r Failed to create overlay for " .. buttonName)
        end

    elseif cmd == "check" then
        -- Check a specific slot in detail
        local slot = tonumber(arg)
        if not slot then
            print("|cffff6600RankWatch:|r Usage: /rw check <slot number>")
            return
        end

        print(string.format("|cffff6600RankWatch:|r Checking slot %d:", slot))

        local spellData = RankWatch.ActionBarSpells[slot]
        if not spellData then
            print("  No spell data stored for this slot")
            return
        end

        print(string.format("  Stored: name='%s', rank='%s'", spellData.name or "nil", spellData.rank or "nil"))

        local nameLower = spellData.name:lower()
        local highestRank = RankWatch.HighestRanks[nameLower]
        print(string.format("  Lookup key: '%s'", nameLower))
        print(string.format("  Highest rank in spellbook: %s", tostring(highestRank)))

        local currentRank = ParseRankNumber(spellData.rank)
        print(string.format("  Parsed current rank: %s", tostring(currentRank)))

        local isLower = RankWatch:IsLowerRank(spellData.name, spellData.rank)
        print(string.format("  IsLowerRank result: %s", tostring(isLower)))

        local buttonName = SlotToButton[slot]
        print(string.format("  Button name: %s", tostring(buttonName)))

        if buttonName then
            local button = _G[buttonName]
            print(string.format("  Button exists: %s", tostring(button ~= nil)))

            local overlay = RankWatch.Overlays[buttonName]
            print(string.format("  Overlay exists: %s", tostring(overlay ~= nil)))

            if overlay then
                print(string.format("  Overlay shown: %s", tostring(overlay:IsShown())))
                print(string.format("  Overlay visible: %s", tostring(overlay:IsVisible())))
                print(string.format("  Overlay alpha: %s", tostring(overlay:GetAlpha())))
            end
        end

    elseif cmd == "debug" then
        -- Debug: show what's detected on action bars
        print("|cffff6600RankWatch Debug:|r Spellbook highest ranks:")
        local spellCount = 0
        for name, rank in pairs(RankWatch.HighestRanks) do
            print(string.format("  %s: Rank %d", name, rank))
            spellCount = spellCount + 1
            if spellCount >= 10 then
                print("  ... (truncated)")
                break
            end
        end

        print("|cffff6600RankWatch Debug:|r Action bar spells:")
        local barCount = 0
        for slot, data in pairs(RankWatch.ActionBarSpells) do
            print(string.format("  Slot %d: %s (%s)", slot, data.name or "nil", data.rank or "no rank"))
            barCount = barCount + 1
        end
        if barCount == 0 then
            print("  (no spells detected on action bars)")
        end

        -- Also scan first 12 slots directly for debugging
        print("|cffff6600RankWatch Debug:|r Direct slot scan (1-12):")
        for slot = 1, 12 do
            if HasAction(slot) then
                local actionType, id, subType = GetActionInfo(slot)
                scanTooltip:ClearLines()
                scanTooltip:SetAction(slot)
                local ttName = _G["RankWatchScanTooltipTextLeft1"] and _G["RankWatchScanTooltipTextLeft1"]:GetText() or "nil"
                local ttRank = _G["RankWatchScanTooltipTextRight1"] and _G["RankWatchScanTooltipTextRight1"]:GetText() or "nil"
                print(string.format("  Slot %d: type=%s, id=%s, tooltip=[%s] [%s]",
                    slot, tostring(actionType), tostring(id), ttName, ttRank))
            end
        end
    elseif cmd == "help" then
        print("|cffff6600RankWatch|r Commands:")
        print("  /rw - Rescan spellbook and action bars")
        print("  /rw list - Show outdated spells on action bars")
        print("  /rw ignore <spell> - Ignore spell (intentional downranking)")
        print("  /rw unignore <spell> - Stop ignoring spell")
        print("  /rw ignored - List ignored spells")
        print("  /rw debug - Show debug info")
        print("  /rw help - Show this help")
    else
        print("|cffff6600RankWatch:|r Unknown command. Use /rw help for commands.")
    end
end

-- Register slash commands
SLASH_RANKWATCH1 = "/rw"
SLASH_RANKWATCH2 = "/rankwatch"
SlashCmdList["RANKWATCH"] = SlashHandler

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Load saved ignored spells
        if RankWatchDB.IgnoredSpells then
            for spellName, _ in pairs(RankWatchDB.IgnoredSpells) do
                RankWatch.IgnoredSpells[spellName] = true
            end
        end
        BuildSlotMapping()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Initial scan on login/reload
        C_Timer.After(1, function()
            RankWatch:FullRefresh()
        end)

    elseif event == "SPELLS_CHANGED" then
        -- Rescan when learning new spells
        RankWatch:FullRefresh()

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        -- Update single slot when changed
        local slot = arg1
        if slot then
            RankWatch:ScanActionSlot(slot)
            RankWatch:UpdateSlotOverlay(slot)
        end

    elseif event == "UPDATE_BONUS_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" then
        -- Refresh overlays when stance/form changes or bar page changes
        RankWatch:UpdateAllOverlays()
    end
end)

-- Print load message
print("|cff00ff00RankWatch|r loaded. Use /rw help for commands.")
