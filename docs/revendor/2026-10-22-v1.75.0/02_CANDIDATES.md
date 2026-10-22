# 02 — Candidates

Sources, all at the local tag `v1.75.0` in `../LibKa0s`: the `CHANGELOG.md` blocks v1.72.0 (line
621), v1.73.0 (537), v1.74.0 (463) and v1.75.0 (13), and the API documents named per row. The 3g
blockers are not candidates; they were fixed in the copy commit (`01_DELTA.md`).

## A. Delivered on the copy

- **Options 29: a structural refresh of a page on screen keeps its scroll offset**
  (`docs/api/Options/version-29.2.34.2.4.8.1.7.4.2.1-docs.md:49`, and the `RefreshPanel` row at
  `:1447`). A write that re-renders a long settings page (a container page, the spell lists) no
  longer drops the player back at the top.
- **Perf 15: the nesting footer says "top level"** for a bucket observed outside every bucket
  (CHANGELOG v1.72.0). AuraMaster passes no `false`; its report wording can only get clearer.
- **DebugLogDiagnostics 3:** `/am diagnostics` names Glow and Sim on its `LibKa0s running:` line when
  a client carries them.
- **Kit 41:** a lizard crash is reported as a `fail` with the crashed file named, never as a blind
  pass (#46, #47).
- **Kit 40:** the vendor gate holds `media/icons/` to the declaration, and the addon ships 5 icons
  instead of 5,836.

## B. New surfaces (host change required)

| Surface | Evidence | Fit for AuraMaster |
|---|---|---|
| `W.SearchBox(parent, width, opts)` (Widgets 13) | `docs/api/Widgets/version-13.1.4.3.2-docs.md:30` | None today: AuraMaster has no filter-bar search box. Additive. |
| `W.TestStrip(parent, opts)`, `W.TEST_STRIP` (Widgets 13) | `docs/api/Widgets/version-13.1.4.3.2-docs.md:45`, `:59` | None: the test strip is for a standalone data window, and AuraMaster's test mode fills its containers in place; it has no such window. Excluded on purpose by OWNER_SCOPE A (#48 names four other adopters). |
| `W.StepPanel` | CHANGELOG v1.75.0, "PerfPanel minor 7"; `docs/api/Sim/version-1.1.1-docs.md:228-232` | Not available: withdrawn before release (LK-11 outcome B). The renderer is Sim-private. Listed for completeness only. |
| `O.Drawer(ctx, spec)` (OptionsDrawer 1) | `docs/api/Options/version-29.2.34.2.5.9.1.7.4.2.1-docs.md:1466`, `:1588` | Plausible but unasked: a container page could fold its rarer groups into drawers. No owner request; the stub gains `Drawer` only for parity (3g a). Additive. |
| `Item.BonusIDsFromLink(link)` (Item 3) | `docs/api/Item/version-3-docs.md:28` | None: AuraMaster handles no items. |
| `Kit.assertLatchHoldOrder(opts)` (kit 39) | `docs/api/testkit/version-39-docs.md:73` | Plausible, test-only: AuraMaster's slash-commands-§7 step-10 latch case is hand-written and could call the helper. Replaces test code the addon owns. |

## C. Whole-module adoption

| Major | Evidence | Fit for AuraMaster |
|---|---|---|
| `LibKa0s-Glow-1.0` | `docs/api/Glow/version-1-docs.md:46` (`Start(frame, style, knobs, key, frameLevel)`) | None: AuraMaster vendors no LibCustomGlow; its Text glow is its own twin engine (`modules/Container_Twins.lua`). The #56 candidacy was false. |
| `LibKa0s-Sim-1.0` | `docs/api/Sim/version-1.1.1-docs.md:61`, `:67` (`Sim:NewSeam`) | None: AuraMaster has no simulator and OWNER_SCOPE A names it as no adopter. Its test mode is a preview of sample auras, not an event simulation. |
| `LibKa0s-Item-1.0` | unchanged scope since v1.71.0 | None: no items. Settled. |

Six class-B rows (one unavailable) and three class-C majors.
