-- tests/general_page_helpers.lua — the General page readers both General-page suites share.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Loaded with dofile
-- by tests/test_pages_general.lua and tests/test_pages_general_categories.lua (issue #19), so the
-- two suites open the page, read the Spell Categories list and spy on its writes the same way
-- instead of each keeping a copy.

local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

--- A fresh environment with the General page drawn; `tab(name)` clicks a tab and answers what that
--- render drew.
local function general(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    local ws = P.show("General")
    local function tab(name) return P.tab("general", name) end
    return NS, m, P, ws, tab
end

--- Whether widget `w` hangs, at any depth, off the General page's scroll: drawn in the tab body,
--- and not in a chrome block above the strip.
local function inScroll(NS, w)
    local function walk(node)
        for _, c in ipairs(node.children or {}) do
            if c == w or walk(c) then return true end
        end
        return false
    end
    return walk(NS.Helpers.EnsureScroll(NS.Helpers.__pageCtx.general))
end

--- Count ContainerManager.RequestApply calls from here on, by the id each one named.
local function spyApply(NS)
    local calls = {}
    local real = NS.ContainerManager.RequestApply
    NS.ContainerManager.RequestApply = function(id, ...)
        local tag = id == nil and "all" or id
        calls[#calls + 1] = tag
        return real(id, ...)
    end
    return calls
end

--- The General page on its Spell Categories tab.
local function spells(opts)
    local NS, m, P, _, tab = general(opts)
    return NS, m, P, tab(NS.L["Spell Categories"])
end

--- The muted markers the panel colors with (settings/GeneralSpells.lua's TYPE_COLORS and
--- YOURS_COLOR). Restated here as literals on purpose: the panel's own constants are file-local, so
--- these are what say a color CHANGED, and the register they were picked from -- the drag handle's
--- gold (1, 0.82, 0) and its help mark (0.7, 0.7, 0.72) -- is written above the constants there.
local TYPE_COLOR = { HELPFUL = "|cff73bf80", HARMFUL = "|cffcc7373" }
local YOURS_COLOR = "|cffd9b861"

--- `text` with every color escape taken out: what the client actually DRAWS. `|cAARRGGBB` and `|r`
--- are read by the client and rendered as nothing at all, so this is the string a player's eye
--- measures -- which is what the padding case asserts the name column against.
local function rendered(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

--- The Category dropdown's label for `key`, built the way the panel builds it: the aura type's own
--- `C.AURA_TYPE_LABELS` word in its bracket, colored, then padding out to the widest such word, then
--- the category's name (settings/GeneralSpells.lua's `categoryLabel`, issue #10 checkpoint 1 and the
--- owner's colors of 2026-09-21). Built here out of the SAME locale strings rather than hard-coded,
--- so a case asserting it asserts the composition and never re-states the wording -- which is also
--- why it is NOT the only thing the marker cases rest on: this helper takes the aura type from the
--- accessor under test, so the suites' cases anchor the type itself to the literal label and to the
--- list the category is declared in.
---
--- THE PADDING IS MEASURED ON THE BARE WORD HERE TOO, which is the whole point: a helper that padded
--- the colored mark would agree with a panel that did the same, and both would be wrong by twelve
--- characters the player cannot see. `rendered` above is the second, independent check.
local function marked(NS, key, auraType)
    auraType = auraType or NS.Categories.AuraTypeOf(key)
    local def = NS.Categories.Find(auraType, key)
    -- Byte length is character length here: the locale guard already holds enUS to ASCII.
    local widest = 0
    for _, word in pairs(NS.Constants.AURA_TYPE_LABELS) do
        local n = #NS.L[word]
        widest = math.max(widest, n)
    end
    local word = NS.L[NS.Constants.AURA_TYPE_LABELS[auraType]]
    local pad = (" "):rep(widest - #word)
    -- A category the player made carries the ownership marker too, in muted gold, and it is a SUFFIX
    -- on the name rather than a second prefix, so the padding above still starts every name at one
    -- offset.
    local name = NS.Categories.LabelOf(def)
    if NS.Categories.IsUserCategory(def) then
        name = (NS.L["{name} {mark}"]
            :gsub("{mark}", function() return YOURS_COLOR .. NS.L["(yours)"] .. "|r" end)
            :gsub("{name}", function() return name end))
    end
    local mark = TYPE_COLOR[auraType] .. (NS.L["[{type}]"]:gsub("{type}", function() return word end)) .. "|r"
    return (NS.L["{mark} {name}"]
        :gsub("{mark}", function() return mark end)
        :gsub("{name}", function() return pad .. name end))
end

--- `key`'s name as the panel writes it in a list of categories: the 'yours' marker, no aura type.
--- `NS.GeneralSpells.MarkedName` is the panel's ONE definition of that, so the claimed-by cases read
--- it rather than composing a second one.
local function ownedName(NS, key)
    local def = NS.Categories.Find("HELPFUL", key) or NS.Categories.Find("HARMFUL", key)
    return NS.GeneralSpells.MarkedName(def)
end

--- Every entry the IdList drew, in DRAW ORDER, as { id =, label =, x =, row =, col = }.
---
--- The walk is per CHILD, not per row, because the spell-category list asks for `columns = 2`
--- (settings/GeneralSpells.lua's H.IdList call, LibKa0s v1.47.0): two entries share one Flow row,
--- so a row's children run X, label, X, label and a helper that read `w.children[2]` alone would
--- see the left column and call the right one absent. `row` is that row's index among the widgets
--- handed in and `col` the entry's position inside it, 1-based -- which is what lets a test assert
--- ROW-MAJOR placement (1 2 / 3 4) rather than only the flat sequence.
---
--- A named entry reads "<name> (<id>)", an unnamed one "Unknown spell <id>" (the library's
--- entryLabel); the X is the Icon immediately before the label (`removeStyle = "icon"`, B2).
---
--- NEITHER MATCH IS ANCHORED AT THE END any more: since LibKa0s v1.49.0 an entry may carry a
--- `suffix` drawn inside the same label after the id ("(also in 1)", settings/GeneralSpells.lua's
--- overlap guardrail), so the id is no longer the last thing in the string. The first
--- "(<digits>)|r" in the label is the id; the count in a suffix never wears parentheses of its own.
local function drawnEntries(ws)
    local out = {}
    for r, w in ipairs(ws) do
        local kids, col = w.children, 0
        if type(kids) ~= "table" then kids = {} end
        local n = #kids
        for i = 1, n do
            local lbl = kids[i]
            if type(lbl) == "table" and lbl.type == "InteractiveLabel" then
                local t = lbl.text or ""
                local id = t:match("%((%d+)%)|r") or t:match("^Unknown spell (%d+)")
                if id then
                    local prev = kids[i - 1]
                    col = col + 1
                    local at = #out + 1
                    out[at] = {
                        id = tonumber(id), label = lbl, row = r, col = col,
                        x = (type(prev) == "table" and prev.type == "Icon") and prev or nil,
                    }
                end
            end
        end
    end
    return out
end

--- The line an IdList drew for spell `id`: its label, and the X at its left.
local function entry(ws, id)
    for _, e in ipairs(drawnEntries(ws)) do
        if e.id == id then return e.label, e.x end
    end
    return nil
end

--- The lines an IdList entry's tooltip draws when the entry is hovered, joined. The claim line
--- ("Also in: ...") is added there by settings/GeneralSpells.lua's own kind table, under the
--- client's spell tooltip, which is where the NAMES live now that the row itself carries only a
--- count. Same idiom as tests/test_pages_general.lua's Reset-all tooltip case: capture the mocked
--- GameTooltip's AddLine.
local function entryTooltip(m, lbl)
    local lines = {}
    rawset(m.GameTooltip, "AddLine", function(_, s)
        lines[#lines + 1] = s
    end)
    lbl:__fire("OnEnter")
    return table.concat(lines, "\n")
end

--- The Icon carrying entry `id`'s "?" help mark, and whether that entry was drawn at all — which
--- entryHelp and entryHelpTint below both read, because the mark's LINES and its TINT are two
--- claims about one widget (the severity, 2026-09-22) and both have to walk the row the same way.
---
--- WALKED IN ORDER, because a Flow row holds TWO entries at two columns and each has its own mark.
--- The library draws [X] [?] [label] per entry, so the mark in force when a label is reached is the
--- one belonging to it -- picking "the first Icon in the row" would answer the left entry's mark
--- for the right entry's label. `__helpLines` is what the library records on the Icon (v1.51.0);
--- the kit's fake has no texture and no tooltip to hover, so it is the only way to read one.
local function entryMark(ws, id)
    for _, row in ipairs(ws) do
        local mark
        for _, kid in ipairs(row.children or {}) do
            if kid.type == "Icon" and kid.__helpTint then
                mark = kid
            elseif kid.type == "InteractiveLabel" and type(kid.text) == "string" then
                local drawn = kid.text:match("%((%d+)%)|r") or kid.text:match("^Unknown spell (%d+)")
                if drawn and tonumber(drawn) == id then
                    return mark, true
                end
            end
        end
    end
    return nil
end

--- The lines an entry's "?" help mark carries, joined; "" for a mark with nothing behind it, and
--- nil when the entry was not drawn at all.
local function entryHelp(ws, id)
    local mark, drawn = entryMark(ws, id)
    if not drawn then return nil end
    if not (mark and mark.__helpLines) then return "" end
    return table.concat(mark.__helpLines, "\n")
end

--- The color `id`'s mark was tinted, as a comparable string, or nil when it drew no mark.
---
--- COMPARED, NEVER SPELLED OUT. The library owns the numbers (ID_HELP_TINT and ID_HELP_DIM,
--- libs/LibKa0s/OptionsWidgets.lua:1956-1958, and the severity tints beside them), and a case that
--- restated them here would go red on a palette change that broke nothing. What the page promises
--- is that the three severities do not LOOK alike, so that is what is asserted.
local function entryHelpTint(ws, id)
    local mark = entryMark(ws, id)
    if not (mark and mark.__helpTint) then return nil end
    return table.concat(mark.__helpTint, ",")
end

--- Every id the IdList drew, in the order it drew them.
local function listedIds(ws)
    local out = {}
    for _, e in ipairs(drawnEntries(ws)) do
        local n = #out
        out[n + 1] = e.id
    end
    return out
end


local function starterIds(NS, key)
    local out = {}
    for id in pairs(NS.Categories.Find("HELPFUL", key).spells) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

--- Record every NS.SetByPath call's path from here on.
local function spyPaths(NS)
    local paths = {}
    local real = NS.SetByPath
    NS.SetByPath = function(path, ...)
        paths[#paths + 1] = path
        return real(path, ...)
    end
    return paths
end

return {
    general = general,
    inScroll = inScroll,
    spyApply = spyApply,
    spells = spells,
    TYPE_COLOR = TYPE_COLOR,
    YOURS_COLOR = YOURS_COLOR,
    rendered = rendered,
    marked = marked,
    ownedName = ownedName,
    drawnEntries = drawnEntries,
    entry = entry,
    entryTooltip = entryTooltip,
    entryMark = entryMark,
    entryHelp = entryHelp,
    entryHelpTint = entryHelpTint,
    listedIds = listedIds,
    starterIds = starterIds,
    spyPaths = spyPaths,
}
