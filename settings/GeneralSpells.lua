local _, NS = ...

-- settings/GeneralSpells.lua — General → Spell Categories and General → Dispel Colors: the two sets
-- every container shares (schema v2 made both the profile's).
--
--     [ Master controls ][ Display ][ Containers ][ Spell Categories ][ Dispel Colors ]
--     Spell Categories  [Category ▾]  [Restore this category's starter list]
--                       -- one of the nine spell-list categories, or Weapon enchants
--                       [Add a spell ____________________________][ Add ]
--                       (X) <icon> Ironbark (102342)             <- a starter, until its X hides it
--                       (X) <icon> A spell you added (424242)
--                    -- OR, when the category is Weapon enchants --
--                       [x] Main hand   [x] Off hand   [x] Ranged
--     Dispel Colors     one swatch per dispel type, Magic … Bleed
--
-- SPELL CATEGORIES is bespoke: the category dropdown, the restore, then the library's IdList over that
-- category's edits, drawn with an X at the left of every entry (`removeStyle = "icon"`, LibKa0s
-- v1.44.0; B2, 2026-09-19). The edits live at the ABSOLUTE path `categorySpells`
-- ({ [categoryKey] = { [spellId] = true | false } }), a carve-out written whole through the seam
-- (settings/Schema.lua), so an edit here re-applies every container. A starter the player removes is
-- stored `false` (nil would let the shipped list bring it back) and drops out of the list until
-- Restore (or typing it back in) returns it; a spell the player adds is stored `true`, and
-- the carve-out's normalizer stores no category left with no edits. The lists are not schema rows, so
-- the page's Defaults leaves them alone, as the Filters page's leaves its Overrides lists; each
-- category has its own restore.
--
-- The dropdown also offers Weapon enchants (kind "enchant"): the odd category with no spell list at
-- all. Choosing it draws ENCHANT_ROWS instead — three real schema rows at `enchantSlots.<slot>`
-- (schema v3, B3), so `/am get|set|list`, Defaults and the resets all see them — plus a line saying
-- the per-container on/off switch lives on Filters → Categories (settings/Filters.lua, B5). The rows
-- carry `skipRender = true`, exactly like the Filters page's category rows: this tab draws them
-- itself rather than the flow engine drawing them a second time.
--
-- NS.GeneralSpells.Select(key) is the seam a per-row link on another page (Filters → Categories, B5)
-- uses to land here on a specific category: it moves this tab's own selection AND the General page's
-- active tab. A key this tab cannot draw (a token or flag category, say) is ignored, so a stale link
-- can never leave the tab showing an empty list.
--
-- DISPEL COLORS are five plain color rows at `dispelColors.<type>`: absolute, so profile-wide, and with
-- no `effect`, so a write re-applies every container. Bars and text read them: a bar's fill or
-- background colored by dispel type, and a text line's dispel type word, backdrop and edge (feedback
-- #7, modules/Style_Text.lua); an icon's dispel border keeps Blizzard's own colored art (modules/Style_Icons.lua,
-- owner 2026-09-13). There is no None swatch (feedback #7): an aura with no dispel type keeps the
-- surface's own color, so a None color would be read by nothing; schema v5 clears the stored leaf.
-- They are palette definitions, one color per dispel type, and carry no class-color companion: the
-- one exemption options-ui-§17 makes.
--
-- This file registers nothing. settings/General.lua registers ENCHANT_ROWS then DISPEL_ROWS after
-- the Containers rows, so Spell Categories takes the fourth strip position and Dispel Colors the
-- fifth, and draws both tabs through TABS. It loads before General.lua for that reason, and before
-- settings/Filters.lua, whose Overrides lists read `candidates`, `ID_STRINGS` and `ID_TOOLTIP` from
-- here.

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

--- The categories this tab can edit: every spell list, plus the weapon-enchant row, whose entry
--- shows its slots rather than a list. Both are buff categories — the engine honors spell lists for
--- buffs only, and enchants are the player's own.
local function spellCategories()
    local out = {}
    for _, def in ipairs(Cat.For("HELPFUL")) do
        if def.kind == "spells" or def.kind == "enchant" then
            out[#out + 1] = def
        end
    end
    return out
end

--- The category this render edits: the session's choice while it is still one this tab can draw
--- (a spell list or the enchant row), else the first.
local function currentCategory(defs)
    local def = Cat.Find("HELPFUL", spellCategory)
    if not (def and (def.kind == "spells" or def.kind == "enchant")) then def = defs[1] end
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

--- The list's entries: the starters the player has not removed, in id order, then the spells the
--- player added. Every one carries the X (removeStyle = "icon"); none is a toggle.
local function entriesFor(def)
    local mine, starters, out = editsOf(def.key), def.spells or {}, {}
    for _, id in ipairs(sortedIds(starters)) do
        if mine[id] ~= false then
            local n = #out
            out[n + 1] = { id = id }
        end
    end
    for _, id in ipairs(sortedIds(mine)) do
        if mine[id] == true and not starters[id] then
            out[#out + 1] = { id = id }
        end
    end
    return out
end

--- Every spell id Aura Master knows, for the ID lists to name: what a typed name is matched against
--- and what the suggestions list beside the spellbook. The client finds a spell by name only in the
--- character's own spellbook and cannot enumerate any other, so these are the only other names a
--- player can type. Every starter of every spell category, every spell the profile's categories edit
--- (added or unticked), every spell on any container's whitelist or blacklist, and every timed buff
--- Aura Master has learned (modules/TimedSpells.lua); each once, ascending. The library may call it
--- at every draw and every submit.
local function candidates()
    local seen, out = {}, {}
    local function addKeys(set)
        if type(set) ~= "table" then return end
        for id in pairs(set) do
            if type(id) == "number" and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    for _, def in ipairs(spellCategories()) do addKeys(def.spells) end
    local p = NS.db and NS.db.profile
    for _, edits in pairs(p and p.categorySpells or {}) do addKeys(edits) end
    for _, c in ipairs(NS.Database.GetContainers()) do
        local f = c.filter
        if f then
            addKeys(f.whitelist)
            addKeys(f.blacklist)
        end
    end
    local g = NS.db and NS.db.global
    addKeys(g and g.timedSpells)
    table.sort(out)
    return out
end

-- Where a typed name can come from, in the add line's tooltip and at the end of its refusal (the
-- library fills `{hint}` from `nameHint`): the spellbook, or the lists `candidates` reads. The enUS
-- copy is the library's own spell hint (O.ID_NAME_HINT.spell), localized here, so a translation
-- rewords the tooltip and the refusal together.
local NAME_HINT = L["Names work for spells in your spellbook and ones this list knows; otherwise use the id or shift-click a link."]

-- The IdList's words, through the locale (the library's own are English literals). Kind-specific
-- rather than the library's `{noun}` forms, so a translation never has to agree with an English noun.
-- A name several spells share is refused, never resolved to one of them: the suggestions list each
-- with its rank to pick from. `looking` is the item lookup's line, which a spell list never shows,
-- carried so no English literal can reach a localized build.
local ID_STRINGS = {
    add       = L["Add"],
    remove    = L["Remove"],
    empty     = L["Type a spell id, a spell link or a spell name."],
    notFound  = L["No spell named '{text}' in your spellbook. {hint}"],
    ambiguous = L["Several spells are named '{text}' — pick one from the list, or use the id."],
    unknown   = L["Unknown spell {id}"],
    looking   = L["Looking up spells..."],
    nameHint  = NAME_HINT,
    more      = L["+{count} more"],
}

-- Both widgets' tooltip on every spell ID list: how to add, then where a name can come from. One
-- routed sentence with a `{hint}` token (localization-§1), filled by a function so no `%` in a
-- translation is read as a pattern.
local ID_TOOLTIP = (L["Type a spell id or a name and pick from the list, or shift-click a spell link into the box, then press Enter or Add. {hint}"]
    :gsub("{hint}", function() return NAME_HINT end))

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

--- The Restore button, as the Category dropdown's right half (a RenderGrid cell, feedback #3): on
--- the same line, so the list's one reset sits beside the control that picks the list. A
--- cell-filling button, so it takes the library's inset width (options-ui-§6), never a flush half.
local function restoreCell(key)
    return { make = function(_, parent)
        local btn = NS.AceGUI:Create("Button")
        btn:SetText(L["Restore this category's starter list"])
        btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
        btn:SetCallback("OnClick", function()
            editCategory(key, function(mine)
                for id in pairs(mine) do mine[id] = nil end
            end)
            rerender()
        end)
        H.AttachTooltip(btn, L["Restore this category's starter list"],
            L["Forget every edit to this category: its removed starter spells come back and the spells you added are removed. Other categories keep theirs."])
        parent:AddChild(btn)
        return btn
    end }
end

-- ---------------------------------------------------------------------------
-- Weapon enchants (the Spell Categories tab's non-list entry)
-- ---------------------------------------------------------------------------

-- The slots, in the order a player reads them off their character. Profile-wide, like the spell
-- lists on this tab: one answer for every container that shows enchants.
local ENCHANT_SLOTS = {
    { key = "mainHand", label = "Main hand" },
    { key = "offHand",  label = "Off hand" },
    { key = "ranged",   label = "Ranged" },
}

-- Real schema rows (so /am get|set|list, Defaults and the resets see them), one per slot at
-- `enchantSlots.<slot>`. `skipRender = true`, exactly as the Filters page's category rows: this
-- tab's own renderEnchant draws them, not the flow engine.
local ENCHANT_ROWS = {}
for _, slot in ipairs(ENCHANT_SLOTS) do
    local row = {
        path = "enchantSlots." .. slot.key, page = PAGE, group = SPELLS, type = "bool",
        skipRender = true, label = L[slot.label],
        desc = L["Read temporary enchants from this weapon slot."],
    }
    ENCHANT_ROWS[#ENCHANT_ROWS + 1] = row
end

--- A shallow copy of `row` with `skipRender` lifted, so THIS render draws it (settings/Filters.lua's
--- forRenderRows is the same idiom): the schema row itself keeps `skipRender = true` for everyone
--- else — `/am get|set|list`, Defaults, the resets.
local function forRender(row)
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    copy.skipRender = nil
    return copy
end

--- The Weapon enchants entry: which slots count, where the per-container switch lives, and the
--- all-slots fallback (modules/FilterCompiler.lua's enchantBlock) so unticking every slot here does
--- not read as a broken control.
local function renderEnchant(ctx)
    H.TextRow(ctx, L["Which weapon slots your temporary enchants are read from, shared by every container. Whether a container shows them at all is that container's own Filters -> Categories row."])
    H.TextRow(ctx, L["Untick every slot here and all three are read anyway — to show no enchants at all, set Weapon enchants to Hide on that container's Filters -> Categories tab instead."])
    local rows = {}
    for i, row in ipairs(ENCHANT_ROWS) do rows[i] = forRender(row) end
    H.RenderRows(ctx, rows, nil, nil, { noHeadings = true })
end

--- The Spell Categories tab: the category dropdown, then either the ID list over the chosen
--- category's spells, or (Weapon enchants) the slot toggles.
local function renderSpells(ctx)
    local defs = spellCategories()
    local def = currentCategory(defs)
    local key = def.key
    if def.kind == "enchant" then
        H.RenderGrid(ctx, { categoryCell(defs, def) })
        return renderEnchant(ctx)
    end
    H.TextRow(ctx, L["The spells each category matches, shared by every container. Click X to leave one out, or add your own; Restore brings the starter list back. Blizzard only honors spell lists for buffs on friendly units."])
    -- Restore on the dropdown's line (feedback #3): with the checkboxes gone (B2) a removed starter is
    -- off the list, and this is how it comes back.
    H.RenderGrid(ctx, { categoryCell(defs, def), restoreCell(key) })
    H.IdList(ctx, {
        kind       = "spell",
        removeStyle = "icon",
        label      = L["Add a spell"],
        tooltip    = ID_TOOLTIP,
        strings    = ID_STRINGS,
        candidates = candidates,
        entries    = function() return entriesFor(def) end,
        -- Adding a starter back includes it again (drops its `false`); anything else is an addition.
        onAdd = function(id)
            editCategory(key, function(mine)
                if def.spells and def.spells[id] then mine[id] = nil else mine[id] = true end
            end)
        end,
        -- A starter is hidden (`false`, so the shipped list does not bring it back); an added spell
        -- is forgotten.
        onRemove = function(id)
            editCategory(key, function(mine)
                if def.spells and def.spells[id] then mine[id] = false else mine[id] = nil end
            end)
        end,
    })
end

-- ---------------------------------------------------------------------------
-- Dispel Colors
-- ---------------------------------------------------------------------------

local DISPEL_ROWS = {}
for _, name in ipairs(C.DISPEL_TYPES) do
    local row = {
        path = "dispelColors." .. name, page = PAGE, group = DISPEL, type = "color", label = L[name],
        desc = L["This dispel type's color for a bar's fill or background, and for a text line's dispel type word, backdrop or edge when those are on. An icon's dispel border keeps Blizzard's own colors."],
    }
    DISPEL_ROWS[#DISPEL_ROWS + 1] = row
end

--- The Dispel Colors tab: one line saying who reads the colors, then the group's five rows.
local function renderDispel(ctx, _, rows)
    H.TextRow(ctx, L["One color per dispel type, shared by every container, for bars colored by dispel type and for a text line's dispel type word, backdrop or edge (Text -> Font). Buffs and many debuffs have no dispel type, class debuffs such as Judgment or Consecration included: those keep a bar's own color and show no type word, backdrop or edge. An icon's dispel border keeps Blizzard's own colors."])
    H.RenderRows(ctx, rows or {}, nil, nil, { noHeadings = true })
end

local TABS = {
    -- Ahead of Dispel Colors: every schema group's tab is collected before any bespoke one.
    { key = SPELLS, label = SPELLS, render = renderSpells, before = DISPEL },
    -- Keyed by its group, so it takes the group's place and is handed the group's rows.
    { key = DISPEL, label = DISPEL, render = renderDispel },
}

-- `candidates`, `ID_STRINGS` and `ID_TOOLTIP` are shared with the Filters page's Overrides lists,
-- which suggest and resolve a typed name the same way.
NS.GeneralSpells = {
    DISPEL_ROWS = DISPEL_ROWS, ENCHANT_ROWS = ENCHANT_ROWS, TABS = TABS,
    candidates = candidates, ID_STRINGS = ID_STRINGS, ID_TOOLTIP = ID_TOOLTIP,
}

--- Point this tab at one category. For the Filters page's per-row link (settings/Filters.lua, B5).
--- A key this tab cannot draw is ignored rather than stored: a stale link must never leave the tab
--- on a category with no editor. Moves the General page's active tab to Spell Categories too, so the
--- link actually lands the player where the category is shown.
function NS.GeneralSpells.Select(key)
    local def = Cat.Find("HELPFUL", key)
    if not (def and (def.kind == "spells" or def.kind == "enchant")) then return end
    spellCategory = key
    local ctx = H.__pageCtx and H.__pageCtx.general
    if ctx then ctx.activeTab = SPELLS end
    rerender()
end
