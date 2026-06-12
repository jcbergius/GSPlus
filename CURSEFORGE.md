# CurseForge Project Description (draft)

Paste into the CurseForge project description. Replace screenshot
placeholders before publishing - listings with screenshots convert far
better. Suggested shots: (1) mouseover tooltip on another player,
(2) item tooltip with the For You comparison, (3) the group overview
window in a raid.

---

# gs+ (GearScore Plus)

**Gear scores that understand your spec. Zero configuration - install it
and everything just works.**

Classic GearScore tells you how big an item is. gs+ tells you
how good it is *for the character wearing it*. A Resto Shaman and a
Warrior tank looking at the same trinket see different scores - because it
IS worth different amounts to them.

## Everything works out of the box

No setup, no profiles to configure, no commands to learn:

- **Your score on the character pane.** Click it for an item-by-item
  breakdown, right-click for your group's scores.
- **Scores on everyone you mouse over.** Hover any player and their gear
  score appears on the tooltip. Players you've seen before show
  instantly.
- **Scores on the inspect window**, with their spec and missing
  enchant / empty socket warnings.
- **Group overview for raid leaders.** Every party/raid member's score,
  role, and gear warnings in one window - perfect for vetting pugs.
- **Exact score sharing between users.** gs+ users in the
  same group exchange scores automatically over the addon channel - no
  inspect range needed. The more of your raid runs it, the better it
  gets.

## Smarter than an item level

- **Role-aware weighting** from your talents - healers value healing,
  tanks value avoidance, hit matters for DPS. Feral Druids are detected
  as cat or bear from their gear.
- **"For You vs Equipped"** on every item tooltip: a green/red answer to
  "is this an upgrade for MY spec?" It even knows when you're hit-capped
  and discounts hit accordingly - with a note explaining why.
- **Transparent math.** Hold Shift on any tooltip for the full
  stat-by-stat breakdown. No black box.
- **Legacy GearScore included.** The familiar classic number is shown
  alongside, so you can still talk to LFG in units everyone knows.
- **Fair and consistent.** The same gear always produces the same score,
  no matter who computes it. Personal adjustments (like hit cap) only
  ever affect your private upgrade advice, never the shared number.

## Display settings

`/gs` (or Interface Options → gs+) toggles individual
visuals: tooltip lines, breakdowns, upgrade comparison, legacy GearScore,
mouseover scores, character pane display, and score sharing. That's the
only command - everything else is automatic.

## Notes

- Designed for TBC Classic / Anniversary realms (English clients;
  localization is planned).
- Gear scoring is an approximation - it doesn't replace class knowledge
  or encounter context.
- Open source under MIT: [GitHub](https://github.com/jcbergius/GSPlus).
  Bug reports and contributions welcome - every change runs against an
  automated test suite.
