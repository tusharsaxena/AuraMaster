local _, NS = ...

-- settings/Filters.lua — what a container shows.
--
--     band          [Container ▾]
--     [ What to show ][ Categories ][ Sorting ][ Spell lists ][ Always / never ]
--
-- Every row here compiles, through modules/FilterCompiler.lua, into the aura groups Blizzard's aura
-- engine evaluates in its own code — we never read an aura while it is secret, so every filter is a
-- declaration made in advance. What the engine will silently not honor for this container (spell
-- ids on a debuff container on yourself, say) is printed in orange above every tab.
--
-- The category rows are generated from defaults/Categories.lua and offered only for the aura type
-- they belong to (`auraTypes`); a category is a three-state choice, stored as "" / "show" / "hide".
-- The two spell-set tabs are bespoke: a set is written WHOLE through the write seam
-- (settings/Schema.lua's carve-outs).

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

local SUBGROUP_BY_KIND = {
    spells = "Spell lists", token = "Blizzard flags", flag = "Blizzard flags", dispel = "Dispel types",
}

local function categoryRows(auraType)
    local rows = {}
    for _, def in ipairs(Cat.For(auraType)) do
        local sub = SUBGROUP_BY_KIND[def.kind] or "Blizzard flags"
        if def.field == "isFromPlayerOrPlayerPet" then sub = "Who cast it" end
        local row = {
            path = "container.filter.categories." .. def.key, page = PAGE, group = G_CATS,
            subgroup = L[sub], auraTypes = { [auraType] = true },
            type = "string", values = STATES, label = L[def.label],
            desc = ("%s\n\n%s"):format(L[def.desc], L["Show: this container shows only the categories set to Show (and your Always list). Hide: never shown here. —: no effect."]),
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

--- A spell's display text: icon, name and id, or the bare id when the client does not know it.
local function spellText(id)
    local name, icon = NS.Compat.GetSpellInfo(id)
    if name then
        return ("|T%s:16:16:0:0|t %s |cff888888(%d)|r"):format(tostring(icon or 134400), name, id)
    end
    return ("|cff888888%s %d|r"):format(L["Unknown spell"], id)
end

--- Re-render this page on the next frame: a set just changed, and the widget whose callback asked
--- for it is still on the stack.
local function rerender()
    if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end
end

local function sortedIds(set)
    local out = {}
    for id in pairs(set or {}) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

--- An "Add spell ID" box. `onAdd(id)` receives a positive integer.
local function addBox(label, onAdd)
    return { make = function(_, parent, rel)
        local box = NS.AceGUI:Create("EditBox")
        box:SetLabel(label)
        box:SetRelativeWidth(rel or 0.5)
        box:SetCallback("OnEnterPressed", function(_, _, text)
            local id = tonumber((text or ""):match("%d+"))
            if id and id > 0 then onAdd(id) end
        end)
        H.AttachTooltip(box, label, L["Type a spell id and press Enter. Turn on tooltip spell ids in the game's options, or look the spell up on Wowhead."])
        parent:AddChild(box)
        return box
    end }
end

-- ── Spell lists: edit one category's spells ───────────────────────────────────────────────────

local spellCategory   -- session: which spell category the tab is editing

local function spellCategories()
    local out = {}
    for _, def in ipairs(Cat.For("HELPFUL")) do
        if def.kind == "spells" then
            out[#out + 1] = def
        end
    end
    return out
end

local function renderSpellLists(ctx, cfg)
    local AceGUI = NS.AceGUI
    local defs = spellCategories()
    local def = Cat.Find("HELPFUL", spellCategory) or defs[1]
    spellCategory = def.key

    local edits = NS.Database.DeepCopy(cfg.filter.categorySpells or {})
    local mine = edits[def.key] or {}
    local function commit()
        edits[def.key] = mine
        NS.SetByPath("container.filter.categorySpells", edits)
        rerender()
    end

    H.TextRow(ctx, L["The spells each category matches, for this container only. Untick one to leave it out, or add your own. Blizzard only honors spell lists for buffs on friendly units."])
    local items = {
        { make = function(_, parent, rel)
            local list, order = {}, {}
            for i, d in ipairs(defs) do list[d.key] = L[d.label]; order[i] = d.key end
            local dd = AceGUI:Create("Dropdown")
            dd:SetLabel(L["Category"])
            dd:SetList(list, order)
            dd:SetValue(def.key)
            dd:SetRelativeWidth(rel or 0.5)
            dd:SetCallback("OnValueChanged", function(_, _, v) spellCategory = v; rerender() end)
            parent:AddChild(dd)
            return dd
        end },
        addBox(L["Add spell ID"], function(id) mine[id] = true; commit() end),
    }

    -- Starter spells first (ticked unless removed), then the ones the player added.
    local rows = {}
    for id in pairs(def.spells or {}) do
        rows[#rows + 1] = { id = id, starter = true }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    for _, id in ipairs(sortedIds(mine)) do
        if mine[id] == true and not (def.spells and def.spells[id]) then
            rows[#rows + 1] = { id = id, starter = false }
        end
    end
    for _, r in ipairs(rows) do
        table.insert(items, { make = function(_, parent, rel)
            local cb = AceGUI:Create("CheckBox")
            cb:SetLabel(spellText(r.id))
            cb:SetRelativeWidth(rel or 0.5)
            cb:SetValue(mine[r.id] ~= false)
            cb:SetCallback("OnValueChanged", function(_, _, on)
                if r.starter then
                    mine[r.id] = (not on) and false or nil
                else
                    mine[r.id] = on and true or nil
                end
                commit()
            end)
            parent:AddChild(cb)
            return cb
        end })
    end
    H.RenderGrid(ctx, items)
    H.InlineButtonPair(ctx, {
        text = L["Restore this category's starter list"],
        onClick = function() mine = {}; commit() end,
    }, nil)
end

-- ── Always / never: the whitelist and the blacklist ───────────────────────────────────────────

local function renderIdSet(ctx, cfg, key, heading, blurb)
    local AceGUI = NS.AceGUI
    local set = NS.Database.DeepCopy(cfg.filter[key] or {})
    local path = "container.filter." .. key
    H.Section(ctx, heading)
    H.TextRow(ctx, blurb)
    local items = { addBox(L["Add spell ID"], function(id)
        set[id] = true
        NS.SetByPath(path, set)
        rerender()
    end), { make = function() return true end } }
    for _, id in ipairs(sortedIds(set)) do
        table.insert(items, { make = function(_, parent, rel)
            local lbl = AceGUI:Create("Label")
            lbl:SetText(spellText(id))
            lbl:SetRelativeWidth(rel or 0.5)
            parent:AddChild(lbl)
            return lbl
        end })
        table.insert(items, { make = function(_, parent, rel)
            local btn = AceGUI:Create("Button")
            btn:SetText(L["Remove"])
            btn:SetRelativeWidth((rel or 0.5) * 0.5)
            btn:SetCallback("OnClick", function()
                set[id] = nil
                NS.SetByPath(path, set)
                rerender()
            end)
            parent:AddChild(btn)
            return btn
        end })
    end
    H.RenderGrid(ctx, items)
end

local function renderAlwaysNever(ctx, cfg)
    renderIdSet(ctx, cfg, "whitelist", L["Always show"],
        L["These spells are shown whatever the categories say. Blizzard only honors this for buffs on friendly units and debuffs on hostile ones."])
    renderIdSet(ctx, cfg, "blacklist", L["Never show"],
        L["These spells are never shown in this container. A spell on both lists is hidden."])
end

NS.RegisterContainerPage(PAGE, L["Filters"], "AuraMasterFiltersPanel", {
    intro = function(ctx, cfg) H.RenderWarnings(ctx, cfg) end,
    tabs = {
        { key = "spellLists", label = L["Spell lists"], auraTypes = { HELPFUL = true }, render = renderSpellLists },
        { key = "alwaysNever", label = L["Always / never"], auraTypes = BUFFS_DEBUFFS, render = renderAlwaysNever },
    },
})
