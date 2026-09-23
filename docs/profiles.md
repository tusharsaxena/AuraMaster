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

`NS.InitDB` (`core/Database.lua:243`), called from `OnInitialize`:

- `AceDB:New("AuraMasterDB", NS.defaults, true)` — `true` puts every character on the shared
  `Default` profile until the player picks a per-character, per-class or per-realm one.
- `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` each call their own handler:
  `NS.OnProfileChanged`, `NS.OnProfileCopied` and `NS.OnProfileReset`. The three share one body and
  differ only in the line they trace.
- Then `NS.RunMigrations` — the ladder, then `Database.PrepareProfile` on the active profile.

## Switching, copying, resetting

`NS.OnProfileChanged`, `NS.OnProfileReset` and `NS.OnProfileCopied` (`core/AuraMaster.lua:173`,
`core/AuraMaster.lua:184`, `core/AuraMaster.lua:191`):

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
- **A switch, copy or reset in combat** cannot be refused, since AceDB fires it. A container the new
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
profile-backed row (`vetoedFromResetAll`, `settings/OptionsSetup.lua:47`), leaving it only the
session rows a profile reset cannot reach. It also skips the **Minimap button** row, which is not a
profile setting at all and which no reset may move (launcher-§3, `docs/ARCHITECTURE.md` → Launcher). Other profiles are untouched. Neither surface is refused
in combat: like Reset Profile, both take the parked teardown described above.

The button's tooltip names the equivalence, because the options descriptor sets `profilesPage =
true` beside `resetProfile` in `settings/OptionsSetup.lua`: *Reset the current profile to its
defaults — the same thing Profiles → Reset Profile does. Your other profiles are not affected.*

## The Profiles sub-page

`settings/Profiles.lua` registers `AceDBOptions:GetOptionsTable(NS.db)` with AceConfig as
`AuraMaster-Profiles` and draws it with `AceConfigDialog:Open` into an AceGUI `SimpleGroup` inside
the canvas, on first show and again on every render (AceConfigDialog re-reads the current profile on
each open). It is the only AceConfig use in the addon (options-ui-§3) and carries no Defaults button.
There is no `/am profile` verb; profiles are managed from this page.

## Without AceDB

If `AceDB-3.0` is missing (only possible if `libs/` was tampered with), `NS.InitDB` builds a
db-shaped table over the raw global — `AuraMasterDB.profile` and `AuraMasterDB.global`, each
backfilled from the defaults — so the addon still loads and answers its CLI. There is then one
implicit profile, no callbacks fire, and the Profiles page opts out because AceDBOptions is gone
with the rest.
