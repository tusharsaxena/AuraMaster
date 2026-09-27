# Font primer addendum: retry a refused font (FP-07)

- **Date:** 2026-09-27, after the owner's in-game run of 6994c46
- **Plans it extends:** `2026-09-27-font-primer.md` and
  `2026-09-27-font-primer-addendum-loading-screen.md` (both executed; frozen)

## What the run showed

The run passed: every name drew. But `/am diagnostics` read
`fonts primed: 1 [Ka0s Kait.ttf 36 THICKOUTLINE]`. Every Ka0s Prototype triple was missing: ten
OUTLINE bar texts and twelve labels, all resolving to
`Interface\Addons\SharedMedia_MyMedia\font\Ka0s Prototype.ttf`, which SharedMedia_MyMedia registers
at load just as it registers Kait. The pass came only from the refresh after the loading screen,
which rewrote text already drawn. The primer itself had loaded nothing for Prototype.

## The defect

`primeBlock` set `seen[path][size][flags] = true` before it called `prime()`. When `fs:SetFont`
answered false, the triple was dropped with no trace. Because it was already marked seen, no later
priming tried it again. A font refused at PLAYER_LOGIN was never primed for the rest of the session.

## FP-07

- A triple is marked primed only when `SetFont` accepts it. A refused triple goes on a refused set.
  The set is keyed `[file][size][flags]`, so it is deduplicated and a repeat look-up allocates
  nothing. Every later `PrimeAll` retries it.
- `FontPrimer.OnLoadingScreenEnd`, and the `PLAYER_ENTERING_WORLD` fallback on a client without
  `LOADING_SCREEN_DISABLED`, run one priming pass before they arm the world hide and refresh. A
  font refused under the loading screen is primed once the screen is gone, and the world refresh
  still follows. A retry that primes arms the normal path: the short hide and refresh in play, the
  world timers at the loading screen's end.
- A triple keeps the one font string it was first tried on. A retry does not create another.
- A priming that meets a refusal writes one `[Fonts] N font(s) refused, retried at the next priming`
  line. It gives counts only.
- Diagnostics: the `fonts primed:` line gains ` refused=<n> [<file> <size> <flags>, ...]`, or
  `refused=0`. It reads state only and is capped like the primed list.
- Tests: `tests/test_fontprimer.lua` uses a SetFont stand-in that refuses a path and then accepts
  it, and `tests/test_diagnostics.lua` covers the `refused=` tail.
- Docs: `docs/debug.md` explains how to read `refused=`. `docs/known-limitations.md` covers a font
  that stays refused. `docs/smoke-tests.md` gains FP11: log in with a cleared cache, and
  `/am diagnostics` lists every Ka0s font under `fonts primed` with `refused=0`.
