from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '.tools'))
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
setup = r'''
timers, frames, macros, bags, items = {}, {}, {}, {}, {}
combat = false
auras = {}
C_UnitAuras = {GetAuraDataByIndex=function(_, index) return auras[index] end}
UIParent, SlashCmdList = {}, {}
NUM_BAG_SLOTS = 4
function CreateFrame(kind, name, parent, template)
    assert(legacyTest or kind ~= 'GameTooltip', 'Must use tooltip data API')
    assert(template ~= 'InterfaceOptionsCheckButtonTemplate', 'Removed options template')
    local frame = {}
    function frame:RegisterEvent(event) end
    function frame:SetScript(event, callback) self[event] = callback end
    function frame:Hide() end
    function frame:Show() if self.OnShow then self.OnShow(self) end end
    function frame:SetOwner() end
    function frame:ClearLines() end
    function frame:SetPoint() end
    function frame:SetText(text) self.text = text end
    function frame:SetTextColor() end
    function frame:SetSize() end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:SetChecked(value) self.checked = value end
    function frame:GetChecked() return self.checked end
    function frame:HookScript(event, callback) self[event] = callback end
    function frame:CreateFontString(name, layer)
        assert(name == nil and layer == 'ARTWORK', 'FontString must be anonymous with valid layer')
        return CreateFrame('FontString')
    end
    function frame:SetHyperlink(link)
        local id = tonumber(link:match('item:(%d+)'))
        for i=1,10 do
            local text = items[id].lines[i]
            _G['TooltipScanTextLeft' .. i] = {GetText=function() return text end}
        end
    end
    frames[#frames+1] = frame
    return frame
end
C_Timer = {After = function(_, callback) timers[#timers+1] = callback end}
function flush()
    local callbacks = timers; timers = {}
    for _, callback in ipairs(callbacks) do callback() end
end
function fire(event, ...) frames[1].OnEvent(frames[1], event, ...) end
function InCombatLockdown() return combat end
function UnitLevel() return 60 end
function UnitRace() return 'Human', 'Human', 1 end
function UnitHealthMax() return 1000 end
function UnitPowerMax() return 800 end
function GetBuildInfo() return '1.60.1', '70374', 'Oct 2026', 16001 end
function GetLocale() return 'enUS' end
function issecretvalue(value) return value == secret end
secret = {}
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bags or 0 end,
    GetContainerItemID = function(_, slot) return bags[slot] end,
    GetContainerItemLink = function(_, slot) return 'item:' .. bags[slot] end,
}
C_Item = {
    GetItemInfo = function(id)
        local item = items[id]
        if not item or item.uncached then return nil end
        return item.name or 'item', 'item:'..id, 1, 1, item.level or 1,
            item.itemType or 'Consumable', item.itemSubType or 'Potion', 20, '', 134830, 0, item.classID or 0, item.subclass or 1
    end,
    RequestLoadItemDataByID = function(id) requested = id end,
    GetItemInfoInstant = function(link) return tonumber(tostring(link):match('item:(%d+)')) or link end,
    GetItemCount = function(id) for _, bagID in ipairs(bags) do if bagID == id then return 1 end end; return 0 end,
}
C_TooltipInfo = {GetBagItem = function(_, slot)
    local lines = {}
    for _, text in ipairs(items[bags[slot]].lines) do lines[#lines+1] = {leftText=text} end
    if items[bags[slot]].noTooltip then return nil end
    return {lines=lines}
end}
function GetMacroIndexByName(name) return macros[name] and name or 0 end
function GetNumMacros() return macroCount or 0, characterMacroCount or 0 end
function GetMacroInfo(name) return name, nil, macros[name] end
function CreateMacro(name, _, body, perCharacter)
    assert(not combat, 'Macro creation in combat')
    if not rejectMacroWrite then macros[name] = body end
    usedCharacterSlot = perCharacter
end
function EditMacro(name, _, _, body)
    assert(not combat, 'Macro update in combat')
    macros[name] = body
end
DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) warned = true; lastMessage = message end}
Constants = {MacroConsts={MAX_ACCOUNT_MACROS=120, MAX_CHARACTER_MACROS=30}}
Settings = {
    RegisterCanvasLayoutCategory=function() return {GetID=function() return 123 end} end,
    RegisterAddOnCategory=function() end,
    OpenToCategory=function(id) opened = id end,
}
'''
lua.execute(setup)
# Reuse the exact same API setup for the new and original addon.
legacy = LuaRuntime(unpack_returned_tuples=True)
legacy.execute(setup)
legacy.execute('legacyTest = true')
# Source from twids/PotionBot commit 54f4f23977a56fb4829621af3593848e370fe4e9; trailing whitespace normalized.
original = root.joinpath('tests/fixtures/PotionBot-5.1.0.lua').read_text(encoding='utf-8')
legacy.execute(original, 'PotionBot')
legacy.execute(r'''
items[118] = {lines={'Minor Healing Potion', 'Use: Restores 70 to 90 health.'}}
items[2455] = {lines={'Minor Mana Potion', 'Use: Restores 140 to 180 mana.'}}
bags = {118,2455}; flush()
assert(select(6, C_Item.GetItemInfo(118)) == 'Consumable')
assert(select(7, C_Item.GetItemInfo(118)) == 'Potion')
assert(macros.HealthPotionBot:find('item:0', 1, true), 'Reproduce original empty health macro')
assert(macros.ManaPotionBot:find('item:0', 1, true), 'Reproduce original empty mana macro')
''')
print('PASS: Original addon reproduces empty health and mana macros with real GetItemInfo field order')
lua.execute(root.joinpath('PotionBot.lua').read_text(encoding='utf-8'), 'PotionBot')
lua.execute(r'''
items[118] = {lines={'Minor Healing Potion', 'Use: Restores 70 to 90 health.'}}
items[858] = {lines={'Lesser Healing Potion', 'Use: Restores 140 to 180 health.'}}
items[2455] = {lines={'Minor Mana Potion', 'Use: Restores 140 to 180 mana.'}}
items[5512] = {subclass=0, lines={'Healthstone', 'Use: Restores 100 health.'}}
items[5514] = {subclass=0, lines={'Mana Agate', 'Conjured Item', 'Use: Restores 100 to 120 mana.'}}
bags = {118,858,2455}
fire('ADDON_LOADED', 'PotionBot'); flush()
assert(macros.HealthPotionBot:find('item:858', 1, true))
assert(macros.ManaPotionBot:find('item:2455', 1, true))
assert(macros.HealthPotionBot:find('/use [combat] item:858', 1, true), 'Combat item restricted to combat, with no mouse-only condition')
bags = {118,5512,5514,2455}
fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot:find('item:5512', 1, true))
assert(macros.ManaPotionBot:find('item:5514', 1, true), 'Mana Agate priority')
combat = true; bags = {858}
fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot:find('item:5512', 1, true))
combat = false; fire('PLAYER_REGEN_ENABLED'); flush()
assert(macros.HealthPotionBot:find('item:858', 1, true))
assert(macros.ManaPotionBot == '#showtooltip', 'Clear exhausted items')
fire('BAG_UPDATE_DELAYED'); combat = true; bags = {}; flush()
assert(macros.HealthPotionBot:find('item:858', 1, true), 'Timer must recheck combat')
combat = false; fire('PLAYER_REGEN_ENABLED'); flush()
assert(macros.HealthPotionBot == '#showtooltip')
items[858].uncached = true; bags = {858}
fire('BAG_UPDATE_DELAYED'); flush(); assert(requested == 858)
items[858].uncached = false; fire('GET_ITEM_INFO_RECEIVED',858,true); flush()
assert(macros.HealthPotionBot:find('item:858', 1, true))
items[858].level = 61
fire('PLAYER_LEVEL_UP'); flush(); assert(macros.HealthPotionBot == '#showtooltip')
items[858].level = 1; items[858].lines = {secret}
fire('BAG_UPDATE_DELAYED'); flush(); assert(macros.HealthPotionBot == '#showtooltip')
items[858].lines = {'Use: Restores 1,400 to 1,800 health.'}
items[118].lines = {'Use: Restores 900 health.'}
bags = {858,118}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot:find('item:858', 1, true), 'Comma-delimited range')
items[858].lines = {'Use: Restores 5000 health over 20 sec.'}
fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot:find('item:118', 1, true), 'Exclude periodic healing')
SlashCmdList.PotionBot(); assert(opened == 123)
frames[2]:Show() -- Exercise settings construction, not just category registration.
PotionBotVariables.healthPotionChecked = false
bags = {}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot:find('item:118', 1, true), 'Respect disabled macro')
macros = {}; macroCount = 120; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.ManaPotionBot and usedCharacterSlot, 'Use free character macro slots')
macros = {}; characterMacroCount = 30; fire('BAG_UPDATE_DELAYED'); flush()
assert(warned and macros.ManaPotionBot == nil)
macroCount,characterMacroCount = 0,0
SlashCmdList.PotionBot('enable'); flush()
items[858].lines = {'Use: Restores 150 health and 200 mana.'}
bags = {858}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot:find('item:858', 1, true) and macros.ManaPotionBot:find('item:858', 1, true))
items[5512].lines = {'Use: Instantly restores 20% of your total health.'}
bags = {5512,118}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot:find('item:5512', 1, true))
items[858].noTooltip = true; bags = {858}; fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.missingTooltips == 1)
items[858].noTooltip = false; flush()
assert(macros.HealthPotionBot:find('item:858', 1, true), 'Retry asynchronously missing tooltip')
items[858].noTooltip = true; fire('BAG_UPDATE_DELAYED'); flush(); flush(); flush(); flush(); flush()
assert(#timers == 0, 'Missing tooltip retries are bounded')
items[858].noTooltip = false; fire('BAG_UPDATE_DELAYED'); flush()
SlashCmdList.PotionBot('diagnose')
assert(PotionBotDiagnostics.macros.HealthPotionBot.verified)
assert(PotionBotDiagnostics.build == '70374' and #PotionBotDiagnostics.items == 1)
assert(PotionBotDiagnostics.items[1].reason == 'candidate')
assert(PotionBotDiagnostics.items[1].lines[1] == 'Use: Restores 150 health and 200 mana.')
macros = {}; rejectMacroWrite = true; fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.macros.HealthPotionBot.error == 'Macro write did not take effect')
rejectMacroWrite = false
local savedAPI = C_TooltipInfo; C_TooltipInfo = nil
fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.lastError, 'Record a real scan API failure')
C_TooltipInfo = savedAPI
items[117] = {subclass=5, lines={'Tough Jerky', 'Use: Restores 61.2 health over 18 sec.'}}
items[159] = {subclass=5, lines={'Refreshing Spring Water', 'Use: Restores 151 mana over 18 sec.'}}
items[858].lines = {'Use: Restores 140 to 180 health.'}
bags = {117,159,858,2455}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot == '#showtooltip\n/use [combat] item:858; [nocombat] item:117')
assert(macros.ManaPotionBot == '#showtooltip\n/use [combat] item:2455; [nocombat] item:159')
assert(PotionBotDiagnostics.food == 117 and PotionBotDiagnostics.water == 159)
local preparedMacro = macros.HealthPotionBot
combat = true; fire('PLAYER_REGEN_DISABLED'); flush()
assert(macros.HealthPotionBot == preparedMacro, 'Combat condition must work without rewriting macro')
combat = false; fire('PLAYER_REGEN_ENABLED'); flush()
items[90001] = {subclass=5, lines={'Combined Meal', 'Use: Restores 180 health and 360 mana over 18 sec.'}}
bags = {90001,117,159,858}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot == '#showtooltip\n/use [combat] item:858; [nocombat] item:90001')
assert(PotionBotDiagnostics.food == 90001 and PotionBotDiagnostics.water == 90001, 'Rank each meal resource by rate; avoid duplicate use')
bags = {117}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot == '#showtooltip\n/use [nocombat] item:117', 'Food-only fallback')
bags = {159}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot == '#showtooltip', 'Health macro must not substitute water for missing food')
assert(macros.ManaPotionBot == '#showtooltip\n/use [nocombat] item:159', 'Water stays on mana macro')
bags = {858}; fire('BAG_UPDATE_DELAYED'); flush()
assert(macros.HealthPotionBot == '#showtooltip\n/use [combat] item:858', 'Never substitute potions for missing food/water')
items[117].level = 61; bags = {117,159}; fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.food == 0 and PotionBotDiagnostics.water == 159)
items[117].level = 1; items[117].subclass = 2 -- An elixir must not be classified as food.
fire('BAG_UPDATE_DELAYED'); flush(); assert(PotionBotDiagnostics.food == 0)
items[117].subclass = 5
items[90002] = {subclass=5, lines={'Buff Food', 'Use: Restores 30 health over 18 sec. If you spend 10 seconds eating you will become well fed.'}}
bags = {117,159,858,2455,90002}; auras = {}; fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.wellFed == 'missing' and PotionBotDiagnostics.food == 90002, 'Prefer buff food despite slower regeneration when Well Fed is missing')
assert(macros.HealthPotionBot == '#showtooltip\n/use [combat] item:858; [nocombat] item:90002')
assert(macros.ManaPotionBot == '#showtooltip\n/use [combat] item:2455; [nocombat] item:159')
auras = {{name='Well Fed'}}; fire('UNIT_AURA', 'player'); flush()
assert(PotionBotDiagnostics.wellFed == 'present' and PotionBotDiagnostics.food == 117, 'Use plain food when already Well Fed')
auras = {}; fire('UNIT_AURA', 'player'); flush()
assert(PotionBotDiagnostics.food == 90002, 'Reselect buff food after expiration')
PotionBotVariables.preferWellFedChecked = false; fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.food == 117, 'Preference can be disabled')
PotionBotVariables.preferWellFedChecked = true
auras = {{name=secret}}; fire('UNIT_AURA', 'player'); flush()
assert(PotionBotDiagnostics.wellFed == 'unknown' and PotionBotDiagnostics.food == 117, 'Secret aura must not be treated as missing Well Fed')
auras = {{name='Well Fed'}}; bags = {90002}; fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.food == 90002, 'Buff food remains a fallback if no plain food exists')
combat=true; auras={}; fire('UNIT_AURA','player'); flush()
assert(PotionBotDiagnostics.wellFed == 'present', 'No aura inspection or macro edits during combat')
combat=false; fire('PLAYER_REGEN_ENABLED'); flush()
assert(PotionBotDiagnostics.wellFed == 'missing')
-- Exact public tooltip captured from the user's Forever build 70374.
items[2888] = {subclass=5, lines={'Beer Basted Boar Ribs', 'Use: Restores 58 health over 18 sec.  Must remain seated while eating. If you spend at least 10 sec eating, you will become well fed and gain 1 Strength for 15 min. Additionally, experience gained from kills is increased by 5%. (1 |4Sec:Sec; Cooldown)'}}
items[90003] = {subclass=5, lines={'Spirit Meal', 'Use: Restores 40 health over 18 sec. You will become well fed and gain 8 Spirit for 15 min.'}}
items[90004] = {subclass=5, lines={'Stamina Meal', 'Use: Restores 50 health over 18 sec. You will become well fed and gain 4 Stamina for 15 min.'}}
items[90005] = {subclass=5, lines={'Shared Meal', 'Use: Restores 45 health over 18 sec. You will become well fed and gain 4 Stamina and Spirit for 15 min.'}}
bags = {2888,90003,90004,90005}; fire('BAG_UPDATE_DELAYED'); flush()
assert(PotionBotDiagnostics.food == 90005, 'With equal primary Stamina, Spirit is a tiebreaker before regeneration')
assert(PotionBotDiagnostics.items[1].foodStats.strength == 1, 'Parse real Forever Strength tooltip without mistaking XP bonus for stats')
assert(PotionBotDiagnostics.items[4].foodStats.spirit == 4 and PotionBotDiagnostics.items[4].foodStats.stamina == 4)
local up, down = {}, {}
for _, frame in ipairs(frames) do
    if frame.text == 'Up' then up[#up+1] = frame end
    if frame.text == 'Down' then down[#down+1] = frame end
end
assert(#up == 8 and #down == 8 and not up[1].enabled and not down[8].enabled)
for position=5,2,-1 do up[position].OnClick() end -- Move Spirit to the top through the real GUI callbacks.
assert(PotionBotVariables.foodStatPriority[1] == 'spirit')
assert(PotionBotDiagnostics.food == 90003, 'GUI priority edit immediately reselects the Spirit meal')
local count = #frames; frames[2]:Show()
assert(#frames == count and PotionBotVariables.foodStatPriority[1] == 'spirit', 'Reopening settings preserves priority without duplicating controls')
auras={{name='Well Fed'}}; bags={117,2888,90003}; fire('UNIT_AURA','player'); flush()
assert(PotionBotDiagnostics.food == 117, 'Stat priority must not waste buff food when already Well Fed')
auras={}; bags={117,2888}; fire('UNIT_AURA','player'); flush()
assert(PotionBotDiagnostics.food == 2888, 'Fall back to another available buff stat when preferred stat is missing')
PotionBotVariables.foodStatPriority = {'spirit','spirit','invalid','intellect'}
fire('BAG_UPDATE_DELAYED'); flush()
assert(#PotionBotVariables.foodStatPriority == 8 and PotionBotVariables.foodStatPriority[1] == 'spirit' and PotionBotVariables.foodStatPriority[2] == 'intellect', 'Normalize saved priority while preserving valid user order')
-- A new addon load must retain the user's saved order.
fire('ADDON_LOADED','PotionBot'); flush()
assert(PotionBotVariables.foodStatPriority[1] == 'spirit')
''')
print('PASS: Real Forever food stat text, shared stat values, primary/secondary ranking, GUI Up/Down callbacks, immediate reselection, reopening settings, saved priority validation and reload persistence')
print('PASS: Health uses food, mana uses water, conditional Well Fed priority, buff gained/lost, preference disabled, secret aura and combat deferral')
print('PASS: Food and water, decimal restoration, secure combat/nocombat branches, no macro rewrites at combat start, combined meals, missing food/water, level and non-food filtering')
print('PASS: Lua 5.1 load, potion ranking, conjured priority, combat deferral, timer race, empty bags, item cache, level, secret text, ranges, periodic exclusion, actual settings construction, disabled macro, account/character macro slots, dual effects, percentages, bounded tooltip retries, persisted diagnosis, failed macro writes and API errors')
