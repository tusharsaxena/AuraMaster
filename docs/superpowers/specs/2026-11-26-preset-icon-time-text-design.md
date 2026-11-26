# Preset icon rows without time text: design

**Date:** 2026-11-26. **Branch:** `feat/2026-11-26-preset-icon-time-text`. **Plan:**
`docs/superpowers/plans/2026-11-26-preset-icon-time-text.md`.

## 1. The request

The owner, verbatim: "AuraMaster presets - [screenshot: the far stack's two icon rows '[18] Target buffs
(all)' and '[17] Target debuffs (all)' with tiny icons whose timer text is truncated to '1...'] - the
ones that use these type of containers, hide the timer text from those icon containers - [screenshot:
the icon container's settings, Time text tab, 'Show' checkbox]".

At 24 px an icon has no room for its time text, which the icon style draws under the icon, so it
reads "1..." and says nothing. The swipe already shows the time left.

## 2. What is stored

The Icon style page's **Time text** tab leads with **Show** (`settings/Icons.lua`, `textRows("time",
G_TIME, ...)`), stored at `container.icons.time.show`. The container template has it on
(`defaults/Profile.lua`, `icons.time = text(true, 11, "BOTTOM", 0, -12, "CENTER")`). A preset container is
the template with the builder's overrides deep-merged over it (`Database.NewContainerData`), so every
icon container a preset made before this change stores `icons.time.show = true`, written out in full;
`Database.PrepareProfile`'s backfill puts `true` back wherever the key is missing.

## 3. The calls

1. **The builder is the single source.** Every icon container any preset creates is built by
   `defaults/Presets.lua`'s `P.Build`, and every one of them passes `sizeTo`'s icon branch, which writes
   its `icons` section (`{ width, height }`). That branch now writes `time = { show = false }` too. It
   covers both kinds of icon container a preset makes: the far stack's icon roles (`ticoD` [17] Target
   debuffs (all), `ticoB` [18] Target buffs (all), Advanced, either look) and every bars role the
   **Icons** look turns into an icon row (`toIcons`). The owner's "the ones that use these type of
   containers" is read as every preset icon container: an Icons-look row is the same kind of container
   on the same 24 px scale, and the swipe is its time read-out as well. `sizeTo` and `toIcons` are
   preset-only (local to `defaults/Presets.lua`), so the template, and with it a container the player
   creates by hand, keeps Show on.
2. **Schema v25** (`Database.HidePresetIconTime`, `core/Database_PresetRestack.lua`, one new ladder step
   in `core/Database.lua`) hides the time text on an existing container a preset made, over every stored
   profile. Nothing records which preset made a container (as for v23 and v24), so a container is a
   preset's by its **shape and name**: `style == "icons"` and a name some builder wrote, `[NN] <role
   name>` with `NN` a number that builder gave that role (the current builder's, the v22 builder's and
   the first numbered builder's, 2026-11-15 to the 2026-11-17 rebuild, when Advanced's target stack
   ran tdeb 10 .. tspec 16; all frozen in the file; that first builder wrote one digit below 10 until
   3edb6ac, which the step reads as two), optionally followed by the ` (N)` suffix `ContainerManager.Create` gives a
   name already in use (an `add` apply over containers of the same names). The role names are read
   through `L`, as the builder writes them.
3. **"Never changed" is decided by the stored value alone.** The preset wrote `true` (the template's),
   so a container whose `icons.time.show` is `true`, or missing (the backfill would make it `true`), is
   untouched and goes to `false`. One already `false` is left as it is and not counted. A player who
   turned Show off and on again also stores `true` and cannot be told apart: that container goes off
   too. This is the same limit v17 and v22 state for their companions, and it is recorded in the
   schema doc's v25 entry. A preset bars row the player switched to Icons on the Style row also stores
   the template's `true` and goes off, where the same switch on this build keeps Show on (`sizeTo`
   writes no `icons` section for a bars row): accepted (review PIT-REV), since it is a small
   preset-named icon row, the case the owner asked about. A container whose `icons` or `icons.time` is not a table is skipped.
4. **What stays.** A bars or text container of any name, an icon container whose name no preset
   builder wrote (renamed, or made by hand), and every other field of a matched container. The step
   writes one field and logs one `[Migrate] v25 profile '<name>'` line for a profile it changed.
5. **A new step, not an extended one.** v23 and v24 were pushed with the 2026-11-24 merge, and a step
   already pushed is never extended (schema.md, migration lesson F7), so this is v25.
6. **Not own-colors.** The change touches no color and no skin companion; `Database.OWN_COLORS` and
   the v22 rule are unaffected.

## 4. Tests (written first)

`tests/test_preset_icon_time.lua`:

- every icon container every preset builds, in both looks, on 1920 x 1080 and the owner's parent,
  states `icons.time.show = false`, and every bars and text container states no `icons` section;
- applying Advanced in Bars stores [17] and [18] with Show off; a container created by hand with
  style icons keeps the template's Show on;
- v25 over a profile the old builder wrote (the current builder's output with Show put back on, in
  both looks, every preset): every icon container goes off, every other container is unchanged;
- v25 over the v22 numbering (the v22 fixture's names, as icon rows): matched;
- v25 over the first numbered builder's names (3edb6ac's tiers, in the one- and two-digit forms):
  matched, and a one-digit number no builder gave that role is not;
- v25 leaves alone a bars container with a preset name, a hand-made icon container, a renamed preset
  icon container and an explicit `false`; it matches a ` (2)` copy and a missing key;
- v25 is idempotent: a second run changes nothing; the ladder climbs to v25 once.

## 5. Docs

README's Presets paragraph (the icon rows draw no time text), `docs/schema.md` (the Schema v25 entry),
`docs/ARCHITECTURE.md` (the presets paragraph's step list), `docs/smoke-tests.md` (two new checks,
written unrun), `docs/test-cases.md` (the new suite and the totals). `docs/settings-panel.md` describes
the Time text tab's rows, not their defaults, so it is unchanged.
