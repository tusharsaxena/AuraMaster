local _, NS = ...

-- settings/Filters.lua — what a container shows.
--
--     band          [Container ▾]
--     [ General ][ Categories ][ Overrides ][ Sorting ][ Situations ]
--     General       the rows, then the priority block (spec §6) at the foot of the tab
--     Categories    Blizzard Categories   [Show all][Hide all], then Show · Hide · Category, plus an
--                                         info icon (N-5)
--                   Spell Categories      NOTE (containers whose FC.IdsMode is not "always"), then
--                                         [Show all][Hide all], the same grid, plus a `See spells`
--                                         link; hidePermanentEnchants beneath it (buffs), and the
--                                         spell-list note beneath it (debuffs)
--                   Dispel Types · Who Cast It  (debuffs) [Show all][Hide all], the same grid
--     Overrides     NOTE (the same containers), then
--                   Whitelist  [Add a spell ____________][ Add ]  <icon> Name (id)  [Remove]
--                   Blacklist  the same
--     Situations    Unit type       Unit type [▾] Reaction [▾] (target, focus), or a note (player, pet)
--                   Where spell lists don't apply   the unit line, then On NPCs [▾] On players [▾]
--                                   (target, focus), Your own and your pet's debuffs [▾] (player and
--                                   pet debuffs) or a note (player and pet buffs), the honor line,
--                                   and the timeless note
--                   Show in         Open world, Dungeons, Scenarios and delves, Raids, Battlegrounds,
--                                   Arenas
--
-- Every row here compiles, through modules/FilterCompiler.lua, into the aura groups Blizzard's aura
-- engine evaluates in its own code — we never read an aura while it is secret, so every filter is a
-- declaration made in advance. What the engine will silently not honor for this container (spell
-- ids on a debuff container on yourself, say) is printed in orange above every tab.
--
-- The category rows are generated from defaults/Categories.lua and offered only for the aura type
-- they belong to (`auraTypes`); a category is a two-state choice, stored as "show" / "hide" and
-- labeled Show / Hide. Show is a POSITIVE claim (spec §6, revised 2026-09-15): an aura in at least
-- one category set to Show is drawn even if another of its categories says Hide, and only an aura
-- whose every category says Hide is removed by them. The priority block at the foot of the What to
-- show tab states the whole order, Overrides included, and is the only place that does. The rows stay in the
-- schema, so `/am get|set|list`, Defaults and the resets see them, but carry `skipRender`: the
-- Categories tab, bespoke and keyed by the group's name, draws them as one ChoiceGrid per `grid`.
-- Which spells a spell category matches is the profile's, edited on General → Spell Categories
-- (settings/GeneralSpells.lua); each spells/enchant row's grid line carries a `See spells` link
-- there (F-3).
--
-- The Overrides tab is bespoke: two ID lists over the container's whitelist and blacklist, each set
-- written WHOLE through the write seam (settings/Schema.lua's carve-outs). They are not schema rows,
-- so the page's Defaults leaves them alone.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local Cat = NS.Categories
local FC = NS.FilterCompiler

local PAGE = "filters"
local BUFFS_DEBUFFS = { HELPFUL = true, HARMFUL = true }

-- The first tab was "What to show" until the owner renamed it (2026-09-20): every other container
-- section opens on a tab called General, and this one asks the same kind of question. The name is
-- per SECTION — the library's O.RenderTabbedSchema builds a section's strip out of the groups of
-- NS.SchemaForPage(pageKey) alone — so it does not meet the General groups of the Text and Bars
-- sections.
local G_SHOW, G_CATS, G_SORT, G_SIT = L["General"], L["Categories"], L["Sorting"], L["Situations"]

NS.RegisterSchemaRows({
    {
        path = "container.filter.castBy", page = PAGE, group = G_SHOW, auraTypes = BUFFS_DEBUFFS,
        type = "string", values = NS.Choices(C.CAST_BY, C.CAST_BY_LABELS), label = L["Cast by"],
        desc = L["Show every aura, only yours (and your pet's), or only other people's."],
    },
    {
        path = "container.filter.durationMode", page = PAGE, group = G_SHOW, auraTypes = BUFFS_DEBUFFS,
        type = "string", values = NS.Choices(C.DURATION_MODES, C.DURATION_MODE_LABELS), label = L["Duration"],
        desc = L["Only timed auras, only permanent ones, or both. 'Without a duration' learns which buffs are timed while you are out of combat; a new one may show once before it is learned."],
    },
    {
        path = "container.filter.maxDuration", page = PAGE, group = G_SHOW, auraTypes = BUFFS_DEBUFFS,
        type = "number", min = 0, max = 3600, step = 5, label = L["Max duration"],
        desc = L["Hide auras whose full duration is longer than this — a 60 keeps short cooldowns and drops hour-long buffs. 0 is no limit, and permanent auras are hidden while a limit is set. There is no minimum: the engine can cap a duration but cannot require one."],
    },
})

-- The preset dropdown beside Max duration (pairWith, below). Not a separate setting: it writes the
-- SAME path the slider does, so there is one stored value and the two controls can never disagree.
-- A stored value matching no preset leaves the dropdown blank rather than snapping the slider to
-- the nearest one — silently changing a player's stored number is worse than a blank dropdown.
local MAX_DURATION_PRESETS = { 0, 30, 60, 300, 600, 1800 }
local MAX_DURATION_LABELS = {
    [0] = L["No limit"], [30] = L["30 seconds"], [60] = L["1 minute"],
    [300] = L["5 minutes"], [600] = L["10 minutes"], [1800] = L["30 minutes"],
}

--- Max duration's right half (pairWith): a dropdown over the same presets, writing the same path
--- through NS.SetByPath so the slider and the dropdown share one stored value.
local function maxDurationPresets(_, line)
    local list, order = {}, {}
    for i, seconds in ipairs(MAX_DURATION_PRESETS) do
        list[seconds] = MAX_DURATION_LABELS[seconds]
        order[i] = seconds
    end
    local cfg, id = NS.ActiveContainer()
    local stored = cfg and cfg.filter and cfg.filter.maxDuration
    local dd = NS.CreateDropdown()
    dd:SetLabel(L["Preset"])
    dd:SetList(list, order)
    -- A stored value with no matching preset stays unset (list[stored] == nil): the dropdown shows
    -- blank rather than the library snapping it to the nearest entry.
    dd:SetValue(list[stored] and stored or nil)
    dd:SetRelativeWidth(0.5)
    dd:SetCallback("OnValueChanged", function(_, _, v)
        NS.SetByPath("container.filter.maxDuration", v, id)
    end)
    line:AddChild(dd)
    return dd
end

-- ── Categories ────────────────────────────────────────────────────────────────────────────────

local STATES = NS.Choices(C.CATEGORY_STATES, C.CATEGORY_STATE_LABELS)

-- Which grid a category is drawn in, by its kind. Who cast it is a flag with a grid of its own.
-- weaponEnchants (kind "enchant") shares "custom" with hidePermanentEnchants below, so B5's tab finds
-- both together. `uncategorized` (U-1) shares it too and is drawn last (Cat.For's declaration order,
-- which categoryRows preserves) — it is the Spell Categories grid's complement row, not a list of its
-- own, but it belongs beside the lists it is defined against.
local GRID_BY_KIND = { spells = "custom", token = "blizzard", flag = "blizzard", dispel = "dispel", enchant = "custom", uncategorized = "custom" }

local function gridOf(def)
    if def.field == "isFromPlayerOrPlayerPet" then return "who" end
    return GRID_BY_KIND[def.kind] or "blizzard"
end

-- F-7: the two-state tooltip. Show is a positive claim — it draws the aura even if another of the
-- aura's categories says Hide (spec §6 rank 3). Hide, on its own, only removes what nothing else
-- claims; the priority blurb above the grids spells out the full order. The old Default/Whitelist/
-- Blacklist wording this replaced is gone from here, locales/enUS.lua and the docs.
local STATE_DESC = L["Show: this category shows the aura, even if another of its categories says Hide. Hide: this category alone never shows it — a Show on another of its categories still can."]

--- One category's Show/Hide row. EXPORTED because a user category's row (issue #10 checkpoint 3,
--- defaults/UserCategories.lua's Cat.SyncUserCategories) has to be built by this exact function rather
--- than by a second one written to look like it: the two would otherwise drift in `grid`,
--- `skipRender`, `printLabel`, `auraTypes`, `values` or the shape of `desc`, and every one of those
--- is read by code whose correctness rests on not being able to tell a user row from a shipped one.
---
--- `auraTypes` comes off `def.auraType` (checkpoint 2's stamped field) rather than off a loop
--- variable, so a definition materialized at runtime types itself the same way a shipped one does.
--- `userCategory` rides along from the definition, so NS.UnregisterSchemaRows can find again exactly
--- the rows the sync owns; a shipped row carries the field as nil, never false, so the schema stays
--- byte-for-byte what it was before this checkpoint.
--- @param def table  a category definition
--- @return table
function NS.CategoryRow(def)
    return {
        path = "container.filter.categories." .. def.key, page = PAGE, group = G_CATS,
        grid = gridOf(def), skipRender = true, printLabel = true,
        auraTypes = { [Cat.AuraTypeOf(def)] = true },
        type = "string", values = STATES, label = Cat.LabelOf(def),
        desc = ("%s\n\n%s"):format(L[def.desc], STATE_DESC),
        userCategory = def.userCategory or nil,
    }
end

local function categoryRows(auraType)
    local rows = {}
    for _, def in ipairs(Cat.For(auraType)) do
        rows[#rows + 1] = NS.CategoryRow(def)
    end
    return rows
end

NS.RegisterSchemaRows(categoryRows("HELPFUL"))
NS.RegisterSchemaRows(categoryRows("HARMFUL"))

-- hidePermanentEnchants stays a typed row of its own (not a Show/Hide category, so no `grid`: a
-- ChoiceGrid cell lights by comparing the stored value against a column's "show"/"hide" string,
-- which a bool row can never match — the click would still WRITE the string, though, permanently
-- truthy from then on). It moves in with the category group and carries `skipRender`, so
-- renderCategories' plain-row pass below draws it as an ordinary checkbox; B5's tab re-places it
-- under the weaponEnchants row it belongs to.
NS.RegisterSchemaRows({
    {
        path = "container.filter.hidePermanentEnchants", page = PAGE, group = G_CATS,
        skipRender = true,
        auraTypes = { HELPFUL = true }, type = "bool", label = L["Hide enchants without a duration"],
        desc = L["Skip weapon enchants that never expire."],
    },
})

-- ── Sorting ───────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    {
        path = "container.filter.sortMethod", page = PAGE, group = G_SORT, auraTypes = BUFFS_DEBUFFS,
        type = "string", values = NS.Choices(C.SORT_METHODS, C.SORT_METHOD_LABELS), label = L["Sort by"],
        desc = L["This sorts WITHIN each engine group, not the whole container; groups are laid out one after another by category, each sorted internally. With nothing on Categories Hidden, this container is one group, so this sorts the whole thing together. Otherwise — something is Hidden — each category set to Show gets its own group (the Uncategorized row is the exception: it only ever gets its own group on a container showing your own or your pet's buffs, where Blizzard is certain to honor the spell list that group is built from), and EACH of those groups is sorted separately before its block is laid out. 'Grouped' variants keep permanent auras together within a group."],
    },
    {
        path = "container.filter.sortDirection", page = PAGE, group = G_SORT,
        type = "string", values = NS.Choices(C.SORT_DIRECTIONS, C.SORT_DIRECTION_LABELS), label = L["Direction"],
        desc = L["Reverses the order within each engine group (see Sort by), not the whole container. With nothing on Categories Hidden, this container is one group, so this reverses the whole thing. Otherwise — something is Hidden — each category set to Show gets its own group (the Uncategorized row is the exception: it only ever gets its own group on a container showing your own or your pet's buffs, where Blizzard is certain to honor the spell list that group is built from), and EACH of those groups is reversed separately; the groups' own layout order does not change."],
    },
    {
        path = "container.filter.maxAuras", page = PAGE, group = G_SORT, auraTypes = BUFFS_DEBUFFS,
        type = "number", min = 0, max = 40, step = 1, label = L["Max auras per group (0 = no limit)"],
        desc = L["The cap applies to each engine group, not the whole container. With nothing on Categories Hidden, this container is one group, so the cap is the container's. Otherwise — something is Hidden — each category set to Show gets its own group (the Uncategorized row is the exception: it only ever gets its own group on a container showing your own or your pet's buffs, where Blizzard is certain to honor the spell list that group is built from), and the cap applies to EACH of those groups separately."],
    },
})

-- ── Situations (S5) ───────────────────────────────────────────────────────────────────────────
--
-- The data behind the Situations tab: where Blizzard won't apply spell lists, what NPCs and players
-- draw (`filter.situations`), the instance types the container shows in (`filter.zones`), and the
-- units a target or focus container shows for (`filter.unitFilter`, S6). All three live under `filter` in the container template, so Copy settings from -> Filters, Duplicate, this
-- page's Defaults and a profile reset carry them, and the load backfill stamps them into every
-- stored container. Every row validates, so a whole-section write (a copy) refuses a bad leaf.
--
-- THE LAST TAB (owner, 2026-10-02). The rows are the Situations group, declared here, after Sorting's,
-- so the strip reads General | Categories | Overrides | Sorting | Situations: the library builds it
-- from the groups in declaration order, and the bespoke tab below is keyed by the group, so it takes
-- the group's place rather than carrying a `before`. Each row keeps `auraTypes`, so a container of no
-- known aura type has no rows in the group and no empty tab. The tab draws the rows itself
-- (renderSituations), through the flow engine, so none carries `skipRender`.
--
-- The zone and Unit type rows take the combat-legal visibility pass. The situation rows take the `view` effect:
-- modules/ContainerManager.lua runs CM.ApplyViews for that container at once, in combat too, never
-- held behind the apply hold (no plan reads them, so nothing needs a re-apply; SI-03).

local SITUATION_OK = {}
for _, mode in ipairs(C.SITUATION_MODES) do SITUATION_OK[mode] = true end

local function validSituation(v) return SITUATION_OK[v] == true end
local function validZone(v) return type(v) == "boolean" end

-- The Unit type gate (S6, the addendum): two choices, each validated against its list.
local UNIT_ROWS = {
    { key = "kind", keys = C.UNIT_KINDS, labels = C.UNIT_KIND_LABELS, label = L["Unit type"],
      desc = L["Show this container only for an NPC or only for a player. An unlocked container, or one in test mode, still shows so you can find it."] },
    { key = "reaction", keys = C.UNIT_REACTIONS, labels = C.UNIT_REACTION_LABELS, label = L["Reaction"],
      desc = L["Show this container only for a unit that is friendly, neutral or hostile to you. An unlocked container, or one in test mode, still shows so you can find it."] },
}

local SITUATION_ROWS = {
    { key = "npcs", label = L["On NPCs"],
      desc = L["Where Blizzard won't apply spell lists to this container's auras, what an NPC shows: every aura once, or only the Blizzard categories set to Show."] },
    { key = "players", label = L["On players"],
      desc = L["Where Blizzard won't apply spell lists to this container's auras, what a player shows: every aura once, or only the Blizzard categories set to Show."] },
}

local function situationRows()
    local rows, values = {}, NS.Choices(C.SITUATION_MODES, C.SITUATION_MODE_LABELS)
    for _, s in ipairs(SITUATION_ROWS) do
        rows[#rows + 1] = {
            path = "container.filter.situations." .. s.key, page = PAGE, group = G_SIT,
            auraTypes = BUFFS_DEBUFFS,
            type = "string", values = values, label = s.label, desc = s.desc,
            validate = validSituation, effect = "view",
        }
    end
    for _, zone in ipairs(C.ZONE_KEYS) do
        rows[#rows + 1] = {
            path = "container.filter.zones." .. zone, page = PAGE, group = G_SIT,
            auraTypes = BUFFS_DEBUFFS,
            type = "bool", label = L[C.ZONE_LABELS[zone]],
            desc = L["Show this container in this kind of zone. An unlocked container, or one in test mode, still shows anywhere so you can find it."],
            validate = validZone, effect = "visibility",
        }
    end
    for _, u in ipairs(UNIT_ROWS) do
        local ok = {}
        for _, k in ipairs(u.keys) do ok[k] = true end
        rows[#rows + 1] = {
            path = "container.filter.unitFilter." .. u.key, page = PAGE, group = G_SIT,
            auraTypes = BUFFS_DEBUFFS,
            type = "string", values = NS.Choices(u.keys, u.labels), label = u.label, desc = u.desc,
            validate = function(v) return ok[v] == true end, effect = "visibility",
        }
    end
    return rows
end

NS.RegisterSchemaRows(situationRows())

-- ---------------------------------------------------------------------------
-- The bespoke tabs
-- ---------------------------------------------------------------------------

-- ── Categories: one grid per kind ────────────────────────────────────────────────────────────

-- The grids in the order they are drawn; one with no row for this aura type is not drawn at all.
-- F-1: the "custom" grid — spells-kind categories plus the weaponEnchants row (F-5) — is headed
-- Spell Categories, not Custom Categories: that is what General → Spell Categories calls the same
-- lists (settings/GeneralSpells.lua).
local GRIDS = {
    { key = "blizzard", heading = L["Blizzard Categories"] },
    { key = "custom",   heading = L["Spell Categories"] },
    { key = "dispel",   heading = L["Dispel Types"] },
    { key = "who",      heading = L["Who Cast It"] },
}

local COLUMNS = {}
for i, value in ipairs(C.CATEGORY_STATES) do
    COLUMNS[i] = { value = value, label = L[C.CATEGORY_STATE_LABELS[value]] }
end

--- The category key a row's path names ("container.filter.categories.<key>"), or nil.
local function keyOfCategoryRow(row)
    return row.path and row.path:match("^container%.filter%.categories%.(.+)$")
end

-- N-4: colors the `See spells` link a WoW-hyperlink blue and the info icon a muted gray, so the
-- extra column reads as controls rather than as more label text. Applied at the call site, never
-- baked into the locale value (localization-§2 keeps a locale VALUE equal to its key; an escape
-- sequence in the string a translator copies would be a second thing to get wrong).
local LINK_COLOR = "|cff6699ff"
local ICON_COLOR = "|cffbbbbbb"
local COLOR_END  = "|r"

-- N-5: a Blizzard category (kind "token" or "flag") is decided by the engine's own secure code —
-- the addon never sees which auras are in it, only whether a given aura currently matches (F-4's
-- filter compile). The tooltip must say so, every time, which is why it is ONE shared disclaimer
-- (below) rather than repeated per category. The per-category text under it names a FEW plausible
-- auras — illustrative, never a claim of completeness — keyed by `def.key`, the category's own
-- schema key, so a category with no entry here simply draws no icon (safer than a placeholder).
local BLIZZARD_DISCLAIMER = L["This is Blizzard's own category, decided by its secure combat code; the addon cannot list every aura it applies to. The examples below are illustrative, not a complete or verified list."]

local BLIZZARD_INFO = {
    bigDefensive = L["Blizzard flags this aura as a major defensive cooldown. Illustrative examples: Ice Block, Divine Shield, Guardian Spirit."],
    externals = L["Blizzard flags this as a defensive effect cast on you by someone else. Illustrative examples: Pain Suppression, Guardian Spirit, Life Cocoon."],
    important = L["Blizzard flags this as important enough to show on enemy nameplates. Illustrative examples: Polymorph, Fear, Hex."],
    castable = L["Blizzard flags this as a buff you are able to cast on yourself or another raid member. Illustrative examples: Power Word: Fortitude, Mark of the Wild, Arcane Intellect."],
    cancelable = L["Blizzard flags this buff as one the player can cancel by right-clicking it off. Illustrative examples: Path of Frost, Aspect of the Cheetah, Levitate."],
    stealable = L["Blizzard flags this buff as one that can be stolen (Spellsteal) or purged (Purge, Devour Magic). Illustrative examples: Ice Barrier, Power Word: Shield, Riptide."],
    crowdControl = L["Blizzard flags this debuff as crowd control. Illustrative examples: Polymorph, Fear, Cyclone."],
    boss = L["Blizzard flags this debuff as applied by a boss encounter. Illustrative examples: a boss's stacking damage-over-time effect, a boss's tank-swap debuff, a boss's enrage-adjacent mechanic."],
    role = L["Blizzard flags this debuff as relevant to your assigned raid role. Illustrative examples: a tank-targeted mechanic, a healer-targeted mechanic, a damage-dealer-targeted mechanic."],
    priority = L["Blizzard flags this debuff as high priority to notice. Illustrative examples: a stacking raid-wide damage-over-time effect, an add's enrage buff, a mechanic that needs an immediate response."],
    raid = L["Blizzard flags this debuff as one your class is able to dispel. Illustrative examples: a Magic effect a Mage can dispel, a Curse a Druid can dispel, a Disease a Priest can dispel."],
    raidInCombat = L["Blizzard flags this debuff as one shown on raid frames during combat. Illustrative examples: a raid-wide damage-over-time effect, a debuff healers are expected to track."],
    groupDispellable = L["Blizzard flags this debuff as dispellable by someone in your group. Illustrative examples: a Poison a Rogue's group can cleanse, a Disease a Death Knight's group can cleanse."],
    dispellable = L["Blizzard flags this debuff as dispellable by any class. Illustrative examples: a common Magic effect, a widespread Curse effect."],
}

-- F-3/N-4/N-5: the Spell Categories AND Blizzard Categories grids' shared extra column — a `See
-- spells` link to that row's list on General → Spell Categories for a `spells`-kind row and the
-- `enchant` row (weaponEnchants), because that tab can draw both (NS.GeneralSpells.Select); an
-- info icon for a `token`- or `flag`-kind row (N-5); blank for every other kind (dispel, the "who
-- cast it" flag rows, uncategorized — the caster-identity flag rows draw in their own "who" grid
-- and are the addon's own computation, not a Blizzard secret, so they earn no disclaimer). `Cat.Find`
-- rather than `Cat.IsSpellCategory`, which only recognizes kind "spells" and would silently drop the
-- enchant row's link.
local CATEGORY_EXTRA = {
    header = "",
    cell = function(row)
        local key = keyOfCategoryRow(row)
        local def = key and (Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key))
        if not def then return nil end
        if def.kind == "spells" or def.kind == "enchant" then
            return {
                text = LINK_COLOR .. L["See spells"] .. COLOR_END,
                tooltip = L["Opens General -> Spell Categories with this category's list selected."],
                onClick = function()
                    NS.GeneralSpells.Select(key)
                    NS.OpenOptionsPage("general")
                    H.SelectTab("general", L["Spell Categories"])
                end,
            }
        end
        if def.kind == "token" or def.kind == "flag" then
            local info = BLIZZARD_INFO[def.key]
            if not info then return nil end
            return {
                text = ICON_COLOR .. L["(info)"] .. COLOR_END,
                tooltip = ("%s\n\n%s"):format(BLIZZARD_DISCLAIMER, info),
            }
        end
        return nil
    end,
}

-- F-4/spec §6: the five ranks, highest first. ONE place in the panel states them — the BOTTOM of the
-- General tab. Rank 1 is the whitelist, rank 2 the blacklist (revised 2026-09-15: the whitelist
-- beats the blacklist, and rank 3's Show is a positive claim that rescues an aura from a Hide
-- elsewhere).
-- Batch 7: rank 5's trailing "UNLESS 'Only these categories' is on" clause is gone —
-- the toggle is retired (D8/R-8..R-11 superseded; `Uncategorized = Hide` says the same thing now, on
-- buffs — see `UNCATEGORIZED_NOTE` below).
--
-- WHERE IT LIVES (batch 8, from the owner's screenshots). It used to be restated verbatim at the
-- TOP of BOTH the Categories and the Overrides tabs — "two halves of one decision" — which put a
-- five-line wall of small text between the player and the controls, twice: "right now it looks
-- horrible". It is now drawn once, after the General rows, through the flow engine's `afterGroup`
-- hook (the page spec at the bottom of this file). General is the tab where the player asks what
-- this container shows at all, so the order that settles it is a footnote to that answer rather
-- than a preamble to two grids.
--
-- T-2 (batch 7) had already broken the old single dense paragraph into one line per rank; this keeps
-- that and adds the frame around it, all from helpers that already exist (no new widget type, and
-- OptionsWidgets.lua still has no bullet/list maker to reach for): an H.Section so the block is
-- announced and separated by the library's own heading rule, the lead-in, and each rank its own
-- H.TextRow, with a hairline spacer between ranks so five lines read as five lines.
--
-- THE SIZE (owner, 2026-09-20, from the live panel): the ranks used to pass GameFontHighlight, the
-- larger face, because batch 8 read the AceGUI Label default as too small. Against the Overrides
-- tab's own Whitelist/Blacklist notes — plain H.TextRow calls with no opts, so the Label default —
-- the block shouted. The ranks now pass NO fontObject either, so the two read at one size
-- (LibKa0s/OptionsWidgets.lua's applyLabelFont only overrides when a name is passed), and the
-- lead-in drops from GameFontNormal to GameFontNormalSmall so it shrinks with them while keeping
-- the normal font's own color.
--
-- THE HEADING is "Filter priority logic" (same owner pass): "Which aura wins" read as a question
-- the tab was asking rather than as the name of the rule below it.
--
-- The WORDING of the ranks is untouched, and is still verified rank by rank against
-- modules/FilterCompiler.lua's own header comment (same five ranks, same order).
local PRIORITY_HEADING = L["Filter priority logic"]
local PRIORITY_LEAD = L["Highest priority first:"]
local PRIORITY_RANKS = {
    L["1. On the Overrides whitelist — always shown."],
    L["2. On the Overrides blacklist — hidden, unless the whitelist already claimed it."],
    L["3. In at least one category set to Show — shown, even if another of its categories says Hide."],
    L["4. In categories that all say Hide — hidden."],
    L["5. In no category at all — shown, nothing removed it."],
}

-- Between two rank lines: enough that they are not read as one wrapped paragraph, small enough that
-- the five still read as one block. Deliberately smaller than H.ROW_VSPACER, which is the gap
-- between two CONTROLS.
local PRIORITY_RANK_GAP = 4

--- The priority block at the foot of the General tab: a heading, the lead-in, then one line per
--- rank. H.Section supplies the gap above it (the library adds its own top spacer once a group has
--- been drawn), so this adds none of its own.
local function renderPriorityBlurb(ctx)
    local scroll = H.EnsureScroll(ctx)
    H.Section(ctx, PRIORITY_HEADING)
    H.TextRow(ctx, PRIORITY_LEAD, { fontObject = "GameFontNormalSmall" })
    if scroll then H.AddSpacer(scroll, PRIORITY_RANK_GAP) end
    for _, line in ipairs(PRIORITY_RANKS) do
        -- No fontObject: the AceGUI Label default, which is the size the Overrides notes read at.
        H.TextRow(ctx, line)
        if scroll then H.AddSpacer(scroll, PRIORITY_RANK_GAP) end
    end
end

-- U-1..U-5/item 7: the cost of Uncategorized's default (Show) is not obvious from the grid alone —
-- hiding a Blizzard category does little on its own while it is Show, since most auras are unlisted
-- and Uncategorized keeps rescuing them under rank 3. Drawn right under the Spell Categories grid, in
-- the tab's own text rather than a tooltip only the row's own label would carry.
--
-- PRINTED ONLY WHERE THE RESCUE CAN HAPPEN, which since issue #11's A2 is a question about the UNIT,
-- not about the aura type. The rescuing group carries one constraint, an `excludeSpellIDs` of the
-- categorized union, so `modules/FilterCompiler.lua` emits it only where the engine is CERTAIN to
-- apply spell ids — `FC.IdsMode` answering "always", for buffs on the player and the pet alone. Anywhere
-- else (every debuff container; a buff container on a `target` or `focus`, which may be one you
-- cannot assist when the engine looks) Uncategorized Show contributes nothing, so this sentence would describe a rescue
-- the plan does not contain and would contradict the row's own tooltip in the same glance. The old
-- gate was `customGridHasEditableList`, i.e. "is this a buff container", which was the right answer
-- for the wrong reason and stopped being either once `Cat.HARMFUL` gained spell lists.
local UNCATEGORIZED_NOTE = L["Uncategorized defaults to Show, which rescues any aura not on the lists above from a Hidden Blizzard category (rank 3 beats rank 4). To actually hide a Blizzard category's auras, set BOTH it and Uncategorized to Hide."]

-- A3 (issue #11): the three CC lists and Racials are the debuff spell lists, and Blizzard honors spell
-- ids for debuffs only on a unit you CANNOT assist (UnitCanAssist; neutral units included) — on you,
-- your pet or an assistable unit it skips the list. Since the spell-list views (SV-05) the rows are not
-- inert there: those containers draw the view their Situations setting picks (every aura once, or the
-- blizzard view), so the note points there (SI-06). Said here, under the grid that offers them, in the same voice the
-- Overrides whitelist uses for the same engine limit ("Blizzard only honors this for buffs on units
-- you can assist and debuffs on units you can't", renderOverrides below). Drawn only on a
-- debuff container that actually got a `spells`-kind row, so it appears beside the rows it is about
-- and never on a buff tab, where the limit is the mirror one and the whitelist note already covers
-- it. The per-container orange warning above every tab (FC.WARN.IDS_ASSISTABLE / IDS_OWN_DEBUFFS)
-- is the other half: it says the same thing for the container's actual unit, this says it for the
-- rows regardless of unit.
local SPELL_LIST_DEBUFF_NOTE = L["The CC lists and Racials only match on a target or focus you can't assist. On your own, your pet's or an assistable unit's debuffs they match nothing, and the Situations tab picks what draws there."]

-- SV-04 (spell-list views, V4): where Blizzard does not apply spell ids, a container draws its blizzard
-- view (modules/FilterViews.lua), in which every spell category's group, the whitelist and the
-- catch-all are NEVER: only the Blizzard categories set to Show draw. Said at the head of the two
-- surfaces that view switches off, on every container whose `FC.IdsMode` is not "always", in the
-- words of the units it is about. One whole sentence per unit wording, so each is a single locale key.
-- "always" (buffs on the player or the pet) has no entry: ids always apply there. The two NOTEs point
-- to the Situations tab (SI-05), which says what draws there instead; its own unit line is the third
-- surface, in the same words.
local VIEW_NOTES = {
    categories = {
        own          = L["NOTE: on your own debuffs, these spell categories are not applied (see Situations)."],
        pet          = L["NOTE: on your pet's debuffs, these spell categories are not applied (see Situations)."],
        assistable   = L["NOTE: on units you can assist, these spell categories are not applied (see Situations)."],
        unassistable = L["NOTE: on units you can't assist, these spell categories are not applied (see Situations)."],
    },
    overrides = {
        own          = L["NOTE: on your own debuffs, these Overrides are not applied (see Situations)."],
        pet          = L["NOTE: on your pet's debuffs, these Overrides are not applied (see Situations)."],
        assistable   = L["NOTE: on units you can assist, these Overrides are not applied (see Situations)."],
        unassistable = L["NOTE: on units you can't assist, these Overrides are not applied (see Situations)."],
    },
    situations = {
        own          = L["On your own debuffs, spell lists don't apply to this container."],
        pet          = L["On your pet's debuffs, spell lists don't apply to this container."],
        assistable   = L["On units you can assist, spell lists don't apply to this container."],
        unassistable = L["On units you can't assist, spell lists don't apply to this container."],
    },
}

--- The unit wording ("own", "pet", "assistable" or "unassistable") for where spell ids do not apply
--- to container `cfg`, or nil where they always do; and the container's FC.IdsMode. "never" is the
--- player's or the pet's debuffs; "dynamic" is a target or focus, whose buffs lose their ids on a
--- unit you can't assist and whose debuffs lose them on one you can.
local function viewWhich(cfg)
    local unit = cfg and cfg.unit
    local auraType = (cfg and cfg.auraType == "HARMFUL") and "HARMFUL" or "HELPFUL"
    local mode = FC.IdsMode(unit, auraType)
    if mode == "always" then return nil, mode end
    if mode == "never" then return (unit == "pet") and "pet" or "own", mode end
    return (auraType == "HARMFUL") and "assistable" or "unassistable", mode
end

--- The `surface` ("categories", "overrides" or "situations") line for container `cfg`, or nil where
--- spell ids always apply.
local function viewNote(surface, cfg)
    local which = viewWhich(cfg)
    return which and VIEW_NOTES[surface][which] or nil
end

-- T-2 (batch 7, readability): "These are the lists on General -> Spell Categories..."
-- claims the grid holds EDITABLE lists. True wherever the grid carries a `spells`-kind row or the
-- `weaponEnchants` row, both of which own a list on General -> Spell Categories — which since issue
-- #11 is BOTH aura types' grids, not the buff one alone (`Cat.HARMFUL` carries `hardCC`, `ccRoot`
-- and `ccSnare`, and settings/GeneralSpells.lua offers every `spells`-kind row of either type). It stays
-- false for a grid whose only row is `uncategorized`, a Show/Hide flag over the catch-all rather
-- than a list of spells — which is what a debuff grid was until A1, and what either grid becomes if
-- its lists are ever taken away. So the line is printed only when the grid this container drew
-- actually carries a row whose list lives there — never removed, never reworded into something vague
-- enough to be true on both sides.
local function customGridHasEditableList(mine)
    for _, row in ipairs(mine) do
        local key = keyOfCategoryRow(row)
        local def = key and (Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key))
        if def and (def.kind == "spells" or def.kind == "enchant") then
            return true
        end
    end
    return false
end

--- A shallow copy of `row` with `skipRender` lifted, so the flow engine (which otherwise leaves
--- every `skipRender` row untouched, on the assumption that a grid or another bespoke drawer owns
--- it) draws it here instead. The SCHEMA row itself keeps `skipRender = true` — this copy is only
--- for this one render call, so `/am get|set|list`, Defaults and any future bespoke placement still
--- see the row as the host's to draw, not the flow engine's.
local function forRenderRows(row)
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    copy.skipRender = nil
    return copy
end

--- `rows` for DRAW, with a category the player made marked as theirs -- in the words the General ->
--- Spell Categories dropdown uses, read from there (`NS.GeneralSpells.MarkedName`) rather than
--- formatted again here, so the two surfaces cannot come to say it differently. `Cat.LabelOf` stays
--- the labeling rule underneath it.
---
--- A PER-RENDER COPY, the same idiom as `forRenderRows` above: the SCHEMA row keeps the bare name,
--- because that name is the row's identity in `/am list` and in the write log and is not a thing to
--- decorate. Only a user category is copied at all, so a build with none pays nothing.
local function markedRows(rows)
    local mark = NS.GeneralSpells and NS.GeneralSpells.MarkedName
    if not mark then return rows end
    local out = {}
    for i, row in ipairs(rows) do
        local key = keyOfCategoryRow(row)
        local def = key and (Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key))
        if def and Cat.IsUserCategory(def) then
            local copy = {}
            for k, v in pairs(row) do copy[k] = v end
            copy.label = mark(def)
            out[i] = copy
        else
            out[i] = row
        end
    end
    return out
end

--- The row at `path` among `rows`, or nil.
local function rowAt(rows, path)
    for _, row in ipairs(rows or {}) do
        if row.path == path then return row end
    end
    return nil
end

-- T-3 (batch 7): the spec's original instruction — move hidePermanentEnchants "beside 'Only these
-- categories'" — cannot be followed literally; that toggle is retired (see T-2/D8 above), there is
-- nothing left to sit beside. The owner's actual complaint was the row sitting alone in dead space
-- BELOW the grid (previously below the grid, the Uncategorized note AND that dead space). It stays a
-- typed row of its own for the same reason as before (a ChoiceGrid cell lights by comparing the
-- stored value against a column's "show"/"hide" string, which a bool can never match) and the grid
-- draws its rows atomically, so it still cannot be hosted INSIDE the grid next to the weaponEnchants
-- row it governs. What moves: it now draws immediately under the grid, ahead of UNCATEGORIZED_NOTE
-- (closing most of that dead space), behind a one-line tie naming the row it is a sub-option of —
-- "Weapon enchants" by name, since the grid's own row order (spells, weaponEnchants, uncategorized)
-- does not always put weaponEnchants directly above it.
local WEAPON_ENCHANT_TIE = L["A sub-option of the Weapon enchants row above:"]

--- Show all / Hide all (feedback #10): every category row of one grid, for the selected container, as
--- ONE bulk act (settings/Schema.lua's bracket): each row still goes through the write seam — its
--- validation, CONFIG_CHANGED and the in-place grid refresh — but the log is one `[Set] <act> <scope>:
--- N rows` line, and the writes' CONFIG_CHANGEDs coalesce into one apply pass.
local function setGrid(rows, state, gridKey)
    local _, id = NS.ActiveContainer()
    if not id then return end
    NS.Bulk.Run(state == "show" and "show all" or "hide all", ("%s categories of container %s"):format(gridKey, id), function()
        for _, row in ipairs(rows) do NS.SetByPath(row.path, state, id) end
    end)
end

--- The two buttons at the top of a grid's section, acting on exactly that grid's rows.
local function bulkButtons(ctx, rows, gridKey)
    H.InlineButtonPair(ctx,
        { text = L["Show all"], tooltip = L["Set every category in this section to Show, for this container."],
          onClick = function() setGrid(rows, "show", gridKey) end },
        { text = L["Hide all"], tooltip = L["Set every category in this section to Hide, for this container."],
          onClick = function() setGrid(rows, "hide", gridKey) end })
end

--- The Spell Categories grid (kind `custom`): heading, bulk buttons, the editable-list blurb, the
--- grid with its extra column, hidePermanentEnchants under it and the two gated notes.
local function renderCustomGrid(ctx, g, mine, cfg, auraType, hideRow)
    H.Section(ctx, g.heading)
    local note = viewNote("categories", cfg)
    if note then H.TextRow(ctx, note) end
    bulkButtons(ctx, mine, g.key)
    if customGridHasEditableList(mine) then
        H.TextRow(ctx, L["These are the lists on General -> Spell Categories, shared by every container."])
    end
    H.ChoiceGrid(ctx, { rows = markedRows(mine), columns = COLUMNS, labelHeader = L["Category"], extraColumn = CATEGORY_EXTRA })
    if hideRow then
        H.TextRow(ctx, WEAPON_ENCHANT_TIE)
        H.RenderRows(ctx, { forRenderRows(hideRow) }, nil, nil, { noHeadings = true })
    end
    if auraType == "HARMFUL" and customGridHasEditableList(mine) then
        H.TextRow(ctx, SPELL_LIST_DEBUFF_NOTE)
    end
    if FC.IdsMode(cfg and cfg.unit, auraType) == "always" then
        H.TextRow(ctx, UNCATEGORIZED_NOTE)
    end
end

--- Every other grid: heading, bulk buttons, then the grid. Its heading is drawn here rather than by
--- ChoiceGrid, so Show all / Hide all sit between the heading and the grid (feedback #10; Dispel
--- Types and Who Cast It too since B11-T10). N-5: only Blizzard Categories gets the extra column;
--- Dispel Types and Who Cast It pass no extraColumn at all, so they draw no 4th cell, blank or
--- otherwise (unlike passing CATEGORY_EXTRA and letting every cell() call answer nil), which keeps
--- their rows the width they always were.
local function renderPlainGrid(ctx, g, mine)
    H.Section(ctx, g.heading)
    bulkButtons(ctx, mine, g.key)
    H.ChoiceGrid(ctx, { rows = mine, columns = COLUMNS, labelHeader = L["Category"],
        extraColumn = g.key == "blizzard" and CATEGORY_EXTRA or nil })
end

--- Grid key -> its drawer; a key not listed draws as `renderPlainGrid`.
local GRID_RENDER = { custom = renderCustomGrid }

--- The Categories tab: a grid each (the priority blurb is the General tab's now, F-4). The Spell Categories grid (kind
--- `custom`) carries F-2's blurb, A3's `SPELL_LIST_DEBUFF_NOTE` and `UNCATEGORIZED_NOTE` — three
--- separate gates, deliberately, because the three sentences stopped being true together the moment
--- `Cat.HARMFUL` gained spell lists: the blurb asks whether this grid holds an editable list (T-2, now
--- true on both aura types), the debuff note asks whether it is a debuff grid holding
--- one, and UNCATEGORIZED_NOTE asks whether the engine is CERTAIN to honor spell ids for this
--- container's unit, which is the only place the rescue it describes can happen. It also carries
--- F-3's `See spells` link, and F-5's hidePermanentEnchants — a plain bool, not a Show/Hide choice —
--- drawn right under that grid (T-3), tied by name to the weaponEnchants row it governs since
--- ChoiceGrid draws its rows atomically and cannot host it inline.
local function renderCategories(ctx, cfg, rows)
    local hideRow = rowAt(rows, "container.filter.hidePermanentEnchants")
    local auraType = cfg and cfg.auraType or "HELPFUL"
    for _, g in ipairs(GRIDS) do
        local mine = {}
        for _, row in ipairs(rows or {}) do
            if row.grid == g.key then
                mine[#mine + 1] = row
            end
        end
        if mine[1] then
            (GRID_RENDER[g.key] or renderPlainGrid)(ctx, g, mine, cfg, auraType, hideRow)
        end
    end
end

-- ── Overrides: the whitelist and the blacklist ────────────────────────────────────────────────

local function sortedIds(set)
    local out = {}
    for id in pairs(set or {}) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

-- F-6/task B6: each Overrides entry's verdict note, drawn by the library under its name
-- (libs/LibKa0s/OptionsIdList.lua's `entry.note`). Built from FC.ExplainSpell, sparingly — a spell
-- that no category claims, or whose categories only confirm what this very list already decided,
-- gets none; the note fires only when a category genuinely disagrees, or the id sits on BOTH lists.
--
-- WORDING RULE: a note describes what the LISTS and the CATEGORIES decide. It never
-- claims what the aura will finally do, because `ExplainSpell` never reads `castBy`, `durationMode`
-- or `maxDuration` — the catch-all group this spell would fall into inherits those from the
-- container's base, so a duration cap or a cast-by restriction can still keep it off screen even
-- when the lists and categories alone would draw it. Say "the categories say Show" / "no category
-- hides it", never "it would show" / "it would be drawn". (Batch 7 retired the one exception
-- this used to carry — the "Only these categories" toggle's rank-5 case, whose definite wording came
-- from the toggle dropping the catch-all outright; the toggle is gone, and rank 5 can no longer be
-- "hidden" at all, so that branch is gone too.)

--- `cfg` with `id` cleared from BOTH override lists, so `ExplainSpell` can be asked what the
--- CATEGORIES alone would decide for it (rank 3/4/5), independent of whichever list holds the
--- entry we are drawing a note for. Shallow beyond `filter`, which is all `ExplainSpell` reads.
local function withoutOverrides(cfg, id)
    local filter = cfg.filter or {}
    local function without(list)
        local out = {}
        for k, v in pairs(list or {}) do out[k] = v end
        out[id] = nil
        return out
    end
    local copy = {}
    for k, v in pairs(cfg) do copy[k] = v end
    copy.filter = {}
    for k, v in pairs(filter) do copy.filter[k] = v end
    copy.filter.whitelist = without(filter.whitelist)
    copy.filter.blacklist = without(filter.blacklist)
    return copy
end

--- The labels of `list` (an `ExplainSpell` `categories` array, or a filtered copy of one), in
--- order, comma-joined — the note's "which categories" fragment. UNROUTED join: only enUS.lua ships
--- today, so a plain ", " between already-localized labels is not costing a translation anything yet
--- (there is not one). Accepted for now because every label in `list` already came through
--- `Cat.LabelOf` — routed when it is a shipped key, left alone when it is a player's own category
--- name — so the sentence a translation actually owns is still whole; if a second locale ships, this
--- separator is the thing to route (a locale-specific list join), not the labels themselves.
local function categoryLabelList(list)
    local names = {}
    for i, c in ipairs(list) do names[i] = c.label end
    return table.concat(names, ", ")
end

--- Only the Show categories among `list` — rank 3's positive claim. A blacklist note naming what the
--- blacklist overrides names these, not the Hide categories a Show already outranks.
local function showCategories(list)
    local out = {}
    for _, c in ipairs(list) do
        if c.state == "show" then
            out[#out + 1] = c
        end
    end
    return out
end

--- The verdict note for spell `id` on override list `key` ("whitelist" or "blacklist"), or nil.
local function overrideNote(cfg, id, ctx, key)
    local filter = cfg.filter or {}
    if key == "blacklist" then
        if (filter.whitelist or {})[id] == true then
            return L["Shown here anyway — it is also on the whitelist, which outranks the blacklist."]
        end
        -- Fire on the counterfactual's VERDICT ("shown"), the mirror of the whitelist branch below —
        -- not on rank 3 alone (rank 3 alone would miss rank 5, where an uncategorized
        -- blacklisted id would be drawn by the ordinary catch-all if the entry were removed; that is
        -- as real a mismatch as a category disagreeing, and the player was not told either way).
        local cat = FC.ExplainSpell(withoutOverrides(cfg, id), id, ctx)
        if cat.verdict ~= "shown" then
            return nil
        end
        if cat.rank == 5 then
            return L["Hidden here by the blacklist; no category here hides it."]
        end
        return L["Hidden here by the blacklist, overriding %s (set to Show)."]:format(
            categoryLabelList(showCategories(cat.categories)))
    end
    if (filter.blacklist or {})[id] == true then
        return L["Also on the blacklist, but the whitelist outranks it — still shown here."]
    end
    -- Fire on the counterfactual's VERDICT ("hidden"), not on rank 4 alone: `uncategorized = "hide"`
    -- (rank 4, on buffs) hides an unlisted id exactly as rank 4 does, and this is the one case most
    -- worth a note — without the whitelist this id would vanish from the container entirely, not
    -- merely lose a category fight. Rank 5 can never be "hidden" (the "Only these
    -- categories" toggle that once made it so is retired — see the WORDING RULE comment above), so
    -- there is no rank-5 branch here any more; every reachable "hidden" verdict now names a category.
    local cat = FC.ExplainSpell(withoutOverrides(cfg, id), id, ctx)
    if cat.verdict ~= "hidden" then
        return nil
    end
    return L["Shown here by the whitelist, overriding %s (set to Hide)."]:format(
        categoryLabelList(cat.categories))
end

--- One override list: its heading and blurb, then the library's ID list over `filter[key]`.
local function overrideList(ctx, cfg, key, heading, blurb)
    local path = "container.filter." .. key
    -- `fn(set)` changes a copy of the set, and the whole set goes back through the seam.
    local function edit(fn)
        local set = NS.Database.DeepCopy(cfg.filter[key] or {})
        fn(set)
        NS.SetByPath(path, set)
    end
    H.Section(ctx, heading)
    H.TextRow(ctx, blurb)
    H.IdList(ctx, {
        kind       = "spell",
        -- Every spell list in the addon draws its remove control the same way (B2).
        removeStyle = "icon",
        -- TWO TO A ROW, as the Spell Categories list draws (LibKa0s v1.47.0's `columns`,
        -- OptionsWidgets minor 24; fitted to the canvas since v1.50.0, minor 27).
        --
        -- THIS IS A CONSISTENCY CALL, NOT A SCROLL-LENGTH ONE, and it is worth saying which.
        -- An override list is per CONTAINER and a player writes a handful of ids into one, so
        -- unlike CC Loss of Control -- 60-odd ids, most of a screen before the next control -- these lists
        -- are short and two columns saves them little. What it saves is the reading: the same
        -- spell rows, with the same X and the same gray id, drawn one per line here and two per
        -- line on General reads as an omission on whichever page the player sees second. An odd
        -- count simply leaves the last row half full.
        --
        -- The truncation trade is the same one General takes and is documented there: above one
        -- column the name does not wrap, the client cuts the TAIL, and the gray `(id)` goes
        -- first. The entry's tooltip still carries the name. And the count is a MAXIMUM -- a
        -- canvas too narrow for two draws one, with nothing here needing to know its width.
        columns    = 2,
        label      = L["Add a spell"],
        tooltip    = NS.GeneralSpells.ID_TOOLTIP,
        strings    = NS.GeneralSpells.ID_STRINGS,
        candidates = NS.GeneralSpells.candidates,
        entries    = function()
            local fcCtx = FC.ProfileContext()
            local out = {}
            for i, id in ipairs(sortedIds(cfg.filter[key])) do
                -- TWO THINGS CAN NEED SAYING under one entry, and the more serious goes
                -- first. overrideNote explains what this override DOES against the categories;
                -- CA.Note says the entry can never match at all (issue #15), which makes the
                -- first note moot -- an id no aura carries has no verdict to explain. Joined
                -- rather than chosen between, so neither is silently dropped.
                --
                -- THEY GO IN THE "?" MARK, NOT IN A `note`, for the reason the Spell Categories
                -- list moved them there (LibKa0s v1.51.0; modules/CastAura.lua's CA.Help): a note
                -- is a full-width second line, so the library gives a noted entry a row of ITS
                -- OWN whatever the column count (`entryNoted`,
                -- libs/LibKa0s/OptionsIdList.lua:849-851) -- and this list asks for two
                -- columns, so every entry with a verdict punched a hole through the grid the
                -- `columns` note above bought. The mark costs a fixed 18px and leaves every row
                -- the same shape. The SENTENCES are unchanged: each was already a whole statement
                -- about the entry ("Hidden here by the blacklist, overriding ..."), which reads as
                -- a tooltip line exactly as it read as an inline one, and the entry's name is the
                -- tooltip's own title rather than something these sentences ever carried.
                --
                -- AND NO SEVERITY IS PASSED for the verdict line. Red is for an entry that can
                -- never match and yellow for the Spell Categories guardrail's "also in"; an
                -- override verdict is neither -- it is this list doing exactly its job -- so such
                -- a mark keeps the library's own gold. CA.Help still reddens the mark by itself
                -- when the never-matches line is one of the two.
                out[i] = { id = id, help = NS.CastAura.Help(id, overrideNote(cfg, id, fcCtx, key)) }
            end
            return out
        end,
        -- The same cast -> aura seam the Spell Categories tab takes (issue #15): an id the data
        -- resolves to an aura is stored as that aura and said so, anything else is stored as
        -- typed. Both add boxes have the same problem, so they take the same answer rather than
        -- each growing a copy of the reasoning.
        onAdd    = function(id)
            local stored, line = NS.CastAura.ForAdd(id)
            edit(function(set) set[stored] = true end)
            if line then NS.Print(line) end
        end,
        onRemove = function(id) edit(function(set) set[id] = nil end) end,
    })
end

local function renderOverrides(ctx, cfg)
    local note = viewNote("overrides", cfg)
    if note then H.TextRow(ctx, note) end
    overrideList(ctx, cfg, "whitelist", L["Whitelist"],
        L["These spells are shown whatever the categories say. Blizzard only honors this for buffs on units you can assist and debuffs on units you can't."])
    overrideList(ctx, cfg, "blacklist", L["Blacklist"],
        L["These spells are never shown in this container, unless the whitelist also names them — the whitelist wins."])
end

-- ── Situations: where spell lists don't apply, and the zones (S4) ────────────────────────────

-- Under the dropdowns: what "Every aura, once" still honors, and what it cannot (Blizzard drops the
-- spell ids there, so nothing built from them applies).
local SITUATIONS_HONOR = L["Every aura still honors Cast by, Duration, Max duration and the Blizzard, Dispel and Who Cast It rows you set to Hide; spell categories, Uncategorized and Overrides do not apply there."]
-- A player or pet buff container: FC.IdsMode "always", no every view, nothing to choose.
local SITUATIONS_ALWAYS = L["Spell lists always apply to your own and your pet's buffs."]
-- The EFFECTIVE mode, as the compiler reads it (FilterCompiler.lua's `timeless`): "Without a
-- duration" on a buff container. Timeless on debuffs compiles as any duration, so it says nothing.
-- The remainder's every view is NEVER there (SI-01) and the other groups keep their blizzard view in
-- the every view (SI-06), so both dropdown choices draw the same.
local SITUATIONS_TIMELESS = L["Every aura draws nothing extra here: 'Without a duration' is built from spell lists."]

--- The dropdowns `mode` (FC.IdsMode) calls for, from the tab's `rows`. A target or focus answers
--- both NPCs and players; the player's or the pet's debuffs only ever the players setting (spec S2),
--- drawn from a per-render copy under its own label so the schema row keeps its name.
local function situationDropdowns(rows, mode)
    local npcs = rowAt(rows, "container.filter.situations.npcs")
    local players = rowAt(rows, "container.filter.situations.players")
    if mode ~= "never" then return { npcs, players } end
    local copy = {}
    for k, v in pairs(players) do copy[k] = v end
    copy.label = L["Your own and your pet's debuffs"]
    copy.desc = L["Where Blizzard won't apply spell lists to your own or your pet's debuffs: every aura once, or only the Blizzard categories set to Show."]
    return { copy }
end

--- The six zone rows among `rows`, in C.ZONE_KEYS order.
local function zoneRows(rows)
    local out = {}
    for _, zone in ipairs(C.ZONE_KEYS) do
        out[#out + 1] = rowAt(rows, "container.filter.zones." .. zone)
    end
    return out
end

--- The Situations tab, last on the strip: Unit type and Reaction first (target and focus) or the
--- own-character note (the owner moved the section to the top, 2026-10-02), then the unit line, the
--- dropdowns and the two notes (or the always note alone), then the six zone checkboxes. Keyed by its
--- group, so `rows` is the group's, already filtered to the container's aura type.
local function renderSituations(ctx, cfg, rows)
    H.Section(ctx, L["Unit type"])
    if C.UNIT_FILTER_UNITS[cfg.unit] then
        H.RenderRows(ctx, { rowAt(rows, "container.filter.unitFilter.kind"),
            rowAt(rows, "container.filter.unitFilter.reaction") }, nil, nil, { noHeadings = true })
    else
        H.TextRow(ctx, L["Always your own character or pet."])
    end
    H.Section(ctx, L["Where spell lists don't apply"])
    local which, mode = viewWhich(cfg)
    if which then
        H.TextRow(ctx, VIEW_NOTES.situations[which])
        H.RenderRows(ctx, situationDropdowns(rows, mode), nil, nil, { noHeadings = true })
        H.TextRow(ctx, SITUATIONS_HONOR)
        if cfg.auraType == "HELPFUL" and cfg.filter and cfg.filter.durationMode == "timeless" then
            H.TextRow(ctx, SITUATIONS_TIMELESS)
        end
    else
        H.TextRow(ctx, SITUATIONS_ALWAYS)
    end
    H.Section(ctx, L["Show in"])
    H.RenderRows(ctx, zoneRows(rows), nil, nil, { noHeadings = true })
end

NS.RegisterContainerSection(PAGE, L["Filters"], {
    tooltip = L["Which auras this container shows, and in what order."],
    intro = function(ctx, cfg) H.RenderWarnings(ctx, cfg) end,
    pairWith = {
        ["container.filter.maxDuration"] = maxDurationPresets,
    },
    -- The priority block is drawn after the last General row, not above the first (see
    -- PRIORITY_RANKS).
    afterGroup = {
        [G_SHOW] = renderPriorityBlurb,
    },
    tabs = {
        -- Keyed by its group, so it takes the group's place and is handed the group's rows.
        { key = G_CATS, label = G_CATS, auraTypes = BUFFS_DEBUFFS, render = renderCategories },
        -- `before` the Sorting group: Overrides is the other half of the Categories decision, so it
        -- sits next to it, and Sorting — which orders whatever survived — follows (batch 8).
        { key = "overrides", label = L["Overrides"], auraTypes = BUFFS_DEBUFFS, before = G_SORT,
          render = renderOverrides },
        -- Keyed by its group, declared after Sorting's, and no `before`: the last tab (SI-05).
        { key = G_SIT, label = G_SIT, auraTypes = BUFFS_DEBUFFS, render = renderSituations },
    },
})
