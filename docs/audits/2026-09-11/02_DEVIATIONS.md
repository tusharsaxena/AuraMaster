# 02 — Deviations: Ka0s Aura Master (2026-09-11)

Audited against **Ka0s WoW Addon Standard v2.42.0 (2026-09-10)**. Deviation-ID prefix: **`AM-`**. This
is the repo's first audit, so every ID is new.

**Grading basis.** Grades follow `AUDIT.md` step 5: impact, not rule strength. A doc-only or
config-only failure is Low even where it fails a MUST, and each entry still names that MUST.

## Tally

The **headline tally counts roots only**. Dependents shaped `derived from <ID>` are listed under their
root and excluded from the headline and from the MUST count.

| | High | Medium | Low | Info | Total |
|---|---|---|---|---|---|
| **Headline — roots only** | 0 | 3 | 14 | 0 | **17** |
| Total including dependents | 0 | 3 | 17 | 0 | **20** |

| MUST failures | High | Medium | Low | Total |
|---|---|---|---|---|
| **Roots only** | 0 | 3 | 10 | **13** |
| Including dependents | 0 | 3 | 12 | **15** |

The remaining four roots fail a SHOULD: AM-13, AM-15, AM-16 and AM-20. Dependent AM-14 fails a
SHOULD NOT.

**Recorded deviations** (register rows) accepted this run: **none**, because the register is empty
(`docs/ARCHITECTURE.md:257`). **Register rows owed:** AM-03 and AM-04 are reasoned declines with no
row. Each can close either by changing code or by filing the row.

**Verdict: minor deviations.** No High. The three Mediums are user-reachable combat or display edges.
The rest are latent, convention or documentation gaps.

---

## Roots and dependents

### AM-01 — `events-frames-taint-§2` — **Medium** — MUST

A pending frame anchor that is skipped during combat is never replayed. `Anchors.ResolvePending`
returns early under `InCombatLockdown()` (`modules/Anchors.lua:102`). Nothing re-runs it on
`PLAYER_REGEN_ENABLED`: `OnCombatChanged` flushes applies and Blizzard frames, but not pending anchors
(`core/AuraMaster.lua:69-75`).

Suppose a container is attached to a named frame that is created by an addon loading **during
combat**. That container stays at its screen fallback after combat ends, until another `ADDON_LOADED`
or an unrelated apply re-places it.

**Fix direction:** replay `Anchors.ResolvePending()` from the `PLAYER_REGEN_ENABLED` branch, and pin
it with a case.

### AM-02 — `events-frames-taint-§2` (also `options-ui-§2` SHOULD) — **Medium** — MUST

Deleting a container, or switching profile, during combat hides and destroys engine frames at once.
The paths:

- `/am delete` (`settings/Slash.lua:164-172`) and the Containers page's Delete
  (`settings/Containers.lua:90-91`) call `CM.Delete`, then `CM.Announce`, then `CM.Sync`, then
  `inst:Destroy()` (`modules/ContainerManager.lua:199-215,60-64,45-57`).
- `Destroy` calls `Retire`, which runs `engine:Hide()`, and then `anchor:Hide()`
  (`modules/Container.lua:120-130,329-335`).
- A profile switch reaches the same `Announce` path (`core/AuraMaster.lua:106-114`).

None of these paths consults `CM.MustDefer` (`modules/ContainerManager.lua:86-88`). They contradict
the addon's own rule that an aura button's ancestry "must not be shown or hidden" on a combat
transition (`modules/Container.lua:303-305`). `/am pick` shows the missing guard's shape
(`settings/Slash.lua:192`).

This was not verified in a live client. The risk is a blocked action or taint on an uncommon but
reachable path.

**Fix direction:** under lockdown, disable the engine via `SetEnabled(false)`, which is combat-legal,
and queue the destroy for `FlushPending`. Refuse `/am delete` and the page Delete in combat with a gray
line.

### AM-03 — `options-ui-§17` — **Medium** — MUST

Unit-scoped containers resolve *Use class color* to the player's class. Every styled surface calls
`NS.ResolveColor(stored, useClass, "player")` (`modules/Style.lua:40-41`). Every composed color row
declares `classColor = { source = "player" }` (`settings/Bars.lua:21`, `settings/Icons.lua:18`), which
the composer stamps as `classColorSource`.

So a `target`, `focus` or `pet` container paints the **player's** class. §17 says a per-unit surface
takes the tracked unit's class.

The addon reasons the choice in `docs/ARCHITECTURE.md:205-206` and `docs/scope.md:81-82`: restyling is
forbidden while auras are secret, so a unit class color would go stale on a target swap. There is
**no register row**, so the decision is not ratified.

**Fix direction:** either file the row (`options-ui-§17`, with a re-check trigger such as "the engine
permits restyling while auras are secret"), or declare `"unit"` for non-player containers and
re-resolve on unit swap once secrecy lifts.

### AM-04 — `events-frames-taint-§1` — **Low** — MUST

TimedSpells registers events on a private frame instead of AceEvent: `frame = CreateFrame("Frame")`
(`modules/TimedSpells.lua:79`), then `RegisterUnitEvent("UNIT_AURA", "player", "pet")` and
`RegisterEvent("PLAYER_REGEN_ENABLED")` (`:96-97`).

The reason is written in a comment (`:75-76`): AceEvent-3.0 has no unit-filtered registration. It is
not recorded in the register.

**Fix direction:** file the register row (trigger: "AceEvent gains unit-event registration, or the
scan no longer needs unit filtering"), or move to AceEvent and filter the unit in the handler.

### AM-05 — `options-ui-§16` (anti-pattern #73) — **Low** — MUST

The Bars `Background` subgroup is a hand-written texture block. It is an `LSM30_Statusbar` texture row
(`settings/Bars.lua:74-78`) plus a hand-assembled color pair (`:79-82`). That is a bar block's
companions without the composer, and without its **opacity** row.

The background's alpha comes only from the color's own alpha (`modules/Style_Bars.lua:133-134`). The
fill, by contrast, gets its own `barAlpha` (`:131`).

**Fix direction:** compose it with `H.BarGroup` remapped to `bg*` keys, adding `bgAlpha`. The
alternative is to drop the texture picker, which leaves a background swatch and its companion.

### AM-06 — `options-ui-§13` (`testing-§12`) — **Low** — MUST

No suite case pins the wrapped-strip invariant. The Bars page carries seven tabs (`settings/Bars.lua:6`),
yet no case asserts that the reserved band and every row's y offset are identical for every
selection. The grep in E-16 returns no such case.

The library itself measures the pitch correctly, from the inactive art
(`libs/LibKa0s/OptionsWidgets.lua:411-452`), so this is a missing case, not a broken strip.

**Fix direction:** add the case against a mock that answers a different height for the selected-state
art, and name the mutation it dies under.

### AM-07 — `documentation-§5` — **Low** — MUST

33 `file:line` citations under `docs/` point at the wrong line: 12 of 34 in `docs/ARCHITECTURE.md`,
and 21 of 63 across seven topic docs. Two more are unverified. Most have shifted by roughly 10–15
lines, which suggests the docs were written against an earlier revision of the same files. Each
citation is enumerated in E-15.

**Fix direction:** one citation sweep, re-running the E-15 script until every line resolves.

- **AM-08 — `documentation-§7` — Low — MUST — derived from AM-07.** `DEPENDENCIES.md` cites
  `modules/ContainerManager.lua:284` for the notice that is at `:296` (`DEPENDENCIES.md:20`). It also
  names a `Compat.IsAddOnLoaded` shim at `core/Compat.lua:206` that does not exist
  (`DEPENDENCIES.md:28`). The evidence-based MUST fails on a named symbol. Same root cause and same
  sweep.
- **AM-09 — `documentation-§5` — Low — MUST — derived from AM-07.** Two code comments assert things
  that are no longer true:
  - `core/PoolSetup.lua:5-9` says every container re-renders pooled elements per aura in combat. The
    only `NS.Pool` caller is `modules/Preview.lua:64-87`; engine buttons are Blizzard's.
  - `core/CoreSetup.lua:80-81` says the frame picker reaches `NS.SKIN`. Nothing outside `CoreSetup`
    reads `NS.SKIN` or `NS.ApplySkin` (E-13).

### AM-10 — `compat` (anti-pattern #10) — **Low** — MUST

A deprecated API is called outside `core/Compat.lua`. The library-absent branch of `NS.Meta` calls the
global `GetAddOnMetadata` (`core/EnvSetup.lua:27-28`). This is reachable only on a degraded install.

**Fix direction:** add a `Compat.GetAddOnMetadata` shim, since Compat loads first
(`AuraMaster.toc:39` versus `:47`), and call it. `docs/compat-layer.md` then counts 18 shims.

### AM-11 — `performance-§6` — **Low** — MUST

Suspend neither cancels nor gates the queued apply. `suspend` unregisters the lifecycle events, stops
TimedSpells and re-runs visibility (`core/PerfSetup.lua:65-72`). But `CM.FlushPending`
(`modules/ContainerManager.lua:120-137`) has no `suspended` check, and the bus listener stays live
(`:301-304`). A settings change during arm B, or an apply queued a frame before suspend, still
compiles and restyles engines.

This is not user-visible; it contaminates a capture.

**Fix direction:** make `FlushPending` return while `NS.Perf.suspended`, keeping the pending set. Resume
already calls `RequestApply()` (`core/PerfSetup.lua:82`).

### AM-12 — `savedvariables-§2` — **Low** — MUST

Defaults are re-typed in the render path. The E-18 grep matched 15 lines in `modules/`, and 12 of them
restate a `CONTAINER_TEMPLATE` value:

- `220`, `18` and `32` (`modules/Style.lua:119,122`)
- `"MEDIUM"` and `5` (`modules/Container.lua:258-259`)
- `8` (`modules/Style_Bars.lua:141`)
- `0.6` (`modules/Style_Icons.lua:76`)
- `"ANCHOR_BOTTOMLEFT"` (`modules/Style.lua:152`)
- and others, listed in E-18.

These are latent, since Backfill guarantees the keys (`core/Database.lua:27-39`). But they are a
second place a default is hardcoded.

**Fix direction:** read the fallback from `NS.CONTAINER_TEMPLATE`, or drop it where Backfill
guarantees the key.

### AM-13 — `localization-§1` — **Low** — SHOULD

Some chat sentences cannot be translated. Routed fragments are concatenated with unrouted pieces, for
example `print(L["Selected"] .. " " .. describe(c))` (`settings/Slash.lua:134`), and likewise at
`:153`, `:161`, `:171`, `:193-194` and `:198`. Two stored display strings are unrouted:
`"Container " .. id` (`modules/ContainerManager.lua:186`) and `" (copy)"` (`:242`).

**Fix direction:** route whole sentences through `L` with placeholders, and route the two name
fragments.

- **AM-14 — `events-frames-taint-§8` — Low — SHOULD NOT — derived from AM-13.** Thirteen call sites
  pre-format their arguments before the printer (E-19). All of them fall outside the
  protected-API trigger set, so the value is addon-owned. They are the same sites as AM-13 and share
  one rewrite.

### AM-15 — `toc-file-§5` — **Low** — SHOULD

Conventional TOC positions are not marked per group. Load-bearing lines are all annotated, which
meets the MUST. `core\Secrets.lua` (`AuraMaster.toc:57`), `core\Database.lua` (`:63`), the Modules
group apart from Style (`:72-83`) and the Settings pages (`:88`, `:91-98`) carry no "conventional"
mark.

**Fix direction:** add one conventional comment per group.

### AM-16 — `debug-logging-§8` — **Low** — SHOULD (coverage is SHOULD per its adoption strength)

The no-op and deferral decisions that would explain a missing container are not traced:

- a deferred apply prints once to chat but writes no debug line (`modules/ContainerManager.lua:123-125`);
- a frame anchor that falls back to the screen is silent (`modules/Anchors.lua:95-96`);
- `ResolvePending` skips silently in combat (`modules/Anchors.lua:102`).

**Fix direction:** add three gated `NS.Debug` lines.

### AM-17 — `architecture-§4` (anti-pattern #19) — **Low** — MUST

Peer modules notify one another by direct call:

- TimedSpells calls `NS.ContainerManager.RequestApply()` after learning spells, and again after
  forgetting them (`modules/TimedSpells.lua:64,121`).
- The General master rows call `NS.ContainerManager.ApplyVisibility()` from `onChange`
  (`settings/General.lua:40-46`). `CONFIG_CHANGED` also queues an apply for the same write, so there
  are two paths.

**Fix direction:** add a `Ka0s_AuraMaster_TimedSpellsChanged` message with sender TimedSpells, and
have ContainerManager's `CONFIG_CHANGED` receiver run `ApplyVisibility` for addon-wide rows. Update
the `## Message Bus` table to four messages.

### AM-18 — `automated-tests-§2` — **Low** — MUST

No gate asserts the runner's executable mode. `tests/_kit/run-automated-tests.sh` is correctly
recorded as `100755` today. But neither `tests/_kit/vendor_sync.lua` nor any addon suite asserts it
(E-9), so a future re-vendor could drop the bit silently.

**Fix direction:** the assertion belongs upstream in the kit's consumer gate. Until then, add a local
case in `tests/test_vendor_sync.lua`.

### AM-19 — `options-ui-§2` — **Low** — MUST

The second settings-open path uses non-canonical refusal wording. `NS.OpenOptionsPage` prints
"Cannot open settings during combat." (`settings/OptionsSetup.lua:209`). The canonical text is
"cannot open settings during combat — Blizzard's category-switch is protected".

A player reaches it when the frame picker is canceled by combat, which calls
`NS.OpenOptionsPage(PAGE)` (`settings/Layout.lua:175-177`, `modules/FramePicker.lua:51-54`). The
message is right in substance and only the wording differs.

**Fix direction:** use the canonical string through `L`.

### AM-20 — `documentation-§1` item 5 — **Low** — SHOULD (MUST once published)

The README has no `## Screenshots` section. The Usage heading follows the description directly
(`README.md:20-22`), and `media/screenshots/` does not exist.

**Fix direction:** capture captioned screenshots of the containers and the settings sub-panels, and
add the section before the first publish.

---

## Checked and not filed

Each of these is compliant or out of scope. Evidence is in `03_EVIDENCE.md`.

- **Vendoring:** the LibKa0s payload and the kit are byte-identical to `v1.29.0` (E-6).
- **Provenance line:** in `CLAUDE.md` only, and the Standard badge is bare.
- **Line endings:** the canonical `.gitattributes` body, and 0 stray files (E-7). The packaging
  dot-entry enumeration is clean (E-8).
- **Close button:** one wrapper, no other call sites (E-13). There are no private media copies.
- **Lint and tests:** lint is 0/0 with `tests/` in scope; the suite is 154/0/154; complexity has zero
  drift and no CCN above 15 (E-1, E-2, E-10).
- **Doc shape:** documentation-§3 passes all six tier checks.
- **Issue store:** clean, with no LEDGER and no `[status]` prefixes (E-5).
- **Spelling:** no British spellings in authored text. The only hits are the canonical lists inside
  the repo's own gate (E-20).
- **Locale keys:** every `enUS` key has a reader (E-21).
- **`X-Curse-Project-ID`:** omitted with its comment, which is compliant.
- **Global reset:** composed Master controls, and the reset is a profile reset with the verbatim
  popup and its blast-radius case.
- **Stubs:** the Options stub's load-completing shape is the documented exception, not a gap.
