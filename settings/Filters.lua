local _, NS = ...

-- settings/Filters.lua — what a container shows.
--
--     band          [Container ▾]
--     [ What to show ][ Categories ][ Sorting ][ Overrides ]
--     Categories    priority blurb (spec §6), then 'Only these categories'
--                   Blizzard Categories   Show · Hide · Category, a line each
--                   Spell Categories      (buffs)        the same grid, plus a `See spells` link
--                                                         and hidePermanentEnchants beneath it
--                   Dispel Types · Who Cast It  (debuffs)
--     Overrides     the same priority blurb, then:
--                   Whitelist  [Add a spell ____________][ Add ]  <icon> Name (id)  [Remove]
--                   Blacklist  the same
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
-- whose every category says Hide is removed by them. The priority blurb at the top of both the
-- Categories and Overrides tabs states the whole order, Overrides included. The rows stay in the
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

local G_SHOW, G_CATS, G_SORT = L["What to show"], L["Categories"], L["Sorting"]

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
    local dd = NS.AceGUI:Create("Dropdown")
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
-- both together.
local GRID_BY_KIND = { spells = "custom", token = "blizzard", flag = "blizzard", dispel = "dispel", enchant = "custom" }

local function gridOf(def)
    if def.field == "isFromPlayerOrPlayerPet" then return "who" end
    return GRID_BY_KIND[def.kind] or "blizzard"
end

-- F-7: the two-state tooltip. Show is a positive claim — it draws the aura even if another of the
-- aura's categories says Hide (spec §6 rank 3). Hide, on its own, only removes what nothing else
-- claims; the priority blurb above the grids spells out the full order. The old Default/Whitelist/
-- Blacklist wording this replaced is gone from here, locales/enUS.lua and the docs.
local STATE_DESC = L["Show: this category shows the aura, even if another of its categories says Hide. Hide: this category alone never shows it — a Show on another of its categories still can."]

local function categoryRows(auraType)
    local rows = {}
    for _, def in ipairs(Cat.For(auraType)) do
        local row = {
            path = "container.filter.categories." .. def.key, page = PAGE, group = G_CATS,
            grid = gridOf(def), skipRender = true, printLabel = true, auraTypes = { [auraType] = true },
            type = "string", values = STATES, label = L[def.label],
            desc = ("%s\n\n%s"):format(L[def.desc], STATE_DESC),
        }
        rows[#rows + 1] = row
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
        auraTypes = { HELPFUL = true, ENCHANT = true }, type = "bool", label = L["Hide enchants without a duration"],
        desc = L["Skip weapon enchants that never expire."],
    },
})

-- D8: "only these categories" drops the catch-all group (modules/FilterCompiler.lua, R-9), so a
-- container draws only the Overrides whitelist and whatever is set to Show. `skipRender`: B5's tab
-- draws it at the top, above the grids, rather than the flow engine's ordinary checkbox row.
NS.RegisterSchemaRows({
    {
        path = "container.filter.onlyShown", page = PAGE, group = G_CATS,
        skipRender = true, auraTypes = BUFFS_DEBUFFS, type = "bool",
        label = L["Only these categories"],
        desc = L["Draw only the Overrides whitelist and the categories set to Show; drop everything else, including auras in no category at all."],
    },
})

-- ── Sorting ───────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    {
        path = "container.filter.sortMethod", page = PAGE, group = G_SORT, auraTypes = BUFFS_DEBUFFS,
        type = "string", values = NS.Choices(C.SORT_METHODS, C.SORT_METHOD_LABELS), label = L["Sort by"],
        desc = L["The order auras are drawn in. 'Grouped' variants keep permanent auras together."],
    },
    {
        path = "container.filter.sortDirection", page = PAGE, group = G_SORT,
        type = "string", values = NS.Choices(C.SORT_DIRECTIONS, C.SORT_DIRECTION_LABELS), label = L["Direction"],
        desc = L["Reverse the order."],
    },
    {
        path = "container.filter.maxAuras", page = PAGE, group = G_SORT, auraTypes = BUFFS_DEBUFFS,
        type = "number", min = 0, max = 40, step = 1, label = L["Max auras per group (0 = no limit)"],
        desc = L["The cap applies to each engine group, not the whole container. With 'Only these categories' off and nothing on Categories Hidden, this container is one group, so the cap is the container's. Otherwise — something is Hidden, or 'Only these categories' is on — each category set to Show gets its own group, and the cap applies to EACH of those separately."],
    },
})

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

-- F-3: the Spell Categories grid's extra column — a link to that row's list on General → Spell
-- Categories, offered for a `spells`-kind row and the `enchant` row (weaponEnchants), because that
-- tab can draw both (NS.GeneralSpells.Select). `Cat.Find` rather than `Cat.IsSpellCategory`, which
-- only recognizes kind "spells" and would silently drop the enchant row's link. Every other kind
-- (token, flag, dispel) never reaches this grid (GRID_BY_KIND), so `def` is never one of them here,
-- but the guard stays honest about what earns the link rather than assuming the grid's shape.
local CUSTOM_EXTRA = {
    header = "",
    cell = function(row)
        local key = keyOfCategoryRow(row)
        local def = key and (Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key))
        if not (def and (def.kind == "spells" or def.kind == "enchant")) then return nil end
        return {
            text = L["See spells"],
            onClick = function()
                NS.GeneralSpells.Select(key)
                NS.OpenOptionsPage("general")
                H.SelectTab("general", L["Spell Categories"])
            end,
        }
    end,
}

-- F-4/spec §6: the five ranks, highest first, restated verbatim on both the Categories and the
-- Overrides tabs — two halves of one decision. Rank 1 is the whitelist, rank 2 the blacklist
-- (revised 2026-09-15: the whitelist now beats the blacklist, and rank 3's Show is a positive claim
-- that rescues an aura from a Hide elsewhere).
local PRIORITY_BLURB = L["Highest priority first: (1) on the Overrides whitelist — always shown. (2) on the Overrides blacklist — hidden, unless the whitelist already claimed it. (3) in at least one category set to Show — shown, even if another of its categories says Hide. (4) in categories that all say Hide — hidden. (5) in no category at all — shown; nothing removed it."]

-- R-10: while `onlyShown` is on, Hide no longer removes anything by itself — an aura is left out of
-- rank 5 (there is no catch-all while this is on) simply by belonging to no category set to Show.
-- The Hide column stays live and clickable regardless (it is still the only way to take a Show back
-- off a row that belongs to more than one category) — do NOT dim it.
local ONLY_SHOWN_NOTE = L["While this is on, Hide does not remove an aura by itself: an aura is shown only through the whitelist or a category set to Show, so here Hide means 'not shown' rather than 'removed'. It is still the only way to undo a Show on a row that belongs to more than one category."]

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

--- The row at `path` among `rows`, or nil.
local function rowAt(rows, path)
    for _, row in ipairs(rows or {}) do
        if row.path == path then return row end
    end
    return nil
end

--- The Categories tab: the priority blurb (F-4), `onlyShown` above the grids (R-8) with R-10's note
--- while it is on, then a grid each. The Spell Categories grid (kind `custom`) carries F-2's blurb
--- and F-3's `See spells` link, and F-5's hidePermanentEnchants — a plain bool, not a Show/Hide
--- choice; a ChoiceGrid cell lights by comparing the stored value against a column's string, which a
--- bool can never match — is drawn as an ordinary checkbox right under that grid, where the
--- weaponEnchants row it governs lives.
local function renderCategories(ctx, cfg, rows)
    H.TextRow(ctx, PRIORITY_BLURB)

    local onlyRow = rowAt(rows, "container.filter.onlyShown")
    if onlyRow then
        H.RenderRows(ctx, { forRenderRows(onlyRow) }, nil, nil, { noHeadings = true })
        if cfg and cfg.filter and cfg.filter.onlyShown then
            H.TextRow(ctx, ONLY_SHOWN_NOTE)
        end
    end

    local hideRow = rowAt(rows, "container.filter.hidePermanentEnchants")
    local hideDrawn = false
    for _, g in ipairs(GRIDS) do
        local mine = {}
        for _, row in ipairs(rows or {}) do
            if row.grid == g.key then
                mine[#mine + 1] = row
            end
        end
        if mine[1] then
            if g.key == "custom" then
                H.Section(ctx, g.heading)
                H.TextRow(ctx, L["These are the lists on General → Spell Categories, shared by every container."])
                H.ChoiceGrid(ctx, { rows = mine, columns = COLUMNS, labelHeader = L["Category"], extraColumn = CUSTOM_EXTRA })
                if hideRow then
                    H.RenderRows(ctx, { forRenderRows(hideRow) }, nil, nil, { noHeadings = true })
                    hideDrawn = true
                end
            else
                H.ChoiceGrid(ctx, { heading = g.heading, rows = mine, columns = COLUMNS, labelHeader = L["Category"] })
            end
        end
    end
    -- An ENCHANT container draws no Spell Categories grid at all (Cat.For("ENCHANT") is empty), so
    -- hidePermanentEnchants — offered for HELPFUL and ENCHANT alike — would otherwise never draw.
    if hideRow and not hideDrawn then
        H.RenderRows(ctx, { forRenderRows(hideRow) }, nil, nil, { noHeadings = true })
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
-- (libs/LibKa0s/OptionsWidgets.lua's `entry.note`). Built from FC.ExplainSpell, sparingly — a spell
-- that no category claims, or whose categories only confirm what this very list already decided,
-- gets none; the note fires only when a category genuinely disagrees, or the id sits on BOTH lists.
--
-- WORDING RULE (fix round 3): a note describes what the LISTS and the CATEGORIES decide. It never
-- claims what the aura will finally do, because `ExplainSpell` never reads `castBy`, `durationMode`
-- or `maxDuration` — the catch-all group this spell would fall into inherits those from the
-- container's base, so a duration cap or a cast-by restriction can still keep it off screen even
-- when the lists and categories alone would draw it. Say "the categories say Show" / "no category
-- hides it", never "it would show" / "it would be drawn" — the one exception is the `onlyShown`
-- rank-5 case below, which really can be definite, and says why right there.

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
--- (there is not one). Accepted for now because every label in `list` is itself routed through
--- NS.L, so the sentence a translation actually owns is still whole; if a second locale ships, this
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
        -- not on rank 3 alone (fix round 2: rank 3 missed rank 5 with `onlyShown` off, where an
        -- uncategorized blacklisted id would be drawn by the ordinary catch-all if the entry were
        -- removed; that is as real a mismatch as a category disagreeing, and the player was not told
        -- either way).
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
    -- Fire on the counterfactual's VERDICT ("hidden"), not on rank 4 alone: rank 5 hides too, under
    -- onlyShown (R-9's catch-all is gone), and that is the one case most worth a note — without the
    -- whitelist this id would vanish from the container entirely, not merely lose a category fight.
    local cat = FC.ExplainSpell(withoutOverrides(cfg, id), id, ctx)
    if cat.verdict ~= "hidden" then
        return nil
    end
    if cat.rank == 5 then
        -- The one wording allowed to stay definite (fix round 3): with `onlyShown` on and no
        -- category claiming the spell, NO group would carry it at all (R-9 drops the catch-all) — so
        -- unlike the other three, there is no downstream duration/castBy filter that could still
        -- keep it off screen. Nothing to falsify, so the stronger claim is honest.
        return L["Shown here by the whitelist; with 'Only these categories' on and nothing here set to Show, it would otherwise not be drawn at all."]
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
        label      = L["Add a spell"],
        tooltip    = NS.GeneralSpells.ID_TOOLTIP,
        strings    = NS.GeneralSpells.ID_STRINGS,
        candidates = NS.GeneralSpells.candidates,
        entries    = function()
            local fcCtx = FC.ProfileContext()
            local out = {}
            for i, id in ipairs(sortedIds(cfg.filter[key])) do
                out[i] = { id = id, note = overrideNote(cfg, id, fcCtx, key) }
            end
            return out
        end,
        onAdd    = function(id) edit(function(set) set[id] = true end) end,
        onRemove = function(id) edit(function(set) set[id] = nil end) end,
    })
end

local function renderOverrides(ctx, cfg)
    H.TextRow(ctx, PRIORITY_BLURB)
    overrideList(ctx, cfg, "whitelist", L["Whitelist"],
        L["These spells are shown whatever the categories say. Blizzard only honors this for buffs on friendly units and debuffs on hostile ones."])
    overrideList(ctx, cfg, "blacklist", L["Blacklist"],
        L["These spells are never shown in this container, unless the whitelist also names them — the whitelist wins."])
end

-- The Categories tab now carries hidePermanentEnchants (auraTypes HELPFUL + ENCHANT), so its own
-- auraTypes has to reach ENCHANT too — otherwise the schema loop still opens the tab (the row makes
-- the group non-empty) but this bespoke render never claims it, and it falls through to the flow
-- engine, which draws nothing for a `skipRender` row.
local CATS_TYPES = { HELPFUL = true, HARMFUL = true, ENCHANT = true }

NS.RegisterContainerPage(PAGE, L["Filters"], "AuraMasterFiltersPanel", {
    intro = function(ctx, cfg) H.RenderWarnings(ctx, cfg) end,
    pairWith = {
        ["container.filter.maxDuration"] = maxDurationPresets,
    },
    tabs = {
        -- Keyed by its group, so it takes the group's place and is handed the group's rows.
        { key = G_CATS, label = G_CATS, auraTypes = CATS_TYPES, render = renderCategories },
        { key = "overrides", label = L["Overrides"], auraTypes = BUFFS_DEBUFFS, render = renderOverrides },
    },
})
