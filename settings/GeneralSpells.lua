local _, NS = ...

-- settings/GeneralSpells.lua — General → Spell Categories and General → Dispel Colors: the two sets
-- every container shares (schema v2 made both the profile's).
--
--     [ Master controls ][ Display ][ Containers ][ Spell Categories ][ Dispel Colors ]
--     Spell Categories  [Category ▾]  [Restore this category's starter list]
--                       -- one of the eleven shipped spell lists, Weapon enchants, or one the
--                          player made -- which reads "(yours)" and is drawn no Restore
--                       ---- Your categories -------------------------------------------------
--                       "Created 'Affixes', empty. Add spells to it below..." <- the answer line
--                       [Rename this category][ Delete this category ]   <- a category you made
--                       'Healing is one of Aura Master's own categories...' <- a shipped one
--                       ---- Make a new category ---------------------------------------------
--                       [New category's name][ Aura type ▾ ]
--                       [ Create category ]
--                       ---- Spells in this category ----------------------------------------
--                       [Add a spell ____________________________][ Add ]
--                       (X) <icon> Ironbark (102342)             <- a starter, until its X hides it
--                       (X) <icon> A spell you added (424242)
--                           Also in: Immunities                  <- another category claims it too
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
-- THE TAB IS ALSO WHERE A PLAYER'S OWN CATEGORIES ARE MADE AND UNMADE (issue #10 checkpoints 6 and
-- 7). The 'Your categories' block between the picker and the list creates one (a name and an aura
-- type, fixed at creation), renames the picked one, and deletes it behind a confirmation; a SHIPPED
-- category draws a sentence there instead, because the lock is on the category object and not on
-- its spells. The block only DRAWS that rule -- `Cat.RenameUserCategory` and
-- `Cat.DeleteUserCategory` are what enforce it, and the aura type has no setter at all. Every
-- entry in the list is marked with the other categories that also claim it, and adding a claimed
-- id says so in chat: the guardrail informs and never blocks, because an aura legitimately belongs
-- to two sets.
--
-- EVERY ACT OF THAT BLOCK ANSWERS IN THE PANEL as well as in chat -- one line under the heading,
-- `notice` below -- and a category the player made is marked "(yours)" wherever it is listed, here
-- and on Filters -> Categories. Restore is not drawn for one at all: see the note above
-- `restoreStarters` for why an empty starter list makes that button a silent delete.
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
-- This file registers no SCHEMA ROWS of its own -- only the delete confirmation's
-- StaticPopupDialogs entry. settings/General.lua registers ENCHANT_ROWS then DISPEL_ROWS after
-- the Containers rows, so Spell Categories takes the fourth strip position and Dispel Colors the
-- fifth, and draws both tabs through TABS. It loads before General.lua for that reason, and before
-- settings/Filters.lua, whose Overrides lists read `candidates`, `ID_STRINGS` and `ID_TOOLTIP` from
-- here.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local Cat = NS.Categories
-- The compiler, for the overlap guardrail's one question (issue #10 checkpoint 7): which other
-- categories already claim a spell id. modules/FilterCompiler.lua loads long before this file.
local FC = NS.FilterCompiler

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

-- THE 'YOUR CATEGORIES' BLOCK ANSWERS IN THE PANEL, NOT ONLY IN THE CHAT FRAME. Pressing Create with
-- an empty box used to re-render with nothing visibly changed and a line in chat: from the panel's
-- side, a button that does nothing. So every act of that block sets this line, and the block draws
-- it directly under its heading -- one `H.TextRow`, which is the same grammar the Filters page
-- states its own conditions in and the same one this tab's shipped-category sentence already uses.
-- No new widget kind, and nothing to dismiss.
--
-- SESSION STATE, LIKE `spellCategory` AND `newName`: it is about the act just run, so the act sets
-- it, the render that follows draws it, the next act replaces it, and picking another category
-- clears it -- at that point it is about something the player is no longer looking at.
local notice

--- Re-render on the next frame: the dropdown or button whose callback asked is still on the stack.
local function rerender()
    if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end
end

--- The block's answer to the act just run: in the panel, and in chat as well. Chat stays because it
--- is this addon's act log -- the Containers page's acts print theirs there too, and a player who
--- looked away still finds the line. `nil` clears the panel's line and prints nothing.
local function say(text)
    notice = text
    if text then NS.Print(text) end
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

-- ---------------------------------------------------------------------------
-- The 'yours' marker (owner, 2026-09-21; issue #10 checkpoint 6 follow-up)
-- ---------------------------------------------------------------------------
--
-- A CATEGORY THE PLAYER MADE SAYS SO. Without it the only way to tell one of your own from one of
-- Aura Master's is to select it and read whether the block below draws a Name box or the lock
-- sentence -- fourteen selections to answer a question about the list. Knowing which are yours is
-- the feature, so it belongs on the row.
--
-- A SUFFIX ON THE NAME, and the aura-type marker above decides that rather than taste. That marker
-- is a PREFIX padded so that every name in the list starts at the same character offset; anything
-- added in FRONT of a name moves that column for the rows that carry it and costs the list exactly
-- the alignment the padding bought. A suffix cannot. It is also the right end for a second reason:
-- the question is asked while scanning, only a few rows answer yes, and marking the other twelve
-- "not yours" would be noise on every row to carry information on two.
--
-- ONE DEFINITION, TWO SURFACES. settings/Filters.lua's Categories grid reads `markedName` through
-- NS.GeneralSpells rather than formatting its own, so the dropdown and the grid cannot come to say
-- it differently. The grid marks a per-render COPY of its rows: the schema row keeps the bare name,
-- because that is the row's identity in `/am list` and in the write log, not a thing to decorate.
--
-- The name is the player's own text, so the token is substituted through a FUNCTION replacement,
-- exactly as CATEGORY_MARKER's is: a `%` in a name is an ordinary character (defaults/Categories.lua
-- keeps it deliberately) and must never be read as a gsub directive.
local USER_MARKER = L["{name} (yours)"]

--- `def`'s name as the panel shows it: `Cat.LabelOf`, marked when the player made the category.
--- `Cat.LabelOf` stays THE labeling rule -- this adds a marker to its answer and never a second copy
--- of it.
local function markedName(def)
    local name = Cat.LabelOf(def)
    if not Cat.IsUserCategory(def) then return name end
    return (USER_MARKER:gsub("{name}", function() return name end))
end

-- `s`'s length in CHARACTERS rather than bytes, so an aura-type word translated with an accent in it
-- pads by what the player actually sees. `Cat.CharCount` is the STORE's counter -- the one that caps
-- a category's name -- read here rather than copied, so a name the box accepts is a name the store
-- keeps whole and the two can never disagree about what a character is.
local charCount = Cat.CharCount

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
    if not typeLabel then return markedName(def) end
    local word = L[typeLabel]
    local pad = (" "):rep(math.max(0, TYPE_WORD_CHARS - charCount(word)))
    return (CATEGORY_MARKER
        :gsub("{type}", function() return word end)
        :gsub("{name}", function() return pad .. markedName(def) end))
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
        -- The answer line goes with the category it was about: a "Deleted 'X'" or a refusal left
        -- standing over a different category's controls would read as a statement about THAT one.
        dd:SetCallback("OnValueChanged", function(_, _, v) spellCategory = v; notice = nil; rerender() end)
        H.AttachTooltip(dd, L["Category"],
            L["Which spell category's list to edit. Every entry is marked with the aura type it filters, because a category only ever shows on a container of that type."])
        parent:AddChild(dd)
        return dd
    end }
end

-- ---------------------------------------------------------------------------
-- Restore, and why a category the player made does not get one
-- ---------------------------------------------------------------------------
--
-- RESTORE FORGETS EVERY EDIT so the category goes back to the list it SHIPPED with. On one of Aura
-- Master's own categories that is what the label promises and what the player gets. On a category
-- the player made, the shipped list is `{}` -- so the same act means "delete every spell in it",
-- silently, under a label describing something else, one row above a Delete that stops to ask
-- permission for exactly that loss.
--
-- THE CONTROL IS NOT DRAWN THERE AT ALL (owner's option (a)), rather than drawn under a second name
-- behind a second confirmation. A one-click empty buys nothing the tab does not already offer: the
-- list's own X takes spells out one at a time, and Delete takes the whole category, list included,
-- behind a confirmation that names what goes. A second destructive button whose only distinction
-- from the first is that it keeps an empty shell would be a second thing to read and get wrong.
-- "Restore this category's starter list" also has no honest relabeling for a category with no
-- starter list: renaming it "Empty this category" makes the picker line mean two different things
-- depending on which category is picked, which is the confusion finding #4 is about one block down.
--
-- AND THE ACT REFUSES IT TOO. Not drawing a button is a statement about this render;
-- `restoreStarters` is the enforcement, so a stale render, a future slash verb and any other caller
-- meet the same answer -- the division of labor `Cat.DeleteUserCategory` and `deleteCell` use.

--- Restore category `key` to its starter list: forget every edit, so removed starters come back and
--- added spells go. A category the player made is REFUSED -- it has no starter list, so there is
--- nothing for this to mean there but "empty it", which is not an act this tab performs unasked.
--- @return boolean|nil ok, string|nil reason
local function restoreStarters(key)
    if Cat.IsUserCategory(key) then
        return nil, L["Only one of Aura Master's own categories has a starter list to go back to. Take spells out of your own with the X beside each one, or delete the category."]
    end
    editCategory(key, function(mine)
        for id in pairs(mine) do mine[id] = nil end
    end)
    return true, nil
end

--- The Restore button, as the Category dropdown's right half (a RenderGrid cell, feedback #3): on
--- the same line, so the list's one reset sits beside the control that picks the list. A
--- cell-filling button, so it takes the library's inset width (options-ui-§6), never a flush half.
--- Drawn only for one of Aura Master's own categories -- see the note above.
local function restoreCell(key)
    return { make = function(_, parent)
        local btn = NS.AceGUI:Create("Button")
        btn:SetText(L["Restore this category's starter list"])
        btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
        btn:SetCallback("OnClick", function()
            local ok, why = restoreStarters(key)
            -- Nothing to say when it worked: the list visibly changes under the button.
            if ok then say(nil) else say(why) end
            rerender()
        end)
        H.AttachTooltip(btn, L["Restore this category's starter list"],
            L["Forget every edit to this category: its removed starter spells come back and the spells you added are removed. Other categories keep theirs."])
        parent:AddChild(btn)
        return btn
    end }
end


-- ---------------------------------------------------------------------------
-- Your categories: create, rename, delete, and the shipped lock (issue #10 checkpoint 6)
-- ---------------------------------------------------------------------------
--
--     [ Category v ]                    [ Restore this category's starter list ]
--     ---- Your categories ---------------------------------------------------
--     -- whatever the last act of this block answered, when there was one --
--     "Renamed 'Frist draft' to 'First draft'. To undo it, type 'Frist draft' back into the box."
--     -- a category the player made --
--     [ Rename this category ____ ]     [ Delete this category ]
--     -- one of Aura Master's own --
--     "Healing is one of Aura Master's own categories. Its name and its buff/debuff choice are
--      fixed, but the spell list below is yours -- add, remove and Restore as you like."
--     -- only while the profile holds a record the sync cannot read --
--     "Aura Master cannot read 1 of this profile's saved categories..."
--     [ Forget unreadable categories ]
--     ---- Make a new category ------------------------------------------------
--     [ New category's name _____ ]     [ Aura type v ]
--     [ Create category ]
--     ---- Spells in this category -------------------------------------------
--
-- THE LAYOUT, JUSTIFIED. The owner asked for simple and obvious, so this adds FOUR controls and no
-- new shape: every one of them is a plain AceGUI widget in an `H.RenderGrid` pair, which is the
-- grammar the picker line above it and the Filters page's own act rows already use. There is no new
-- widget kind, no inline list of categories with per-row buttons, and no separate management tab.
--
--   * IT SITS DIRECTLY UNDER THE PICKER, ABOVE the spell list, because it is about WHICH category
--     is being edited -- the same subject as the dropdown it follows. Below the list it would be
--     off-screen behind sixty spell entries on exactly the categories a player edits most.
--   * RENAME IS THE NAME BOX ITSELF, not a name box plus a Rename button. The box is the category's
--     name: it shows the stored one, and committing it (Enter, or the box's own accept) stores it.
--     A button beside it would be a second way to do the one thing the box already does. It is
--     LABELED with the act rather than the noun, and the create form is put under a heading of its
--     own, because two Enter-committing name boxes a row apart are two boxes to type in the wrong
--     one of -- renderManage says how the two are told apart and why that is enough.
--   * DELETE IS A BUTTON ON THE NAME'S OWN LINE, in the right half, exactly where the picker line
--     above puts Restore -- so the two destructive-ish acts of this tab sit in one column, and
--     neither is reachable without first picking the category it acts on.
--   * CREATE IS TWO CONTROLS AND A BUTTON, in reading order: what it is called, what it holds, make
--     it. The aura type is HERE and only here, because it is fixed at creation (the ledger: the
--     compiler groups by aura type and every container's stored Show/Hide is keyed by category key,
--     so letting the type move would silently carry a category between two grids and orphan that
--     state). A control that could only ever be set once would read as a control that is broken.
--   * THE SHIPPED CASE DRAWS ONE SENTENCE RATHER THAN DISABLED CONTROLS. A grayed-out name box and
--     a grayed-out Delete on twelve of the fourteen categories would be a panel mostly made of
--     things that do not work, and it would not say WHY. The sentence says why, and says the half
--     that is NOT locked -- the spell list, Restore included, which is the owner's exact
--     distinction.
--
-- THE LOCK IS NOT DRAWN, IT IS ENFORCED. `Cat.RenameUserCategory` and `Cat.DeleteUserCategory` both
-- refuse a key with no stored record, which is every shipped category, and the aura type has no
-- setter at all -- `Cat.CreateUserCategory` is the only writer of the field in the addon. So a
-- stale panel (a category deleted on another page, a render from before a profile switch) and a
-- future slash path both hit the same refusal the drawing rule is derived from. This tab never
-- decides the rule; it reads it off `Cat.IsUserCategory` and lets the acts answer.

-- The create form's state. Session, like `spellCategory`: it means nothing outside an open panel,
-- and it is carried across renders so a rerender (adding a spell, switching category) does not
-- throw away half-typed text.
local newName, newType = "", "HELPFUL"

-- Forward declaration: the new-category name box commits with Enter, and the Create button is the
-- same act. Declared here so one definition serves both rather than the box growing a copy of it.
local doCreate

--- The category set changed, so every container's compiled plan may have: a category added or
--- removed changes what `categorizedUnion` is the complement of, and a deleted one takes a whole
--- engine group with it. The panel refresh is `rerender`; this is the other half. A combat lockdown
--- needs no gate here -- CM defers the apply itself and says so -- unlike the container Delete,
--- which tears real frames down.
local function reapplyAll()
    if NS.ContainerManager and NS.ContainerManager.RequestApply then
        NS.ContainerManager.RequestApply()
    end
end

--- The picked category's name box: the rename, for a category the player made.
---
--- ON ENTER, NOT ON EVERY KEYSTROKE. A rename per keystroke would write a record (and re-run the
--- sync, and rebuild every schema row) for every character typed, and would store "H" on the way to
--- "Healing done". The box is redrawn from the STORE on the refresh that follows, so a refused or
--- empty name visibly snaps back to the stored one rather than leaving the box lying.
local function nameCell(def)
    return { make = function(_, parent, rel)
        local box = NS.AceGUI:Create("EditBox")
        box:SetLabel(L["Rename this category"])
        box:SetText(Cat.LabelOf(def))
        box:SetMaxLetters(Cat.USER_NAME_MAX)
        box:SetRelativeWidth(rel or 0.5)
        box:SetCallback("OnEnterPressed", function(_, _, text)
            local was = Cat.LabelOf(def)
            local ok, why = Cat.RenameUserCategory(def.key, text)
            if not ok then
                say(why)
            else
                -- THE OLD NAME, SAID OUT LOUD, IS THE WHOLE OF THE UNDO. A rename is recoverable by
                -- typing the previous name back and by nothing else, so the previous name has to
                -- still be somewhere the player can read it -- and the box itself no longer holds
                -- it, because it is redrawn from the store.
                say(L["Renamed '%s' to '%s'. To undo it, type '%s' back into the box."]
                    :format(was, Cat.SanitizeUserName(text) or text, was))
            end
            rerender()
        end)
        H.AttachTooltip(box, L["Rename this category"],
            L["What this category is called, in the lists and on every container's Filters tab. Press Enter to rename it. Renaming keeps everything else: its spells, and each container's Show or Hide for it."])
        parent:AddChild(box)
        return box
    end }
end

-- The confirmation, because Delete discards a list the player built by hand. It names the category
-- and then names WHAT IS LOST, in the order the act discards it: the spell list, and every
-- container's stored Show/Hide -- across every profile, which is the one consequence a player
-- cannot see from this page and so is the one the sentence has to say out loud.
StaticPopupDialogs["AURAMASTER_DELETE_CATEGORY"] = {
    -- It also says the one consequence that is not a loss and still surprises people: an aura this
    -- category was HIDING is not hidden by anything once the category is gone, so it comes back
    -- through Uncategorized on every container that shows that.
    text         = L["Delete the category '%s'? Its spell list is discarded, and every container in every profile forgets whether it showed or hid it — anything it was hiding becomes visible again through Uncategorized. Your other categories keep theirs."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function(_, data)
        -- `data` is the KEY, never the definition: the popup outlives the render that showed it, and
        -- a definition captured then may have been torn down and rebuilt by a sync since. The act
        -- refuses a key it does not find, which is exactly the answer a stale popup deserves.
        --
        -- The name is read BEFORE the act, because after it there is no definition left to read it
        -- off -- and the tab jumps to whatever category is first, so without a line naming the one
        -- that went, a delete looks like the dropdown changing its mind.
        local gone = Cat.Find("HELPFUL", data) or Cat.Find("HARMFUL", data)
        local name = gone and Cat.LabelOf(gone) or tostring(data)
        local ok, why = Cat.DeleteUserCategory(data)
        if not ok then return say(why) end
        say(L["Deleted '%s'. This tab is showing another category now."]:format(name))
        reapplyAll()
        H.RefreshAllPanels()
    end,
}

--- The picked category's Delete, for a category the player made. Cell-filling, like Restore above.
local function deleteCell(def)
    return { make = function(_, parent)
        local btn = NS.AceGUI:Create("Button")
        btn:SetText(L["Delete this category"])
        btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
        btn:SetCallback("OnClick", function()
            local popup = StaticPopup_Show("AURAMASTER_DELETE_CATEGORY", Cat.LabelOf(def))
            if popup then popup.data = def.key end
        end)
        H.AttachTooltip(btn, L["Delete this category"],
            L["Discards this category, the spells you put in it, and every container's Show or Hide for it. Your other categories are not affected."])
        parent:AddChild(btn)
        return btn
    end }
end

-- ---------------------------------------------------------------------------
-- The way out of a stored record the sync cannot read
-- ---------------------------------------------------------------------------
--
-- `Cat.UnusableUserRecords` has the whole of the reasoning: a record with no usable aura type, no
-- usable name or a key outside the reserved namespace is SKIPPED by the sync rather than guessed at,
-- which is right, but it leaves the record with no definition -- so it is in no dropdown, no Delete
-- reaches it, and even its debris cannot be swept while it is still on disk. "Left for the player to
-- fix or delete" has to mean there is something the player can press. This is it.
--
-- IT IS DRAWN ONLY WHEN THERE IS ONE, so the ordinary panel is unchanged, and it says the two things
-- that decide whether to press it: that nothing is using these records, and that what they hold
-- cannot be recovered from here. The confirmation is the same shape Delete's is, for the same
-- reason -- it discards stored data the player cannot see and so cannot weigh.
StaticPopupDialogs["AURAMASTER_FORGET_BROKEN_CATEGORIES"] = {
    text         = L["Forget the %d saved categories Aura Master cannot read? They are in no list and cannot be repaired from here, and whatever they held is discarded. Your other categories are not affected."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function()
        -- The list is re-read by the act rather than carried on the popup: the popup outlives the
        -- render that showed it, and the answer to "which records are unreadable" is the store's.
        local gone = Cat.ForgetUnusableUserRecords()
        say(L["Forgot %d unreadable saved categories."]:format(gone))
        reapplyAll()
        H.RefreshAllPanels()
    end,
}

--- The unreadable-records line and its button, or nothing at all when the profile has none.
local function renderBroken(ctx)
    local bad = Cat.UnusableUserRecords(NS.db and NS.db.profile)
    local count = #bad
    if count == 0 then return end
    H.TextRow(ctx, L["Aura Master cannot read %d of this profile's saved categories, so they are in no list and nothing is using them. They cannot be repaired from here, but you can be rid of them."]
        :format(count))
    H.RenderGrid(ctx, { { make = function(_, parent)
        local btn = NS.AceGUI:Create("Button")
        btn:SetText(L["Forget unreadable categories"])
        btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
        btn:SetCallback("OnClick", function()
            StaticPopup_Show("AURAMASTER_FORGET_BROKEN_CATEGORIES", count)
        end)
        H.AttachTooltip(btn, L["Forget unreadable categories"],
            L["Discards the saved categories Aura Master cannot read, and any spell lists or container decisions left under their keys. Asks first."])
        parent:AddChild(btn)
        return btn
    end } })
end

--- The new category's name box. Typing is remembered across renders (`newName`), and Enter creates,
--- so the form can be completed without reaching for the mouse.
local function newNameCell()
    return { make = function(_, parent, rel)
        local box = NS.AceGUI:Create("EditBox")
        box:SetLabel(L["New category's name"])
        box:SetText(newName)
        box:SetMaxLetters(Cat.USER_NAME_MAX)
        box:SetRelativeWidth(rel or 0.5)
        box:SetCallback("OnTextChanged", function(_, _, text) newName = text end)
        box:SetCallback("OnEnterPressed", function(_, _, text)
            newName = text
            doCreate()
        end)
        H.AttachTooltip(box, L["New category's name"],
            L["A name for a category of your own. Two categories may share a name — each keeps its own spells — but a name you can tell apart in a dropdown is easier to live with."])
        parent:AddChild(box)
        return box
    end }
end

--- The new category's aura type. Reads `C.AURA_TYPE_LABELS`, the same two words the dropdown's
--- markers and every container's own Aura type row use, in `C.AURA_TYPES` order.
local function newTypeCell()
    return { make = function(_, parent, rel)
        local list, order = {}, {}
        for i, auraType in ipairs(C.AURA_TYPES) do
            list[auraType] = L[C.AURA_TYPE_LABELS[auraType]]
            order[i] = auraType
        end
        local dd = NS.AceGUI:Create("Dropdown")
        dd:SetLabel(L["Aura type"])
        dd:SetList(list, order)
        dd:SetValue(newType)
        dd:SetRelativeWidth(rel or 0.5)
        dd:SetCallback("OnValueChanged", function(_, _, v) newType = v end)
        H.AttachTooltip(dd, L["Aura type"],
            L["Whether this category holds buffs or debuffs. It is fixed when the category is created: a category only ever shows on a container of its own type, and moving it would lose every container's Show or Hide for it. To change it, make a new category and delete this one."])
        parent:AddChild(dd)
        return dd
    end }
end

--- Create the category the form describes, then select it: a category made and not shown would
--- leave the player to find it in a dropdown of fourteen.
function doCreate()
    local key, why = Cat.CreateUserCategory(newName, newType)
    if not key then
        say(why)
        return rerender()
    end
    -- THE SANITIZED NAME, NEVER THE RAW BOX TEXT. `Cat.SanitizeUserName` strips `|` precisely because
    -- the client reads it as the escape character, and the create has just succeeded, so a clean
    -- name is guaranteed. Formatting the box's own text instead would hand a `|c` or a `|T` typed
    -- into the box straight to the chat frame and to this panel's own line.
    local clean = Cat.SanitizeUserName(newName) or newName
    if Cat.UserCategoryNameTaken(NS.db.profile, newName, key) then
        -- INFORMS, DOES NOT REFUSE (the ledger): the key is identity, so two categories with one
        -- name are two categories. The line is for the player who typed the same name twice by
        -- accident and would otherwise wonder which of the two the dropdown is showing them.
        say(L["There is already a category called '%s'. Both were kept — they are separate categories with separate spell lists."]:format(clean))
    else
        say(L["Created '%s', empty. Add spells to it below, then set it to Show or Hide on each container's Filters -> Categories tab."]:format(clean))
    end
    newName = ""
    spellCategory = key
    reapplyAll()
    rerender()
end

--- The Create button. Cell-filling in the left half of a line of its own, under the two controls it
--- reads, because it acts on both of them.
local function createCell()
    return { make = function(_, parent)
        local btn = NS.AceGUI:Create("Button")
        btn:SetText(L["Create category"])
        btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
        btn:SetCallback("OnClick", doCreate)
        H.AttachTooltip(btn, L["Create category"],
            L["Makes a category of your own, empty. Fill it from the list below, then set it to Show or Hide on each container's Filters -> Categories tab like any other category."])
        parent:AddChild(btn)
        return btn
    end }
end

--- The "Your categories" block: the answer line, the picked category's own controls (or the sentence
--- saying why it has none), the way out of an unreadable record, and then the create form under a
--- heading of its own. Drawn for the enchant row too -- it is one of the shipped categories the
--- sentence is about, and creating a category is not a thing only the spell-list tabs may do.
---
--- THE SHIPPED SENTENCE COMES IN TWO, because Weapon enchants is not a spell list. The general one
--- promises "add, remove and Restore" the list below, and on the enchant entry there is no list
--- below to add to, nothing to remove and no Restore drawn -- a sentence describing three controls
--- the tab does not have. The enchant entry gets the half of the sentence that IS true (the name and
--- the aura type are fixed) plus what it actually draws.
---
--- THE CREATE FORM SITS UNDER ITS OWN HEADING, and finding #4 is why. "Rename this category" and the
--- create form's name box are two Enter-committing edit boxes a row apart; the rename takes effect
--- at once and has no undo but retyping the old name. Three things now tell them apart, and none of
--- them is a color or an icon: they are under DIFFERENT HEADINGS, so the block the player is reading
--- says which act they are in; their labels name ACTS rather than the noun they share ("Rename this
--- category" against "New category's name", where the old "Name" and "New category" differed by one
--- word); and only one of them is ever pre-filled -- the rename box is redrawn from the store on
--- every render, so it always holds the live name, while the create box holds an empty string until
--- the player types. A rename that does go through now says the OLD name back (`nameCell`), which is
--- the only undo a rename has.
local function renderManage(ctx, def)
    local scroll = H.EnsureScroll(ctx)
    if scroll then H.AddSpacer(scroll, SECTION_GAP) end
    H.Section(ctx, L["Your categories"])
    if notice then H.TextRow(ctx, notice) end
    if Cat.IsUserCategory(def) then
        H.RenderGrid(ctx, { nameCell(def), deleteCell(def) })
    elseif def.kind == "enchant" then
        H.TextRow(ctx, L["'%s' is one of Aura Master's own categories: its name and its buff or debuff choice are fixed. It holds no spell list at all — the weapon slots below are what it reads."]
            :format(Cat.LabelOf(def)))
    else
        H.TextRow(ctx, L["'%s' is one of Aura Master's own categories: its name and its buff or debuff choice are fixed. Its spell list is still yours — add, remove and Restore it as you like."]
            :format(Cat.LabelOf(def)))
    end
    renderBroken(ctx)
    if scroll then H.AddSpacer(scroll, SECTION_GAP) end
    H.Section(ctx, L["Make a new category"])
    H.RenderGrid(ctx, { newNameCell(), newTypeCell() })
    H.RenderGrid(ctx, { createCell() })
end

-- ---------------------------------------------------------------------------
-- The overlap guardrail (issue #10 checkpoint 7)
-- ---------------------------------------------------------------------------
--
-- INFORM, DO NOT BLOCK -- the ledger decided this before any of it was written, and the reason is
-- that overlap is CORRECT: a defensive that is also an immunity belongs on both lists, and the
-- compiler already resolves the overlap by drawing the aura once, under the first category set to
-- Show (docs/ARCHITECTURE.md, Filter priority). Refusing the add would make a correct configuration
-- unreachable. So the player is told WHICH other categories hold the id, twice over: once in a chat
-- line at the moment of the add, and permanently as a note under the entry in the list.
--
-- ASKED OF `FC.ClaimingCategories`, WHICH IS THE COMPILER'S OWN ANSWER (published at checkpoint 7).
-- A walk written here would be a second answer to the question "whose list is this id on", free to
-- drift from `FC.CategorySpells`'s starters-unioned-with-edits rule -- and a guardrail that
-- disagrees with the plan is worse than none. The filter handed in is EMPTY on purpose: this is a
-- statement about the category set, not about any one container, so every claim comes back `show`
-- and the state is ignored.
--
-- ONLY THE SAME AURA TYPE CAN CLAIM. Category membership is per aura type -- a buff list and a
-- debuff list never meet in one container -- so a buff category and a debuff category holding one id
-- do not overlap at all, and saying they did would be a false alarm on every dispel and interrupt id
-- that appears in both worlds.

--- Every OTHER category of `def`'s aura type that already holds `id`, as labels in declaration
--- order. `Cat.LabelOf` has already been applied by the compiler, so these are drawn as they are.
--- @return table  labels, possibly empty
local function otherClaimants(def, id)
    local out = {}
    local profile = NS.db and NS.db.profile
    local claiming = FC.ClaimingCategories(Cat, Cat.AuraTypeOf(def), {},
        profile and profile.categorySpells, id)
    for _, c in ipairs(claiming) do
        if c.key ~= def.key then
            local n = #out
            out[n + 1] = c.label
        end
    end
    return out
end

--- The list entry's note for `id`, or nil: which other categories claim it. The library draws a
--- noted entry on a full-width row of its own, so an unclaimed id costs nothing.
local function overlapNote(def, id)
    local others = otherClaimants(def, id)
    if not others[1] then return nil end
    -- The join is a plain ", " for the same reason settings/Filters.lua's `categoryLabelList` gives:
    -- every label in it is already localized, only enUS ships, and if a second locale ever does it
    -- is the SEPARATOR that needs routing, never the labels.
    return L["Also in: %s"]:format(table.concat(others, ", "))
end

--- Say, once, that the spell just added is claimed elsewhere too. At the ADD rather than only in the
--- list, because the list is long and sorted by name: the note the player needs to see is eight
--- screens down from the box they typed into.
local function sayOverlap(def, id)
    local others = otherClaimants(def, id)
    if not others[1] then return end
    local name = NS.Compat.GetSpellInfo(id)
    NS.Print(L["%s is also in: %s. An aura in two categories is drawn once, under the first of them a container sets to Show."]
        :format(name or tostring(id), table.concat(others, ", ")))
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
        renderManage(ctx, def)
        return renderEnchant(ctx)
    end
    -- A category the player made has no starter list, so neither sentence nor button may promise one
    -- (the note above `restoreStarters`): the lead-in drops the Restore clause and the picker line
    -- drops the button, leaving the dropdown the whole width of that line.
    if Cat.IsUserCategory(def) then
        H.TextRow(ctx, L["The spells this category matches, shared by every container. Click X to leave one out, or add your own. Blizzard only honors spell lists for buffs on friendly units and debuffs on hostile ones."])
        H.RenderGrid(ctx, { categoryCell(defs, def) })
    else
        H.TextRow(ctx, L["The spells each category matches, shared by every container. Click X to leave one out, or add your own; Restore brings the starter list back. Blizzard only honors spell lists for buffs on friendly units and debuffs on hostile ones."])
        -- Restore on the dropdown's line (feedback #3): with the checkboxes gone (B2) a removed
        -- starter is off the list, and this is how it comes back.
        H.RenderGrid(ctx, { categoryCell(defs, def), restoreCell(key) })
    end
    -- Create / rename / delete, between the picker and the list: the block is about WHICH category
    -- is being edited, which is the dropdown's subject, not the spell list's.
    renderManage(ctx, def)
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
        -- The entries, each marked with the other categories that also claim it (checkpoint 7's
        -- guardrail). The note is computed per draw rather than stored: it is a statement about the
        -- other lists, and those change under this one -- from this very tab, and from another
        -- category's Restore.
        entries    = function()
            local out = entriesFor(def)
            for _, e in ipairs(out) do e.note = overlapNote(def, e.id) end
            return out
        end,
        -- Adding a starter back includes it again (drops its `false`); anything else is an addition.
        onAdd = function(id)
            editCategory(key, function(mine)
                if def.spells and def.spells[id] then mine[id] = nil else mine[id] = true end
            end)
            -- INFORM, NEVER REFUSE: the add has already happened above. What the player is told is
            -- which other categories of this aura type also hold the id, and what the compiler does
            -- about it (checkpoint 7).
            sayOverlap(def, id)
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
-- `MarkedName` is the ONE definition of the 'yours' marker, read by settings/Filters.lua's Categories
-- grid; `RestoreStarters` is the restore ACT, published so that it is testable and so that any
-- future caller meets the refusal the button's absence only implies.
NS.GeneralSpells = {
    DISPEL_ROWS = DISPEL_ROWS, ENCHANT_ROWS = ENCHANT_ROWS, TABS = TABS,
    candidates = candidates, ID_STRINGS = ID_STRINGS, ID_TOOLTIP = ID_TOOLTIP,
    MarkedName = markedName, RestoreStarters = restoreStarters,
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
