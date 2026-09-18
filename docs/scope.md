# Scope

What Ka0s Aura Master is for, and — the load-bearing half — what it deliberately does not do. A
feature request is answered here first: in scope, out of scope, or out of reach of any addon on this
client. The player-facing contract is the README; the engineering boundary is this page.

## What it does

- **Player-built aura containers.** Any number per profile, each with its own name, enable switch,
  filters, placement and look (`defaults/Profile.lua:112`, `NS.CONTAINER_TEMPLATE`).
- **Four units:** `player`, `target`, `focus`, `pet` (`core/Constants.lua:39`).
- **Three aura types:** buffs (`HELPFUL`), debuffs (`HARMFUL`) and the player's temporary weapon
  enchants (`ENCHANT`, drawn through the engine's `AddItemEnchantment`). A player-buff container also
  appends the weapon enchants after its buffs, unless the `weaponEnchants` category
  (`container.filter.categories.weaponEnchants`) is set to Hide.
- **Two styles:** bars (icon, fill, spark, name, time and stack text) and icons (border, dispel
  border, cooldown swipe, time and stack text).
- **Filters declared up front and evaluated by the game:** who cast it (anyone / me and my pet /
  anyone but me), timed-only or permanent-only, a maximum full duration (no minimum — *Out of reach*
  below), 34 categories set to Show or Hide, schema v4 (defined in `defaults/Categories.lua`: spell
  lists, Blizzard aura flags and filter tokens, dispel types, player-or-creature source, and the
  weapon-enchant capability), a per-container Overrides whitelist and blacklist of spells (the
  whitelist always wins, `docs/ARCHITECTURE.md` → Filter priority), the spell categories' lists
  (editable, and shared by every container in the profile), sort method and direction, and a
  per-group cap.
- **Placement:** attached to the screen (draggable), to another container (follows it as it grows),
  or to any named frame, with a click-to-pick frame selector (`modules/FramePicker.lua`).
- **Test mode:** placeholder auras drawn through the same `Style` code, switched by the Master
  controls *Test mode* checkbox, `/am test` or the minimap button's left click; session-only and
  ended when combat starts. Unlocking only makes containers draggable, and live auras keep drawing.
- **Hiding Blizzard's buff and debuff frames**, by reparenting them out of combat.
- **Profiles** through AceDB, with a Profiles sub-page.
- **A full CLI** — every schema row is reachable through `/am get|set|reset`, and the registry through
  `/am containers|select|new|delete`.
- **Retail only**, Interface 120100 (Midnight 12.1), English as the source locale.

## What it deliberately does not do

### Deferred — tracked as GitHub issues

- **Party units 1–5.** The engine can take any unit token; the settings model, the unit dropdown and
  the swap events have not been widened yet. Tracked as a GitHub issue.
- **A "Text" container style** — aura names and times as lines of text with no bar or icon. Tracked
  as a GitHub issue.

### Out of scope by decision

- **Raid, arena, boss and nameplate units.** Containers are for a handful of units the player
  watches, not a unit-frame replacement.
- **Trigger logic, custom code or conditions.** No user-supplied Lua, no "show when X and Y", no
  sounds, glows or per-spell colors. That is an aura framework, not a display addon.
- **Cooldown tracking.** Spell cooldowns are not auras.
- **A live LDB data feed.** The addon ships a broker object and a minimap button (launcher-§1,
  `core/LauncherSetup.lua`), but it is a `type = "launcher"` — something to click, not a value a
  display watches. There is no count, timer or status text to feed one.
- **Profile import/export strings.** AceDB profiles persist in `AuraMasterDB`; there is no
  serialization layer.
- **Hiding Blizzard frames during combat.** Reparenting a Blizzard frame under lockdown is refused, so
  the switch applies on the next `PLAYER_REGEN_ENABLED`.

### Out of reach on this client (12.1)

These are not declined; the game forbids them, and a request for one is answered with the rule.

- **Reading an aura in combat.** Aura data is secret during combat, encounters, Mythic+ and PvP, and
  aura buttons refuse addon access while it is (`core/Secrets.lua`). Everything the addon filters on
  has to be a declaration the engine evaluates.
- **A native "no duration" filter.** The engine can require a duration (`maxDuration`) but cannot
  require its absence. "Only auras without a duration" is built by learning which buff spells are
  timed while auras are readable (`modules/TimedSpells.lua`), so a timed buff not yet learned shows
  once. On a debuff container the mode narrows nothing, because only buffs are learned.
- **A minimum duration.** The engine's candidate filters cap a duration (`maxDuration`) but cannot
  require one to be at least N seconds, and an aura's duration is unreadable while auras are secret,
  so it cannot be filtered after the fact either. Requested 2026-09-14; declined with the rule.
- **Spell-id filtering everywhere.** The engine honors include/exclude spell ids only for buffs on
  friendly units and debuffs on hostile units. The addon warns per container
  (`identityWarning`, `modules/FilterCompiler.lua:558`) rather than letting the filter look broken.
- **Restyling a button mid-combat.** Size, font and color changes wait until secrecy lifts
  (`CM.MustDefer`, `modules/ContainerManager.lua:161`).
- **Fake auras inside the engine.** The engine only shows real auras, so preview elements are the
  addon's own frames.

## Resolved decisions

- **The engine owns every aura container.** A hand-built aura display cannot see auras in combat on
  12.1, and `SecureAuraHeaderTemplate` is gone from Retail; `CustomAuraContainerTemplate` is the one
  supported path.
- **A permanent aura draws a full bar.** The engine's status bar runs on elapsed time and the
  addon's own fill is anchored to its moving edge (`modules/Style_Bars.lua`), the technique
  TinyBuffBars (MIT) established.
- **Class colors follow the container's unit.** A container tracking the target, focus or pet paints
  its class colors with that unit's class, read once per apply and used by every button of the
  container, so one container never mixes two classes. A swap of that unit re-applies the container
  when it uses a class color. Under combat lockdown or aura secrecy the re-apply waits for the
  restriction to lift, and the container keeps the previous unit's class until then
  (options-ui-§17; audit 2026-09-11 AM-03).
- **Container settings share one relative path model** (`container.…`) so one schema, one write seam
  and one CLI serve every container (`settings/Schema.lua` header).
- **Categories have two states** (schema v3, owner's 2026-09-15 revision), labeled Show and Hide and
  stored `"show"` / `"hide"`; Show is the default and is a *positive claim*, not merely "not
  excluded" — an aura in even one Show category is drawn even if another of its categories says Hide,
  and only an aura whose every category says Hide is removed by them (`docs/ARCHITECTURE.md` →
  Filter priority). **The real limitation this costs:** Categories alone can no longer build "only
  Defensives" the way the old exclusive Whitelist did — hiding every other category is not the same
  thing, because an aura in no category at all still shows (nothing removed it). Getting that back
  needs either the Overrides whitelist, or the **Uncategorized** category set to Hide (batch 7,
  `U-1`..`U-5`; the retired per-container "only these categories" toggle meant exactly this and is
  gone, fix round 2 of that effort) — `uncategorized` on a buff container, `uncategorizedDebuffs` on a
  debuff one, both on the Categories tab's Spell Categories grid.
- **Reset all settings is a profile reset** (options-ui-§12): every container goes with the profile,
  and the starter containers come back.
