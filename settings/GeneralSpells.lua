local _, NS = ...

-- settings/GeneralSpells.lua — General → Spell Categories and General → Dispel Colors: the two sets
-- every container shares (schema v2 made both the profile's).
--
--     [ Master controls ][ Display ][ Containers ][ Spell Categories ][ Dispel Colors ]
--     Spell Categories  [Category ▾]
--                       [Add a spell ____________________________][ Add ]
--                       <icon> Ironbark (102342)                   [x]       <- a starter: ticked unless removed
--                       <icon> A spell you added (424242)          [Remove]
--                       [Restore this category's starter list]
--     Dispel Colors     one swatch per dispel type, Magic … None
--
-- SPELL CATEGORIES is bespoke: the category dropdown, then the library's IdList over that category's
-- edits, then the restore. The edits live at the ABSOLUTE path `categorySpells`
-- ({ [categoryKey] = { [spellId] = true | false } }), a carve-out written whole through the seam
-- (settings/Schema.lua), so an edit here re-applies every container. A starter the player unticks is
-- stored `false` (nil would let the shipped list bring it back), a spell the player adds `true`, and
-- the carve-out's normalizer stores no category left with no edits. The lists are not schema rows, so
-- the page's Defaults leaves them alone, as the Filters page's leaves its Always / never lists; each
-- category has its own restore.
--
-- DISPEL COLORS are six plain color rows at `dispelColors.<type>`: absolute, so profile-wide, and with
-- no `effect`, so a write re-applies every container. Both styles read them — a bar colored by dispel
-- type, and the tint on an icon's dispel border (modules/Style_Icons.lua). They are palette
-- definitions, one color per dispel type, and carry no class-color companion: the one exemption
-- options-ui-§17 makes.
--
-- This file registers nothing. settings/General.lua registers DISPEL_ROWS after the Containers rows,
-- so the Dispel Colors tab follows Containers, and draws both tabs through TABS. It loads before
-- General.lua for that reason.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local Cat = NS.Categories

local PAGE = "general"
local SPELLS = L["Spell Categories"]
local DISPEL = L["Dispel Colors"]

-- ---------------------------------------------------------------------------
-- Spell Categories
-- ---------------------------------------------------------------------------

local spellCategory   -- session: which category the tab edits (the first when unset)

--- Re-render on the next frame: the dropdown or button whose callback asked is still on the stack.
local function rerender()
    if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end
end

--- The spell categories, in defaults/Categories.lua's order. Every one is a buff category: the
--- engine honors spell lists for buffs only.
local function spellCategories()
    local out = {}
    for _, def in ipairs(Cat.For("HELPFUL")) do
        if def.kind == "spells" then
            out[#out + 1] = def
        end
    end
    return out
end

--- The category this render edits: the session's choice while it is still a spell category, else
--- the first.
local function currentCategory(defs)
    local def = Cat.Find("HELPFUL", spellCategory)
    if not (def and def.kind == "spells") then def = defs[1] end
    spellCategory = def.key
    return def
end

local function sortedIds(set)
    local out = {}
    for id in pairs(set or {}) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

--- Category `key`'s stored edits, never nil.
local function editsOf(key)
    local all = NS.db.profile.categorySpells
    return all and all[key] or {}
end

--- Rewrite category `key`'s edits: `fn(mine)` changes a copy of them, and the whole profile set goes
--- back through the seam's carve-out. Every other category's edits ride along unchanged.
local function editCategory(key, fn)
    local all = NS.Database.DeepCopy(NS.db.profile.categorySpells or {})
    local mine = all[key] or {}
    fn(mine)
    all[key] = mine
    NS.SetByPath("categorySpells", all)
end

--- The list's entries: the starters in id order, each a toggle ticked unless removed, then the
--- spells the player added, each removable.
local function entriesFor(def)
    local mine, starters, out = editsOf(def.key), def.spells or {}, {}
    for _, id in ipairs(sortedIds(starters)) do
        out[#out + 1] = { id = id, toggle = true, on = mine[id] ~= false }
    end
    for _, id in ipairs(sortedIds(mine)) do
        if mine[id] == true and not starters[id] then
            out[#out + 1] = { id = id }
        end
    end
    return out
end

--- What a typed name is matched against when the client cannot look it up (it finds only spells the
--- character knows): every starter of every spell category, and every timed buff Aura Master has
--- learned (modules/TimedSpells.lua).
local function candidates()
    local seen, out = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    for _, def in ipairs(spellCategories()) do
        for id in pairs(def.spells or {}) do add(id) end
    end
    local g = NS.db and NS.db.global
    for id in pairs(g and g.timedSpells or {}) do add(id) end
    table.sort(out)
    return out
end

-- The IdList's words, through the locale (the library's own are English literals). Kind-specific
-- rather than the library's `{noun}` forms, so a translation never has to agree with an English noun.
local ID_STRINGS = {
    add       = L["Add"],
    remove    = L["Remove"],
    empty     = L["Type a spell id, a spell link or a spell name."],
    notFound  = L["No spell named '{text}'."],
    ambiguous = L["Several spells are named '{text}'. Use the id."],
    unknown   = L["Unknown spell {id}"],
}

local function categoryCell(defs, def)
    return { make = function(_, parent, rel)
        local list, order = {}, {}
        for i, d in ipairs(defs) do
            list[d.key] = L[d.label]
            order[i] = d.key
        end
        local dd = NS.AceGUI:Create("Dropdown")
        dd:SetLabel(L["Category"])
        dd:SetList(list, order)
        dd:SetValue(def.key)
        dd:SetRelativeWidth(rel or 0.5)
        dd:SetCallback("OnValueChanged", function(_, _, v) spellCategory = v; rerender() end)
        H.AttachTooltip(dd, L["Category"], L["Which spell category's list to edit."])
        parent:AddChild(dd)
        return dd
    end }
end

--- The Spell Categories tab: the category dropdown, its ID list, and its restore.
local function renderSpells(ctx)
    local defs = spellCategories()
    local def = currentCategory(defs)
    local key = def.key
    H.TextRow(ctx, L["The spells each category matches, shared by every container. Untick one to leave it out, or add your own. Blizzard only honors spell lists for buffs on friendly units."])
    H.RenderGrid(ctx, { categoryCell(defs, def) })
    H.IdList(ctx, {
        kind       = "spell",
        label      = L["Add a spell"],
        tooltip    = L["Type a spell id or name, or shift-click a spell link into the box, then press Enter or Add. A name the game cannot find is matched against every category's starter spells and the timed buffs Aura Master has learned."],
        strings    = ID_STRINGS,
        candidates = candidates,
        entries    = function() return entriesFor(def) end,
        -- Adding a starter back includes it again (drops its `false`); anything else is an addition.
        onAdd = function(id)
            editCategory(key, function(mine)
                if def.spells and def.spells[id] then mine[id] = nil else mine[id] = true end
            end)
        end,
        onRemove = function(id)
            editCategory(key, function(mine) mine[id] = nil end)
        end,
        onToggle = function(id, on)
            editCategory(key, function(mine)
                if on then mine[id] = nil else mine[id] = false end
            end)
        end,
    })
    H.InlineButtonPair(ctx, {
        text    = L["Restore this category's starter list"],
        tooltip = L["Forget every edit to this category: its starter spells are ticked again and the spells you added are removed. Other categories keep theirs."],
        onClick = function()
            editCategory(key, function(mine)
                for id in pairs(mine) do mine[id] = nil end
            end)
            rerender()
        end,
    }, nil)
end

-- ---------------------------------------------------------------------------
-- Dispel Colors
-- ---------------------------------------------------------------------------

local DISPEL_ROWS = {}
for _, name in ipairs(C.DISPEL_TYPES) do
    local row = {
        path = "dispelColors." .. name, page = PAGE, group = DISPEL, type = "color", label = L[name],
        desc = L["This dispel type's color: a bar's fill when Color by is set to dispel type, and the tint on an icon's dispel border."],
    }
    DISPEL_ROWS[#DISPEL_ROWS + 1] = row
end

--- The Dispel Colors tab: one line saying who reads the colors, then the group's six rows.
local function renderDispel(ctx, _, rows)
    H.TextRow(ctx, L["One color per dispel type, shared by every container: the fill of a bar colored by dispel type, and the tint on an icon's dispel border."])
    H.RenderRows(ctx, rows or {}, nil, nil, { noHeadings = true })
end

local TABS = {
    -- Ahead of Dispel Colors: every schema group's tab is collected before any bespoke one.
    { key = SPELLS, label = SPELLS, render = renderSpells, before = DISPEL },
    -- Keyed by its group, so it takes the group's place and is handed the group's rows.
    { key = DISPEL, label = DISPEL, render = renderDispel },
}

NS.GeneralSpells = { DISPEL_ROWS = DISPEL_ROWS, TABS = TABS }
