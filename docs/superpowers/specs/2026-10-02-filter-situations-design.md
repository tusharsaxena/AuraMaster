# Filter situations: design (NPC / player behavior where spell lists don't apply, and zones)

- **Date:** 2026-10-02
- **Branch:** `feat/2026-10-02-filter-situations`, in the main AuraMaster tree (the game loads it).
- **Plan:** `docs/superpowers/plans/2026-10-02-filter-situations.md`
- **Builds on:** `2026-10-02-spell-list-views-design.md` (merged, 5b6c9f2). Its ids / no-ids views stay;
  this adds a third.
- **Design inputs:** `docs/superpowers/research/2026-10-02-filter-situations-design-inputs.json` (three
  read-only design agents and an adversarial critic, 2026-10-02).

## Owner decisions (2026-10-02)

1. A new Filters tab, **Situations**, the **last** tab, after Sorting.
2. Per container, where Blizzard won't apply spell lists, the behavior splits by **NPC** vs **player**:
   **Every aura, once** (the default, opt-out) or **Only my Blizzard categories set to Show** (what
   master ships today).
3. Per container **zone** checkboxes on the same tab, **all on** by default (opt-out): Open world,
   Dungeons, Scenarios and delves, Raids, Battlegrounds, Arenas.
4. The "Other (no Blizzard category)" row is **dropped**: under "Show beats Hide" it overrode most
   spell-category Hides, and decision 2's "Every aura, once" covers its purpose.
5. Everything else is the orchestrator's call; the decisions below record each one.

## Problem

After the spell-list views fix, a target buff container that hides categories draws only its Blizzard
Show categories on an enemy NPC. Before the fix the 7 broken groups drew every NPC buff (7 times).
The owner wants enemy NPC buffs back in M+, once each, while staying strict on enemy players if they
choose, and wants containers to exist only in chosen zones.

## Design

### S1. A third view: "every"

Each plan now carries three views with one structure: **ids** (the group's own fields), **blizzard**
(today's `noIds`, renamed) and **every**. `group.noIds` becomes `group.views = { blizzard = {...},
every = {...} }`; readers use `(view ~= "ids" and g.views and g.views[view]) or g`.

- **R-3 (no category Hidden):** one group; all three views are the same group (as today for blizzard).
  No remainder slot.
- **R-4 on a container whose `FC.IdsMode` is not "always":** the plan gains one **trailing remainder
  group**. Its ids view and blizzard view are NEVER (`{ includeDispelTypes = {} }`). Its every view is
  the base (aura type, Cast by, max duration, and the base's own excludes as today) **minus every
  Hidden category on the Blizzard Categories, Dispel Types and Who Cast It grids** (via
  `excludeCategory`: negated tokens, flags, `excludeDispelTypes`). In the every view, **every other
  group is NEVER**. So the every view is exactly one live group: every aura passing the base and not
  in a Hidden Blizzard-grid category, once. Spell categories, Uncategorized and the Overrides lists
  do not apply there (Blizzard drops spell ids).
  - Both Who Cast It rows Hidden is a real contradiction: the remainder's every view is NEVER.
  - `durationMode = "timeless"` is built from spell ids, which Blizzard drops: the remainder's every
    view is NEVER there, and the Situations tab says so.
  - The blacklist rides on the base as today; Blizzard drops it on these units (except never-secret
    spells), so the tab says the Overrides lists don't apply there.
- **IdsMode "always" (player and pet buffs):** no remainder slot, no change.

The remainder slot changes `FC.StructureKey` for those containers, so each rebuilds once at the first
apply after upgrading (held out of combat by the existing apply rules). After that no setting on the
Situations tab rebuilds anything.

### S2. Choosing the view at runtime

`ContainerClass:ResolveView()` (it now takes the instance, so it can read the container's settings):

1. `FC.IdsMode` "always" → **ids**.
2. "dynamic" and `NS.Compat.IdsApply(unit, auraType)` → **ids**.
3. Otherwise pick the situation: `player` / `pet` containers use the **players** setting (labelled
   "Your own and your pet's debuffs"); `target` / `focus` use `NS.Compat.IsPlayerUnit(unit)`
   (`UnitIsPlayer`, pcall + CanAccess; documented non-secret) → **players** or **npcs**. An
   unknowable answer uses the stricter of the two settings.
4. The setting (`filter.situations.npcs` / `.players`, `"every"` | `"blizzard"`, default `"every"`)
   gives the view.

It runs where `ApplyView` runs today (Build, Update, target/focus swap, UNIT_FACTION / UNIT_FLAGS for
target, focus and the player, stand-up) and is combat-legal (`SetAuraGroupFilterString` /
`SetAuraGroupCandidateFilters`). A change to either Situations dropdown takes a new **`view` effect**
that runs `CM.ApplyViews` for that container at once, in combat too, instead of the apply hold.
EmptyWatch reads the active view through `inst.view` (`"ids" | "blizzard" | "every"`), never
re-resolving with partial arguments. The `[Filter]` line names the view (`spell lists off, every aura
(NPC)` …), and `/am diagnostics` prints `mode= view= situation=`.

### S3. Zones

`filter.zones = { none = true, party = true, scenario = true, raid = true, pvp = true, arena = true }`
(`IsInInstance()`'s instance types). `NS.Compat.InstanceType()` pcall-wraps it; an unreadable,
nil or unknown type is **allowed** (no checkbox exists to untick it). `ContainerClass:ShouldShow`
becomes `(not p.locked) or previewing or (visibilityAllows(p.visibility) and zoneAllows(cfg))`: an
unlocked or test-mode container still shows anywhere so it can be found, as the General visibility
rule does. Hiding goes through the existing combat-legal path (`ApplyLive` → engine `SetEnabled`),
never the anchor under lockdown. Re-evaluated by `CM.ApplyVisibility()` on `PLAYER_ENTERING_WORLD`
and `ZONE_CHANGED_NEW_AREA` (registered with the lifecycle events and released on stand-down), and
read on the first visibility pass so a `/reload` inside an instance is right from the start.
Zone rows take the existing `visibility` effect. Followers attached to a zone-hidden parent re-seam
as they do for a visibility-hidden one.

### S4. The Situations tab

Last tab of Filters (`G_SIT = L["Situations"]`, rows declared after Sorting's). Two sections:

- **Where spell lists don't apply** — one line saying where that is for this container (the same unit
  wording as the Spell Categories NOTE), then the dropdowns: *On NPCs* and *On players* (target and
  focus containers), or *Your own and your pet's debuffs* (player and pet debuff containers). Each:
  "Every aura, once" / "Only my Blizzard categories set to Show". A short line under them: "Every aura
  still honors Cast by, Max duration and the Blizzard, Dispel and Who Cast It rows you set to Hide;
  spell categories, Uncategorized and Overrides do not apply there." Player and pet **buff**
  containers show "Spell lists always apply to your own and your pet's buffs." and no dropdowns. A
  container in "Without a duration" mode adds: "Every aura draws nothing extra here: 'Without a
  duration' is built from spell lists."
- **Show in** — six checkboxes: Open world, Dungeons, Scenarios and delves, Raids, Battlegrounds,
  Arenas.

The Spell Categories and Overrides NOTE lines gain "(see Situations)". README: Usage paragraph and an
FAQ entry ("Why don't my target's buffs show on enemies?" → Situations), and the zone checkboxes.

### S5. Settings data

`filter.situations` and `filter.zones` in `CONTAINER_TEMPLATE`, so Copy settings from → Filters,
Duplicate, the Filters page's Defaults and profile reset carry them. The schema ladder backfills them
into every existing container (template defaults: "every", all zones on). Existing containers' ids and
blizzard views are byte-identical before and after (proven by a test on the owner's real profile);
their behavior changes only on units where spell lists don't apply, by the owner's opt-out default.

## Accepted costs

- "Every aura, once" cannot honor spell categories, Uncategorized, the Overrides lists or "Without a
  duration" on those units: Blizzard drops spell ids there. The tab says so.
- A container with a Hidden category on a target/focus/player-debuff unit rebuilds once after upgrade.
- A one-frame transient of the previous view on a target swap, as today.

## Testing

- Compiler: the remainder slot (present only for R-4 on non-"always"), its three views, every other
  group NEVER in the every view, Who-both-Hidden and timeless → NEVER; no aura matches two groups in
  any view; R-3 and player-buff plans unchanged; the owner's real profile (every container) has
  byte-identical ids and blizzard views before and after.
- Runtime: ResolveView truth table (always / dynamic-ids / players / npcs / pet / unknowable →
  stricter); the `view` effect applies in combat; EmptyWatch follows `inst.view`; diagnostics line.
- Zones: each instance type, unknown → allowed, unlocked and test mode show anywhere, the two events,
  stand-down release, first pass after a reload, followers.
- Settings: the tab is last; rows per container mode; Copy → Filters carries both tables; defaults.
- Smoke (owner): M+ NPC buffs back once each; a hostile player with Players = "Only Blizzard"; a
  friendly target unchanged; switching a dropdown in combat; each zone checkbox; reload inside a dungeon.
