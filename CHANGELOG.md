## 5.5.0-forever-beta

- Add a saved food-stat priority list with Up/Down controls in /pb, including Spirit.
- Rank Well Fed foods by stat amounts in user order, then restoration quality.
- Parse public buff benefit text, shared primary-stat values and common spell/healing wording.
- Exercise GUI reordering and selection using a real Forever Strength food tooltip.

## 5.4.0-forever-beta

- Keep food exclusively on the health macro and water on the mana macro outside combat.
- Add a default-enabled setting to prefer Well Fed food when the buff is absent.
- Prefer plain food with an existing buff; retain buff food as a fallback.
- Refresh on player aura changes outside combat and treat unreadable auras as unknown.

## 5.3.0-forever-beta

- Include food and water on both buttons outside combat using secure nocombat conditions.
- Keep combat potions behind combat conditions; no macro rewrite at combat start.
- Rank meals by restoration per second, handle decimal amounts and avoid duplicate combined meals.

## 5.2.1-forever-beta

- Reproduce the original empty macros with the real GetItemInfo return order.
- Add diagnostic reports, macro-write verification and character-slot fallback.
- Support dual restoration effects, percentage healthstones and bounded tooltip retries.
- Use supported checkbutton controls and exercise settings construction in tests.

## 5.2.0-forever-beta

- Add Interface 16001 for WoW Forever beta.
- Read bag tooltip data through C_TooltipInfo and defer macro changes during combat.
- Fix range ranking, Classic mana gem recognition, exhausted item clearing and keyboard macro activation.
- Use one binding label file and a shared Bindings.xml.
- Remove aura-based health macro suppression.
- Validate locally with Lua 5.1 mocks; in-game Forever validation remains pending.

## Version 1.0.0 (Initial Release)

### Features
- **Smart Potion Detection**: Automatically detects health and mana potions, elixirs, flasks
- **Class-Specific Priority**: Healthstones (Warlock) and Mana Gems (Mage) are prioritized
- **Automatic Macro Creation**: Creates HealthPotionBot and ManaPotionBot macros
- **Multi-Version Support**: Compatible with Classic Era, Cataclysm Classic, and Retail
- **Classic Era Support**: Properly handles "Restores X to Y health/mana" tooltip format
- **Priority System**: Prioritizes special items > conjured items > regular consumables
- **Configurable Interface**: Enable/disable macros through addon settings

### Technical Details
- Complete rewrite from DrinkBot foundation
- Enhanced tooltip scanning for various potion formats
- Improved sorting algorithm for optimal item selection
- Clean macro generation without unnecessary spell references
- Proper event handling for bag updates and player state changes

### Slash Commands
- `/pb`, `/pp`, or `/potionbot` - Opens configuration panel

### Installation
- Extract to Interface/AddOns/PotionBot/
- Compatible with all current WoW versions
