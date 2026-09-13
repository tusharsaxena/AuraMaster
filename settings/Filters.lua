local _, NS = ...

-- settings/Filters.lua — what a container shows.
--
--     band          [Container ▾]
--     [ What to show ][ Categories ][ Sorting ][ Overrides ]
--     Categories    Blizzard Categories   Default · Whitelist · Blacklist · Category, a line each
--                   Custom Categories     (buffs)        the same grid over the spell categories
--                   Dispel Types · Who Cast It  (debuffs)
--     Overrides     Whitelist  [Add a spell ____________][ Add ]  <icon> Name (id)  [Remove]
--                   Blacklist  the same
--
-- Every row here compiles, through modules/FilterCompiler.lua, into the aura groups Blizzard's aura
-- engine evaluates in its own code — we never read an aura while it is secret, so every filter is a
-- declaration made in advance. What the engine will silently not honor for this container (spell
-- ids on a debuff container on yourself, say) is printed in orange above every tab.
--
-- The category rows are generated from defaults/Categories.lua and offered only for the aura type
-- they belong to (`auraTypes`); a category is a three-state choice, stored as "" / "show" / "hide"
-- and labeled Default / Whitelist / Blacklist. The rows stay in the schema, so `/am get|set|list`,
-- Defaults and the resets see them, but carry `skipRender`: the Categories tab, bespoke and keyed by
-- the group's name, draws them as one ChoiceGrid per `grid`. Which spells a spell category matches
-- is the profile's, edited on General → Spell Categories (settings/GeneralSpells.lua).
--
-- The Overrides tab is bespoke: two ID lists over the container's whitelist and blacklist, each set
-- written WHOLE through the write seam (settings/Schema.lua's carve-outs). They are not schema rows,
-- so the page's Defaults leaves them alone.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local Cat = NS.Categories

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
        type = "number", min = 0, max = 3600, step = 5, label = L["Max duration (sec, 0 = no limit)"],
        desc = L["Hide auras whose full duration is longer than this — a 60 keeps short cooldowns and drops hour-long buffs. Permanent auras are hidden while a limit is set."],
    },
    {
        path = "container.filter.includeEnchants", page = PAGE, group = G_SHOW, subgroup = L["Weapon enchants"],
        auraTypes = { HELPFUL = true }, type = "bool", label = L["Also show weapon enchants"],
        desc = L["Add your temporary weapon enchants after the buffs. Only on a container showing your own buffs."],
    },
    {
        path = "container.filter.hidePermanentEnchants", page = PAGE, group = G_SHOW, subgroup = L["Weapon enchants"],
        auraTypes = { HELPFUL = true, ENCHANT = true }, type = "bool", label = L["Hide enchants without a duration"],
        desc = L["Skip weapon enchants that never expire."],
    },
})

-- ── Categories ────────────────────────────────────────────────────────────────────────────────

local STATES = NS.Choices(C.CATEGORY_STATES, C.CATEGORY_STATE_LABELS)

-- Which grid a category is drawn in, by its kind. Who cast it is a flag with a grid of its own.
local GRID_BY_KIND = { spells = "custom", token = "blizzard", flag = "blizzard", dispel = "dispel" }

local function gridOf(def)
    if def.field == "isFromPlayerOrPlayerPet" then return "who" end
    return GRID_BY_KIND[def.kind] or "blizzard"
end

local function categoryRows(auraType)
    local rows = {}
    for _, def in ipairs(Cat.For(auraType)) do
        local row = {
            path = "container.filter.categories." .. def.key, page = PAGE, group = G_CATS,
            grid = gridOf(def), skipRender = true, printLabel = true, auraTypes = { [auraType] = true },
            type = "string", values = STATES, label = L[def.label],
            desc = ("%s\n\n%s"):format(L[def.desc], L["Whitelist: this container shows only the categories set to Whitelist (and the spells on its Overrides whitelist). Blacklist: never shown here. Default: no effect."]),
        }
        rows[#rows + 1] = row
    end
    return rows
end

NS.RegisterSchemaRows(categoryRows("HELPFUL"))
NS.RegisterSchemaRows(categoryRows("HARMFUL"))

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
        type = "number", min = 0, max = 40, step = 1, label = L["Max auras (0 = no limit)"],
        desc = L["Draw at most this many auras for each shown category."],
    },
})

-- ---------------------------------------------------------------------------
-- The bespoke tabs
-- ---------------------------------------------------------------------------

-- ── Categories: one grid per kind ────────────────────────────────────────────────────────────

-- The grids in the order they are drawn; one with no row for this aura type is not drawn at all.
local GRIDS = {
    { key = "blizzard", heading = L["Blizzard Categories"] },
    { key = "custom",   heading = L["Custom Categories"] },
    { key = "dispel",   heading = L["Dispel Types"] },
    { key = "who",      heading = L["Who Cast It"] },
}

local COLUMNS = {}
for i, value in ipairs(C.CATEGORY_STATES) do
    COLUMNS[i] = { value = value, label = L[C.CATEGORY_STATE_LABELS[value]] }
end

--- The Categories tab: the group's rows (already the ones this aura type is offered), a grid each.
local function renderCategories(ctx, _, rows)
    for _, g in ipairs(GRIDS) do
        local mine = {}
        for _, row in ipairs(rows or {}) do
            if row.grid == g.key then
                mine[#mine + 1] = row
            end
        end
        if mine[1] then
            H.ChoiceGrid(ctx, { heading = g.heading, rows = mine, columns = COLUMNS, labelHeader = L["Category"] })
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
        tooltip    = L["Type a spell id or name, or shift-click a spell link into the box, then press Enter or Add. A name the game cannot find is matched against every category's starter spells and the timed buffs Aura Master has learned."],
        strings    = NS.GeneralSpells.ID_STRINGS,
        candidates = NS.GeneralSpells.candidates,
        entries    = function()
            local out = {}
            for i, id in ipairs(sortedIds(cfg.filter[key])) do out[i] = { id = id } end
            return out
        end,
        onAdd    = function(id) edit(function(set) set[id] = true end) end,
        onRemove = function(id) edit(function(set) set[id] = nil end) end,
    })
end

local function renderOverrides(ctx, cfg)
    overrideList(ctx, cfg, "whitelist", L["Whitelist"],
        L["These spells are shown whatever the categories say. Blizzard only honors this for buffs on friendly units and debuffs on hostile ones."])
    overrideList(ctx, cfg, "blacklist", L["Blacklist"],
        L["These spells are never shown in this container. A spell on both lists is hidden."])
end

NS.RegisterContainerPage(PAGE, L["Filters"], "AuraMasterFiltersPanel", {
    intro = function(ctx, cfg) H.RenderWarnings(ctx, cfg) end,
    tabs = {
        -- Keyed by its group, so it takes the group's place and is handed the group's rows.
        { key = G_CATS, label = G_CATS, auraTypes = BUFFS_DEBUFFS, render = renderCategories },
        { key = "overrides", label = L["Overrides"], auraTypes = BUFFS_DEBUFFS, render = renderOverrides },
    },
})
