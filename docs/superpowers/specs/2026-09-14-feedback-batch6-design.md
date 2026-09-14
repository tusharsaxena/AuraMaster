# Feedback batch 6 — design spec

- **Date:** 2026-09-14
- **Branch:** `feat/2026-09-14-feedback-batch6` (AuraMaster); sibling branch of the same name in
  LibKa0s
- **Source:** the owner's in-game feedback of 2026-09-14 (Filters → Categories, Filters → What to
  show, General → Spell Categories, and a tooltip defect on a bars container), plus six decisions
  taken in the brainstorm (section 2)
- **Plan:** `docs/superpowers/plans/2026-09-14-feedback-batch6.md` (checkpointed, resumable)

Every requirement below has an ID (`K-2`, `P-1`, …) that the plan, the commits and the tests cite.

## 1. Goals

1. Make the **Filters → Categories** grid say what it is: the second block is the *Spell Categories*
   the General page edits, each row carrying a link straight to its list.
2. Reduce the grid to **Show / Hide**, drawn as checkbox-shaped cells that keep radio behavior —
   one choice per row, a yellow fill. Categories become a pure exclusion filter.
3. **Surface the filter priority**, in the panel, in the docs, and per spell on the Overrides lists.
4. Move **weapon enchants** out of *What to show* and into the category model, on both pages.
5. Settle the **minimum-duration** request: the engine cannot do it; record the limit and improve
   the maximum instead.
6. Stop a bars container **leaking the world unit's tooltip** through the gaps between its bars.

## 2. Decisions (taken 2026-09-14; do not re-litigate)

| # | Decision |
|---|---|
| D1 | **There is no minimum-duration filter and there will not be one.** Blizzard's candidate filters expose `maxDuration` only, and durations are unreadable while auras are secret. The "greater than" half of the request is dropped, the limit is recorded in `docs/scope.md`, and a GitHub issue is filed. The learned-duration approximation (storing each buff's duration in `modules/TimedSpells.lua`) was considered and declined |
| D2 | **Weapon enchants become a category on both pages.** A `Show / Hide` row on Filters → Categories, and an entry in the General → Spell Categories dropdown that shows enchant options instead of a spell list |
| D3 | **`hidePermanentEnchants` stays per-container.** It moves to a sub-row under the category row on Filters → Categories. Promoting it to the profile would silently change every `ENCHANT`-type container |
| D4 | **The grid cell change ships in LibKa0s, not as an AuraMaster fork.** options-ui-§6 forbids per-panel layout code in a host; a library widget keeps AM conformant with no deviation. LibKa0s is bumped and re-vendored across all ten addons in this effort |
| D5 | **The filter priority is documented and surfaced.** Its ranks are unchanged in spirit; D7 removes one of them |
| D7 | **Categories become Show / Hide, defaulting to Show, and Show means "not excluded".** The three-state model goes: `""` and `"show"` collapse into one state that contributes nothing, and `"hide"` excludes. A container is therefore *every aura of its type minus what its Hidden categories exclude* — always one category group, never one per shown category. **What this costs:** a container can no longer be built as "only Defensives" from this tab; that is done by hiding the other categories, or with the Overrides whitelist. The v3 migration preserves the intent of anyone who used the old Whitelist (section 5, `E-8`) |
| D8 | **"Draw only these" is restored as a per-container toggle** (owner, 2026-09-15, revising the same day's earlier acceptance of the loss). Categories alone still cannot express it — rank 5 draws an aura in no category — so a switch on the Categories tab drops the catch-all group instead. Off by default, so nothing changes for a container that does not ask for it |
| D6 | **The double tooltip is fixed with a container-wide mouse blocker**, gated on the existing `Style.TakesHover(cfg)` rule. It is not reproducible headlessly, so the headless test asserts the blocker's existence and gating, and `docs/smoke-tests.md` carries the in-client confirmation |

## 3. LibKa0s v1.36.0

Four additive changes. No existing caller changes behavior except the ChoiceGrid cell's art.

| ID | Change | File |
|---|---|---|
| `K-1` | `O.ChoiceGrid` cell: stop calling `SetType("radio")`; draw a checkbox whose lit state is a solid yellow fill. The exclusive behavior is unchanged — it lives in `choiceCell`, never in the widget — so a click on the lit cell still re-lights it and writes nothing | `OptionsWidgets.lua` |
| `K-2` | `O.ChoiceGrid` spec gains optional `extraColumn = { header = <string>, cell = function(row) -> { text, onClick, tooltip } or nil }`, drawn after the label column as an `InteractiveLabel`. A `nil` cell draws a blank of the same width. `choiceLabelRel` gives back the column's width | `OptionsWidgets.lua` |
| `K-3` | `O.IdList` entry gains optional `note = <string>`, a short trailing line drawn under the entry's name in the gray the id already uses | `OptionsWidgets.lua` |
| `K-4` | `O.SelectTab(pageKey, tabKey)` sets a rendered panel's `ctx.activeTab` and refreshes it. Returns whether a panel with that page key exists. Public, so hosts stop reaching for the `O.__panelFor` test seam | `Options.lua` |

`NS.OpenOptionsPage(pageKey)` already exists in `settings/OptionsSetup.lua:261`, with the combat
gate options-ui-§2 requires. No page-open API is added to the library.

**Re-vendor:** cut the tag, then roll `libs/LibKa0s/` + `tests/_kit/` and the CLAUDE.md provenance
line into all ten addons, per `/wow-addon:revendor-libka0s`.

## 4. Filters → Categories

| ID | Requirement |
|---|---|
| `F-1` | The `Custom Categories` heading becomes **`Spell Categories`** |
| `F-2` | A line under that heading: these are the lists on General → Spell Categories, shared by every container |
| `F-3` | Each `spells`-kind row carries a **`See spells`** link in the grid's extra column (`K-2`). It calls `NS.GeneralSpells.Select(key)`, then `NS.OpenOptionsPage("general")`, then `H.SelectTab("general", L["Spell Categories"])` (`K-4`). Rows of every other kind leave the cell blank |
| `F-4` | An ordered priority blurb at the top of the tab (section 6) |
| `F-6` | The grid has **two** columns. `C.CATEGORY_STATES` becomes `{ "show", "hide" }` and `C.CATEGORY_STATE_LABELS` becomes `{ show = "Show", hide = "Hide" }`. Every category row's stored default is `"show"`, stamped in `defaults/Profile.lua`'s `CONTAINER_TEMPLATE` rather than left absent, so a row always lights a cell |
| `F-7` | Every row's tooltip is rewritten for two states: *Hide — never drawn in this container. Show — drawn, unless something else hides it.* The old Default/Whitelist/Blacklist wording is removed from `settings/Filters.lua`, `locales/enUS.lua` and the docs |
| `F-5` | The `weaponEnchants` row (section 5) appears in the `Spell Categories` grid — `GRID_BY_KIND` in `settings/Filters.lua` gains `enchant = "custom"` — with `hidePermanentEnchants` as a sub-row beneath it. Its extra-column link goes to its own General → Spell Categories entry (`E-6`), like every other row in that grid |

`NS.GeneralSpells.Select(key)` is a new exported setter over the file's existing `spellCategory`
session upvalue. It accepts any spell-list category key and the enchant key, and is a no-op for
anything else, so a stale link can never leave the tab on a category it cannot draw.

## 5. Weapon enchants as a category

| ID | Requirement |
|---|---|
| `E-1` | New category **kind `enchant`** in `defaults/Categories.lua`: `{ key = "weaponEnchants", kind = "enchant", label = "Weapon enchants", desc = ... }` on `Cat.HELPFUL` |
| `E-2` | `modules/FilterCompiler.lua` reads the row's state instead of `filter.includeEnchants`: `plan.enchants` is set when the state is **not `"hide"`**, the container's `auraType` is `HELPFUL` and its `unit` is `player`. That is the same rule every other category now follows (`D7`) — Show contributes nothing and the enchants are drawn; only Hide takes them away. **This changes the shipped default: enchants are ON for a new player buff container**, where `defaults/Profile.lua:115` had them off |
| `E-3` | `splitCategories` skips kind `enchant`, so the row never reaches `hidden` and never contributes an exclusion to the aura group. `excludeCategory` ignores the kind too, as a second line of defence for any future caller |
| `E-4` | The `Weapon enchants` subgroup is removed from *What to show*. `container.filter.includeEnchants` is removed from the schema; `container.filter.hidePermanentEnchants` keeps its path and moves to the Categories tab (`F-5`), still offered for `HELPFUL` and `ENCHANT` |
| `E-5` | **Schema v3 migration** in `core/Database.lua`, written to PRESERVE what each existing container draws today: `filter.includeEnchants == false` (or absent, which is the template's `false`) → `filter.categories.weaponEnchants = "hide"`; `== true` → `"show"`. The old key is then cleared. Since the template stamped `false`, most existing containers migrate to an explicit `Hide` — truthful about what they draw, and one click from the new default. `ENCHANT`-type containers are untouched; they never read the flag |
| `E-6` | General → Spell Categories offers `Weapon enchants` in its dropdown. In its place it draws: the three weapon slots as toggles (new profile-wide `enchantSlots`, all on by default), and a line saying the per-container options live on Filters → Categories, with a link back |
| `E-8` | **The same v3 migration preserves old Whitelist intent.** For each container, if any category of its aura type was stored `"show"` under the old three-state model, every category of that aura type NOT stored `"show"` becomes `"hide"`, and the `"show"` rows stay `"show"`. A container that drew only Defensives keeps drawing only Defensives. Where no category was `"show"`, every `""` simply becomes `"show"`. This runs BEFORE `E-5`, so the enchant row is written against an already-normalized table |
| `E-7` | `enchantBlock` in the compiler builds its `slots` list from `profile.enchantSlots` rather than the hardcoded triple, defaulting to all three when the profile has none |

`defaults/Profile.lua` gains `enchantSlots = { mainHand = true, offHand = true, ranged = true }`
at profile scope, drops `includeEnchants` from `CONTAINER_TEMPLATE` (line 115), and drops the
shipped `Player buffs` container's `includeEnchants = true` (line 201) — the new Show default covers it.
It also stamps every category row at `"show"` in `CONTAINER_TEMPLATE` (`F-6`).

## 6. Filter priority (revised by the owner, 2026-09-15)

**This supersedes the order the batch was started with.** Two things changed: the Overrides
whitelist now beats the blacklist, and a category's Show is a positive claim on an aura rather than
merely the absence of a Hide.

| Rank | Rule | Outcome |
|---|---|---|
| 1 | On the Overrides **whitelist** | **Shown.** Always, whatever anything else says |
| 2 | On the Overrides **blacklist** | **Hidden**, unless rank 1 already claimed it |
| 3 | In **at least one** category set to Show | **Shown**, even if it is also in a category set to Hide |
| 4 | In one or more categories, **all** of them set to Hide | **Hidden** |
| 5 | In **no** category at all | **Shown** — nothing removed it (owner, 2026-09-15) |

Stated as one sentence: an aura is hidden when the blacklist names it, or when every category it
belongs to says Hide; everything else is drawn, and the whitelist overrides both.

Rank 3 is the substantive change. Under the superseded order a single Hide removed an aura even if
another category showed it — so a Defensive that was also Cancelable vanished from a container that
wanted defensives. Now a Show anywhere rescues it.

### 6b. How that compiles

The engine ANDs the constraints inside one group and ORs the groups, so "in ANY shown category"
is a union and therefore needs a group per shown category — the machinery `C-2` deleted, brought
back and extended with a catch-all.

| ID | Requirement |
|---|---|
| `R-1` | The **whitelist group** is emitted first: the aura type and those ids alone. The blacklist is NOT applied to it (rank 1 beats rank 2) |
| `R-2` | `applyLists` inverts: whitelisted ids are removed from the **blacklist**, not the other way round. The Overrides blurb stops saying "a spell on both lists is hidden" and says the whitelist wins |
| `R-3` | **When no category is set to Hide**, exactly one category group is emitted: the base, minus the whitelist. A shown category cannot rescue anything when nothing is hiding, so the extra groups would be pure cost. This keeps a default container at one group |
| `R-4` | **When at least one category is Hidden**, one group per SHOWN category is emitted — the base plus that category's positive constraint, minus every earlier shown category and minus the whitelist, so no aura is drawn twice — followed by the catch-all |
| `R-5` | The **catch-all group** is last: the base, minus every hidden category, minus every shown category, minus the whitelist. It is what draws an aura belonging to no category (rank 5) |
| `R-6` | `excludeCategory` regains a positive sibling for `R-4`. Kind `enchant` takes part in neither — it matches no aura |
| `R-7` | The blacklist applies to the base, so it reaches the shown groups and the catch-all but never the whitelist group |

Consequence for `E-8`: once this lands, **the v3 migration's whitelist-id copying is no longer
needed and is reverted.** It existed only to stop a Hide from removing an aura that a Show also
claimed — which is now rank 3's job, done properly and for every category kind rather than only
for `spells`-kind ids.

### 6c. "Only these categories" (`D8`)

Rank 5 is what makes "draw only these" impossible: an aura in no category is drawn because nothing
removed it. The toggle turns rank 5 off for one container.

| ID | Requirement |
|---|---|
| `R-8` | New per-container `container.filter.onlyShown`, a bool defaulting to **false**. A schema row in the Categories group carrying `skipRender` — task B5 draws it at the top of the tab, above the grids |
| `R-9` | When it is **on**, the catch-all group (`R-5`) is not emitted. The groups are then the whitelist group plus one per shown category, so an aura is drawn only if the whitelist names it or at least one of its categories says Show. `R-3`'s single-group optimization does NOT apply while it is on: the shown groups ARE the container, whether or not anything is hidden |
| `R-10` | While it is on, **Hide means "not shown" rather than "removed"** — an aura reaches rank 4 only by failing rank 3, and rank 3 is now the only way in. The Hide cells stay live and clickable, because Hide is the only way to un-Show a row; the tab's blurb says what the two states mean under each setting. Do NOT dim the Hide column |
| `R-11` | On, with no category set to Show and nothing on the whitelist, a container draws nothing. That is a legitimate configuration to arrive at by accident, so it carries its own warning — `FC.WARN.ONLY_SHOWN_NONE`, "Only the categories set to Show are drawn, and no category is set to Show." — in place of the generic `NEVER_MATCHES` |

`ExplainSpell` follows: with `onlyShown` on, an aura that reaches rank 5 is reported `hidden`, not
`shown`, and the note says the container draws only its shown categories.

The toggle is deliberately per-container and not profile-wide: one container showing a curated set
while another shows everything is the normal case.

### 6a. The compiler simplification (`D7`)

| ID | Requirement |
|---|---|
| `C-1` | `splitCategories` returns `hidden` alone. A row's state is `hide` or it contributes nothing |
| `C-2` | `addCategoryGroups` always adds exactly **one** group: the base, minus every hidden category, minus the Overrides whitelist. The per-shown-category loop, and with it the "an aura matching two shown categories appears once, under the first" rule, is deleted |
| `C-3` | `applyCategory`'s positive path is deleted; what is left is renamed `excludeCategory(con, def, spellEdits)`. `setFlag`'s `soft` parameter goes with it — every remaining call is a negation, so the parameter is dead |
| `C-4` | A group `label` is no longer a category name. The single group is labelled `"All"`, as the no-category case already was |
| `C-5` | The `maxAuras` row's description stops saying "for each shown category" — there is one group, so the cap is the container's |
| `C-6` | An empty `spells`-kind category set to Hide still contributes no exclusion (today's `isEmpty` guard). The `conflict` path for an empty SHOWN category is deleted with the shown path |

## 7. Max duration

| ID | Requirement |
|---|---|
| `D-1` | `container.filter.maxDuration` keeps its path, range and step. Its label becomes `Max duration`; its description states plainly that it is an upper bound and that no lower bound exists |
| `D-2` | A preset dropdown beside it — `30s · 1m · 5m · 10m · 30m · No limit` — writing the same path through the seam. A stored value matching no preset leaves the dropdown showing nothing rather than snapping the slider |
| `D-3` | `docs/scope.md` → *Out of reach on this client (12.1)* gains a **minimum duration** entry beside the existing no-duration one |
| `D-4` | A GitHub issue records the request and the engine limit, labelled `state:will-not-do` + `severity:low` |

## 8. The double tooltip

Today only the engine's aura buttons hold the mouse (`Style.ApplyBehavior` →
`SetMouseMotionEnabled`). The gaps between bars and the container's own padding hold nothing, so
the world unit behind is moused over there and its `GameTooltip` is drawn beside the aura's
`AuraButtonTooltip`, which is still up from the button the cursor just left.

| ID | Requirement |
|---|---|
| `T-1` | `modules/Container.lua` gives each container a **blocker** frame: a child of the container's own frame, `SetAllPoints`, at a frame level below the engine's buttons, with no art |
| `T-2` | Its `SetMouseMotionEnabled` follows `Style.TakesHover(cfg)` — the same rule the live buttons and the preview placeholders already use — so a click-through or tooltips-off container is unaffected. It never takes clicks: `SetMouseClickEnabled(false)`, so right-click cancel and anything behind a click-through container keep working |
| `T-3` | The blocker is re-gated whenever the container's behavior block is re-applied, and released with the container |
| `T-4` | `tests/test_container.lua` asserts the blocker exists, covers the container, and follows `TakesHover` across `clickThrough` and `tooltips` |
| `T-5` | `docs/smoke-tests.md` gains a step: stand over a world unit with a bars container across it, hover a bar and then a gap between two bars, and confirm only Aura Master's tooltip is drawn |

## 9. Tests

Failing-first for each. Additions, by suite:

| Suite | Covers |
|---|---|
| `test_filtercompiler.lua` | `C-1`…`C-6` (one group always; a hidden category excludes; no shown-category groups remain), `E-2`, `E-3`, `E-7` (enchant kind and slots), `P-3` (every rank, and a spell claimed by two categories) |
| `test_database.lua` | `E-8` (a container with an old `"show"` row keeps its narrowing; one with none gets all-`"show"`), then `E-5` (enchant row, both directions and the absent case; an `ENCHANT` container untouched) |
| `test_pages_filters.lua` | `F-1`…`F-7`, `P-1`, `P-4`, `D-1`, `D-2` |
| `test_pages_general.lua` | `E-6`, `NS.GeneralSpells.Select` |
| `test_container.lua` | `T-1`…`T-4` |
| `test_schema_paths.lua` | `includeEnchants` gone, `enchantSlots` present, every category row stamped `"show"` |
| `test_locale.lua`, `test_docs.lua` | every new string routed through `NS.L`; the docs above updated |

Green gate at every step: `lua tests/run.lua` and `luacheck .` (0/0).

## 10. Documented deviations

None expected. `D4` keeps the grid widget in the library precisely so options-ui-§6 is not
deviated from. If the enchant category kind turns out to need host-side layout the library cannot
express, that is a deviation and stops for a decision rather than being written silently.

## 11. Out of scope

- Reading aura durations, and therefore any minimum-duration filter (`D1`).
- Changing what the filter compiler decides (`D5`) — only what it says.
- Promoting `hidePermanentEnchants` to the profile (`D3`).
- Party units and the Text style, which remain issues #1 and #2.
