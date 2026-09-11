# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below is the **authoritative pass count** — the README test
badge and any count quoted in the docs must agree with it.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_loadorder.lua (7)

- loadorder: the TOC lists the locale first and the Profiles page last
- loadorder: every TOC path exists, and none is a library
- loadorder: the load-bearing pairs are in order, and the TOC says why
- loadorder: every addon file in the TOC is covered by a LOAD-BEARING or Conventional note
- loadorder: the runner loaded exactly the TOC's files and the XML's library files
- loadorder: the offline perf runner and the degraded list derive from the TOC too
- loadorder: the library registered — NS.Perf is the real probe, not the stub

### test_setups.lua (8)

- core: NS.Print is reclaimed from AceConsole and prints with the cyan [AM] tag
- core: NS.Printf is reclaimed from AceConsole and formats inside the secret-safe printer
- core: every close control goes through the one NS.MakeCloseButton wrapper
- media: icons and the monospace face resolve inside this addon's folder
- env: the version falls back to NS.version where the TOC cannot be read
- env: the metadata reader never calls the deprecated global
- debug: the logging flag is ours, session-only, and never written to the profile
- degraded: without LibKa0s the addon still loads and every seam answers

### test_database.lua (10)

- database: a fresh profile is seeded with the three starter containers, once
- database: PrepareProfile is idempotent
- database: string ids, dangling order entries and orphans are repaired
- database: the backfill fills a missing leaf and keeps a stored false
- database: every category key is present on a stored container, neutral
- database: category keys are unique across the buff and debuff lists
- database: a new container's data is a deep copy of the template with a fresh id
- database: the migration runner stamps the schema and creates the timed-spell store
- database: an existing SavedVariables file keeps its containers
- database: a non-numeric container key is dropped and the profile loads

### test_schema.lua (24)

- schema: every row validates against defaults/Profile.lua
- schema: the validator is falsifiable — an unresolvable path and a missing group each fail
- schema: no path is registered twice
- schema: every row has a label and a group (a row without a group belongs to no tab)
- schema: a row's default comes from the template, never from a composer
- schema: every color row has its class-color companion next to it, or is a palette swatch
- schema: every category of both lists is a row, offered only for its aura type
- schema: the Filters page offers the active container's categories and no others
- schema: a container path writes the selected container and no other
- schema: an explicit container id overrides the selection
- schema: with nothing selected, a container path means the first container
- schema: a container write with no containers refuses, naming why
- schema: an unknown path refuses
- schema: every write announces CONFIG_CHANGED once, naming the container
- schema: a failed validation writes nothing
- schema: renaming to a taken name through the seam stores a unique, trimmed name
- schema: a session row is stored by its own set, never in the profile
- schema: a session row announces no CONFIG_CHANGED and queues no apply
- schema: ApplyDefault restores the shipped value without sharing a table
- schema: a spell set is written whole and normalized to positive integer ids
- schema: category spell edits keep only real spell categories
- schema: a whole section written through the seam replaces it, backfills it, logs once and announces once
- schema: a section write refuses a non-section path, a non-table, and a value a row rejects
- schema: a section write runs the normalize hook of every row under it, with the target id

### test_filtercompiler.lua (27)

- filter: an unfiltered buff container is one HELPFUL group with no candidate filters
- filter: a debuff container starts from HARMFUL
- filter: cast by me and by others compile to PLAYER and its negation
- filter: a max duration becomes the engine's maxDuration candidate filter
- filter: 'only timed' is maxDuration = huge, which drops permanent auras
- filter: 'only timeless' excludes every learned timed spell and ignores a max duration
- filter: 'only timeless' on a debuff container is reported and treated as any duration
- filter: showing a token category adds the token
- filter: hiding a token category adds its negation to every group
- filter: hiding a flag category asks for the opposite value
- filter: a dispel category shown includes, hidden excludes
- filter: two shown categories are a union, and the second excludes the first
- filter: a token shown after a token excludes it by negation
- filter: a category's spell edits add and remove ids
- filter: a shown spell category with every id removed can never match, and says so
- filter: the whitelist is its own first group and every other group excludes it
- filter: the blacklist is excluded everywhere and beats the whitelist
- filter: spell lists on your own debuffs are flagged as ignored
- filter: spell lists on a target's buffs only apply while it is friendly
- filter: the player's own buffs carry no identity warning
- filter: a weapon-enchant container has three slots and no aura groups
- filter: an enchant container on another unit still shows the player's, and says so
- filter: a player buff container may append weapon enchants; a target's may not
- filter: max auras caps each group; 0 means no cap
- filter: an unknown sort method falls back to Blizzard's default
- filter: Signature is independent of key insertion order and sees nested changes
- filter: StructureKey tracks the group count, the enchant slots and hide-permanent

### test_container.lua (16)

- container: the engine is anchored before its first group and given its unit last
- container: a player buff container with enchants adds all three enchant slots
- container: a filter change is applied in place, sending only what changed
- container: a change of shape retires the engine and builds a new one
- container: toggling hide-permanent rebuilds the engine with the new flag
- container: a sort-direction change reaches the enchant sort in place
- container: a restyle re-dresses every button the engine has made
- container: nothing touches the engine while auras are secret, and it catches up after
- container: the show ladder — suspend, the master switch, the container switch, visibility
- container: unlocking previews placeholders through the style code and disables the engine
- container: a visibility pass re-dresses no preview element unless the settings changed
- container: a new target refreshes only the containers tracking the target
- container: Blizzard's load-on-demand aura container is loaded before the first engine
- container: on a client without the aura engine nothing is built and preview still works
- container: deleting a container disables its engine and hides its anchor
- container: an anchor is movable but never saved by the client's layout cache

### test_containermanager.lua (23)

- manager: Create appends a container, names it uniquely and announces it
- manager: two containers with one name become 'X' and 'X (2)'
- manager: deleting a container sends the ones attached to it back to the screen
- manager: Rename trims, refuses an empty name and keeps names unique
- manager: names that differ only in case are not unique
- manager: Duplicate copies every setting under a new id and name, offset on screen
- manager: CopyFrom copies the chosen section, never the name or the position
- manager: CopyFrom and ResetPositions write through the seam, send no CONTAINERS_CHANGED, and report a rejected write
- manager: many apply requests in one frame schedule one pass
- manager: an apply under combat lockdown waits, says so once, and runs after combat
- manager: /am preview, /am lock and a rename under lockdown print no deferral notice
- manager: a master visibility row hides containers at once, with no apply pass
- manager: a deferral out of combat while auras are secret names the restriction, and combat inside it adds no line
- manager: the regen edge never escalates the notice; a later held request does
- manager: a container deleted under lockdown is parked — disabled, nothing hidden — and destroyed after combat
- manager: a parked id that comes back before combat ends reuses its instance and draws again
- manager: a profile switch under lockdown parks departing containers and tears them down after combat
- manager: a profile reset under lockdown parks departing containers and tears them down after combat
- manager: creating or duplicating a container in combat is refused and creates nothing
- manager: ResetPositions puts every container back on the screen, staggered
- manager: a target swap under lockdown leaves the class color silently stale and re-applies after combat
- manager: a target swap out of combat re-applies only class-colored containers of that unit
- manager: an out-of-combat swap to a same-class target, or NPC to NPC, queues no apply

### test_anchors.lua (13)

- anchors: a chain that would loop is detected
- anchors: a container attaches to another one, and a loop falls back to the screen
- anchors: a named frame that does not exist yet waits, and attaches once it does
- anchors: a frame that appears during combat is attached when combat ends
- anchors: a screen fallback and a skipped resolve are traced
- anchors: a forbidden frame, or something that is not a frame, is never a target
- anchors: a drag saves the dragged container's position, rounded, whatever is selected
- anchors: a drag saves the position in one write
- picker: a frame resolves to its nearest named ancestor, skipping the screen and ourselves
- picker: a forbidden frame under the cursor ends the walk without calling its methods
- picker: it arms on release, then a left-click on a named frame picks it
- picker: combat starting mid-pick cancels it
- picker: Escape cancels

### test_style.lua (15)

- style: an element's size comes from its style's settings
- style: a stored-nil leaf falls back to the template's own value
- style: a bar's fill and background take their texture, color and opacity from settings
- style: the background opacity multiplies onto the background texture
- preview: a column of bars grows down from the top left
- preview: rows of icons growing left and up wrap after perLine
- style: a restyle clears the additive bindings before adding them again
- style: a bar binds the engine's timer bar, icon, name, time and stacks
- style: an icon binds the cooldown and the dispel border
- style: right-click cancel is offered only on your own buffs, and never click-through
- style: a preview element is dressed but never bound to the engine
- style: a class color keeps the stored alpha; off, the stored swatch is used
- style: a target container's class color is the target's, snapshotted at apply
- style: the Blizzard time format asks for no formatter of our own
- style: buttons of one look share one formatter and curve; a new color builds a new curve

### test_timedspells.lua (9)

- timed: nothing is needed until a container shows only timeless auras
- timed: it hears UNIT_AURA through AceEvent only while needed and readable
- timed: UNIT_AURA for another unit schedules nothing
- timed: combat drops UNIT_AURA and its end restores it with a scan
- timed: secret auras out of combat keep UNIT_AURA unregistered until the restriction lifts
- timed: learning a spell is announced on the bus to every receiver, and the manager re-applies
- timed: a readable scan learns every timed buff once, and skips permanent ones
- timed: while auras are secret nothing is read
- timed: what was learned reaches the filter as excluded ids, and Forget clears it

### test_slash.lua (15)

- slash: every command is a positional {name, desc, fn} triple
- slash: the reserved verbs are all present
- slash: /am new creates the described container and selects it
- slash: /am new with a word it does not know creates nothing and says why
- slash: /am select takes an id or a name; /am containers marks the selection
- slash: /am set writes the selected container through the seam
- slash: lock, unlock and preview drive the same settings the panel does
- slash: /am delete removes a container by id
- slash: a name two containers share is refused, not guessed
- slash: /am delete in combat refuses in gray and keeps the container
- slash: /am resetall in combat refuses in gray and resets nothing
- slash: /am new in combat refuses in gray and creates nothing
- slash: /am pick starts the frame picker for the selected container
- slash: /am resetall and the General reset print the same line
- slash: /am debug on and off flip the session flag; it never reaches the profile

### test_optionssetup.lua (14)

- options: NS.Helpers IS the library instance
- options: every page registers, in TOC order, and Profiles opts out without AceDBOptions
- options: every page renders without a reported error
- options: the General page leads with Master controls, in canonical order
- options: the Filters page offers the spell-list tab only for a buff container
- options: the banner is the picker — choosing a container retargets every page
- options: the Containers page's New button creates and selects a container
- options: a page's Defaults button restores only the selected container
- options: Reset all settings resets the active profile whole, and nothing else (options-ui-§12)
- options: opening a page in combat refuses with the canonical gray line
- options: the Delete and Reset-all popups refuse in combat
- options: the Background block is composed in canonical order, and its tooltips name the background
- options: a wrapped tab strip reserves the same band and places every tab at the same y for every selection
- options: the degraded stub completes the load — every page's rows still register

### test_perf.lua (5)

- perf: every declared bucket is reached by a real bracket
- perf: a dormant probe notes nothing
- perf: suspend makes the addon inert without a reload, and resume restores it
- perf: suspend holds a queued apply until resume
- perf: without the library, /am perf answers one honest line

### test_locale.lua (2)

- locale: every L[...] subscript in the source is defined in enUS.lua
- locale: every key enUS.lua defines is used somewhere in the source

### test_docs.lua (6)

- README.md carries no angle-bracket argument placeholders
- the addon's own files use US spellings (localization-§5's canonical lists)
- the spelling gate is falsifiable: it flags a British word and passes its US twin
- every Tier 2 documentation-map row agrees with docs/
- every .md under docs/ appears in the documentation map
- docs: every file:line citation names an existing file and a non-blank line inside it

### test_surface_parity.lua (4)

- parity: the Core stub publishes everything core/CoreSetup.lua publishes live
- parity: the DebugLog stub carries every member the addon calls
- parity: the Options stub carries every helper a page file reaches at load
- parity: the Slash stub carries every dispatcher member the addon calls

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- vendor: the automated-test runner is recorded executable (100755)

### test_lintconfig.lua (4)

- lintconfig: .luacheckrc sets no top-level ignore
- lintconfig: .luacheckrc switches no warning class off wholesale
- lintconfig: every files[...] ignore is narrowed to a file or a name
- lintconfig: no source file carries a bare inline luacheck ignore

### test_eol.lua (1)

- eol: every tracked file carries the terminator .gitattributes declares for it

## Totals

| Suite | Cases |
|-------|------:|
| test_loadorder.lua | 7 |
| test_setups.lua | 8 |
| test_database.lua | 10 |
| test_schema.lua | 24 |
| test_filtercompiler.lua | 27 |
| test_container.lua | 16 |
| test_containermanager.lua | 23 |
| test_anchors.lua | 13 |
| test_style.lua | 15 |
| test_timedspells.lua | 9 |
| test_slash.lua | 15 |
| test_optionssetup.lua | 14 |
| test_perf.lua | 5 |
| test_locale.lua | 2 |
| test_docs.lua | 6 |
| test_surface_parity.lua | 4 |
| test_vendor_sync.lua | 3 |
| test_lintconfig.lua | 4 |
| test_eol.lua | 1 |
| **Total** | **206** |
