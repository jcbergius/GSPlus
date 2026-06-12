# In-Game Test Checklist

The automated harness (`tests/harness.lua`) covers logic, but it stubs the
WoW API. This ~10 minute pass covers what only a real client can verify.
Run it before tagging a release.

Setup: copy the addon folder into `Interface/AddOns/`, then:

```text
/console scriptErrors 1
/reload
```

Leave script errors on for the whole pass - any Lua error popup is a failure.

## 1. First impressions (2 min)

- [ ] On a character that has never used the addon, exactly one green
      orientation message appears in chat after login. `/reload` again -
      no message this time.
- [ ] `/bgs` opens the options panel; every checkbox reflects its default
      (all on). The panel also appears under Interface Options → AddOns.

## 2. Character pane hub (2 min)

- [ ] Open the character pane (`C`). The **BGS** score shows, positioned
      sensibly (not overlapping stats or buttons). *If misplaced, note the
      offset - it's set in `CharacterPaneUI.lua` (`73, 254`).*
- [ ] Hover it: tooltip shows profile, weighted score, budget score,
      legacy GS, and the click/right-click hints.
- [ ] The profile shown matches your actual spec (core check - this
      validates `GetTalentTabInfo` parsing on this client).
- [ ] **Click** → gear window opens: items in slot order, scores colored,
      hovering a row shows the item tooltip.
- [ ] Profile dropdown: pick a different profile - scores update; pick
      "Automatic" - detected profile returns.
- [ ] **Right-click** the BGS score → group window opens. Solo, it shows
      just you with your score.

## 3. Item tooltips (2 min)

- [ ] Hover an equipped item: BetterGearScore section shows Weighted
      Score, Budget Score, GearScore (legacy), and "For You vs Equipped:
      currently equipped".
- [ ] Hover a bag/bank/AH item for the same slot: the For You line shows
      a green/red delta.
- [ ] Hold **Shift**: stat-by-stat breakdown appears and the
      contributions visually add up to the weighted score.
- [ ] Hover an item with a green "Equip:" effect (healing/spell damage/
      MP5): the budget score includes it.
- [ ] Shift-compare (hover item with Shift on a vendor/AH): the
      comparison tooltips also show scores, with no duplicated lines.
- [ ] Hover a recipe or container item repeatedly: no duplicate
      BetterGearScore sections.
- [ ] If your character is at/near hit cap: an orange note appears under
      the For You line on hit items - but the Weighted Score itself must
      NOT change as you cross the cap.

## 4. Other players (2 min)

- [ ] Mouse over a nearby player: tooltip shows "inspecting..." then the
      score fills in (or appears on the next hover). Second hover is
      instant.
- [ ] Mouse over the same player after a `/reload`: score shows instantly
      (persistent cache).
- [ ] Inspect a player: their score appears on the inspect window;
      hovering it shows their profile and any enchant/socket warnings.
      *Check the frame position on the inspect window specifically - it
      mirrors the character pane offsets and may need its own tuning in
      `InspectPaneUI.lua`.*

## 5. Group features (2 min, needs a second player)

- [ ] Join a party with another addon user. Within ~10 seconds, the group
      window shows their exact score marked "(shared, just now)".
- [ ] With a non-addon party member in inspect range: open the group
      window - they get inspected automatically and show "(inspected)".
- [ ] Swap a piece of gear: your row/score updates within a few seconds
      on BOTH clients (broadcast debounce is 5s).
- [ ] A party member with missing enchants/empty sockets shows the orange
      warning text.

## 6. Options sanity (1 min)

- [ ] Toggle "Show gear score on item tooltips" off: tooltip section
      disappears immediately. Toggle back on.
- [ ] Toggle "Show gear score on the character pane" off: BGS display
      hides. Toggle back on.
- [ ] `/reload`: all toggles persisted.

## 7. Class-specific spot checks (when available)

- [ ] **Feral Druid**: in cat gear the profile reads Druid Feral; in
      bear/tank gear it flips to Druid Tank (gear-based detection).
- [ ] **Hunter**: legacy GS weights the ranged weapon heavily.
- [ ] A healer sees Healing-heavy items score above Spell Damage items;
      a tank sees avoidance/stamina items score high.

## Known tuning points

If something is misplaced rather than broken, these are the dials:

- Character pane position: `CharacterPaneUI.lua` → `SetPoint(...73, 254)`
- Inspect window position: `InspectPaneUI.lua` → `SetPoint(...73, 254)`
- Gear window header layout: `UI.lua` → `HEADER_HEIGHT`, dropdown anchor
