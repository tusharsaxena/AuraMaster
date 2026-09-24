local _, NS = ...

-- settings/GeneralDispel.lua — General → Dispel Colors: one color per dispel type, shared by every
-- container (schema v2 made the set the profile's). Peeled whole out of settings/GeneralSpells.lua
-- (issue #16, layout-§1), with no change to what it draws or stores.
--
--     [ Master controls ][ Display ][ Spell Categories ][ Dispel Colors ]
--     Dispel Colors     the lead-in and its four bullets, then one swatch per dispel type,
--                       Magic … Bleed
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
-- This file registers nothing itself. settings/General.lua registers ROWS after the Spell
-- Categories tab's enchant rows, so Dispel Colors takes the last strip position, and draws TAB
-- beside settings/GeneralSpells.lua's. It loads after GeneralSpells.lua, whose published BULLET
-- and BULLET_GAP its bullets read (one definition, not a copy), and before General.lua.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local GS = NS.GeneralSpells

local PAGE = "general"
local DISPEL = L["Dispel Colors"]
local BULLET, BULLET_GAP = GS.BULLET, GS.BULLET_GAP

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

-- Keyed by its group, so it takes the group's place and is handed the group's rows.
NS.GeneralDispel = {
    ROWS = DISPEL_ROWS,
    TAB  = { key = DISPEL, label = DISPEL, render = renderDispel },
}
