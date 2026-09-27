# Font primer: design (replaces the blank-name repaint)

- **Date:** 2026-09-27
- **Branch:** `fix/2026-09-27-blank-bar-names` (the same branch; this design supersedes
  `2026-09-27-blank-bar-names-design.md`, which stays as the record of the first attempt)
- **Findings:** `docs/superpowers/research/2026-09-27-blank-bar-names-findings.md`, section
  "Correction: the real cause is the font"
- **Plan:** `docs/superpowers/plans/2026-09-27-font-primer.md`
- **Owner decisions (2026-09-27):** remove the repaint (NameRepaint) once master plus a font warm-up
  tested clean, which it did; then build the primer. Issue #24.

## Problem

WoW loads an addon-supplied font file lazily. Text first drawn in it before the load completes comes
out empty and stays empty until it is written again. A bar name is written by the aura engine once,
when the aura is assigned, so a name drawn in a not-yet-loaded font stays blank. Drawing on a hidden
frame does not load the font; drawing on a shown frame does.

## Goal

Every font the containers draw in is loaded before any container text is drawn in it, so no name,
time, stack or label text ever comes up blank. The change should be small, cost nothing in combat and
nothing while stood down, and the NameRepaint machinery goes.

## Design

### P1. Remove NameRepaint

Remove `modules/NameRepaint.lua` and everything that exists only for it:

- its TOC entry;
- the Sync calls in `CM.FlushPending` and `CM.ApplyVisibility`;
- the `OnEnterWorld` hook and the `Arm` calls in `OnUnitSwap` and `OnUnitPet`;
- the stand-down Stop;
- the `nameRepaint` perf bucket and its `tests/perf.lua` scenarios;
- `tests/test_namerepaint.lua`, and the count changes it made in `test_disabled`, `test_perf` and
  `test_emptywatch`;
- the `name repaint:` diagnostics line;
- the docs NR-05 added.

Keep what stands on its own:

- the removal of the cee5bb6 width fields (they read `?` on live bars);
- the shared refusal in `TT.Compile`;
- the corrected findings.

`Style.ShowsEngineName` is removed as well, unless the primer uses it. It does not.

### P2. `modules/FontPrimer.lua` (`NS.FontPrimer`)

- **What it primes:** every distinct (font path, size, flags) triple that any container in the
  active profile uses: `bars.name`, `bars.time`, `bars.stacks`, `icons.time`, `icons.stacks`,
  `text.font` and `label.font`. Paths are resolved exactly as `Style.ApplyFont` resolves them
  (`Style.Fetch("font", ...)` with the same fallback and flag map), so the primed key is the one the
  bars will use. Fonts under `Fonts\` are built into the client and are skipped. All containers are
  primed, enabled or not: it is cheap, and it covers a container being turned on later.
- **How:** one frame, parented to UIParent, `SetSize(1, 1)`, placed off-screen (the
  ChonkyCharacterSheet pattern), and **shown**. For each triple not primed yet this session, a
  FontString on that frame gets `SetFont(path, size, flags)` and `SetText(SAMPLE)`. SAMPLE is the
  character set probe v4 proved: A-Z, a-z, 0-9 and common punctuation. The frame is hidden again
  `HOLD` seconds later, by a cancellable `C_Timer.NewTimer` handle. The primed set is kept, so a
  triple is primed once per session.
- **When:**
  - `FontPrimer.PrimeAll()` runs where `CM.StartListening()` runs (at `CM.Init` on login and at
    stand-up), before the first build. That is PLAYER_LOGIN, when every addon, and so every
    LibSharedMedia font, is registered.
  - It runs again from the `CONFIG_CHANGED` handler before the apply is requested (a font setting,
    a new container, a profile switch).
  - Nothing runs while stood down.
- **Follow-up refresh:** priming a triple that the live bars may already have drawn in (a font
  changed in settings, or a `/reload` that builds with auras present) leaves those names blank. So
  whenever a PrimeAll primed something new, it arms one refresh after `REFRESH` seconds. The refresh
  runs `ContainerClass:Refresh()` (UpdateAllAuras) on each live instance that has an engine, is not
  parked or stale, and is shown and not previewing (a disabled engine would clear its auras). It is
  one-shot: re-arming only restarts it. This is the only engine call the primer makes.
- **Stand-down:** `FontPrimer.Stop()` from `CM.StopListening()`: cancel both timers and hide the
  frame. The primed set survives, because the fonts stay loaded.
- **Constants:** `HOLD = 1.0`, `REFRESH = 0.5`.

### P3. Diagnostics and trace

- `/am diagnostics` header: `fonts primed: <n> [<file> <size> <flags>, ...] refresh=<armed|idle>`.
  It reads state only (debug-logging-§14).
- Trace: one `NS.Debug("Fonts", "primed %d new font(s)", n)` line per PrimeAll that primed anything.

### P4. Docs

- `docs/debug.md`: rewrite "Bar names that do not show" around the lazy font load and the primer.
- `docs/midnight-quirks.md`: replace the "name is written once" section with a measured section on
  the lazy font load, keeping the engine write-once fact that makes it visible.
- ARCHITECTURE, data-flow, module-map, performance and known-limitations back to the truth: no
  aura-driven path in combat again, and the primer's one-off cost.
- `docs/smoke-tests.md`: replace the BN checks (never run) with FP checks from the same number.

## Testing

Test-first, in a new suite `tests/test_fontprimer.lua`. It covers:

- the triples are collected from every block and deduplicated;
- a `Fonts\` path is skipped;
- the path matches `Style.ApplyFont`'s resolution, including the fallback;
- the frame is shown while priming and hidden after `HOLD`;
- a second PrimeAll primes nothing new and arms no refresh;
- a font change primes only the new triple and arms one refresh;
- the refresh reaches only eligible instances (engine, shown, not previewing, not parked or stale);
- nothing runs while stood down, and Stop cancels both timers and hides the frame;
- the diagnostics line.

`test_disabled`'s survivor and timer census must hold. The mock cannot show a font loading, so the
owner's smoke checks prove the effect: a cleared-cache login and first casts with every container on
Ka0s Prototype, and no probe installed.

## Risks

- **Whether an off-screen frame counts as drawn.** Probe v4 drew on screen. ChonkyCharacterSheet
  primes off-screen and reports it works. If the first smoke check still shows a blank, the fallback
  is a 1 x 1 on-screen frame that clips its children, and it is a one-line change.
- **A font LibSharedMedia registers after PLAYER_LOGIN** (a media addon loaded on demand): it
  resolves to the fallback until the next CONFIG_CHANGED or login. This is accepted.
