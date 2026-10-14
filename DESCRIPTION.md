# PotionBot behavior

PotionBot scans carried bags and maintains HealthPotionBot and ManaPotionBot.
The player activates these macros by clicking an action bar or using a keybind.

HealthPotionBot uses food outside combat and a healthstone or healing potion in
combat. ManaPotionBot uses water outside combat and a mana gem or mana potion in
combat. Neither substitutes the other resource when an item is missing, and
potions are never used outside combat. A combined food/drink can serve both macros.

Macro combat/nocombat conditions select the appropriate item and tooltip
without rewriting the macro at combat start. Bag changes during combat are
handled after combat ends. Missing item data and tooltips are handled asynchronously,
and macro writes are verified by reading the resulting body back.

Healthstones and mana gems have priority over ordinary potions. Instant
restoration amounts determine potion quality. Food and water are compared by
restoration per second; conjured status and item ID break ties.

The /pb panel offers an option to prefer Well Fed food when the buff is missing.
Its Up/Down list orders Stamina, Strength, Agility, Intellect, Spirit, Spell power,
Attack power and Healing. Buff foods are compared by stat amounts in that order,
then regeneration. If the desired stat is unavailable, another available buff food
is a fallback. With Well Fed present, plain food is preferred, with buff food as
a fallback if no plain food exists. An unreadable aura is treated as unknown.
No aura inspection or macro editing happens in combat.

English public tooltip benefit text supplies food stats. Unknown formulations
fall back to regeneration; the parser does not claim to recognize every possible
spell/healing description. Saved preferences survive /reload.

The original empty-macro defect compared GetItemInfo return 7 (subtype such as
Potion) to Consumable, which is return 6. The new selector uses numeric class IDs.
Tests preserve the original source to reproduce this defect and verify the new
selector, settings callbacks, macro conditions, combat deferral and saved priorities.

Forever Interface 16001 is the intended client target. Original Classic Era,
Cataclysm and Retail TOC entries remain but have not been regression-tested
in those clients. Local Lua 5.1 tests do not establish live in-game compatibility.
See README.md for installation, test commands and diagnostics.
