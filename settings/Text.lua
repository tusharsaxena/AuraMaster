local _, NS = ...

-- settings/Text.lua — how a container drawn as TEXT looks (modules/Style_Text.lua draws it; the
-- template language is modules/TextTemplate.lua's).
--
--     band   [Container ▾]
--     [ General ][ Font ][ Icon ][ Pandemic ][ Animation ]
--     General   Size (Size to fit, then Width and Height, dimmed under a note while it is on),
--               then -- Text Template --: [Template ▾] (a built-in, or Custom), the Custom
--               template box (Custom only), a read-only Preview EditBox (the line on a sample aura,
--               PrettyChat's shape), the Tokens/Rules cheat sheet; then Placement and the centering
--               note
--     Font      Font, Countdown, then Dispel type (feedback #7: the word's color, a backdrop, an
--               edge, each opt-in and off; moved here from Animation, smoke batch 2 item 5)
--     Icon      Icon (position, size, gap, zoom), Icon border; every row but the position (and the
--               border swatch) dims while the position is None, under a note
--     Pandemic  Time color (the duration tokens' color and blink in the pandemic window, once
--               "Running out" on Animation; smoke batch 2, B2-1) and its note
--     Animation Loop
--
-- General is drawn bespoke (its `tabs` entry below) to put the built-in picker, the preview and two
-- read-only blocks between its rows: the token cheat sheet, and the centering note under Placement.
-- Its rows are still ordinary schema rows, drawn by the flow engine, so the panel, `/am set`, the
-- Defaults button and the resets all reach them through the one write seam. The Template dropdown is
-- not a row: it writes the template (and, for the centered built-in, Justify) through that seam
-- (feedback #5).
--
-- The Template row's `validate` is the parser (TT.Validate): a refused template is never stored, and
-- the refusal's reason reaches the player through the write seam's third return (settings/Schema.lua)
-- -- printed under "Invalid value for container.text.template" by the panel and by `/am set` alike.
--
-- A container drawn as bars or icons sees every row here disabled, under a note naming where its
-- style is changed (settings/OptionsSetup.lua's mutedNotice). The read-only TEXT between the
-- rows dims with them: the Placement notes are gray at all times, and the Text Template block's
-- Preview line and cheat sheet are grayed for that render (`dim`/`token`), so nothing on an inert
-- tab reads brighter than the controls it describes. The font and icon-border blocks
-- are composed (options-ui-§16) with class-color companions (options-ui-§17) resolved to the tracked unit's
-- class, as on the Bars page; the pandemic-window time swatch is a palette color and carries none.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local TT = NS.TextTemplate
local D = NS.CONTAINER_TEMPLATE.text

local PAGE = "text"
local P = "container.text."
local UNIT = { source = "unit" }

local G_GENERAL, G_FONT, G_ICON, G_ANIM = L["General"], L["Font"], L["Icon"], L["Animation"]
local G_PANDEMIC, S_TIME = L["Pandemic"], L["Time color"]
local S_PLACEMENT, S_DISPEL = L["Placement"], L["Dispel type"]
local SMALL = { fontObject = "GameFontHighlightSmall" }
local HEADING = { fontObject = "GameFontNormalSmall" }
local GRAY = "|cff808080%s|r"
local GOLD = "|cffffd100%s|r"
local BULLET = "- "
local CUSTOM = "custom"

-- Which containers have Custom chosen in the Template dropdown this session, by id. Page state, not a
-- setting: a stored template matching no built-in reads as Custom on its own; this keeps the box open
-- for one that matches a built-in once the player asked to edit it.
local customOpen = {}

-- A write that changes what the General tab draws (the box, the preview, the centering note) redraws
-- it, on the next frame, out of the widget's own callback.
local function structural() if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end end

--- The selected container's text block (empty with no container).
local function textBlock()
    local c = NS.ActiveContainer()
    return c and c.text or {}
end

--- A `disabledIf` predicate: the row is dimmed unless the selected container's loop effect is one
--- of `...`.
local function unlessAnim(...)
    local wanted = {}
    for _, v in ipairs({ ... }) do wanted[v] = true end
    return function() return not wanted[textBlock().anim or D.anim] end
end

--- A `disabledIf` predicate: the pandemic-window rows need a duration token in the template (the blink
--- and the color ride the duration run's text).
local function noDuration()
    return not TT.ForDraw(textBlock().template).hasDuration
end

--- A `disabledIf` predicate: Color the dispel type needs a $dispeltype$ token to color (feedback #7).
local function noDispel()
    return not TT.ForDraw(textBlock().template).hasDispel
end

--- A `disabledIf` predicate: the Icon tab's rows draw nothing while Icon position is None (smoke
--- batch 2, item 6: the icon and its border draw only on Left or Right).
local function noIcon()
    return (textBlock().icon or D.icon) == "NONE"
end

--- A `disabledIf` predicate: Width and Height dim while Size to fit is on (batch 8, AS-1); they stay
--- stored, and stand whenever the size cannot be measured.
local function sizedToFit()
    return textBlock().autoSize == true
end

--- A `disabledIf` predicate: the row is dimmed while the selected container's toggle `key` is off.
local function unlessOn(key)
    return function() return not textBlock()[key] end
end

-- ── General ───────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    -- Size to fit (batch 8, AS-1): first in Size, a structural write so Width and Height dim (and
    -- the note under them shows) on the redraw. The size itself is modules/Style_Text.lua's.
    { path = P .. "autoSize", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "bool", startsLine = true,
      label = L["Size to fit"], desc = L["Size each line's box to its content: the height from the font, the icon, a stacked Center's rows and the bounce, the width from the widest line the placeholders draw. A live aura name longer than those is drawn in full past the edge, from where it is justified. Turn off to set the size by hand, and cut longer text at the edge."], onChange = structural },
    { path = P .. "width", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number",
      min = C.TEXT_WIDTH_MIN, max = C.TEXT_WIDTH_MAX, step = 1, disabledIf = sizedToFit, startsLine = true,
      label = L["Width (px)"], desc = L["The width of one line, icon included. Text past the edge is cut off. Grayed out while Size to fit is on: the width then follows the content, and this value is used only if it cannot be measured."] },
    { path = P .. "height", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 8, max = 80, step = 1,
      disabledIf = sizedToFit,
      label = L["Height (px)"], desc = L["The height of one line. Center stacks a line of several fields in rows, and the box grows to fit them. Grayed out while Size to fit is on: the height then follows the content, and this value is used only if it cannot be measured."] },
    { path = P .. "template", page = PAGE, group = G_GENERAL, subgroup = L["Text Template"], type = "string",
      dialogControl = "EditBox", maxLetters = C.TEXT_TEMPLATE_MAX, wide = true, label = L["Custom template"],
      desc = L["What each line says, built from the tokens listed below. Press Enter to apply."],
      validate = TT.Validate, onChange = structural },
    { path = P .. "justifyH", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_H, C.JUSTIFY_LABELS), label = L["Justify"],
      desc = L["How the line sits in its box. Center on a template of several fields stacks them, one centered row each; text outside [ ] is not drawn then, so put it inside the brackets of the field it belongs to."],
      onChange = structural },
    { path = P .. "justifyV", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_V, C.TEXT_JUSTIFY_V_LABELS), label = L["Vertical justify"],
      desc = L["Whether the line sits at the top, middle or bottom of its box."] },
    { path = P .. "x", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, startsLine = true, label = L["X offset"], desc = L["Horizontal nudge, in pixels."] },
    { path = P .. "y", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, label = L["Y offset"], desc = L["Vertical nudge, in pixels."] },
})

--- Whether this render is the page drawn disabled — the container is not drawn as text. The library
--- holds `ctx.__renderDisabled` for the whole of a page tab's render (O.RenderTabbedSchema's
--- `disabledFor`, through settings/OptionsSetup.lua's RenderPage), which is how every ROW here dims
--- itself; free-standing text has to be told.
local function pageDim(ctx)
    return ctx.__renderDisabled and true or false
end

--- Read-only prose, in the gray the Placement notes already read in (they are written GRAY at all
--- times, which is why they were the one block that looked right on a disabled page). Owner,
--- 2026-09-20: the Text Template subsection's Preview and cheat sheet stayed at full brightness
--- while every control around them dimmed, so the inert part of the tab was its loudest part.
local function dim(ctx, text)
    if not pageDim(ctx) then return text end
    return GRAY:format(text)
end

--- A run of template syntax: the token gold, or the same gray as the prose once the page is not in
--- use — gold nested inside a gray wrap would survive it, since a WoW `|r` restores the color it is
--- nested in rather than the default.
local function token(ctx, text)
    return (pageDim(ctx) and GRAY or GOLD):format(text)
end

--- A small gap, then a heading line, in the same voice a subgroup heading reads in (owner,
--- 2026-09-19: "hard to read - give it better formatting and spacing").
local function heading(ctx, text)
    local scroll = H.EnsureScroll(ctx)
    if scroll then H.AddSpacer(scroll, H.ROW_VSPACER) end
    H.TextRow(ctx, dim(ctx, text), HEADING)
end

--- One bullet, drawn small.
local function bullet(ctx, text)
    H.TextRow(ctx, dim(ctx, BULLET .. text), SMALL)
end

--- A bullet's continuation line: an example, indented under it and in the token gold so it reads as
--- template syntax rather than prose.
local function example(ctx, text)
    H.TextRow(ctx, "    " .. token(ctx, text), SMALL)
end

--- The token cheat sheet, under the Template box: a **Tokens** list (one gold `$token$` bullet each,
--- its meaning in plain text), then a **Rules** list (bracket hiding, the two escapes, how an odd run
--- of [ combines with one, why a duration belongs in brackets -- feedback #5: text outside them
--- shows on a timeless aura too -- and why a separator does -- smoke batch 2 item 8: an empty field's
--- width is secret, so only a bracket takes its separator away), each rule's example on its own
--- indented, gold continuation line.
--- Read-only text (owner, 2026-09-19: "split it into keywords and guidelines - use bullet points").
local function cheatSheet(ctx)
    heading(ctx, L["Tokens"])
    for _, def in ipairs(C.TEXT_TOKENS) do
        bullet(ctx, ("%s  %s"):format(token(ctx, "$" .. def.key .. "$"), L[C.TEXT_TOKEN_LABELS[def.key]]))
    end
    heading(ctx, L["Rules"])
    bullet(ctx, L["[ ] hides its text along with the token inside it:"])
    example(ctx, L["$spellname$[ x$stacks$] shows ' x3' only at 2 or more stacks."])
    bullet(ctx, L["To write a literal [, ] or $, type it twice:"])
    example(ctx, L["[[, ]] or $$."])
    bullet(ctx, L["Escapes and brackets combine:"])
    example(ctx, L["[[[$stacks$]]] shows [3] only when stacked."])
    bullet(ctx, L["Text outside [ ] always shows, even on an aura with no duration:"])
    example(ctx, L["($remainingpercent$%) leaves ( ) behind, [ ($remainingpercent$%)] hides with the time."])
    bullet(ctx, L["Put a separator inside the brackets of the field it leads, so an empty field takes it along:"])
    example(ctx, L["$spellname$[-$stacks$] drops the - with the stacks; $spellname$-$stacks$ leaves it."])
end

--- Under Placement: what Center does to a template of more than one piece (feedback #1): it stacks
--- the fields in rows and leaves plain text out (modules/Style_Text.lua's layoutStack). One row reads
--- singular: a literal-plus-one-field template (`Buff: $spellname$`) is Stacked but has
--- only one field row.
local function centerNote(ctx, cfg)
    local s = cfg.text or {}
    local compiled = TT.ForDraw(s.template)
    if not NS.Style.Text.Stacked(s, compiled) then return end
    local n = NS.Style.Text.FieldCount(compiled)
    local msg = n == 1 and L["Center stacks this template in 1 row; text outside [ ] is not drawn."]
        or L["Center stacks this template in %d rows, one per field; text outside [ ] is not drawn."]:format(n)
    H.TextRow(ctx, GRAY:format(msg), SMALL)
end

--- Under Justify, always (smoke batch 2, item 3): what Center does to a template of several fields,
--- and why it cannot center them on one line. The facts are modules/Style_Text.lua's: Text.Stacked,
--- layoutStack's rows, Text.StackHeight's fixed rows, and an icon at size 0 taking one row's height.
local function justifyNote(ctx)
    H.TextRow(ctx, GRAY:format(L["Center centers the line only when the template is a single piece. With several fields, each field (name, stacks, dispel type, and the duration tokens together) gets its own centered row, text outside [ ] is not drawn, and the box grows to fit the rows. Rows keep their place even when a field is empty (one stack, no dispel type, no duration), and an icon at size 0 is one row tall. Aura text is secret, so its width cannot be measured to center several fields on one line."]), SMALL)
end

-- ── The built-in templates (feedback #5) ──────────────────────────────────────────────────────

--- Whether container `id`'s Template dropdown reads Custom: its template matches no built-in, or the
--- player chose Custom this session.
local function isCustom(cfg, id)
    local s = cfg.text or {}
    return customOpen[id] or TT.MatchBuiltin(cfg.auraType, s.template, s.justifyH or D.justifyH) == nil
end

--- Choose built-in `key` for container `id`: its template, then the justify it needs (Center for the
--- centered one; Left for any other when the stored justify is Center), each through the write seam,
--- both under one `NS.Bulk.Run` bracket so a pick that touches both -- Centered picked
--- from a Left template, or the reverse -- applies once, as Show all / Hide all already do
--- (`settings/Filters.lua`'s `setGrid`), rather than drawing an intermediate mismatched frame.
local function pickBuiltin(cfg, id, key)
    local def = C.TEXT_BUILTINS[key]
    customOpen[id] = nil
    NS.Bulk.Run("pick built-in", ("template of container %s"):format(id), function()
        NS.SetByPath(P .. "template", def.template, id)
        local justify = (cfg.text and cfg.text.justifyH) or D.justifyH
        if def.justifyH and justify ~= def.justifyH then
            NS.SetByPath(P .. "justifyH", def.justifyH, id)
        elseif not def.justifyH and justify == "CENTER" then
            NS.SetByPath(P .. "justifyH", "LEFT", id)
        end
    end)
end

--- The Template dropdown: the container's built-ins, then Custom. A bespoke cell (not a schema row:
--- it has no stored value of its own), drawn disabled with the page.
local function templatePicker(cfg, id)
    return { make = function(ctx, parent, rel)
        local list, order = {}, {}
        for i, key in ipairs(TT.Builtins(cfg.auraType)) do
            list[key] = L[C.TEXT_BUILTIN_LABELS[key]]
            order[i] = key
        end
        local n = #order
        order[n + 1] = CUSTOM
        list[CUSTOM] = L["Custom"]
        local s = cfg.text or {}
        local dd = NS.AceGUI:Create("Dropdown")
        dd:SetLabel(L["Template"])
        dd:SetList(list, order)
        dd:SetValue(isCustom(cfg, id) and CUSTOM or TT.MatchBuiltin(cfg.auraType, s.template, s.justifyH or D.justifyH))
        dd:SetRelativeWidth(rel or 0.5)
        if ctx.__renderDisabled then dd:SetDisabled(true) end
        dd:SetCallback("OnValueChanged", function(_, _, key)
            if key == CUSTOM then customOpen[id] = true else pickBuiltin(cfg, id, key) end
            structural()
        end)
        H.AttachTooltip(dd, L["Template"], L["A ready-made line, or Custom to write your own from the tokens below. The Preview shows the result on a sample aura."])
        parent:AddChild(dd)
        return dd
    end }
end

--- The Preview box's text: `Text.PreviewLine` on the aura type's sample aura, a stray `|` doubled,
--- the whole line wrapped in the container's own font color (`Style.ApplyFont`'s own call) so the box
--- reads as the live line would -- with a Task 12 colored dispel word still riding inside it, since a
--- WoW `|r` restores the wrapping color it is nested in, not just white.
---
--- `PreviewLine` joins a Center-stacked template's rows with `"\n"`, which suited the old Preview
--- LABEL (it wraps), but a single-line WoW EditBox does not lay a `\n` out as a break.
--- Controller ruling: join stacked rows with a visible `" / "` instead, inside
--- the same font-color wrap, so "Centered: name over time" reads "Ignore Pain / 11s".
--- `gray` (the page drawn disabled) takes the font color off the line and reads it in the notes'
--- gray instead: the container's own bright font color on an inert tab was the loudest thing on it.
local function previewText(cfg, sample, gray)
    local raw = (NS.Style.Text.PreviewLine(cfg.text, sample):gsub("\n", " / "))
    raw = NS.Style.Text.EscapeStrayPipes(raw)
    if gray then return GRAY:format(raw) end
    local font = (cfg.text and cfg.text.font) or D.font
    local r, g, b = NS.Style.Color(font.fontColor, font.useClassColorFont)
    -- Rounded, not truncated, and clamped (Style_Text.lua's own `hex`): a stored 196/255 can float
    -- back to 195.999..., which %x truncates to 0xc3 instead of 0xc4.
    local function hex(v) return math.floor(math.max(0, math.min(1, v or 1)) * 255 + 0.5) end
    return ("|cff%02x%02x%02x%s|r"):format(hex(r), hex(g), hex(b), raw)
end

--- The Preview box (owner, 2026-09-19: "more like PrettyChat"): a disabled EditBox, `SetLabel`,
--- `SetFullWidth` and `SetDisabled` in that order, exactly PrettyChat's `previewInput`
--- (`../PrettyChat/settings/Panel.lua`). A bespoke cell, not a schema row: it has no stored value of
--- its own, and is rebuilt on every render, so it is never stale.
local function previewBox(cfg)
    return { wide = true, make = function(ctx, parent)
        local sample = C.TEXT_SAMPLE_AURAS[cfg.auraType] or C.TEXT_SAMPLE_AURAS.HELPFUL
        local box = NS.AceGUI:Create("EditBox")
        box:SetLabel(L["Preview"])
        box:SetFullWidth(true)
        box:SetDisabled(true)
        box:SetText(previewText(cfg, sample, pageDim(ctx)))
        H.AttachTooltip(box, L["Preview"], L["The line this template draws on a sample aura. Read-only."])
        parent:AddChild(box)
        return box
    end }
end

--- A copy of `row` the flow engine draws nothing for but its subsection heading (RenderRows emits a
--- subgroup's heading before it looks at skipRender).
local function headingOnly(row)
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    copy.skipRender = true
    return copy
end

--- Text Template: the subsection heading, the Template dropdown, the Custom template box (Custom
--- only), the Preview box on the aura type's sample aura, then the cheat sheet.
---
--- The dropdown and the box are widgets, and dim with the page on their own. The Preview's text and
--- the cheat sheet are free-standing text, and are dimmed by hand (`dim`/`token`) so the whole
--- subsection goes quiet together, as Placement's notes always have (owner, 2026-09-20).
local function renderTemplate(ctx, cfg, row)
    local _, id = NS.ActiveContainer()
    if row then H.RenderRows(ctx, { headingOnly(row) }, nil, nil, { noHeadings = true }) end
    H.RenderGrid(ctx, { templatePicker(cfg, id) })
    if row and isCustom(cfg, id) then H.RenderRows(ctx, { row }, nil, nil, { noHeadings = true }) end
    H.RenderGrid(ctx, { previewBox(cfg) })
    cheatSheet(ctx)
end

--- Under Size, while Size to fit is on: why Width and Height are dimmed, and when they still count.
local function fitNote(ctx)
    if not sizedToFit() then return end
    H.TextRow(ctx, GRAY:format(L["Width and height follow the font, the icon and the template while Size to fit is on. They still apply if the size cannot be measured."]), SMALL)
end

-- The Placement rows drawn above the Justify note (the justify pair); the offsets follow it.
local JUSTIFY_ROWS = { [P .. "justifyH"] = true, [P .. "justifyV"] = true }

--- The General tab: Size, then what each line says (renderTemplate), then Placement: the justify
--- pair, the Justify note (item 3), the offsets and the centering note.
local function renderGeneral(ctx, cfg, rows)
    local size, justify, tail, templateRow = {}, {}, {}, nil
    for _, row in ipairs(rows or {}) do
        if row.path == P .. "template" then
            templateRow = row
        else
            local list = size
            if row.subgroup == S_PLACEMENT then list = JUSTIFY_ROWS[row.path] and justify or tail end
            local n = #list
            list[n + 1] = row
        end
    end
    H.RenderRows(ctx, size, nil, nil, { noHeadings = true })
    fitNote(ctx)
    renderTemplate(ctx, cfg, templateRow)
    H.RenderRows(ctx, justify, nil, nil, { noHeadings = true })
    justifyNote(ctx)
    H.RenderRows(ctx, tail, nil, nil, { noHeadings = true })
    centerNote(ctx, cfg)
end

-- ── Font ──────────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows(H.FontGroup({
    prefix = P .. "font.", page = PAGE, group = G_FONT, subgroup = L["Font"], classColor = UNIT,
}))
NS.RegisterSchemaRows({
    { path = P .. "timeFormat", page = PAGE, group = G_FONT, subgroup = L["Countdown"], type = "string",
      values = NS.Choices(C.TIME_FORMATS, C.TIME_FORMAT_LABELS), label = L["Time format"],
      desc = L["How the duration tokens write a time."] },
    -- Color by dispel type (feedback #7): three opt-in stand-ins, all off, since no engine binding
    -- colors a whole line by the aura's type (modules/Style_Text.lua's header). On the Font tab since
    -- smoke batch 2, item 5 (they color the text); paths and stored values unchanged.
    { path = P .. "dispelTypeColor", page = PAGE, group = G_FONT, subgroup = S_DISPEL, type = "bool",
      startsLine = true, disabledIf = noDispel,
      label = L["Color the dispel type"],
      desc = L["Write $dispeltype$ in its type's color from General -> Dispel Colors. The rest of the line keeps the font color. Needs $dispeltype$ in the template."] },
    { path = P .. "dispelBackdrop", page = PAGE, group = G_FONT, subgroup = S_DISPEL, type = "bool",
      startsLine = true, label = L["Backdrop in the dispel color"],
      desc = L["Fill the line's box, behind the text, with the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none."] },
    { path = P .. "dispelBackdropAlpha", page = PAGE, group = G_FONT, subgroup = S_DISPEL, type = "number",
      min = 0.05, max = 1, step = 0.05, isPercent = true, disabledIf = unlessOn("dispelBackdrop"),
      label = L["Backdrop opacity"], desc = L["How strongly the backdrop shows behind the text."] },
    { path = P .. "dispelEdge", page = PAGE, group = G_FONT, subgroup = S_DISPEL, type = "bool",
      startsLine = true, label = L["Edge in the dispel color"],
      desc = L["Outline the line's box in the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none."] },
    { path = P .. "dispelEdgeSize", page = PAGE, group = G_FONT, subgroup = S_DISPEL, type = "number",
      min = 1, max = 4, step = 1, disabledIf = unlessOn("dispelEdge"),
      label = L["Edge thickness (px)"], desc = L["How thick the edge is."] },
})

-- ── Icon ──────────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "icon", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "string",
      values = NS.Choices(C.TEXT_ICON_POSITIONS, C.TEXT_ICON_POSITION_LABELS), label = L["Icon position"],
      desc = L["Where the aura's icon sits beside the text, or hide it."], onChange = structural },
    { path = P .. "iconSize", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 80, step = 1,
      disabledIf = noIcon,
      label = L["Icon size (0 = line height)"], desc = L["A square icon this many pixels wide."] },
    { path = P .. "iconGap", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 20, step = 1,
      disabledIf = noIcon,
      label = L["Icon gap (px)"], desc = L["Space between the icon and the text."] },
    { path = P .. "iconZoom", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 0.3, step = 0.01,
      disabledIf = noIcon,
      label = L["Icon zoom"], desc = L["Crop the icon's border art."] },
})
local iconBorder = H.BorderGroup({
    prefix = P, page = PAGE, group = G_ICON, subgroup = L["Icon border"], show = true, classColor = UNIT,
    keys = { borderShow = "iconBorderShow", borderStyle = "iconBorderStyle", borderSize = "iconBorderSize",
             borderColor = "iconBorderColor", useClassColorBorder = "useClassColorIconBorder" },
})
-- Every border row dims with no icon (noIcon), except the swatch: a color row is never grayed
-- (anti-pattern #74, options-ui-§17), as the pandemic-window time swatch stays live on the Pandemic tab.
for _, row in ipairs(iconBorder) do
    if row.path == P .. "iconBorderShow" then row.tooltip = L["Draw a border around the icon; its art sits inside it."] end
    -- A style other than Solid is a backdrop, which a live button's secret size keeps from redrawing
    -- (modules/Style.lua's ApplyBorder, B2-3): the tooltip says when it shows.
    if row.path == P .. "iconBorderStyle" then row.tooltip = L["The border texture. Solid redraws at once; any other texture, and a new thickness for one, reaches the aura buttons already on screen after a /reload."] end
    if row.type ~= "color" then row.disabledIf = noIcon end
end
NS.RegisterSchemaRows(iconBorder)

-- ── Pandemic ──────────────────────────────────────────────────────────────────────────────────
-- Smoke batch 2, B2-1 (the owner's call): once "Running out" on the Animation tab, named for the
-- pandemic window as on the Bars and Icons pages, and registered ahead of Animation so its tab
-- sits before it. Labels only: the paths and stored values are unchanged.

NS.RegisterSchemaRows({
    { path = P .. "expiringColorOn", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "bool",
      startsLine = true, disabledIf = noDuration,
      label = L["Recolor the time in the pandemic window"],
      desc = L["Turn the duration tokens another color in the pandemic window: the last seconds, set below. The rest of the line keeps the font color."] },
    { path = P .. "expiringThreshold", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "number",
      min = 1, max = 60, step = 1, disabledIf = noDuration,
      label = L["Pandemic window (seconds left)"], desc = L["The pandemic window starts this many seconds before the aura ends."] },
    -- Palette definition (options-ui-§17 exemption): identifies a state, not a player.
    -- Never dimmed, even without a duration token: a swatch is read for its alpha (anti-pattern #74,
    -- tests/test_schema.lua).
    { path = P .. "expiringColor", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "color",
      startsLine = true,
      label = L["Pandemic-window time color"], desc = L["The duration tokens' color in the pandemic window."] },
    -- engine-only: the blink is a curve the engine steps on its own clock; a placeholder's time is a
    -- fixed number, so the preview shows the pandemic-window color and never the blink
    -- (tests/test_render_coverage.lua).
    { path = P .. "expiringBlink", page = PAGE, group = G_PANDEMIC, subgroup = S_TIME, type = "bool",
      disabledIf = noDuration, coverage = "engine-only",
      label = L["Blink in the pandemic window"],
      desc = L["Blink the duration tokens in the pandemic window, in the pandemic-window time color when that is on. Only the duration tokens blink. The preview shows the color, not the blink."] },
})

-- ── Animation ─────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "anim", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "string",
      values = NS.Choices(C.TEXT_ANIMS, C.TEXT_ANIM_LABELS), label = L["Effect"],
      desc = L["A looping effect on the whole line. Pulse fades it down and back, Blink switches it off and on, Bounce moves it up and down (give the box a few pixels of headroom). A change made in combat starts when combat ends."] },
    { path = P .. "animSpeed", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 0.2, max = 3, step = 0.1, disabledIf = unlessAnim("pulse", "blink", "bounce"),
      label = L["Seconds per cycle"], desc = L["How long one pulse, blink or bounce takes."] },
    { path = P .. "animIntensity", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 0, max = 0.9, step = 0.05, isPercent = true, disabledIf = unlessAnim("pulse", "blink"),
      label = L["Faded to"], desc = L["How visible the line stays at the low point of a pulse or blink."] },
    { path = P .. "animBounce", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 1, max = 10, step = 1, disabledIf = unlessAnim("bounce"),
      label = L["Bounce height (px)"], desc = L["How far the line moves up. The box clips it, so leave headroom."] },
})

--- After the Icon tab's rows: why they are dimmed, when Icon position is None (smoke batch 2, item 6).
local function iconNote(ctx)
    if not noIcon() then return end
    H.TextRow(ctx, GRAY:format(L["Set Icon position to show the icon."]), SMALL)
end

--- After the Pandemic tab's rows: why they are dimmed, when the template has no duration.
local function pandemicNote(ctx)
    if not noDuration() then return end
    H.TextRow(ctx, GRAY:format(L["The pandemic window needs a duration token, such as $remainingduration$, in the template."]), SMALL)
end

NS.RegisterContainerPage(PAGE, L["Text"], "AuraMasterTextPanel", {
    tabs = { { key = G_GENERAL, label = G_GENERAL, render = renderGeneral } },
    afterGroup = { [G_ICON] = iconNote, [G_PANDEMIC] = pandemicNote },
    disabledFor = function(cfg) return cfg.style ~= "text" end,
    disabledNotice = function(cfg)
        if cfg.style == "icons" then
            return L["Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."]
        end
        return L["Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."]
    end,
})
