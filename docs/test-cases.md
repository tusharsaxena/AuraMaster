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

### test_database.lua (21)

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
- database: PrepareProfile seeds an empty profile from its own counter, in declaration order
- database: PrepareProfile marks a stocked profile seeded, drops a non-table entry and restamps ids
- database: a schema version newer than this build is never lowered
- database: learned timed spells survive a load
- database: without AceDB the addon runs on the raw SavedVariables, keeping what was stored
- database: GetContainers follows the stored order and skips an id with no container
- database: a string id in the stored order keeps its place
- database: a deleted id is never handed out again, not even after a reload
- database: NewContainerData takes an id from the counter without registering the container
- database: seeded starters share no table with each other or with the template
- database: a file from before the seeded flag, the id counter and the order keeps its containers

### test_schema.lua (26)

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
- schema: a carve-out's refusal is the locale's sentence
- schema: category spell edits keep only real spell categories
- schema: a whole section written through the seam replaces it, backfills it, logs once and announces once
- schema: a section write refuses a non-section path, a non-table, and a value a row rejects
- schema: a section write runs the normalize hook of every row under it, with the target id
- schema: CheckWrite answers what SetByPath would, and stores and announces nothing

### test_filtercompiler.lua (37)

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
- filter: the whole plan for four rich containers is unchanged (characterization)
- filter: Signature tells a number from its string and a boolean from its name
- filter: numeric strings in the duration and cap settings are read as numbers
- filter: spell lists accept string ids and drop ids switched off
- filter: a category's spell edits accept string ids and ignore keys that are not ids
- filter: an unknown aura type compiles as buffs, and only buffs append weapon enchants
- filter: the spell-list warning follows the unit and the aura type
- filter: 'only timeless' with nothing learned yet filters no ids and warns about none
- filter: a hidden spell category with every id removed excludes nothing
- filter: group keys stay consecutive when a contradiction drops a group

### test_container.lua (35)

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
- container: a line holds perLine elements and the spacing between them; 0 per line is unbounded
- container: growth normalizes to right and down, and the anchor corner is the one auras grow away from
- container: a changed candidate filter is re-sent on the live engine; the filter string is not
- container: clearing the last candidate filter sends the engine an empty table, not nil
- container: sort, cap and layout changes each send only their own setter
- container: a unit change is sent to the live engine once
- container: switching style rebuilds the engine even when the filter plan keeps its shape
- container: a weapon-enchant container shows the player's enchants in the engine's three slots, whatever its unit
- container: an enchant slot the engine refuses costs that slot, not the build
- container: an engine call that raises is traced, and the build carries on to the unit
- container: a restyle dresses every group button and every enchant frame, and skips a lookup the engine refuses
- container: an instance whose container is gone applies nothing and touches no engine
- container: the anchor's scale is the container's times the master's, never below a tenth
- container: the anchor's alpha is the container's times the master's
- container: out-of-combat visibility shows out of combat and hides in it
- container: the class snapshot is the tracked unit's, and nothing for the player or for enchants
- container: a class the client withholds resolves to no class instead of raising
- container: a button the engine creates is dressed with the container's class snapshot
- container: on a client without the aura engine a container is deleted without error

### test_containermanager.lua (48)

- manager: Create appends a container, names it uniquely and announces it
- manager: two containers with one name become 'X' and 'X (2)'
- manager: deleting a container sends the ones attached to it back to the screen
- manager: Rename trims, refuses an empty name and keeps names unique
- manager: names that differ only in case are not unique
- manager: Duplicate copies every setting under a new id and name, offset on screen
- manager: CopyFrom copies the chosen section, never the name or the position
- manager: CopyFrom and ResetPositions write through the seam, send no CONTAINERS_CHANGED, and report a rejected write
- manager: CopyFrom is all or nothing — a corrupt later section stores and announces nothing
- manager: many apply requests in one frame schedule one pass
- manager: an apply under combat lockdown waits, says so once, and runs after combat
- manager: /am test, /am lock and a rename under lockdown print no deferral notice
- manager: a master visibility row hides containers at once, with no apply pass
- manager: disabling a container in combat hides it at once, with no apply and no deferral notice
- manager: a deferral out of combat while auras are secret names the restriction, and combat inside it adds no line
- manager: the regen edge never escalates the notice; a later held request does
- manager: a Blizzard-frame toggle in combat says it waits, once, and applies after combat
- manager: a container deleted under lockdown is parked — disabled, nothing hidden — and destroyed after combat
- manager: a parked id that comes back before combat ends reuses its instance and draws again
- manager: a profile switch under lockdown parks departing containers and tears them down after combat
- manager: a profile reset under lockdown parks departing containers and tears them down after combat
- manager: a profile reset in combat keeps a reused id parked until the deferred apply rebuilds it
- manager: a profile switch in combat keeps a reused id parked until the deferred apply rebuilds it
- manager: a profile copy in combat keeps a reused id parked until the deferred apply rebuilds it
- manager: a parked id revived by a profile change in combat stays parked until the deferred apply
- manager: an id a later Create reuses after a profile reset while auras are secret stays parked until the deferred apply
- manager: creating or duplicating a container in combat is refused and creates nothing
- manager: ResetPositions puts every container back on the screen, staggered
- manager: a target swap under lockdown leaves the class color silently stale and re-applies after combat
- manager: a stale class and a held change of the player's re-apply the container once after the hold
- manager: a target swap out of combat re-applies only class-colored containers of that unit
- manager: an out-of-combat swap to a same-class target, or NPC to NPC, queues no apply
- manager: a class-changing swap queued just before combat applies after it, with no deferral notice
- manager: timed spells learned just before combat apply after it, with no deferral notice
- manager: /am forgettimed in combat is the player's change, so it says it waits
- manager: a player's change held beside the addon's own request is announced once
- manager: a reload in combat builds silently and applies once combat ends
- manager: a request for one container applies only that one
- manager: a flushed queue is empty, and a later request schedules a pass of its own
- manager: a held request keeps exactly its container through the hold
- manager: a flush with nothing queued traces no deferral, even under lockdown
- manager: a container row re-applies its own container; an addon-wide row re-applies every one
- manager: a new container is named and staggered by its id; a given position is kept
- manager: UniqueName skips every taken suffix, and a blank name becomes Container
- manager: deleting a container leaves every other attachment and the selection alone
- manager: a duplicate of an attached container keeps its position; an unknown id is refused
- manager: a rebuilt engine re-anchors every container attached to it
- manager: a client without the aura engine is told once, at startup

### test_compat.lua (16)

- compat: the aura engine counts as present only with its sort enum and CreateFrame
- compat: EnsureAuraContainer loads Blizzard_AuraContainer only when it is not loaded yet
- compat: a LoadAddOn that raises, or no C_AddOns at all, still answers from the enums
- compat: AurasAreSecret answers a strict boolean, and false when the client cannot say
- compat: every sort key reaches a distinct member of the engine's sort enum
- compat: sort direction reads the engine enum, else 1 for reverse and 0 for normal
- compat: enchant slots read the engine enum by member, with the client's numbering as fallback
- compat: the enchant sort and placement read their enums, else 1
- compat: flow axis and direction use AnchorUtil's enums, else pass the name through
- compat: the status-bar and dispel-style enums answer nil on a client without them
- compat: no duration formatter for Blizzard's own text, without C_StringUtil, or when creation fails
- compat: a detailed formatter shows two units with a carry, a short one a single unit
- compat: the expiring text color is a step curve from the expiring color to the normal one at the threshold
- compat: no curve API, or a curve that refuses a point, gives no text color
- compat: the mouse focus is the topmost frame GetMouseFoci returns, else the legacy global
- compat: spell info comes from C_Spell, and the pre-11.0 global only when C_Spell is absent

### test_secrets.lua (3)

- secrets: without the client's secrets system nothing is secret and every value is readable
- secrets: issecretvalue alone decides access when canaccessvalue is absent, as a strict boolean
- secrets: canaccessvalue, when the client has it, overrides the secret test

### test_bus.lua (5)

- bus: every message name carries this addon's prefix and no two share one
- bus: two receivers on their own targets both hear one message, with its payload
- bus: CONTAINERS_CHANGED goes out once per registry act, and never for a refused one
- bus: world entry and each combat edge send one VISIBILITY_CHANGED; a unit swap sends none
- bus: a CONFIG_CHANGED the receiver cannot read re-applies the container it names, or every one

### test_state.lua (2)

- state: the session flags start off, are never saved, and a reload starts them clean
- state: preview's toggle stores a strict boolean and hides or restores the engines at once

### test_lifecycle.lua (10)

- lifecycle: the eight lifecycle events are registered to their handlers, and nothing else is
- lifecycle: a focus change refreshes the focus containers, a target change the target ones
- lifecycle: UNIT_PET refreshes the pet containers only for the player's own pet
- lifecycle: entering the world runs an apply held while auras were secret
- lifecycle: combat starting runs no held apply; combat ending does
- lifecycle: a profile switch out of combat rebuilds every container for the new profile at once
- lifecycle: every profile event clears the container selection and re-renders the panel once
- lifecycle: a copied profile is prepared before its containers are built
- lifecycle: a reset profile gets its starters back, numbered from 1 again
- lifecycle: a profile switch applies the new profile's Blizzard-frame settings

### test_anchors.lua (24)

- anchors: a chain that would loop is detected
- anchors: a container attaches to another one, and a loop falls back to the screen
- anchors: a named frame that does not exist yet waits, and attaches once it does
- anchors: a frame that appears during combat is attached when combat ends
- anchors: a screen fallback and a skipped resolve are traced
- anchors: a forbidden frame, or something that is not a frame, is never a target
- anchors: a drag saves the dragged container's position, rounded, whatever is selected
- anchors: a drag saves the position in one write
- handle: a dark WHITE8X8 strip with a 1px gold edge, a gold label and the catalog help mark
- handle: above the anchor when auras grow down, below when up, edge-aligned where they start
- handle: at least as wide as its container's element, and as its label with room for the help mark
- handle: while shown the anchor's clamp rect takes it in; hidden, or in combat, the rect is left alone
- handle: under lockdown a changed layout does not re-place the handle; the next pass after it does
- handle: a handle first shown under lockdown is placed once; the anchor's clamp still waits
- handle: a visibility pass that changes nothing re-sets no clamp insets
- handle: the help mark carries the tooltip and right-click opens the settings on this container
- handle: the tooltip follows the cursor, owned by UIParent, never anchored to the strip or the mark
- handle: a left-drag that starts on the help mark moves the container as one on the strip does
- handle: without the media library the help mark falls back to Blizzard's information icon
- picker: a frame resolves to its nearest named ancestor, skipping the screen and ourselves
- picker: a forbidden frame under the cursor ends the walk without calling its methods
- picker: it arms on release, then a left-click on a named frame picks it
- picker: combat starting mid-pick cancels it
- picker: Escape cancels

### test_style.lua (19)

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
- style: a tracked unit whose class lookup raises paints the swatch, and nothing raises
- style: a dress that raises still clears its class color, and the error reaches the caller
- style: a dress that raises hands the error handler the failing styler's stack
- style: a dress that raises a non-string value hands that value on unchanged
- style: the Blizzard time format asks for no formatter of our own
- style: buttons of one look share one formatter and curve; a new color builds a new curve

### test_timedspells.lua (11)

- timed: nothing is needed until a container shows only timeless auras
- timed: it hears UNIT_AURA through AceEvent only while needed and readable
- timed: UNIT_AURA for another unit schedules nothing
- timed: combat drops UNIT_AURA and its end restores it with a scan
- timed: a scan queued before combat is dropped in combat, and the gate reopening scans again
- timed: secret auras out of combat keep UNIT_AURA unregistered until the restriction lifts
- timed: learning a spell is announced on the bus to every receiver, and the manager re-applies
- timed: a readable scan learns every timed buff once, and skips permanent ones
- timed: while auras are secret nothing is read
- timed: what was learned reaches the filter as excluded ids, and Forget clears it
- timed: Forget traces what it cleared

### test_slash.lua (23)

- slash: every command is a positional {name, desc, fn} triple
- slash: the reserved verbs are all present
- slash: /am new creates the described container and selects it
- slash: /am new with a word it does not know creates nothing and says why
- slash: /am select takes an id or a name; /am containers marks the selection
- slash: /am set writes the selected container through the seam
- slash: lock, unlock and test drive the same settings the panel does
- slash: /am preview is an unknown verb now; it prints the help index and changes nothing
- slash: /am help and the landing page list test, not preview
- slash: /am disable and /am enable write the master switch through the seam and say so
- slash: /am disable in combat is not refused; the master switch is a visibility write
- slash: /am enable prints the seam's error instead of the success line
- slash: enable and disable are listed by /am help and on the landing page
- slash: the degraded stub still answers /am enable and /am disable
- slash: /am delete removes a container by id
- slash: a name two containers share is refused, not guessed
- slash: /am delete in combat refuses in gray and keeps the container
- slash: /am resetall in combat resets the profile and parks what it drops (options-ui-§12)
- slash: the General Reset-all popup in combat resets the profile and parks what it drops (options-ui-§12)
- slash: /am new in combat refuses in gray and creates nothing
- slash: /am pick starts the frame picker for the selected container
- slash: /am resetall and the General reset print the same line
- slash: /am debug on and off flip the session flag; it never reaches the profile

### test_bulklog.lua (13)

- bulklog: a container page's Defaults is one [Set] line counting the rows it changed
- bulklog: General's Defaults is one [Set] line counting the rows it changed
- bulklog: Reset all, from /am resetall or the General popup, is one line in total — the profile handler's
- bulklog: the degraded build's Reset all is one line in total, too
- bulklog: Slash's CliResetAll, handed the same pair, is one [Set] reset all line
- bulklog: a profile reset and a profile copy are one [Set] line each; a switch keeps its trace
- bulklog: CopyFrom is one [Set] line counting the rows it changed, and no [Containers] summary
- bulklog: a refused CopyFrom logs nothing
- bulklog: ResetPositions is one [Set] line counting the rows it changed
- bulklog: a bracket inside a bracket logs once, summed, when the outer one closes
- bulklog: a -0 stored over 0 is not a change, so a settled ResetPositions counts none
- bulklog: a bulk act that raises still logs its one line, marked, and the seam logs again
- bulklog: a library Defaults a row's onChange stops counts the write it stored

### test_optionssetup.lua (17)

- options: NS.Helpers IS the library instance
- options: every page registers, in TOC order, and Profiles opts out without AceDBOptions
- options: the Profiles page SHOWS the container AceConfigDialog fills, even a pooled (hidden) one
- options: every page renders without a reported error
- options: the General page leads with Master controls, in canonical order
- options: the Filters page offers the spell-list tab only for a buff container
- options: a container page's tabs are its schema groups, then its admitted bespoke tabs; a stale tab falls back
- options: with no containers a container page draws one placeholder tab
- options: the banner is the picker — choosing a container retargets every page
- options: the Containers page's New button creates and selects a container
- options: a page's Defaults button restores only the selected container
- options: Reset all settings resets the active profile whole, and nothing else (options-ui-§12)
- options: opening a page in combat refuses with the canonical gray line
- options: the Delete popup refuses in combat
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
- the automated-test runner is recorded executable (100755)

### test_lintconfig.lua (5)

- lintconfig: .luacheckrc sets no top-level ignore
- lintconfig: .luacheckrc switches no warning class off wholesale
- lintconfig: every files[...] ignore is narrowed to a file or a name
- lintconfig: no source file carries a bare inline luacheck ignore
- lintconfig: no length operator shares its line with a keyword or brace lizard must see

### test_eol.lua (1)

- eol: every tracked file carries the terminator .gitattributes declares for it

## Totals

| Suite | Cases |
|-------|------:|
| test_loadorder.lua | 7 |
| test_setups.lua | 8 |
| test_database.lua | 21 |
| test_schema.lua | 26 |
| test_filtercompiler.lua | 37 |
| test_container.lua | 35 |
| test_containermanager.lua | 48 |
| test_compat.lua | 16 |
| test_secrets.lua | 3 |
| test_bus.lua | 5 |
| test_state.lua | 2 |
| test_lifecycle.lua | 10 |
| test_anchors.lua | 24 |
| test_style.lua | 19 |
| test_timedspells.lua | 11 |
| test_slash.lua | 23 |
| test_bulklog.lua | 13 |
| test_optionssetup.lua | 17 |
| test_perf.lua | 5 |
| test_locale.lua | 2 |
| test_docs.lua | 6 |
| test_surface_parity.lua | 4 |
| test_vendor_sync.lua | 3 |
| test_lintconfig.lua | 5 |
| test_eol.lua | 1 |
| **Total** | **351** |
