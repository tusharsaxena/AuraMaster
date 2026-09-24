local _, NS = ...

-- defaults/UserCategories.lua — the categories a PLAYER makes (issue #10): the stored records, their
-- materialization into defaults/Categories.lua's two lists, and the acts that create, rename and
-- delete them. Peeled out of defaults/Categories.lua (AM-13) so that file stays under the 1500-line
-- cap; it extends the same `NS.Categories` table and nothing reads it at file scope.

local Cat = NS.Categories

-- ---------------------------------------------------------------------------
-- User categories (issue #10, checkpoint 3)
-- ---------------------------------------------------------------------------
--
-- A category the player made is STORED as a small record and MATERIALIZED as an ordinary definition
-- in defaults/Categories.lua's two lists. That one decision is what makes this checkpoint small: `Cat.For`,
-- `Cat.Find`, `Cat.IsSpellCategory`, `Cat.DefaultStates`, `Cat.StatesShowing`, `Cat.AuraTypeOf`'s
-- KEY form (the note above it there, carried forward from checkpoint 2, is satisfied by this and nothing
-- else), settings/Filters.lua's `gridOf` and its `See spells` link, settings/GeneralSpells.lua's
-- category dropdown, and modules/FilterCompiler.lua's `categorizedUnion`, `splitCategories`,
-- `includeCategory`/`excludeCategory` and `FC.ClaimingCategories` all go on working with no edit at
-- all, because none of them can tell a user definition from a shipped one. `def.userCategory` is
-- the ONE marker that can, and only three things read it: the teardown below, the schema row's own
-- `userCategory` flag (so the rows can be found again), and tests/test_locale.lua's exemption.
--
-- THE STORED SHAPE, in the profile (defaults/Profile.lua, schema v6):
--
--   userCategories    = { [key] = { key = key, name = "<player text>", auraType = "HELPFUL"|"HARMFUL" } }
--   userCategoryOrder = { key, key, ... }
--
-- and NOT the spell list, which reuses `profile.categorySpells[key]` like every other category's
-- edits. `FC.CategorySpells(def, spellEdits)` is defined as the definition's own starters UNIONED
-- with the profile's per-key edits, so a user definition carrying `spells = {}` has, as its entire
-- list, exactly the `true` entries of `categorySpells[key]`. No new merge rule, no second store and
-- no second editor -- settings/GeneralSpells.lua's `entriesFor`, `editCategory` and `editsOf`, and
-- settings/Schema.lua's `categorySpells` carve-out, are already the right code.
--
-- The price of that reuse is named rather than hidden: the carve-out's normalizer DROPS every key it
-- does not recognize and writes the set WHOLE, so a user key whose definition had failed to
-- materialize would have its entire spell list deleted by the next unrelated edit of any other
-- category. `Cat.HasUserRecord` below is what settings/Schema.lua asks instead, so the stored RECORD
-- alone protects the list even when the definition is missing.

local L = NS.L

-- The reserved key namespace. Every user category's key begins with it and no shipped key ever may;
-- tests/test_defaults.lua asserts that, so a category added to defaults/Categories.lua's lists in a later version
-- cannot quietly take a namespace a player's saved data already lives in.
local USER_PREFIX = "user"
local USER_PREFIX_LENGTH = #USER_PREFIX
local USER_KEY_CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"
local USER_KEY_LENGTH = 10

-- The description every user category carries. FIXED, and routed through the locale like any other
-- shipped string -- which is precisely why the locale exemption (tests/test_locale.lua) can be one
-- FIELD of one flagged definition kind rather than the whole definition: only `label` is the
-- player's own text. If this ever needs to name the category it must be a format string taking the
-- name as a `%s` ARGUMENT, never a concatenation: a name is data, and a `%` inside it read as a
-- directive is the same class of bug as the `|` the sanitizer below strips.
local USER_DESC = "Your own category. Edit its spells on General -> Spell Categories."

-- Long enough for "Mythic+ affixes I care about", short enough that a grid row stays a row.
local NAME_MAX = 40

--- The cap `Cat.SanitizeUserName` applies, published so the panel's name boxes can stop the player
--- at the same number the store would silently trim them to (settings/GeneralSpells.lua). One
--- constant, two readers: a box that let 60 characters be typed and then stored 40 would be a
--- control that lies about what it did.
---
--- IT IS A COUNT OF CHARACTERS AT BOTH READERS. `EditBox:SetMaxLetters` counts what the player
--- typed, not what it encodes to, so a byte cap at the store would disagree with the boxes on every
--- name with a non-ASCII character in it -- and disagree by cutting one in half, which is how a
--- name ends in a lone continuation byte the font draws as a replacement glyph.
Cat.USER_NAME_MAX = NAME_MAX

--- `s`'s length in CHARACTERS rather than bytes: a UTF-8 continuation byte (binary 10xxxxxx) is the
--- rest of the character before it and is not counted, so this is what a player would count.
--- Published because the cap below and the Category dropdown's marker padding
--- (settings/GeneralSpells.lua) both have to count the same thing.
--- @param s string
--- @return number
function Cat.CharCount(s)
    return select(2, tostring(s):gsub("[^\128-\191]", ""))
end

--- `s` cut to at most `max` CHARACTERS, never mid-sequence: the cut is taken at the byte before the
--- lead byte of the character that would be the (max + 1)th.
local function truncateChars(s, max)
    local bytes = #s
    local count, cut = 0, bytes
    for i = 1, bytes do
        local b = s:byte(i)
        if b < 128 or b > 191 then
            count = count + 1
            if count > max then
                cut = i - 1
                break
            end
        end
    end
    return s:sub(1, cut)
end

--- A player-supplied category name as it is STORED: the escape character `|` and every control
--- character removed, trimmed, and capped at NAME_MAX CHARACTERS -- `Cat.CharCount`'s count, which
--- is the one the panel's boxes enforce. nil when nothing is left.
---
--- SANITIZED ONCE, AT THE WRITE, NEVER AT THE DRAW. `def.label` reaches `NS.L[def.label]` and from
--- there a FontString, and a FontString reads `|c`, `|T` and `|H` as color, texture and hyperlink
--- escapes -- so a bare `|` in a name could recolor the grid row it sits in, paint a texture over it
--- or turn it into a link, in the tooltip as well as the row. Escaping at render instead would mean
--- every reader had to remember to, and the one that forgot would be the hole; one canonical stored
--- value leaves nothing to remember. `%` is deliberately KEPT -- it is an ordinary character in a
--- name, and the rule that protects it is the one above USER_DESC: a name is only ever a format
--- ARGUMENT.
--- @param name string
--- @return string|nil
function Cat.SanitizeUserName(name)
    if type(name) ~= "string" then return nil end
    local clean = name:gsub("|", ""):gsub("%c", "")
    clean = clean:match("^%s*(.-)%s*$")
    if Cat.CharCount(clean) > NAME_MAX then
        clean = truncateChars(clean, NAME_MAX):match("^%s*(.-)%s*$")
    end
    if clean == "" then return nil end
    return clean
end

--- Whether `key` sits in the reserved user-category namespace: the `user` prefix every generated key
--- carries and no shipped key ever may (tests/test_defaults.lua asserts the second half).
---
--- STRUCTURAL, not a guess at how the key was made, and the sync below REFUSES a stored record whose
--- key falls outside it exactly as it refuses one with an unknown aura type. A record keyed `healing`
--- -- hand-edited, or left by a corrupt write -- would otherwise be materialized into `Cat.HELPFUL`
--- beside the shipped `healing`, two definitions under one key. The next sync's teardown then finds
--- the user def BY KEY and takes `healing` out of the container template with it, so the SHIPPED
--- category's row has no default for the rest of the session: `NS.DefaultFor` answers nil and
--- `NS.ValidateSchema` fails on a row the player never touched.
--- @param key string|nil
--- @return boolean
function Cat.IsUserKey(key)
    return type(key) == "string" and key:sub(1, USER_PREFIX_LENGTH) == USER_PREFIX
end

-- The key generator: a Lehmer (MINSTD) sequence of this file's own, seeded ONCE on first use.
--
-- `math.random` alone was not enough, and the reason is worth stating plainly: nothing in this addon
-- ever called `math.randomseed`, so in Lua 5.1 every client walks the SAME sequence from its first
-- draw. Two players who each made their first category would have been handed the same key, which is
-- precisely the collision the random scheme was chosen to avoid.
--
-- SEEDED ONCE, LAZILY, RATHER THAN MIXED PER CALL. The entropy the client offers is a wall clock in
-- SECONDS, so mixing it into every draw would make two keys created in the same minute share most of
-- their bits; drawing from a sequence seeded once gives ten independent characters per key however
-- fast they are made. Lazily rather than at load because the one ingredient that actually
-- distinguishes two clients -- the player GUID -- is not there until the player is in the world,
-- while `Cat.NewUserKey` runs only when somebody creates a category, long after.
--
-- ITS OWN STATE, NOT `math.randomseed`. The client runs every addon in ONE Lua state, so reseeding
-- the shared generator would reach into whatever any other addon is drawing from.
local RNG_MODULUS = 2147483647
local rngState

--- Fold every byte of `s` into `seed`. Not a hash with any property worth naming: it only has to
--- carry the whole string into the seed rather than the first few characters of it.
local function mixString(seed, s)
    local length = #s
    for i = 1, length do
        seed = (seed * 31 + s:byte(i)) % RNG_MODULUS
    end
    return seed
end

--- The seed, from what the client can say about THIS session that another client would not say.
--- The GUID is the load-bearing one -- Blizzard-unique per character, so two players do not share a
--- sequence even if they create a category in the same second; the clock and the profiler separate
--- two characters of one account, and cover a client that answers no GUID at all. Every source is
--- optional, because the headless harness has only some of them and a future client may move one.
local function seedValue()
    local seed = 7757  -- an arbitrary non-zero start: MINSTD is degenerate at zero
    if type(UnitGUID) == "function" then
        local guid = UnitGUID("player")
        if type(guid) == "string" then seed = mixString(seed, guid) end
    end
    if type(time) == "function" then seed = (seed + (tonumber(time()) or 0)) % RNG_MODULUS end
    if type(debugprofilestop) == "function" then
        seed = (seed + math.floor(tonumber(debugprofilestop()) or 0)) % RNG_MODULUS
    end
    if seed == 0 then seed = 1 end
    return seed
end

--- `math.random(low, high)`'s shape, off the sequence above. The HIGH bits decide the answer: a
--- Lehmer generator's low bits are the weak ones, and `% n` would read exactly those.
local function defaultRand(low, high)
    rngState = ((rngState or seedValue()) * 16807) % RNG_MODULUS
    return low + math.floor(rngState / RNG_MODULUS * (high - low + 1))
end

--- A fresh user-category key: `user` followed by ten lowercase base-36 characters.
---
--- RANDOM, NOT DERIVED FROM THE NAME AND NOT A COUNTER, and both halves earn their place.
--- Not derived: a rename is then a pure `rec.name` write and nothing in the rename path touches the
--- key, which makes "renaming orphans every container's stored Show/Hide" -- the trap issue #10
--- names -- structurally impossible rather than merely avoided.
--- Not a counter: keys LEAVE their profile. modules/ContainerManager.lua's CopyFrom copies a
--- container's `filter.categories`, AceDB's OnProfileCopied copies a whole profile, and import and
--- export (#9) will carry them between accounts. A per-profile counter guarantees that two profiles
--- that each created a first category both own `user1`, with different names, different aura types
--- and different spell lists -- a collision no code can detect and that a copy resolves silently and
--- wrongly. With a random key, two categories created independently under the SAME NAME are two
--- categories, which is the right answer: the name is a label, the key is identity.
---
--- WHAT THE RANDOMNESS ACTUALLY BUYS, AND WHAT IT DOES NOT. Within the account it is a GUARANTEE and
--- it is not the generator's doing: `taken` is every key in use ACCOUNT-WIDE (`Cat.UserKeysInUse`),
--- so the loop below simply refuses to hand back a key this account already holds, and a copy between
--- profiles cannot land two categories on one key however the draws fall. ACROSS accounts there is
--- NO guarantee, only a very small probability -- the generator is seeded per client (see
--- `seedValue` above), the draw is ten base-36 characters, and nothing can check a key an account
--- has never seen. So the import half of #9 must REKEY a record whose key the importing account
--- already holds rather than trust that keys cannot collide; this generator makes that case rare,
--- not impossible, and the earlier version of this comment claimed more than the code delivers.
---
--- `rand` is a test seam: the generator above unless a case hands in one that collides on purpose.
--- @param taken table|nil  [key] = true
--- @param rand function|nil
--- @return string
function Cat.NewUserKey(taken, rand)
    taken = type(taken) == "table" and taken or {}
    rand = rand or defaultRand
    local attempt = 0
    while true do
        attempt = attempt + 1
        local key = USER_PREFIX
        for _ = 1, USER_KEY_LENGTH do
            local i = rand(1, #USER_KEY_CHARS)
            key = key .. USER_KEY_CHARS:sub(i, i)
        end
        -- Ten base-36 characters is about 52 bits, so a second attempt is already unreachable in
        -- practice and the fifth is a formality. Past it the attempt counter is appended, which
        -- makes TERMINATION a property of this loop rather than a property of the generator: a
        -- degenerate `rand` that answers the same number forever still runs out of collisions.
        if attempt > 5 then key = key .. attempt end
        if not taken[key] then return key end
    end
end

--- Every user-category key stored anywhere in the account: each profile of AceDB's raw store, the
--- active profile, and the no-AceDB fallback's single one. ACCOUNT-WIDE on purpose (see
--- `Cat.NewUserKey`); it costs one walk per creation, which is as rare an act as this addon has.
--- @param db table|nil  defaults to NS.db
--- @return table  [key] = true
function Cat.UserKeysInUse(db)
    local out = {}
    local function harvest(p)
        if type(p) ~= "table" or type(p.userCategories) ~= "table" then return end
        for key in pairs(p.userCategories) do
            if type(key) == "string" then out[key] = true end
        end
    end
    db = db or NS.db
    if type(db) == "table" then
        harvest(db.profile)
        local store = type(db.sv) == "table" and db.sv.profiles
        if type(store) == "table" then
            for _, p in pairs(store) do harvest(p) end
        end
    end
    return out
end

--- Whether `defOrKey` names a category the player made. The definition form reads the marker the
--- sync stamps; the key form resolves through `Cat.Find`, so it answers only while the category is
--- materialized -- which is every moment after NS.RunMigrations except inside the sync itself.
--- @return boolean
function Cat.IsUserCategory(defOrKey)
    local def = defOrKey
    if type(def) == "string" then def = Cat.Find("HELPFUL", def) or Cat.Find("HARMFUL", def) end
    return type(def) == "table" and def.userCategory == true
end

--- A category definition's label AS IT IS SHOWN: a shipped label is a locale key and goes through
--- `NS.L`, a user label is the player's own text and never does. EVERY site that draws a category
--- name asks this rather than indexing `NS.L` itself -- the settings grids, the Spell Categories
--- dropdown and modules/FilterCompiler.lua's `ExplainSpell` notes.
---
--- Not a tidiness rule. `NS.L` answers its own miss path, handing back any key it has no line for,
--- so `L[def.label]` LOOKS correct for a user category right up until a player names one "Healing"
--- or "Movement" -- at which point the lookup finds a real shipped line and the panel shows the
--- shipped string in place of the name that was typed. Invisible on enUS, where the line and the key
--- read the same; plainly wrong on any translated client. The locale exemption tests/test_locale.lua
--- makes is that a user name is DATA; this is the half of it that lives at the draw.
--- @param def table  a category definition
--- @return string
function Cat.LabelOf(def)
    if type(def) ~= "table" or type(def.label) ~= "string" then return "" end
    if def.userCategory then return def.label end
    return L[def.label]
end

--- Whether `profile` STORES a user category under `key`, materialized or not. The distinction is
--- load-bearing in exactly one place, and it is a data-loss one: settings/Schema.lua's
--- `categorySpells` normalizer drops every key that is not an editable category and writes the set
--- WHOLE, so a key whose definition failed to materialize would have its entire spell list deleted
--- by the next unrelated edit of any other category. The stored record alone protects the list.
--- @return boolean
function Cat.HasUserRecord(key, profile)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" or type(key) ~= "string" then return false end
    local recs = profile.userCategories
    return type(recs) == "table" and recs[key] ~= nil
end

--- `profile.userCategoryOrder` reconciled against `profile.userCategories`, exactly the way
--- core/Database.lua's `rebuildOrder` reconciles `containerOrder`: dangling keys dropped, duplicates
--- dropped, records with no order entry appended in key order. WRITTEN BACK, so the reconciliation
--- happens at the sync rather than at every read.
---
--- Declaration order is the ONLY ordering source. `pairs` over `userCategories` is nondeterministic,
--- so an order derived from it would vary between logins -- and since modules/FilterCompiler.lua
--- emits one engine group per shown category in declaration order, and `FC.StructureKey` rebuilds a
--- live container whenever the group count or shape moves, that variance would be visible in game
--- and not merely in a table dump.
--- @return table  the reconciled order
function Cat.UserCategoryOrder(profile)
    if type(profile) ~= "table" then return {} end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local stored = type(profile.userCategoryOrder) == "table" and profile.userCategoryOrder or {}
    local seen, order = {}, {}
    for _, key in ipairs(stored) do
        if type(key) == "string" and recs[key] ~= nil and not seen[key] then
            seen[key] = true
            order[#order + 1] = key
        end
    end
    local orphans = {}
    for key in pairs(recs) do
        if type(key) == "string" and not seen[key] then
            orphans[#orphans + 1] = key
        end
    end
    table.sort(orphans)
    for _, key in ipairs(orphans) do
        order[#order + 1] = key
    end
    profile.userCategoryOrder = order
    return order
end

--- One stored record's usable name, or nil plus why it has none. A record is NEVER coerced into
--- validity: an unknown aura type coerced to HELPFUL would silently move the category between the
--- two grids and orphan every container's stored state for it, which is exactly what the
--- immutability decision (defaults/Categories.lua) forbids. A record that does not answer is SKIPPED and left on disk,
--- for the player to fix or delete rather than for this to guess at.
---
--- THE KEY IS CHECKED FIRST, and refusing a key outside the reserved namespace is the same kind of
--- refusal as refusing an unknown aura type: a record keyed `healing` is not a user category with a
--- bad field, it is a claim on a SHIPPED category's identity, and materializing it puts two
--- definitions under one key and costs the shipped one its container-template entry at the next
--- sync (`Cat.IsUserKey`).
local function usableName(key, rec)
    if not Cat.IsUserKey(key) then
        return nil, "the key is outside the reserved '" .. USER_PREFIX .. "' namespace"
    end
    if type(rec) ~= "table" then return nil, "the record is not a table" end
    if rec.auraType ~= "HELPFUL" and rec.auraType ~= "HARMFUL" then
        return nil, "unknown aura type " .. tostring(rec.auraType)
    end
    local name = Cat.SanitizeUserName(rec.name)
    if not name then return nil, "no usable name" end
    return name
end

--- Every record `profile` stores that `usableName` refuses, as { key =, why = } in key order.
---
--- SKIPPING SUCH A RECORD IS RIGHT AND LEAVING IT AT THAT IS NOT. The sync will not guess at a
--- missing aura type or an unusable name, because guessing moves a category between the two grids
--- or renames it behind the player's back -- so a record that does not answer is left on disk "for
--- the player to fix or delete". But there was nothing to press: an unmaterialized record is in no
--- dropdown, so no Delete reaches it, and `forgetUserKey` skips any profile that still holds a
--- record under the key, so its own debris could never be swept either. A record like that was
--- permanently stuck. This is what the panel reads to offer a way out
--- (settings/GeneralSpells.lua's 'Your categories' block).
---
--- A record under a non-string key is debris of the same kind and is reported too, keyed by what
--- `tostring` makes of it, so the count the player is shown is the whole of what will go.
--- @param profile table|nil
--- @return table
function Cat.UnusableUserRecords(profile)
    profile = profile or (NS.db and NS.db.profile)
    local out = {}
    local recs = type(profile) == "table" and profile.userCategories
    if type(recs) ~= "table" then return out end
    for key, rec in pairs(recs) do
        if type(key) ~= "string" then
            out[#out + 1] = { key = key, why = "the key is not a string" }
        else
            local name, why = usableName(key, rec)
            if not name then
                local at = #out
                out[at + 1] = { key = key, why = why }
            end
        end
    end
    table.sort(out, function(a, b) return tostring(a.key) < tostring(b.key) end)
    return out
end

--- The index a user definition is inserted at: immediately before the aura type's Weapon enchants
--- row (buffs) or its Uncategorized row (debuffs) -- the first definition whose kind is `enchant` or
--- `uncategorized`. So settings/Filters.lua's `custom` grid reads shipped spell lists, then the
--- player's own lists, then Weapon enchants, then Uncategorized: Uncategorized stays LAST (U-1), and
--- a user category sits among the shipped lists it is a sibling of rather than stranded after the
--- enchant row. No shipped definition moves relative to any other, so no shipped ordering claim --
--- A1's two CC rows above `crowdControl`, U-1 itself -- changes.
local function userInsertIndex(list)
    for i, def in ipairs(list) do
        if def.kind == "enchant" or def.kind == "uncategorized" then return i end
    end
    return #list + 1
end

local function storedUserRecords(profile)
    return (type(profile) == "table" and type(profile.userCategories) == "table")
        and profile.userCategories or {}
end

local function templateCategories()
    return NS.CONTAINER_TEMPLATE and NS.CONTAINER_TEMPLATE.filter
        and NS.CONTAINER_TEMPLATE.filter.categories
end

--- Sync phase 1: every user definition out of both lists, with its template key and schema row.
local function teardownUserDefinitions(template)
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        local list = Cat[auraType]
        local last = #list
        for i = last, 1, -1 do
            if list[i].userCategory then
                if template then template[list[i].key] = nil end
                table.remove(list, i)
            end
        end
    end
    if NS.UnregisterSchemaRows then
        NS.UnregisterSchemaRows(function(row) return row.userCategory == true end)
    end
end

--- Sync phase 2: auraType -> the path of the row the user rows are registered in front of.
local function insertionAnchors()
    -- Where each aura type's rows are inserted, read BEFORE anything is materialized: the path of
    -- the row the definitions are being inserted in front of. Schema order has to track `Cat.For`
    -- order per aura type, because settings/Filters.lua's renderCategories draws each grid in SCHEMA
    -- order and not in `Cat.For` order -- so a row merely APPENDED would draw below Uncategorized
    -- and break U-1 outright, and a row inserted before Uncategorized alone would still draw below
    -- Weapon enchants while its definition sat above it.
    local before = {}
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        local list = Cat[auraType]
        local at = list[userInsertIndex(list)]
        before[auraType] = at and ("container.filter.categories." .. at.key) or nil
    end
    return before
end

--- Sync phase 3: a definition and a template key per usable record; returns built (per aura type), made.
local function materializeRecords(recs, order, template)
    local built = { HELPFUL = {}, HARMFUL = {} }
    local made = 0
    for _, key in ipairs(order) do
        local rec = recs[key]
        local name, why = usableName(key, rec)
        if not name then
            if NS.Debug then
                NS.Debug("Migrate", "user category '%s' skipped and left on disk: %s",
                    tostring(key), tostring(why))
            end
        else
            if rec.name ~= name then
                -- Canonicalized in the STORE, not merely rendered safely, so there stays exactly one
                -- stored value and `Cat.SanitizeUserName`'s "never at the draw" rule holds. This is
                -- not coercion of the kind the aura-type rule forbids: a name is a label and nothing
                -- reads it, while an aura type decides which grid and which engine group the
                -- category belongs to.
                if NS.Debug then
                    NS.Debug("Set", "user category '%s': name canonicalized to '%s'", tostring(key), name)
                end
                rec.name = name
            end
            rec.key = key
            local list = Cat[rec.auraType]
            local def = {
                key = key, kind = "spells", label = name, desc = USER_DESC,
                -- An EMPTY starter list, which is the whole reuse argument: FC.CategorySpells
                -- resolves starters-plus-edits, so this category's list IS categorySpells[key].
                spells = {},
                auraType = rec.auraType, userCategory = true,
            }
            table.insert(list, userInsertIndex(list), def)
            if template then template[key] = "show" end
            local b = built[rec.auraType]
            b[#b + 1] = def
            made = made + 1
        end
    end
    return built, made
end

--- Sync phase 4: the schema rows for the definitions built, each aura type's in front of its anchor.
local function registerUserRows(built, before)
    -- The rows LAST, because NS.RegisterSchemaRows stamps each row's `default` out of the container
    -- template and the template only carries the key from the materialize phase.
    if NS.RegisterSchemaRows and NS.CategoryRow then
        for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
            local rows = {}
            for i, def in ipairs(built[auraType]) do rows[i] = NS.CategoryRow(def) end
            if rows[1] then NS.RegisterSchemaRows(rows, before[auraType]) end
        end
    end
end

--- Bring `Cat.HELPFUL`, `Cat.HARMFUL`, the container template's `filter.categories` and the schema
--- rows into agreement with `profile`'s stored user categories. THE ONE SEAM: core/Database.lua's
--- NS.RunMigrations calls it after the whole schema ladder and before Database.PrepareProfile,
--- core/AuraMaster.lua's prepareProfile calls it before its own PrepareProfile (so a switch, a copy
--- and a reset all pass through it), and the create and rename acts below call it so a category is
--- live the instant it is made. NOT at panel render: a row that existed only while the panel was
--- open would be invisible to `/am get|set|list`, to a page's Defaults and to the resets, which is
--- the whole reason these rows are in the schema at all.
---
--- IT TEARS DOWN BEFORE IT BUILDS, and the four mirrors move in ONE act. A stale row left behind by
--- a profile switch fails NS.ValidateSchema (the template no longer carries the key, so
--- NS.DefaultFor answers nil) and answers `/am get` for a category this profile does not have; but
--- the severe one is a stale DEFINITION, which makes `Cat.IsSpellCategory(deadKey)` true, so
--- `categorizedUnion` reads the NEW profile's `categorySpells` under a key that belonged to the OLD
--- profile's category and quietly takes ids out of the complement `uncategorized` is defined
--- against. Definitions, rows and template keys are therefore never torn down one without the other.
---
--- Rebuilt whole rather than diffed: the cost is one array rebuild per profile change, and what it
--- buys is that the function has one path, is trivially idempotent, and cannot leave a half-applied
--- state behind if a record in the middle of the list turns out to be corrupt.
--- @param profile table|nil
--- @return number  the categories materialized (a skipped record is not one)
function Cat.SyncUserCategories(profile)
    local recs = storedUserRecords(profile)
    local order = Cat.UserCategoryOrder(profile)
    local template = templateCategories()
    teardownUserDefinitions(template)
    local before = insertionAnchors()
    local built, made = materializeRecords(recs, order, template)
    registerUserRows(built, before)
    return made
end

--- Whether another user category of `profile` already carries `name` (case-insensitively), ignoring
--- `exceptKey`. For checkpoint 6's warning, which INFORMS and does not block: the key is identity,
--- so two categories called the same thing are two categories and refusing that would be refusing
--- something harmless.
--- @return boolean
function Cat.UserCategoryNameTaken(profile, name, exceptKey)
    local clean = Cat.SanitizeUserName(name)
    if not clean or type(profile) ~= "table" or type(profile.userCategories) ~= "table" then
        return false
    end
    clean = clean:lower()
    for key, rec in pairs(profile.userCategories) do
        if key ~= exceptKey and type(rec) == "table" and type(rec.name) == "string"
            and rec.name:lower() == clean then
            return true
        end
    end
    return false
end

--- Create a user category and return its key, or nil plus a player-facing reason.
---
--- The category is LIVE the instant this returns: the sync materializes the definition, stamps the
--- container template and registers the schema row, so `/am get container.filter.categories.<key>`
--- answers at once and the next compile counts its spells. Its spell list needs no creation of its
--- own -- it is `profile.categorySpells[key]`, empty until the player adds to it on General ->
--- Spell Categories, exactly like every other category's edits.
---
--- THE STORED CONTAINERS GET THE KEY HERE TOO, through Database.PrepareProfile's ordinary backfill
--- -- the same mechanism `Cat.DefaultStates`' comment above promises for a key added in a later
--- version, run one act earlier rather than waited for. The compiler would not have noticed the
--- difference (`splitCategories` reads an absent state as Show, which is the default anyway), but
--- the settings panel would: a ChoiceGrid cell lights by comparing the STORED value against its
--- column, so until the key exists in the container a brand-new category would draw with neither
--- Show nor Hide lit. PrepareProfile is idempotent, so calling it here costs a walk and nothing else.
--- @param name string
--- @param auraType string  "HELPFUL" | "HARMFUL"
--- @param profile table|nil  defaults to NS.db.profile
--- @param db table|nil  defaults to NS.db, for the account-wide key scan
--- @return string|nil key, string|nil reason
function Cat.CreateUserCategory(name, auraType, profile, db)
    profile = profile or (NS.db and NS.db.profile)
    -- No profile is not a refusal a player can act on and never reaches one: every caller runs after
    -- NS.InitDB. It answers nil with no reason rather than inventing a sentence to show.
    if type(profile) ~= "table" then return nil, nil end
    if auraType ~= "HELPFUL" and auraType ~= "HARMFUL" then
        return nil, L["A category holds buffs or debuffs, and the choice cannot be changed later."]
    end
    local clean = Cat.SanitizeUserName(name)
    if not clean then return nil, L["A category needs a name."] end
    if type(profile.userCategories) ~= "table" then profile.userCategories = {} end
    if type(profile.userCategoryOrder) ~= "table" then profile.userCategoryOrder = {} end
    local key = Cat.NewUserKey(Cat.UserKeysInUse(db or NS.db))
    profile.userCategories[key] = { key = key, name = clean, auraType = auraType }
    local count = #profile.userCategoryOrder
    profile.userCategoryOrder[count + 1] = key
    Cat.SyncUserCategories(profile)
    if NS.Database and NS.Database.PrepareProfile then NS.Database.PrepareProfile(profile) end
    if NS.Debug then
        NS.Debug("Set", "user category '%s' created: %s (%s)", key, clean, auraType)
    end
    return key, nil
end

--- Rename a user category.
---
--- THE KEY DOES NOT MOVE, which is the entire point of the keying scheme: every container's stored
--- `filter.categories.<key>`, the schema row, and `categorySpells[key]` all go on naming the same
--- category, so a rename cannot orphan one stored value. A duplicate name is ALLOWED -- see
--- `Cat.UserCategoryNameTaken` -- and an empty or whitespace-only one is refused. A shipped category
--- is refused outright: the plan of record's lock is on the category OBJECT, never on its contents.
---
--- THE RESERVED NAMESPACE IS CHECKED HERE TOO, exactly as `Cat.DeleteUserCategory` checks it and
--- for the same reason: a record keyed `healing` -- hand-edited, imported, or left by a corrupt
--- write -- is not a user category with a bad field, it is a claim on a SHIPPED category's identity.
--- Renaming it would succeed, store a name under a shipped key and leave the store holding a record
--- the sync refuses to materialize, which is exactly the shape `usableName` exists to refuse.
--- @return boolean|nil ok, string|nil reason
function Cat.RenameUserCategory(key, name, profile)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" then return nil, nil end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local rec = type(key) == "string" and Cat.IsUserKey(key) and recs[key]
    if type(rec) ~= "table" then
        return nil, L["Only a category you made can be renamed."]
    end
    local clean = Cat.SanitizeUserName(name)
    if not clean then return nil, L["A category needs a name."] end
    local was = rec.name
    rec.name = clean
    Cat.SyncUserCategories(profile)
    if NS.Debug then
        NS.Debug("Set", "user category '%s' renamed: %s -> %s", key, tostring(was), clean)
    end
    return true, nil
end

-- ---------------------------------------------------------------------------
-- Deletion (issue #10 checkpoint 5)
-- ---------------------------------------------------------------------------
--
-- CLEANUP IS EAGER: everything a deleted category leaves behind goes at the moment of the delete,
-- across every STORED profile, the ones nobody is logged into included. The plan of record allowed
-- either eager or lazy if the choice was documented and the validator tolerated the transient
-- state; this is the choice and these are the reasons.
--
-- 1. THERE IS NO LAZY PRUNER TO WRITE IT INTO. `Database.Backfill` only ever fills -- its own header
--    says so -- and `Database.PrepareProfile` is fill-and-reconcile throughout, so lazy would mean a
--    NEW destructive pass over stored containers that runs on every load and every profile switch,
--    deleting keys it decides are unknown. That pass is the dangerous thing here, not the debris: it
--    would run while `Cat.SyncUserCategories` is the thing that decides what is known, and a load in
--    which the sync half ran -- a corrupt record, an error mid-list -- would hand it a set of
--    "unknown" keys that are merely not materialized YET, and it would delete the player's stored
--    Show/Hide for categories that still exist. Eager cleanup runs in one act, on a key the player
--    just named, and cannot mistake a half-built session for a dead category.
-- 2. LAZY CANNOT REACH THE PROFILES THAT ACTUALLY HOLD THE DEBRIS. A pruner on the load path only
--    ever sees the profile being loaded, so debris in an inactive profile survives until the player
--    happens to switch to it -- and `Cat.UserKeysInUse` is account-wide precisely because these keys
--    travel (CopyFrom, OnProfileCopied, and #9's import). Eager walks `Database.EachProfile`, which
--    is the same set of profiles the schema ladder migrates.
-- 3. THE VALIDATOR IS NEVER ASKED TO TOLERATE ANYTHING. `NS.ValidateSchema` fails a row whose path
--    does not resolve against the container template, and the sync tears the row, the definition and
--    the template key down together -- so after an eager delete there is no row, no def, no template
--    key and no stored leaf anywhere, and the validator is clean at every instant rather than clean
--    once something later tidies up.
--
-- THE ONE THING EAGER MUST NOT DO is delete another category's data, and one case makes that real:
-- AceDB's profile COPY duplicates `userCategories` wholesale, so two profiles can legitimately hold
-- a record under the SAME key, with their own names, their own spell lists and their own containers.
-- Deleting in one of them must leave the other entirely alone. So the sweep skips any profile that
-- still holds a record of its own under the key -- `forgetUserKey`'s first test -- and the owner's
-- record is removed BEFORE the sweep, which is what makes the owner profile eligible for it.

--- Clear every trace of category `key` from ONE stored profile: its spell list and the stored
--- Show/Hide in each of its containers. A profile that holds a RECORD under the key owns a category
--- of its own there (a profile copy) and is left untouched -- see the note above.
--- @return number  the leaves cleared, for the log
local function forgetUserKey(p, key)
    if type(p) ~= "table" then return 0 end
    if type(p.userCategories) == "table" and p.userCategories[key] ~= nil then return 0 end
    local cleared = 0
    if type(p.categorySpells) == "table" and p.categorySpells[key] ~= nil then
        p.categorySpells[key] = nil
        cleared = cleared + 1
    end
    if type(p.containers) == "table" then
        for _, c in pairs(p.containers) do
            local cats = type(c) == "table" and type(c.filter) == "table" and c.filter.categories
            if type(cats) == "table" and cats[key] ~= nil then
                cats[key] = nil
                cleared = cleared + 1
            end
        end
    end
    return cleared
end

--- Sweep category `key` out of every stored profile of `db`, `profile` first and by identity.
---
--- PER PROFILE, INSIDE ITS OWN pcall, and that is the whole of the atomicity answer. By the time
--- this runs the record is already gone, so the definition, the schema row and the container
--- template's entry MUST come down with it: a raise part way through the walk would otherwise leave
--- a LIVE category no record owns -- a schema row resolving against a template key nothing will
--- write again, and a dropdown entry whose Delete now refuses. Making the sweep atomic would mean
--- copying every stored profile and swapping them in, which is the whole saved-variables table;
--- making the FAILURE recoverable costs one pcall per profile. So this is RECOVERABLE, NOT ATOMIC,
--- and the difference is said plainly: a profile whose stored table is malformed costs only its own
--- leaves, every other profile is still swept, the caller's `Cat.SyncUserCategories` runs either
--- way, and what survives is an inert Show/Hide value under a key no category answers to -- read by
--- nothing, written by nothing, and cleared the next time that key is swept.
---
--- The owner profile goes first and BY IDENTITY, because it may not be in the store at all: the
--- headless harness and every test hand a bare profile table in, and `Database.EachProfile`'s
--- fallback branch answers `db.profile`, which is a DIFFERENT table from the one being deleted from.
--- The `seen` set is what keeps a profile reachable both ways from being swept twice -- harmless,
--- but it would double the count in the log line and make the log a lie.
--- @return number cleared, number failed
local function sweepUserKey(profile, key, db)
    local cleared, failed, seen = 0, 0, {}
    local function sweep(p)
        if type(p) ~= "table" or seen[p] then return end
        seen[p] = true
        local ok, n = pcall(forgetUserKey, p, key)
        if ok then cleared = cleared + n else failed = failed + 1 end
    end
    sweep(profile)
    db = db or NS.db
    if type(db) == "table" and NS.Database and NS.Database.EachProfile then
        if not pcall(NS.Database.EachProfile, db, sweep) then failed = failed + 1 end
    end
    return cleared, failed
end

--- Delete a user category and everything it owns, and answer whether it went.
---
--- THE REFUSAL IS THE ACT'S, NOT THE PANEL'S. A shipped category is refused here, by the same test
--- the rename uses -- it has no stored record -- so hiding the button is a courtesy to the reader
--- and never the enforcement. The lock is on the category OBJECT: nothing in this file can delete,
--- rename or retype `healing`, while `categorySpells.healing` stays the player's to edit and to
--- Restore. A key outside the reserved namespace is refused for the same reason `usableName`
--- refuses one: a record keyed `healing` is a claim on a shipped category's identity, and honoring
--- it here would sweep the SHIPPED category's stored state out of every profile in the account.
---
--- WHAT IS DISCARDED, in the order this does it: the record, the order entry (through the ordinary
--- reconcile, which drops a dangling key), the player's spell list for it, and every container's
--- stored Show/Hide for it in every stored profile. The definition, the schema row and the container
--- template's entry are the sync's, and it tears all three down as one act.
--- THE PARTIAL SWEEP IS PART OF THE ANSWER (owner, 2026-09-21). The sweep is recoverable and not
--- atomic on purpose -- see `sweepUserKey` -- so a stored profile whose table is malformed keeps its
--- own leaves while every other profile is cleaned. That is a real outcome and not a failure of the
--- delete: the record is gone, the definition is gone, and what survives is inert. But it used to
--- reach `NS.Debug` and nothing else, so the player was told "deleted" and never told that one
--- profile kept its debris. The count of refusing profiles is now RETURNED, third, so a caller can
--- say so; settings/GeneralSpells.lua's confirmation does.
--- @param key string
--- @param profile table|nil  the profile that OWNS the category; defaults to NS.db.profile
--- @param db table|nil  the store to sweep; defaults to NS.db
--- @return boolean|nil ok, string|nil reason, number|nil failed  profiles that refused the sweep
function Cat.DeleteUserCategory(key, profile, db)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" then return nil, nil end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local rec
    if type(key) == "string" and Cat.IsUserKey(key) then rec = recs[key] end
    if rec == nil then
        return nil, L["Only a category you made can be deleted."]
    end
    -- A record that is not a TABLE is a corrupt one, and it is deleted rather than refused. Refusing
    -- it is what made it permanently undeletable: the sync will not materialize it, so it is in no
    -- dropdown and no other act can reach it (`Cat.UnusableUserRecords`). The namespace test above
    -- is the one that still has to hold, because that is the one protecting a shipped category's
    -- stored state; the shape of the record protects nothing.
    local name = type(rec) == "table" and rec.name or nil
    recs[key] = nil
    Cat.UserCategoryOrder(profile)

    local cleared, failed = sweepUserKey(profile, key, db)

    Cat.SyncUserCategories(profile)
    if NS.Debug then
        NS.Debug("Set",
            "user category '%s' (%s) deleted: %s stored leaf(s) cleared across the account, %s profile(s) refused the sweep",
            key, tostring(name), cleared, failed)
    end
    return true, nil, failed
end

--- Forget every record `Cat.UnusableUserRecords` names, and answer how many went.
---
--- ONE ACT RATHER THAN A LOOP OF DELETES, because `Cat.DeleteUserCategory` cannot reach these: it
--- refuses a key outside the reserved namespace, and a record keyed `healing` is exactly the shape
--- that gets stuck. The namespace test is still honored where it actually matters -- the RECORD goes
--- whatever its key, but the STORED LEAVES are swept only for a key inside the namespace, because a
--- leaf under a shipped key is the shipped category's Show/Hide and is none of this act's business.
---
--- Nothing here can be repaired automatically, and nothing tries: a record with no usable aura type
--- or no usable name holds a spell list that cannot be attributed to either grid, and guessing is
--- the thing `usableName` exists to refuse. This is the player's decision, taken behind the panel's
--- own confirmation (settings/GeneralSpells.lua).
--- @param profile table|nil
--- @param db table|nil
--- @return number  the records forgotten
function Cat.ForgetUnusableUserRecords(profile, db)
    profile = profile or (NS.db and NS.db.profile)
    if type(profile) ~= "table" then return 0 end
    local bad = Cat.UnusableUserRecords(profile)
    if not bad[1] then return 0 end
    local recs = type(profile.userCategories) == "table" and profile.userCategories or {}
    local cleared = 0
    for _, entry in ipairs(bad) do
        recs[entry.key] = nil
        if Cat.IsUserKey(entry.key) then
            cleared = cleared + sweepUserKey(profile, entry.key, db)
        end
    end
    Cat.UserCategoryOrder(profile)
    Cat.SyncUserCategories(profile)
    if NS.Debug then
        NS.Debug("Set", "%s unreadable user category record(s) forgotten: %s stored leaf(s) cleared",
            #bad, cleared)
    end
    return #bad
end
