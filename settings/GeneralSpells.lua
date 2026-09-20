local _, NS = ...

-- settings/GeneralSpells.lua — General → Spell Categories and General → Dispel Colors: the two sets
-- every container shares (schema v2 made both the profile's).
--
--     [ Master controls ][ Display ][ Containers ][ Spell Categories ][ Dispel Colors ]
--     Spell Categories  [Category ▾]  [Restore this category's starter list]
--                       -- one of the eleven spell-list categories, or Weapon enchants
--                       ---- Spells in this category ----------------------------------------
--                       [Add a spell ____________________________][ Add ]
--                       (X) <icon> Ironbark (102342)             <- a starter, until its X hides it
--                       (X) <icon> A spell you added (424242)
--                    -- OR, when the category is Weapon enchants --
--                       [x] Main hand   [x] Off hand   [x] Ranged
--     Dispel Colors     the lead-in and its four bullets, then one swatch per dispel type,
--                       Magic … Bleed
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

-- One bullet's marker, prefixed at draw so the locale keys stay plain prose (settings/Text.lua's
-- cheat sheet does the same).
local BULLET = "- "

-- A hairline between two bullets: enough that they are not read as one wrapped paragraph, small
-- enough that they still read as one block. settings/Filters.lua's PRIORITY_RANK_GAP, same reason.
local BULLET_GAP = 4

-- The gap a subsection heading gets above it. Mirrors the library's own SECTION_TOP_SPACER, which
-- `H.Section` emits only for a schema-driven page; this tab is drawn by hand, so it supplies its
-- own. See the note at the `H.Section` call in `renderSpells` for why the number is a literal.
local SECTION_GAP = 10

-- ---------------------------------------------------------------------------
-- Spell Categories
-- ---------------------------------------------------------------------------

local spellCategory   -- session: which category the tab edits (the first when unset)

--- Re-render on the next frame: the dropdown or button whose callback asked is still on the stack.
local function rerender()
    if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end
end

--- Whether `def` is a row this tab can draw: a spell list of either aura type, or the weapon-enchant
--- row, whose entry shows its slots rather than a list. Buffs are no longer the whole story — issue
--- #11 gave `Cat.HARMFUL` its first `spells`-kind categories (`hardCC`, `softCC`) and the engine
--- honors debuff spell ids on a hostile target or focus — so the test is the KIND, never the aura
--- type. Missing that is how a shipped list becomes uneditable: the Filters page's `See spells` link
--- offers itself for every `spells`-kind row it draws, including a debuff container's.
local function editableHere(def)
    return def ~= nil and (def.kind == "spells" or def.kind == "enchant")
end

--- The categories this tab can edit, buff lists first and in each aura type's own declaration order,
--- so the dropdown reads the way the Filters page's grids do.
local function spellCategories()
    local out = {}
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, def in ipairs(Cat.For(auraType)) do
            if editableHere(def) then
                local n = #out
                out[n + 1] = def
            end
        end
    end
    return out
end

--- The category this render edits: the session's choice while it is still one this tab can draw
--- (a spell list or the enchant row), else the first.
local function currentCategory(defs)
    local def = Cat.Find("HELPFUL", spellCategory) or Cat.Find("HARMFUL", spellCategory)
    if not editableHere(def) then def = defs[1] end
    spellCategory = def.key
    return def
end

--- The client's name for spell `id`, lowercased for sorting, or nil while it has none. The lookup is
--- `NS.Compat.GetSpellInfo`, deliberately the same C_Spell call the library's own entry label reads
--- (`libs/LibKa0s/OptionsWidgets.lua:397-405`), so a list can never sort on one name and draw
--- another.
local function sortName(id)
    local name = NS.Compat.GetSpellInfo(id)
    if type(name) ~= "string" or name == "" then return nil end
    return name:lower()
end

--- `set`'s ids in the order the list draws them: BY NAME, case-insensitively, exactly as every
--- container picker lists (core/Database.lua's GetContainersByName, B2-2). Owner, 2026-09-20: id
--- order put Frost Nova (122) above Entangling Roots (339) above Hamstring (1715), which is no
--- order at all to a reader.
---
--- AN ID THE CLIENT CANNOT NAME HAS NO NAME TO SORT ON, and the answer is chosen rather than
--- accidental: it sorts AFTER every named id, and ties there break on the id ascending. Two reasons.
--- The library draws such an entry as "Unknown spell 12345" (`OptionsWidgets.lua:2499-2506`), so it
--- carries no name for a reader to look for and belongs at the end rather than wedged between two
--- real names; and the id tiebreak makes the whole comparison a total order over the set, so the
--- sort is deterministic whatever order `pairs` hands the ids in. A nil name never reaches the
--- comparison — it is resolved once, up front, into `key`.
---
--- The list does NOT reorder itself a moment later. O.IdList's re-ask-and-redraw (five asks, 0.4 s
--- a window) is the ITEM path: `loadEntry` returns at once unless the kind declares `loads = true`,
--- which only "item" does (`OptionsWidgets.lua:741` and `:2543-2548`). A spell's name is client data
--- with no load step, so an id that is unnamed at this draw is an id the client does not know at
--- all, and it stays unnamed and last until a re-render — no visible settling, and nothing here to
--- mistake for a bug.
local function sortedByName(set)
    local out, key = {}, {}
    for id in pairs(set or {}) do
        out[#out + 1] = id
        key[id] = sortName(id)
    end
    table.sort(out, function(a, b)
        local ka, kb = key[a], key[b]
        if ka == kb then return a < b end       -- both unnamed, or the same name: id ascending
        if ka == nil then return false end      -- unnamed sorts after every named id
        if kb == nil then return true end
        return ka < kb
    end)
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

--- The list's entries: the starters the player has not removed and the spells the player added, as
--- ONE list ordered by name (`sortedByName`). Every one carries the X (removeStyle = "icon"); none
--- is a toggle.
---
--- One list, not starters-then-additions: the two are indistinguishable on screen — same icon, same
--- name, same X — so a spell of the player's own parked below the alphabet would read as a list that
--- is sorted right up to the point where it stops. The distinction that does survive is stored, not
--- drawn: Restore still tells them apart (editCategory), and an added spell is still forgotten by
--- its X while a removed starter is stored `false`.
local function entriesFor(def)
    local mine, starters, wanted = editsOf(def.key), def.spells or {}, {}
    for id in pairs(starters) do
        if mine[id] ~= false then wanted[id] = true end
    end
    for id, on in pairs(mine) do
        if on == true and not starters[id] then wanted[id] = true end
    end
    local out = {}
    for i, id in ipairs(sortedByName(wanted)) do out[i] = { id = id } end
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

-- ---------------------------------------------------------------------------
-- The Category dropdown's buff/debuff marker (owner, 2026-09-20; issue #10 checkpoint 1)
-- ---------------------------------------------------------------------------
--
-- Every entry in the Category dropdown says which aura type its category filters. Until issue #11
-- the list was buff-only and the question never arose; it now mixes `Cat.HELPFUL`'s nine spell
-- lists and Weapon enchants with `Cat.HARMFUL`'s `hardCC` and `softCC`, and nothing on the row said
-- so -- a player editing "Hard CC (loss of control)" had no way to tell from this tab that its ids
-- only ever bite on a hostile target or focus.
--
-- A PREFIX, NOT A SUFFIX, and the real labels decide it rather than taste: the two debuff rows
-- already end in parenthetical suffixes ("Hard CC (loss of control)", "Soft CC (roots & snares)"),
-- so a trailing marker would sit a second bracketed phrase behind the first and read as part of the
-- name. A prefix also puts every marker in the same column down the open list, which is what makes
-- it scannable rather than something to be read per row. And it survives the one thing this
-- dropdown cannot afford: it is narrow, and a pullout row's FontString is LEFT-justified and
-- anchored to both edges of its button (AceGUIWidget-DropDown-Items.lua:166-169, under libs/), so
-- an entry too long for the list loses its TAIL -- a leading marker is the half that cannot be cut
-- off, a trailing one is the first thing lost, exactly on the longest names. The CLOSED box is a
-- different FontString with a different default, and `sizeCategoryDropdown` below deals with it.
--
-- THE WORDS ARE NOT OURS TO CHOOSE. `C.AURA_TYPE_LABELS` is what the panel already calls these two
-- things everywhere a player meets them: the container's own Aura type dropdown
-- (settings/Containers.lua:79), the gray summary behind every container in the picker
-- (settings/OptionsSetup.lua:410) and the `/am list` line (settings/Slash.lua:177) -- those three
-- are its readers, and the Filters page is not among them; its category rows are labeled from the
-- category, not from the aura type. So the marker reads the table rather than defining a second
-- vocabulary here. Read, not copied: a translation that moves those two labels moves the markers
-- with them, and a future third aura type would be marked without touching this file.
--
-- WEAPON ENCHANTS IS MARKED LIKE EVERY OTHER ROW, as a buff. It is kind "enchant" and not a spell
-- list at all, but it is declared in `Cat.HELPFUL`, it is drawn in a BUFF container's Filters grid
-- and nowhere else, and the container Aura type row's own description already tells the player
-- "your temporary weapon enchants are a buff category there". An unmarked row in a marked list
-- would read as a bug or as a third, nameless kind of category; marking it buff-side agrees with
-- every other surface it appears on. This is why the marker keys off `Cat.AuraTypeOf` (the field
-- stamped in defaults/Categories.lua) and not off the KIND, which `editableHere` tests separately.
--
-- The CLOSED dropdown needs no separate TEXT: AceGUI's Dropdown draws the selected value by looking
-- its key up in the same `list` table (`SetValue` -> `self:SetText(self.list[value] or "")`,
-- libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown.lua:528-530), so marking the entries marks the
-- selection. A test below pins that, since it is a property of the widget and not of this file.
-- What it does need is `sizeCategoryDropdown`, further down: the box it is drawn in has its own
-- clipping behavior.
--
-- THE NAMES LINE UP AS FAR AS A PROPORTIONAL FONT ALLOWS, WHICH IS NOT PIXEL-EXACT, AND THAT IS
-- SAID PLAINLY RATHER THAN CLAIMED AWAY. "[Buffs] " and "[Debuffs] " are different widths, so a
-- bare prefix would start every name at a different x and cost the list the name column the marker
-- was meant to preserve. The type word is therefore padded out to the widest one in the locale, so
-- every name starts at the same CHARACTER offset -- the padding sits behind the "]" so the brackets
-- keep their own shape. In pixels it only closes most of the gap: the item font is proportional
-- (GameFontNormalSmall, FRIZQT__.TTF), a space glyph is not the width of the letters it stands in
-- for, and a FontString has no tab stops, so the two spaces standing in for "De" land short of it.
-- Pixel-exact would mean measuring the string at draw time or giving each row a second FontString,
-- and a twelve-row picker does not carry either. Character-exact is what the tests pin.
local CATEGORY_MARKER = L["[{type}] {name}"]

--- `s`'s length in CHARACTERS rather than bytes: UTF-8 continuation bytes are not counted, so an
--- aura-type word translated with an accent in it pads by what the player actually sees.
local function charCount(s)
    return select(2, tostring(s):gsub("[^\128-\191]", ""))
end

-- The widest aura-type word in this locale, in characters -- every marker is padded out to it.
-- Read out of `C.AURA_TYPE_LABELS` at load, so a third aura type, or a translation that makes
-- "Buffs" the longer word, changes the padding without an edit here.
local TYPE_WORD_CHARS = 0
for _, word in pairs(C.AURA_TYPE_LABELS) do
    TYPE_WORD_CHARS = math.max(TYPE_WORD_CHARS, charCount(L[word]))
end

--- `def`'s dropdown label: its name, prefixed with the aura type it filters and padded so the name
--- starts at the same character offset as every other row's.
--- Falls back to the bare name if the def carries no aura type, which no shipped or user category
--- ever should -- given a def, `Cat.AuraTypeOf` is total over real definitions -- so the fallback
--- is there to keep a malformed def out of the panel's way, not as a supported shape.
local function categoryLabel(def)
    local auraType = Cat.AuraTypeOf(def)
    local typeLabel = auraType and C.AURA_TYPE_LABELS[auraType]
    if not typeLabel then return Cat.LabelOf(def) end
    local word = L[typeLabel]
    local pad = (" "):rep(math.max(0, TYPE_WORD_CHARS - charCount(word)))
    return (CATEGORY_MARKER
        :gsub("{type}", function() return word end)
        :gsub("{name}", function() return pad .. Cat.LabelOf(def) end))
end

-- The open list and the closed box are two DIFFERENT FontStrings, and the marker is safe in
-- neither by default. Both are fixed from here rather than in `libs/`, which is a vendored payload.
--
-- THE OPEN LIST DOES NOT GROW TO FIT ITS ENTRIES. Opening sizes the pullout as
-- `self.pulloutWidth or self.frame:GetWidth()`
-- (libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown.lua:381) and nothing anywhere measures the items,
-- so with no `pulloutWidth` the open list is exactly as wide as this half-width control while its
-- longest entry, "[Debuffs] Hard CC (loss of control)", runs to 35 characters -- and a row that
-- does not fit loses its tail, which is the end of the category's name. `SetPulloutWidth`
-- (AceGUIWidget-DropDown.lua:639-641) is the widget's own answer, and a fixed width is the right
-- shape for it: the list is sized to its contents, not to whatever fraction of the panel the
-- control happens to occupy.
--
-- THE CLOSED BOX WOULD CLIP THE MARKER ITSELF. Its FontString is not one of AceGUI's: it is the
-- Blizzard UIDropDownMenuTemplate's own `$parentText`, adopted and re-anchored to both edges of the
-- control (AceGUIWidget-DropDown.lua:712-717) with its justification never set -- the single
-- `SetJustifyH` in that file is line 722, on the `label` caption above the box. The template is not
-- in this tree, so what it justifies to cannot be read here, and a RIGHT-justified FontString holds
-- an overlong string by its tail and pushes the HEAD out of the frame, which for a prefix marker is
-- precisely the half that must survive. So it is not inherited: justify LEFT explicitly, and the
-- closed box clips like the pullout rows do, tail first, marker last.
--
-- Both calls are capability-guarded (the same shape as modules/Style.lua:824): the headless widget
-- kit is a data recorder with neither method, and it is not ours to extend.
local CATEGORY_PULLOUT_WIDTH = 320

--- Size `dd`'s open list to its own entries and pin its closed box to LEFT justification.
local function sizeCategoryDropdown(dd)
    if dd.SetPulloutWidth then dd:SetPulloutWidth(CATEGORY_PULLOUT_WIDTH) end
    local fs = dd.text
    if type(fs) == "table" and fs.SetJustifyH then fs:SetJustifyH("LEFT") end
end

local function categoryCell(defs, def)
    return { make = function(_, parent, rel)
        local list, order = {}, {}
        for i, d in ipairs(defs) do
            list[d.key] = categoryLabel(d)
            order[i] = d.key
        end
        local dd = NS.AceGUI:Create("Dropdown")
        dd:SetLabel(L["Category"])
        dd:SetList(list, order)
        dd:SetValue(def.key)
        dd:SetRelativeWidth(rel or 0.5)
        sizeCategoryDropdown(dd)
        dd:SetCallback("OnValueChanged", function(_, _, v) spellCategory = v; rerender() end)
        H.AttachTooltip(dd, L["Category"],
            L["Which spell category's list to edit. Every entry is marked with the aura type it filters, because a category only ever shows on a container of that type."])
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
    H.TextRow(ctx, L["The spells each category matches, shared by every container. Click X to leave one out, or add your own; Restore brings the starter list back. Blizzard only honors spell lists for buffs on friendly units and debuffs on hostile ones."])
    -- Restore on the dropdown's line (feedback #3): with the checkboxes gone (B2) a removed starter is
    -- off the list, and this is how it comes back.
    H.RenderGrid(ctx, { categoryCell(defs, def), restoreCell(key) })
    -- Owner, 2026-09-20: the add box and the entries under it ran straight on from the dropdown and
    -- its Restore, so the tab read as one undivided column. The library's own heading rule closes
    -- the picker off and opens the list. The heading does NOT repeat the add row's own label ("Add
    -- a spell") -- the block below it is the whole list, of which adding is one control -- so it
    -- names what the block IS.
    --
    -- The spacer is ours because the library's own is out of reach here. `H.Section` emits its
    -- SECTION_TOP_SPACER only once `ctx.lastGroup` is set, and only the schema-driven row renderer
    -- sets it — this tab is drawn by hand through `H.RenderGrid`, which never does. Without this the
    -- heading sits tighter under the picker than every schema-driven heading on Bars or Text, which
    -- is the inconsistency the owner asked to close rather than a new one to open.
    --
    -- The 10 is a LITERAL on purpose: the library republishes `ROW_VSPACER` to hosts and deliberately
    -- keeps `SECTION_TOP_SPACER` internal (`libs/LibKa0s/Options.lua:45-83`, and the scalar list at
    -- `:594-598`), so `H.SECTION_TOP_SPACER` does not exist and reading it would silently be nil.
    -- Matching the number is the honest way to match the look; if the library ever republishes it,
    -- this is the line that takes it.
    local gridScroll = H.EnsureScroll(ctx)
    if gridScroll then H.AddSpacer(gridScroll, SECTION_GAP) end
    H.Section(ctx, L["Spells in this category"])
    H.IdList(ctx, {
        kind       = "spell",
        removeStyle = "icon",
        -- TWO COLUMNS, FILLED ROW-MAJOR (1 2 / 3 4). Owner, 2026-09-20: one entry per row ran very
        -- long for a 60-id category -- Hard CC alone is most of a screen of scrolling before the
        -- next control. `columns` is LibKa0s v1.47.0's O.IdList option (OptionsWidgets minor 24,
        -- `libs/LibKa0s/OptionsWidgets.lua:2843-2850`): the count is floored and clamped into
        -- 1..ID_COLUMNS_MAX, which the library pins at 2 (`:1902`), so two is the whole of what it
        -- offers rather than a taste. Each entry's relative width is divided by the count, so a
        -- pair still sums to the width one entry held alone. Row-major is the library's packing
        -- order, which is why the by-name sort above reads left-to-right then down, not down one
        -- column and back up the next.
        --
        -- THE TRADE WE TOOK. At more than one column the library turns word wrap OFF on an entry's
        -- label, because a name that wrapped to two lines would push the column beside it down and
        -- break the grid (`entryNoWrap`, `:2762-2770`). The client then truncates the TAIL, and the
        -- gray `(id)` sits at the tail -- so a long spell name in a narrow panel shows part of its
        -- name and no id. Hovering the row still names the spell. docs/settings-panel.md says this
        -- where it describes the Spell Categories tab.
        --
        -- Only the spell-category list asks for columns; the Filters page Overrides lists stay one
        -- per row.
        columns    = 2,
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

-- The three facts the tab has to state before the swatches mean anything: where the colors are
-- read, what has no dispel type at all and how that looks, and that an icon's dispel border is
-- Blizzard's art rather than one of these. They were one paragraph of five lines until the owner
-- asked for a list (2026-09-20, from the live panel) -- the same complaint, and the same answer,
-- as settings/Filters.lua's priority block: a lead-in, then one H.TextRow per fact with a hairline
-- between them, drawn from helpers that already exist. The WORDING is the paragraph's, split.
local DISPEL_LEAD = L["One color per dispel type, shared by every container:"]
local DISPEL_FACTS = {
    L["Read by bars colored by dispel type, and by a text line's dispel type word, backdrop or edge (Text -> Font)."],
    -- Split in two (the paragraph's one long sentence): at panel width a ~170-character bullet wraps,
    -- and its second line lands flush under the "- " with no hanging indent, so a three-bullet block
    -- reads as 1/2/1 lines and loses the shape the bullets were asked for. Two short facts instead.
    L["Buffs and many debuffs have no dispel type at all, class debuffs such as Judgment or Consecration included."],
    L["Those keep a bar's own color, and show no type word, backdrop or edge."],
    L["An icon's dispel border keeps Blizzard's own colors."],
}

--- The Dispel Colors tab: the lead-in and its four bullets, then the group's five rows.
local function renderDispel(ctx, _, rows)
    local scroll = H.EnsureScroll(ctx)
    H.TextRow(ctx, DISPEL_LEAD, { fontObject = "GameFontNormalSmall" })
    if scroll then H.AddSpacer(scroll, BULLET_GAP) end
    for _, fact in ipairs(DISPEL_FACTS) do
        H.TextRow(ctx, BULLET .. fact)
        if scroll then H.AddSpacer(scroll, BULLET_GAP) end
    end
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
    local def = Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key)
    if not editableHere(def) then return end
    spellCategory = key
    local ctx = H.__pageCtx and H.__pageCtx.general
    if ctx then ctx.activeTab = SPELLS end
    rerender()
end
