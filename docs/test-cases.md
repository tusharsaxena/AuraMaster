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

### test_database.lua (12)

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

### test_schema_paths.lua (33)

- schema paths: the seam validates before it resolves, so a bad value names the value, not the container
- schema paths: normalize is handed the resolved id, so a container keeps its own name in any case
- schema paths: the seam writes, then reacts, then logs, then announces — each seeing the stored value
- schema paths: onChange, the [Set] line and CONFIG_CHANGED all see the normalized value
- schema paths: a refused write reacts to nothing, logs nothing and announces nothing
- schema paths: a path that is not a string is refused by every seam, naming what was passed
- schema paths: a selection naming a container that no longer exists falls back to the first
- schema paths: an explicit container id that does not exist is refused, never redirected to the selection
- schema paths: an absolute path writes the profile whatever container is named or selected
- schema paths: GetSetting reads paths that are not rows, and a container path reads nil with no containers
- schema paths: a table value is stored as a copy, so the caller's table can never edit the container
- schema paths: a row's validate runs at the seam — the attach target refuses a non-number and a cycle
- schema paths: DefaultFor answers the template or the profile defaults, as a copy, never the stored value
- schema paths: RegisterSchemaRows stamps a resolvable row's default, and leaves session and unresolved rows alone
- schema paths: ValidateSchema fails an unknown page, an unknown type and an empty group, and says which
- schema paths: SchemaForPage keeps declaration order and drops hidden rows and rows the container's type does not take
- schema paths: Choices keeps the key order and localizes each label, falling back to the key
- schema paths: a spell set goes to the container it names, announced as filters and logged once
- schema paths: a spell set or a section with no container to land in is refused, naming why
- schema paths: category edits drop an empty edit set and store a truthy edit as true
- schema paths: exactly the six documented sections are whole-writable
- schema paths: a section write fires onChange only for the leaves it changed, with the target id
- schema paths: a row under a section that refuses its leaf refuses the whole section — CheckWrite says the same
- schema paths: a section write backfills a copy, so the caller's table comes back as it went in
- schema paths: a section replaces the stored one from the template, not merges into it, and normalizes its spell sets
- schema paths: a section's [Set] line renders the stored table with sorted keys and nested tables elided
- schema paths: a section's [Set] line is not even built while debug is off
- schema paths: with no containers CheckWrite refuses a container row and passes a global one
- schema paths: ApplyDefault is a no-op for nothing, a row with no path, and a row with no default
- schema paths: ApplyDefault restores a session row through its own set
- schema paths: a session row needs no database — it checks and writes before InitDB has run
- schema paths: a session row's validate still guards it
- schema paths: a session row with no get reads nil, never the profile

### test_filtercompiler.lua (28)

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

### test_containermanager.lua (37)

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

### test_slash_verbs.lua (35)

- slash verbs: /am help prints the alias header, then one row per NS.COMMANDS verb in order
- slash verbs: the landing page's rows are /am help's rows without the chat indent
- slash verbs: /am and /auramaster both reach the one dispatcher
- slash verbs: /am options is an alias of /am config, and both open the settings panel
- slash verbs: /am version prints the version on its own line
- slash verbs: get, set and reset with no path print a usage line naming /am
- slash verbs: an unknown path, or one in the wrong case, is not found and nothing is written
- slash verbs: a global row reads with no note; a container row names the container it read
- slash verbs: with no containers, get and list read a container row as nil and note nothing
- slash verbs: set clamps a number to the row's range and echoes what was stored
- slash verbs: set refuses what the row's type cannot take, and stores and announces nothing
- slash verbs: set writes a color in the stored {r, g, b, a} shape; get decodes a partial one channel by channel
- slash verbs: a value the parser takes but the seam refuses prints the seam's reason, then the unchanged value
- slash verbs: set and reset reach a session row, which never lands in the profile
- slash verbs: reset restores the selected container's row only, and its echo carries no note
- slash verbs: set on a global row writes the profile through the seam
- slash verbs: /am list prints every row once, grouped by page in page order, noting container rows
- slash verbs: /am resetall resets the profile once, with no popup, and says so
- slash verbs: /am resetall without the settings helpers says it cannot, and resets nothing
- slash verbs: the Reset-all confirmation is options-ui-§12's wording, a Yes/No pair that waits
- slash verbs: /am lock ends preview mode through the seam; /am unlock says how to drag
- slash verbs: /am test reads its word in any case, toggles on anything else, and says which
- slash verbs: /am pick with no containers, or in combat, never starts the picker
- slash verbs: /am pick attaches the container selected when it began, even if the selection moves
- slash verbs: a right-click cancels /am pick, says so, and attaches nothing
- slash verbs: /am perf prints every line the harness returns, tagged, and hands it the rest of the line
- slash verbs: a bare /am debug toggles the window and leaves the flag; /am debug ON is read in any case
- slash verbs: /am containers marks the selection and a disabled container, and says when there are none
- slash verbs: /am select matches a name in any case, and a miss moves nothing
- slash verbs: /am new reads its words in any case, and a later word overrides an earlier one
- slash verbs: /am delete matches a name in any case and names what it deleted; a miss deletes nothing
- slash verbs: /am resetposition and /am forgettimed do their act and say so
- slash verbs: without the library each schema verb names what is missing, and writes nothing
- slash verbs: without the library /am still prints its help, aliases still route, and an unknown verb says so
- slash verbs: without the library the host verbs keep working

### test_bulklog.lua (20)

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
- bulklog: a stray bulkEnd with no bracket open logs nothing, and the next bracket still counts itself
- bulklog: a spell set written in a bracket counts once when it changed and not at all when it did not
- bulklog: a section written in a bracket counts each row and spell set under it that changed, and its own line is muted
- bulklog: a session row written in a bracket is counted through its own get
- bulklog: each act starts its own count and its own error mark
- bulklog: an error inside a nested bracket marks the outer act's one line
- bulklog: Bulk.Run stays silent only when its act answers true, the profile reset's signal
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

### test_options_descriptor.lua (16)

- options descriptor: a rendered widget reads the selected container and writes it through the seam
- options descriptor: a color swatch shows the stored color and stores the picker's in the {r, g, b, a} shape
- options descriptor: a page's Defaults resets the page's session rows too
- options descriptor: Reset all writes only session rows through the seam and resets only the active profile
- options descriptor: Reset all never writes a Profiles-page row, live or degraded
- options descriptor: the degraded Reset all resets the profile whole and walks no profile-backed row
- options descriptor: the banner lists every container in display order and ignores a re-pick of the selection
- options descriptor: the Containers page's picker is a plain dropdown on the chrome ledger that selects
- options descriptor: a container page draws its intro, then the bespoke tabs its container's type admits
- options descriptor: with no containers a page draws the one empty-registry line and no intro
- options descriptor: a page's own header replaces the banner
- options descriptor: a re-render returns the last render's chrome widgets to the pool, after it draws
- options descriptor: RenderWarnings draws one orange line per thing the engine will not do
- options descriptor: panel refreshes asked for in one frame are one refresh, on the next frame
- options descriptor: OpenOptionsPage opens a registered page's category and falls back to the panel otherwise
- options descriptor: the stub's composers emit the paths and types the live composers do

### test_perf.lua (8)

- perf: every declared bucket is reached by a real bracket
- perf: a dormant probe notes nothing
- perf: suspend makes the addon inert without a reload, and resume restores it
- perf: suspend holds a queued apply until resume
- perf: the buckets are declared in report order, and only the per-container apply nests
- perf: suspend and resume log to the console whatever the debug flag says
- perf: resume re-registers exactly the lifecycle events suspend took away
- perf: without the library, /am perf answers one honest line

### test_debuglogsetup.lua (7)

- debuglog: enabling logging writes the [Init] summary — name, version, schema, profile and container count
- debuglog: the flag is NS.State.debug itself — the sink and IsEnabled read it live
- debuglog: the chat acknowledgment goes through the addon's tagged printer; the console brackets both ends
- debuglog: showing or hiding the console refreshes open panels, so the Master controls row follows it
- debuglog: the Debug console row shows and hides the window and never touches the logging flag
- debuglog: without the library, SetEnabled still flips the flag and acks, and says once that the window is gone
- debuglog: without the library the console row is honest — never checked, and its tooltip says why

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
| test_database.lua | 12 |
| test_schema.lua | 26 |
| test_schema_paths.lua | 33 |
| test_filtercompiler.lua | 28 |
| test_container.lua | 16 |
| test_containermanager.lua | 37 |
| test_anchors.lua | 24 |
| test_style.lua | 19 |
| test_timedspells.lua | 11 |
| test_slash.lua | 23 |
| test_slash_verbs.lua | 35 |
| test_bulklog.lua | 20 |
| test_optionssetup.lua | 17 |
| test_options_descriptor.lua | 16 |
| test_perf.lua | 8 |
| test_debuglogsetup.lua | 7 |
| test_locale.lua | 2 |
| test_docs.lua | 6 |
| test_surface_parity.lua | 4 |
| test_vendor_sync.lua | 3 |
| test_lintconfig.lua | 5 |
| test_eol.lua | 1 |
| **Total** | **368** |
