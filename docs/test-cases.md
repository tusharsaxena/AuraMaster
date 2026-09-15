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

### test_setups.lua (14)

- core: NS.Print is reclaimed from AceConsole and prints with the cyan [AM] tag
- core: NS.Printf is reclaimed from AceConsole and formats inside the secret-safe printer
- core: every close control goes through the one NS.MakeCloseButton wrapper
- media: icons and the monospace face resolve inside this addon's folder
- env: the version falls back to NS.version where the TOC cannot be read
- env: the metadata reader never calls the deprecated global
- debug: the logging flag is ours, session-only, and never written to the profile
- degraded: without LibKa0s the addon still loads and every seam answers
- media: the shipped face and bar textures reach LibSharedMedia, from this addon's folder
- core: the degraded printer names the missing library once, on the first line it prints
- core: the degraded Printf stringifies every argument before it formats
- core: the degraded color resolver keeps the stored alpha, and falls through for a unit with no class
- core: every close button is built with this addon's folder, so it can draw the catalog mark
- namespace: NS is private — no global — and carries the folder name and the [AM] tag

### test_database.lua (64)

- database: a fresh profile is seeded with the three starter containers, once
- database: PrepareProfile is idempotent
- database: string ids, dangling order entries and orphans are repaired
- database: the backfill fills a missing leaf and keeps a stored false
- database: every category key is present on a stored container, at Show (schema v3)
- database: category keys are unique across the buff and debuff lists
- database: a new container's data is a deep copy of the template with a fresh id
- database: the migration runner stamps the schema and creates the timed-spell store
- database: an existing SavedVariables file keeps its containers
- database: a stored section of the wrong type is replaced from the template on load
- database: a non-numeric container key is dropped and the profile loads
- database: a string key naming an id already stored as a number is dropped; the numeric key wins
- database: a dropped string twin leaves one [Migrate] line naming the key
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
- database v2: spell additions from every container are united in the profile
- database v2: a starter is removed profile-wide only when every container that edited it removed it
- database v2: an addition beats another container's removal of the same spell
- database v2: the two healing lists' spell edits merge under healing
- database v2: a container's two healing states merge — show beats hide beats neutral
- database v2: dispel colors come from the first dispel-colored container in display order
- database v2: with no dispel-colored container the first container's colors win, completed from the defaults
- database v2: a stale string twin or a non-numeric container key takes no part in the merge
- database v2: a profile with no containers gets the default dispel colors and empty spell lists
- database v2: stored Medium strata rises to High and every other strata is kept
- database v2: the step is idempotent over a profile it already migrated
- database v2: RunMigrations migrates every stored profile, the inactive one included
- database v2: RunMigrations logs one [Migrate] line per profile, and a second run is a no-op
- database v2: without AceDB the step migrates the one profile there is
- database v2: a fresh profile carries the profile-wide spell lists and dispel colors
- v3: a container that whitelisted a category hides every other category of its type
- v3: a container with no whitelisted category gets every row at show
- v3: includeEnchants becomes the weaponEnchants row and the old key is cleared
- v3: a HARMFUL container is never given a weaponEnchants row — that category does not exist for debuffs
- v3: an ENCHANT container is left alone
- v3: a container with a missing or unrecognized auraType is left completely untouched
- v3: MigrateV3 is idempotent — a second run changes nothing a first run already decided
- v3: a container with no filter.categories table at all converges without an enchant row narrowing it, even once weaponEnchants is a real kind="enchant" category
- v3: a narrowed container's filter.whitelist is left untouched — the compiler rescues the shown categories now
- v3: uncategorized is left to the ordinary backfill (X-2), not to MigrateV3 itself — UNWHITELISTED branch only
- v3: a WHITELISTED (narrowed) container gets uncategorized stamped hide directly from MigrateV3, never left for the backfill
- v3: a narrowed container does not gain unlisted auras after migrating — compiled, not just stored
- v3: MigrateV3 returns the number of containers it walked
- v3: a container skipped for an unrecognized auraType is not counted in the walked total, and logs its own line
- v3: the whitelist lift never sweeps a category the aura type does not have
- v4: the current schema version is 4
- v3: RunMigrations migrates every stored profile, the inactive one included
- v4: a HELPFUL container with the toggle on ends up with Uncategorized hidden, and the dead key cleared
- v4: a HARMFUL container with the toggle on ends up with Uncategorized (debuffs) hidden, and the dead key cleared
- v4: a container with the toggle off or absent is untouched
- v4: an ENCHANT container with the toggle on is neither converted nor lost — it compiles to no groups, so nothing was ever lost
- v4: an unrecognized auraType with the toggle on is genuinely lost, named in lostList, and its dead key still cleared
- v4: MigrateV4 is idempotent
- v4: a genuinely lost container's notice reaches NS.Print, not just NS.Debug (item 3)
- v4: no notice is printed when nothing was lost

### test_schema.lua (28)

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
- schema: the spell lists are one profile-wide set at the absolute path categorySpells (schema v2)
- schema: the validator resolves the profile-wide sets, and the dispel swatches are profile rows
- schema: a whole section written through the seam replaces it, backfills it, logs once and announces once
- schema: a section write refuses a non-section path, a non-table, and a value a row rejects
- schema: a section write runs the normalize hook of every row under it, with the target id
- schema: CheckWrite answers what SetByPath would, and stores and announces nothing

### test_schema_paths.lua (36)

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
- schema paths: an explicit-id attach write is checked for a loop from the container it writes
- schema paths: an explicit-id attach write that would loop is refused, whatever is selected
- schema paths: an attach write through the selection still checks the selected container
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

### test_filtercompiler.lua (74)

- filter: an unfiltered buff container is one HELPFUL group with no candidate filters
- filter: a debuff container starts from HARMFUL
- filter: cast by me and by others compile to PLAYER and its negation
- filter: a max duration becomes the engine's maxDuration candidate filter
- filter: 'only timed' is maxDuration = huge, which drops permanent auras
- filter: 'only timeless' excludes every learned timed spell and ignores a max duration
- filter: 'only timeless' on a debuff container is reported and treated as any duration
- filter: showing a token category adds nothing when nothing is hidden — there is always exactly one group (R-3)
- filter: hiding a token category negates its token in the catch-all (R-5)
- filter: hiding a flag category asks for the opposite value
- filter: a dispel category shown includes nothing when nothing is hidden, hidden excludes
- filter: two shown categories with nothing hidden still compile to the one, unfiltered group (R-3)
- filter: two hidden token categories both negate, in the catch-all (R-5)
- filter: a hidden category's spell edits add and remove ids from the catch-all's exclusion
- filter: spell edits are the profile's, handed in ctx; a container's own old copy is ignored (schema v2)
- filter: both compile sites hand the compiler the profile's spell lists
- filter: showing a spell category with every id removed, and nothing hidden, still contributes nothing (R-3)
- filter: a shown spell category with every id removed can never match, and is dropped as a conflict (R-6)
- filter: categories set to show add no group when nothing is hidden — there is always exactly one
- filter: a category set to hide excludes its spells from the catch-all
- filter: a token category set to hide negates its token
- filter: show and hide are not symmetric — show excludes nothing
- filter: a hidden spell category with no ids left contributes no exclusion
- filter: the whitelist is its own first group and every other group excludes it
- filter: the whitelist beats the blacklist — an id on both lists is shown (R-2)
- filter: the blacklist still reaches the catch-all, but never the whitelist group (R-7)
- filter: a stray filter.onlyShown key, however it got there, is inert — the compiler never reads it (D8 retired)
- filter: Uncategorized Show draws an unlisted aura even when a Blizzard token category is Hidden — the owner's exact case
- filter: no two groups can match the same aura when Uncategorized is Show — the catch-all would have (fix round 1)
- filter: Uncategorized Hide drops the catch-all entirely rather than shipping a group that can never match (fix round 1)
- filter: a listed aura's own category group is unaffected by Uncategorized either way
- filter: Uncategorized Show on a debuff container contributes no group and does not neuter another category's Hide
- filter: Uncategorized Hide on a debuff container reproduces the retired 'Only these categories' toggle exactly
- filter: Uncategorized Show on a debuff container with nothing else hidden changes nothing (R-3 still applies)
- explain: an unlisted id is rank 3 (shown) when Uncategorized is Show — not the old rank 5
- explain: an unlisted id is rank 4 (hidden) when Uncategorized is Hide
- explain: with no Uncategorized category for the aura type at all, an unclaimed id is still rank 5
- explain: HARMFUL, Uncategorized Show (default): an unclaimed id is rank 5, not rank 3 — hasUnion is false, nothing to rescue
- explain: HARMFUL, Uncategorized Hide: an unclaimed id is rank 4, naming Uncategorized
- filter: spell lists on your own debuffs are flagged as ignored
- filter: spell lists on a target's buffs only apply while it is friendly
- filter: the player's own buffs carry no identity warning
- filter: a weapon-enchant container has three slots and no aura groups
- filter: an enchant container on another unit still shows the player's, and says so
- filter: the weaponEnchants row decides the enchant slots, and adds no group
- filter: the enchant row does nothing on a debuff or a non-player container
- filter: the enchant slots the container draws are exactly the profile's, in a fixed order
- filter: an enchant container's slots also come from the profile, falling back to all three
- filter: max auras caps each group; 0 means no cap
- filter: max auras stamps EVERY group, not just the first — the cap is per group, not per container
- filter: an aura in a Show category is drawn even if it is also in a Hide category (rank 3 beats rank 4)
- filter: a Hide plus a Show yields a group per shown category plus the catch-all, with no aura drawn twice (R-4/R-5)
- filter: one Hide on the real shipped category list explodes to one group per other shown category — 15 for HELPFUL, 15 for HARMFUL today
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
- filter: a contradiction drops the catch-all without disturbing the whitelist group's key
- filter: hiding two categories that contradict on the same flag leaves nothing, and says so
- explain: the whitelist beats the blacklist — rank 1, shown
- explain: the blacklist alone hides — rank 2
- explain: a Show category rescues an aura another category hides — rank 3, shown, both named
- explain: an aura whose every category says Hide is hidden — rank 4
- explain: an aura in no category is shown, with no categories named — rank 5
- explain: a stray filter.onlyShown key does not affect rank 5 — the toggle is retired
- explain: a token category is never named — only spells-kind categories are reasoned about

### test_container.lua (41)

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
- container: a live container has a mouse blocker covering its engine, below its buttons
- container: a shape change re-anchors the blocker to the new engine
- container: raising the anchor's level after the engine exists leaves the blocker strictly below it
- container: the blocker follows TakesHover and never takes clicks, matching the live buttons
- container: a live click-through flip re-gates the blocker without a rebuild
- container: a hidden container hides its blocker along with its engine, and Park hides it too
- container: on a client without the aura engine a container is deleted without error

### test_containermanager.lua (51)

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
- manager: a profile-wide dispel color or spell-list write re-applies every container (G-2, G-3)
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
- apply: an error in one container's Apply does not stop the others or replaceAttached
- apply: with no client error handler the pass finishes, then the first error is raised

### test_compat.lua (19)

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
- compat: no duration formatter without C_StringUtil, or when creation fails
- compat: a detailed formatter shows two units with a carry, a short one a single unit
- compat: every time format rounds a fractional second up, as the cooldown countdown does (I-2)
- compat: the Blizzard format copies the engine's default formatter, rounding up (I-2)
- compat: without the curve API, or with a curve that refuses a point, the Blizzard format tops out at days
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

### test_anchors.lua (63)

- anchors: a chain that would loop is detected
- anchors: a container attaches to another one, and a loop falls back to the screen
- anchors: a named frame that does not exist yet waits, and attaches once it does
- anchors: a frame that appears during combat is attached when combat ends
- anchors: a screen fallback and a skipped resolve are traced
- anchors: a forbidden frame, or something that is not a frame, is never a target
- anchors: a forbidden frame falls back to the screen without waiting, so an add-on load never re-places it
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
- anchors: a screen container sits at its stored point on UIParent, sized to one element
- anchors: a container attaches to its target's engine frame at the derived points, or to its anchor before it has one
- anchors: a container never attaches to itself or to one that does not exist
- anchors: a frame target takes the stored attach point, relative point and offsets
- anchors: a frame that refuses the anchor falls back to the screen, cleanly re-placed
- anchors: an empty frame name is a screen fallback that waits on nothing
- anchors: a waiting container set back to the screen stops waiting
- anchors: a waiting container deleted before its frame appears is dropped from the wait
- anchors: an add-on loading re-places only the containers still waiting
- anchors: a loop among other containers is refused, and the walk still ends
- anchors: a chain that ends at a screen container is no loop; one that returns to the start is
- anchors: a real, unforbidden frame resolves, even one without IsForbidden; a name that is not a string never does
- anchors: a drag with no relative point stores the point for both, and each offset to one decimal
- anchors: an anchor that reads back no point writes nothing
- handle: the strip names its container, and a container whose settings are gone hides it
- handle: an attached container's tooltip says where its offsets are set; a screen one does not
- handle: an attached container, or one in combat, does not move on a drag, and a stray drag stop stores nothing
- handle: the strip sits fifty levels above its anchor, over the container's elements
- handle: a left click on the strip opens nothing; a right click opens this container's settings
- anchors: derived points continue a vertical/right/down parent
- anchors: derived points continue a vertical/left/down parent
- anchors: derived points continue a vertical/right/up parent
- anchors: derived points continue a vertical/left/up parent
- anchors: derived points continue a horizontal/right/down parent
- anchors: derived points continue a horizontal/right/up parent
- anchors: derived points continue a horizontal/left/down parent
- anchors: derived points continue a horizontal/left/up parent
- anchors: an attached container flows as its parent does, and its own flow stays stored
- anchors: a chain inherits its root's flow; a broken or looping chain stops where it breaks
- anchors: a container attached to another takes derived points from the parent's flow
- anchors: a frame-attached container keeps its stored points
- anchors: the engine's flow, the placeholders and the handle all read the inherited flow
- anchors: detaching a container restores its own stored flow at the next apply
- anchors: a write that moves a container's flow re-applies every container following it
- anchors: while its parent previews, an attached container hangs from the parent's preview extent, not its engine (L-4)
- anchors: locking re-anchors an attached container to its parent's engine, and unlocking back to the extent (L-4)
- anchors: under lockdown a preview toggle leaves an attached container where it is; the pass after combat moves it (L-4)
- handle: an attached container's strip sits above every placeholder of the container it is attached to (L-4)

### test_style.lua (43)

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
- style: buttons of one look share one formatter and curve; a new color builds a new curve
- style: the Solid border is registered with the media library as the flat white texture
- style: a media key resolves through the media library; an unknown, empty, odd or broken one draws the fallback
- style: a font the client refuses falls back to the built-in font at the same size and flags
- style: each outline setting reaches the font as the client's flag string
- style: a font shadow is a one-pixel black drop when on, and no offset when off
- style: a text's corner, offsets and justification come from its block, the template filling what is missing
- style: a text given a box is as wide as the box less its offset, so its justification has room to show
- style: a missing text block leaves its font string untouched
- style: a text's color is its own swatch, or the dress's class when its companion is on
- style: a missing color paints opaque white rather than raising
- style: a border is hidden when off, styled None, or without a positive size
- style: a shown border takes the media edge, its size and its color
- style: a binding the client lacks is skipped, and one it refuses costs that binding alone
- style: a class color is looked for only in the active style's block, text blocks included
- style: a dispel color map holds a color per stored type, and nothing for a leaf that is not a color
- style: tooltips and click-through decide whether a button takes the mouse at all
- style: right-click cancel reaches weapon enchants, never the player's debuffs, and never when turned off
- style: the tooltip anchor and in-combat hiding come from settings, the template filling a missing anchor
- style: the time text gets the engine's formatter for its format, and the expiring color at its threshold
- style: a placeholder's time text is what its format's formatter writes, the one the engine is handed (B-5)
- style: a placeholder running out takes the running-out color, as the engine's curve paints a live one (B-5)
- style: at the default threshold one placeholder is running out, so turning the color on shows (B-5)
- style: a style leaf left nil draws the template's value, never a literal of its own
- style: a frame dressed as a bar, then as an icon, builds icon regions and hides the bar's
- style: hiding the other style's regions never hides the element itself

### test_timedspells.lua (19)

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
- timed: the pet's timed buffs are learned too
- timed: an aura read that raises ends that unit's scan, not the other unit's
- timed: a secret spell id or a secret duration is never learned
- timed: a burst of the player's aura changes queues one scan
- timed: Forget is announced as the player's own change, and the next readable scan learns again
- timed: a scan tick the gate drops is never bracketed; one that reads is, once
- timed: a disabled container, or one showing debuffs, needs no scan
- timed: a client without the aura API learns nothing and raises nothing

### test_style_bars.lua (50)

- bars: the element takes its configured size, and a left icon is a square of the bar's height
- bars: a right icon pins to the right edge and the bar stops short of it by the icon and its gap
- bars: without an icon the bar fills the whole element and the icon is hidden
- bars: the background sits under the bar area, never under the icon
- bars: the icon zoom crops the texture evenly from every side
- bars: draining left, the fill runs from the bar's start to the timer's edge and the spark rides its right end
- bars: draining right, the fill runs from the timer's edge to the bar's end and the spark rides its left end
- bars: the spark shows unless turned off, twice the bar's height, in its own width and color
- bars: with the timeless spark off, the live spark rides a clip frame bounded by the elapsed region
- bars: draining right, the clipped spark sits wholly on the elapsed side of the right-hand edge
- bars: with the timeless spark on, and in every preview, nothing is clipped and the spark stays centered
- bars: with the timeless spark off, the live clipped spark blends normally, not additively
- bars: with the timeless spark on, the live spark stays additive over the opaque fill
- bars: a non-engine dress (preview) always keeps the additive, centered spark, whatever sparkTimeless says
- bars: the clip-mode blend switch leaves the player's own spark color alone
- bars: a missing timeless-spark setting reads the template's
- bars: a timeless preview aura hides its spark when the option is off; a timed one keeps it
- bars: the texts sit above the spark's clip frame, which sits above the bar
- bars: a shown icon border frames the icon's box and the art insets by its size
- bars: a right-hand icon insets from the right edge
- bars: an icon border turned off, styled None or with no icon draws nothing and insets nothing
- bars: the icon border takes the class color through its own companion, and a missing size the template's
- bars: class colors paint the fill, background, spark and border with the dress's class, keeping each alpha
- bars: the class companions left off paint every surface its stored swatch
- bars: a missing bar opacity paints the template's, never a number restated in the composer
- bars: a missing border size paints the template's, so a border turned on still shows
- bars: a bar border shows only when turned on, with its style, size and color
- bars: the refresh-window highlight takes the pandemic color, never a class color
- bars: the name stops short of the time text, and runs to the bar's end when the time is hidden
- bars: each text shows or hides on its own setting
- bars: the stack count sits on the icon, or on the bar when there is no icon
- bars: the name and time are laid against the bar, in their configured corners
- bars: each text is boxed to its host less its offset: the bar area, or the icon for the stacks on it
- bars: beside the name the time is boxed to its format's widest string, so its justify shows and the name keeps its room
- bars: the engine drives the timer bar by elapsed time, eased only when smoothing is on
- bars: a hidden region is never handed to the engine
- bars: every shown region is bound to its own engine field
- bars: dispel coloring tints the fill through the engine with the stored dispel colors
- bars: switching Color by from dispel type back to static paints the bar's own color again
- bars: back to static on a button holding no aura, the fill the engine hid shows again
- bars: in dispel mode the engine's tint stays the fill's last color
- bars: the refresh-window highlight is bound only when turned on, and always cleared first
- bars: a preview fill is the remaining fraction of the bar area, net of the icon and its gap
- bars: a preview with a missing icon gap measures the template's gap, as the layout does
- bars: a missing icon size is the template's, in the layout and in the preview alike
- bars: a timeless preview aura draws a full bar with no time text, and an expired one keeps one pixel
- bars: preview text shows the name, whole seconds left, and stacks only above one
- bars: a preview fill drains from the configured side, spark at its leading edge
- bars: a dispel-colored preview paints the Magic color, since no real aura names a type
- bars: filling a preview element that was never dressed does nothing and raises nothing

### test_style_icons.lua (25)

- icons: the art sits inside a shown border, inset by the border's size
- icons: a hidden border, or the None style, leaves the art edge to edge
- icons: a square icon is zoomed evenly from every side
- icons: a wide icon is cropped top and bottom, a tall one left and right, never squashed
- icons: the border takes its style, size and color, and the dress's class when asked
- icons: a missing border size paints the template's, so the border and the art's inset still show
- icons: the cooldown draws a swipe in the configured opacity, its edge and direction on their settings
- icons: the cooldown turned off hides the swipe and never binds it to the engine
- icons: Blizzard's countdown numbers show only when asked for
- icons: the time and stack texts are laid against the icon's frame and show on their own settings
- icons: the time and stack texts are boxed to the icon's width less their offsets
- icons: a hidden text is never handed to the engine; a shown one is, as its own region
- icons: the dispel border is the engine's debuff art on harmful auras only
- icons: the dispel border keeps Blizzard's own colors; Dispel Colors drive bars only (G-3, owner 2026-09-13)
- icons: our border draws above the swipe, the dispel border above ours, the texts above all (I-1)
- icons: the dispel border's art reaches past the icon, as Blizzard sizes it, so its ring sits on the icon's edge
- icons: a non-square icon's dispel art reaches past it by a sixth of each side
- icons: the dispel border turned off is hidden and never bound
- icons: turning the dispel border off on a live button keeps it hidden (B-4)
- icons: the refresh-window highlight is bound only when on, in the pandemic color
- icons: an icon's buttons get the shared mouse behavior
- icons: a restyle re-dresses the regions it built, and builds none
- icons: a preview icon's cooldown starts as long ago as its placeholder has run
- icons: a timeless preview icon clears its cooldown and shows no time
- icons: filling a preview icon that was never dressed does nothing and raises nothing

### test_preview.lua (19)

- preview: every placeholder aura is drawn, each where Preview.Offset puts it against the anchor
- preview: the per-group cap limits the placeholders, and an enchant container shows at most two
- preview: a shown preview with nothing applied is left alone; an applied one is dressed again in the same frames
- preview: a lower cap hides the extra placeholders rather than leaving them drawn
- preview: Hide releases every placeholder, and the next Show dresses them again
- preview: a container whose settings are gone draws nothing and raises nothing
- preview: placeholders paint with the container's class snapshot, as its real buttons do
- preview: /am test shows placeholders on a locked addon, with the engine off and no drag handle
- preview: a vertical layout wraps into a new column one element's width plus the line spacing across
- preview: a missing layout block grows down and right from the top left with no spacing
- preview: switching Color by from dispel type back to static leaves no dispel tint on a placeholder (B-4)
- preview: switching a previewed container from bars to icons re-dresses without error
- preview: switching a previewed container from icons to bars re-dresses without error
- preview: a bar container duplicated while unlocked, then switched to icons, re-dresses (the owner's steps)
- preview: each style keeps its own pool, and a switch parks the other style's placeholders
- preview: a placeholder holds the mouse's hover as its container's buttons do, so no world tooltip shows through (L-3)
- preview: the extent covers the placeholder block from the corner it starts at, sized by Preview.Offset (L-4)
- preview: a real container's extent is a frame of ours under its anchor, kept when the preview hides (L-4)
- preview: under lockdown a placed extent stands, and one never placed is placed once (L-4)

### test_render_coverage.lua (2)

- coverage: every Bars row reaches a drawn region, on a live button and on the preview
- coverage: every Icons row reaches a drawn region, on a live button and on the preview

### test_blizzardframes.lua (8)

- blizzard: hiding moves the frame under a hidden parent of ours; restoring puts back the parent it had
- blizzard: applying twice remembers the first parent, so a restore never lands on our hidden frame
- blizzard: buffs and debuffs are hidden and restored independently
- blizzard: a frame the setting never hid is left where it is, whoever moved it
- blizzard: a frame that had no parent is restored to UIParent
- blizzard: a client without the frame, or a global that is not one, is skipped without raising
- blizzard: in combat nothing moves and Apply says it has to wait; with no profile, nothing is waiting
- blizzard: a profile switch applies the new profile's choice

### test_framepicker.lua (13)

- picker: the screen and the world are never a target, and the walk ends there
- picker: the walk climbs past one of this addon's own frames to a named frame above it
- picker: the walk gives up after thirty-two unnamed frames
- picker: hovering a named frame outlines it and names it beside the cursor
- picker: the label follows the cursor at the UI's scale
- picker: over nothing named the outline hides and the label says what to do
- picker: a frame the outline may not anchor to hides the outline instead of raising
- picker: the outline carries the template that lets it outline an aura container
- picker: a right-click cancels, and nothing is picked
- picker: a left-click over nothing named keeps the pick going
- picker: Escape keeps its key from the game for that press only, and cancels
- picker: any other key passes through and the pick continues
- picker: a new pick waits for the buttons to be released again before it can pick

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

### test_slash_verbs.lua (36)

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
- slash verbs: /am set on a free-text row stores every word typed after the path
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
- options: the Filters page offers the Overrides tab only for a buff or debuff container
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

### test_options_descriptor.lua (18)

- options descriptor: a rendered widget reads the selected container and writes it through the seam
- options descriptor: a color swatch shows the stored color and stores the picker's in the {r, g, b, a} shape
- options descriptor: a page's Defaults resets the page's session rows too
- options descriptor: Reset all writes only session rows through the seam and resets only the active profile
- options descriptor: Reset all never writes a Profiles-page row, live or degraded
- options descriptor: the degraded Reset all resets the profile whole and walks no profile-backed row
- options descriptor: the banner lists every container in display order and ignores a re-pick of the selection
- options descriptor: Containers' picker is a plain dropdown in the tab body that selects
- options descriptor: a container page draws its intro, then the bespoke tabs its container's type admits
- options descriptor: with no containers a page draws the one empty-registry line and no intro
- options descriptor: a page disabled for its container hands the disable to a bespoke tab, and lets go after
- options descriptor: RenderTabbedPage draws no banner; RenderContainerPage is the banner plus it
- options descriptor: an addon-wide tabbed page draws every tab with no container, and a bespoke tab keyed by a group takes its place
- options descriptor: a bespoke tab with `before` is drawn ahead of the tab it names, else last
- options descriptor: RenderWarnings draws one orange line per thing the engine will not do
- options descriptor: panel refreshes asked for in one frame are one refresh, on the next frame
- options descriptor: OpenOptionsPage opens a registered page's category and falls back to the panel otherwise
- options descriptor: the stub's composers emit the paths and types the live composers do

### test_pages_general.lua (36)

- general: the Enable checkbox writes the master switch through the seam
- general: the four show-or-hide master rows are visibility passes; Master scale re-applies
- general: the visibility dropdown offers the four states in order and stores the one chosen
- general: locking ends preview mode; unlocking leaves it alone
- general: the Debug console checkbox shows the window and writes nothing to the profile
- general: the Display tab's preview checkbox turns preview mode on for the session only
- general: Hide Blizzard buffs reparents BuffFrame away, and back to where it was
- general: the Blizzard-frame rows re-apply no container
- general: Reset position puts every container back on the screen
- general: Reset all settings asks first and resets nothing until the answer
- general: the Reset-all tooltip names the equivalence with Profiles -> Reset Profile
- general: the Reset-all popup carries options-ui-§12's wording and cannot be clicked through
- general: Defaults restores the General rows of the profile and no container setting, now that Containers is its own page
- general: the page's Defaults tooltip no longer mentions a container's identity (N-1: Containers is its own page)
- general: the tab strip reads Master controls, Display, Spell Categories, Dispel Colors — Containers is gone from it
- general → spell categories: a dropdown of the nine spell categories plus Weapon enchants, opening on the first
- general → spell categories: every starter is a toggle entry, ticked; nothing is removable yet
- general → spell categories: adding by id writes categorySpells whole through the seam, and Remove takes it off
- general → spell categories: a name resolves through the candidates — any category's starter, or a learned timed spell
- general → spell categories: typing lists the candidates — the profile's edits, every container's overrides, the learned timed buffs
- general → spell categories: a name only the candidates know resolves — another category's added spell, a spell on any container's overrides
- general → spell categories: picking a suggestion adds it through the one writer, exactly once
- general → spell categories: a name two ranks share lists both, labeled; Enter without a pick adds neither
- general → spell categories: the add line's tooltip and its refusal say where a name can come from
- general → spell categories: unticking a starter stores false; ticking it or adding it again drops the edit
- general → spell categories: choosing another category lists its starters, by name where the client knows them
- general → spell categories: Restore this category's starter list clears that category's edits and no other's
- general → spell categories: choosing Weapon enchants draws slot toggles, not a spell list
- general → spell categories: the Weapon enchants entry explains the all-slots fallback
- general → spell categories: unticking a weapon slot writes the profile, one row at a time
- general: Select moves the Spell Categories tab onto the given category, and ignores a key it cannot draw
- general: Select accepts the enchant key too, and lands the tab on it
- general → spell categories: the tab and Dispel Colors are drawn with no container at all
- general → dispel colors: six profile-wide swatches with no class-color companion, under a line saying they drive bars only
- general → dispel colors: a swatch writes its own type's color and re-applies every container
- general → dispel colors: the page's Defaults restores them

### test_pages_containers.lua (22)

- containers: registers its own top-level Blizzard category, with one tab, Containers (N-1)
- containers: NS.OpenOptionsPage('containers') opens its own category, not the main one (N-3)
- containers: the tab body opens with the Container picker and New container on one line
- containers: the picker retargets the tab and every page
- containers: New container creates a container and selects it
- containers: Delete keeps the picker and New through both refreshes, and the picker lists what remains (C-3)
- containers: with no containers the page draws the picker, New container and one line instead of the rows
- containers: the Name box renames the selected container, trimmed, and no other
- containers: /am reset container.name says a name has no default and changes nothing
- containers: a blank name is refused and the container keeps its name
- containers: a rename re-lists every picker and re-applies no container
- containers: the Unit dropdown offers the four units in order and writes the selected container
- containers: changing the aura type redraws an open Filters page for the new type, on the next frame
- containers: the Style dropdown offers bars and icons and writes the selected container
- containers: New and Duplicate in combat refuse in gray and create nothing
- containers: Duplicate copies the selected container and selects the copy
- containers: Delete asks first, naming the container, and deletes it only on Yes
- containers: the copy block offers every other container and copies only the chosen section
- containers: copying Everything takes what the source is, never its name or position
- containers: with one container the page offers Duplicate and Delete but no copy block
- containers: Defaults restores Enabled, Unit, Aura type and Style, and never the name
- containers: the page's Defaults tooltip says it takes the selected container's identity and keeps its name

### test_pages_filters.lua (38)

- filters: Cast by writes the selected container's filter and no other
- filters: a buff container's Categories tab offers the weapon-enchant rows; a debuff container's does not
- filters: a weapon-enchant container's hide-permanent row is a checkbox too, and stores a boolean
- filters: hidePermanentEnchants draws right under the Spell Categories grid, tied to Weapon enchants by name, ahead of the Uncategorized note (T-3)
- filters: a weapon-enchant container is offered one row on each of two tabs and no spell tabs
- filters: the max-auras description tells the truth about a group being per-shown-category, not the whole container
- filters: the sort-by and direction descriptions tell the truth about a group being per-shown-category, not the whole container
- filters: a max-duration preset writes the same path as the slider
- filters: a stored max-duration matching no preset leaves the preset dropdown blank
- filters: the max-duration description says there is no minimum
- filters: a buff container's Categories tab is two grids, Blizzard Categories then Spell Categories, each once
- filters: a debuff container's Categories tab is Blizzard Categories, Spell Categories, Dispel Types and Who Cast It, each once
- filters: every grid's columns are Show and Hide, then the category (schema v3)
- filters: the Spell Categories grid opens with a line naming where its lists live (F-2)
- filters: the 'these are the lists' line draws on a buff container and not on a debuff one, whose Spell Categories grid is Uncategorized-only (T-2)
- filters: the Uncategorized cost note draws on a buff container and not on a debuff one (review fix wave, item 2)
- filters: a spells-kind row's See spells link selects that category on General -> Spell Categories and lands there; a token row gets an info icon instead (F-3/N-3/N-4/N-5)
- filters: the priority order (spec §6) appears on both the Categories and the Overrides tab, highest rank first
- filters: the priority blurb is five separate lines, one per rank, identical on both tabs (T-2)
- filters: the retired 'Only these categories' row is gone — no such control on the Categories tab
- filters: a grid checkbox stores show or hide for the selected container and re-syncs its line
- filters: /am get and /am list print a category's state as Show or Hide
- filters: every category row is skipRender and names its grid
- filters: no aura type is offered a Spell lists tab; the lists live on General → Spell Categories
- filters: Overrides replaces Always / never, with a Whitelist and a Blacklist section
- filters: Overrides adds to one list at a time by id or by name, and Remove takes an id off
- filters: an Overrides name the game cannot find adds nothing and says why on the add line
- filters: an Overrides list suggests the profile's edits and the other list; a keyboard pick writes that list once
- filters: an Overrides name two ranks share is refused until one is picked, and the tooltip says where names come from
- filters: every tab opens with what the engine will not honor here, in orange
- filters: a plain whitelist entry with nothing to disagree has no note
- filters: a spell on both lists gets a note on its blacklist entry saying the whitelist wins
- filters: a spell on both lists gets a note on its whitelist entry naming the blacklist too
- filters: a blacklisted spell in a Show category names that category as overridden
- filters: a whitelisted spell every one of its categories would hide names them as overridden
- filters: a blacklisted spell a Hide category would also hide gets no note
- filters: an uncategorized blacklisted spell warns that no category hides it
- filters: a whitelisted spell no category claims, on a buff container, names Uncategorized instead of the generic rank-5 wording

### test_pages_layout.lua (22)

- layout: the tabs are Frame, Anchor, Growth, Mouse, in that order
- layout: the Anchor tab is broken into Screen, Another container, Named frame and Offset
- layout: Pick a frame sits beside Frame name in Named frame, and there is no Attach to the screen
- layout: in screen mode only the subsections that apply are enabled
- layout: in container mode only the subsections that apply are enabled
- layout: in frame mode only the subsections that apply are enabled
- layout: changing Attach to re-dims the same widgets before any redraw
- layout: Attach to writes the mode and redraws an open page on the next frame
- layout: the Container dropdown offers None and every other container, never the selected one
- layout: a target that would close a loop is refused; any other, or None, is stored
- layout: Frame name stores the typed name for the selected container
- layout: Pick a frame in combat refuses in gray and starts nothing
- layout: a pick attaches the container selected when it began, and reopens the page
- layout: a Growth write re-applies only the selected container
- layout: Strata offers the five layers in order and stores the one chosen
- layout: the Mouse tab's rows write the selected container's behavior
- layout: Defaults restores the selected container's placement and arrangement, and not its look
- layout: after the banner moves, the page draws the newly selected container's values
- layout: an attached container's Fill and growth are dimmed and show its parent's
- layout: a screen or frame container's growth rows are its own and live, with no follow line
- layout: the follow line is drawn on the Growth tab only
- layout: Another container names the derived points and the container it is attached to

### test_pages_bars.lua (11)

- bars: every tab of an icons container carries the orange notice; a bars container's carry none
- bars: on an icons container every row of every tab is drawn disabled; on a bars container none is (B-2)
- bars: the wrong-style notice is drawn large, then a spacer before the first control (B-2)
- bars: the Icon tab holds the icon's four rows, then the composed icon-border block (B-1)
- bars: the General tab's Spark subsection turns the spark off on auras without a duration (B-3)
- bars: the seven tabs are drawn in order, whatever the container shows (S-1: Size folded into General)
- bars: General opens on Size (Width, Height) ahead of Fill, with paths unchanged (S-1)
- bars: Width writes the selected container, and the page re-reads after the banner moves
- bars: a confirmed fill color is stored on the selected container, as a table of its own
- bars: Highlights carries no dispel swatches, and Color by points at General -> Dispel Colors (B-6)
- bars: Defaults restores the selected container's bar look and leaves its icon look alone

### test_pages_icons.lua (7)

- icons: a bars container's tabs carry the orange notice; an icons container's carry none
- icons: on a bars container every row of every tab is drawn disabled; on an icons container none is (B-2)
- icons: the wrong-style notice is drawn large, then a spacer before the first control (B-2)
- icons: the six tabs are drawn in order
- icons: Width on the Icons page writes the icon width, never the bar width
- icons: the Cooldown rows write the selected container's swipe
- icons: Defaults restores the selected container's icon look and leaves its bar look alone

### test_pages_about.lua (3)

- about: the landing page lists every slash command, in /am help's own words
- about: the Notes line is read from this addon's TOC when the page is drawn
- about: the logo is this addon's own art, shipped as a texture the client can load

### test_pages_profiles.lua (3)

- profiles: the page registers this database's AceDBOptions table under its own app name
- profiles: every render re-opens the dialog into the one container it built
- profiles: without AceConfigDialog the page opts out instead of failing on first show

### test_envsetup.lua (4)

- env: NS.Meta reads this addon's own manifest, by its folder name, on both arms
- env: the version is the TOC's where it can be read, and the fallback constant where not
- env: an empty TOC version falls back like an absent one, on both arms
- env: the version is never nil — '?' when neither the TOC nor the constant answers

### test_poolsetup.lua (4)

- pool: the live seam is the library's own pool, not the fallback
- pool: the fallback carries every member the preview calls
- pool: a released placeholder is reused rather than made again, on both arms
- pool: a re-dressed preview gets every placeholder back in the slot it held, on both arms

### test_defaults.lua (13)

- defaults: every starter container is a valid container whose every override the template knows
- defaults: every category carries what its kind needs, and a label and description
- defaults: spell categories are buff categories, and IsSpellCategory names exactly them
- defaults: uncategorized is declared LAST in both Cat.HELPFUL and Cat.HARMFUL (U-1, fix round 3)
- defaults: every leaf of the container template is edited by a settings row or is a spell set
- defaults: every profile default is a settings row, a spell set or the registry's own bookkeeping
- defaults: every dropdown's default is one of its choices
- defaults: every slider's default lies inside its range
- defaults: the dispel palette covers every dispel type, and the profile holds its own copy
- defaults: spell lists and dispel colors are profile-wide, never a container's (schema v2)
- defaults: one Healing category holds both retired healing lists, where Core healing was
- defaults: a container draws in the Medium strata, the default UI's own layer (X-3)
- defaults: the global schema stamp defaults to 1, never the current version

### test_perf.lua (8)

- perf: every declared bucket is reached by a real bracket
- perf: a dormant probe notes nothing
- perf: suspend makes the addon inert without a reload, and resume restores it
- perf: suspend holds a queued apply until resume
- perf: the buckets are declared in report order, and only the per-container apply nests
- perf: suspend and resume log to the console whatever the debug flag says
- perf: resume re-registers exactly the lifecycle events suspend took away
- perf: without the library, /am perf answers one honest line

### test_debuglogsetup.lua (8)

- debuglog: enabling logging writes the [Init] summary — name, version, schema, profile and container count
- debuglog: the flag is NS.State.debug itself — the sink and IsEnabled read it live
- debuglog: the chat acknowledgment goes through the addon's tagged printer; the console brackets both ends
- debuglog: showing or hiding the console refreshes open panels, so the Master controls row follows it
- debuglog: the Debug console row shows and hides the window and never touches the logging flag
- debuglog: Reset all closes an open console, because the console row carries a default
- debuglog: without the library, SetEnabled still flips the flag and acks, and says once that the window is gone
- debuglog: without the library the console row is honest — never checked, and its tooltip says why

### test_locale.lua (6)

- locale: every L[...] subscript in the source is defined in enUS.lua
- locale: every key enUS.lua defines is used somewhere in the source
- locale: no key is defined twice in enUS.lua
- locale: every enUS value is its own key, so the English build shows the source string
- locale: every string routed by value has its key — Constants labels, categories, filter warnings
- locale: every value is ASCII, the em dash excepted (T-1)

### test_docs.lua (7)

- README.md carries no angle-bracket argument placeholders
- the addon's own files use US spellings (localization-§5's canonical lists)
- the spelling gate is falsifiable: it flags a British word and passes its US twin
- every Tier 2 documentation-map row agrees with docs/
- every .md under docs/ appears in the documentation map
- docs: every file:line citation names an existing file and a non-blank line inside it
- docs: every file:line citation sits within 3 lines of a name its own sentence gives in backticks

### test_surface_parity.lua (4)

- parity: the Core stub publishes everything core/CoreSetup.lua publishes live
- parity: the DebugLog stub carries every member the addon calls
- parity: the Options stub carries every helper the host calls, off the load path as a no-op
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
| test_setups.lua | 14 |
| test_database.lua | 64 |
| test_schema.lua | 28 |
| test_schema_paths.lua | 36 |
| test_filtercompiler.lua | 74 |
| test_container.lua | 41 |
| test_containermanager.lua | 51 |
| test_compat.lua | 19 |
| test_secrets.lua | 3 |
| test_bus.lua | 5 |
| test_state.lua | 2 |
| test_lifecycle.lua | 10 |
| test_anchors.lua | 63 |
| test_style.lua | 43 |
| test_timedspells.lua | 19 |
| test_style_bars.lua | 50 |
| test_style_icons.lua | 25 |
| test_preview.lua | 19 |
| test_render_coverage.lua | 2 |
| test_blizzardframes.lua | 8 |
| test_framepicker.lua | 13 |
| test_slash.lua | 23 |
| test_slash_verbs.lua | 36 |
| test_bulklog.lua | 20 |
| test_optionssetup.lua | 17 |
| test_options_descriptor.lua | 18 |
| test_pages_general.lua | 36 |
| test_pages_containers.lua | 22 |
| test_pages_filters.lua | 38 |
| test_pages_layout.lua | 22 |
| test_pages_bars.lua | 11 |
| test_pages_icons.lua | 7 |
| test_pages_about.lua | 3 |
| test_pages_profiles.lua | 3 |
| test_envsetup.lua | 4 |
| test_poolsetup.lua | 4 |
| test_defaults.lua | 13 |
| test_perf.lua | 8 |
| test_debuglogsetup.lua | 8 |
| test_locale.lua | 6 |
| test_docs.lua | 7 |
| test_surface_parity.lua | 4 |
| test_vendor_sync.lua | 3 |
| test_lintconfig.lua | 5 |
| test_eol.lua | 1 |
| **Total** | **915** |
