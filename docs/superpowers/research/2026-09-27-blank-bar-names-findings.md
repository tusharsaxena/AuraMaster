# Blank bar names: findings (2026-09-27)

- **Reported by:** the owner, 2026-09-26 and 2026-09-27.
- **Spec:** `docs/superpowers/specs/2026-09-27-blank-bar-names-design.md`
- **Plan:** `docs/superpowers/plans/2026-09-27-blank-bar-names.md`
- **Blizzard source:** Gethe/wow-ui-source, branch `live`, fetched raw on 2026-09-27. Paths are
  relative to `Interface/AddOns/Blizzard_AuraContainer/`. Line numbers are those of the fetched copy.

## The symptom

A bar shows its icon, its fill and its time, and no spell name. It happens the first time an aura is
seen in a session and never on the second. `/reload` clears it. It showed most often on characters
the owner had not played recently, and on the first pull of a Mythic+ key.

## How the cause was isolated (owner's in-client runs)

| Run | What it showed |
|---|---|
| `/am diagnostics` with blank bars | The cached time-text width was 31 px on 240 px bars, so the time box could not have squeezed the name out. The `nameW` / `timeW` / `barW` fields added in cee5bb6 read `?` on every live bar: the client withholds the geometry of engine-bound regions. |
| Screenshots of blank bars | Only the name was missing. The time, drawn in the same font at the same size and outline, showed. This rules out the font. The same aura showed its name in one container and none in another at the same moment. |
| `C_Spell.IsSpellDataCached` before a first cast | Returned true for every spell tried, on characters not played in a year, in sessions that did not reproduce the bug. It was not checked in a session that did. |
| A `SPELL_DATA_LOAD_RESULT` listener | Printed nothing. The event answers explicit load requests only. |
| `_retail_\Cache` renamed away, then a fresh login | The bug reproduced on almost every aura. The new cache held a `Spell<pid>.tmp` file of spell records streamed that session. |
| Login with the cleared cache | Every aura present at login showed a blank bar, and those bars stayed blank through combat. Auras gained later mostly showed names. |
| Bar height changed 16 → 17 on one container, no `/reload` | That container's names appeared. An untouched container on the same screen stayed blank. |

## The mechanism (Blizzard source)

1. The button writes the name from the aura payload and nothing else. `AuraContainerUtil.SetSpellNameForAura`
   (`Blizzard_AuraContainerUtil.lua:241-260`) takes `auraData.name`, and writes `""` when it is nil.
   It has an asynchronous retry for an item enchant (`ContinueWithCancelOnItemLoad`, the same function),
   but none for a spell.
2. The name is written on every assign and every update of that aura instance:
   `ApplyAuraInstance` calls `ApplySpellName` unconditionally (`Blizzard_CustomAuraButton.lua:580-591`),
   from `OnAuraInstanceAssigned` and `OnAuraInstanceUpdated` (`:321-327`). An aura that never updates
   again keeps the name it was assigned with. A permanent buff present at login is the worst case.
3. Every `Set*` binding ends with `UpdateAuraDisplay`, which reruns `ApplyAuraInstance` in Update mode
   with the button's stored `auraData` (`:594-597`). A re-dress repaints, which is what the owner's
   bar-height change did.
4. `UpdateAllAuras` marks a full rebuild (`Blizzard_ManagedAuraContainer.lua:45-57`):
   `FullAuraRebuild` = ParseAuras + ResetAuraFrames + RebuildLayoutGroups (`:26`). The parse fetches
   fresh aura data, so a name that has since streamed in is written. While the container is disabled,
   the same call clears its auras (`:504-507`), so a repaint must skip a disabled engine.

## How peer addons behave (installed copies, read 2026-09-27)

- **SetisBuffBars** binds `SetSpellName` the same way (`Core.lua:2065`). On every player `UNIT_AURA`
  it waits 0.05 s and calls `UpdateAllAuras` on both of its containers, with no combat guard
  (`QueueAuraOrderRefresh`, `Core.lua:3379-3398`). It does this to keep its sort order right, and
  as a side effect a blank name is rewritten within moments. Its changelog (0.3.14-0.3.16) records blank names after a
  font change, fixed by re-binding and a two-pass `UpdateAllAuras`.
- **ElkBuffBars v3** binds `SetSpellName` once (`v3/EbbAuraButton.lua:267`) and calls `UpdateAllAuras`
  only when settings change (`v3/EbbAuraContainer.lua:172`). It is exposed to the same bug.
- **EllesmereUI** aura bars bind only the icon, the cooldown, the stack count and the time
  (`EllesmereUI_AuraKit.lua:1152-1162`). It never shows an engine-written name, so it cannot hit this.

## What AuraMaster did before the fix

`UpdateAllAuras` was already sent in combat on target, focus and pet changes
(`ContainerManager.RefreshUnit` → `ContainerClass:Refresh`). That swap rebuild is itself a first
sighting of the new unit's auras, so it can write a blank that nothing repaints afterwards. The
engine's own `SetEnabled` also runs `UpdateAllAuras` when its enabled state flips
(`Blizzard_AuraContainer.lua:28-33`), and `ApplyLive` flips it on visibility changes, lock changes
and test mode. Those flips repaint by accident. With visibility `always` and no toggle, nothing
repainted a player container, which is why the owner's own buffs stayed blank until `/reload`.
Smoke checks must avoid those toggles, or they will hide the bug.

## Refuted hypotheses

- The time-text box squeezes the name (cee5bb6): the cached width is normal.
- The custom font is not ready: the time draws in the same font.
- A spell-load event the addon could wait for: `SPELL_DATA_LOAD_RESULT` did not fire. Why
  `auraData.name` is nil on a first sighting is not proven beyond the cache-clear correlation. The fix
  does not depend on the reason: it rereads the aura data later.
