local _, NS = ...

-- settings/GeneralSpells.lua — General → Spell Categories: the spell lists every container shares
-- (schema v2 made them the profile's). Its sibling set, General → Dispel Colors, is
-- settings/GeneralDispel.lua (issue #16).
--
--     [ Master controls ][ Display ][ Containers ][ Spell Categories ][ Dispel Colors ]
--     Spell Categories  [Category ▾]  [Restore this category's starter list]
--                       -- one of the eleven shipped spell lists, Weapon enchants, or one the
--                          player made -- which reads "(yours)" and is drawn no Restore. Every
--                          entry is marked [Buffs] green or [Debuffs] red, "(yours)" gold
--                       [Rename this category][ Delete this category ]   <- a category you made,
--                          straight under the picker and under no heading; a shipped one draws
--                          nothing here at all
--                       "Created 'Affixes', empty. Add spells to it below..." <- the answer line
--                       ---- Make a new category ---------------------------------------------
--                       [New category's name][ Create category ]
--                       [ Aura type ▾ ]
--                       ---- Spells in this category ----------------------------------------
--                       [Add a spell ____________________________][ Add ]
--                       (X) <icon> Ironbark (102342)             <- a starter, until its X hides it
--                       (X) <icon> A spell you added (424242) (also in 1)
--                                                                <- another category claims it too;
--                                                                   hovering the entry names it
--                    -- OR, when the category is Weapon enchants --
--                       ---- Weapon slots ----------------------------------------------------
--                       [x] Main hand   [x] Off hand   [x] Ranged
--     Dispel Colors     settings/GeneralDispel.lua
--
-- SPELL CATEGORIES is bespoke: the category dropdown, the restore, then the library's IdList over that
-- category's edits, drawn with an X at the left of every entry (`removeStyle = "icon"`, LibKa0s
-- v1.44.0; B2, 2026-09-19). The edits live at the ABSOLUTE path `categorySpells`
-- ({ [categoryKey] = { [spellId] = true | false } }), a carve-out written whole through the seam
-- (settings/Schema.lua), so an edit here re-applies every container. A starter the player removes is
-- stored `false` (nil would let the shipped list bring it back) and drops out of the list until
-- Restore (or typing it back in) returns it; a spell the player adds is stored `true`, and
-- the carve-out's normalizer stores no category left with no edits. The lists are not schema rows, so
-- the page's Defaults leaves them alone, as the Filters section's leaves its Overrides lists; each
-- category has its own restore.
--
-- The dropdown also offers Weapon enchants (kind "enchant"): the odd category with no spell list at
-- all. Choosing it draws ENCHANT_ROWS instead — three real schema rows at `enchantSlots.<slot>`
-- (schema v3, B3), so `/am get|set|list`, Defaults and the resets all see them — plus a line saying
-- the per-container on/off switch lives on Filters → Categories (settings/Filters.lua, B5). The rows
-- carry `skipRender = true`, exactly like the Filters section's category rows: this tab draws them
-- itself rather than the flow engine drawing them a second time.
--
-- NS.GeneralSpells.Select(key) is the seam a per-row link on another page (Filters → Categories, B5)
-- uses to land here on a specific category: it moves this tab's own selection AND the General page's
-- active tab. A key this tab cannot draw (a token or flag category, say) is ignored, so a stale link
-- can never leave the tab showing an empty list.
--
-- THE TAB IS ALSO WHERE A PLAYER'S OWN CATEGORIES ARE MADE AND UNMADE (issue #10 checkpoints 6 and
-- 7). The rename box and the Delete sit directly under the picker, for a category the player made
-- and for no other, and 'Make a new category' under them creates one (a name and an aura type,
-- fixed at creation); a SHIPPED category draws neither, and no sentence in their place either
-- (owner, 2026-09-21). That is a DRAWING rule only -- `Cat.RenameUserCategory` and
-- `Cat.DeleteUserCategory` are what enforce it, and the aura type has no setter at all. Every
-- entry in the list is marked with how many other categories also claim it, and adding a claimed
-- id says so in chat: the guardrail informs and never blocks, because an aura legitimately belongs
-- to two sets. On the row that mark is a gray `(also in N)` after the id -- LibKa0s v1.49.0's entry
-- `suffix`, which costs the row nothing -- and the NAMES are in the entry's tooltip.
--
-- EVERY ACT OF THAT BLOCK ANSWERS IN THE PANEL as well as in chat -- one line under the controls,
-- `notice` -- and a category the player made is marked "(yours)" wherever it is listed, here
-- and on Filters -> Categories. Restore is not drawn for one at all: see the note above
-- `restoreStarters` for why an empty starter list makes that button a silent delete.
--
-- THAT BLOCK IS ITS OWN FILE, settings/GeneralUserCategories.lua (AM-ATS-03, peeled along the 'Make
-- a new category' seam): the rename, the Delete, the way out of an unreadable record, the create
-- form, the answer line and the tab's selection it is stamped with. This file draws the picker and
-- the list and calls that block's `Render` between them.
--
-- This file registers no SCHEMA ROWS of its own and no StaticPopupDialogs entry -- the delete
-- confirmation is settings/GeneralUserCategories.lua's. settings/General.lua registers ENCHANT_ROWS
-- after the Display rows and settings/GeneralDispel.lua's rows after those, so Spell Categories
-- takes the third strip position and Dispel Colors the fourth, and draws this tab through TABS. It
-- loads after settings/GeneralUserCategories.lua, whose table it reads at file load; before
-- GeneralDispel.lua, which reads BULLET and BULLET_GAP from here, and before General.lua for the
-- rows; and before settings/Filters.lua, whose Overrides lists read `candidates`, `ID_STRINGS` and
-- `ID_TOOLTIP` from here.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local Cat = NS.Categories
-- The compiler, for the overlap guardrail's one question (issue #10 checkpoint 7): which other
-- categories already claim a spell id. modules/FilterCompiler.lua loads long before this file.
local FC = NS.FilterCompiler
-- The cast -> aura lookup (issue #15): what to store when a player types a spell that is CAST
-- as one id and lands as another, and what to draw under an entry already holding one.
-- modules/CastAura.lua loads before this file.
local CA = NS.CastAura
-- The own-category block and the answer line, peeled out of this file along the 'Make a new
-- category' seam (AM-ATS-03): settings/GeneralUserCategories.lua, which loads directly before this
-- one. It also owns the tab's selection, because the answer line is stamped with it.
local UC = NS.GeneralUserCategories
local rerender, say, endVisit, renderManage = UC.Rerender, UC.Say, UC.EndVisit, UC.Render

local PAGE = "general"
local SPELLS = L["Spell Categories"]
-- Only for the Spell Categories tab's `before`: the tab itself is settings/GeneralDispel.lua's.
local DISPEL = L["Dispel Colors"]

-- One bullet's marker, prefixed at draw so the locale keys stay plain prose (settings/Text.lua's
-- cheat sheet does the same). Published on NS.GeneralSpells for settings/GeneralDispel.lua.
local BULLET = "- "

-- A hairline between two bullets: enough that they are not read as one wrapped paragraph, small
-- enough that they still read as one block. settings/Filters.lua's PRIORITY_RANK_GAP, same reason.
local BULLET_GAP = 4

-- The gap a subsection heading gets above it: settings/GeneralUserCategories.lua's, which draws the
-- 'Make a new category' heading with it. See the note at the `H.Section` call in `renderSpells` for
-- why the number is a literal.
local SECTION_GAP = UC.SECTION_GAP

-- ---------------------------------------------------------------------------
-- Spell Categories
-- ---------------------------------------------------------------------------

--- Whether `def` is a row this tab can draw: a spell list of either aura type, or the weapon-enchant
--- row, whose entry shows its slots rather than a list. Buffs are no longer the whole story — issue
--- #11 gave `Cat.HARMFUL` its first `spells`-kind categories (`hardCC`, `softCC`) and the engine
--- honors debuff spell ids on a hostile target or focus — so the test is the KIND, never the aura
--- type. Missing that is how a shipped list becomes uneditable: the Filters section's `See spells` link
--- offers itself for every `spells`-kind row it draws, including a debuff container's.
local function editableHere(def)
    return def ~= nil and (def.kind == "spells" or def.kind == "enchant")
end

--- The categories this tab can edit, buff lists first and in each aura type's own declaration order,
--- so the dropdown reads the way the Filters section's grids do.
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
    local selected = UC.Selected()
    local def = Cat.Find("HELPFUL", selected) or Cat.Find("HARMFUL", selected)
    if not editableHere(def) then def = defs[1] end
    UC.SetSelected(def.key)
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
--- The library draws such an entry as "Unknown spell 12345" (`entryLabel`,
--- `OptionsWidgets.lua:2792-2803`), so it carries no name for a reader to look for and belongs at
--- the end rather than wedged between two real names; and the id tiebreak makes the whole
--- comparison a total order over the set, so the sort is deterministic whatever order `pairs`
--- hands the ids in. A nil name never reaches the comparison — it is resolved once, up front,
--- into `key`.
---
--- The list does NOT reorder itself a moment later. O.IdList's re-ask-and-redraw (five asks, 0.4 s
--- a window) is the ITEM path: `loadEntry` returns at once unless the kind declares `loads = true`,
--- which only "item" does (`OptionsWidgets.lua:2840-2845`, and the candidate rule at `:744`). A
--- spell's name is client data with no load step, so an id that is unnamed at this draw is an id
--- the client does not know at all, and it stays unnamed and last until a re-render — no visible
--- settling, and nothing here to mistake for a bug.
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

-- Both widgets' tooltip on every spell ID list: how to add, that the id has to be the AURA's, then
-- where a name can come from. One routed sentence with a `{hint}` token (localization-§1), filled
-- by a function so no `%` in a translation is read as a pattern.
--
-- THE AURA SENTENCE IS THIS ADDON'S, AND `{hint}` IS THE LIBRARY'S. NAME_HINT is a localized copy
-- of `O.ID_NAME_HINT.spell` and tests/test_pages_general_categories.lua pins the two as equal, so
-- that a translation rewords the tooltip and the widget's own refusal together. The fact that an id has to
-- be the one the aura carries is not the library's business -- it is true of THIS addon, because
-- this addon filters on auras -- so it belongs in the sentence this file owns (issue #15,
-- acceptance criterion 4). modules/CastAura.lua catches the ids it can and says so at add time;
-- this sentence stands behind the ones it cannot.
local ID_TOOLTIP = (L["Type a spell id or a name and pick from the list, or shift-click a spell link into the box, then press Enter or Add. The id has to be the one the AURA carries, which is not always the one you cast. {hint}"]
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
-- (settings/Containers.lua:82), the gray summary behind every container in the picker
-- (settings/OptionsSetup.lua:363) and the `/am list` line (settings/Slash.lua:180) -- those three
-- are its readers, and the Filters section is not among them; its category rows are labeled from the
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
--
-- THE MARKER IS COLORED, AND MUTED (owner, 2026-09-21, from the live panel). Green for buffs, red
-- for debuffs, gold for a category the player made. MUTED is the word: these sit BESIDE a name and
-- are not the subject of the row, so each is a dimmed version of its hue rather than the saturated
-- one a status light would use. The panel already has a register for chrome of this kind -- the
-- drag handle's gold label at (1, 0.82, 0) and its help mark at (0.7, 0.7, 0.72),
-- libs/LibKa0s/WidgetsDragHandle.lua:492 and :168 -- and these three sit inside it:
--
--     Buffs    (0.45, 0.75, 0.50) = 73bf80   muted green
--     Debuffs  (0.80, 0.45, 0.45) = cc7373   muted red
--     (yours)  (0.85, 0.72, 0.38) = d9b861   the handle's gold, dimmed toward the help mark
--
-- THE ESCAPES ARE NOT CHARACTERS, AND THE PADDING NEVER SEES THEM. `|cAARRGGBB` and `|r` are read
-- by the client and drawn as nothing at all, so a padding measured over a colored string would pad
-- by twelve phantom characters and throw the column away -- which is exactly how this change goes
-- wrong. It cannot here: `categoryLabel` measures `charCount(word)` on the BARE aura-type word, the
-- color is applied to the finished bracket afterwards, and both markers carry the same one `|c` and
-- one `|r`, so the offsets do not even move in BYTES. tests/test_pages_general.lua strips every
-- escape and asserts the name still starts at one offset in what is left, which is the thing the
-- player's eye actually measures.
--
-- THE BRACKETS ARE COLORED WITH THE WORD, so the marker reads as one object. That is why the shape
-- string takes a `{mark}` rather than a `{type}`: the bracketed marker is built and colored whole,
-- and only then dropped into the line. Both halves stay in the locale -- the brackets are a
-- translator's to restyle, as they were when they were literals in the shape.
local CATEGORY_MARKER = L["{mark} {name}"]
local TYPE_MARK       = L["[{type}]"]

-- The muted markers, as the client's own escapes. Applied by `colored`, which leaves text alone
-- when there is no color for it: a `|r` with no `|c` in front of it would close a color the panel
-- never opened.
local COLOR_END   = "|r"
local TYPE_COLORS = { HELPFUL = "|cff73bf80", HARMFUL = "|cffcc7373" }
local YOURS_COLOR = "|c" .. C.SECONDARY_GOLD

--- `text` in `color`, or `text` unchanged when there is no color for it.
local function colored(color, text)
    if type(color) ~= "string" or color == "" then return text end
    return color .. text .. COLOR_END
end

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
-- exactly as CATEGORY_MARKER's is: a `%` in a name is an ordinary character (defaults/UserCategories.lua
-- keeps it deliberately) and must never be read as a gsub directive.
--
-- IN MUTED GOLD, and the marker is its own locale string for the same reason the aura type's
-- bracket is: the parentheses are part of the mark and are colored with it, so the shape string
-- holds a `{mark}` and the mark holds the words. The mark is substituted BEFORE the name, so a
-- player who types "{name}" or "{mark}" into a category's name gets those characters back rather
-- than a second substitution.
--
-- COLORED HERE MEANS COLORED EVERYWHERE THE PANEL LISTS A CATEGORY: this is the one definition
-- (settings/Filters.lua's Categories grid, and the claiming names in an entry's tooltip, both
-- read it), and a gold marker in the dropdown beside a plain one in the grid would read as two
-- different marks.
local USER_MARKER = L["{name} {mark}"]
local YOURS_MARK  = L["(yours)"]

--- `def`'s name as the panel shows it: `Cat.LabelOf`, marked when the player made the category.
--- `Cat.LabelOf` stays THE labeling rule -- this adds a marker to its answer and never a second copy
--- of it.
local function markedName(def)
    local name = Cat.LabelOf(def)
    if not Cat.IsUserCategory(def) then return name end
    local mark = colored(YOURS_COLOR, YOURS_MARK)
    return (USER_MARKER
        :gsub("{mark}", function() return mark end)
        :gsub("{name}", function() return name end))
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
    -- MEASURED ON THE BARE WORD, before any color reaches it: `|cff73bf80` and `|r` are drawn as
    -- nothing, so padding out a colored marker would pad by twelve characters the player cannot see.
    local pad = (" "):rep(math.max(0, TYPE_WORD_CHARS - charCount(word)))
    local mark = colored(TYPE_COLORS[auraType],
        (TYPE_MARK:gsub("{type}", function() return word end)))
    return (CATEGORY_MARKER
        :gsub("{mark}", function() return mark end)
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
-- Both calls are capability-guarded (the same shape as modules/Style.lua:899): the headless widget
-- kit is a data recorder with neither method, and it is not ours to extend.
local CATEGORY_PULLOUT_WIDTH = 320

--- Size `dd`'s open list to its own entries and pin its closed box to LEFT justification.
local function sizeCategoryDropdown(dd)
    if dd.SetPulloutWidth then dd:SetPulloutWidth(CATEGORY_PULLOUT_WIDTH) end
    local fs = dd.text
    if type(fs) == "table" and fs.SetJustifyH then fs:SetJustifyH("LEFT") end
end

--- The Category picker.
---
--- `wide` when it is alone on its line, which is every branch but the shipped one that puts
--- Restore beside it (owner, from the live panel, 2026-09-22). A half-width dropdown with empty
--- space to its right read as though a control had failed to draw; a category's name is also the
--- longest string on the line, and `(yours)` plus the `[Buffs]` marker were being truncated on a
--- narrow canvas for no reason. RenderGrid hands a wide item `rel = nil`, which is what
--- `SetFullWidth` below keys off.
local function categoryCell(defs, def, wide)
    return { wide = wide, make = function(_, parent, rel)
        local list, order = {}, {}
        for i, d in ipairs(defs) do
            list[d.key] = categoryLabel(d)
            order[i] = d.key
        end
        local dd = NS.AceGUI:Create("Dropdown")
        dd:SetLabel(L["Category"])
        dd:SetList(list, order)
        dd:SetValue(def.key)
        if rel then dd:SetRelativeWidth(rel) else dd:SetFullWidth(true) end
        sizeCategoryDropdown(dd)
        -- The answer line is not cleared here. It goes with the category it was about -- a
        -- "Deleted 'X'" or a refusal standing over a different category's controls would read as a
        -- statement about THAT one -- and `settleNotice` is the ONE place that rule lives, so this
        -- selection and a profile switch and a panel reopen all meet the same test
        -- (settings/GeneralUserCategories.lua).
        dd:SetCallback("OnValueChanged", function(_, _, v) UC.SetSelected(v); rerender() end)
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
-- The overlap guardrail (issue #10 checkpoint 7)
-- ---------------------------------------------------------------------------
--
-- INFORM, DO NOT BLOCK -- the ledger decided this before any of it was written, and the reason is
-- that overlap is CORRECT: a defensive that is also an immunity belongs on both lists, and the
-- compiler already resolves the overlap by drawing the aura once, under the first category set to
-- Show (docs/data-flow.md, Filter priority). Refusing the add would make a correct configuration
-- unreachable. So the player is told WHICH other categories hold the id, twice over: once in a chat
-- line at the moment of the add, and permanently on the entry's own row -- a count in its label,
-- the names in its tooltip.
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

--- Every OTHER category of `def`'s aura type that already holds `id`, as the panel names them, in
--- declaration order.
---
--- MARKED "(yours)" LIKE EVERY OTHER LIST ON THIS TAB (owner, 2026-09-21). The compiler answers with
--- `Cat.LabelOf`'s name, which is the labeling rule and stays it -- but the marker is the PANEL's,
--- added by `markedName` wherever the panel lists a category, and these two lines were the only
--- place it listed one without it. A claimed-by tooltip line reading "Also in: Immunities" could
--- name a category the player made and never say so, in a sentence whose whole job is to tell them
--- where else their spell already lives. Resolved by KEY out of `def`'s own aura type, which is
--- the only type that can claim (see above), so the lookup is total over the answer.
--- @return table  labels, possibly empty
local function otherClaimants(def, id)
    local out = {}
    local profile = NS.db and NS.db.profile
    local auraType = Cat.AuraTypeOf(def)
    local claiming = FC.ClaimingCategories(Cat, auraType, {},
        profile and profile.categorySpells, id)
    for _, c in ipairs(claiming) do
        if c.key ~= def.key then
            local other = auraType and Cat.Find(auraType, c.key)
            local n = #out
            out[n + 1] = other and markedName(other) or c.label
        end
    end
    return out
end

--- The list entry's suffix for `id`, or nil: HOW MANY other categories claim it, in a few gray
--- words the library draws INSIDE the entry's own label, after the id -- `(X) [icon] Renewing Mist
--- (119611) (also in 1)` (owner, 2026-09-21; LibKa0s v1.49.0's `entry.suffix`, OptionsWidgets minor
--- 25, `libs/LibKa0s/OptionsWidgets.lua:2756-2803`). It replaces the `note` this used to be: a note
--- is a second full-width Label that took the entry out of the two-column grid for the row it landed
--- on, and the library's own guidance is a sentence in a `note`, a few words in a `suffix`, and the
--- full story in the TOOLTIP -- which is where the NAMES now are (`overlapLine`).
---
--- The count is `#otherClaimants`, so it is still `FC.ClaimingCategories`'s answer and not a second
--- walk of the category set.
---
--- TWO WHOLE STRINGS AND A BRANCH, which is this repo's own count idiom (settings/Text.lua's
--- `centerNote`): the singular is its own locale value rather than a `%d` standing in for "1", so a
--- translation is free to give the two forms different shapes.
--- The claim line in `id`'s entry tooltip, or nil: which other categories claim it, BY NAME. The
--- suffix on the row says only that there are some; the tooltip is where the library says the full
--- story belongs, and it is the one place on this row with the width for names.
---
--- The names are `markedName`'s, so a category the player made still reads "(yours)" here exactly as
--- it does in every other list on this tab -- `Cat.LabelOf` stays THE labeling rule and this is not a
--- second copy of it (see `otherClaimants`).
local function overlapLine(def, id)
    local others = otherClaimants(def, id)
    if not others[1] then return nil end
    -- The join is a plain ", " for the same reason settings/Filters.lua's `categoryLabelList` gives:
    -- every label in it is already localized, only enUS ships, and if a second locale ever does it
    -- is the SEPARATOR that needs routing, never the labels.
    return L["Also in: %s"]:format(table.concat(others, ", "))
end

--- The IdList kind for this tab's spell list: the library's `"spell"` ids, with ONE thing added --
--- the claim line under the client's own spell tooltip on an entry (`overlapLine`).
---
--- A host kind with `base = "spell"` is the only hook there is: `O.IdList` builds an entry's tooltip
--- from the kind's `tooltip` and from nothing else (`entryTooltip`,
--- `libs/LibKa0s/OptionsWidgets.lua:2874-2886`), and a based kind takes the base's `info`, `link`,
--- `noun`, `plural` and name color, so the list draws exactly as it did.
---
--- `resolve` DELEGATES back to the library. A based kind does not inherit the client's name lookup
--- (`BASE_FIELDS`, `:471`), so without this line typing "Renewing Mist" into the add box would stop
--- resolving; handing the text to `O.ResolveId("spell", ...)` is the library's own documented way
--- back to the spellbook lookup and the shared-name check, rather than a second copy of either.
---
--- AND THE SUGGESTIONS COME WITH THE BASE. The library keys its client sources off its own kind
--- tables, but reads that table through `decorKind`, so a kind declaring `base = "spell"` wears the
--- spell row -- the spellbook, and the rank a shared name is checked against (`suggestRow`,
--- `libs/LibKa0s/OptionsWidgets.lua:866-871`). A spell that is in the spellbook and on no list of
--- this addon is therefore still offered as you type, as well as still resolving by name, by id or
--- by link. Under LibKa0s v1.49.0 that lookup was keyed by the kind TABLE ITSELF, a host table
--- joined no row, and this tab bought its tooltip at the price of its autocomplete; v1.49.1 is the
--- fix, and tests/test_pages_general_categories.lua pins both halves together.
local function spellKind(def)
    return {
        base = "spell",
        -- WARN BEFORE THE CLICK, not after it (LibKa0s v1.51.0). A suggestion row for an id that
        -- can never be an aura says so while the player is still choosing between it and the aura
        -- underneath it. Everything else modules/CastAura.lua does happens after the pick.
        suggestTag = NS.CastAura.SuggestTag,
        resolve = function(text, cands) return H.ResolveId("spell", text, cands) end,
        tooltip = function(tip, id)
            if type(tip.SetSpellByID) == "function" then tip:SetSpellByID(id) end
            local line = overlapLine(def, id)
            if line and type(tip.AddLine) == "function" then
                tip:AddLine(line, nil, nil, nil, true)
            end
        end,
    }
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
-- `enchantSlots.<slot>`. `skipRender = true`, exactly as the Filters section's category rows: this
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
---
--- UNDER A HEADING OF ITS OWN, and that is a fix rather than a decoration (owner, 2026-09-21). This
--- is drawn AFTER `renderManage`, and a heading owns everything drawn beneath it until the next one
--- -- so the lead-in and the three checkboxes landed under "Make a new category" and read as part of
--- the create form. Every other block of this tab already names itself ("Make a new category",
--- "Spells in this category"); this one now does too, and the order of the calls is left
--- alone, because the block ABOVE the slots is the same block that sits above every other category's
--- spell list and belongs in the same place on both.
local function renderEnchant(ctx)
    local scroll = H.EnsureScroll(ctx)
    if scroll then H.AddSpacer(scroll, SECTION_GAP) end
    H.Section(ctx, L["Weapon slots"])
    H.TextRow(ctx, L["Which weapon slots your temporary enchants are read from, shared by every container. Whether a container shows them at all is that container's own Filters -> Categories row."])
    H.TextRow(ctx, L["Untick every slot here and all three are read anyway — to show no enchants at all, set Weapon enchants to Hide on that container's Filters -> Categories tab instead."])
    local rows = {}
    for i, row in ipairs(ENCHANT_ROWS) do rows[i] = forRender(row) end
    H.RenderRows(ctx, rows, nil, nil, { noHeadings = true })
end

--- The Spell Categories tab: the category dropdown, then either the ID list over the chosen
--- category's spells, or (Weapon enchants) the slot toggles.
local function renderSpells(ctx)
    endVisit(ctx)
    local defs = spellCategories()
    local def = currentCategory(defs)
    local key = def.key
    if def.kind == "enchant" then
        -- ITS OWN LEAD-IN, because this was the one entry whose picker had none: both spell-list
        -- branches below say what the list under the dropdown is, and choosing Weapon enchants
        -- replaced that sentence with nothing at all. It says the one thing that makes the rest of
        -- the tab read correctly here -- there is no spell list, so there is nothing to add to or
        -- take out of -- and leaves the slots to their own block.
        H.TextRow(ctx, L["Weapon enchants matches the temporary enchants on your weapons rather than a list of spells, so there is nothing to add or remove here. The weapon slots it reads are below."])
        H.RenderGrid(ctx, { categoryCell(defs, def, true) })
        renderManage(ctx, def)
        return renderEnchant(ctx)
    end
    -- A category the player made has no starter list, so neither sentence nor button may promise one
    -- (the note above `restoreStarters`): the lead-in drops the Restore clause and the picker line
    -- drops the button, leaving the dropdown the whole width of that line.
    if Cat.IsUserCategory(def) then
        H.TextRow(ctx, L["The spells this category matches, shared by every container. Click X to leave one out, or add your own. Blizzard only honors spell lists for buffs on friendly units and debuffs on hostile ones."])
        H.RenderGrid(ctx, { categoryCell(defs, def, true) })
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
    -- `:565-571`), so `H.SECTION_TOP_SPACER` does not exist and reading it would silently be nil.
    -- Matching the number is the honest way to match the look; if the library ever republishes it,
    -- this is the line that takes it.
    local gridScroll = H.EnsureScroll(ctx)
    if gridScroll then H.AddSpacer(gridScroll, SECTION_GAP) end
    H.Section(ctx, L["Spells in this category"])
    H.IdList(ctx, {
        kind       = spellKind(def),
        removeStyle = "icon",
        -- TWO COLUMNS, FILLED ROW-MAJOR (1 2 / 3 4). Owner, 2026-09-20: one entry per row ran very
        -- long for a 60-id category -- Hard CC alone is most of a screen of scrolling before the
        -- next control. `columns` is LibKa0s v1.47.0's O.IdList option (OptionsWidgets minor 24,
        -- `libs/LibKa0s/OptionsWidgets.lua:3344-3354`): the count is floored and clamped into
        -- 1..ID_COLUMNS_MAX, which the library pins at 2 (`:1953`), so two is the whole of what it
        -- offers rather than a taste. Each entry's relative width is divided by the count, so a
        -- pair still sums to the width one entry held alone. Row-major is the library's packing
        -- order, which is why the by-name sort above reads left-to-right then down, not down one
        -- column and back up the next.
        --
        -- THE TRADE WE TOOK. At more than one column the library turns word wrap OFF on an entry's
        -- label, because a name that wrapped to two lines would push the column beside it down and
        -- break the grid (`entryNoWrap`, `:2800-2808`). The client then truncates the TAIL, and the
        -- gray `(id)` and the `(also in N)` suffix sit at the tail -- so a long spell name in a
        -- narrow panel loses its suffix first, then its id, then the end of its own name. Hovering
        -- the row still names the spell AND names the categories. docs/settings-panel.md says this
        -- where it describes the Spell Categories tab.
        --
        -- AND IT DOES NOT ALWAYS FIT, at the narrowest width this list is drawn at. The label is
        -- `0.43` of the content width in the icon style at two columns and an entry spends 16px of
        -- it on its icon (`entryNameRel` and `ID_ICON_SIZE`, `libs/LibKa0s/OptionsWidgets.lua`), and
        -- the floor for THIS list is the icon style's 520px content, not the default style's 584px
        -- (the table in `docs/api/Options/version-23.24.3.7.3-docs.md` of the LibKa0s repo). So the
        -- real budget is `0.43 * 520 - 16 = 207.6px` -- an earlier note here computed 235px against
        -- the wrong floor and overstated it by 28px. At the LIBRARY's rule-of-thumb 4.5px a
        -- character (its figure, stated as a rule of thumb; nothing in this repo measures a font)
        -- that is about 46 characters for the name, the id and the suffix together, while a long
        -- row such as `Ancestral Protection Totem (207399) (also in 1)` is 47 with the spaces. It
        -- overruns the floor by about a character, and what goes is the SUFFIX -- the library's
        -- documented truncation order, and acceptable, because the tooltip still carries
        -- every name. A panel wider than the floor buys it back at about 8 characters per 100px.
        --
        -- The Filters section's Overrides lists ask for two as well, since 2026-09-21. They are
        -- SHORT lists -- a handful of ids per container against this one's sixty -- so that is a
        -- consistency call rather than a scroll-length one, and settings/Filters.lua says so at
        -- its own call.
        columns    = 2,
        label      = L["Add a spell"],
        tooltip    = ID_TOOLTIP,
        strings    = ID_STRINGS,
        candidates = candidates,
        -- The entries, each marked with HOW MANY other categories also claim it (checkpoint 7's
        -- guardrail); the names are in the entry's tooltip, through `spellKind`. The suffix is
        -- computed per draw rather than stored: it is a statement about the other lists, and those
        -- change under this one -- from this very tab, and from another category's Restore.
        entries    = function()
            local out = entriesFor(def)
            for _, e in ipairs(out) do
                -- EVERYTHING THIS ROW HAS TO SAY GOES IN ITS "?" MARK (LibKa0s v1.51.0). It used
                -- to be split: an `(also in N)` suffix inline, and a `note` for an id that can
                -- never match -- and a note is a full-width second line, so the library gave such
                -- an entry a row of its own and every warned id punched a hole through the
                -- two-column grid. The mark costs a fixed 18px, says both, and leaves every row
                -- the same shape as every other. The count is gone from the row with the suffix:
                -- the mark is where a reader now looks, and the names were always in the tooltip.
                -- AND THE MARK IS COLORED BY WHICH OF THE TWO IT IS SAYING (owner, 2026-09-22):
                -- red for an entry that can never match, yellow for one another category also
                -- claims, and the library's dim for an entry with neither. CA.Help decides
                -- between them, because the precedence is its own ordering rule and not this
                -- page's; all this call does is name the severity of the line IT adds.
                e.help = CA.Help(e.id, overlapLine(def, e.id), CA.HELP_WARN)
            end
            return out
        end,
        -- Adding a starter back includes it again (drops its `false`); anything else is an addition.
        onAdd = function(id)
            -- THE AURA'S ID, NOT THE CAST'S, WHERE THE DATA KNOWS ONE (issue #15). CA.ForAdd
            -- answers the id to actually store and the line owed to the player; it rewrites only
            -- what a real trigger edge resolved, and for everything else hands back exactly what
            -- was typed. It never refuses -- a boss aura the generator never heard of has to be
            -- enterable, and silence about an id is not evidence against it.
            local stored, line = CA.ForAdd(id)
            id = stored
            editCategory(key, function(mine)
                if def.spells and def.spells[id] then mine[id] = nil else mine[id] = true end
            end)
            if line then NS.Print(line) end
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

local TABS = {
    -- Ahead of Dispel Colors (settings/GeneralDispel.lua's tab): every schema group's tab is
    -- collected before any bespoke one.
    { key = SPELLS, label = SPELLS, render = renderSpells, before = DISPEL },
}

-- `candidates`, `ID_STRINGS` and `ID_TOOLTIP` are shared with the Filters section's Overrides lists,
-- which suggest and resolve a typed name the same way.
-- `MarkedName` is the ONE definition of the 'yours' marker, read by settings/Filters.lua's Categories
-- grid; `RestoreStarters` is the restore ACT, published so that it is testable and so that any
-- future caller meets the refusal the button's absence only implies.
-- `BULLET` and `BULLET_GAP` are published once here and read by settings/GeneralDispel.lua's
-- lead-in and bullets rather than copied there.
NS.GeneralSpells = {
    ENCHANT_ROWS = ENCHANT_ROWS, TABS = TABS, BULLET = BULLET, BULLET_GAP = BULLET_GAP,
    candidates = candidates, ID_STRINGS = ID_STRINGS, ID_TOOLTIP = ID_TOOLTIP,
    MarkedName = markedName, RestoreStarters = restoreStarters,
}

--- Point this tab at one category. For the Filters section's per-row link (settings/Filters.lua, B5).
--- A key this tab cannot draw is ignored rather than stored: a stale link must never leave the tab
--- on a category with no editor. Moves the General page's active tab to Spell Categories too, so the
--- link actually lands the player where the category is shown.
function NS.GeneralSpells.Select(key)
    local def = Cat.Find("HELPFUL", key) or Cat.Find("HARMFUL", key)
    if not editableHere(def) then return end
    UC.SetSelected(key)
    local ctx = H.__pageCtx and H.__pageCtx.general
    if ctx then ctx.activeTab = SPELLS end
    rerender()
end
