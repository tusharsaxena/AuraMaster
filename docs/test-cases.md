# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below is the **authoritative pass count** — the README test
badge and any count quoted in the docs must agree with it.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_loadorder.lua (8)

- loadorder: the TOC lists the locale first and the Profiles page last
- loadorder: every TOC path exists, and none is a library
- loadorder: the load-bearing pairs are in order, and the TOC says why
- loadorder: GeneralDispel loads after GeneralSpells and before General
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

### test_launcher.lua (30)

- launcher: one broker object, of type launcher, registered with LibDBIcon under the FOLDER name
- launcher: Register is idempotent, so a second call builds no second button
- launcher: the icon is this addon's own 128 logo — the file ## IconTexture names
- launcher: the icon file ships as an uncompressed 32-bit 128x128 TGA
- launcher: the descriptor passes the three toggle pairs this addon has, and no retired field
- launcher: the LEFT click opens the settings panel and changes nothing else
- launcher: the LEFT click opens the panel while disabled too — it is where the addon is re-enabled
- launcher menu: titled with the brand, entries Enabled, Locked, Test mode, in that order
- launcher menu: every checkbox reads the live state when the menu opens
- launcher menu: Enabled calls the enable/disable handler, and prints what /am disable prints
- launcher menu: Locked calls the lock/unlock handler, and prints what /am unlock prints
- launcher menu: Test mode calls the /am test handler, through the switch the checkbox uses
- launcher menu: while disabled, Locked and Test mode are grayed and Enabled stays live
- launcher menu: on a client without MenuUtil the right click opens the settings panel
- launcher tooltip: enabled, locked, test mode off — the whole block, in the library's order
- launcher tooltip: every state is read on the show — unlock and test mode change the next hover
- launcher tooltip: shown while disabled, with the same two hints
- minimap row: composed, stored not session, default SHOWN, in its canonical position
- minimap row: the seam inverts — the row says shown, LibDBIcon's key says hidden
- minimap row: one record of one state — LibDBIcon writes the very table the row writes
- minimap row: Reset all settings and a profile switch both leave the button alone
- minimap row: the General page's Defaults button leaves the button alone and resets the rest
- minimap row: /am set and /am reset reach it through the same seam, inverted the same way
- verbs: /am enable and /am disable are aliases of the Enable row's path, holding no state
- verbs: the dispatcher answers while the addon is disabled, or the pair is one-way
- verbs: the launcher's menu, /am test and the Test mode checkbox are three doors onto one switch
- launcher: a host with neither broker library does not raise, and still records the choice
- launcher: with LibDataBroker but no LibDBIcon, the broker plugin still exists
- launcher: with LibKa0s absent the stub answers every member, and the row still stores
- parity: the Launcher stub carries every member of the live instance

### test_database.lua (73)

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
- v11: the current schema version is 11
- v3: RunMigrations migrates every stored profile, the inactive one included
- v4: a HELPFUL container with the toggle on ends up with Uncategorized hidden, and the dead key cleared
- v4: a HARMFUL container with the toggle on ends up with Uncategorized (debuffs) hidden, and the dead key cleared
- v4: a container with the toggle off or absent is untouched
- v4: an ENCHANT container with the toggle on is neither converted nor lost — it compiles to no groups, so nothing was ever lost
- v4: an unrecognized auraType with the toggle on is genuinely lost, named in lostList, and its dead key still cleared
- v4: MigrateV4 is idempotent
- v4: a genuinely lost container's notice reaches NS.Print, not just NS.Debug (item 3)
- v4: no notice is printed when nothing was lost
- database: a fresh profile seeds the Player cooldowns text container last, showing only two buff lists
- v5: an ENCHANT container becomes a player buff container showing only Weapon enchants, its look kept (feedback #6)
- v5: a whitelist on the ENCHANT container is cleared, so the migrated container draws no buffs (fix round 1, review Important #1)
- v5: a container with no filter table at all still converts cleanly (review Minor #2)
- v5: only ENCHANT containers are touched, and a second run changes nothing (feedback #6)
- v5: RunMigrations converts every stored profile, and the result draws enchants only (feedback #6)
- v5: MigrateV5 logs one [Migrate] line per converted container, naming it (feedback #6)
- v5: the profile's retired dispelColors.None leaf is cleared (feedback #7)
- database: GetContainersByName sorts by name, case-insensitively, the id breaking a tie; display order untouched (B2-2)

### test_database_categories.lua (22)

- v6: MigrateV6 stamps the user-category store, and a second run changes nothing
- v6: a profile that predates user categories climbs the ladder and stays valid
- v7: MigrateV7 retires Consumables and seeds the new categories from where their auras fell
- v7: the debuff-side Racials is Hidden wherever Hard CC or Soft CC is
- v7: a second MigrateV7 run changes nothing, and a new key's stored edit wins over a moved one
- v7: a v6 profile climbs to v7 with every schema row still resolving
- user categories: one round-trips through a reload, with its spells
- user categories: the sync runs BEFORE PrepareProfile, so a stored one reaches every container
- user categories: the schema row resolves, and the seam reads and writes it per container
- user categories: Cat.AuraTypeOf answers for a user category KEY, not only for its definition
- user categories: a profile switch swaps the set and leaves no stale definition, row or template key
- user categories: a new key collides with nothing shipped and with nothing in any stored profile
- user categories: a rename keeps the key, so a container's stored Show/Hide survives it
- user categories: a stored record alone protects its spell list from the categorySpells write
- user categories: deleting one clears the record, the list and every container's state, in the active profile and in an inactive one
- user categories: deleting one leaves a COPY of it in another profile entirely alone
- user categories: delete and rename are refused at the ACT for a shipped category, and the aura type has no setter at all
- user categories: the reserved namespace is what BOTH the rename and the delete rest on
- user categories: a record the sync cannot read can still be got rid of, and taking it leaves a shipped category alone
- user categories: a profile the sweep raises on costs its own leaves and nothing else
- user categories: the name cap counts characters, so a non-ASCII name is never cut mid-sequence
- user categories: a deleted category is gone from the grid and from the union, and Uncategorized is still last

### test_migrations.lua (28)

- migrations: NS.SCHEMA_VERSION is the runner's target, the last step's version
- migrations: a legacy v1 account with NO stamp runs every step
- migrations: a stored stamp survives the logout strip, so the next build's step runs
- migrations: every step is idempotent on a fresh default profile
- migrations: a step that raises leaves the stamp where it was and the addon loads
- migrations: an inactive profile is migrated too
- migrations: v8 zeroes the old 0/-4 offset on a container attached to another, and nothing else
- migrations: a v7 account climbs to v8 in every profile
- migrations: a new container's attach offset is 0/0
- migrations: v8 stamps Size to fit off on every stored Text container only, and keeps a stored value
- migrations: a v7 account keeps its hand-set text size; a fresh install's starters fit their content
- migrations: after v8 a new container and a new profile start with Size to fit on; a duplicate keeps its source's
- migrations: v9 removes Size to fit from bars and icons containers, and keeps every Text one
- migrations: a v8 account climbs through v9 in every profile
- migrations: a v1 account reaches v9 with Size to fit off on Text only
- migrations: v9 stamps attach.edge after-start where it is missing or unknown, and keeps a known one
- migrations: v9 resets a screen container's old 0/-4 to 0/0, and leaves frame and container offsets
- migrations: a v7 and a v8 account climb past v9 with every chain on after-start, Automatic since v11, and no screen 0/-4
- migrations: v10 stamps the attach side and resets a screen 0/-4 that an early v9 left
- migrations: v10 changes nothing on a profile a full v9 already migrated
- migrations: a v9 account missing both climbs through v10 in every profile
- migrations: a v8 account reaches v11 with the same result as one that climbed through a full v9
- migrations: v11 drops the default side and converts every other to the points it resolved to
- migrations: v11 converts to the very points ResolvedEdge and EdgePoints gave at v10
- migrations: v11 keeps points already stored and still removes the side
- migrations: a v10 account reaches v11 in every profile, each converted under its own chain
- migrations: v9, v8 and v1 accounts reach v11 with no attach side left and every chain Automatic
- migrations: on load a stored point that is not one of the nine is read as Automatic, and a known one kept

### test_schema.lua (33)

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
- schema: a row's own refusal reason travels as the third return of SetByPath and CheckWrite
- schema: with LibKa0s the bracket, registry and validator are the library's
- schema: the registry follows an insert and a removal, the library's and the host's
- schema: without LibKa0s the host arm still answers
- schema: -0 over 0 is still no change under SameValue

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

### test_filtercompiler.lua (85)

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
- filter: FC.IdsHonored is the CAN-EVER predicate — true wherever a spell list could ever bite
- filter: FC.IdsAlwaysHonored is the CERTAIN predicate — true only for buffs on the player and pet
- filter: a PLAYER debuff container with a non-empty union still gives Uncategorized Show no group — fix round 3's failure through issue #11's new door
- filter: a TARGET debuff container gives Uncategorized Show no group either — a target may be FRIENDLY
- filter: a FRIENDLY-target buff container loses the Uncategorized Show rescue — the accepted cost, pinned
- filter: a target debuff container still warns 'while the unit is hostile' although the gate dropped its Show group
- filter: a TARGET debuff container's spells-kind Show still emits its group, and warns — the accepted residual, pinned
- explain: an unlisted id is rank 3 (shown) when Uncategorized is Show — not the old rank 5
- explain: an unlisted id is rank 4 (hidden) when Uncategorized is Hide
- explain: with no Uncategorized category for the aura type at all, an unclaimed id is still rank 5
- explain: HARMFUL, Uncategorized Show (default): an unclaimed id is rank 5, not rank 3 — hasUnion is false, nothing to rescue
- explain: HARMFUL, Uncategorized Hide: an unclaimed id is rank 4, naming Uncategorized
- explain: HARMFUL with a non-empty union on the PLAYER: an unclaimed id is still rank 5, never a rescue the compiler does not compile
- explain: HARMFUL with a non-empty union on a TARGET: still rank 5, in lockstep with the gate
- explain: HELPFUL on a TARGET: the rescue the accepted cost gives up is not claimed here either
- filter: every unit/aura-type combination prints exactly the identity warning it printed before the predicate split
- filter: spell lists on your own debuffs are flagged as ignored
- filter: spell lists on a target's buffs only apply while it is friendly
- filter: the player's own buffs carry no identity warning
- filter: the weaponEnchants row decides the enchant slots, and adds no group
- filter: the enchant row does nothing on a debuff or a non-player container
- filter: the enchant slots the container draws are exactly the profile's, in a fixed order
- filter: an enchant-only buff container's slots also come from the profile, falling back to all three
- filter: max auras caps each group; 0 means no cap
- filter: max auras stamps EVERY group, not just the first — the cap is per group, not per container
- filter: an aura in a Show category is drawn even if it is also in a Hide category (rank 3 beats rank 4)
- filter: a Hide plus a Show yields a group per shown category plus the catch-all, with no aura drawn twice (R-4/R-5)
- filter: one Hide on the real shipped category list explodes to one group per other shown category — 17 for HELPFUL, 18 for HARMFUL today
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
- filter: the Player cooldowns starter draws one group per list it shows and no catch-all
- filter: a buff container showing only Weapon enchants draws the slots, no aura group and no never-matches warning (feedback #6)

### test_filtercompiler_categories.lua (9)

- categories: a user category joins the categorized union, so Uncategorized stops rescuing what it claims
- categories: a user category reaches the compiler as an ordinary spells-kind def of Categories.For
- categories: ClaimingCategories names every spells-kind category of the aura type that holds an id, in declaration order
- categories: ClaimingCategories is the same answer ExplainSpell gives, and the container's filter decides only the state
- categories: a user category alone on Show compiles to its group, with its own spell ids on it
- categories: a user category with an EMPTY list is the one shape that compiles to nothing, and it warns
- categories: an empty user category shown does not take Uncategorized's catch-all down with it
- categories: a user DEBUFF category alone on Show compiles the same way, and warns about hostility
- categories: a user category shown beside a shipped one gets its own group, after it and minus its ids

### test_container.lua (52)

- container: the engine is anchored before its first group and given its unit last
- container: a player buff container with enchants adds all three enchant slots
- container: a filter change is applied in place, sending only what changed
- container: a change of shape retires the engine and builds a new one
- container: toggling hide-permanent rebuilds the engine with the new flag
- container: a sort-direction change reaches the enchant sort in place
- container: a restyle re-dresses every button the engine has made
- container: nothing touches the engine while auras are secret, and it catches up after
- container: the show ladder — suspend, the master switch, the container switch, visibility
- container: test mode previews placeholders through the style code and disables the engine
- container: unlocked, a container shows whatever its visibility rule, its engine drawing, under an outline (B1)
- container: the unlocked outline under a secret anchor size draws strips and never raises
- container: test mode shows the placeholders while locked, whatever the visibility rule (B1)
- container: test mode off, a locked container set to never is hidden again (B1)
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
- container: a text template of a new shape rebuilds the engine; one of the same shape restyles it
- container: flipping Grow vertically retires the engine and pins the new one at the new corner, before its first group
- container: flipping Grow horizontally retires the engine and pins the new one at the new corner, before its first group
- container: a spacing, per-line or fill change keeps the corner and updates the engine in place
- container: a buff container showing only Weapon enchants draws the engine's three slots and no aura group (feedback #6)
- container: an enchant slot the engine refuses costs that slot, not the build
- container: an engine call that raises is traced, and the build carries on to the unit
- container: a restyle dresses every group button and every enchant frame, and skips a lookup the engine refuses
- container: a re-dress that raises is reported, a debug line each time and the client's error handler once per message (item 7)
- container: an instance whose container is gone applies nothing and touches no engine
- container: the anchor's scale is the container's times the master's, never below a tenth
- container: the anchor's alpha is the container's times the master's
- container: out-of-combat visibility shows out of combat and hides in it
- container: the class snapshot is the tracked unit's, and nothing for the player
- container: a class the client withholds resolves to no class instead of raising
- container: a button the engine creates is dressed with the container's class snapshot
- container: a live container has a mouse blocker covering its engine, below its buttons
- container: a shape change re-anchors the blocker to the new engine
- container: raising the anchor's level after the engine exists leaves the blocker strictly below it
- container: the blocker follows TakesHover and never takes clicks, matching the live buttons
- container: a live click-through flip re-gates the blocker without a rebuild
- container: a hidden container hides its blocker along with its engine, and Park hides it too
- container: on a client without the aura engine a container is deleted without error
- container: an engine whose frame level reads secret leaves the blocker at level 0, never raising (E)
- container: ApplyVisibility records the hang mode for test mode, unlocked and locked; Park and Destroy reset it

### test_containermanager.lua (53)

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
- manager: /am lock and a rename under lockdown print no deferral notice
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
- manager: an id that returns out of combat revives its destroyed instance
- manager: an id a profile reset hands out again out of combat revives its destroyed instance
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

### test_compat.lua (29)

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
- compat: a duration property reads the engine enum by member, and nil without it
- compat: a rule formatter is built with its breakpoints, and nil without the API or when refused
- compat: a duration binding writes nothing for a timeless or expired aura, and refreshes only when asked
- compat: the blink curve alternates the running-out color's alpha every quarter second, then the normal color
- compat: the mouse focus is the topmost frame GetMouseFoci returns
- compat: GetMouseFocus answers from GetMouseFoci and has no pre-11.0 rung
- compat: spell info comes from C_Spell, and the pre-11.0 global only when C_Spell is absent
- compat: spell info answers name then icon on a hit, and exactly one nil on a C_Spell miss
- compat: with LibKa0s a spell info hit is the major's six values, and a legacy miss one nil
- compat: without LibKa0s spell info is the major's absent answer, one nil
- compat: a dispel border color goes through AuraUtil, as the engine's PreserveAsset style paints it (DB-1)
- compat: without AuraUtil a dispel border color is DebuffTypeColor's, and nothing without either

### test_secrets.lua (6)

- secrets: without the client's secrets system nothing is secret and every value is readable
- secrets: issecretvalue alone decides access when canaccessvalue is absent, as a strict boolean
- secrets: canaccessvalue, when the client has it, overrides the secret test
- secrets: the guard trio answers the pinned matrix, one strict boolean each
- secrets: with LibKa0s present the three guards ARE LibKa0s-Compat-1.0's
- secrets: without LibKa0s the host's guard bodies answer the same pinned matrix

### test_bus.lua (8)

- bus: every message name carries this addon's prefix and no two share one
- bus: the catalog is exactly these four keys and wire names
- bus: a key the catalog never declared raises, for a publisher as well as a subscriber
- bus: without LibKa0s the catalog is the same four pairs, as a plain table
- bus: two receivers on their own targets both hear one message, with its payload
- bus: CONTAINERS_CHANGED goes out once per registry act, and never for a refused one
- bus: world entry and each combat edge send one VISIBILITY_CHANGED; a unit swap sends none
- bus: a CONFIG_CHANGED the receiver cannot read re-applies the container it names, or every one

### test_state.lua (2)

- state: the session flags start off, are never saved, and a reload starts them clean
- state: test mode is session-only and off at login; unlocking keeps real auras drawing (B1)

### test_lifecycle.lua (15)

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
- lifecycle: the degraded latch stands up and down only on an edge
- lifecycle: one bad event name leaves the other seven registered and is recorded
- lifecycle: one bad event name, on a client without C_EventUtils, is caught by the probe rung
- lifecycle: a rejection while logging is on is traced at the moment it happens
- lifecycle: the degraded Core stub's SafeRegisterEvent records a bad name and keeps the rest

### test_anchors.lua (77)

- anchors: a chain that would loop is detected
- anchors: a container attaches to another one, and a loop falls back to the screen
- anchors: a named frame that does not exist yet waits, and attaches once it does
- anchors: a frame that appears during combat is attached when combat ends
- anchors: a screen fallback and a skipped resolve are traced
- anchors: a forbidden frame, or something that is not a frame, is never a target
- anchors: a forbidden frame falls back to the screen without waiting, so an add-on load never re-places it
- anchors: a drag saves the dragged container's position, rounded, whatever is selected
- anchors: a drag saves the position in one write
- handle: a dark strip with a 1px gold edge, a gold label and the catalog help mark
- handle: under a secret anchor size it builds, resizes and draws its edge without arithmetic
- handle: above the anchor when auras grow down, below when up, edge-aligned where they start
- handle: at least as wide as its container's element, and as its label with room for the help mark
- handle: while shown the anchor's clamp rect takes it in; hidden, or in combat, the rect is left alone
- handle: under lockdown a changed layout does not re-place the handle; the next pass after it does
- handle: a handle first shown under lockdown is placed once; the anchor's clamp still waits
- handle: a visibility pass that changes nothing re-sets no clamp insets
- handle: the help mark carries the tooltip and right-click opens the settings on this container
- handle: the tooltip follows the cursor, owned by UIParent, never anchored to the strip or the mark
- handle: a left-drag that starts on the help mark moves the container as one on the strip does
- handle: with no media catalog the help mark falls back to Blizzard's information icon
- handle: with LibKa0s absent a container has no handle at all, and every pass over it is a no-op
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
- anchors: derived points do not depend on the parent's fill axis
- anchors: a container attached to an icon row stacks below it, on the side its rows start from
- anchors: an attached container flows as its parent does, and its own flow stays stored
- anchors: a chain inherits its root's flow; a broken or looping chain stops where it breaks
- anchors: a container attached to another takes derived points from the parent's flow
- anchors: a frame-attached container keeps its stored points
- anchors: the engine's flow, the placeholders and the handle all read the inherited flow
- anchors: detaching a container restores its own stored flow at the next apply
- anchors: a write that moves a container's flow re-applies every container following it
- anchors: a parent's growth flip rebuilds its follower's engine, pinned at the derived corner, and re-anchors it to the parent's new engine
- anchors: while its parent previews, an attached container hangs from the parent's preview extent, not its engine (L-4)
- anchors: ending test mode re-anchors an attached container off the extent, and starting it back to the extent (L-4)
- anchors: under lockdown ending test mode leaves an attached container where it is; the pass after combat moves it (L-4)
- handle: an attached container's strip sits above every placeholder of the container it is attached to (L-4)
- handle: the width comes from a detached measuring string, never the label, which may sit on secret geometry (E)
- handle: a measured width that reads secret falls back to the element's width, never raising (E)
- handle: an anchor whose frame level reads secret places the strip from the stored level (E)
- handle: an attached container's strip falls back to the stored level when its target's frame level reads secret (E)
- anchors: a drag whose offsets read secret saves nothing (E)
- handle: while test mode is on the label carries an orange TEST tag after the name; off, the name alone (feedback #8)
- handle: a right-click on the ? opens the Containers page with this container selected in its band (feedback #9)
- handle: under combat lockdown the right-click is refused in gray and selects nothing (feedback #9)
- handle: an attached container's name is a desaturated gray, to the screen it keeps the plain color (owner, 2026-09-26)

### test_anchors_seam.lua (10)

- seam: SeamOffset leaves one of the child's gaps in the direction the chain stacks
- seam: a child attached below a column leaves its own spacing, and its X/Y nudge on top
- seam: a chain growing up leaves the gap upward, so the child never overlaps its parent
- seam: a child attached below an icon row leaves its own line spacing
- seam: the gap is the child's spacing, never the parent's
- seam: a frame-attached container keeps its stored offsets and takes no gap
- seam: a container whose target cannot be used sits at its screen position, with no gap
- seam: while the parent previews, the child hangs from its extent with the same gap as locked
- seam: an attached child's strip sits before its own block, in its own column (batch 10 F1)
- seam: a screen container's strip keeps its place above or below its auras

### test_anchors_edges.lua (15)

- edges: EDGES lists the nine tokens, after then ahead then behind, and no before or center side
- edges: EdgePoints gives the design table's pair for every token and growth
- edges: EdgePoints(L, 'after-start') is exactly the old DerivedPoints for all 8 axis, growH and growV combinations
- edges: every one of the nine is allowed, behind on a wide child too; only a non-token is not (G5)
- edges: SeamOffset leaves the child's own gap across for a side, and after is unchanged (AP-2)
- edges: a side-attached child is placed at its edge's points with its gap across and the nudge on top
- edges: flipping the root's growth mirrors an Automatic child; an explicit pair stays and takes the seam of the side it now is
- edges: a side-attached follower of a follower takes no strip room; an after one does (AP-2)
- edges: the default side follows a Text container's justify; a bars child under a bars parent is after-start (E5, G3)
- edges: an attachment writes no points: a centered Text container attaches Automatic, on after-center (G2, G3)
- edges: picked points survive an attach, a retarget and a detach and re-attach
- edges: a write to either point, the mode or the container re-applies the followers and the parents (AP-4)
- anchors: FlowChangeOnAttach is nil when nothing would change or nothing is usable
- anchors: FlowChangeOnAttach names the keys that change and the followers that re-flow too
- anchors: FlowChangeOnAttach compares with the target's chain root, not the target

### test_anchors_hang.lua (11)

- hang: unlocked and not in test mode, an attached container hangs from its parent's one-element anchor, not its empty engine
- hang: a chain 3 -> 2 -> 1 unlocked: 3 hangs from 2's anchor, 2 from 1's
- hang: locking re-anchors followers onto the parent's engine, unlocking puts them back; a pass that changes nothing re-places nothing
- hang: unlocked, ending test mode moves followers from the preview extent to the parent's anchor, and starting it moves them back
- hang: under lockdown a lock leaves a follower where it is; the pass after combat moves it
- hang: three empty Text containers chained and unlocked: no two strips overlap, and each sits between its parent's block and its own
- hang: the room for a strip is the follower's own: unlocked it adds its strip's row to the seam, locked the seam alone (F2)
- hang: locked, a follower of a follower keeps its own seam: no strip shows, so none needs room
- hang: in test mode a chain leaves the same room for its strips (EO-2)
- hang: a test-mode chain locked shows no strips and keeps its own seams
- hang: HangMode reads the recorded mode, and before any visibility pass falls back on the preview

### test_emptywatch.lua (25)

- empty: a token-only group holding an aura is not empty, asked with a count of one
- empty: a token-only group with nothing to show is empty
- empty: a unit that does not exist is empty without reading an aura
- empty: a readable pool of 0 is empty without reading an aura
- empty: an include id hits and misses
- empty: spell ids are ignored on a hostile target's buffs, as the engine ignores them
- empty: a max duration drops a permanent aura and one that runs longer
- empty: dispel types include and exclude
- empty: a flag the aura data does not carry is not knowable
- empty: a read that raises, a secret field and secret auras are not knowable
- empty: weapon enchants present, absent, and permanent under Hide permanent
- empty: an enchant on a container with no aura is not empty even when its unit's auras are unknowable
- empty: unlocked and predicted empty, the follower hangs from the slot and the placeholder shows
- empty: a parent that gains an aura moves its follower onto the engine and hides its placeholder; losing it moves it back
- empty: a prediction that is not knowable hangs from the engine with the placeholder hidden
- empty: 50 UNIT_AURA events cost one pass
- empty: PLAYER_REGEN_DISABLED puts every follower on the engine before lockdown, and combat's end brings the slot back
- empty: under lockdown nothing is re-placed, whatever the prediction
- empty: an oil on the weapon arms one pass at its expiry, and the lapse brings the placeholder back
- empty: UNIT_AURA is heard only while unlocked, and a lock drops it
- empty: target and focus are heard on a second frame only while a target or focus container shows
- empty: test mode, secret auras and a stand-down each drop UNIT_AURA
- empty: the player frame filters UNIT_AURA alone; pet and inventory changes ride AceEvent
- empty: a target switch re-predicts at once, so no follower hangs from the emptied engine in between
- empty: a target switch folds a pass already due into its own, leaving no timer behind

### test_anchors_close.lua (6)

- close: the X sits immediately left of the help mark, the catalog close glyph at the help mark's size
- close: with no media catalog the X falls back to the library's Blizzard stop button
- close: a left click disables THIS container through the write seam and says how to bring it back
- close: a right click on the X opens the settings like the strip and the ?, and disables nothing
- close: in combat the X still disables the container, raising nothing and moving no anchor
- close: the X's tooltip names the container (following a rename) and says how to turn it back on

### test_anchors_label.lua (23)

- label: the template carries label = { show = false, justifyH = AUTO, x = 0, y = 0, font = gold Friz 12 OUTLINE }
- label: a stored container without a label gains the whole block, and a stored one survives the backfill
- label: off by default, no label frame is ever built
- label: on and locked, the name shows in a plain, mouse-less frame; turned off it hides
- label: unlocked, the label AND the strip both show, the strip moved out past the label (D6)
- label: the strip's clamp reaches over the label too while both show
- label: test mode shows it, locked or not; visibility never, disabled and the stand-down hide it
- label: Park and Destroy hide it
- label: a visibility pass under lockdown moves a placed label not at all; a never-placed one is placed once
- label: growing right and down it sits where the strip does, plus its X/Y, text justified LEFT
- label: growing left and down it sits where the strip does, plus its X/Y, text justified RIGHT
- label: growing right and up it sits where the strip does, plus its X/Y, text justified LEFT
- label: growing left and up it sits where the strip does, plus its X/Y, text justified RIGHT
- label justify: with no pick, Bars and Text center the name on its host, whatever the growth
- label justify: a pick wins over the style default, Left and Right inset 4, Center none
- label justify: an icons pick holds when the growth flips; AUTO goes back to the style default
- label justify: LabelJustify answers the style default for nil, AUTO and an unknown stored value
- label: a container attached to another puts its label on its own block's before side, like a root's; the strip moves out past it
- label: a follower's follower makes room for its own strip, not for its parent's label and strip
- label: a rename lands on the label at once, also under lockdown, with no apply queued
- label: Copy settings copies the label section and not the name; Everything includes it
- label: its class color makes a tracked container re-apply on a unit swap, only while the label shows
- label: ApplyFont paints an explicit class, falls back to the swatch for none, and keeps its three-argument path

### test_anchors_strip.lua (7)

- strip: a behind follower's strip sits before it, lined up with the edge that faces its parent, so it runs away from it
- strip: a behind follower's before strip clamps over its own column, not toward its parent
- strip: an icons label mirrors only for a behind follower, whose strip lines up with the edge facing its parent
- strip: no join dot is built for a container joined to another, unlocked or in test mode
- strip: the tooltip of a container joined to another names the parent's point and the parent
- strip: in test mode the outline encloses the whole placeholder block, locked or not; locked outside it, none
- strip: the test-mode outline moves no follower: the seam is the same locked and in test mode (SS-3)

### test_anchors_column.lua (19)

- column: an after follower's strip sits before its own block, like a root's, mirrored by the growth
- column: a follower's strip stays before it whatever other followers hold its sides
- column: unlocked with the label on, a follower reads strip, label, block before its own block
- column: locked with the label on, a follower's label sits on its block's before side, not beside the column
- column: a label is justified inside its own block per LJ-1, with no mirror for an after follower
- column: an after follower sits past its parent by its own strip's room while unlocked, and by the seam alone locked
- column: the label's row counts locked and unlocked, the strip's only while it shows
- column: growing up, the chain spreads upward, the furniture below each block
- column: the X/Y nudge adds on top of the spread seam
- column: a lock or unlock re-places a follower through its own visibility pass, and a repeat pass re-places nothing
- column: under lockdown the seam waits; the first pass after combat catches up
- column: RefreshSeam allocates nothing when the seam already fits
- column: test mode, unlocked, spreads the chain the same way and hangs from the preview block
- column: the owner's Text chain reads strip, block, strip, block, strip, block in one column
- column: an ahead follower is pushed along the growth past its parent's strip and label while that strip runs over it
- column: an ahead follower clears its parent's label row, locked or not, since a long name runs on over its column
- column: an ahead follower stays level when its parent's strip fits its own block, and growing up it is pushed upward
- column: a behind follower keeps its strip before it, lined up with the edge facing its parent, and is never pushed
- column: a follower of a side follower spreads by its own strip, as any after follower does

### test_anchors_points.lua (16)

- points: a bars or icons child under a bars or icons parent defaults to after-start, under every growth
- points: an icons or bars child under a Text parent justified CENTER is centered; LEFT or RIGHT is not
- points: a Text child lines up with its own justify, whatever the parent, and flips with growH
- points: the default follows the chain root's growth, not the child's own stored growth
- points: an explicit pair is used as stored, and does not mirror when the growth flips
- points: one explicit point keeps the other automatic, as the matching half of the default pair
- points: a stored point that is not one of the nine reads as Automatic
- points: a stored attach.edge is not read outside the migration
- points: AttachEdge classifies the pair in effect as one of the nine tokens, or nil when free
- points: a classified explicit pair is placed exactly as batch 10 places its token
- points: behind is no longer refused: a child several auras wide sits on its behind pair
- points: a free pair is placed at X/Y alone: no seam, no spread, no push
- points: an after pair spreads by the child's furniture while unlocked; the free pair beside it does not
- points: a free follower's strip and label sit on its own before side, lined up with H0
- points: a write to either point, a style or a text justify re-applies the followers
- points: AttachPoints and AttachEdge allocate nothing

### test_anchors_steady.lua (7)

- steady: the owner's centered chain growing up lands on the same x with its parent's engine empty as populated
- steady: an end join (right) holds too, and growth left mirrors both
- steady: hanging from the parent's one-element anchor (slot) or its preview gives the same place
- steady: a parent one row across (icons filling a row) is steady on y for a side join centered
- steady: a parent more than one element across is not rewritten on that axis
- steady: parent and child at different scales convert the offset to the child's scale
- steady: start-aligned pairs are placed as before, along the chain and across it

### test_anchors_width.lua (6)

- width: a long name on a wide Bars container gives a strip exactly as wide as its bar, the name shortened with ...
- width: in test mode the name is shortened, never the TEST tag, which stays after it
- width: a name that fits is drawn whole, the strip still the bar's width
- width: the full name stays the strip's tooltip title
- width: a one-icon container too narrow for the marks and a readable label keeps its natural width
- width: the label is worked out once per name and width, not on every pass

### test_texttemplate.lua (26)

- template: an unknown token is refused, naming it and every known token (rule 1)
- template: a lone $ with no closing $ is literal text (rule 1)
- template: a token used twice is refused (rule 2)
- template: a token between two duration tokens is refused, naming it (rule 3)
- template: nested and unmatched brackets are refused (rule 4)
- template: a [ ] group holds exactly one of stacks, dispel type or the duration run (rule 4)
- template: a bracket around the duration run must hold all of it (rule 5)
- template: { and } are refused inside the duration run and its bracket, allowed elsewhere (rule 6)
- template: an empty template, or one with no token, is refused (rule 7)
- template: longer than 200 characters is refused (rule 8)
- template: the first broken rule is the one reported
- template: [[, ]] and $$ write a literal [, ] and $
- template: an odd run of [ opens with its first, an even run is all escapes (]] ]  mirror)
- template: tokens are case-insensitive
- template: the default template folds its bracket text into the stacks and duration pieces
- template: the name alone is one piece, and single
- template: a duration run keeps its inner text in the format, one component per token
- template: a bracketed duration run carries the bracket text in its format
- template: a % in a stacks bracket is doubled in the rule format and kept in pre/post
- template: a dispel type keeps its bracket text as pre and post
- template: adjacent literals merge into one piece, and none is empty
- template: compiled results are memoized per template string
- template: Validate answers true, or false and the refusal
- template: ForDraw draws a refused stored template as the default one, and says it fell back
- template: every built-in compiles, and each aura type's list is the pinned one
- template: a stored template matches a built-in by its text and its justify rule, else none

### test_style.lua (60)

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
- style: a Solid border is four strips between the frame's corners, never a backdrop (B2-3)
- style: a tint edge lays the Solid border's four strips, white, untinted and hidden, for the engine to show (DB-1)
- style: a Solid border takes the class color through its companion (B2-3)
- style: a Solid border under a secret size draws and never raises (B2-3)
- style: another style draws a backdrop on a frame of its own, with its edge, size and color (B2-3)
- style: another style applies its backdrop once per edge and size, and again when either moves (B2-3)
- style: another style under a secret size keeps its last backdrop and only recolors (B2-3)
- style: a backdrop frame first made under a secret size applies nothing until its size reads plain (B2-3)
- style: switching between Solid and another style hides the other drawing (B2-3)
- style: another style on a client without the backdrop mixin draws nothing and never raises
- style: a binding the client lacks is skipped, and one it refuses costs that binding alone
- style: a class color is looked for only in the active style's block, text blocks included
- style: a dispel color map holds a color per stored type, and nothing for a leaf that is not a color
- style: a dispel color map's None entry is the surface's own color, and every entry opaque (feedback #7, item 4)
- style: tooltips and click-through decide whether a button takes the mouse at all
- style: right-click cancel reaches the player's buffs and their enchant slots, never the player's debuffs, and never when turned off
- style: the tooltip anchor and in-combat hiding come from settings, the template filling a missing anchor
- style: the time text gets the engine's formatter for its format, and the expiring color at its threshold
- style: a placeholder's time text is what its format's formatter writes, the one the engine is handed (B-5)
- style: a placeholder running out takes the running-out color, as the engine's curve paints a live one (B-5)
- style: at the default threshold one placeholder is running out, so turning the color on shows (B-5)
- style: a style leaf left nil draws the template's value, never a literal of its own
- style: a frame dressed as a bar, then as an icon, builds icon regions and hides the bar's
- style: hiding the other style's regions never hides the element itself
- style: a text element takes its size from its own block, and a missing leaf from the template
- style: a text container's class color is looked for in its text block, the font included
- style: a duration run's text format has its format string and one component per token, built once
- style: a duration run binds its format and binding, recolored only when asked, blinking only when asked
- style: a placeholder's seconds are written by the format's formatter, else as whole seconds
- style: a client that refuses the percent rule's step gets the plain "%d" rule, never none (feedback #5)
- style: no format Aura Master itself authors carries a leading or trailing space (feedback #5)

### test_castaura.lua (7)

- castaura: an id the table has never heard of is stored exactly as typed
- castaura: a trigger-derived id is rewritten to its aura, and the player is told
- castaura: a name-derived id is NOT rewritten — the candidates are offered
- castaura: a stored entry that can never match carries a note
- castaura: an absent or empty table says nothing about any id
- castaura: the help lines come with a severity — red for never-matches, the caller's for its own line
- castaura: a non-number is not resolved

### test_timedspells.lua (22)

- timed: nothing is needed until a container shows only timeless auras
- timed: it hears UNIT_AURA only while needed and readable
- timedspells: UNIT_AURA is registered for player and pet only, on the module's own frame
- timedspells: disable unregisters the unit frame and enable reuses it
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
- timed: a client that refuses UNIT_AURA leaves TimedSpells not listening, and the rest loads

### test_style_bars.lua (63)

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
- bars: with the timeless spark off, the live clipped spark stays additive
- bars: the spark's blend never depends on sparkTimeless or engine
- bars: the spark art is desaturated so its hue is the player's sparkColor
- bars: the neutral additive spark leaves the player's own spark color alone
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
- bars: beside the name the time is boxed to the measured width of its format's widest string (B4)
- bars: a measurer answering no width, refusing the font or raising gives the ems budget and caches nothing
- bars: where nothing can be measured the time keeps its ems budget
- bars: the engine drives the timer bar by elapsed time, eased only when smoothing is on
- bars: a hidden region is never handed to the engine
- bars: every shown region is bound to its own engine field
- bars: dispel coloring tints the fill through the engine with the stored dispel colors
- bars: Color by dispel type on the background tints it through the engine, no type keeping the background color (feedback #7)
- bars: a dispel-colored background carries its opacity times its color's alpha on the region, the map opaque
- bars: a dispel-colored fill carries its opacity times its color's alpha on the region
- bars: a static background and fill keep the opacity on the region and the color's alpha on the color
- bars: switching Color by from dispel type back to static paints the bar's own color again
- bars: back to static on a button holding no aura, the fill the engine hid shows again
- bars: in dispel mode the engine's tint stays the fill's last color
- bars: switching Color by from dispel type back to static on the background paints the background's own color again (feedback #7)
- bars: back to static on a button holding no aura, the background the engine hid shows again (feedback #7)
- bars: the refresh-window highlight is bound only when turned on, and always cleared first
- bars: with the time's class color on, the running-out curve returns to the class color, one curve per container
- bars: a live re-dress with both borders on under secret geometry draws them and re-binds everything (B2-3)
- bars: a border the client refuses costs that border alone: every binding still runs, and it is reported (B2-3)
- bars: a preview fill is the remaining fraction of the bar area, net of the icon and its gap
- bars: a preview with a missing icon gap measures the template's gap, as the layout does
- bars: a missing icon size is the template's, in the layout and in the preview alike
- bars: a timeless preview aura draws a full bar with no time text, and an expired one keeps one pixel
- bars: preview text shows the name, whole seconds left, and stacks only above one
- bars: a preview fill drains from the configured side, spark at its leading edge
- bars: a dispel-colored placeholder paints its own type's palette color, and one with no type the surface's (TD-4)
- bars: an untyped dispel-colored placeholder keeps the container's class snapshot, not the player's (TD-4)
- bars: filling a preview element that was never dressed does nothing and raises nothing

### test_style_icons.lua (31)

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
- icons: the dispel border is our four strips, tinted by the engine (PreserveAsset), on harmful auras only (DB-1)
- icons: the dispel border keeps Blizzard's own colors; Dispel Colors drive bars only (G-3, DB-2)
- icons: our border draws above the swipe, the dispel border above ours, the texts above all (I-1)
- icons: the dispel strips take our Solid border's exact shape and thickness (DB-1)
- icons: the dispel strips follow Border thickness on every dress (DB-1)
- icons: a hidden border, the None style or 0 thickness draws the dispel edge at 1 px (DB-2)
- icons: a non-Solid border style still takes flat dispel strips at its thickness (DB-2)
- icons: the dispel border turned off is hidden and never bound
- icons: turning the dispel border off on a live button keeps it hidden (B-4)
- icons: the refresh-window highlight is bound only when on, in the pandemic color
- icons: an icon's buttons get the shared mouse behavior
- icons: a restyle re-dresses the regions it built, and builds none
- icons: a live re-dress with the border on under secret geometry re-binds the highlight and the time color (B2-3)
- icons: a border the client refuses costs the border alone: every binding still runs, and it is reported (B2-3)
- icons: a live resize under secret geometry runs no backdrop arithmetic (B2-3)
- icons: a preview icon's cooldown starts as long ago as its placeholder has run
- icons: a timeless preview icon clears its cooldown and shows no time
- icons: filling a preview icon that was never dressed does nothing and raises nothing
- icons: a debuff placeholder tints its dispel strips in Blizzard's color for its type; a buff, an untyped one or the option off shows none (TD-4, DB-1)

### test_style_text.lua (55)

- text style: the element takes its size; clip, animation and text-area frames nest inside it
- text style: Left lays the first piece at the area's left and each next piece against the previous one
- text style: Right lays the last piece at the area's right and each earlier piece against the next
- text style: the vertical justify picks the top, middle or bottom anchor points
- text style: each chained piece is pulled back over the previous one by the measured padding (item 8)
- text style: a padding that cannot be measured chains at 0, and is measured again later (item 8)
- text style: the padding is measured once per font, size and flags (item 8)
- text style: every piece is justified to its side of the chain; a stacked row is centered (item 8)
- text style: Center centers a one-piece template as one line, exactly as before (feedback #1)
- text style: Center stacks a multi-piece template, each field a row centered under the last; literals are not drawn (feedback #1)
- text style: a stacked line's element grows to its rows; Left and Right keep the stored height (feedback #1)
- text style: the vertical justify places the stack at the top, middle or bottom of a taller box (feedback #1)
- text style: a line moved off Center draws its literals again (feedback #1)
- text style: every piece takes the line's font; a literal takes its text
- text style: each engine piece is bound to its own field, a literal to none
- text style: stacks bind a rule formatter that hides one stack and folds the bracket text
- text style: dispel type binds a text map of every type in the bracket text, nothing without a type
- text style: the duration run binds its format, components and a prebuilt binding that writes nothing when timeless
- text style: blink binds the blinking curve and a 0.1 s refresh; off, neither
- text style: with the font's class color on, the running-out curves return to the class color, one curve per container
- text style: a class snapshot that changes in place builds a new curve, never reuses the old class's
- text style: a loop setter that raises cannot cost the engine bindings: the fields are bound first
- text style: two buttons of one container get distinct prebuilt duration bindings
- text style: a live re-dress for a new shape binds the new chain's strings, not the parked chain's
- text style: a template without a duration token binds no duration text
- text style: a preview dress binds nothing
- text style: the three loops are built once, looping as each effect needs, and None plays none
- text style: each effect plays its own loop with the speed, fade and height set
- text style: an icon on the left sits on the animated frame and the text area starts after it and its gap
- text style: on a stacked Center, icon size 0 is ONE ROW's height, not the whole stack (fix round 1, feedback #1)
- text style: an icon on the right insets the area's right edge; none hides it and binds nothing
- text style: a left icon with its border on draws the border at its edge size and color, the art inset inside it (item 6)
- text style: an icon border the client refuses on a live re-dress costs the icon, never the text, and is reported
- text style: an icon whose SetSize is refused on a live re-dress costs the icon, never the text, and is reported
- text style: the same refusal on every re-dress reaches the error handler once, and the debug log each time
- text style: a live re-dress with the icon border on under secret geometry draws the border and reports nothing (B2-3)
- text style: a refused stored template draws the default one and logs it once
- text style: a template edit that keeps the shape re-dresses the same strings; a new shape swaps chains
- text style: the structure key carries the template's shape, so a live shape change gets new buttons
- text style: Style.Element dresses a text container through Style.Text, bound and unbound, without raising
- text style: bars, then text, then bars again keeps each style's regions, hidden while the other draws
- text style: a placeholder fills each piece as the engine would
- text style: a stacked line previews as its field rows, one per line, without its literals (feedback #1)
- text style: a placeholder's percent is the nearest whole number, as the engine's step rule rounds it (feedback #5)
- text style: a placeholder hides a single stack, a missing dispel type and a timeless duration with their bracket text
- text style: a placeholder running out takes the running-out color on its duration piece only
- text style: Color the dispel type writes each word in its palette color inside the bracket text (feedback #7)
- text style: a colored dispel map is built once per look, and a new palette color rebuilds it (feedback #7)
- text style: the dispel tint map is built once per look, and a new palette color rebuilds it too (feedback #7, fix round 1)
- text style: the dispel backdrop fills the text area and is tinted through the engine, for a typed aura only (feedback #7)
- text style: the dispel edge is four strips of its thickness around the text area, each tinted through the engine (feedback #7)
- text style: a placeholder with a dispel type shows the backdrop and edge in its palette color; one without shows neither (feedback #7)
- text style: an Enrage aura shows no visible backdrop or edge, live or in the preview (fix round 1, feedback #7)
- text style: a placeholder's and the Preview box's dispel word take its palette color when the option is on (feedback #7)
- text style: a debuff placeholder's dispel word and tints follow its own type, and the untyped one shows neither (TD-4)

### test_style_text_autosize.lua (18)

- autosize: off, the element keeps its stored size, and a stacked Center still grows (AS-3)
- autosize: the template turns it on; a new container reads the template's true (AS-1, AS-3)
- autosize: on, the width is the widest placeholder line plus |x| and 2, the height the font plus padding (AS-2)
- autosize: the width is clamped to the Width row's range
- autosize: a debuff container measures the debuff placeholders, a buff one the buffs
- autosize: a placeholder's name is the client's own when it has one
- autosize: the worst case carries the longest dispel type word, not only the ones the placeholders show
- autosize: the worst-case duration is measured, not only the placeholders' short ones
- autosize: an icon beside the line sets the height at its size and widens the box by it and its gap
- autosize: bounce headroom follows the vertical justify, and a line-height icon is inset by the FINAL height
- autosize: a stacked Center is its rows tall and as wide as its widest ROW
- autosize: a measure that fails keeps the stored size, is not remembered, and a later one autosizes
- autosize: the size is remembered per style signature; a changed font size measures again
- autosize: the dressed element, the flow layout and the preview offset all take the autosized size
- autosize: on, a live name longer than the budget draws in full at its justify point (TX-1, E8)
- autosize: a stacked Center's long name row is not cut either
- autosize: a placeholder with the long name is not cut in test mode
- autosize: off, a hand-set width still cuts a long line at the box, and a toggle re-dress follows it

### test_preview.lua (28)

- preview: every placeholder aura is drawn, each where Preview.Offset puts it against the anchor
- preview: the per-group cap limits the placeholders
- preview: a container showing only Weapon enchants previews one placeholder per enchant slot, and its extent agrees (feedback #6)
- preview: a shown preview with nothing applied is left alone; an applied one is dressed again in the same frames
- preview: a lower cap hides the extra placeholders rather than leaving them drawn
- preview: Hide releases every placeholder, and the next Show dresses them again
- preview: a container whose settings are gone draws nothing and raises nothing
- preview: placeholders paint with the container's class snapshot, as its real buttons do
- preview: a vertical layout wraps into a new column one element's width plus the line spacing across
- preview: a missing layout block grows down and right from the top left with no spacing
- preview: switching Color by from dispel type back to static leaves no dispel tint on a placeholder (B-4)
- preview: a background colored by dispel type paints each placeholder's own type, its alpha on the region (feedback #7, item 4; TD-4)
- preview: switching a previewed container from bars to icons re-dresses without error
- preview: switching a previewed container from icons to bars re-dresses without error
- preview: a bar container duplicated in test mode, then switched to icons, re-dresses (the owner's steps)
- preview: each style keeps its own pool, and a switch parks the other style's placeholders
- preview: a placeholder holds the mouse's hover as its container's buttons do, so no world tooltip shows through (L-3)
- preview: the extent covers the placeholder block from the corner it starts at, sized by Preview.Offset (L-4)
- preview: a real container's extent is a frame of ours under its anchor, kept when the preview hides (L-4)
- preview: under lockdown a placed extent stands, and one never placed is placed once (L-4)
- preview: a text container's placeholders read its template, each bracket's text hidden with its value
- preview: a HARMFUL container draws the debuff placeholders, a HELPFUL one the buffs (TD-1)
- preview: Preview.AurasFor answers the set for the aura type, and the buffs for anything else (TD-1)
- preview: switching a previewed container's aura type re-dresses it with the other set (TD-1)
- preview: a placeholder's name and icon come from its spell id when the client answers, the literals when not (TD-3)
- preview: the debuff set covers every dispel type plus one with none, and runs out, stacks and lasts forever (TD-2)
- preview: a container showing only Weapon enchants previews the enchant set, one per slot (SEP-4)
- preview: a Text container's Size to fit measures the enchant names too, so an enchant placeholder fits its box

### test_render_coverage.lua (3)

- coverage: every Bars row reaches a drawn region, on a live button and on the preview
- coverage: every Icons row reaches a drawn region, on a live button and on the preview
- coverage: every Text row reaches a drawn region, on a live button and on the preview

### test_blizzardframes.lua (8)

- blizzard: hiding moves the frame under a hidden parent of ours; restoring puts back the parent it had
- blizzard: applying twice remembers the first parent, so a restore never lands on our hidden frame
- blizzard: buffs and debuffs are hidden and restored independently
- blizzard: a frame the setting never hid is left where it is, whoever moved it
- blizzard: a frame that had no parent is restored to UIParent
- blizzard: a client without the frame, or a global that is not one, is skipped without raising
- blizzard: in combat nothing moves and Apply says it has to wait; with no profile, nothing is waiting
- blizzard: a profile switch applies the new profile's choice

### test_framepicker.lua (15)

- picker: the screen and the world are never a target, and the walk ends there
- picker: the walk climbs past one of this addon's own frames to a named frame above it
- picker: the walk gives up after thirty-two unnamed frames
- picker: hovering a named frame outlines it and names it beside the cursor
- picker: the label follows the cursor at the UI's scale
- picker: over nothing named the outline hides and the label says what to do
- picker: a frame the outline may not anchor to hides the outline instead of raising
- picker: the outline over a frame of secret size draws strips and never raises
- picker: the outline carries the template that lets it outline an aura container
- picker: a right-click cancels, and nothing is picked
- picker: a left-click over nothing named keeps the pick going
- picker: Escape keeps its key from the game for that press only, and cancels
- picker: any other key passes through and the pick continues
- picker: a new pick waits for the buttons to be released again before it can pick
- framepicker: PickFor refuses in combat, refuses with no container, and makes exactly the two attach writes

### test_disabled.lua (18)

- disabled: enabled, the addon registers a non-empty set
- disabled: every registration the addon owns is UNREGISTERED, not gated
- disabled: TimedSpells' private unit frame is in the census while enabled and gone when disabled
- disabled: what MUST survive does — the dispatcher, the panel, AceDB and the launcher
- disabled: nothing is left armed, and nothing arms itself afterwards
- disabled: a queued apply and a queued scan are canceled, not left armed
- disabled: every frame that was shown is hidden, at the source
- disabled: firing every baseline event writes nothing, says nothing and shows nothing
- disabled: every reserved verb answers, and the bare /am opens the panel
- disabled: this addon's own feature verbs refuse on one line and reach no write seam
- disabled: the launcher's left-click opens the panel and its menu grays every feature toggle
- disabled: the panel's Test mode row refuses to start while disabled and prints one refusal line
- disabled: re-enabling restores the registration set, from the settings as they are NOW
- disabled: releasing one hold does not stand up an addon the other still holds down
- disabled: a profile switch to an enabled profile stands the addon back up
- disabled: a disabled login builds no container frame
- disabled: a profile switch while disabled builds nothing until enable
- disabled: a profile switch while down, then a stand-up in combat, keeps a reused id parked

### test_slash.lua (28)

- slash: every command is a positional {name, desc, fn} triple
- slash: the reserved verbs are all present
- slash: NS.COMMANDS carries 23 verbs, diagnostics right after debug, and no diag verb
- slash: /am new creates the described container and selects it
- slash: /am new text creates a text-style container
- slash: /am new gives the new container the Fill its style suits (B5)
- slash: /am new with a word it does not know creates nothing and says why
- slash: /am select takes an id or a name; /am containers marks the selection
- slash: /am set writes the selected container through the seam
- slash: lock and unlock drive the same setting the panel does
- slash: /am preview is an unknown verb; /am test switches test mode and leaves the lock alone (B1)
- slash: /am help and the landing page list test, and not preview (B1)
- slash: /am disable and /am enable write the master switch through the seam and say so
- slash: /am disable in combat is not refused; the master switch is a visibility write
- slash: /am enable prints the seam's error instead of the success line
- slash: enable and disable are listed by /am help and on the landing page
- slash: the degraded stub's /am disable and /am enable store the switch through writeThrough
- slash: the degraded stub's /am lock and /am unlock store the lock through writeThrough
- slash: /am delete removes a container by id
- slash: a name two containers share is refused, not guessed
- slash: /am delete in combat refuses in gray and keeps the container
- slash: /am resetall in combat resets the profile and parks what it drops (options-ui-§12)
- slash: the General Reset-all popup in combat resets the profile and parks what it drops (options-ui-§12)
- slash: /am new in combat refuses in gray and creates nothing
- slash: /am pick starts the frame picker for the selected container
- slash: /am resetall and the General reset print the same line
- slash: /am debug on and off flip the session flag; it never reaches the profile
- slash: the dispatcher's isEnabled is NS.EnabledStored

### test_slash_verbs.lua (50)

- slash verbs: /am help prints the alias header, then one row per NS.COMMANDS verb in order
- slash verbs: the landing page's rows are /am help's rows without the chat indent
- slash verbs: /am and /auramaster both reach the one dispatcher
- slash verbs: /am options is an alias of /am config, and both open the settings panel
- slash verbs: a bare or whitespace-only /am opens the settings panel through config; /am help prints the list
- slash verbs: in combat a bare /am prints the same refusal /am config does
- slash verbs: /am version prints the version on its own line
- slash verbs: get, set and reset with no path print a usage line naming /am
- slash verbs: an unknown path, or one in the wrong case, is not found and nothing is written
- slash verbs: a global row reads with no note; a container row names the container it read
- slash verbs: with no containers, get and list read a container row as nil and note nothing
- slash verbs: set clamps a number to the row's range and echoes what was stored
- slash verbs: set refuses what the row's type cannot take, and stores and announces nothing
- slash verbs: set writes a color in the stored {r, g, b, a} shape; get decodes a partial one channel by channel
- slash verbs: a value the parser takes but the seam refuses prints the refusal and no echo of the unchanged value
- slash verbs: /am set with a refused value prints INVALID and the row's reason once each, and does not echo the unchanged value
- slash verbs: /am reset container.name prints the library's no-default line once
- slash verbs: /am reset with no container prints the seam's reason, not the no-default line
- slash verbs: set and reset reach a session row, which never lands in the profile
- slash verbs: reset restores the selected container's row only, and its echo carries no note
- slash verbs: set on a global row writes the profile through the seam
- slash verbs: /am list prints every row once, grouped by page in page order, noting container rows
- slash verbs: /am resetall resets the profile once, with no popup, and says so
- slash verbs: /am resetall without the settings helpers says it cannot, and resets nothing
- slash verbs: the Reset-all confirmation is options-ui-§12's wording, a Yes/No pair that waits
- slash verbs: /am lock and /am unlock go through the seam: unlocked shows the handle, and live auras keep drawing (B1)
- slash verbs: /am enable, /am disable, /am lock, /am unlock echo the stored value in the set shape
- slash verbs: /am test in combat refuses on one gray line and starts nothing (B1)
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
- slash verbs: /am get global.minimap.shown answers true while the button shows; /am set global.minimap.shown false stores hide = true
- slash verbs: the old path global.minimap.hide is not a setting, and nothing is written
- slash verbs: a legacy store's minimap.hide reads through the renamed path with no migration
- slash verbs: without the library each schema verb names what is missing, and writes nothing
- slash verbs: without the library /am set on a composed row or a writeThrough path prints the one line and writes nothing
- slash verbs: without the library a bare /am still runs config, help prints the list, aliases route, and an unknown verb says so
- slash verbs: without the library the host verbs keep working
- slash verbs: while disabled every feature verb refuses on ONE line naming /am enable, and acts on nothing
- slash verbs: while disabled the live set still answers — settings stay readable and repairable
- slash verbs: the disabled gate is ONE decision over the whole verb table, not a per-verb guard
- slash verbs: /am new enchants makes a player buff container showing only Weapon enchants (feedback #6)

### test_diagnostics.lua (38)

- diag: /am diagnostics writes the report to the console ungated, opens it, and says so once
- diag: /am diagnostics answers while the addon is disabled, and the state line says so
- diag: /am debug diagnostics writes the report to the console ungated, opens it, and says so once
- diag: /am debug diagnostics answers while the addon is disabled, and the state line says so
- diag: /am debug diag no longer runs the report; it falls through to the window toggle
- diag: bare /am debug and /am debug on|off keep their meaning; the forms are read in any case
- diag: without LibKa0s both forms print the unavailable line and raise nothing
- diag: the module writes sections only; the buffer, markers, cap and Run are the library's
- diag: the library's identity header leads, then the addon's state
- diag: the header names version, schema, profile, state, holds and the apply queue
- diag: the profile section lists non-default rows only, with no color escape
- diag: auras on the player are dumped per filter with every field
- diag: a secret aura field prints as secret, never compares, and is left out of predictions
- diag: while auras are secret no aura API is called and no button is touched
- diag: a raising aura read is reported and the containers still report
- diag: absent units read none, and a pet that exists is dumped
- diag: every container gets a line and a full filter block, lists sorted and named
- diag: a container's non-default rows are listed, with no color escape, untouched rows absent
- diag: a row scoped to an aura type is not listed for a container of the other type
- diag: the plan verdict reads in sync, PENDING, DRIFT or not built
- diag: plan groups report the engine's frame and shown counts, or ? when unreadable
- diag: shown buttons are identified by instance, then by our own regions, else id=?
- diag: predictions come from ExplainSpell over the unit's readable auras
- diag: an engine button whose IsShown is secret out of combat costs no section
- diag: a partly secret group counts the readable buttons and the unknowable ones apart
- diag: a raising button probe costs one line, never the predictions
- diag: a plan group that raises keeps later groups and the warnings
- diag: [Cfg] lists only the settings in use; the rest go on an inert line
- diag: [Cfg] prints no attach.edge: v11 made it two points, and no row stores it (batch 11 G4)
- diag: [Cont] prints both points in effect, whether each is automatic, and the classification (batch 11 G7)
- diag: a failing section is reported and the next container still reports
- diag: the report is capped below the console buffer and says it was truncated
- diag: predictions stop at the id cap and the report says it was truncated
- diag: a report's aura reads are its own, even when a spec passes the sections
- diag: QueueSnapshot hands out copies, never the live queue
- diag: a disabled login says so in the header, and each [Plan] not built line says why
- diag: a stood-down addon names its holds; built containers read hidden, not unbuilt
- diag: a container with no instance while running is not built for want of one

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
- bulklog: Bulk.Run stays silent only when its act sets info.profileReset, the profile reset's signal
- bulklog: a library Defaults a row's onChange stops counts the write it stored

### test_optionssetup.lua (17)

- options: NS.Helpers IS the library instance
- options: General and Containers register, in TOC order; the former sub-pages do not, and Profiles opts out without AceDBOptions
- options: the Profiles page SHOWS the container AceConfigDialog fills, even a pooled (hidden) one
- options: every page renders without a reported error
- options: the General page leads with Master controls, in canonical order
- options: the Filters page offers the Overrides tab only for a buff or debuff container, never an unknown type
- options: a container page's tabs are its schema groups, with a bespoke tab placed where it asks; a stale tab falls back
- options: the banner is the picker — choosing a container retargets every page
- options: the Containers page's New button creates and selects a container
- options: a page's Defaults button restores only the selected container
- options: Reset all settings resets the active profile whole, and nothing else (options-ui-§12)
- options: opening a page in combat refuses with the canonical gray line
- options: the Delete popup refuses in combat
- options: the Background block is composed in canonical order, and its tooltips name the background
- options: a wrapped tab strip reserves the same band and places every tab at the same y for every selection
- options: the degraded stub completes the load — every page's rows still register
- options: the library-absent schema is the full one minus exactly the composed rows (options-ui-§1)

### test_options_descriptor.lua (18)

- options descriptor: a rendered widget reads the selected container and writes it through the seam
- options descriptor: a color swatch shows the stored color and stores the picker's in the {r, g, b, a} shape
- options descriptor: a page's Defaults resets the page's session rows too
- options descriptor: Reset all writes only session rows through the seam and resets only the active profile
- options descriptor: Reset all never writes a Profiles-page row, live or degraded
- options descriptor: the degraded Reset all resets the profile whole and walks no profile-backed row
- options descriptor: the banner lists every container by name and ignores a re-pick of the selection
- options descriptor: Containers' picker sits in the chrome block above the strip and selects (feedback #2)
- options descriptor: every page's Container picker sorts by name, case-insensitively, the id breaking a tie (B2-2)
- options descriptor: a container page draws its intro, then the bespoke tabs its container's type admits
- options descriptor: with no containers a page draws the one empty-registry line and no intro
- options descriptor: RenderPage draws no banner; a banner hook draws the container band first
- options descriptor: an addon-wide tabbed page draws every tab with no container, and a bespoke tab keyed by a group takes its place
- options descriptor: a bespoke tab with `before` is drawn ahead of the tab it names, else last
- options descriptor: RenderWarnings draws one orange line per thing the engine will not do
- options descriptor: panel refreshes asked for in one frame are one refresh, on the next frame
- options descriptor: OpenOptionsPage opens a registered page's category, a section's through Containers, and falls back to the panel otherwise
- options descriptor: every stub composer answers an empty row list

### test_pages_general.lua (35)

- general: the Enable checkbox writes the master switch through the seam
- general: the four show-or-hide master rows are visibility passes; Master scale re-applies
- general: the visibility dropdown offers the four states in order and stores the one chosen
- general: the Debug console checkbox shows the window and writes nothing to the profile
- general: the Test mode checkbox shows the placeholders without unlocking, and reads the mode back (B1)
- general: a Test mode start in combat is refused and the checkbox reads false again (B1)
- general: combat starting ends test mode, and Reset all settings ends it too (B1)
- general: Hide Blizzard buffs reparents BuffFrame away, and back to where it was
- general: the Blizzard-frame rows re-apply no container
- general: Reset position puts every container back on the screen
- general: Reset all settings asks first and resets nothing until the answer
- general: the Reset-all tooltip names the equivalence with Profiles -> Reset Profile
- general: the Reset-all popup carries options-ui-§12's wording and cannot be clicked through
- general: Defaults restores the General rows of the profile and no container setting, now that Containers is its own page
- general: the page's Defaults tooltip no longer mentions a container's identity (N-1: Containers is its own page)
- general: the tab strip reads Master controls, Display, Spell Categories, Dispel Colors — Containers is gone from it
- general → spell categories: the list is ordered by name, case-insensitively, ids the client cannot name last (owner 2026-09-20)
- general → spell categories: the list draws two columns, filled row-major, in the by-name order (owner 2026-09-20)
- general → spell categories: a dropdown of the fourteen spell categories plus Weapon enchants, opening on the first
- general → spell categories: every Category entry is prefixed with the aura type it filters (issue #10)
- general → spell categories: the markers are padded so every name starts at the same column (issue #10)
- general → spell categories: the closed dropdown shows the marked label too (issue #10)
- general → spell categories: a section heading separates the picker from the spell list (2026-09-20)
- general → spell categories: every starter is listed with an X on its left, and no checkbox (B2)
- general → spell categories: adding by id writes categorySpells whole through the seam, and its X takes it off
- general → spell categories: a name resolves through the candidates — any category's starter, or a learned timed spell
- general → spell categories: choosing Weapon enchants draws slot toggles, not a spell list
- general → spell categories: the Weapon enchants entry explains the all-slots fallback
- general → spell categories: unticking a weapon slot writes the profile, one row at a time
- general: Select moves the Spell Categories tab onto the given category, and ignores a key it cannot draw
- general: Select accepts the enchant key too, and lands the tab on it
- general → spell categories: the tab and Dispel Colors are drawn with no container at all
- general → dispel colors: five profile-wide swatches, no None, no class-color companion, under a line saying they drive bars and text
- general → dispel colors: a swatch writes its own type's color and re-applies every container
- general → dispel colors: the page's Defaults restores them

### test_pages_general_categories.lua (32)

- general → spell categories: the picker owns its row, and Create sits beside the name (owner 2026-09-22)
- general → spell categories: the create form makes a category, shows it, and it is usable at once
- general → spell categories: the name box renames without moving the key, and keeps the container's Show/Hide
- general → spell categories: a shipped category draws no controls, no heading and no sentence (owner 2026-09-21)
- general → spell categories: the rename and the Delete sit directly under the picker (owner 2026-09-21)
- general → spell categories: Delete asks first, and the confirmation's act is what refuses a shipped key
- general → spell categories: a category the player made is drawn no Restore, and the act refuses one
- general → spell categories: Weapon enchants is promised no spell list, Restore or add/remove
- general → spell categories: a category the player made says so, without moving the name column
- general → spell categories: the rename box and the create box cannot be mistaken for each other
- general → spell categories: every act of the block answers in the panel, not only in chat
- general → spell categories: a saved record the sync cannot read can be forgotten from the panel
- general → spell categories: an id another category already claims is marked in the list and reported at the add
- general → spell categories: the answer line dies with the profile it was said in
- general → spell categories: the answer line ends when the page leaves the screen
- general → spell categories: Weapon enchants has a lead-in, and its slots have a heading of their own
- general → spell categories: a claimed-by tooltip says when the other category is one the player made
- general → spell categories: the mark's color says which of the two things it has to say
- general → spell categories: two other claimants are both named, in the mark and the tooltip
- general → spell categories: one unreadable record reads in the singular
- general → spell categories: a profile that refuses the sweep is said out loud, not only logged
- general → spell categories: typing lists the candidates — the profile's edits, every container's overrides, the learned timed buffs
- general → spell categories: the add box still offers a spellbook spell that is on NO list of this addon
- general → spell categories: a host kind with a base keeps its own entry tooltip AND its base's suggestions
- general → spell categories: a name only the candidates know resolves — another category's added spell, a spell on any container's overrides
- general → spell categories: picking a suggestion adds it through the one writer, exactly once
- general → spell categories: a name two ranks share lists both, labeled; Enter without a pick adds neither
- general → spell categories: the add line's tooltip and its refusal say where a name can come from
- general → spell categories: a starter's X stores false and drops it from the list; adding it again drops the edit (B2)
- general → spell categories: choosing another category lists its starters, by name where the client knows them
- general → spell categories: Restore sits above the Add line and clears that category's edits and no other's (B2)
- general → spell categories: Restore sits on the Category dropdown's line, to its right (feedback #3)

### test_pages_containers.lua (31)

- containers: registers its own top-level Blizzard category, with one tab, General (N-1, options-ui-§14)
- containers: Unit, Aura type and Style sit under their own subsection; Name and Enabled do not
- containers: the subsection heading is drawn between Enabled and Unit, not anywhere else
- containers: NS.OpenOptionsPage('containers') opens its own category, not the main one (N-3)
- containers: the picker and New container sit in the band above the strip, drawn before it (feedback #2)
- containers: the picker retargets the tab and every page
- containers: New container creates a container and selects it
- containers: New container takes the Fill its style suits (B5)
- containers: a created container with its own Fill keeps it; Create with only a style takes the style's
- containers: Delete keeps the band's picker and New through both refreshes, and the picker lists what remains (C-3)
- containers: with no containers the page draws the band's picker and New, and one line instead of the rows
- containers: the Name box renames the selected container, trimmed, and no other
- containers: /am reset container.name says a name has no default and changes nothing
- containers: a blank name is refused and the container keeps its name
- containers: a rename re-lists every picker and re-applies no container
- containers: the Unit dropdown offers the four units in order and writes the selected container
- containers: changing the aura type redraws an open Filters page for the new type, on the next frame
- containers: Aura type offers Buffs and Debuffs only; the retired Weapon enchants type is refused (feedback #6)
- containers: the Style dropdown offers bars, icons and text and writes the selected container
- containers: a new Style resets Fill to the one it suits and leaves the grow directions (B5)
- containers: re-choosing the same Style keeps a Fill set by hand (B5)
- containers: /am set container.style resets Fill the same way, one apply and one rebuild (B5)
- containers: a duplicate and a copy-from keep the source's Fill (B5)
- containers: in combat the library refuses Duplicate and New container; nothing is created
- containers: Duplicate copies the selected container and selects the copy
- containers: Delete asks first, naming the container, and deletes it only on Yes
- containers: the copy block offers every other container and copies only the chosen section
- containers: copying Everything takes what the source is, never its name or position
- containers: with one container the page offers Duplicate and Delete but no copy block
- containers: Defaults restores Enabled, Unit, Aura type and Style, and never the name
- containers: the page's Defaults tooltip names the section on screen and the kept name

### test_pages_filters.lua (49)

- filters: Cast by writes the selected container's filter and no other
- filters: a buff container's Categories tab offers the weapon-enchant rows; a debuff container's does not
- filters: hidePermanentEnchants draws right under the Spell Categories grid, tied to Weapon enchants by name, ahead of the Uncategorized note (T-3)
- filters: the max-auras description tells the truth about a group being per-shown-category, not the whole container
- filters: the sort-by and direction descriptions tell the truth about a group being per-shown-category, not the whole container
- filters: a max-duration preset writes the same path as the slider
- filters: a stored max-duration matching no preset leaves the preset dropdown blank
- filters: the max-duration description says there is no minimum
- filters: a buff container's Categories tab is two grids, Blizzard Categories then Spell Categories, each once
- filters: a debuff container's Categories tab is Blizzard Categories, Spell Categories, Dispel Types and Who Cast It, each once
- filters: the Dispel Types grid draws no 4th cell, blank or otherwise
- filters: a category the player made is marked as theirs in the grid, and its schema row is not (owner 2026-09-21)
- filters: every grid's columns are Show and Hide, then the category (schema v3)
- filters: the Spell Categories grid opens with a line naming where its lists live (F-2)
- filters: the 'these are the lists' line draws wherever the grid holds an editable list — both aura types since Hard CC and Soft CC (T-2)
- filters: a debuff container's Categories tab says Hard CC and Soft CC only work on a hostile target or focus (A3)
- filters: the Uncategorized cost note draws only where the engine is certain to honor spell ids (A2)
- filters: a spells-kind row's See spells link selects that category on General -> Spell Categories and lands there; a token row gets an info icon instead (F-3/N-3/N-4/N-5)
- filters: the priority order (spec §6) is stated on the General tab, highest rank first
- filters: the priority block is stated once — not on Categories, not on Overrides (batch 8)
- filters: the priority block is a heading, a lead-in and five separate rank lines (T-2, batch 8)
- filters: the priority block is drawn under the General rows, not above them (batch 8)
- filters: the priority ranks read at the same size as the Overrides notes (2026-09-20)
- filters: the four tabs read General, Categories, Overrides, Sorting (batch 8)
- filters: the retired 'Only these categories' row is gone — no such control on the Categories tab
- filters: a grid checkbox stores show or hide for the selected container and re-syncs its line
- filters: /am get and /am list print a category's state as Show or Hide
- filters: every category row is skipRender and names its grid
- filters: no aura type is offered a Spell lists tab; the lists live on General → Spell Categories
- filters: Overrides replaces Always / never, with a Whitelist and a Blacklist section
- filters: Overrides adds to one list at a time by id or by name, and Remove takes an id off
- filters: the Overrides lists pack two entries to a row, row-major
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
- filters: an entry with a verdict keeps its place in the two-column grid
- filters: an uncategorized blacklisted spell warns that no category hides it
- filters: a whitelisted spell no category claims, on a buff container, names Uncategorized instead of the generic rank-5 wording
- filters: Show all and Hide all head every Categories section, one pair each (feedback #10, B11-T10)
- filters: Show all / Hide all on Dispel Types and Who Cast It set exactly their own section, for this container only (B11-T10)
- filters: Hide all on Blizzard Categories hides exactly that section, as one [Set] line and one apply (feedback #10)
- filters: Show all on Spell Categories shows exactly that section, whatever Blizzard Categories say (feedback #10)

### test_pages_layout.lua (47)

- layout: the tabs are Frame, Anchor, Growth, Mouse, Label, in that order
- layout: the Label rows write the selected container's label, dimmed while it is off but the swatch (NL-4)
- layout: Label > Justify shows the justify in effect with no pick, stores a pick, and Defaults clears it (B9 LJ-1)
- layout: the Label Justify row is dimmed while the label is off
- layout: the Anchor tab draws only the chosen mode's subsections, each under its heading (feedback #4)
- layout: Pick a frame sits beside Frame name in Named frame, and there is no Attach to the screen
- layout: in screen mode only the subsections that apply are drawn (feedback #4)
- layout: in container mode only the subsections that apply are drawn (feedback #4)
- layout: in frame mode only the subsections that apply are drawn (feedback #4)
- layout: changing Attach to redraws the tab on the next frame with the chosen subsections (feedback #4)
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
- layout: the follow line is dim gold, says why, and has a gap below it (F6)
- layout: the follow line is drawn on the Growth tab only
- layout: Another container names the derived points and the container it is attached to
- layout: the attachment line names the points in effect, picked or Automatic (batch 11 G2)
- layout: Another container draws the two anchor-point dropdowns, each Automatic (<in effect>) then the nine points (G1)
- layout: an anchor-point pick stores the point, any pair is allowed, and Automatic stores nil (G1, G2)
- layout: a picked point's Automatic entry still names what Automatic would give, not the pick (G2)
- layout: /am set takes the nine point names in any case or auto; attach.edge is no longer a path (G7)
- layout: a write to either anchor point re-places the container on its parent (G1)
- layout: every Point and Relative point row places the first aura, since the container's full size is secret
- layout: the facing-growth hint shows exactly when Point's side and the growth point at each other
- layout: the hint names the growth to pick instead, one line per facing axis
- layout: the hint is Named frame's alone — the screen has no frame to grow over, and a follower's points are derived
- layout: choosing a facing Point redraws the tab with the hint on the next frame
- layout: the Container row's help names no Side row, which batch 11 retired (G1)
- layout: a Container pick whose chain flows differently asks first and stores nothing (GC-1)
- layout: accepting the attach popup attaches and keeps the child's own Growth settings (E3)
- layout: canceling the attach popup stores nothing, and accepting it in combat is refused
- layout: the attach popup counts the containers attached to the child
- layout: no popup when the flow matches, for None, or outside container mode
- layout: switching Attach to into container mode with a differing target stored asks first
- layout: /am set attaches without asking and prints one line; a differing detach prints one
- layout: a chain root's Growth tab says how many containers follow its fill and growth
- layout: Named frame reads Named frame anchor point on the left and This container anchor point on the right (owner, 2026-09-26)

### test_pages_bars.lua (11)

- bars: the Icon tab holds the icon's four rows, then the composed icon-border block (B-1)
- bars: the General tab's Spark subsection turns the spark off on auras without a duration (B-3)
- bars: the seven tabs are drawn in order, whatever the container shows (S-1: Size folded into General)
- bars: General opens on Size (Width, Height) ahead of Fill, with paths unchanged (S-1)
- bars: Width writes the selected container, and the page re-reads after the banner moves
- bars: a confirmed fill color is stored on the selected container, as a table of its own
- bars: Pandemic carries no dispel swatches, and Color by points at General -> Dispel Colors (B-6)
- bars: the Pandemic tab holds the time color and the highlight, in pandemic-window words, paths unchanged (B2-1)
- bars: Background & border offers Color by beside the background, writing bgColorMode (feedback #7)
- pages: every Border style row says Solid redraws at once and another texture after a /reload (B2-3)
- bars: Defaults restores the selected container's bar look and leaves its icon look alone

### test_pages_icons.lua (5)

- icons: the six tabs are drawn in order
- icons: Width on the Icons page writes the icon width, never the bar width
- icons: the Cooldown rows write the selected container's swipe
- icons: the Pandemic tab holds the time color and the highlight, in pandemic-window words, paths unchanged (B2-1)
- icons: Defaults restores the selected container's icon look and leaves its bar look alone

### test_pages_text.lua (28)

- text page: the five tabs are drawn in order, Pandemic before Animation (B2-1)
- text page: General holds Size, the Template dropdown and box, the cheat sheet, then Placement
- text page: the section is named Text Template (Task 20, owner: rename this section)
- text page: the Preview is a disabled EditBox labeled Preview, PrettyChat's own shape (Task 20)
- text page: the Preview box refreshes after a template change (Task 20)
- text page: the cheat sheet has a Tokens heading, a Rules heading and one bullet per token (Task 20)
- text page: a valid template is stored; a refused one is not, and the panel prints why
- text page: /am set refuses a bad template with the parser's reason, indented under the refusal
- text page: a gray note under Justify says what Center does and why, whatever the justify (item 3)
- text page: Center on a multi-piece template draws the note naming its rows (feedback #1)
- text page: each loop row is live only for the effects that use it
- text page: without a duration token the pandemic-window rows dim, except the swatch, under a note
- text page: the Pandemic tab holds the time color and the blink, in pandemic-window words, paths unchanged (B2-1)
- text page: with Icon position None every Icon row but the position dims, the swatch excepted, under a note (item 6)
- text page: the blink row is engine-only, and the Font tab carries the composed font block, time format and Dispel type
- text page: Defaults restores the selected container's text look and nothing else
- text page: the Template dropdown lists the aura type's built-ins, then Custom (feedback #5)
- text page: picking a built-in writes its template, and the centered one Center; the box stays hidden (feedback #5)
- text page: picking a built-in that also moves Justify writes and applies once (final review)
- text page: Custom reveals the box with the current template; an unmatched template reads as Custom (feedback #5)
- text page: the Preview box renders the sample aura, brackets filled and empty ones hidden (feedback #5)
- text page: the centered built-in's Preview joins its two rows with a visible separator (final review)
- text page: a literal | in a custom template is doubled in the Preview box, not left to break it (final review)
- text page: an already-doubled || in a custom template still doubles each pipe (final review)
- text page: a colored dispel word's |cff...|r run survives escapeStrayPipes intact (final review)
- text page: Font carries the three dispel-type options, all off, each dimmed until it can show (feedback #7, item 5)
- text page: Size to fit leads Size; while it is on Width and Height dim under a note, and say why
- text page: /am set container.text.autoSize reaches the same seam

### test_pages_tabs.lua (6)

- tabs: every page and section draws its tab keys and labels in order
- tabs: a container switch that takes the active tab away heals the strip to its first tab
- tabs: the Filters page draws the engine's warnings above the tab's rows
- tabs: with no containers General keeps its tabs and Containers offers its General section alone
- tabs: the Containers page's band holds the picker and New container, out of the tab body
- tabs: re-rendering Filters and Containers ten times each leaves the live Dropdown and Button counts flat

### test_pages_rail.lua (16)

- sections: Filters, Layout, Bars, Icons and Text register as sections under their page keys
- sections: each style section's gate is derived from its style, on both builds (Diagnostics' inert split)
- rail: Containers draws General, Filters, Layout and the selected container's own style, in that order
- rail: the page opens on General, today's one General tab under the band, beside a 120px rail
- rail: the draw order is PageBanner, NavRail, TabStrip
- rail: a rail click draws that section's strip and rows under the same band
- rail: each section keeps its own tab: Filters, Categories, Layout, back to Filters lands on Categories (smoke 5)
- rail: a Style change heals an active style section to the new style's entry; other sections stay (smoke 4)
- rail: choosing a container of another style in the band moves Bars to Icons
- rail: with no containers the rail lists General alone, which says how to make one
- rail: a former sub-page key opens Containers on that section, drawn on the next show (smoke 7)
- rail: a style key the container is not drawn in opens Containers and moves nothing; Containers keeps the section
- rail: SelectTab on a section key selects the section and its tab; on the General page it is the library's
- rail: selecting a section is refused in combat and moves nothing
- rail: Defaults restores only the active section's rows for the selected container (smoke 6)
- rail: the Defaults tooltip names the section on screen and the kept name

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

### test_defaults.lua (30)

- defaults: every starter container is a valid container whose every override the template knows
- defaults: every category carries what its kind needs, and a label and description
- defaults: IsSpellCategory names exactly the spells-kind categories of BOTH aura types
- defaults: every shipped category answers its own aura type through AuraTypeOf, by def and by key
- defaults: AuraTypeOf is total — nil for an unknown key and for anything that is not a definition
- defaults: Hard CC and Soft CC ship as non-empty HARMFUL spell lists of positive integer ids
- defaults: Hard CC and Soft CC are declared ABOVE crowdControl, the Blizzard token they refine
- defaults: uncategorized is declared LAST in both Cat.HELPFUL and Cat.HARMFUL (U-1, fix round 3)
- defaults: every leaf of the container template is edited by a settings row or is a spell set
- defaults: every profile default is a settings row, a spell set or the registry's own bookkeeping
- defaults: every dropdown's default is one of its choices
- defaults: every slider's default lies inside its range
- defaults: the dispel palette covers every dispel type, and the profile holds its own copy
- defaults: spell lists and dispel colors are profile-wide, never a container's (schema v2)
- defaults: one Healing category holds both retired healing lists, where Core healing was
- defaults: a container draws in the Medium strata, the default UI's own layer (X-3)
- defaults: the global schema stamp defaults to 0, never the current version
- defaults: StatesShowing hides every buff category but the ones named, and leaves the debuff ones at Show
- defaults: no shipped category key sits in the reserved 'user' namespace
- defaults: SanitizeUserName strips the escape character and control characters, trims and caps
- defaults: NewUserKey is namespaced and terminates against a generator that always collides
- defaults: the key generator is the client's own, not the shared unseeded math.random
- defaults: a user category materializes among the spell lists, above Weapon enchants, Uncategorized still last
- defaults: schema order tracks Cat.For order per aura type, user categories included
- defaults: a user category's name is unrouted by design, and its description is not
- defaults: a sync canonicalizes a stored user name in the store, not only at the draw
- defaults: a corrupt user record is skipped and left on disk, never coerced
- defaults: a record outside the reserved namespace cannot hijack a shipped category
- defaults: a user category's name is shown as typed even when it is a shipped locale key
- defaults: userCategoryOrder is reconciled the way containerOrder is

### test_perf.lua (8)

- perf: every declared bucket is reached by a real bracket
- perf: a dormant probe notes nothing
- perf: suspend makes the addon inert without a reload, and resume restores it
- perf: suspend holds a queued apply until resume
- perf: the buckets are declared in report order, and only the per-container apply nests
- perf: suspend and resume log to the console whatever the debug flag says
- perf: resume re-registers exactly the lifecycle events suspend took away
- perf: without the library, /am perf answers one honest line

### test_debuglogsetup.lua (9)

- debuglog: enabling logging writes the [Init] summary — name, version, schema, profile and container count
- debuglog: the flag is NS.State.debug itself — the sink and IsEnabled read it live
- debuglog: the chat acknowledgment goes through the addon's tagged printer; the console brackets both ends
- debuglog: showing or hiding the console refreshes open panels, so the Master controls row follows it
- debuglog: the Debug console row shows and hides the window and never touches the logging flag
- debuglog: Reset all closes an open console, because the console row carries a default
- debuglog: without the library, SetEnabled still flips the flag and acks, and says once that the window is gone
- debuglog: without the library the diagnostics members answer with one honest line and write nothing
- debuglog: without the library the console row is honest — never checked, and its tooltip says why

### test_locale.lua (7)

- locale: every L[...] subscript in the source is defined in enUS.lua
- locale: every key enUS.lua defines is used somewhere in the source
- locale: no key is defined twice in enUS.lua
- locale: every enUS value is its own key, so the English build shows the source string
- locale: every string routed by value has its key — Constants labels, categories, filter warnings
- locale: every value is ASCII, the em dash excepted (T-1)
- locale: no library-missing line joins a routed fragment

### test_docs.lua (6)

- README.md carries no angle-bracket argument placeholders
- every Tier 2 documentation-map row agrees with docs/
- every .md under docs/ appears in the documentation map
- docs: every file:line citation names an existing file and a non-blank line inside it
- docs: no file:line citation lands on a comment-only or blank line
- docs: every file:line citation sits within 3 lines of a name its own sentence gives in backticks

### test_prose.lua (18)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose: the exclusions this repository declared suppressed 11 of 176 tracked authored file(s), by: docs/spell-research/ [skipDirs in tests/prose_waivers.lua] (11): docs/spell-research/2026-09-20/ANALYSIS.md, docs/spell-research/2026-09-20/DIFF.md, docs/spell-research/2026-09-20/SOURCES.md, docs/spell-research/2026-09-24-logs/CORRECTIONS.md, docs/spell-research/2026-09-24-logs/CURRENT_CATEGORIES.md, docs/spell-research/2026-09-24-logs/DECISIONS.md, docs/spell-research/2026-09-24-logs/FLAGS.md, docs/spell-research/2026-09-24-logs/PROPOSED_ADDITIONS.md, docs/spell-research/2026-09-24-logs/REVIEW.md, docs/spell-research/2026-09-24-logs/SOURCES.md, docs/spell-research/2026-09-24-logs/dictionary/AURAS.md
- prose: no path this repository narrows the gate by is loaded by a TOC
- prose: every path this repository narrows the gate by is one .pkgmeta keeps out of the zip
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

### test_surface_parity.lua (7)

- parity: the Core stub publishes everything core/CoreSetup.lua publishes live
- parity: the DebugLog stub carries every member the addon calls
- parity: the Options stub carries every helper the host calls, off the load path as a no-op
- parity: the Bus stub carries every LibKa0s-Bus-1.0 member the addon calls
- parity: the Compat arms carry every LibKa0s-Compat-1.0 member the addon wires
- parity: the Slash stub carries every dispatcher member the addon calls
- parity: the Slash stub's refusal line is the library's own format, byte for byte

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_lintconfig.lua (6)

- lintconfig: .luacheckrc sets no top-level ignore
- lintconfig: .luacheckrc switches no warning class off wholesale
- lintconfig: every files[...] ignore is narrowed to a file or a name
- lintconfig: no source file carries a bare inline luacheck ignore
- lintconfig: no length operator shares its line with a keyword or brace lizard must see
- lintconfig: every read_globals name is referenced as a global by some authored file

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

### test_diagnostics_contract.lua (7)

- diagnostics contract: both forms run the report
- diagnostics contract: the debug word is matched in any case
- diagnostics contract: both markers carry the brand and the end counts the report
- diagnostics contract: the report appends after what the console already holds
- diagnostics contract: the report lands with logging off and leaves it off
- diagnostics contract: both forms run while the addon is disabled
- diagnostics contract: no other name runs the report

## Totals

| Suite | Cases |
|-------|------:|
| test_loadorder.lua | 8 |
| test_setups.lua | 14 |
| test_launcher.lua | 30 |
| test_database.lua | 73 |
| test_database_categories.lua | 22 |
| test_migrations.lua | 28 |
| test_schema.lua | 33 |
| test_schema_paths.lua | 36 |
| test_filtercompiler.lua | 85 |
| test_filtercompiler_categories.lua | 9 |
| test_container.lua | 52 |
| test_containermanager.lua | 53 |
| test_compat.lua | 29 |
| test_secrets.lua | 6 |
| test_bus.lua | 8 |
| test_state.lua | 2 |
| test_lifecycle.lua | 15 |
| test_anchors.lua | 77 |
| test_anchors_seam.lua | 10 |
| test_anchors_edges.lua | 15 |
| test_anchors_hang.lua | 11 |
| test_emptywatch.lua | 25 |
| test_anchors_close.lua | 6 |
| test_anchors_label.lua | 23 |
| test_anchors_strip.lua | 7 |
| test_anchors_column.lua | 19 |
| test_anchors_points.lua | 16 |
| test_anchors_steady.lua | 7 |
| test_anchors_width.lua | 6 |
| test_texttemplate.lua | 26 |
| test_style.lua | 60 |
| test_castaura.lua | 7 |
| test_timedspells.lua | 22 |
| test_style_bars.lua | 63 |
| test_style_icons.lua | 31 |
| test_style_text.lua | 55 |
| test_style_text_autosize.lua | 18 |
| test_preview.lua | 28 |
| test_render_coverage.lua | 3 |
| test_blizzardframes.lua | 8 |
| test_framepicker.lua | 15 |
| test_disabled.lua | 18 |
| test_slash.lua | 28 |
| test_slash_verbs.lua | 50 |
| test_diagnostics.lua | 38 |
| test_bulklog.lua | 20 |
| test_optionssetup.lua | 17 |
| test_options_descriptor.lua | 18 |
| test_pages_general.lua | 35 |
| test_pages_general_categories.lua | 32 |
| test_pages_containers.lua | 31 |
| test_pages_filters.lua | 49 |
| test_pages_layout.lua | 47 |
| test_pages_bars.lua | 11 |
| test_pages_icons.lua | 5 |
| test_pages_text.lua | 28 |
| test_pages_tabs.lua | 6 |
| test_pages_rail.lua | 16 |
| test_pages_about.lua | 3 |
| test_pages_profiles.lua | 3 |
| test_envsetup.lua | 4 |
| test_poolsetup.lua | 4 |
| test_defaults.lua | 30 |
| test_perf.lua | 8 |
| test_debuglogsetup.lua | 9 |
| test_locale.lua | 7 |
| test_docs.lua | 6 |
| test_prose.lua | 18 |
| test_surface_parity.lua | 7 |
| test_vendor_sync.lua | 3 |
| test_lintconfig.lua | 6 |
| test_eol.lua | 2 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 7 |
| **Total** | **1640** |
