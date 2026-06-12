# Better Gear Score

Better Gear Score is a World of Warcraft Classic / Anniversary addon that calculates a role-aware gear score for the player’s equipped items.

Unlike simple item-level or raw-stat scoring, Better Gear Score attempts to value gear based on what your character is actually built to do. It detects your class and talent specialization, chooses an appropriate role profile, scans equipped items, and calculates both raw and weighted gear scores.

## Features

- **Automatic Role Detection**
  - Reads the player’s talent trees.
  - Automatically selects an appropriate role profile.
  - Examples:
    - Restoration Shaman → Shaman Healer
    - Protection Warrior → Warrior Tank
    - Holy Paladin → Paladin Healer
    - Shadow Priest → Priest DPS

- **Role-Weighted Gear Score**
  - Stats are weighted differently depending on role.
  - Healers value healing power, intellect, spirit, and MP5.
  - Tanks value stamina, armor, defense, dodge, parry, and block.
  - Physical DPS value hit, attack power, agility, strength, crit, and haste.
  - Casters value spell power, hit, intellect, crit, and haste.

- **Raw Stat Budget**
  - Shows the total unweighted stat budget on your gear.
  - Useful for comparing how much total stat value an item has before role weighting.

- **Tooltip Scanning**
  - Adds Better Gear Score information directly to item tooltips.
  - Detects many Classic-style green equip effects that are not always exposed cleanly by Blizzard’s item stat API.
  - Examples:
    - `Equip: Increases healing done by up to X`
    - `Equip: Increases damage done by magical spells and effects by up to X`
    - `Equip: Restores X mana per 5 sec.`
    - `Equip: Improves your chance to hit by X%`

- **Equipped Gear Window**
  - Displays total weighted gear score.
  - Shows raw and weighted totals.
  - Lists equipped items in slot order with their individual contribution.
  - Includes a profile dropdown for quick manual overrides.

- **Character Pane Score**
  - Shows your current score directly on the character pane.

- **Inspect Scoring**
  - `/bgs target` scores the gear of the player you are targeting (inspect range required).
  - Uses their inspected talents to pick a role profile when available.

- **Performance Friendly**
  - Item stats, set bonuses, and totals are cached and only recalculated when your equipment or talents change.
  - Equipment-swap event bursts are debounced into a single refresh.

- **Chat Commands**
  - Quick access to score, UI, detected role, available profiles, inspect scoring, and an item scan debugging command.

## Installation

1. Download or clone this repository.

2. Copy the addon folder into your WoW Classic addon directory:

   ```text
   World of Warcraft/_classic_/Interface/AddOns/BetterGearScore
   ```

   On Windows, this is often:

   ```text
   C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\BetterGearScore
   ```

3. Make sure the folder contains `BetterGearScore.toc` directly inside it.

   Correct:

   ```text
   Interface/AddOns/BetterGearScore/BetterGearScore.toc
   ```

   Incorrect:

   ```text
   Interface/AddOns/BetterGearScore/BetterGearScore/BetterGearScore.toc
   ```

4. Restart the game or type:

   ```text
   /reload
   ```

## Usage

### Basic Commands

```text
/bgs
/gs
```

Shows the help menu.

```text
/bgs score
```

Prints your current Better Gear Score in chat.

```text
/bgs show
```

Opens the Better Gear Score window.

```text
/bgs hide
```

Closes the Better Gear Score window.

```text
/bgs toggle
```

Toggles the Better Gear Score window.

```text
/bgs detect
```

Shows the detected talent profile and talent point distribution.

```text
/bgs profiles
```

Lists all available scoring profiles.

```text
/bgs profile
```

Shows the currently selected profile.

```text
/bgs profile auto
```

Returns profile selection to automatic talent detection.

```text
/bgs profile warrior_tank
```

Manually overrides the profile. This is mostly useful for testing or edge cases. The profile dropdown in the gear window (`/bgs show`) does the same thing.

```text
/bgs target
```

Scores the gear of your current target (must be a player in inspect range).

```text
/bgs scan [Item Link]
```

Prints the stats Better Gear Score detected on a linked item, plus its budget and weighted scores. Shift-click an item into the command to link it.

## Automatic Role Detection

Better Gear Score uses your talent trees to determine your role profile.

For example:

| Class | Talent Tree | Detected Profile |
|---|---|---|
| Warrior | Arms | Warrior DPS |
| Warrior | Fury | Warrior DPS |
| Warrior | Protection | Warrior Tank |
| Paladin | Holy | Paladin Healer |
| Paladin | Protection | Paladin Tank |
| Paladin | Retribution | Paladin DPS |
| Priest | Discipline | Priest Healer |
| Priest | Holy | Priest Healer |
| Priest | Shadow | Priest DPS |
| Shaman | Elemental | Shaman Elemental |
| Shaman | Enhancement | Shaman Enhancement |
| Shaman | Restoration | Shaman Healer |
| Druid | Balance | Druid Balance |
| Druid | Feral Combat | Druid Feral |
| Druid | Restoration | Druid Restoration |

Some roles are inherently ambiguous. For example, a Feral Druid may be playing as either cat DPS or bear tank. Better Gear Score currently defaults Feral to `Druid Feral`. Future versions may improve this by also analyzing equipped gear.

## Scoring Model

Better Gear Score calculates two values:

### Raw Stat Budget

The raw stat budget is the sum of all detected stats on an item.

Example:

```text
+18 Spirit
+42 Healing
+14 Spell Damage
+7 MP5
```

Raw stat budget:

```text
18 + 42 + 14 + 7 = 81
```

### Weighted Gear Score

The weighted score multiplies each stat by the currently selected role profile.

Example for a Shaman Healer:

```text
18 Spirit × 0.35 = 6.30
42 Healing × 1.00 = 42.00
14 Spell Power × 0.35 = 4.90
7 MP5 × 0.95 = 6.65
```

Weighted score:

```text
6.30 + 42.00 + 4.90 + 6.65 = 59.85
```

Displayed score:

```text
59
```

## Supported Stats

Better Gear Score currently supports these stat categories:

```text
Strength
Agility
Intellect
Stamina
Spirit
Armor
Attack Power
Ranged Attack Power
Spell Power
Healing
Defense
Dodge
Parry
Block
Critical Strike
Hit
Haste
Mana per 5 seconds
```

Classic items often contain special equip effects rather than clean modern stat entries. Better Gear Score scans item tooltips to detect important effects such as healing power, spell damage, MP5, hit, crit, and dodge.

## Role Profiles

Each profile uses weights from `0.0` to `1.0`.

```text
1.0 = best-in-role stat
0.7–0.9 = strong stat
0.3–0.6 = useful secondary stat
0.1–0.2 = minor incidental value
0.0 = effectively useless for that role
```

Examples:

- A Shaman Healer gives `0.0` value to Strength and Attack Power.
- A Warrior Tank gives high value to Stamina, Armor, Defense, Dodge, Parry, and Block.
- A Mage DPS gives high value to Spell Power, Hit, Intellect, Crit, and Haste.
- A Rogue DPS gives high value to Agility, Attack Power, Hit, Crit, and Haste.

## Files

```text
BetterGearScore.toc
Core.lua
StatWeights.lua
Profiles.lua
TalentDetector.lua
ItemParser.lua
SetBonuses.lua
BetterGearScoreCalculator.lua
CharacterPaneUI.lua
UI.lua
Tooltip.lua
Inspect.lua
Commands.lua
README.md
```

### File Overview

- **BetterGearScore.toc**
  - Addon manifest and load order.

- **Core.lua**
  - Initializes the addon, registers events, and refreshes the UI.

- **StatWeights.lua**
  - Contains all role-based stat weight tables.

- **Profiles.lua**
  - Handles profile names, defaults, manual overrides, and automatic profile selection.

- **TalentDetector.lua**
  - Reads talent trees and maps the dominant tree to a scoring profile.

- **ItemParser.lua**
  - Reads equipped items, parses item stats, and scans tooltip equip effects. Results are cached per item link.

- **SetBonuses.lua**
  - Detects active set bonuses on equipped gear and converts them into stats.

- **BetterGearScoreCalculator.lua**
  - Calculates raw and weighted gear scores. The total score is cached until equipment or talents change.

- **CharacterPaneUI.lua**
  - Displays the score on the character pane.

- **UI.lua**
  - Creates and updates the Better Gear Score window, including the profile dropdown.

- **Tooltip.lua**
  - Adds Better Gear Score information to item tooltips, including comparison tooltips.

- **Inspect.lua**
  - Scores inspected players for `/bgs target`.

- **Commands.lua**
  - Registers and handles slash commands.

## Saved Variables

Better Gear Score uses:

```lua
BetterGearScoreSavedVars
```

This is used for settings such as manual profile overrides.

Your `.toc` should contain:

```toc
## SavedVariables: BetterGearScoreSavedVars
```

## Development Notes

### Reloading

After making code changes, reload the UI with:

```text
/reload
```

### Lua Errors

To enable Lua error popups in-game:

```text
/console scriptErrors 1
/reload
```

To disable them again:

```text
/console scriptErrors 0
/reload
```

### Testing Role Detection

Use:

```text
/bgs detect
```

This prints the detected profile and the talent point distribution used to determine it.

### Testing Tooltip Parsing

Hover items with green equip effects such as:

```text
Equip: Increases healing done by up to 42 and damage done by up to 14 for all magical spells and effects.
Equip: Restores 7 mana per 5 sec.
```

The tooltip should show a higher raw stat budget than just the visible base stats.

## Limitations

- Tooltip parsing is currently designed for English clients.
- Some Classic item effects have unusual wording and may not be detected yet.
- Talent detection identifies specialization, not always exact gameplay intent.
- Feral Druid cat vs bear is currently not perfectly distinguishable from talents alone.
- Gear scoring is an approximation and should not replace class knowledge, encounter context, or common sense.

## Planned Improvements

- Better tooltip parsing coverage for more Classic item effects.
- Localization support for non-English clients.
- Smarter Feral Druid tank vs DPS detection based on equipped gear.
- Better support for weapon DPS and weapon-specific scoring.
- More detailed item breakdowns in the UI.
- Show inspected players' scores directly on the inspect frame.

## License

MIT License
