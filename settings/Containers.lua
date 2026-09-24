local _, NS = ...

-- settings/Containers.lua — the Containers page: which containers exist, and what each is.
--
--     band        [Container v picker ][ New container ]            <- above the strip (options-ui-§14)
--     [ General ]
--     General     [Name] [Enabled]
--                 -- What it shows, and how --                     <- subsection (options-ui-§7)
--                 [Unit] [Aura type] / [Style]
--                 [Duplicate] [Delete]                             <- acts on the selected container
--                 -- Copy settings from --  [Source v] [What v] [Copy]
--
-- A TOP-LEVEL PAGE (N-1, batch 7) whose single tab is Containers. It used to be General's third
-- tab (docs/superpowers/specs/2026-09-15-feedback-batch7-design.md, N-1); the owner moved it out to
-- its own page, mirroring MultiMeters' Windows, and Filters, Layout, Bars and Icons became its
-- sub-pages (N-2, marked by NS.SubPageLabel — settings/OptionsSetup.lua's D6 section).
--
-- THE PICKER AND NEW CONTAINER SIT IN THE BAND ABOVE THE STRIP (feedback #2, 2026-09-19), in the
-- library's chrome block (Helpers.ContainerHeader, settings/OptionsSetup.lua): the identity controls
-- options-ui-§14 puts there, on one row. The acts on the selected container — Name, Enabled,
-- Duplicate, Delete, Copy settings from — stay on the page's one tab, which options-ui-§14 then names General.
-- This retired the page's options-ui-§14 deviation (docs/ARCHITECTURE.md). The block is drawn anew
-- on every render, so a Delete's two refreshes cannot lose it; the widgets of the render before are
-- released after each render (releaseStale), never during one.
--
-- This file registers its own rows and its own page, at the bottom, like every other page file.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local CM = NS.ContainerManager
local print = NS.Print
local printf = NS.Printf

local PAGE = "containers"
-- options-ui-§14: the tab holding a page's acts, under a band carrying its picker, is named General.
local GROUP = L["General"]

-- options-ui-§7: the tab is the GROUP's heading, and a subgroup is what breaks a tab up inside
-- itself. Name and Enabled answer "which container is this" and need no heading; Unit, Aura type and
-- Style answer a different question — what it watches and how it is drawn — and sat unheaded in the
-- same run of rows, which read as one undifferentiated block (owner, batch 8, from a screenshot).
-- They now carry a subsection of their own. Worded the way a player would ask it rather than after
-- the three field names, which would only repeat the labels immediately under it.
local S_SHOWS = L["What it shows, and how"]

-- Changing what a container IS changes which rows other pages offer (buff categories are not
-- debuff categories), so the panel is rebuilt — on the next frame, out of the dropdown's callback.
local function structural() if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end end

local ROWS = {
    {
        path = "container.name", page = PAGE, group = GROUP, type = "string", dialogControl = "EditBox",
        maxLetters = 40, label = L["Name"],
        desc = L["What this container is called in the picker, on its drag handle and in /am containers. Press Enter to apply."],
        validate = function(v) return type(v) == "string" and v:match("%S") ~= nil end,
        -- Every write — the panel, `/am set`, Rename — stores the trimmed name made unique
        -- case-insensitively, so `/am select|delete <name>` can never match two containers.
        normalize = function(v, id) return CM.UniqueName(v:match("^%s*(.-)%s*$"), id) end,
        -- NotifyRenamed is the whole effect (handles and pickers); Container:Apply never reads the
        -- name, so a rename queues no apply and, in combat, announces no deferral.
        onChange = function() CM.NotifyRenamed() end, effect = "none",
        -- A name has no meaningful default (owner, 2026-09-13): neither this page's Defaults nor
        -- `/am reset` restores it, and `/am reset` prints the library's no-default line. The
        -- template's name still backfills.
        noReset = true,
    },
    {
        path = "container.enabled", page = PAGE, group = GROUP, type = "bool",
        label = L["Enabled"], desc = L["Draw this container. A disabled container keeps its settings."], effect = "visibility",
    },
    {
        path = "container.unit", page = PAGE, group = GROUP, subgroup = S_SHOWS, type = "string",
        values = NS.Choices(C.UNITS, C.UNIT_LABELS), label = L["Unit"],
        desc = L["Whose auras this container shows."],
        onChange = structural,
    },
    {
        path = "container.auraType", page = PAGE, group = GROUP, subgroup = S_SHOWS, type = "string",
        values = NS.Choices(C.AURA_TYPES, C.AURA_TYPE_LABELS), label = L["Aura type"],
        desc = L["Buffs or debuffs. The Filters page offers the categories of whichever you choose; your temporary weapon enchants are a buff category there."],
        onChange = structural,
    },
    {
        path = "container.style", page = PAGE, group = GROUP, subgroup = S_SHOWS, type = "string",
        values = NS.Choices(C.STYLES, C.STYLE_LABELS), label = L["Style"],
        desc = L["Draw each aura as a bar, an icon or a line of text. Bars, Icons and Text each have their own settings page."],
        -- B5: a new style resets Fill (Layout -> Growth) to the one it suits, through the one write
        -- seam and for the same container, then the panel rebuilds once. Only on a real change: the
        -- seam hands onChange the value it replaced. A duplicate, a copy-from's own layout, a profile
        -- switch and the starter seeding never come through here, so their stored Fill stands. A new
        -- container takes the same rule at creation (modules/ContainerManager.lua's newContainerData).
        onChange = function(v, id, old)
            local axis = C.STYLE_FILL_AXIS[v]
            if axis and old ~= v then NS.SetByPath("container.layout.axis", axis, id) end
            structural()
        end,
    },
}

NS.RegisterSchemaRows(ROWS)

-- ---------------------------------------------------------------------------
-- Acts on the selected container
-- ---------------------------------------------------------------------------

-- A refusal (CM.Create's third return) is the gray combat line; any other error prints plain.
local function sayError(err, refused)
    if refused then return printf("|cff808080%s|r", err) end
    print(err)
end

local function doNew()
    local id, err, refused = CM.Create({})
    if not id then return sayError(err, refused) end
    H.SelectContainer(id)
end

local function doDuplicate()
    local _, id = NS.ActiveContainer()
    if not id then return end
    local newId, err, refused = CM.Duplicate(id)
    if not newId then return sayError(err, refused) end
    H.SelectContainer(newId)
end

StaticPopupDialogs["AURAMASTER_DELETE_CONTAINER"] = {
    text         = L["Delete the container '%s'? Its settings are discarded."],
    button1      = L["Yes"],
    button2      = L["No"],
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function(_, data)
        -- The same gate as /am delete: a popup accepted after combat started must not tear down.
        if InCombatLockdown() then
            return printf("|cff808080%s|r", L["cannot delete a container during combat — its display cannot be torn down until combat ends"])
        end
        if data and CM.Delete(data) then H.RefreshAllPanels() end
    end,
}

local function doDelete()
    local cfg, id = NS.ActiveContainer()
    if not id then return end
    local popup = StaticPopup_Show("AURAMASTER_DELETE_CONTAINER", tostring(cfg.name))
    if popup then popup.data = id end
end

-- The copy control's selection. Page state, not a setting: it means nothing outside an open panel.
local copySource, copySection = nil, "all"

local SECTION_KEYS = { "all", "filter", "layout", "behavior", "bars", "icons", "text" }
local SECTION_LABELS = {
    all = "Everything (what it shows and how it looks)", filter = "Filters", layout = "Layout",
    behavior = "Mouse", bars = "Bar style", icons = "Icon style", text = "Text style",
}

local function sourceCell(_, parent, rel)
    local _, activeId = NS.ActiveContainer()
    local list, order = {}, {}
    for _, c in ipairs(NS.Database.GetContainersByName()) do   -- by name, as every picker (B2-2)
        if c.id ~= activeId then
            list[c.id] = tostring(c.name)
            order[#order + 1] = c.id
        end
    end
    if not list[copySource] then copySource = order[1] end
    local dd = NS.AceGUI:Create("Dropdown")
    dd:SetLabel(L["Source container"])
    dd:SetList(list, order)
    dd:SetValue(copySource)
    dd:SetRelativeWidth(rel or 0.5)
    dd:SetCallback("OnValueChanged", function(_, _, v) copySource = v end)
    parent:AddChild(dd)
    return dd
end

local function sectionCell(_, parent, rel)
    local list, order = {}, {}
    for i, k in ipairs(SECTION_KEYS) do list[k] = L[SECTION_LABELS[k]]; order[i] = k end
    local dd = NS.AceGUI:Create("Dropdown")
    dd:SetLabel(L["What to copy"])
    dd:SetList(list, order)
    dd:SetValue(copySection)
    dd:SetRelativeWidth(rel or 0.5)
    dd:SetCallback("OnValueChanged", function(_, _, v) copySection = v end)
    parent:AddChild(dd)
    return dd
end

local function renderCopy(ctx)
    local _, activeId = NS.ActiveContainer()
    H.Section(ctx, L["Copy settings from"])
    H.RenderGrid(ctx, { { make = sourceCell }, { make = sectionCell } })
    H.InlineButtonPair(ctx, {
        text = L["Copy onto this container"],
        tooltip = L["Replace the chosen settings of the selected container with the source's. Name and position are never copied."],
        onClick = function()
            if not (copySource and activeId) then return end
            local ok, err = CM.CopyFrom(copySource, activeId, copySection ~= "all" and copySection or nil)
            -- A copy can change what the selected container IS (its aura type, its style), and so
            -- which rows every page offers: re-render, as the Delete popup does.
            if ok then H.RefreshAllPanels() else print(err) end
        end,
    }, nil)
end

local function afterRows(ctx)
    H.InlineButtonPair(ctx,
        { text = L["Duplicate"], tooltip = L["Make a copy of this container with every setting."], onClick = doDuplicate },
        { text = L["Delete"], tooltip = L["Delete this container. Asks first."], onClick = doDelete })
    local count = #NS.Database.GetContainers()
    if count > 1 then renderCopy(ctx) end
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------

--- The General tab: the selected container's identity rows and the acts on it. With no container
--- there is nothing to edit: the one sentence saying how to make one (the band still offers New).
local function render(ctx, cfg, rows)
    if not cfg then
        H.TextRow(ctx, L["No containers yet. Click New container, or type /am new."])
        return
    end
    H.RenderRows(ctx, rows or {}, { [GROUP] = afterRows }, nil, { noHeadings = true })
end

NS.Containers = { GROUP = GROUP, rows = ROWS, render = render }

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

local PAGE_SPEC = {
    -- Every tab draws whether or not a container exists (the render above handles the empty case
    -- itself, same as General).
    addonWide = true,
    tabs      = { { key = GROUP, label = GROUP, render = render } },
}

local HEADER = { onNew = doNew }
local function header(ctx) H.ContainerHeader(ctx, HEADER) end

--- Hand the previous render's chrome widgets back to AceGUI. AFTER the render, never before: the
--- render is usually running inside one of their callbacks (the picker's, New's), and a widget
--- released on the way in could be handed straight back out, re-initialized, under its own callback.
---
--- Final review, Minor #1 (this file duplicates `Helpers.ContainerHeader`'s own swap-and-release):
--- kept on purpose. `ContainerHeader` swaps `ctx.__chromeWidgets` too, but by the time it runs here
--- it is swapping the EMPTY table this wrapper just installed (line below), so its own release is a
--- no-op on this path -- the widgets this function actually frees are the ones captured before that
--- swap. Only the tab-strip's own `onSelect` (`Helpers.RenderTabbedPage`'s direct call to `header`,
--- bypassing this wrapper) relies on `ContainerHeader`'s release doing the real work. No test in the
--- suite targets the three paths (first build, a `renderPage` redraw, tab `onSelect`) individually
--- for a leak or a double-release, only the whole-suite live-heap gate, which is indirect evidence
--- rather than proof. Removing this wrapper's capture without that proof risks a widget leak on the
--- `renderPage` path the first time `ContainerHeader`'s internals change, so it stays.
local function releaseStale(stale)
    local AceGUI = NS.AceGUI
    if not (AceGUI and AceGUI.Release and stale) then return end
    for _, w in ipairs(stale) do AceGUI:Release(w) end
end

local function renderPage(ctx)
    local stale = ctx.__chromeWidgets
    ctx.__chromeWidgets = {}
    H.RenderTabbedPage(ctx, PAGE, PAGE_SPEC, header)
    releaseStale(stale)
end

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("AuraMasterContainersPanel", L["Containers"], {
        pageKey         = PAGE,
        defaultsButton  = true,
        defaultsTooltip = L["Restore the selected container's Enabled, Unit, Aura type and Style to its addon default. Its name is kept."],
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults(PAGE, ctx) end
    H.__pageCtx[PAGE] = ctx
    -- Through SetRenderer, which owns WHEN the page draws and refuses under combat (options-ui-§11).
    H.SetRenderer(ctx, renderPage)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["Containers"])
end

NS.RegisterOptionsPage(PAGE, L["Containers"], build)
