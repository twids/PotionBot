# PotionBot

<div align="center">
  <img src="logo.png" alt="PotionBot Logo" width="200" height="200">
</div>

PotionBot is a World of Warcraft addon that automatically creates and updates macros with the best health and mana potions in your bags, prioritizing special items like Healthstones and Mana Gems.

*Based on the original DrinkBot addon - modified to work with health and mana potions instead of food and drinks.*

## Features

- **Smart Potion Detection**: Automatically scans your bags for health and mana potions, elixirs, and flasks
- **Priority System**: 
  - Healthstones are prioritized over all health potions
  - Mana Gems are prioritized over all mana potions
  - Conjured items are preferred over regular consumables
  - Higher restoration values are preferred
- **Automatic Macro Creation**: Creates "HealthPotionBot" and "ManaPotionBot" macros
- **Multi-Version Support**: Works with Classic Era, Cataclysm Classic, and Retail WoW
- **Configurable**: Enable/disable individual macros through the interface options

## Slash Commands

- `/hb` or `/PotionBot` - Opens the configuration panel

## How It Works

1. The addon scans your bags for consumable items
2. Identifies potions, elixirs, flasks, healthstones, and mana gems through tooltip analysis
3. Sorts them by priority (special items > conjured > regular) and effectiveness
4. Creates/updates macros with the best available items
5. Updates automatically when your bag contents change

## Macro Usage

The created macros use:
- **Left-click**: Use the potion/item
- The macro tooltip shows the currently selected item

## Installation

1. Download and extract to your `Interface/AddOns/` folder
2. Restart WoW or use `/reload`
3. Configure through Interface Options or use `/hb`

## Compatibility

- **Classic Era (Vanilla)**: Full support
- **Cataclysm Classic**: Full support  
- **Retail (Dragonflight/War Within)**: Full support

## Credits

Based on the original DrinkBot concept, completely rewritten for potion management with enhanced class-specific item support.
