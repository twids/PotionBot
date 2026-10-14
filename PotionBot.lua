-- PotionBot: select bag consumables out of combat; the player activates the macros.
local addonName = ... or "PotionBot"
local VERSION = "5.5.0-forever-beta"
local PotionBot = CreateFrame("Frame")
local pending, queued = false, false
local healthPotionCurrent, manaPotionCurrent = 0, 0
local foodCurrent, waterCurrent = 0, 0
local PotionBotDB
local report, waitingItems = {}, {}
local tooltipRetries = 0
local statOptions = {
    {key="stamina", label="Stamina", terms={"stamina"}},
    {key="strength", label="Strength", terms={"strength"}},
    {key="agility", label="Agility", terms={"agility"}},
    {key="intellect", label="Intellect", terms={"intellect"}},
    {key="spirit", label="Spirit", terms={"spirit"}},
    {key="spellpower", label="Spell power", terms={"spell power", "spell damage"}},
    {key="attackpower", label="Attack power", terms={"attack power"}},
    {key="healing", label="Healing", terms={"healing"}},
}
local statByKey = {}
for _, option in ipairs(statOptions) do statByKey[option.key] = option end

local function Message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0PotionBot|r: " .. text)
end

local function NewReport()
    local version, build, _, interface = GetBuildInfo()
    report = {version=VERSION, client=version, build=build, interface=interface,
        locale=GetLocale(), items={}, macros={}, scanned=0, missingTooltips=0}
    PotionBotDiagnostics = report
end

-- Classic conjured items have names such as Mana Ruby, rather than "mana gem".
local healthstones = {
    [5512]=true, [5511]=true, [5509]=true, [5510]=true, [9421]=true,
    [19004]=true, [19005]=true, [19006]=true, [19007]=true,
    [19008]=true, [19009]=true, [19010]=true, [19011]=true,
    [19012]=true, [19013]=true,
}
local manaGems = { [5514]=true, [5513]=true, [8007]=true, [8008]=true }

local function InitializePotionBotDB()
    if type(PotionBotVariables) ~= "table" then PotionBotVariables = {} end
    if PotionBotVariables.healthPotionChecked == nil then PotionBotVariables.healthPotionChecked = true end
    if PotionBotVariables.manaPotionChecked == nil then PotionBotVariables.manaPotionChecked = true end
    if PotionBotVariables.preferWellFedChecked == nil then PotionBotVariables.preferWellFedChecked = true end
    local order, seen = {}, {}
    if type(PotionBotVariables.foodStatPriority) == "table" then
        for _, key in ipairs(PotionBotVariables.foodStatPriority) do
            if statByKey[key] and not seen[key] then order[#order+1] = key; seen[key] = true end
        end
    end
    for _, option in ipairs(statOptions) do
        if not seen[option.key] then order[#order+1] = option.key end
    end
    PotionBotVariables.foodStatPriority = order
    PotionBotDB = PotionBotVariables
end

local function IsPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

local function WellFedState()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return "unknown" end
    local unknown = false
    for index = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        if not ok or not IsPublic(aura) then return "unknown" end
        if not aura then return unknown and "unknown" or "missing" end
        if IsPublic(aura.name) and type(aura.name) == "string" then
            if aura.name:lower() == "well fed" then return "present" end
        else
            unknown = true
        end
    end
    return "unknown"
end

local function TooltipLines(bag, slot)
    local data = C_TooltipInfo.GetBagItem(bag, slot)
    local lines = {}
    if data and data.lines then
        for _, line in ipairs(data.lines) do
            if IsPublic(line.leftText) and type(line.leftText) == "string" then
                lines[#lines + 1] = line.leftText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            end
        end
    end
    return lines
end

local function Amount(text, resource, meal)
    text = text:lower():gsub("\194\160", " ")
    -- Meals are compared by restoration per second; combat items by instant amount.
    if not (text:find("restor") or text:find("heals? ")) then return nil end
    local seconds = text:match("over ([%d%.]+) sec")
    if text:find("every %d") then return nil end
    if meal then
        seconds = tonumber(seconds)
        if not seconds or seconds <= 0 then return nil end
    else
        if seconds then return nil end
        seconds = 1
    end
    local percent = text:match("([%d%.]+)%% of [^%.]-" .. resource)
        or text:match("([%d%.]+)%% " .. resource)
    if percent then
        local maximum
        if resource == "health" then maximum = UnitHealthMax("player") else maximum = UnitPowerMax("player", 0) end
        if IsPublic(maximum) and type(maximum) == "number" and maximum > 0 then
            return maximum * tonumber(percent) / 100 / seconds
        end
        return nil
    end
    -- Match each resource independently, including dual-resource potions.
    local low, high = text:match("([%d,%.]+) to ([%d,%.]+) " .. resource)
    if low then return (tonumber((low:gsub(",", ""))) + tonumber((high:gsub(",", "")))) / 2 / seconds end
    local fixed = text:match("([%d,%.]+) " .. resource)
    if fixed then return tonumber((fixed:gsub(",", ""))) / seconds end
end

local function Better(candidate, current)
    if not current then return true end
    if candidate.special ~= current.special then return candidate.special end
    if candidate.amount ~= current.amount then return candidate.amount > current.amount end
    if candidate.conjured ~= current.conjured then return candidate.conjured end
    return candidate.id < current.id
end

local function FoodStats(text)
    local stats = {}
    -- Read the benefit after Well Fed, not the food name or health/mana restoration.
    local benefit = text:match("well[%s%-]+fed(.*)")
    if not benefit then return stats end
    for _, option in ipairs(statOptions) do
        for _, term in ipairs(option.terms) do
            local value = benefit:match("([%d,%.]+)%s+" .. term .. "%f[%A]")
                or benefit:match(term .. " by ([%d,%.]+)")
            if value then
                stats[option.key] = math.max(stats[option.key] or 0, tonumber((value:gsub(",", ""))) or 0)
            end
        end
    end
    -- Classic food commonly shares a value: "gain 8 Stamina and Spirit".
    local amount, first, second = benefit:match("([%d,%.]+)%s+(%a+)%s+and%s+(%a+)")
    if amount and statByKey[first] and statByKey[second] then
        local value = tonumber((amount:gsub(",", "")))
        if value then stats[first] = stats[first] or value; stats[second] = stats[second] or value end
    end
    local spellBonus = benefit:match("damage done by magical spells and effects by up to ([%d,]+)")
        or benefit:match("damage and healing done by magical spells and effects by up to ([%d,]+)")
    if spellBonus then stats.spellpower = tonumber((spellBonus:gsub(",", ""))) end
    local healingBonus = benefit:match("healing done by spells and effects by up to ([%d,]+)")
    if healingBonus then stats.healing = tonumber((healingBonus:gsub(",", ""))) end
    return stats
end

local function BetterBuffFood(candidate, current)
    if not current then return true end
    for _, key in ipairs(PotionBotDB.foodStatPriority) do
        local a, b = candidate.stats[key] or 0, current.stats[key] or 0
        if a ~= b then return a > b end
    end
    return Better(candidate, current)
end

local function ScanBags()
    NewReport()
    local bestHealth, bestMana, bestFood, bestWater, bestBuffFood, bestPlainFood
    local wellFed = WellFedState()
    report.wellFed, report.preferWellFed = wellFed, PotionBotDB.preferWellFedChecked
    report.foodStatPriority = PotionBotDB.foodStatPriority
    local level = UnitLevel("player")
    local bagSlots = NUM_BAG_SLOTS or (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots) or 4
    for bag = 0, bagSlots do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id then
                report.scanned = report.scanned + 1
                local name, _, _, _, minLevel, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(id)
                local entry = {id=id, bag=bag, slot=slot, name=name, minLevel=minLevel,
                    classID=classID, subclassID=subclassID}
                if not name then
                    entry.reason = "waiting for item data"
                    if not waitingItems[id] then
                        waitingItems[id] = true
                        C_Item.RequestLoadItemDataByID(id)
                    end
                elseif minLevel and minLevel > level then
                    entry.reason = "requires higher level"
                else
                    local lines = TooltipLines(bag, slot)
                    local text = table.concat(lines, "\n"):lower()
                    local itemName = name:lower()
                    local stone = healthstones[id] or itemName:find("healthstone", 1, true) ~= nil
                    local gem = manaGems[id] or itemName:find("mana gem", 1, true) ~= nil
                    -- Class/subclass IDs are independent of the client's language.
                    local potion = classID == 0 and subclassID == 1
                    local meal = classID == 0 and subclassID == 5
                    entry.reason = "not a restoration consumable"
                    if potion or stone or gem or meal then
                        entry.lines = lines
                        local health, mana
                        for _, line in ipairs(lines) do
                            health = Amount(line, "health", meal) or health
                            mana = Amount(line, "mana", meal) or mana
                        end
                        local conjured = text:find("conjured", 1, true) ~= nil
                        entry.health, entry.mana = health, mana
                        entry.reason = (health or mana) and "candidate" or "no readable restoration effect"
                        entry.kind = meal and "food/drink" or "combat item"
                        if #lines == 0 then
                            entry.reason = "waiting for tooltip"
                            report.missingTooltips = report.missingTooltips + 1
                        end
                        if meal then
                            if health then
                                local item = {id=id, amount=health, special=false, conjured=conjured}
                                entry.wellFedFood = text:find("well[%s%-]+fed") ~= nil
                                if entry.wellFedFood then
                                    item.stats = FoodStats(text)
                                    entry.foodStats = item.stats
                                    if BetterBuffFood(item, bestBuffFood) then bestBuffFood = item end
                                else
                                    if Better(item, bestPlainFood) then bestPlainFood = item end
                                end
                                if Better(item, bestFood) then bestFood = item end
                            end
                            if mana then
                                local item = {id=id, amount=mana, special=false, conjured=conjured}
                                if Better(item, bestWater) then bestWater = item end
                            end
                        elseif health and not gem then
                            local item = {id=id, amount=health, special=stone, conjured=conjured}
                            if Better(item, bestHealth) then bestHealth = item end
                        end
                        if not meal and mana and not stone then
                            local item = {id=id, amount=mana, special=gem, conjured=conjured}
                            if Better(item, bestMana) then bestMana = item end
                        end
                    end
                end
                if (#report.items < 80) and (not name or classID == 0 or healthstones[id] or manaGems[id]) then
                    report.items[#report.items + 1] = entry
                end
            end
        end
    end
    healthPotionCurrent = bestHealth and bestHealth.id or 0
    manaPotionCurrent = bestMana and bestMana.id or 0
    if PotionBotDB.preferWellFedChecked then
        if wellFed == "missing" then
            bestFood = bestBuffFood or bestPlainFood
        else
            -- An unreadable aura is not evidence that Well Fed is absent.
            bestFood = bestPlainFood or bestBuffFood
        end
    end
    foodCurrent = bestFood and bestFood.id or 0
    waterCurrent = bestWater and bestWater.id or 0
    report.health, report.mana = healthPotionCurrent, manaPotionCurrent
    report.food, report.water = foodCurrent, waterCurrent
    report.healthEnabled, report.manaEnabled = PotionBotDB.healthPotionChecked, PotionBotDB.manaPotionChecked
end

local function UpdateMacro(name, combatID, restID)
    local index = GetMacroIndexByName(name)
    -- Secure conditions choose the action and tooltip without editing during combat.
    local choices = {}
    if combatID > 0 then choices[#choices + 1] = "[combat] item:" .. combatID end
    if restID > 0 then choices[#choices + 1] = "[nocombat] item:" .. restID end
    local body = "#showtooltip"
    if #choices > 0 then body = body .. "\n/use " .. table.concat(choices, "; ") end
    if index == 0 then
        local count, characterCount = GetNumMacros()
        local limits = Constants and Constants.MacroConsts or {}
        local accountMax = limits.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120
        local characterMax = limits.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS or 18
        local perCharacter = count >= accountMax
        if perCharacter and (characterCount or 0) >= characterMax then
            report.macros[name] = {error="No free account or character macro slots"}
            Message("No free macro slots for " .. name .. ".")
            return
        end
        CreateMacro(name, "INV_MISC_QUESTIONMARK", body, perCharacter)
    else
        local _, _, existing = GetMacroInfo(index)
        if existing ~= body then EditMacro(index, name, "INV_MISC_QUESTIONMARK", body) end
    end
    local actualIndex = GetMacroIndexByName(name)
    local _, _, actualBody = GetMacroInfo(actualIndex)
    report.macros[name] = {body=actualBody, expected=body, verified=actualIndex ~= 0 and actualBody == body}
    if not report.macros[name].verified then
        report.macros[name].error = "Macro write did not take effect"
        Message("Could not update " .. name .. ". Run /pb diagnose.")
    end
end

local function RunPotionBot()
    if InCombatLockdown() then pending = true; return end
    pending = false
    InitializePotionBotDB()
    ScanBags()
    if PotionBotDB.healthPotionChecked then UpdateMacro("HealthPotionBot", healthPotionCurrent, foodCurrent) end
    if PotionBotDB.manaPotionChecked then UpdateMacro("ManaPotionBot", manaPotionCurrent, waterCurrent) end
end

local QueueUpdate
local function SafeRun()
    local ok, err = pcall(RunPotionBot)
    if not ok then
        report.lastError = tostring(err)
        PotionBotDiagnostics = report
        Message("Update failed: " .. report.lastError)
    elseif not pending and (report.missingTooltips or 0) > 0 and tooltipRetries < 3 then
        tooltipRetries = tooltipRetries + 1
        QueueUpdate()
    end
end

QueueUpdate = function()
    pending = true
    if queued or InCombatLockdown() then return end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        SafeRun() -- Recheck combat here: it may have started during the delay.
    end)
end

local function OnCheckboxChanged(key, checked)
    PotionBotDB[key] = checked
    PotionBotVariables[key] = checked
    SafeRun()
end

local panel = CreateFrame("Frame")
panel.name = addonName
panel:Hide()
local optionCheckboxes, priorityRows = {}, {}
local panelBuilt = false

local function createCheckbox(label, key)
    local checkBox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkBox:SetChecked(PotionBotDB[key])
    checkBox:HookScript("OnClick", function(self)
        local checked = self:GetChecked()
        OnCheckboxChanged(key, checked)
    end)
    local text = checkBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", checkBox, "RIGHT", 2, 0)
    text:SetText(label)
    optionCheckboxes[key] = checkBox
    return checkBox
end

local function RefreshOptions()
    for key, checkbox in pairs(optionCheckboxes) do checkbox:SetChecked(PotionBotDB[key]) end
    for index, row in ipairs(priorityRows) do
        local option = statByKey[PotionBotDB.foodStatPriority[index]]
        row.label:SetText(index .. ". " .. option.label)
        row.up:SetEnabled(index > 1)
        row.down:SetEnabled(index < #priorityRows)
    end
end

local function MovePriority(index, offset)
    local other = index + offset
    local order = PotionBotDB.foodStatPriority
    if other < 1 or other > #order then return end
    order[index], order[other] = order[other], order[index]
    SafeRun()
    RefreshOptions()
end

panel:SetScript("OnShow", function()
    if panelBuilt then RefreshOptions(); return end
    panelBuilt = true
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(addonName)
    title:SetTextColor(0.41, 0.8, 0.94)

    local keysAndLabels = {
        {key = "manaPotionChecked", label = "Mana: water out of combat, potion/gem in combat"},
        {key = "healthPotionChecked", label = "Health: food out of combat, potion/stone in combat"},
        {key = "preferWellFedChecked", label = "Prefer Well Fed food when the buff is missing"},
    }

    for index, data in ipairs(keysAndLabels) do
        local checkBox = createCheckbox(data.label, data.key)
        checkBox:SetPoint("TOPLEFT", 16, -44 - (index - 1) * 28)
    end

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 16, -150)
    heading:SetText("Food buff priority (highest first)")
    local explanation = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    explanation:SetPoint("TOPLEFT", 16, -170)
    explanation:SetText("Used when Well Fed is missing. Stronger stats win; then regeneration.")
    for index = 1, #statOptions do
        local position = index
        local row = {}
        row.label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("TOPLEFT", 24, -202 - (index - 1) * 28)
        row.up = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.up:SetSize(48, 22)
        row.up:SetPoint("TOPLEFT", 205, -198 - (index - 1) * 28)
        row.up:SetText("Up")
        row.up:SetScript("OnClick", function() MovePriority(position, -1) end)
        row.down = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.down:SetSize(48, 22)
        row.down:SetPoint("LEFT", row.up, "RIGHT", 6, 0)
        row.down:SetText("Down")
        row.down:SetScript("OnClick", function() MovePriority(position, 1) end)
        priorityRows[index] = row
    end
    RefreshOptions()
end)

local categoryId = nil
if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterAddOnCategory and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    categoryId = category:GetID()
    Settings.RegisterAddOnCategory(category)
end

SLASH_PotionBot1 = "/pb"
SLASH_PotionBot2 = "/pp"
SLASH_PotionBot3 = "/potionbot"

local function ShowStatus()
    Message(VERSION .. ": health item " .. healthPotionCurrent .. ", mana item " .. manaPotionCurrent)
    Message("Out of combat: food item " .. foodCurrent .. ", water item " .. waterCurrent)
    Message("Well Fed: " .. (report.wellFed or "unknown") ..
        "; prefer buff food: " .. (PotionBotDB.preferWellFedChecked and "on" or "off"))
    local labels = {}
    for _, key in ipairs(PotionBotDB.foodStatPriority) do labels[#labels+1] = statByKey[key].label end
    Message("Food buff priority: " .. table.concat(labels, " > "))
    Message("Health macro " .. (PotionBotDB.healthPotionChecked and "enabled" or "disabled") ..
        "; mana macro " .. (PotionBotDB.manaPotionChecked and "enabled" or "disabled"))
    if pending then Message("Update pending until combat ends.") end
    if report.lastError then Message("Last error: " .. report.lastError) end
end

function SlashCmdList.PotionBot(input)
    local command = (input or ""):lower():match("^%s*(%S+)")
    if command == "status" then ShowStatus(); return end
    if command == "enable" then
        PotionBotDB.healthPotionChecked, PotionBotDB.manaPotionChecked = true, true
        QueueUpdate(); Message("Both macros enabled."); return
    end
    if command == "scan" or command == "diagnose" then
        tooltipRetries = 0
        SafeRun()
        ShowStatus()
        if command == "diagnose" then
            for _, entry in ipairs(report.items or {}) do
                Message("Item " .. entry.id .. " " .. (entry.name or "uncached") .. ": " .. entry.reason)
            end
            Message("Diagnostic saved. /reload writes it to PotionBot.lua in SavedVariables.")
        end
        return
    end
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    elseif categoryId then
        Settings.OpenToCategory(categoryId)
    end
end


PotionBot:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName then
            InitializePotionBotDB()
            QueueUpdate()
            Message(VERSION .. " loaded. /pb status shows the selected items.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then QueueUpdate() end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local id, success = ...
        if waitingItems[id] then
            waitingItems[id] = nil
            if success then QueueUpdate() end
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then QueueUpdate() end
    else
        tooltipRetries = 0
        QueueUpdate()
    end
end)
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED",
    "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED", "UNIT_AURA",
}) do PotionBot:RegisterEvent(event) end
InitializePotionBotDB()
