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
- `/hb` or `/PotionBot` - Opens configuration panel

### Installation
- Extract to Interface/AddOns/PotionBot/
- Compatible with all current WoW versions
