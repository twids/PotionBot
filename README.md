# PotionBot

## WoW Forever beta port (5.5.0-forever-beta)

Targets Interface 16001. The local installation was identified as Forever
1.60.1.70374 (enUS). This port has passed mocked Lua 5.1 tests; live in-game
loading, protected actions and item tooltips still require verification.

- Uses C_TooltipInfo bag data instead of hidden tooltip frames.
- Fixes the original empty-macro bug: GetItemInfo result 7 is the item subtype
  (Potion), not the class (Consumable, result 6). Selection uses numeric class IDs.
- Updates macros outside combat and catches up after combat ends.
- Each macro includes secure combat/nocombat conditions. In combat the health
  button uses a healthstone/potion and the mana button uses a mana gem/potion.
  Out of combat the health button uses food and the mana button uses water.
  Neither substitutes the other resource if food or water is missing, and
  neither uses a potion outside combat. Combined food/drink can serve both buttons.
- The default-enabled /pb option "Prefer Well Fed food when the buff is missing"
  gives buff food priority when no Well Fed aura is present. With the buff already
  active, plain food is preferred, with buff food as a fallback if it is all you
  have. Turning the option off selects solely by restoration quality. Buff food
  is identified by English "well fed" text in its tooltip; the player aura is
  identified by its public "Well Fed" name. Unknown/restricted aura state is not
  treated as proof the buff is missing. Selection updates on player aura changes
  outside combat and after combat ends.
- /pb includes a "Food buff priority" list with Up/Down buttons. Order Stamina,
  Strength, Agility, Intellect, Spirit, Spell power, Attack power and Healing to
  your preference. The order is saved and changes immediately update selection
  outside combat. The initial order is the order listed here.
- With Well Fed missing and the buff-food option enabled, buff foods are compared
  by the amount of the first stat in your list, then the next stat, and so on.
  Restoration per second breaks ties. If your preferred stat is unavailable,
  another available buff food remains a fallback. Existing Well Fed still prefers
  plain food, and disabling buff-food preference selects by regeneration only.
  Stat parsing uses English benefit text after "well fed", including shared
  values such as "8 Stamina and Spirit". Unknown stat wording falls back to
  regeneration; not every possible spell/healing tooltip formulation is covered.
- Chooses food/drink by restoration per second, then conjured status and item ID.
- Prioritizes healthstones and Classic mana gems, including Mana Agate/Ruby.
- Handles healing/mana ranges and clears exhausted items from macros.
- Supports both action-bar clicks and keyboard activation.
- Falls back to character macro slots if account macro slots are full, and
  reads the macro back to verify each write.
- Handles dual health/mana effects and healthstones restoring a percentage.
- Retries missing tooltips a bounded number of times and waits for item data.
- Does not inspect auras or edit macros during combat.
- Restoration text parsing currently supports English clients only. Combat items
  need an instant restoration effect; food/drink need a timed restoration effect.
  Stat elixirs and flasks are excluded.
- Existing Classic Era, Cataclysm and Retail targets have not been regression
  tested in their game clients by this port.

Install the PotionBot folder under your Forever client's Interface/AddOns folder.
Enable it in the character-selection AddOns list, log in or run /reload, and open
/pb. Put HealthPotionBot and ManaPotionBot from /macro on your action bars.
If both account and character macro slots are full, free two slots first.

Commands: /pb opens settings, /pb status shows current selection, /pb scan
rescans, and /pb enable enables both macros without discarding other settings.
/pb diagnose scans and prints why consumables were selected or rejected.
After that command, /reload flushes PotionBotDiagnostics into the account's
SavedVariables/PotionBot.lua. The latest report contains build/locale, consumable
item IDs and public tooltip lines, selected items, macro bodies and update errors.
It does not collect chat, account names or credentials, and replaces the previous
report on each scan. Reports describe the last completed scan, not proof of use.

In-game check: carry food, water, different potion ranks and a healthstone/mana
gem. Outside combat HealthPotionBot should show/use food and ManaPotionBot
should show/use water. With buff food and plain food, check the health selection
before and after gaining/losing Well Fed. Reorder the desired stats in /pb and
check that available matching food is selected while Well Fed is missing.
In combat each button should show and use
the corresponding potion/stone/gem. Use a macro via keyboard, then consume or move the
last selected item during combat. The macro should update after combat ends.
Check that /pb opens Settings and that no Lua or blocked-action errors appear.

Developer verification:

```shell
python -m pip install --target .tools -r tests/requirements.txt
python tests/verify.py
```
The test runs the preserved original 5.1.0 source with realistic GetItemInfo results,
reproduces both item:0 macros, then verifies the new implementation against the
same API contract. It also constructs the settings panel and simulates failed
macro writes, missing tooltip/item data and combat transitions.

<div align="center">
  <img src="logo.png" alt="PotionBot Logo" width="200" height="200">
</div>

PotionBot creates two macros with food and water out of combat and health/mana restoration items in combat.

*Based on the original DrinkBot addon, with healthstone and mana gem support.*

## Features

- **Bag scanning**: Detects instant health/mana potions plus food and water
- **Priority System**: 
  - Healthstones are prioritized over all health potions
  - Mana Gems are prioritized over all mana potions
  - Conjured items break ties between equally effective consumables
  - Higher restoration values are preferred
- **Automatic Macro Creation**: Creates "HealthPotionBot" and "ManaPotionBot" macros
- **Client targets**: Forever beta; original Classic Era, Cataclysm and Retail TOC entries retained but not verified in-game
- **Configurable**: Enable/disable individual macros through the interface options

## Slash Commands

- `/pb`, `/pp`, or `/potionbot` - Opens the configuration panel

## How It Works

1. The addon scans your bags for consumable items
2. Identifies restoration potions, healthstones, mana gems, food and water
3. Selects special combat items, applies the configured food-buff priority, then compares effectiveness and conjured status
4. Creates/updates macros with the best available items
5. Updates automatically when your bag contents change

## Macro Usage

The created macros use:
- **Click or keybind**: Food/water outside combat, potion/stone/gem in combat
- The macro tooltip shows the currently selected item

## Installation

1. Download and extract to your `Interface/AddOns/` folder
2. Restart WoW or use `/reload`
3. Configure through Interface Options or use `/pb`

## Credits

Based on the original DrinkBot concept, completely rewritten for potion management with enhanced class-specific item support.
