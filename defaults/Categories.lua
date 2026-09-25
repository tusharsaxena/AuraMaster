local _, NS = ...

-- defaults/Categories.lua — the aura CATEGORIES a container's filter can show or hide.
--
-- A category is one of six KINDS, and the kind decides how modules/FilterCompiler.lua turns it into
-- something Blizzard's aura container evaluates in its own secure code (we never see aura data in
-- combat, so every filter has to be declared up front — see docs/data-flow.md):
--
-- Show is the absence of a decision (schema v3) in the sense that it never NARROWS what draws: it is
-- the default every key starts at (`DefaultStates` below). It is not inert, though (batch 6's filter-
-- priority revision, modules/FilterCompiler.lua) — a Show is a POSITIVE claim that beats a Hide on
-- the same aura, and once any category is Hidden the compiler emits one group PER Show category
-- (plus a catch-all), not the single group a container with nothing Hidden still gets. Only Hide
-- writes a constraint, an exclusion, and only on the group(s) it actually reaches.
--
--   token          an aura filter token (`BIG_DEFENSIVE`, `CROWD_CONTROL`, …). Hiding it adds the
--                  negation `!TOKEN` to the group's filter string.
--   flag           a boolean candidate filter on the aura (`isBossAura`, `isRoleAura`, …). Hiding it
--                  asks for `not value`.
--   dispel         a set of dispel types. Hiding it adds to `excludeDispelTypes`.
--   spells         a curated list of spell ids. Hiding it adds to `excludeSpellIDs`. Blizzard only
--                  honors spell ids for BUFFS ON FRIENDLY UNITS and DEBUFFS ON HOSTILE ONES, so a
--                  buff category's list bites on the player, the pet and a friendly target or focus,
--                  and a debuff category's list bites on a HOSTILE target or focus and nowhere else
--                  (issue #11 gave `Cat.HARMFUL` its first two, `hardCC` and `softCC`). The Filters
--                  page and General -> Spell Categories say so where it matters (docs/scope.md,
--                  "What the engine cannot do").
--   enchant        the player's temporary weapon enchants. The odd one out: it matches no aura and
--                  joins no aura group. Hide takes the container's enchant slots away, Show gives
--                  them back (modules/FilterCompiler.lua's Compile, not its group builder).
--   uncategorized  batch 7, `U-1`..`U-5` (docs/superpowers/specs/2026-09-15-feedback-batch7-design.md
--                  section 4): "in none of the profile's SPELL-LIST (kind `spells`) categories" —
--                  Blizzard token/flag/dispel categories do NOT count toward being categorized. It has
--                  no id list of its own; it is the COMPLEMENT of every `spells`-kind category's
--                  effective ids, so modules/FilterCompiler.lua handles it with dedicated logic rather
--                  than the generic per-kind include/exclude every other kind shares. Drawn LAST in the
--                  grid, default Show. There is no General -> Spell Categories entry for it: it has no
--                  list to edit.
--
--                  ONE ROW PER AURA TYPE, ASYMMETRIC (2026-09-16 — the owner restored the debuff
--                  row an earlier pass dropped; issue #11's part A2 re-derived the asymmetry from the
--                  UNIT rather than from the aura type). Both rows' unions are now genuine subsets —
--                  `Cat.HELPFUL` has always had `spells`-kind categories and `Cat.HARMFUL` gained
--                  `hardCC` and `softCC` below — so what decides whether a Show row may contribute a
--                  group of its own is no longer "is the union empty" but "is the one constraint that
--                  group would carry CERTAIN to be applied". Its only constraint is an
--                  `excludeSpellIDs` of the union, and the engine discards spell ids except for buffs
--                  on friendly units and debuffs on hostile ones — so the gate is
--                  `modules/FilterCompiler.lua`'s `FC.IdsAlwaysHonored(unit, auraType)`, TRUE ONLY for
--                  buffs on the player and the pet, the two units that cannot turn hostile. It is a
--                  gate of its own, NOT the `FC.IdsHonored` the identity warning reads and not
--                  computed from it: the warning answers the weaker "can the engine EVER honor ids
--                  here", where a `target` or `focus` is true for both aura types (A2a ruling 1).
--
--                  So the row SUPERSEDES the catch-all only where that gate holds. There: Show
--                  excludes the union (rescuing an unlisted buff from another category's Hide) and
--                  Hide contributes nothing of its own, since there is no id list of "every other
--                  spell" to subtract. Everywhere else — every debuff container, and a `target` or
--                  `focus` buff container whose unit may be hostile when the engine looks — Show
--                  contributes NOTHING and the ordinary catch-all runs as if the row were not there,
--                  while Hide still suppresses the catch-all outright, reproducing the retired "Only
--                  these categories" toggle exactly. Concretely proven (2026-09-16, and again in A2):
--                  a Show group whose one `excludeSpellIDs` the engine throws away carries no
--                  candidate filter at all, draws EVERY aura of the type regardless of any other
--                  category's Hide, and neuters them all — the owner's original complaint reborn.
--
-- THE SPELL LISTS ARE A STARTER SET, WRITTEN FOR THIS ADDON. They were assembled from public spell
-- data for Retail 12.x and are meant to be edited: the Filters page lets a player add or remove any
-- id per category, and those edits live in the profile (profile.categorySpells, shared by every
-- container since schema v2), never here.
-- An id that does not exist in the current client simply never matches, so a stale entry costs
-- nothing but a row in the editor.
--
-- PROVENANCE (issue #11 part C, spec section C6). `hardCC` and `softCC` below are the first lists
-- here that were DERIVED rather than hand-assembled: `tools/spell-research/research.py` reads the
-- client's own DB2 tables, closes the player-reachable spell pool over `EffectTriggerSpell` (the
-- addon filters on the AURA's id, not the cast's), buckets by spell mechanic, and diffs the result
-- against this file — it never writes it. Each list records the build and date it was derived
-- against on its own definition, so a stale list is visible HERE and not only in the frozen bundle
-- under docs/spell-research/. Re-run the tool to refresh one; the accept step stays the author's.
--
-- `class` on a spell is only for grouping the editor by class; the filter ignores it.

NS.Categories = NS.Categories or {}
local Cat = NS.Categories

local function spells(list)
    local out = {}
    for class, ids in pairs(list) do
        for _, id in ipairs(ids) do out[id] = class end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Buff categories
-- ---------------------------------------------------------------------------

Cat.HELPFUL = {
    {
        key = "defensives", kind = "spells", label = "Defensive cooldowns",
        desc = "Personal defensive cooldowns.",
        spells = spells({
            -- 385391: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            WARRIOR     = { 118038, 184364, 871, 23920, 12975, 385391 },
            -- 403876: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 212641, 393108: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 389539: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 6940: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PALADIN     = { 642, 498, 31850, 86659, 184662, 205191, 403876, 212641, 393108, 389539, 6940 },
            HUNTER      = { 186265, 264735 },
            ROGUE       = { 5277, 31224, 1966 },
            -- 33206: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PRIEST      = { 47585, 19236, 33206 },
            DEATHKNIGHT = { 48792, 48707, 55233, 49039 },
            SHAMAN      = { 108271 },
            -- 235450: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 11426: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 414658: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 235313: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            MAGE        = { 45438, 342246, 235450, 11426, 414658, 235313 },
            WARLOCK     = { 104773, 108416 },
            -- 122470: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 132578: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 116849: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            MONK        = { 120954, 122278, 122783, 125174, 122470, 132578, 116849 },
            -- 102342: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DRUID       = { 22812, 61336, 102342 },
            -- 207771: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DEMONHUNTER = { 212800, 196555, 207771 },   -- Metamorphosis (162264, 187827) is Offensive cooldowns only (owner 2026-09-25)
            -- 374349: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 357170: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            EVOKER      = { 363916, 374349, 357170 },
        }),
    },
    {
        key = "bigDefensive", kind = "token", token = "BIG_DEFENSIVE", label = "Big defensives (Blizzard)",
        desc = "Auras Blizzard itself flags as big defensives.",
    },
    {
        key = "externals", kind = "token", token = "EXTERNAL_DEFENSIVE", label = "External defensives (Blizzard)",
        desc = "Defensives another player cast on the unit, as Blizzard flags them.",
    },
    {
        key = "activeMitigation", kind = "spells", label = "Active mitigation",
        desc = "Short, frequently refreshed tank mitigation.",
        -- Owner 2026-09-25: Blood Shield (77535), Shuffle (215479) and Rushing Jade Wind (116847) are
        -- not active mitigation, so Monk has no entry here.
        spells = spells({
            WARRIOR     = { 132404, 190456 },
            PALADIN     = { 132403 },
            DEATHKNIGHT = { 195181 },
            DRUID       = { 192081 },
            DEMONHUNTER = { 203819 },
        }),
    },
    {
        key = "raidCDs", kind = "spells", label = "Raid cooldowns",
        desc = "Group-wide cooldowns and haste effects.",
        spells = spells({
            -- Every Bloodlust variant sits here (owner review 2026-09-25): Bloodlust, Heroism, Time Warp,
            -- Primal Rage, Harrier's Cry, Fury of the Aspects, and the drums any class can use --
            -- 1243972 Void-touched Drums and 444257 Thunderous Drums.
            ALL         = { 1243972, 444257 },
            WARRIOR     = { 97463 },
            PALADIN     = { 31821 },
            DEATHKNIGHT = { 145629 },
            -- 740 Tranquility (owner review 2026-09-25)
            DRUID       = { 740 },
            DEMONHUNTER = { 209426 },
            PRIEST      = { 81782 },
            SHAMAN      = { 2825, 32182, 325174 },   -- Bloodlust, Heroism, Spirit Link Totem (the AURA; 98007 is the cast, issue #15)
            MAGE        = { 80353 },
            -- 466904: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            HUNTER      = { 264667, 466904 },
            -- 374227 Zephyr: in both Raid cooldowns and Movement (owner review 2026-09-25)
            EVOKER      = { 390386, 374227 },
        }),
    },
    {
        key = "offensiveCDs", kind = "spells", label = "Offensive cooldowns",
        desc = "Damage cooldowns.",
        spells = spells({
            -- 436358: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            WARRIOR     = { 1719, 107574, 436358 },
            -- 454351: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PALADIN     = { 31884, 454351 },
            DEATHKNIGHT = { 51271, 207289 },
            -- 1276767: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            WARLOCK     = { 1276767 },
            -- 252071: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DRUID       = { 194223, 102560, 106951, 102543, 252071 },
            -- 186254, 1235388, 1285912: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            HUNTER      = { 288613, 19574, 360952, 186254, 1235388, 1285912 },
            MAGE        = { 190319, 12472, 365362 },
            ROGUE       = { 121471, 13750, 185422 },
            -- 187827: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DEMONHUNTER = { 162264, 187827 },
            -- 373316: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PRIEST      = { 194249, 373316 },
            MONK        = { 137639 },
            -- 114052, 1219480: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            SHAMAN      = { 114051, 114052, 1219480 },
            -- 431698: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            EVOKER      = { 375087, 431698 },
        }),
    },
    {
        -- One list since schema v2: the former coreHealing and lesserHealing, united (core/Database.lua's
        -- MigrateV2 merges a player's edits and category states of the two).
        key = "healing", kind = "spells", label = "Healing",
        desc = "Heal-over-time effects, shields and beacons.",
        spells = spells({
            -- 1227806: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DRUID   = { 774, 8936, 33763, 48438, 102352, 155777, 207386, 1227806 },
            -- 1246768: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 77489: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 1253593: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PRIEST  = { 139, 17, 194384, 41635, 1246768, 77489, 1253593 },
            -- 383648: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 382024: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            SHAMAN  = { 61295, 974, 383648, 382024 },
            -- 1260617: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 443113: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 406220: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 1260681: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            MONK    = { 119611, 124682, 115175, 1260617, 443113, 406220, 1260681 },
            -- 367364: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 373862: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 355941: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 1291636: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 376788: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 409895: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 409678: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 363534: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 373267: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            EVOKER  = { 364343, 366155, 367364, 373862, 355941, 1291636, 376788, 409895, 409678, 363534, 373267 },
            -- 1245369: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 1244893: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 156322: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PALADIN = { 53563, 156910, 200025, 287280, 1245369, 1244893, 156322 },
        }),
    },
    {
        key = "support", kind = "spells", label = "Support",
        desc = "Buffs cast on other players.",
        spells = spells({
            -- 34477: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            HUNTER  = { 34477 },
            -- 57934: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 115834: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 1224098: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            ROGUE   = { 57934, 115834, 1224098 },
            -- 454863: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 474754: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DEATHKNIGHT = { 454863, 474754 },
            -- 10060: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PRIEST  = { 10060 },   -- Void Shield (Unfolding Vision) 1300009 removed (owner 2026-09-25)
            -- 474750: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DRUID   = { 29166, 474750 },
            -- 413984: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 360827: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 375253: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 375230: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 375226: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 375229: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 375257: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 406789: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 375256: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- Time Spiral is one aura per class (the cast 374968 applies none); all 13 are listed. 375234,
            -- 375238, 375240, 375252, 375254, 375255, 375258 added 2026-09-25: seen in the 2026-09-24 logs,
            -- mapped to their class in the 12.1 spell data.
            EVOKER  = { 369459, 413984, 360827, 375253, 375230, 375226, 375229, 375257, 406789, 375256,
                        375234, 375238, 375240, 375252, 375254, 375255, 375258 },
        }),
    },
    {
        -- Split out of Support (owner 2026-09-25): the raid-wide buffs every group member carries.
        -- Blessing of the Bronze has one aura per class; the ids are the ones the 2026-09-24 combat
        -- logs saw (docs/spell-research/2026-09-24-logs).
        key = "groupBuffs", kind = "spells", label = "Group buffs",
        desc = "Raid-wide buffs such as Mark of the Wild, Arcane Intellect and Battle Shout.",
        spells = spells({
            MAGE    = { 1459 },
            PRIEST  = { 21562 },
            WARRIOR = { 6673 },
            DRUID   = { 1126 },
            SHAMAN  = { 462854 },
            EVOKER  = { 381748, 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754,
                        381756, 381757, 381758 },
        }),
    },
    {
        key = "movement", kind = "spells", label = "Movement",
        desc = "Speed and freedom effects.",
        spells = spells({
            -- 202164: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 446044: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 1244157: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            WARRIOR = { 202164, 446044, 1244157 },
            -- 36554: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            ROGUE   = { 2983, 36554 },
            -- 48265: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 444347: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 434029: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 212552: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DEATHKNIGHT = { 48265, 444347, 434029, 212552 },
            -- 77761, 77764: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 400126: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 252216: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DRUID   = { 1850, 106898, 77761, 77764, 400126, 252216 },   -- Travel and Mount Form are Stances (owner 2026-09-25)
            -- 221883, 221885, 221887, 254471, 254472, 254474, 276111, 276112, 294133, 363608, 453804: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 394454: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- Divine Steed is one aura per mount appearance, chosen by race, glyph or bridle (the cast 190784
            -- applies none). 254473 (Vigilant Charger, seen in the logs) and 1289616, 1289617 (the pre-12.0.1
            -- Charger models, in the 12.1 spell data but not yet seen) added 2026-09-25.
            PALADIN = { 1044, 221886, 221883, 221885, 221887, 254471, 254472, 254473, 254474, 276111, 276112, 294133,
                        363608, 453804, 1289616, 1289617, 394454 },
            -- 443569: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 450552: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 119085: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            MONK    = { 116841, 443569, 450552, 119085 },
            -- 186258: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            HUNTER  = { 186257, 186258 },
            -- 260881: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 454025: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 58875: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 468226: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            SHAMAN  = { 192082, 79206, 2645, 260881, 454025, 58875, 468226 },
            -- 73325: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PRIEST  = { 121557, 65081, 73325 },
            -- 387633: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            WARLOCK = { 111400, 387633 },
            -- 374227: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 442204: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            EVOKER  = { 358267, 374227, 442204 },
        }),
    },
    {
        key = "utility", kind = "spells", label = "Utility",
        desc = "Soulstones, stealth, water walking and similar.",
        spells = spells({
            WARLOCK = { 20707, 5697 },
            PRIEST  = { 111759 },   -- Levitate (the AURA; 1706 is the cast, issue #15)
            SHAMAN  = { 546 },
            MAGE    = { 130, 32612 },
            HUNTER  = { 5384 },
            ROGUE   = { 1784 },
            DRUID   = { 5215 },
        }),
    },
    {
        -- Owner 2026-09-25. Travel Form and Mount Form are here only, not in Movement; Ghost Wolf stays
        -- in Movement.
        key = "stances", kind = "spells", label = "Stances",
        desc = "Warrior stances, druid forms and paladin auras.",
        spells = spells({
            WARRIOR = { 386164, 386196, 386208 },                    -- Battle, Berserker, Defensive Stance
            DRUID   = { 5487, 768, 24858, 114282, 165961, 1066, 40120, 210053 }, -- Bear, Cat, Moonkin, Treant, Travel (x3), Mount Form
            PALADIN = { 465, 317920, 32223 },                        -- Devotion, Concentration, Crusader Aura
            PRIEST  = { 232698 },                                    -- Shadowform
        }),
    },
    {
        -- Owner 2026-09-25. The buffs of the DB2 "Racial - <race>" skill lines' active abilities and
        -- procs (build 12.1.0.69875), passives left out; every id here but four was seen as a player
        -- buff in the 2026-09-24 combat logs (not seen: 28880, 121093, 370626 Gift of the Naaru and
        -- 281954 Pterrordax Swoop). The racial DEBUFFS are the debuff list `racialDebuffs` below.
        key = "racials", kind = "spells", label = "Racials",
        desc = "Buffs from racial abilities, such as Stoneform, Berserking and Blood Fury.",
        spells = spells({
            ALL = {
                65116,                                                  -- Stoneform (Dwarf)
                26297,                                                  -- Berserking (Troll)
                20572, 33697, 33702,                                    -- Blood Fury (Orc)
                274739, 274740, 274741, 274742,                         -- Ancestral Call (Mag'har Orc)
                273104,                                                 -- Fireblood (Dark Iron Dwarf)
                58984,                                                  -- Shadowmeld (Night Elf)
                28880, 59542, 59543, 59544, 59545, 59547, 59548, 121093, 370626, 416250, -- Gift of the Naaru (Draenei)
                7744,                                                   -- Will of the Forsaken (Undead)
                59752,                                                  -- Will to Survive (Human)
                68992, 87840, 406087,                                   -- Darkflight, Running Wild, Calm the Wolf (Worgen)
                360022, 1289789,                                        -- Chosen Identity, Battle Visage (Dracthyr)
                256948, 256374,                                         -- Spatial Rift, Entropic Embrace (Void Elf)
                291944, 281954,                                         -- Regeneratin', Pterrordax Swoop (Zandalari Troll)
                255654,                                                 -- Bull Rush (Highmountain Tauren)
                291843,                                                 -- Brush It Off (Kul Tiran)
                436344, 461063,                                         -- Azerite Surge, Quiet Contemplation (Earthen)
                1238467,                                                -- Thorn Bloom (Haranir)
            },
        }),
    },
    {
        key = "important", kind = "token", token = "IMPORTANT", label = "Important (Blizzard)",
        desc = "Auras Blizzard flags as important, the ones enemy nameplates show.",
    },
    {
        key = "castable", kind = "token", token = "RAID", label = "Castable by you",
        desc = "Buffs of a kind you can apply yourself.",
    },
    {
        key = "cancelable", kind = "token", token = "CANCELABLE", label = "Cancelable",
        desc = "Buffs the player is able to cancel.",
    },
    {
        key = "stealable", kind = "flag", field = "isStealable", value = true, label = "Stealable / purgeable",
        desc = "Buffs that can be stolen or purged — most useful on an enemy target.",
    },
    {
        key = "weaponEnchants", kind = "enchant", label = "Weapon enchants",
        desc = "Your temporary weapon enchants, drawn after the buffs. Only on a container showing your own buffs; which weapon slots count is set on General -> Spell Categories.",
    },
    {
        -- U-1: last in the grid, on purpose (renderCategories draws categoryRows() in Cat.For order).
        key = "uncategorized", kind = "uncategorized", label = "Uncategorized",
        desc = "Not in any of the Spell Categories lists above (Blizzard categories do not count). On a container watching you or your pet, Show rescues an unlisted buff from a Hidden Blizzard category; on a target or focus Blizzard may discard the spell list that rescue is built from, so Show simply changes nothing there. Hide removes the aura along with everything else this container has no other reason to draw, on every unit.",
    },
}

-- ---------------------------------------------------------------------------
-- Debuff categories
-- ---------------------------------------------------------------------------
--
-- Every category here but the first two is something the engine can evaluate for ANY unit. `hardCC`
-- and `softCC` are `spells`-kind (issue #11 part A) and so are not: Blizzard honors spell ids for
-- debuffs on HOSTILE units only, and discards them on the player, the pet and any friendly unit. The
-- two rows are still worth shipping — the question they answer ("is my sheep on the target", "is it
-- rooted") is asked of a hostile target or focus, which is exactly where the ids do bite — and every
-- surface that can mislead says so: their own descs below, the Filters page's Categories tab, the
-- General -> Spell Categories blurb, and the per-container orange warning
-- (`FC.WARN.IDS_HOSTILE_ONLY` / `IDS_OWN_DEBUFFS`, modules/FilterCompiler.lua).

local ALL_DISPELS = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

-- DERIVED AGAINST BUILD 12.1.0.69875, 2026-09-20 (spec C6). Both lists below came out of
-- `python3 tools/spell-research/research.py`, which is what regenerates them; its frozen bundle for
-- this pair is docs/spell-research/2026-09-20/ (derived.json, DIFF.md, ANALYSIS.md and the gzipped
-- raw DB2 exports). Roll this line, and the two curation notes' numbers, whenever a later run is
-- accepted — the tool never writes this file, so a list can only go stale silently if nobody is
-- told which build it was true for.

Cat.HARMFUL = {
    {
        -- ABOVE `crowdControl` on purpose: these two editable rows read before the Blizzard token
        -- they refine, which is the order a player reasons in (spec A1).
        --
        -- CURATED, not the generator's raw output, and curated BY HAND. The 2026-09-20 run bucketed
        -- 215 ids here; what ships is 59. No mechanical filter over derived.json reproduces those 59
        -- and this note does not pretend one does. Three things govern, in order:
        --   1. ONE ID PER ABILITY A PLAYER LANDS ON A TARGET, and it is the id whose mechanic and DR
        --      the TARGET carries — not the cast id, not a legacy rank, not a sibling aura out of an
        --      older id block. The one stated exception is below: a spec-split ability.
        --   2. EVERY CLASS SHIPS ITS SIGNATURE CC, for every spec that has one. A class or spec
        --      opening this list and finding its own CC missing is the failure the list exists to
        --      avoid, so a hole here outranks any amount of tidiness.
        --   3. BEYOND THAT THE LONG TAIL IS THE CURATOR'S JUDGMENT. Said in as many words because
        --      it is true: which of the remaining ids earn a row is a call, not a derivation, and a
        --      later curator may call it differently. It is a defensible call because nothing is
        --      lost — the exhaustive derived set (215 hard, 212 soft for build 12.1.0.69875) is
        --      frozen in docs/spell-research/2026-09-20/, and General -> Spell Categories lets a
        --      player add any id out of it. These two rows are A STARTER SET meant to be edited,
        --      exactly what this file says of every other list it ships.
        --
        -- WHAT THE JUDGMENT LOOKED LIKE — illustrations, not a closed list of exclusions. Out under
        -- rule 1 go duplicate ranks and variants of an ability already represented: of the 77 ids the
        -- mechanic graph reached directly, 17 are named Polymorph and 9 Hex, one of each ships, so 16
        -- and 8 of them came out (across the whole 215 those two names are 38 and 20). Out too go
        -- encounter and trinket effects that reached the pool through a trait or spec row no player
        -- casts (Hammer of Retribution 405397, Victor's Presence 1276084, Ensorcelled by Flame
        -- 1276097, Jailer's Judgment 162056, Insanity 312678, Ancient Aftershock 325886), and stuns
        -- incidental to a damage ability rather than CC anyone tracks (Fists of Fury 120086, Infernal
        -- Awakening 22703). Rule 2 pulls ids back IN from the bridged entries — the canonical CC the
        -- mechanic graph cannot reach because the ability is cast as one spell and applies its aura
        -- as another (Freezing Trap, Storm Bolt, Shockwave, Ring of Frost, Blinding Light, Holy Word:
        -- Chastise, Capacitor Totem, Intimidation), the six the domain review named as holes a player
        -- of that class notices on sight (Asphyxiate 108194, Sigil of Misery, Song of Chi-Ji, Maim
        -- and Shield Charge; the sixth was Wake of Ashes, removed — see below), and the last three
        -- the per-class sweep found: Lightning
        -- Lasso 204437 (Shaman shipped only Hex and Capacitor Totem), Rake 163505 (the Feral stealth
        -- opener's stun) and Void Nova 1234195.
        --
        -- VOID NOVA SHIPS, and it is a player ability rather than an encounter or trinket effect:
        -- 1234195 has no SkillLineAbility row at all and reaches the pool as TraitDefinition 137090,
        -- whose entry 132289 maps through node 107347 onto TraitTree 854 — the demon hunter class
        -- tree, loaded by all three DH specs (577, 581, 1480). Five files under
        -- docs/spell-research/2026-09-20/raw/ carry that chain end to end: TraitDefinition.csv.gz,
        -- TraitNodeEntry.csv.gz, TraitNodeXTraitNodeEntry.csv.gz, TraitNode.csv.gz and
        -- TraitTreeLoadout.csv.gz. Note that derived.json files this id's class as "skillline"
        -- anyway — the generator stamps that source whenever a class was reached by ANY route, so
        -- the two do not actually disagree.
        --
        -- Every id added was read out of derived.json first for name, mechanic and DR. Class was
        -- verified too, but by hand wherever derived.json is unreliable on it (see `softCC`).
        --
        -- THE ONE EXCEPTION TO RULE 1: an ability the client SPEC-SPLITS, shipping a live id per
        -- specialization rather than an old rank and a new one. Asphyxiate is the only
        -- one in this run and both ids ship — 221562 is the Blood id (the run reaches it through
        -- TraitDefinition), 108194 the Frost/Unholy one (reached through the family bridge) — because
        -- a Frost death knight watching only for 221562 would never see the stun land. The rule
        -- drops ranks and variants of ONE ability; it does not merge two live abilities that share
        -- a name, and the first draft misapplied it here.
        --
        -- WAKE OF ASHES IS DELIBERATELY ABSENT FROM BOTH ROWS. The owner removed it on 2026-09-20.
        -- It shipped here as a stun (255941) until then, and this file carried the argument for
        -- filing it as one; that argument is gone with the id, because the decision was not that the
        -- research was wrong. No id of the ability belongs on either list — not 255941, not 255937
        -- (the cast), not 205290 (the older stun aura) and not 205273 (the ancestor's slow, which
        -- `softCC` has never shipped; Paladin's Soft CC row is Judgment of Justice). A later research
        -- run WILL derive the ability into the hard-CC bucket again: leaving it out is the intended
        -- diff, not an oversight to helpfully correct. A player who wants it adds the id on
        -- General -> Spell Categories.
        --
        -- MAIM ships on 203123, not 203126. Both are aura-applying spells named Maim in this build,
        -- and the one a Feral target carries is 203123 — mechanic 12 (stunned) on DiminishType 4,
        -- the stun DR, matching the finisher's own DR category. 203126 is mechanic 14
        -- (incapacitated) on DiminishType 16, a different DR entirely. The cast, 22570, applies no
        -- aura of its own and so is not a debuff id at all.
        --
        -- KNOWN GAPS, recorded rather than papered over, because a player who notices one missing
        -- should find the reason in this file. Five abilities are absent and stay absent:
        --   * Repentance (20066), hard CC. The research run's SENTINELS_UNREACHABLE records why —
        --     its id appears in none of the four pool sources for this build, so the client grants
        --     it by a route the pipeline cannot see.
        --   * Axe Toss (89766) and Seduction (6358), hard CC, the warlock's pet CC. Both sit on a
        --     PET skill line with ClassMask 0, and the pool keeps a ClassMask-0 row only on one of
        --     the thirteen class lines — the same test that keeps professions and mounts out.
        --   * Earthbind Totem (2484), soft CC. In the pool, but it carries no mechanic and its aura
        --     is named "Earthbind", so neither the mechanic match nor the bridge's exact-name test
        --     can cross to it.
        --   * Earthgrab Totem (64695), soft CC — found while closing this review, and recorded ONLY
        --     here: the bundle under docs/spell-research/ is frozen and its ANALYSIS.md does not
        --     name it. The id is in NEITHER derived bucket, which is why Shaman ships no root at
        --     all. Same shape as Earthbind: the talent 51485 is in the pool but carries mechanic 0,
        --     and the root aura 64695 ("Earthgrab", mechanic 7) is triggered only by 116943, the
        --     totem's own pulse, which the pool never reaches.
        -- A player who wants any of the five adds it by id on General -> Spell Categories.
        key = "hardCC", kind = "spells", label = "Hard CC (loss of control)",
        desc = "Stuns, incapacitates, disorients and fears, plus Cyclone, Banish and Mind Control — the unit is not in control of itself. Only works on a hostile target or focus: Blizzard discards spell lists for debuffs on you or on a friendly unit.",
        spells = spells({
            WARRIOR     = { 5246, 132168, 132169, 385954 },          -- Intimidating Shout, Shockwave, Storm Bolt, Shield Charge
            PALADIN     = { 853, 10326, 105421 },                    -- Hammer of Justice, Turn Evil, Blinding Light
            -- 1258508: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            HUNTER      = { 1513, 3355, 24394, 117526, 213691, 1258508 },     -- Scare Beast, Freezing Trap, Intimidation, Binding Shot, Scatter Shot
            -- 427773: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            ROGUE       = { 408, 1776, 1833, 2094, 6770, 427773 },           -- Kidney Shot, Gouge, Cheap Shot, Blind, Sap
            -- 200196: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            PRIEST      = { 605, 8122, 9484, 64044, 200200, 205364, 200196 }, -- Mind Control, Psychic Scream, Shackle Horror, Psychic Horror, Holy Word: Chastise, Dominate Mind
            DEATHKNIGHT = { 108194, 111673, 207167, 221562 },        -- Asphyxiate (Frost/Unholy), Control Undead, Blinding Sleet, Asphyxiate (Blood)
            SHAMAN      = { 51514, 118905, 204437 },                 -- Hex, Capacitor Totem, Lightning Lasso
            MAGE        = { 118, 31661, 82691, 383121 },             -- Polymorph, Dragon's Breath, Ring of Frost, Mass Polymorph
            WARLOCK     = { 710, 1098, 5484, 118699, 6789, 30283 },  -- Banish, Subjugate Demon, Howl of Terror, Fear (the AURA; 5782 is the cast), Mortal Coil, Shadowfury
            MONK        = { 115078, 119381, 198909 },                -- Paralysis, Leg Sweep, Song of Chi-Ji
            DRUID       = { 99, 2637, 5211, 33786, 163505, 203123 }, -- Incapacitating Roar, Hibernate, Mighty Bash, Cyclone, Rake, Maim
            DEMONHUNTER = { 179057, 207685, 211881, 217832, 1234195 }, -- Chaos Nova, Sigil of Misery, Fel Eruption, Imprison, Void Nova
            EVOKER      = { 360806, 372245 },                        -- Sleep Walk, Terror of the Skies
            ALL         = { 20549, 107079, 287712 },                 -- War Stomp, Quaking Palm, Haymaker (racials)
        }),
    },
    {
        -- CURATED BY HAND, by the same three rules `hardCC` above states: 212 derived, 54 shipped,
        -- and no mechanical filter over derived.json reproduces those 54 either. Rule 1 picks the id
        -- the target carries — VOID TENDRILS ships on 114404, the aura, not on 108920, the cast:
        -- 114404 is the APPLY_AURA row carrying SpellCategories mechanic 7 on the root DR, while
        -- 108920 has no effect row at all in this build's export and is in neither derived bucket.
        -- Rule 2 brings back from the bridge what a class would miss: Tar Trap, Entrapment, Grip of
        -- the Dead, the five the domain review named (Void Tendrils, Steel Trap, Clash, Cone of
        -- Cold, Judgment of Justice), and the four the last per-class sweep found — Landslide 355689
        -- (the Evoker's only root, and the row shipped none), Sigil of Chains 204843 (demon hunter),
        -- Strike of the Windlord 392983 (monk) and Stormbind 1251059 (shaman), the last two the same
        -- shape as the shipped Keg Smash 121253 and Ice Strike 470194.
        --
        -- WHAT RULE 1 MEANS FOR A ROUTINE SLOW, because the first draft had this backwards: it
        -- dropped five ids as "passive procs and damage riders nobody tracks as crowd control" while
        -- shipping six of exactly that kind. A snare is a snare ON THE TARGET. If the client records
        -- a soft-CC mechanic on a debuff a player applies, the id ships, however routine the ability
        -- carrying it — the question this row answers is "can it get away from me", and a Keg Smash
        -- slow answers it as well as a Frost Nova does. So the five that were cut are back in
        -- (Moonfire 164812's talent-only snare, Chrono Shift 236299, Blast Wave 157981, Fatal
        -- Flourish 35546, Truth's Wake 403695), beside the six kept anyway (Mind Flay 15407, Heart
        -- Strike 206930, Keg Smash 121253, Ice Strike 470194, Infected Wounds 58180, Permeating
        -- Chill 370898).
        --
        -- WHAT CAME OUT, again as illustrations and not a closed list: another id for an ability
        -- already listed (Infected Wounds 345209, The Hunt 370970, Bursting Shot 224729), retired
        -- covenant and legacy rows (Fae Tendrils 342373), and most of the rest of the 212, which the
        -- run's own ANALYSIS.md reads as self-buffs' incidental slows rather than anything landed on
        -- a target. Most, not all: past rules 1 and 2 this is rule 3, judgment, and what makes that
        -- safe to say out loud is that the frozen bundle and the Spell Categories editor put every
        -- id one paste away.
        --
        -- The 40 ids the run emitted under `ALL` because it could not resolve a class were hand-keyed
        -- to the class that actually casts them where one exists — the run's own ANALYSIS.md calls
        -- grouping them under `ALL` a cosmetic lie, and `ALL` here means a racial, nothing else. The
        -- complete set of hand-keyings across BOTH rows, so the note matches what was done: Slow,
        -- Frostbite, Mass Slow, Chrono Shift and Blast Wave to MAGE, Apathy to PRIEST, Ice Strike to
        -- SHAMAN, Bursting Shot and Entrapment to HUNTER, and on `hardCC` above Scatter Shot to
        -- HUNTER, Fel Eruption to DEMONHUNTER and Psychic Horror (64044) to PRIEST. Wing Buffet
        -- (357214) is keyed to EVOKER too, though the run had it as `ALL` off a skill line rather
        -- than as unresolved. CLASS IS THE ONE FIELD derived.json IS NOT TRUSTED ON: its
        -- `classSource == "skillline"` rows are noisy — it files Frostbolt Volley 141425 under
        -- WARRIOR and Fae Tendrils 342373 under MAGE, neither of which ships — so name, mechanic and
        -- DR come from derived.json and every shipped id's class was verified by hand.
        --
        -- ABILITIES WITH BOTH A HARD AND A SOFT MECHANIC are not rare — 13 names appear in both
        -- derived buckets, seven of them with an id shipped across the two rows (Blast Wave, Blinding
        -- Sleet, Bursting Shot, Clash, Mind Flay, Ring of Frost, The Hunt). Each ships
        -- ONCE, on the id whose mechanic is the one the target actually carries, because a spell
        -- belongs to exactly one bucket and the two lists must never double-count an aura. The Hunt
        -- ships here on its root id (323996 rooted; 333762 is the stun): a demon hunter watching The
        -- Hunt on a target is watching the root that pins them. Wake of Ashes was the eighth such
        -- name and went to `hardCC`; the owner removed it from both rows on 2026-09-20, and `hardCC`
        -- says so.
        key = "softCC", kind = "spells", label = "Soft CC (roots & snares)",
        desc = "Roots and snares — the unit keeps control of itself but cannot move freely. Only works on a hostile target or focus: Blizzard discards spell lists for debuffs on you or on a friendly unit.",
        spells = spells({
            WARRIOR     = { 1715, 12323 },                           -- Hamstring, Piercing Howl
            PALADIN     = { 403695, 408383 },                        -- Truth's Wake, Judgment of Justice
            HUNTER      = { 5116, 64803, 135299, 162480, 186387, 190925, 195645 }, -- Concussive Shot, Entrapment, Tar Trap, Steel Trap, Bursting Shot, Harpoon, Wing Clip
            -- 35546 IS THE CAST AND ITS AURA IS UNKNOWN (issue #15). It applies no aura of its
            -- own and has no EffectTriggerSpell edge, so the data cannot name one; the owner's
            -- live probe could not observe one either, reporting it as a proc that fires and
            -- vanishes rather than an aura that sits on a unit. It is left as the cast id
            -- KNOWINGLY: a row that matches nothing is no worse than a row that is gone, and
            -- removing it would lose the record that this slow exists. Settle it by watching a
            -- real target while an Outlaw rogue has the talent, then swap in what lands.
            ROGUE       = { 3409, 35546, 185763 },                   -- Crippling Poison, Fatal Flourish (cast; aura unknown), Pistol Shot
            PRIEST      = { 15407, 114404, 390669 },                 -- Mind Flay, Void Tendrils, Apathy
            -- 444826: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            -- 460501: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DEATHKNIGHT = { 45524, 206930, 273977, 444826, 460501 },                 -- Chains of Ice, Heart Strike, Grip of the Dead
            SHAMAN      = { 51490, 196840, 470194, 1251059 },        -- Thunderstorm, Frost Shock, Ice Strike, Stormbind
            MAGE        = { 122, 31589, 157981, 157997, 212792, 236299, 378760, 391104 }, -- Frost Nova, Slow, Blast Wave, Ice Nova, Cone of Cold, Chrono Shift, Frostbite, Mass Slow
            WARLOCK     = { 334275, 384069 },                        -- Curse of Exhaustion, Shadowflame
            -- 116706: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            MONK        = { 116095, 121253, 123586, 324382, 392983, 116706 }, -- Disable, Keg Smash, Flying Serpent Kick, Clash, Strike of the Windlord
            DRUID       = { 339, 58180, 61391, 102359, 127797, 164812 }, -- Entangling Roots, Infected Wounds, Typhoon, Mass Entanglement, Ursol's Vortex (the AURA; 102793 is the cast), Moonfire
            -- 370970: combat-log evidence, docs/spell-research/2026-09-24-logs (SID)
            DEMONHUNTER = { 198813, 204843, 213405, 370970 },        -- Vengeful Retreat, Sigil of Chains, Master of the Glaive, The Hunt
            EVOKER      = { 355689, 357214, 368970, 370898 },        -- Landslide, Wing Buffet, Tail Swipe, Permeating Chill
            ALL         = { 260369 },                                -- Arcane Pulse (racial)
        }),
    },
    {
        -- Owner 2026-09-25: the debuffs of the DB2 "Racial - <race>" skill lines, every one seen in the
        -- 2026-09-24 combat logs. They stay in Hard CC and Soft CC as well; this list only groups them.
        -- Mechagnome's Recently Failed (313015) is left out: a lockout on yourself, where Blizzard
        -- discards a debuff spell list anyway. A key of its own, not `racials`: a key names one
        -- category across both aura types (`Cat.AuraTypeOf`).
        key = "racialDebuffs", kind = "spells", label = "Racials",
        desc = "Debuffs from racial abilities, such as War Stomp and Quaking Palm. Only works on a hostile target or focus: Blizzard discards spell lists for debuffs on you or on a friendly unit.",
        spells = spells({
            ALL = {
                20549,                                                  -- War Stomp (Tauren)
                107079,                                                 -- Quaking Palm (Pandaren)
                287712,                                                 -- Haymaker (Kul Tiran)
                260369,                                                 -- Arcane Pulse (Nightborne)
                357214, 368970,                                         -- Wing Buffet, Tail Swipe (Dracthyr)
                255723,                                                 -- Bull Rush (Highmountain Tauren)
                1238474,                                                -- Thorn Bloom (Haranir)
            },
        }),
    },
    {
        key = "crowdControl", kind = "token", token = "CROWD_CONTROL", label = "Crowd control",
        desc = "Stuns, fears, roots and similar, as Blizzard flags them.",
    },
    {
        key = "boss", kind = "flag", field = "isBossAura", value = true, label = "Boss debuffs",
        desc = "Debuffs applied by a boss.",
    },
    {
        key = "role", kind = "flag", field = "isRoleAura", value = true, label = "Role debuffs",
        desc = "Debuffs Blizzard flags as relevant to your role.",
    },
    {
        -- `priority`, not `important`: every category key is unique across BOTH lists, because a
        -- container's category states are one map and a container can change its aura type.
        key = "priority", kind = "flag", field = "isPriorityAura", value = true, label = "Priority",
        desc = "Debuffs Blizzard flags as priority.",
    },
    {
        key = "raid", kind = "token", token = "RAID", label = "Raid (you can dispel)",
        desc = "Debuffs you are able to dispel.",
    },
    {
        key = "raidInCombat", kind = "token", token = "RAID_IN_COMBAT", label = "Raid in combat",
        desc = "Debuffs Blizzard shows on raid frames during combat.",
    },
    {
        key = "groupDispellable", kind = "token", token = "RAID_PLAYER_DISPELLABLE", label = "Dispellable by your group",
        desc = "Debuffs someone in your group can dispel.",
    },
    {
        key = "dispellable", kind = "token", token = "DISPELLABLE", label = "Dispellable by anyone",
        desc = "Debuffs any class can dispel.",
    },
    {
        key = "dispels", kind = "dispel", types = ALL_DISPELS, label = "Has a dispel type",
        desc = "Magic, curse, disease, poison or bleed.",
    },
    { key = "magic",   kind = "dispel", types = { Magic = true },   label = "Magic",   desc = "Magic debuffs." },
    { key = "curse",   kind = "dispel", types = { Curse = true },   label = "Curse",   desc = "Curses." },
    { key = "disease", kind = "dispel", types = { Disease = true }, label = "Disease", desc = "Diseases." },
    { key = "poison",  kind = "dispel", types = { Poison = true },  label = "Poison",  desc = "Poisons." },
    { key = "bleed",   kind = "dispel", types = { Bleed = true },   label = "Bleed",   desc = "Bleeds." },
    {
        key = "fromNonPlayers", kind = "flag", field = "isFromPlayerOrPlayerPet", value = false,
        label = "From non-players", desc = "Debuffs applied by creatures rather than players.",
    },
    {
        key = "fromPlayers", kind = "flag", field = "isFromPlayerOrPlayerPet", value = true,
        label = "From any player", desc = "Debuffs applied by any player or their pet.",
    },
    {
        -- Restored 2026-09-16, asymmetric with the buff row — see the KINDS doc above.
        -- Hide reproduces the retired "Only these categories" toggle exactly (drops the catch-all, so
        -- only what is explicitly Shown is drawn). Show is a plain default that must NOT contribute a
        -- group of its own, and since issue #11's A2 that is a fact about the UNIT, not about this
        -- file: `hardCC` and `softCC` above give the debuff union real content, so the old reason
        -- ("there is nothing to be outside of") is dead. The live reason is that the group a Show
        -- would contribute carries one constraint, an `excludeSpellIDs` of that union, and the engine
        -- discards spell ids on every debuff container there is — on the player and pet outright, on
        -- a target or focus the moment the unit is friendly. What the engine would receive is an
        -- unrestricted HARMFUL group: every debuff drawn, every other Hide on the tab defeated.
        -- `modules/FilterCompiler.lua` gates it on `FC.IdsAlwaysHonored(unit, auraType)` — false for
        -- all four debuff units and for a `target`/`focus` buff container too — so this stays a
        -- general rule keyed on whether ids are CERTAIN to be honored, not a debuff-only special case.
        key = "uncategorizedDebuffs", kind = "uncategorized", label = "Uncategorized",
        desc = "Hide draws only what you have explicitly set to Show on this tab (the retired 'Only these categories' toggle, exactly). Show is the default and changes nothing by itself: Hard CC and Soft CC are the only debuff spell lists, and Blizzard never lets a debuff container use a spell list to rescue an aura, so there is no rescue for this row to perform.",
    },
}

-- ---------------------------------------------------------------------------
-- Aura type, stamped onto every definition (issue #10 checkpoint 2)
-- ---------------------------------------------------------------------------
--
-- From here on every definition above carries its own aura type in `def.auraType`, written once at
-- load out of the list it was declared in. Until now the type was purely IMPLICIT: a def was a buff
-- category because it sat in `Cat.HELPFUL` and a debuff one because it sat in `Cat.HARMFUL`, so
-- nothing holding a single def could ask which it was without also remembering which table handed
-- it over. The Category dropdown's buff/debuff markers (settings/GeneralSpells.lua, the same
-- issue's checkpoint 1) need exactly that question answered per def, and so does every later
-- checkpoint of issue #10.
--
-- STAMPED AT LOAD, NOT DERIVED BY LOOKUP, and the reason is the user categories checkpoint 3 brings
-- rather than tidiness. An accessor that derived the answer could only do it by searching
-- `Cat.HELPFUL` and `Cat.HARMFUL` for the key -- which answers NOTHING for a def that was never in
-- either list, and a user category is precisely that: a definition built out of the player's stored
-- data, whose aura type is their choice at creation. Deriving would leave two ways to ask the same
-- question, one for shipped categories and another for user ones, which is the split the single
-- accessor below exists to prevent. With a field, a user category simply arrives already stamped
-- and `Cat.AuraTypeOf` never learns the difference. The price is one write per def at load.
--
-- AURA TYPE IS IMMUTABLE AFTER CREATION (the plan of record's decision, 2026-09-20,
-- docs/superpowers/specs/2026-09-20-custom-spell-categories-plan.md). Nothing rewrites
-- `def.auraType` afterwards -- not this file, not the settings panel, not a migration.
-- modules/FilterCompiler.lua groups by aura type and a container's stored Show/Hide is keyed by
-- category key, so a category that changed type would orphan every container's stored state for it
-- and silently move between two different grids. Changing a user category's type means deleting it
-- and creating another.
for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
    for _, def in ipairs(Cat[auraType]) do def.auraType = auraType end
end

-- The list an aura type this build does not know gets: none (a stored ENCHANT container predates schema
-- v5, which turns it into a buff container before anything reads its categories).
local NONE = {}

--- The ordered category list for an aura type, never nil.
--- @param auraType string  "HELPFUL" | "HARMFUL"
--- @return table
function Cat.For(auraType)
    if auraType == "HELPFUL" or auraType == "HARMFUL" then return Cat[auraType] end
    return NONE
end

--- One category definition by aura type and key, or nil.
--- @return table|nil
function Cat.Find(auraType, key)
    for _, def in ipairs(Cat.For(auraType)) do
        if def.key == key then return def end
    end
    return nil
end

--- Whether `key` names a spell-list category (the only kind whose spells a player can edit).
--- @return boolean
function Cat.IsSpellCategory(key)
    local def = Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key)
    return def ~= nil and def.kind == "spells"
end

--- The aura type a category filters: "HELPFUL" or "HARMFUL". Reads the field stamped above. It
--- takes EITHER a definition or a key, so a caller holding one asks the same way as a caller
--- holding the other: settings/GeneralSpells.lua's dropdown holds defs, while everything walking a
--- container's stored `filter.categories` holds a bare key.
---
--- BOTH FORMS ARE TOTAL OVER LIVE DEFINITIONS, shipped and user alike. Given a def it reads
--- `def.auraType`, so any definition the addon built answers -- shipped ones from the load-time
--- stamp, and a user category from the same field out of its stored shape. Given a KEY it finds the
--- def through `Cat.Find`, which walks `Cat.HELPFUL` and `Cat.HARMFUL`; since checkpoint 3
--- materializes every usable user record INTO those two lists (`Cat.SyncUserCategories`), a user
--- category's key reaches its def there like any other and answers with the aura type it was created
--- under. So a caller holding a bare key out of a stored `filter.categories` types a user category
--- correctly, which is what the callers walking stored state need.
---
--- THE WIDENING CAME FOR FREE, and that is the point worth recording: nothing in this accessor
--- changed. It followed from materializing user defs into the shipped lists rather than keeping them
--- in a store of their own, which is the same decision that lets `Cat.For`, `Cat.Find`,
--- `Cat.IsSpellCategory`, `Cat.DefaultStates` and settings/Filters.lua's grids stay single-path.
---
--- A key nothing knows answers nil rather than failing, the same as `Cat.Find`. A stored container
--- can perfectly well name a category this build does not have -- an older profile's retired key, a
--- user category belonging to a DIFFERENT profile than the live one, and after checkpoint 5 a
--- deleted user category -- so the caller decides what that means.
---
--- Aura type is IMMUTABLE after creation; the note above the stamping loop says why.
--- @param defOrKey table|string  a category definition, or a category key
--- @return string|nil
function Cat.AuraTypeOf(defOrKey)
    local def = defOrKey
    if type(def) == "string" then def = Cat.Find("HELPFUL", def) or Cat.Find("HARMFUL", def) end
    if type(def) ~= "table" then return nil end
    return def.auraType
end

--- Every category key across both lists, each mapped to "show" — the default state (schema v3:
--- Show is the absence of a decision, so it excludes nothing). The container template's
--- `filter.categories` is built from this, so a key added in a later version reaches every stored
--- container through the ordinary backfill and resolves for the schema validator.
--- @return table
function Cat.DefaultStates()
    local out = {}
    for _, list in ipairs({ Cat.HELPFUL, Cat.HARMFUL }) do
        for _, def in ipairs(list) do out[def.key] = "show" end
    end
    return out
end

--- The default states with every BUFF category Hidden except `keys`, which stay Show: a container
--- that draws only the buffs those categories claim (the "Player cooldowns" starter,
--- defaults/Profile.lua). That hides every Blizzard token and flag category, Weapon enchants and
--- Uncategorized too, so an unlisted buff has no Show left to draw it. The debuff categories keep
--- Show: inert on a buff container, and a later switch to debuffs does not start all-hidden.
--- @param keys table  category keys of Cat.HELPFUL
--- @return table
function Cat.StatesShowing(keys)
    local out = Cat.DefaultStates()
    for _, def in ipairs(Cat.HELPFUL) do out[def.key] = "hide" end
    for _, key in ipairs(keys) do out[key] = "show" end
    return out
end

--- The states of an ENCHANT-ONLY buff container (schema v5, feedback #6): every buff category Hidden
--- but Weapon enchants, Uncategorized included, so the container draws the player's temporary weapon
--- enchants and no aura at all. The v5 migration (core/Database.lua) and `/am new enchants`
--- (settings/Slash.lua) both build one from this.
--- @return table
function Cat.EnchantOnlyStates()
    return Cat.StatesShowing({ "weaponEnchants" })
end
