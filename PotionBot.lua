--[[
PotionBot - World of Warcraft Addon
Based on DrinkBot by the original author
Modified to work with health and mana potions instead of food and drinks
Includes special prioritization for healthstones and mana gems
--]]

local PotionBot = CreateFrame("FRAME", "PotionBot", UIParent)
PotionBot:RegisterEvent("BAG_UPDATE_DELAYED")
PotionBot:RegisterEvent("PLAYER_ENTERING_WORLD")
PotionBot:RegisterEvent("PLAYER_LEVEL_UP")
PotionBot:RegisterEvent("UNIT_AURA")
PotionBot:SetScript("OnEvent", function(self, event, ...) self:OnEvent(event, ...) end)

-- Debug message to confirm addon is loading
-- print("|cff69ccf0PotionBot|r addon loaded successfully!")

local healthPotionCurrent, manaPotionCurrent = 0, 0
local healthPotionID, manaPotionID = {}, {}
local tooltipScan = CreateFrame("GameTooltip", "TooltipScan", nil, "GameTooltipTemplate")
tooltipScan:SetOwner(UIParent, "ANCHOR_NONE")
local tooltipScanBuff = CreateFrame("GameTooltip", "TooltipScanBuff", UIParent, "GameTooltipTemplate")
tooltipScanBuff:SetOwner(UIParent, "ANCHOR_NONE")

local _, _, _, tocversion = GetBuildInfo()
local majorVersion = math.floor(tocversion / 10000)

local gameVersion = majorVersion or 11

local triggerWords = {"potion", "elixir", "flask", "healthstone", "mana gem"}

local function ScanBags()
    local healthPotions, manaPotions = {}, {}
    local priorityHealthPotion, priorityManaPotion = nil, nil
    local _, _, raceID = UnitRace("player")
    
    if raceID ~= 84 and raceID ~= 85 then
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    tooltipScan:SetOwner(UIParent, "ANCHOR_NONE")
                    tooltipScan:SetHyperlink(itemLink)
                    tooltipScan:Show()

                    local healthAmount, manaAmount, healthSeconds, manaSeconds = nil, nil, nil, nil
                    local isWellFed, isPriority, isPotion, isConjured, isHealthstone, isManaGem = false, false, false, false, false, false

                    for i = 1, 10 do
                        local lineText = _G["TooltipScanTextLeft" .. i]:GetText()
                        if not lineText then break end

                        if string.match(lineText, "Restores 100%% health and 100%% Mana over (%d+) sec") then
                            isPriority = true
                            healthAmount, manaAmount = 100, 100
                            healthSeconds, manaSeconds = tonumber(string.match(lineText, "(%d+) sec")), tonumber(string.match(lineText, "(%d+) sec"))
                        end

                        if string.match(lineText, "Conjured Item") then
                            isConjured = true
                        end

                        -- Check for healthstones (warlock created items)
                        if string.match(lineText:lower(), "healthstone") then
                            isHealthstone = true
                            isPotion = true -- Treat healthstones as potions
                            isPriority = true -- Healthstones should be prioritized
                        end

                        -- Check for mana gems (mage created items)
                        if string.match(lineText:lower(), "mana gem") then
                            isManaGem = true
                            isPotion = true -- Treat mana gems as potions
                            isPriority = true -- Mana gems should be prioritized
                        end

                        local healthPatterns = {
                            {pattern = "([%d,%.]+) million health over (%d+) sec", multiplier = 1000000},
                            {pattern = "([%d,]+) health over (%d+) sec", multiplier = 1},
                            {pattern = "(%d+) health over (%d+) sec", multiplier = 1},
                            {pattern = "([%d,%.]+) million health and ([%d,%.]+) million mana over (%d+) sec", multiplier = 1000000},
                            {pattern = "([%d,]+) health and ([%d,]+) mana over (%d+) sec", multiplier = 1},
                            {pattern = "(%d+) health and (%d+) mana over (%d+) sec", multiplier = 1},
                            {pattern = "Restores (%d+) health", multiplier = 1}, -- Instant health potions
                            {pattern = "Restores ([%d,]+) health", multiplier = 1}, -- Instant health potions with commas
                            {pattern = "Restores (%d+) to (%d+) health", multiplier = 1}, -- Classic range healing (e.g., "Restores 70 to 90 health")
                        }

                        local manaPatterns = {
                            {pattern = "([%d,%.]+) million mana over (%d+) sec", multiplier = 1000000},
                            {pattern = "([%d,]+) mana over (%d+) sec", multiplier = 1},
                            {pattern = "(%d+) mana over (%d+) sec", multiplier = 1},
                            {pattern = "([%d,%.]+) million health and ([%d,%.]+) million mana over (%d+) sec", multiplier = 1000000},
                            {pattern = "([%d,]+) health and ([%d,]+) mana over (%d+) sec", multiplier = 1},
                            {pattern = "(%d+) health and (%d+) mana over (%d+) sec", multiplier = 1},
                            {pattern = "Restores (%d+) mana", multiplier = 1}, -- Instant mana potions
                            {pattern = "Restores ([%d,]+) mana", multiplier = 1}, -- Instant mana potions with commas
                            {pattern = "Restores (%d+) to (%d+) mana", multiplier = 1}, -- Classic range mana (e.g., "Restores 140 to 180 mana")
                        }

                        for _, match in ipairs(healthPatterns) do
                            if match.pattern == "Restores (%d+) to (%d+) health" then
                                -- Handle range pattern specially
                                local minHealth, maxHealth = string.match(lineText, match.pattern)
                                if minHealth and maxHealth then
                                    -- Use average of min and max for comparison
                                    healthAmount = (tonumber(minHealth) + tonumber(maxHealth)) / 2 * match.multiplier
                                    healthSeconds = 1 -- Instant effect
                                end
                            else
                                local healthMatch, secondsMatch = string.match(lineText, match.pattern)
                                if healthMatch and secondsMatch then
                                    local sanitizedHealthMatch = healthMatch:gsub(",", "")
                                    healthAmount = tonumber(sanitizedHealthMatch) * match.multiplier
                                    healthSeconds = tonumber(secondsMatch)
                                elseif healthMatch and not secondsMatch then
                                    -- Instant potion
                                    local sanitizedHealthMatch = healthMatch:gsub(",", "")
                                    healthAmount = tonumber(sanitizedHealthMatch) * match.multiplier
                                    healthSeconds = 1 -- Instant effect
                                end
                            end
                        end

                        for _, match in ipairs(manaPatterns) do
                            if match.pattern == "Restores (%d+) to (%d+) mana" then
                                -- Handle range pattern specially
                                local minMana, maxMana = string.match(lineText, match.pattern)
                                if minMana and maxMana then
                                    -- Use average of min and max for comparison
                                    manaAmount = (tonumber(minMana) + tonumber(maxMana)) / 2 * match.multiplier
                                    manaSeconds = 1 -- Instant effect
                                end
                            else
                                local manaMatch, secondsMatch = string.match(lineText, match.pattern)
                                if manaMatch and secondsMatch then
                                    local sanitizedManaMatch = manaMatch:gsub(",", "")
                                    manaAmount = tonumber(sanitizedManaMatch) * match.multiplier
                                    manaSeconds = tonumber(secondsMatch)
                                elseif manaMatch and not secondsMatch then
                                    -- Instant potion
                                    local sanitizedManaMatch = manaMatch:gsub(",", "")
                                    manaAmount = tonumber(sanitizedManaMatch) * match.multiplier
                                    manaSeconds = 1 -- Instant effect
                                end
                            end
                        end

                        if string.match(lineText:lower(), "well fed") then
                            isWellFed = true
                        end

                        if string.match(lineText:lower(), "potion") or 
                           string.match(lineText:lower(), "elixir") or 
                           string.match(lineText:lower(), "flask") or
                           string.match(lineText:lower(), "gem") then
                            isPotion = true
                        end
                    end

                    -- Process items that are potions, elixirs, flasks, or healthstones
                    if healthAmount and healthSeconds and (isPotion or isHealthstone) and not isWellFed then
                        local itemID = select(1, C_Item.GetItemInfoInstant(itemLink))
                        if itemID then
                            local itemType = select(7, C_Item.GetItemInfo(itemID))
                            if itemType == "Consumable" then
                                local healthPotion = {
                                    id = itemID, 
                                    rate = healthAmount / healthSeconds, 
                                    isPriority = isPriority or isHealthstone, -- Healthstones are always priority
                                    isConjured = isConjured, 
                                    isHealthstone = isHealthstone,
                                    quantity = C_Item.GetItemCount(itemID)
                                }
                                if isPriority or isHealthstone then
                                    priorityHealthPotion = healthPotion
                                else
                                    table.insert(healthPotions, healthPotion)
                                end
                            end
                        end
                    end

                    -- Process items that are potions, elixirs, flasks, mana gems, but not healthstones
                    if manaAmount and manaSeconds and (isPotion or isManaGem) and not isWellFed and not isHealthstone then
                        local itemID = select(1, C_Item.GetItemInfoInstant(itemLink))
                        if itemID then
                            local itemType = select(7, C_Item.GetItemInfo(itemID))
                            if itemType == "Consumable" then
                                local manaPotion = {
                                    id = itemID, 
                                    rate = manaAmount / manaSeconds, 
                                    isPriority = isPriority or isManaGem, -- Mana gems are always priority
                                    isConjured = isConjured, 
                                    isManaGem = isManaGem,
                                    quantity = C_Item.GetItemCount(itemID)
                                }
                                if isPriority or isManaGem then
                                    priorityManaPotion = manaPotion
                                else
                                    table.insert(manaPotions, manaPotion)
                                end
                            end
                        end
                    end

                    tooltipScan:Hide()
                    tooltipScan:ClearLines()
                end
            end
        end
    else
		-- Earthen race uses special items - skip for potion functionality
		-- local earthenRocks = { 113509, 228494, 228493 }
		-- We don't include earthen-specific items for potion functionality
	end

    local function sortItems(a, b)
        -- Healthstones always come first for health items
        if a.isHealthstone ~= b.isHealthstone then
            return a.isHealthstone
        end
        -- Mana gems always come first for mana items
        if a.isManaGem ~= b.isManaGem then
            return a.isManaGem
        end
        if a.isPriority ~= b.isPriority then
            return a.isPriority
        end
        if a.rate ~= b.rate then
            return a.rate > b.rate
        end
        if a.isConjured ~= b.isConjured then
            return a.isConjured
        end
        return a.id < b.id
    end

    table.sort(healthPotions, sortItems)
    table.sort(manaPotions, sortItems)

    healthPotionID = {}
    manaPotionID = {}

    if priorityHealthPotion then table.insert(healthPotionID, priorityHealthPotion) end
    for _, healthPotion in ipairs(healthPotions) do table.insert(healthPotionID, healthPotion) end

    if priorityManaPotion then table.insert(manaPotionID, priorityManaPotion) end
    for _, manaPotion in ipairs(manaPotions) do table.insert(manaPotionID, manaPotion) end
end



local function CreateOrUpdateMacro()

    if not PotionBotDB then
        PotionBotDB = PotionBotVariables
    end

    local healthPotionChecked = PotionBotDB.healthPotionChecked
    local manaPotionChecked = PotionBotDB.manaPotionChecked

    if healthPotionChecked then
        local healthPotionIdx = GetMacroIndexByName("HealthPotionBot")
        local healthline1 = "#showtooltip item:" .. healthPotionCurrent .. "\n"
        local healthline2 = "/use [btn:1] item:" .. healthPotionCurrent

        if PotionBotDrinking == true then
            healthline2 = ""
        end

        if healthPotionIdx == 0 then
            if GetNumMacros() >= 120 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0PotionBot|r: |cffff0000WARNING|r: Unable to create |cff69ccf0HealthPotionBot|r macro. All of your Macro slots are already in use. Please delete a macro and /reload.")
                return
            end
            CreateMacro("HealthPotionBot", "INV_MISC_QUESTIONMARK", healthline1 .. healthline2, nil)
        else
            EditMacro(healthPotionIdx, "HealthPotionBot", "INV_MISC_QUESTIONMARK", healthline1 .. healthline2)
        end
    end

    if manaPotionChecked then
        local manaPotionIdx = GetMacroIndexByName("ManaPotionBot")
        local manaline1 = "#showtooltip item:" .. manaPotionCurrent .. "\n"
        local manaline2 = "/use [btn:1] item:" .. manaPotionCurrent

        if manaPotionIdx == 0 then
            if GetNumMacros() >= 120 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0PotionBot|r: |cffff0000WARNING|r: Unable to create |cff69ccf0ManaPotionBot|r macro. All of your Macro slots are already in use. Please delete a macro and /reload.")
                return
            end
            CreateMacro("ManaPotionBot", "INV_MISC_QUESTIONMARK", manaline1 .. manaline2, nil)
        else
            EditMacro(manaPotionIdx, "ManaPotionBot", "INV_MISC_QUESTIONMARK", manaline1 .. manaline2)
        end
    end
end

local function PotionBotGo()
    local playerLvl = UnitLevel("player")
    ScanBags()

    local firstHealthPotionWithQty, firstManaPotionWithQty = nil, nil

    for _, healthPotion in ipairs(healthPotionID) do
        local qtyInBags = C_Item.GetItemCount(healthPotion.id) or 0
        local minLevel = select(5, C_Item.GetItemInfo(healthPotion.id)) or 0
        if qtyInBags > 0 and minLevel <= playerLvl then
            firstHealthPotionWithQty = healthPotion.id
            break
        end
    end

    for _, manaPotion in ipairs(manaPotionID) do
        local qtyInBags = C_Item.GetItemCount(manaPotion.id) or 0
        local minLevel = select(5, C_Item.GetItemInfo(manaPotion.id)) or 0
        if qtyInBags > 0 and minLevel <= playerLvl then
            firstManaPotionWithQty = manaPotion.id
            break
        end
    end

    if firstHealthPotionWithQty then
        healthPotionCurrent = firstHealthPotionWithQty
    end
    
    if firstManaPotionWithQty then
        manaPotionCurrent = firstManaPotionWithQty
    end

    CreateOrUpdateMacro()
end

local function ScanAurasForBuffs()
    local drinking = false

    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then
            break
        end
        if aura.duration and aura.duration <= 35 then
            local auraName = aura.name:lower()
            for _, word in ipairs(triggerWords) do
                if string.find(auraName, word) then
                    drinking = true
                    break
                end
            end
            if drinking then
                break
            end
        end
    end

    if PotionBotDrinking ~= drinking then
        PotionBotDrinking = drinking
        CreateOrUpdateMacro()
    end
end

local function RunPotionBot()
    if C_Item.GetItemCount(healthPotionCurrent) >= 0 or C_Item.GetItemCount(manaPotionCurrent) >= 0 then
        PotionBotGo()
    end
end

local function InitializePotionBotDB()
    if not PotionBotVariables then
		if gameVersion >= 4 then
			PotionBotVariables = { healthPotionChecked = true, manaPotionChecked = true }
		elseif gameVersion == 1 then
			PotionBotVariables = { healthPotionChecked = true, manaPotionChecked = true }
		end  
    end
    PotionBotDB = PotionBotVariables
end

local function OnCheckboxChanged(key, checked)
    PotionBotDB[key] = checked
    PotionBotVariables[key] = checked
    RunPotionBot()
end

local addonName = "PotionBot"
local panel = CreateFrame("Frame")
panel.name = addonName
panel:Hide()

local function createCheckbox(label, key)
    local checkBox = CreateFrame("CheckButton", addonName .. "Check" .. label, panel, "InterfaceOptionsCheckButtonTemplate")
    checkBox:SetChecked(PotionBotDB[key])
    checkBox:HookScript("OnClick", function(self)
        local checked = self:GetChecked()
        OnCheckboxChanged(key, checked)
    end)
    checkBox.Text:SetText(label)
    return checkBox
end

panel:SetScript("OnShow", function()
local title = panel:CreateFontString("ARTWORK", nil, "GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(addonName)
title:SetTextColor(0.41, 0.8, 0.94) -- Blue color


    local kindsTitle = panel:CreateFontString("ARTWORK", nil, "GameFontNormal")
    kindsTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    kindsTitle:SetText("")

    local keysAndLabels = {
        {key = "manaPotionChecked", label = "Enable ManaPotionBot Macro"},
		{key = "healthPotionChecked", label = "Enable HealthPotionBot Macro"},
    }

    local index = 0
    local rowHeight = 24
    local columnWidth = 150
    local rowNum = 10

    for _, data in pairs(keysAndLabels) do
        local checkBox = createCheckbox(data.label, data.key)
        local columnIndex = math.floor(index / rowNum)
        local offsetRight = columnIndex * columnWidth
        local offsetUp = -(index * rowHeight) + (rowHeight * rowNum * columnIndex) - 16
        checkBox:SetPoint("TOPLEFT", kindsTitle, "BOTTOMLEFT", offsetRight, offsetUp)
        index = index + 1
    end

    panel:SetScript("OnShow", nil)
end)

local categoryId = nil
if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterAddOnCategory and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    categoryId = category.ID
    Settings.RegisterAddOnCategory(category)
end

SLASH_PotionBot1 = "/hb"
SLASH_PotionBot2 = "/PotionBot"

function SlashCmdList.PotionBot()
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    elseif categoryId then
        Settings.OpenToCategory(categoryId)
    end
end

function PotionBot:OnEvent(event, ...)
    if not InCombatLockdown() then
        if event == "UNIT_AURA" then
            local unit = ...
            if unit == "player" then
                ScanAurasForBuffs()
            end
        elseif event == "BAG_UPDATE_DELAYED" then
            RunPotionBot()
            InitializePotionBotDB()
		elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" then
		    C_Timer.After(0.5, function()
				if C_Item.GetItemCount(healthPotionCurrent) >= 0 or C_Item.GetItemCount(manaPotionCurrent) >= 0 then
					PotionBotGo()
				end
			end)
		end
    end
end

InitializePotionBotDB()

-- Initial scan on addon load
C_Timer.After(1, function()
    PotionBotGo()
end)
