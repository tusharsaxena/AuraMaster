# Font primer addendum: survive the loading screen (FP-06)

- **Date:** 2026-09-27, after the owner's first in-game run of cbdd82f
- **Plan it extends:** `2026-09-27-font-primer.md` (FP-00..FP-05 executed; frozen)

## What the run showed

Auras cast after login drew with zero delay in every Ka0s Prototype container. The auras present at
login (Devotion Aura, Sign of the Skirmisher, Ophidian Maw, Afterimage, Encapsulated Destiny, Void
Breach) stayed blank for the whole session.

## Why (the working explanation)

`FontPrimer.PrimeAll` runs at PLAYER_LOGIN, under the loading screen. The prime frame was hidden one
second later, and the refresh fired 0.5 s after priming, both before the loading screen ended. The
working assumption is that nothing is drawn while the loading screen shows, so the font never loaded.
The login auras were then the first text drawn in the font: they came out blank, and that failed draw
loaded it, which is why every later aura drew. Probe v4 kept its sample text visible all session, so
it never hit this.

## FP-06

- `FontPrimer.OnEnterWorld()`, called from `addon:OnEnterWorld`, stands down like the rest:
  - if anything was primed since the last loading screen, it keeps (or makes) the prime frame shown;
  - it arms the hide at `WORLD_HOLD` = 2.0 s and one refresh at `WORLD_REFRESH` = 1.5 s after
    PLAYER_ENTERING_WORLD;
  - it clears the "primed since the last loading screen" mark.
- A loading screen with nothing newly primed arms nothing.
- A PrimeAll that primes during play (a font setting, a profile switch) keeps the existing HOLD and
  REFRESH behavior. A PrimeAll before the first PLAYER_ENTERING_WORLD does not arm its short hide or
  refresh; it leaves them to OnEnterWorld.
- Tests: login ordering (a PrimeAll at login, then PEW, then the refresh reaching the eligible
  instances, then the frame hidden); a second PEW arming nothing; a font change during play still on
  the 0.5 s path; stand-down cancels the world timers.
- Docs: `docs/debug.md`, the performance cost note and the smoke checks (a new check: login with
  permanent buffs up and a cleared cache, and their names draw within about 2 s after the loading
  screen).
