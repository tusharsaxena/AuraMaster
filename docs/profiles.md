# Profiles

AceDB profiles are user-visible here — the Profiles sub-page is a profile control in the options UI
— which is the trigger for this doc (documentation-§3).

## What a profile holds

**Everything the player built.** `profile` carries the master controls, the two Blizzard-frame
switches and the whole container registry (`containers`, `containerOrder`, `nextContainerId`,
`seeded`). Switching profile therefore swaps the entire set of containers, their filters, placement
and look. Shape and defaults: `docs/schema.md`.

**Not in a profile:** `global.timedSpells` (which buffs are timed is a fact about the game, learned
once for the account), `global.schemaVersion`, the `AuraMasterPerfDB` capture ring (outside AceDB
entirely, performance-§5) and the session state (`debug`, the selected container, preview).

## AceDB setup

`NS.InitDB` (`core/Database.lua:269`), called from `OnInitialize`:

- `AceDB:New("AuraMasterDB", NS.defaults, true)` — `true` puts every character on the shared
  `Default` profile until the player picks a per-character, per-class or per-realm one.
- `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` each call their own handler:
  `NS.OnProfileChanged`, `NS.OnProfileCopied` and `NS.OnProfileReset`. The three share one body and
  differ only in the line they trace.
- Then `NS.RunMigrations` — the ladder, then `Database.PrepareProfile` on the active profile.

## Switching, copying, resetting

`NS.OnProfileChanged`, `NS.OnProfileReset` and `NS.OnProfileCopied` (`core/AuraMaster.lua:248`,
`core/AuraMaster.lua:259`, `core/AuraMaster.lua:266`):

```
NS.OnProfileChanged() / OnProfileReset() / OnProfileCopied(source)
  ├─ Database.PrepareProfile(db.profile)    backfill every container, normalize the order,
  │                                          seed the starters if this profile never had them
  ├─ State.SetActiveContainer(nil)           the old selection's id may not exist here
  ├─ the event's one trace line              switch: [Profile] changed -> X
  │                                          reset:  [Set] reset profile 'X' to defaults
  │                                          copy:   [Set] copied profile 'A' → 'X'
  ├─ ContainerManager.Announce()             instances follow the new registry, apply all,
  │                                          CONTAINERS_CHANGED → the panel re-renders
  ├─ BlizzardFrames.Apply()                  the new profile's hide switches
  └─ NS.RefreshOptionsPanel()
```

- **A new profile** starts empty, so `PrepareProfile` seeds the three starter containers into it.
- **A copy** brings the source's containers with their ids; `PrepareProfile` then makes the order and
  the id counter consistent.
- **A reset** empties the profile. `seeded` goes back to `false` with it, so the starter containers
  come back — a reset is "as installed", not "nothing".
- **Logging (debug-logging-§10).** A reset or a copy is AceDB replacing the profile whole, not a write
  through the seam, so its handler logs it once. A reset's line carries no row count, which debug-logging-§10
  allows. A reset re-seeds the starter containers, so counting the rows not at default would
  overcount. AceDB also gives no hook before the wipe, so the Profiles page's Reset Profile cannot
  cheaply snapshot the rows it is about to change. Reset all's bulk bracket wraps the profile reset
  and logs nothing of its own, and the session rows it writes first are muted, so a Reset all reads
  as that one line.
- The apply that follows is deferred like any other while auras are secret or combat lockdown is on.
- **A switch, copy or reset in combat** from the page cannot be refused, since AceDB fires it (the
  `/am profile` verb refuses its own switch in combat, below). A container the new
  profile does not have is parked (its engine disabled, nothing hidden) and torn down after combat;
  a container it adds gets a plain anchor frame now and its engine once combat ends. Ids are reused
  across profiles (a reset reseeds the starters from id 1), so a container whose id the new profile
  also has stays parked too: its engine was built for the old container, and it draws again only
  after the deferred apply rebuilds it for the new one. The same holds for a container the new
  profile lacks: it is marked as parked by a profile change, so if a Create or Duplicate hands its
  id out again before the apply can run (a reset rewinds the id counter, and both are allowed out of
  combat while aura information is withheld), it stays parked until that apply rebuilds it.

## Reset all settings is a profile reset

General → Master controls → **Reset all settings** and `/am resetall` both reach
`NS.Helpers.RestoreAllDefaults`. The options descriptor's `resetProfile` makes that
`db:ResetProfile()` (options-ui-§12), so the global reset and Profiles → Reset Profile are the same
act, with the same popup wording. The global reset's own row walk skips the Profiles page and every
profile-backed row (`vetoedFromResetAll`, `settings/OptionsSetup.lua:48`), leaving it only the
session rows a profile reset cannot reach. It also skips the **Minimap button** row, which is not a
profile setting at all and which no reset may move (launcher-§3, `docs/settings-panel.md` → Launcher). Other profiles are untouched. Neither surface is refused
in combat: like Reset Profile, both take the parked teardown described above.

The button's tooltip names the equivalence, because the options descriptor sets `profilesPage =
true` beside `resetProfile` in `settings/OptionsSetup.lua`: *Reset the current profile to its
defaults — the same thing Profiles → Reset Profile does. Your other profiles are not affected.*

## The Profiles sub-page

`settings/Profiles.lua` registers `AceDBOptions:GetOptionsTable(NS.db)` with AceConfig as
`AuraMaster-Profiles` and draws it with `AceConfigDialog:Open` into an AceGUI `SimpleGroup` inside
the canvas, on first show and again on every render (AceConfigDialog re-reads the current profile on
each open). It is the only AceConfig use in the addon (options-ui-§3) and carries no Defaults button.
New, copy, delete and reset are managed from this page; switching also has a chat verb (below).

## The `/am profile` verb

`/am profile` lists the profiles, the current one marked `(current)`; `/am profile <name>` switches to
that profile. The verb's behavior is `LibKa0s-Slash-1.0`'s `CliProfile` (Slash minor 17), reached
through the `profile` row in `NS.COMMANDS` and the descriptor's `profiles` field, which hands over
`NS.db` at call time (`settings/Slash.lua`):

- **The name** keeps its case and inner spaces (AceDB names are case-sensitive); one pair of
  surrounding quotes is stripped, so `/am profile "Raid Night"` and `/am profile Raid Night` are the
  same.
- **An existing profile only.** An unknown name prints `No profile named '<name>'.`, a
  `Did you mean '<name>'?` when exactly one profile matches ignoring case, and the list. It never
  creates a profile: `SetProfile` would, and a new profile gets the starter containers seeded into it.
  New profiles come from this page.
- **The switch** is `NS.db:SetProfile(name)`, so it runs the same `OnProfileChanged` path as the
  page (above), with its one `[Profile] changed -> <name>` line; the library logs nothing of its own.
  The current name answers `Already on profile '<name>'.`
- **Refused in combat** (`Can't switch profiles in combat.`), unlike the page, whose switch AceDB fires
  and so cannot be refused. The list and the refusals still answer in combat.
- **Live while disabled.** `profile` is in `liveVerbs()`, so a disabled player can switch to a
  profile where the addon is on; `prepareProfile` re-reads the latch.
- **Library absent.** The degraded stub's `CliProfile` prints `/am profile is unavailable: the LibKa0s
  library did not load.` and switches nothing. With AceDB absent (below) the store lacks the profile
  methods and the verb prints `Profiles are not available.`

## Without AceDB

If `AceDB-3.0` is missing (only possible if `libs/` was tampered with), `NS.InitDB` builds a
db-shaped table over the raw global — `AuraMasterDB.profile` and `AuraMasterDB.global`, each
backfilled from the defaults — so the addon still loads and answers its CLI. There is then one
implicit profile, no callbacks fire, and the Profiles page opts out because AceDBOptions is gone
with the rest.
