local _, NS = ...

-- settings/GeneralUserCategories.lua — General → Spell Categories' own-category block: the rename
-- and Delete under the picker, the way out of a record the sync cannot read, and 'Make a new
-- category' (issue #10 checkpoints 6 and 7), plus the answer line every act of that block sets.
-- Peeled whole out of settings/GeneralSpells.lua along its 'Make a new category' seam (AM-ATS-03,
-- ATS-09: the file stood at 1480 lines, twenty under the cap). A move, not a rewrite: the tab still
-- draws in the same order, and settings/GeneralSpells.lua calls `Render` where it called
-- `renderManage`.
--
-- THIS FILE OWNS THE TAB'S SESSION STATE, because the answer line is stamped with it. `spellCategory`
-- (which category the tab edits) is read by `say` for the stamp and written by `doCreate`, which
-- selects the category it just made; settings/GeneralSpells.lua reads and moves it through
-- `Selected` / `SetSelected` (its `currentCategory` and `NS.GeneralSpells.Select`). One owner, so
-- the stamp and the selection can never be two copies of one fact.
--
-- It registers no SCHEMA ROWS -- only the StaticPopupDialogs entries of the delete confirmation and
-- the forget-unreadable confirmation -- and publishes `NS.GeneralUserCategories`. It loads directly
-- before settings/GeneralSpells.lua, which reads that table as an upvalue at file load.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local Cat = NS.Categories

-- The gap a subsection heading gets above it. Mirrors the library's own SECTION_TOP_SPACER, which
-- `H.Section` emits only for a schema-driven page; this tab is drawn by hand, so it supplies its
-- own. See the note at the `H.Section` call in settings/GeneralSpells.lua's `renderSpells` for why
-- the number is a literal. Published for that file, which draws two more such headings.
local SECTION_GAP = 10

local spellCategory   -- session: which category the tab edits (the first when unset)

-- THE 'THIS CATEGORY' BLOCK ANSWERS IN THE PANEL, NOT ONLY IN THE CHAT FRAME. Pressing Create with
-- an empty box used to re-render with nothing visibly changed and a line in chat: from the panel's
-- side, a button that does nothing. So every act of that block sets this line, and the block draws
-- it directly under its heading -- one `H.TextRow`, which is the same grammar the Filters section
-- states its own conditions in and the same one this tab's shipped-category sentence already uses.
-- No new widget kind, and nothing to dismiss.
--
-- THE LINE'S LIFETIME IS THE STATE IT WAS SAID IN, AND THE DRAW ENFORCES IT (owner, 2026-09-21).
-- One thing used to clear it -- the Category dropdown's own OnValueChanged -- so it outlived a panel
-- close and reopen, a move to another settings page and a PROFILE SWITCH: a player could open the
-- panel and be told about an act they ran ten minutes ago, in a profile they had since left. The
-- line is now STAMPED with what it is about, and `settleNotice` drops it on the first draw that
-- does not match. Three things scope it:
--
--   * THE PROFILE it was said in. A switch replaces every category, list and container decision the
--     sentence names, so the sentence is about a store that is no longer loaded.
--   * THE CATEGORY it was about. "Deleted 'X'" left standing over another category's controls reads
--     as a statement about THAT one. A delete stamps no key at all -- the category it names is gone
--     -- and the next draw adopts its own, because that draw is the one the sentence explains.
--   * THE VISIT. The page leaving the screen ends it: `endVisit` hooks the panel's own OnHide. The
--     clear alone is not enough there, because a hidden page is NOT re-rendered on its next show
--     unless something marked it dirty (libs/LibKa0s/Options.lua's SetRenderer), so the stale line
--     would still be hanging there in pixels when the panel came back -- hence the structural
--     refresh beside it.
--
-- What it deliberately does NOT clear on is a hop to another TAB of this page and back: the panel
-- never leaves the screen, the profile and the category are the ones the line is about, and it is
-- still the last thing the player did here. The three moves above are the ones that turn it into a
-- statement about something else.
--
-- SESSION STATE, LIKE `spellCategory` AND `newName`: it means nothing outside an open panel.
local notice
local noticeState   -- { profile = <name>, key = <category key, or nil until a draw adopts one> }

--- Re-render on the next frame: the dropdown or button whose callback asked is still on the stack.
local function rerender()
    if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end
end

--- The profile the panel is looking at, for the answer line's stamp. `"?"` before there is a store
--- (the headless harness, and every render before ADDON_LOADED), which is one state and never two
--- different profiles wearing one name.
local function profileName()
    return (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?"
end

--- The block's answer to the act just run: in the panel, and in chat as well. Chat stays because it
--- is this addon's act log -- the Containers page's acts print theirs there too, and a player who
--- looked away still finds the line. `nil` clears the panel's line and prints nothing.
---
--- `key` is the category the line is ABOUT and defaults to the selected one. Pass `false` from an
--- act that leaves no category to point at -- the delete -- and the next draw adopts the category it
--- shows in its place.
local function say(text, key)
    if key == nil then key = spellCategory end
    notice = text
    noticeState = text and { profile = profileName(), key = key or nil } or nil
    if text then NS.Print(text) end
end

--- Drop the answer line unless the draw about to happen is the one it was said for: same profile,
--- same category. Called by the block before it draws anything, so a line can never be drawn over a
--- state it was not about.
local function settleNotice(def)
    if not notice then return end
    local st = noticeState
    if not st or st.profile ~= profileName() then
        notice, noticeState = nil, nil
        return
    end
    -- A delete's line adopts the category drawn in place of the one it names, and dies with THAT.
    if st.key == nil then st.key = def.key end
    if st.key ~= def.key then notice, noticeState = nil, nil end
end

-- One entry per page context, and this tab is drawn on exactly one, so the table holds one key. It
-- is keyed by the ctx rather than a flag written onto it: the page context is the library's table,
-- not ours to grow a field on.
local visitHooked = {}

--- End the answer line when this page goes off screen -- the settings window closing, or another
--- page being opened. Hooked once per page context, on the panel's own OnHide.
local function endVisit(ctx)
    if type(ctx) ~= "table" or visitHooked[ctx] then return end
    local panel = ctx.panel
    if type(panel) ~= "table" or type(panel.HookScript) ~= "function" then return end
    visitHooked[ctx] = true
    panel:HookScript("OnHide", function()
        if not notice then return end
        notice, noticeState = nil, nil
        -- STRUCTURAL, because the line is a row of the block and not a widget value: a hidden page
        -- takes this as "dirty" and draws again on its next show, which is the only thing that
        -- takes the sentence off the screen it is still sitting on.
        if H.RefreshPanel then H.RefreshPanel(ctx, true) end
    end)
end

-- ---------------------------------------------------------------------------
-- Rename, delete, and the shipped lock; then Make a new category (checkpoint 6)
-- ---------------------------------------------------------------------------
--
--     [ Category v ]                    [ Restore this category's starter list ]
--     -- a category the player made; one of Aura Master's own draws nothing here --
--     [ Rename this category ____ ]     [ Delete this category ]
--     -- whatever the last act of this block answered, when there was one --
--     "Renamed 'Frist draft' to 'First draft'. To undo it, type 'Frist draft' back into the box."
--     -- only while the profile holds a record the sync cannot read --
--     "Aura Master cannot read 1 of this profile's saved categories..."
--     [ Forget unreadable categories ]
--     ---- Make a new category ------------------------------------------------
--     [ New category's name _____ ]     [ Create category ]
--     [ Aura type v ]
--     ---- Spells in this category -------------------------------------------
--
-- THE LAYOUT, JUSTIFIED. The owner asked for simple and obvious, so this adds FOUR controls and no
-- new shape: every one of them is a plain AceGUI widget in an `H.RenderGrid` pair, which is the
-- grammar the picker line above it and the Filters section's own act rows already use. There is no new
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
--   * IT HAS NO HEADING OF ITS OWN (owner, 2026-09-21). It carried one -- "This category" -- and a
--     heading between the dropdown and the two controls that act on what the dropdown is showing
--     separated things that belong together. The blocks that follow still name themselves, so the
--     tab reads: picker, what you can do to it, "Make a new category", "Spells in this category".
--   * THE SHIPPED CASE DRAWS NOTHING AT ALL, neither disabled controls nor a sentence. Grayed-out
--     controls on twelve of the fourteen categories would be a panel mostly made of things that do
--     not work; the sentence that stood there instead said the name and the aura type are fixed and
--     the spell list is still the player's, and the owner asked for it gone (2026-09-21) because
--     the lead-in above the picker already describes the list in the words its own controls use.
--     So a shipped category goes picker -> create form -> list, with nothing in between.
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
        local ok, why, failed = Cat.DeleteUserCategory(data)
        if not ok then return say(why) end
        -- A PARTIAL SWEEP IS SAID OUT LOUD. The act is deliberately recoverable rather than atomic
        -- (defaults/UserCategories.lua's sweepUserKey), so a stored profile whose table is malformed
        -- costs only its own leaves -- but "deleted" then means slightly less than it says, and
        -- before this the difference reached NS.Debug and nothing else. It is never a failure of the
        -- delete, so the line still leads with what went; what is left is inert and named as such.
        --
        -- `false` is the key this line is about: the category it names no longer exists, so the
        -- stamp adopts whatever the next draw shows in its place (see `say`).
        if failed and failed > 0 then
            local partial = failed == 1
                and L["Deleted '%s'. One saved profile could not be tidied up: it may still hold this category's spell list and Show or Hide, which nothing reads."]
                or L["Deleted '%s'. %d saved profiles could not be tidied up: they may still hold this category's spell list and Show or Hide, which nothing reads."]
            say(partial:format(name, failed), false)
        else
            say(L["Deleted '%s'. This tab is showing another category now."]:format(name), false)
        end
        reapplyAll()
        H.RefreshAllPanels()
    end,
}

--- The picked category's Delete, for a category the player made. Cell-filling, like Restore on the picker
--- line (settings/GeneralSpells.lua's `restoreCell`).
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
--
-- ITS SENTENCE IS PICKED AT THE SHOW, because ONE is the ordinary count and "Forget the 1 saved
-- categories" is not a sentence (owner, 2026-09-21). This repo's way with a count-dependent string
-- is two whole strings and a branch, never a stitched-together fragment -- settings/Text.lua's
-- `centerNote` is the standing example -- and a StaticPopup holds exactly one `text`, so the branch
-- writes the one it needs onto the dialog a line before showing it. The singular says no number at
-- all: the block that opened it has just said how many there are.
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
        say(gone == 1 and L["Forgot 1 unreadable saved category."]
            or L["Forgot %d unreadable saved categories."]:format(gone))
        reapplyAll()
        H.RefreshAllPanels()
    end,
}

--- The unreadable-records line and its button, or nothing at all when the profile has none.
local function renderBroken(ctx)
    local bad = Cat.UnusableUserRecords(NS.db and NS.db.profile)
    local count = #bad
    if count == 0 then return end
    -- One is the common count, and the plural-only sentence read as broken English at exactly the
    -- moment a player met it. Two strings and a branch, this repo's own idiom for a count-dependent
    -- line (settings/Text.lua's centerNote); the singular carries the "1" as a literal, as that one
    -- does, so a translator is handed a whole sentence rather than a number to agree with.
    H.TextRow(ctx, count == 1
        and L["Aura Master cannot read 1 of this profile's saved categories, so it is in no list and nothing is using it. It cannot be repaired from here, but you can be rid of it."]
        or L["Aura Master cannot read %d of this profile's saved categories, so they are in no list and nothing is using them. They cannot be repaired from here, but you can be rid of them."]
        :format(count))
    H.RenderGrid(ctx, { { make = function(_, parent)
        local btn = NS.AceGUI:Create("Button")
        btn:SetText(L["Forget unreadable categories"])
        btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
        btn:SetCallback("OnClick", function()
            StaticPopupDialogs["AURAMASTER_FORGET_BROKEN_CATEGORIES"].text = count == 1
                and L["Forget the saved category Aura Master cannot read? It is in no list and cannot be repaired from here, and whatever it held is discarded. Your other categories are not affected."]
                or L["Forget the %d saved categories Aura Master cannot read? They are in no list and cannot be repaired from here, and whatever they held is discarded. Your other categories are not affected."]
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
    -- THE SELECTION MOVES FIRST, and the answer line's stamp is why it is written here rather than
    -- below: `say` stamps the line with whatever category is selected, and a line about a category
    -- just made has to be stamped with THAT one or the very next draw drops it as a line about
    -- something else. The box is still cleared after the branch below, which reads it.
    spellCategory = key
    if Cat.UserCategoryNameTaken(NS.db.profile, newName, key) then
        -- INFORMS, DOES NOT REFUSE (the ledger): the key is identity, so two categories with one
        -- name are two categories. The line is for the player who typed the same name twice by
        -- accident and would otherwise wonder which of the two the dropdown is showing them.
        say(L["There is already a category called '%s'. Both were kept — they are separate categories with separate spell lists."]:format(clean))
    else
        say(L["Created '%s', empty. Add spells to it below, then set it to Show or Hide on each container's Filters -> Categories tab."]:format(clean))
    end
    newName = ""
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

--- The picked category's own controls -- the rename and the Delete, for a category the player made
--- -- then the answer line, the way out of an unreadable record, and the create form under a
--- heading of its own. Drawn for the enchant row too: creating a category is not a thing only the
--- spell-list tabs may do.
---
--- NO HEADING, AND NOTHING AT ALL FOR ONE OF AURA MASTER'S OWN (owner, 2026-09-21, from the live
--- panel). It had a "This category" heading over a body that, on twelve of the fourteen entries,
--- was one sentence saying the category is Aura Master's. The owner wants neither: no heading, no
--- sentence. So this block now draws for a SHIPPED category exactly what it has to say about it,
--- which is nothing, and the tab goes picker -> create form -> spell list.
---
---   * THE SENTENCE IS GONE, BOTH OF ITS TWO FORMS, and nothing is lost that the tab does not
---     already say. The lock it described is still enforced by `Cat.RenameUserCategory` and
---     `Cat.DeleteUserCategory` and was never drawn from here; what the sentence ADDED was that the
---     spell list is still the player's, which the lead-in above the picker says in the words the
---     controls use ("Click X to leave one out, or add your own; Restore brings the starter list
---     back"), and, on the enchant entry, that there is no spell list at all -- which that branch's
---     own lead-in says in full before the picker is even drawn.
---   * THE HEADING IS GONE FOR A CATEGORY THE PLAYER MADE TOO, and the rename and the Delete move
---     up against the dropdown. They are about WHICH category is picked, which is the dropdown's
---     own subject, so under it with nothing in between is where they belong: picker, then the two
---     things you can do to what it is showing. A heading between a control and the two controls
---     that act on it was a landmark separating things that belong together.
---   * WHAT KEEPS IT READING AS BLOCKS rather than a run-on is the gap below, not a heading above:
---     the picker and its two acts are consecutive grid rows and read as one block, and SECTION_GAP
---     plus "Make a new category" closes it off -- the same gap that already separates the create
---     form from "Spells in this category". For a shipped category the block collapses to nothing
---     and the gap lands directly under the picker line, which is one gap and not two.
---
--- THE ANSWER LINE OUTLIVES THE HEADING IT USED TO SIT UNDER. It is the block's answer to the act
--- just run -- a refusal, a rename's undo, a create's next step -- and it is drawn under whatever
--- the block drew, so it reads as the answer to the control above it. On a shipped category it is
--- the only thing this block ever draws.
---
--- IT SETTLES THE ANSWER LINE BEFORE IT DRAWS ANYTHING (`settleNotice`), so the line can never be
--- drawn over a profile or a category it was not said about. The rule and its three scopes are
--- written above `notice`.
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
    settleNotice(def)
    local scroll = H.EnsureScroll(ctx)
    -- Directly under the picker, under no heading, and only for a category the player made: a
    -- shipped one draws nothing here at all.
    if Cat.IsUserCategory(def) then
        H.RenderGrid(ctx, { nameCell(def), deleteCell(def) })
    end
    if notice then H.TextRow(ctx, notice) end
    renderBroken(ctx)
    if scroll then H.AddSpacer(scroll, SECTION_GAP) end
    H.Section(ctx, L["Make a new category"])
    -- NAME AND CREATE ON ONE LINE, AURA TYPE UNDER THEM (owner, from the live panel, 2026-09-22).
    -- It pairs the box with the button that consumes it, the way Rename pairs with Delete above,
    -- and it leaves Aura type on its own line where a dropdown reads as a setting rather than as
    -- the second half of a form.
    --
    -- IT DOES PUT THE SUBMIT ABOVE AN INPUT, which is the one thing to know about this order: a
    -- player who reads strictly top to bottom meets Create before Aura type. That is survivable
    -- because the type has a value from the moment the block draws -- it defaults to Buffs and
    -- cannot be empty -- so pressing Create without having looked at it creates a buff category
    -- rather than failing. The name is the only field that can be empty, and it is the one on the
    -- button's own line.
    H.RenderGrid(ctx, { newNameCell(), createCell() })
    H.RenderGrid(ctx, { newTypeCell() })
end

-- `Render` is the block (settings/GeneralSpells.lua's `renderSpells` calls it between the picker and
-- the list), `EndVisit` the answer line's OnHide hook, `Rerender` the next-frame refresh, `Say` the
-- answer line itself (the picker line's Restore answers through it too), and
-- `Selected` / `SetSelected` the tab's one selection (see the header).
NS.GeneralUserCategories = {
    SECTION_GAP = SECTION_GAP,
    Render = renderManage, EndVisit = endVisit, Rerender = rerender, Say = say,
    Selected = function() return spellCategory end,
    SetSelected = function(key) spellCategory = key end,
}
