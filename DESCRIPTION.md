# PotionBot - Detailed Description

## Overview
PotionBot is a World of Warcraft addon designed to streamline potion management during gameplay. Instead of manually selecting different potions as you acquire better ones, PotionBot automatically maintains two macros that always use the most effective health and mana restoration items available in your bags.

## The Problem It Solves
- **Inventory Management**: No more manually updating action bars when you get better potions
- **Combat Efficiency**: Always use the best available restoration items without thinking
- **Bag Space**: Prioritizes special items like Healthstones and Mana Gems over regular potions
- **Multi-Version Compatibility**: Works across different WoW expansions with varying item formats

## How It Works

### Automatic Scanning
The addon continuously monitors your bags using WoW's `BAG_UPDATE_DELAYED` event. When items change, it:
1. Scans all bag slots for consumable items
2. Reads item tooltips to identify restoration amounts
3. Categorizes items by type (health vs mana restoration)
4. Applies priority rules to determine the best options

### Priority System
**Health Items (in order of preference):**
1. Healthstones (Warlock-created items)
2. Conjured health potions/items
3. Regular health potions (highest healing amount first)
4. Health elixirs and flasks

**Mana Items (in order of preference):**
1. Mana Gems (Mage-created items)
2. Conjured mana potions/items  
3. Regular mana potions (highest restoration first)
4. Mana elixirs and flasks

### Macro Creation
The addon creates two persistent macros:
- **HealthPotionBot**: Uses the best available health restoration item
- **ManaPotionBot**: Uses the best available mana restoration item

These macros are automatically updated whenever your inventory changes, ensuring they always point to the optimal items.

## Technical Implementation

### Tooltip Parsing
The addon uses a sophisticated tooltip scanning system to identify consumable items:
- Creates hidden GameTooltip frames for item analysis
- Parses tooltip text for restoration patterns like "Restores X to Y health"
- Handles different tooltip formats across WoW versions (Classic Era uses ranges like "25 to 35")
- Identifies special item types through tooltip keywords

### Cross-Version Compatibility
Supports multiple WoW versions through intelligent detection:
- **Classic Era (1.15.x)**: Handles range-based restoration values
- **Cataclysm Classic (4.4.x)**: Supports modern tooltip formats
- **Retail (11.0.x)**: Full modern WoW API compatibility

### Event-Driven Updates
Uses efficient event handling to minimize performance impact:
- `BAG_UPDATE_DELAYED`: Responds to inventory changes
- `PLAYER_ENTERING_WORLD`: Initial setup on login/reload
- `PLAYER_LEVEL_UP`: Rechecks available items when leveling
- `UNIT_AURA`: Monitors for relevant buffs/debuffs

## User Experience

### Setup Process
1. Install the addon to your AddOns folder
2. Log in or `/reload` to activate
3. The addon automatically creates the two macros
4. Drag macros to action bars or create keybinds
5. Optionally configure preferences with `/pb` or `/potionbot`

### Daily Usage
- Use the macros like any other action bar button
- No manual management required - macros update automatically
- Visual feedback shows which items are being prioritized
- Configuration panel allows enabling/disabling specific macro types

### Quality of Life Features
- **Saved Settings**: Preferences persist across sessions
- **Slash Commands**: Easy access to configuration (`/pb`, `/potionbot`)
- **Visual Indicators**: Color-coded addon messages for status updates
- **Error Handling**: Graceful handling of edge cases and missing items

## Development Philosophy

### Code Quality
- Clean, readable Lua code following WoW addon best practices
- Comprehensive error handling and edge case management
- Efficient algorithms to minimize performance impact
- Modular design for easy maintenance and updates

### User-Centric Design
- Zero-configuration operation out of the box
- Intelligent defaults that work for most players
- Optional customization for power users
- Consistent behavior across different WoW versions

### Community Focus
- Open source development on GitHub
- Automated release pipeline for timely updates
- Comprehensive documentation and examples
- Based on proven DrinkBot foundation with community trust

## Attribution
PotionBot is based on the original DrinkBot addon, modified and enhanced to focus specifically on health and mana potions instead of food and drinks. The core scanning and macro management concepts were adapted from DrinkBot's proven architecture, with significant enhancements for potion-specific functionality and modern WoW compatibility.

## Future Roadmap
- Enhanced tooltip parsing for edge case items
- Support for additional consumable types (bandages, etc.)
- Advanced filtering options for specific potion types
- Integration with popular addon frameworks
- Performance optimizations for large inventories