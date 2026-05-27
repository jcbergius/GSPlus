# Better Gear Score

A WoW Classic addon that calculates gear score based on item stat budgets with class-specific weighting.

## Features

- **Raw Stat Budget Calculation**: Base gear score is the sum of all stats on an item
  - Example: Item with 50 STR + 50 AGI + 50 INT = 150 base stat budget

- **Class-Weighted Scoring**: Applies class-specific multipliers to each stat
  - Different classes value different stats (e.g., Rogues value Agility more, Mages value Intellect)
  - Supports all 9 WoW Classic classes with optimized weights

- **Character Total Score**: View combined weighted score for all equipped items

- **Individual Item Scores**: See each item's contribution to your gear score

- **Multiple Display Options**:
  - UI Panel: Scrollable window showing character total and individual items
  - Chat Commands: Quick access via slash commands
  - Item Tooltips: Hover over items to see details

## Installation

1. Copy the `BetterGearScore` folder to your WoW Classic addons directory:
   ```
   C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\BetterGearScore
   ```
   (Path varies by WoW installation location)

2. Reload WoW or type `/reload` in-game

3. The addon loads automatically on login

## Usage

### Chat Commands

- `/gearscore` or `/gs` - Show help menu
- `/gs show` or `/gs ui` - Open the gear score window
- `/gs hide` or `/gs close` - Close the window
- `/gs toggle` - Toggle window visibility
- `/gs score` - Print current gear score to chat

### UI Window

- **Total Gear Score**: Large text showing your weighted character gear score
- **Raw vs Weighted**: Shows both raw stat budget and class-weighted score
- **Item List**: Scrollable list of all equipped items with individual scores
- **Item Hover**: Hover over any item to see the full tooltip

## How the Calculation Works

1. **Raw Stat Budget**: Sum all stats on an item
   - Counts: Strength, Agility, Intellect, Stamina, Spirit, Armor, Attack Power, Spell Power, Defense, Dodge, Parry, Block, Critical Strike, Haste

2. **Apply Class Weights**: Multiply each stat by the class-specific weight
   - Example for Rogue on an item:
     - 50 STR × 0.8 = 40
     - 50 AGI × 1.4 = 70
     - 50 INT × 0.2 = 10
     - **Total Weighted Score = 120**

3. **Sum All Items**: Add weighted scores for all equipped items to get character total

## Class Weights

Each class has optimized stat multipliers:

- **Warrior**: Favors Strength (1.2) and Stamina (1.1)
- **Paladin**: Balanced Strength (1.0), Intellect (1.1), Block (1.0)
- **Hunter**: Favors Agility (1.3) and Attack Power (1.1)
- **Rogue**: Heavily favors Agility (1.4) and Attack Power (1.2)
- **Priest**: Heavily favors Intellect (1.4) and Spell Power (1.3)
- **Death Knight**: Favors Strength (1.3) and Stamina (1.2)
- **Shaman**: Balanced with Intellect (1.2) emphasis
- **Mage**: Heavily favors Intellect (1.5) and Spell Power (1.4)
- **Warlock**: Favors Intellect (1.4) and Spell Power (1.3)
- **Druid**: Balanced weights (1.0-1.1) for versatility

## Files

- `GearScore.toc` - Addon manifest
- `Core.lua` - Main addon initialization and event handling
- `StatWeights.lua` - Class-specific stat multipliers
- `ItemParser.lua` - Item stat extraction from WoW API
- `GearScoreCalculator.lua` - Gear score calculation logic
- `UI.lua` - User interface panel and tooltips
- `Commands.lua` - Chat command handler

## Requirements

- World of Warcraft Classic
- Lua 5.1 (included with WoW)

## License

MIT License - Feel free to modify and distribute
