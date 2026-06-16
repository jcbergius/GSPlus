# Analysis of `STAT_BUDGET_COST` in `Calculator.lua`

*A web-referenced review of GS+'s stat budget costs against WoW's documented
itemization system.*

> **Status — applied in v2.4.6.** Every recommendation below was implemented:
> `ITEM_BUDGET_EXPONENT` 1.7095 -> 1.5; `SCHOOL_SPELLPOWER` 0.86 -> 0.70; `MP5`
> 2.0 -> 2.5; `SPELL_PENETRATION` 0.20 -> 0.90; per-school resistances 2.5 -> 1.0;
> armor penetration split into a flat key (`ARMOR_PENETRATION`, 0.10) and a
> combat-rating key (`ARMOR_PENETRATION_RATING`, 1.0). The all-roles-within-15%
> balance test still passes (band 9% -> 12%), so role weights were left as tuned
> apart from aliasing the new armor-pen-rating key to attack power.

## 1. Executive summary

GS+'s `Calculator.STAT_BUDGET_COST` table is, to a remarkable degree, a faithful
copy of the canonical WoW itemization "stat budget" (the Hyzenthlei cost table
that Blizzard later confirmed at BlizzCon). **15 of the ~22 distinct cost values
match the documented figures exactly** (primary stats, Stamina, combat ratings,
attack power, ranged attack power, spell damage, +Healing, block value). The
table is well-grounded, not invented.

Six things diverge from the documented system. In order of how much they affect
the **displayed gs+** score (which is the linear weighted sum — see §3):

| # | Item | Addon value | Documented value | Reaches displayed gs+? |
|---|------|-------------|------------------|------------------------|
| 1 | `SCHOOL_SPELLPOWER` (single-school spell damage) | 0.86 | **0.70** | Yes — casters over-scored ~23% on those items |
| 2 | `MP5` | 2.00 | **2.5** | Yes — healers' MP5 under-scored ~20% |
| 3 | `SPELL_PENETRATION` | 0.20 | **0.8–0.9** | Yes (niche) — casters under-score spell pen ~4.5× |
| 4 | `ARMOR_PENETRATION` (used for Wrath ArP *rating*) | 0.10 | **1.0** (a combat rating) | Yes — Wrath armor-pen-rating undervalued |
| 5 | Per-school `*_RESISTANCE` | 2.50 each | **1.0** single-school (2.5 = *all* schools) | No (resist weight is 0) — only inflates the raw Budget Score |
| 6 | `ITEM_BUDGET_EXPONENT` | 1.7095 | **1.5 (3/2)** | No — affects only the optional raw Budget Score |

Everything else is accurate. The headline correctness issues that actually move
the gs+ number are #1 (school spell power) and #2 (MP5); #6 (the exponent) is the
largest *conceptual* deviation but has the smallest blast radius because the
displayed score doesn't use it.

---

## 2. How WoW's itemization budget actually works

Every equippable item is assigned a **budget** of points from its item level and
slot, and each stat point "costs" a fixed amount of that budget (its *StatMod*).
This was reverse-engineered by Hyzenthlei (2006) and later confirmed by a
Blizzard BlizzCon slide (1% melee crit = 14 points, i.e. 14× a basic stat).

**Documented per-point costs (StatMod), normalized so a primary stat = 1:**

| Stat | StatMod |
|------|---------|
| Strength / Agility / Intellect / Spirit | 1.0 |
| Any combat *rating* (crit, hit, haste, expertise, dodge, parry, defense, resilience, mastery, …) | 1.0 |
| Stamina | 0.67 (was 1.0 pre-TBC) |
| Attack power | 0.5 |
| Ranged attack power | 0.4 |
| Attack power (single creature type) | 0.33 |
| Spell damage | 0.86 |
| Spell damage (single school) | 0.70 |
| Spell damage (single creature type) | 0.55 |
| +Healing | 0.45 |
| MP5 | 2.5 |
| Block value | 0.65 |
| Magic / spell penetration | 0.9 (≈0.8 per the gem cross-check) |
| Additional (bonus) armor | 0.1 (BC) → 1/14 ≈ 0.071 (patch 3.2 / Wrath) |
| Resistance (one school) | 1.0 |
| Resistance (all schools) | 2.5 |

Two structural points from the sources matter for GS+:

1. **The combination is non-linear.** Costs are not simply summed. The documented
   rule is *Budget^1.5 = Σ (StatValue × StatMod)^1.5* — i.e. each stat's cost is
   raised to the **3/2 power**, summed, and the budget is the same power of the
   total. This is what stops a hybrid item with two stats from being worth twice
   a one-stat item; concentrated items are worth more per budget point.

2. **Weapon DPS, spell power on weapons, sockets, and set bonuses are *not* part
   of the stat budget** — they scale with item level separately. (GS+ already
   treats weapon DPS and set bonuses on their own tracks, which is consistent.)

Sources: Warcraft Wiki *Stat budget*; ZAM/Allakhazam *Itemization Formulas (WoW)*
(see §10).

---

## 3. How GS+ uses the budget cost

Two distinct numbers are computed in `Calculator.lua`, and `STAT_BUDGET_COST`
feeds **both**:

- **Raw "Budget Score"** — `CalculateRawStatBudget` is a p-norm:
  `total = Σ (value·cost)^p ; raw = total^(1/p)` with `p = ITEM_BUDGET_EXPONENT`.
  This mirrors Blizzard's `Budget^1.5 = Σ cost^1.5` structure exactly — **only the
  exponent value differs** (1.7095 vs 1.5). This number is shown only when
  "Budget Score" is enabled and is otherwise unused for the headline score.

- **Weighted gs+ (the number on your character pane)** — `CalculateWeightedStatScore`
  is a **linear** sum: `Σ value · cost · roleWeight`. The code comments correctly
  argue throughput adds linearly, so the exponent is deliberately *not* applied
  here.

Consequence: **the per-stat `cost` is a multiplier inside the displayed gs+**, so
a wrong cost skews the score wherever that stat's role weight is non-zero. The
**exponent**, by contrast, never touches the displayed gs+ — it only shapes the
optional Budget Score. (`TalentDetector:ResolveProfileByGear`, which decides
hybrid roles, also uses the linear weighted score, so it's unaffected by the
exponent too.)

This is why §1 ranks cost errors above the exponent error.

---

## 4. Per-stat verdict

**Exact matches (no action):** `STRENGTH/AGILITY/INTELLECT/SPIRIT` = 1.0;
`STAMINA` = 0.67; all ratings (`DEFENSE/DODGE/PARRY/BLOCK/CRITICAL/HIT/HASTE/
EXPERTISE/RESILIENCE/WEAPON_SKILL/MASTERY`) = 1.0; `ATTACKPOWER` = 0.5;
`RANGED_ATTACKPOWER` = 0.4; `SPELLPOWER` = 0.86; `HEALING` = 0.45;
`BLOCK_VALUE` = 0.65. These are the documented StatMods verbatim.

**Reasonable derivations (no action):**
- `FERAL_ATTACKPOWER` = 0.5 — undocumented, but feral AP behaves like melee AP, so cloning AP's 0.5 is correct.
- `HEALTH` = 0.067 and `MANA` = 0.067 — derived as Stamina/10 and Intellect/15 (the TBC "10 health = 1 Stamina, 15 mana = 1 Intellect" conversions). Internally consistent.
- `HP5` = 2.5 — undocumented (HP5 is rare); pricing it like MP5/regen is defensible.
- `ARMOR` = 0.07 — matches the **Wrath-era** bonus-armor StatMod (1/14 ≈ 0.071). The older BC figure was 0.10. Since the addon is TBC-anchored you *could* argue 0.10, but 0.07 is a documented value and the difference is negligible against armor's tiny role weights.

**Diverges from documentation:**

- **`SCHOOL_SPELLPOWER` = 0.86 → should be 0.70.** The documented cost of
  *single-school* spell damage is 0.70, not the full 0.86 of all-school spell
  power. Because `SCHOOL_SPELLPOWER` aliases the `SPELLPOWER` role weight, this
  over-scores school-specific caster items (Frozen Shadoweave, Spellfire, school
  damage wands) by 0.86/0.70 ≈ **1.23×** on that stat. Real impact for shadow /
  frost / fire specialists.

- **`MP5` = 2.00 → should be 2.5.** Documented MP5 is the single most expensive
  common stat at 2.5. Healers weight MP5 ~0.8, so this **under-scores healer MP5
  by ~20%**. (Note the table prices resistances at 2.5 but MP5 lower — the two
  appear to have been swapped/rounded.)

- **`SPELL_PENETRATION` = 0.20 → should be ~0.9.** Off by ~4.5×. It aliases the
  `SPELLPOWER` weight, so casters under-score spell penetration heavily. Low
  practical importance (a PvP-only stat), but it's a clear data error.

- **`ARMOR_PENETRATION` = 0.10 — ambiguous across flavors.** The addon maps both
  TBC *flat* "ignore N armor" and Wrath *armor penetration rating* to this one
  key. As flat armor-ignore, 0.10 (≈ bonus armor) is fine. As a Wrath **combat
  rating**, the documented cost is 1.0, so Wrath ArP-rating gear is undervalued
  ~10×. (It aliases the `ATTACKPOWER` weight, so it does reach melee scores.)

- **Per-school `*_RESISTANCE` = 2.50 → should be 1.0 (single school).** Only the
  *all-schools* bundle is 2.5; one school is 1.0. Worse, `ParseAllResistancesLine`
  adds an "all resistances" value to **all five** schools, each then costed at
  2.5 — so a "+25 All Resistances" item contributes 5 × 25 × 2.5 = 312.5 budget,
  vs the documented 25 × 2.5 = 62.5 (the all-res bundle is *discounted*, not 5×
  full price). That's a ~5× over-count. **However, every profile weights
  resistances at 0**, so this never touches the displayed gs+ — it only inflates
  the optional raw Budget Score. Low priority, but worth fixing for that number's
  fidelity.

---

## 5. The budget exponent: 1.7095 vs the documented 1.5

The documented itemization exponent is firmly **3/2 = 1.5**. GS+ uses
**1.7095**, and the in-code comment ties it to a *color-reference* ilvl curve
(`(ilvl − 91.45)/0.65`) that is unrelated to the stat-combination exponent — so
1.7095 has no documented basis as a budget exponent. It appears hand-picked
(plausibly to make the raw Budget Score's magnitude resemble legacy GearScore).

A higher exponent **rewards stat concentration more aggressively.** For an item
whose budget is split evenly across *n* stats, the p-norm pays out
`budget · n^(1/p − 1)` versus a single-stat item's full `budget`:

| Stats split | Concentration premium at p = 1.5 (documented) | at p = 1.7095 (GS+) |
|-------------|-----------------------------------------------|---------------------|
| 2 stats | +26% | +33% |
| 4 stats | +59% | +78% |

So GS+'s Budget Score penalizes well-rounded items noticeably harder than
Blizzard's own itemization would — by roughly 7 points for a 2-stat item and ~19
points for a 4-stat item, relative to the correct 1.5 curve.

**Recommendation:** set `ITEM_BUDGET_EXPONENT = 1.5` to match the documented
system. **Caveat:** because the displayed gs+ is linear, this changes only the
optional Budget Score; expect that number to shift and any hard-coded comparisons
or expectations around it to need a glance. It does **not** change anyone's
headline gs+.

---

## 6. Budget cost vs throughput value — the conceptual subtlety

The documented StatMod answers "how much **budget** did Blizzard charge for this
stat?" GS+ reuses those numbers as if they also answer "how much is this stat
**worth** to the player," then multiplies by a 0–1 role weight. These two
questions are not the same axis:

- They *coincide* for attack power: 1 Strength → 2 AP, and AP's budget cost is
  0.5, so cost ≈ value. The addon's `ATTACKPOWER` roleWeight ≈ 0.9 (≈ "full
  value") then fine-tunes — coherent, no double counting.
- They *diverge* for stats where Blizzard's pricing isn't a throughput statement.
  MP5 costs 2.5 budget but that doesn't mean 1 MP5 is worth 2.5 Intellect to a
  healer. The addon leans on the role weight to absorb the difference (healer MP5
  weight 0.8), which works only because the weights were tuned **against these
  specific costs**.

The practical implication: `STAT_BUDGET_COST` and `PROFILE_WEIGHTS` are a
**matched pair**. The cost table is the right place for "universal stat→budget
normalization," and the role weight for "per-role value." That separation is
sound — but it means you can't change a cost in isolation without sanity-checking
the affected role weights, or the product (cost × weight) will drift. The
existing "all roles within ~15% gs+ band" test is the guardrail to re-run after
any change here.

---

## 7. Recommendations (ranked)

1. **`SCHOOL_SPELLPOWER`: 0.86 → 0.70.** Highest-value correctness fix; matches
   documented single-school spell damage and stops over-scoring school-specific
   caster gear. Re-run the role-band test afterward.
2. **`MP5`: 2.00 → 2.5.** Restores healer MP5 to its documented cost (and lines
   it up with the resistance 2.5 the table already uses).
3. **Disambiguate armor penetration.** Keep ~0.10 for TBC flat armor-ignore, but
   treat Wrath/Cata *armor penetration rating* as a combat rating (≈1.0). This
   likely means splitting the parser's `ARMOR_PENETRATION` into a flat key and a
   rating key (the parser already distinguishes "ignore N armor" text from
   `ARMOR_PENETRATION_RATING`).
4. **`SPELL_PENETRATION`: 0.20 → 0.8–0.9.** Low impact (PvP-only) but trivially
   correct.
5. **`ITEM_BUDGET_EXPONENT`: 1.7095 → 1.5.** Aligns the Budget Score with
   Blizzard's curve. Cosmetic to the headline gs+; do it for fidelity, and note
   the Budget Score numbers will move.
6. **Per-school resistance: 2.50 → 1.0**, and cost an "all resistances" source at
   0.5/school (so the bundle totals the documented 2.5). Affects only the raw
   Budget Score today; lowest priority.

Items #1–#4 change the displayed gs+ for the affected specs; #5–#6 do not.

---

## 8. Caveats & methodology

- The documented StatMods describe **Vanilla→Wrath** itemization (the system was
  retired around Cataclysm/MoP as stats were consolidated). GS+ anchors its
  budget to TBC and rescales *color references* per flavor, so the TBC-era table
  is the right baseline; Cata-specific stats (mastery, reforging) sit outside the
  classic table and are reasonable extrapolations.
- "Reaches displayed gs+?" was verified against `PROFILE_WEIGHTS` and the
  `STAT_WEIGHT_ALIASES` map in `StatWeights.lua` (e.g. `SCHOOL_SPELLPOWER`,
  `SPELL_PENETRATION` → `SPELLPOWER`; `ARMOR_PENETRATION` → `ATTACKPOWER`;
  resistances weighted 0 across all profiles).
- The community StatMod table is itself reverse-engineered and the wiki flags it
  "accuracy disputed" at the margins; treat the costs as well-supported estimates,
  not Blizzard source. This matches the addon's own "this is data — tune freely"
  philosophy.

---

## 9. Bottom line

GS+'s stat budget is **well-founded** — it reproduces the canonical itemization
cost table almost exactly. The actionable corrections are small and specific:
school spell damage (0.86→0.70) and MP5 (2.0→2.5) are the two that visibly move
scores; armor-pen-rating and spell-pen are smaller fixes; the resistance pricing
and the 1.7095→1.5 exponent only affect the optional Budget Score. None of these
indicate a broken model — just a handful of values to true up against the
documented system.

---

## 10. References

- Warcraft Wiki — *Stat budget*: https://warcraft.wiki.gg/wiki/Stat_budget
- ZAM / Allakhazam — *Itemization Formulas (WoW)* (Hyzenthlei cost table, 3/2 budget formula): https://wow.allakhazam.com/wiki/Itemization_Formulas_(WoW)
- Warcraft Wiki — *Combat rating system*: https://warcraft.wiki.gg/wiki/Combat_rating_system
- Original source thread (now archived): Elitist Jerks, *Item Level Mechanics* (referenced by Warcraft Wiki).
