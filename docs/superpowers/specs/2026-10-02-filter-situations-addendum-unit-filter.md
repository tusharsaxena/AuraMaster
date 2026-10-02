# Filter situations, addendum: unit type and reaction

- **Date:** 2026-10-02
- **Extends:** `2026-10-02-filter-situations-design.md` (binding; this file adds S6 and the SI-08..SI-10
  record).
- **Owner requests (2026-10-02):** (1) rename "Castable by you" to "Castable/Dispellable by you" and quote
  Blizzard's definition in its tooltip (SI-08); (2) a "Unit type" section on the Situations tab with two
  dropdowns, unit type (All, NPC, Players) and reaction (All, Friendly, Hostile, Neutral) (SI-10).
- **Also recorded:** SI-09, a refused view setter leaves the view stale and resent in full, and
  diagnostics print the active view (found while checking the owner's Bloodsurge report).

## S6. Unit type and reaction

A third section on the Situations tab, **Unit type**, with two dropdowns:

- **Unit type:** All (default), NPCs, Players. Read with `NS.Compat.IsPlayerUnit` (`UnitIsPlayer`).
- **Reaction:** All (default), Friendly, Neutral, Hostile. Read with `UnitReaction(unit, "player")`
  through a new `NS.Compat.UnitReactionKind(unit)`: 5 or above is friendly, 4 neutral, 3 or below
  hostile (player-vs-player reactions use the same bands). pcall plus `NS.Secrets.CanAccess`; nil when
  not knowable. Blizzard's API documentation flags neither return as secret.

Stored as `filter.unitFilter = { kind = "all" | "npc" | "player", reaction = "all" | "friendly" |
"neutral" | "hostile" }` in `CONTAINER_TEMPLATE` (so Copy settings from → Filters, Duplicate and the
Filters page's Defaults carry it), backfilled into existing containers as All / All.

**Where it applies:** target and focus containers. On player and pet containers the section shows
"Always your own character or pet." and no dropdowns, and the setting is ignored.

**What it does:** a container whose current unit does not match both choices shows nothing. It joins the
show ladder beside the zone rule: `ContainerClass:ShouldShow` is `(not p.locked) or previewing or
(visibilityAllows and zoneAllows and unitAllows)`, so an unlocked or test-mode container still shows,
and hiding goes through the existing combat-legal `ApplyLive` → engine `SetEnabled` path. An unknowable
answer, or no unit, allows (the container then simply has nothing to draw). Re-evaluated on a target or
focus swap, on `UNIT_FACTION` / `UNIT_FLAGS` for target and focus and the player (the view frames
already registered), and on the rows' own writes (`visibility` effect). The visibility pass that already
runs on these events must cover it; no new event is registered.

**Interplay:** independent of the spell-list view (S2). A container limited to Hostile NPCs still uses
"Every aura, once" or "Only Blizzard" on them per its NPC setting.

## Testing

Compat reads (each band, secret and raising reads → nil); the gate truth table (kind × reaction ×
unknowable × unlocked / test mode); swap and reaction-change re-evaluation in combat; player and pet
containers ignore it and show the note; Copy → Filters carries it; defaults All / All and the backfill;
the tab shows the section with two dropdowns after Show in; docs, README and smoke checks.
