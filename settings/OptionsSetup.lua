local _, NS = ...

-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0 (options-ui-§1).
--
-- The canvas shell, the schema-row → AceGUI makers, the two-column flow engine, the tab strip and
-- the chrome band are the library's. This file is the part that is ours: where a value lives,
-- which rows belong to which page, what a color looks like on disk — and the one piece of page
-- furniture four pages share, the CONTAINER BANNER, with the renderer every per-container page
-- goes through.
--
-- Loads after settings/Slash.lua and BEFORE every settings/<page>.lua, because those files call
-- the composers (NS.Helpers.FontGroup, …) at FILE LOAD.

local L = NS.L
local print = NS.Print

local PARENT_TITLE = "Ka0s Aura Master"

-- The one rule about what a global reset must not touch, named once because it is enforced twice:
-- by the library through skipRestoreAll, and by the degradation stub's own reset loop. It vetoes
-- the Profiles page and every profile-backed row (options-ui-§12): the global reset IS a profile
-- reset, so what the walk keeps is only what a profile reset cannot reach — the session rows.
local function vetoedFromResetAll(row)
    if row.page == "profiles" then return true end
    return not row.sessionOnly
end

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

local descriptor = {
    parentTitle   = PARENT_TITLE,
    mainPanelName = "AuraMasterMainPanel",

    print = function(line) print(line) end,
    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, value) NS.SetByPath(path, value) end,
    applyDefault = function(row) NS.ApplyDefault(row) end,
    allRows      = function() return NS.Schema end,
    rowsForPage  = function(pageKey, filter) return NS.SchemaForPage(pageKey, filter) end,

    skipRestoreAll = vetoedFromResetAll,
    -- RESET ALL SETTINGS IS A PROFILE RESET (options-ui-§12). AceDB empties the active profile —
    -- every container with it — the defaults merge back, and OnProfileReset reaches
    -- NS.OnProfileChanged (core/AuraMaster.lua), which re-seeds the starter containers and rebuilds
    -- everything. Positions live in the profile and come back with it.
    resetProfile = function()
        local db = NS.db
        if db and db.ResetProfile then db:ResetProfile() end
    end,
    -- This addon ships the AceDBOptions Profiles sub-page (settings/Profiles.lua), so the Reset-all
    -- tooltip names the equivalence §12 asks for: "the same thing Profiles → Reset Profile does"
    -- (LibKa0s-Options minor 18). Read by MasterControls alone, with resetProfile supplied.
    profilesPage = true,
    -- The bulk bracket (LibKa0s-Options minor 16, debug-logging-§10), paired as the contract asks:
    -- RestoreDefaults and RestoreAllDefaults write through the seam muted, and settings/Schema.lua
    -- logs the act once. A Reset all is logged by NS.OnProfileReset alone.
    bulkBegin = function(...) NS.Bulk.Begin(...) end,
    bulkEnd   = function(...) NS.Bulk.End(...) end,

    scheduleTimer = function(fn, delay) return NS.addon:ScheduleTimer(fn, delay) end,
    getLSM        = function() return LibStub("LibSharedMedia-3.0", true) end,
    validate      = function() NS.ValidateSchema() end,
    onAceGUI      = function(AceGUI) NS.AceGUI = AceGUI end,
    buildMain     = function(ctx)
        if NS.Helpers and NS.Helpers.BuildMainContent then NS.Helpers.BuildMainContent(ctx) end
    end,

    colorDecode = function(c)
        if type(c) ~= "table" then c = {} end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end,
    colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
}

-- ---------------------------------------------------------------------------
-- The degradation stub — LOAD-COMPLETING, not member-answering (options-ui-§1)
-- ---------------------------------------------------------------------------
--
-- Every page file calls a composer inside NS.RegisterSchemaRows AT FILE LOAD. With any of those
-- nil the page file raises, its rows never register, and most of the schema — with /am list,
-- /am set and the profile defaults — silently vanishes. So this stub publishes every member a page
-- file touches at load, measured by deleting one and re-running tests/degraded_env.lua, and
-- nothing else: no widget maker, no flow engine, no header, no LAYOUT constant.
--
-- The composers reproduce the STORED SURFACE only — one row per canonical leaf at the path the live
-- composer derives, with its type. Labels, ranges and media sources are read by widgets, and this
-- build has none. tests/test_optionssetup.lua pins the member set and the schema row count.
if not lib then
    local function sayMissing() NS.Printf(L["%s, so the settings panel is unavailable."], NS.LIBKA0S_MISSING) end
    local Helpers = {}
    NS.Helpers = Helpers

    local function composeBlock(leaves, spec)
        spec = spec or {}
        local keys, omit = spec.keys or {}, spec.omit or {}
        local rows = {}
        for _, leaf in ipairs(leaves) do
            if not omit[leaf.leaf] then
                local row = {
                    path = leaf.path or ((spec.prefix or "") .. (keys[leaf.leaf] or leaf.leaf)),
                    page = spec.page, group = spec.group, subgroup = spec.subgroup,
                    type = leaf.type, sessionOnly = leaf.sessionOnly,
                }
                rows[#rows + 1] = row
            end
        end
        for _, extra in ipairs(spec.extra or {}) do
            local row = {}
            for k, v in pairs(extra) do row[k] = v end
            row.page, row.group, row.subgroup = spec.page, spec.group, spec.subgroup
            rows[#rows + 1] = row
        end
        return rows
    end

    Helpers.ColorPair = function(spec)
        spec = spec or {}
        local key = spec.key or "color"
        local companion = spec.companionKey or ("useClassColor" .. key:sub(1, 1):upper() .. key:sub(2))
        return composeBlock({ { leaf = key, type = "color" }, { leaf = companion, type = "bool" } }, spec)
    end
    Helpers.FontGroup = function(spec)
        return composeBlock({
            { leaf = "font", type = "string" }, { leaf = "fontSize", type = "number" },
            { leaf = "fontColor", type = "color" }, { leaf = "useClassColorFont", type = "bool" },
            { leaf = "fontFlags", type = "string" }, { leaf = "fontShadow", type = "bool" },
        }, spec)
    end
    Helpers.BorderGroup = function(spec)
        spec = spec or {}
        local leaves = {
            { leaf = "borderStyle", type = "string" }, { leaf = "borderSize", type = "number" },
            { leaf = "borderColor", type = "color" }, { leaf = "useClassColorBorder", type = "bool" },
        }
        if spec.show then table.insert(leaves, 1, { leaf = "borderShow", type = "bool" }) end
        return composeBlock(leaves, spec)
    end
    Helpers.BarGroup = function(spec)
        return composeBlock({
            { leaf = "barTexture", type = "string" }, { leaf = "barAlpha", type = "number" },
            { leaf = "barColor", type = "color" }, { leaf = "useClassColorBar", type = "bool" },
        }, spec)
    end

    -- The literal options-ui-§15 mandates; the host uses it as the afterGroup key, so both paths
    -- must answer it for the two schemas to match.
    Helpers.MASTER_GROUP = "Master controls"
    Helpers.MasterControls = function(spec)
        spec = spec or {}
        local omit = {}
        for k in pairs(spec.omit or {}) do omit[k] = true end
        if spec.frameless then omit.scale, omit.alpha, omit.locked = true, true, true end
        local rows = composeBlock({
            { leaf = "enabled", type = "bool" }, { leaf = "visibility", type = "string" },
            { leaf = "scale", type = "number" }, { leaf = "alpha", type = "number" },
            { leaf = "locked", type = "bool" },
            { leaf = "debugConsole", type = "bool", sessionOnly = true,
              path = spec.debugConsolePath or "state.debugConsole" },
        }, { prefix = spec.prefix, page = spec.page, group = spec.group or Helpers.MASTER_GROUP,
             subgroup = spec.subgroup, omit = omit, extra = spec.extra })
        return rows, function() end
    end

    -- Kept although it is reached at call time: `/am resetall` is a recovery path, and the player
    -- whose panel will not open is the one who needs it.
    -- One bulk act, like the library's: the session rows are written muted, and the profile reset
    -- is logged once, by NS.OnProfileReset (debug-logging-§10).
    Helpers.RestoreAllDefaults = function()
        NS.Bulk.Run("reset", "all", function()
            for _, row in ipairs(NS.Schema or {}) do
                if not vetoedFromResetAll(row) then NS.ApplyDefault(row) end
            end
            local db = NS.db
            if not (db and db.ResetProfile) then return false end
            db:ResetProfile()
            return true
        end)
    end

    -- Reached only from a builder, a render or a user action, so a no-op is the honest answer.
    for _, name in ipairs({ "RefreshAllPanels", "RefreshScalars", "RestoreDefaults" }) do
        Helpers[name] = function() end
    end

    NS.RegisterOptionsPage = function() end
    NS.RefreshOptionsPanel = function() end
    NS.CreateOptionsPanel  = function() sayMissing() end
    NS.OpenOptionsPanel    = function() sayMissing() end
    NS.OpenOptionsPage     = function() sayMissing() end
    NS.RegisterContainerPage = function() end
    return
end

-- ---------------------------------------------------------------------------
-- The live wiring
-- ---------------------------------------------------------------------------

-- LSM30_Border lines up on a canvas page only once wrapped; the library does it once per process
-- whoever calls it (LibKa0s-Options-1.0 minor 15), so the call is unconditional.
lib.__PatchLSM30Border()

-- NS.Helpers IS the library instance, decorated in place — never a copy — so a host helper added
-- below can call the library's members and a suite spying on one sees the one callers see.
NS.Helpers = lib:New(descriptor)
local Helpers = NS.Helpers

NS.RegisterOptionsPage = function(key, name, builder) Helpers.RegisterOptionsPage(key, name, builder) end
NS.CreateOptionsPanel  = function() Helpers.CreateOptionsPanel() end
NS.OpenOptionsPanel    = function() Helpers.OpenOptionsPanel() end
NS.RefreshOptionsPanel = function() Helpers.RefreshAllPanels() end

-- Every Blizzard subcategory a page registered, by page key, so the frame picker can bring the
-- player back to the Layout page it started from.
local categories = {}

--- Open the settings window at one page. Refuses under combat lockdown exactly as the library's
--- own open does (options-ui-§2) — a category switch is protected, so it is refused, never deferred.
function NS.OpenOptionsPage(pageKey)
    if InCombatLockdown() then
        NS.Printf("|cff808080%s|r", L["cannot open settings during combat — Blizzard's category-switch is protected"])
        return
    end
    local cat = categories[pageKey]
    if cat and cat.GetID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(cat:GetID())
    else
        Helpers.OpenOptionsPanel()
    end
end

-- A structural refresh requested from inside a widget's own callback — a dropdown that changes
-- which rows exist — is run on the NEXT frame, so the render never releases the widget whose
-- callback is still on the stack. Coalesced: ten requests in one frame are one refresh.
local refreshQueued = false
function NS.RequestPanelRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        Helpers.RefreshAllPanels()
    end)
end

-- The registry changed (a container created, deleted, renamed, copied onto): every banner lists
-- containers and every per-container page may now be looking at a different one. Subscribed on
-- this file's own bus target (architecture-§4).
local ev = NS.NewBusTarget()
ev:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, function() NS.RequestPanelRefresh() end)

-- ---------------------------------------------------------------------------
-- The container banner and the per-container page renderer
-- ---------------------------------------------------------------------------

local C = NS.Constants

--- The picker's entries: every container, labeled with what it shows.
local function containerList()
    local list, order = {}, {}
    for _, c in ipairs(NS.Database.GetContainers()) do
        list[c.id] = ("%s  |cff888888(%s %s, %s)|r"):format(tostring(c.name),
            L[C.UNIT_LABELS[c.unit] or tostring(c.unit)],
            L[C.AURA_TYPE_LABELS[c.auraType] or tostring(c.auraType)]:lower(),
            L[C.STYLE_LABELS[c.style] or tostring(c.style)]:lower())
        order[#order + 1] = c.id
    end
    return list, order
end

--- Point every per-container page at container `id`: the ONE writer of the selection from the
--- panel. A structural refresh follows, because the other pages did not change VALUE, they
--- changed SUBJECT.
function Helpers.SelectContainer(id)
    if NS.State then NS.State.SetActiveContainer(id) end
    Helpers.RefreshAllPanels()
end

local BANNER_TOOLTIP = "Which container the settings on this page apply to. Every container is configured independently; the choice is shared by every page."

--- The banner every per-container page draws (options-ui-§14): the picker itself, the page's only
--- picker, re-read at render time so two pages can never disagree.
function Helpers.ContainerBanner(ctx)
    local list, order = containerList()
    local _, activeId = NS.ActiveContainer()
    local dd = Helpers.PageBanner(ctx, {
        label    = L["Container"],
        tooltip  = L[BANNER_TOOLTIP],
        list     = list,
        order    = order,
        value    = activeId,
        onSelect = function(id)
            if id == nil or id == activeId then return end
            Helpers.SelectContainer(id)
        end,
    })
    ctx.__bannerWidget = dd
    return dd
end

--- Place one AceGUI widget inside a PageHeader frame: "LEFT" / "RIGHT" half, or full width.
function Helpers.PlaceInHeader(widget, frame, half)
    local f = widget and widget.frame
    if not f then return end
    f:SetParent(frame)
    f:ClearAllPoints()
    if half == "LEFT" then
        f:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        f:SetPoint("TOPRIGHT", frame, "TOP", -4, 0)
    elseif half == "RIGHT" then
        f:SetPoint("TOPLEFT", frame, "TOP", 4, -18)
        f:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -18)
    else
        f:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        f:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    end
    f:Show()
end

--- The picker as a plain AceGUI Dropdown, for a page whose ONE chrome block also carries a control
--- (the Containers page's New button). Recorded on the ctx's widget ledger for release.
function Helpers.ContainerPickerWidget(ctx)
    local AceGUI = NS.AceGUI
    local list, order = containerList()
    local _, activeId = NS.ActiveContainer()
    local dd = AceGUI:Create("Dropdown")
    ctx.__chromeWidgets[#ctx.__chromeWidgets + 1] = dd
    dd:SetLabel(L["Container"])
    dd:SetList(list, order)
    dd:SetValue(activeId)
    dd:SetCallback("OnValueChanged", function(_, _, id)
        if id == nil or id == activeId then return end
        Helpers.SelectContainer(id)
    end)
    Helpers.AttachTooltip(dd, L["Container"], L[BANNER_TOOLTIP])
    ctx.__bannerWidget = dd
    return dd
end

--- Return the previous render's chrome widgets to AceGUI's pool — AFTER the render, because a
--- render is usually reached from one of their own callbacks.
local function releaseStaleChromeWidgets(ctx)
    local AceGUI = NS.AceGUI
    local stale = ctx.__staleChromeWidgets
    ctx.__staleChromeWidgets = nil
    if not (AceGUI and AceGUI.Release and stale) then return end
    for _, w in ipairs(stale) do AceGUI:Release(w) end
end

--- One orange line per thing the aura engine will silently not do for this container, above the
--- tab's rows (modules/FilterCompiler.lua's plan warnings).
function Helpers.RenderWarnings(ctx, cfg)
    local plan = NS.FilterCompiler.Compile(cfg, {
        timedSpells = NS.db and NS.db.global and NS.db.global.timedSpells,
    })
    for _, w in ipairs(plan.warnings or {}) do
        Helpers.TextRow(ctx, "|cffffa040" .. L[w] .. "|r")
    end
end

--- A container page's tabs: its schema groups in first-seen order, then the bespoke tabs the
--- container's aura type admits. No container, no tabs.
--- @return table tabs, table byGroup, table bespoke
local function collectTabs(cfg, pageKey, spec)
    local tabs, byGroup, bespoke = {}, {}, {}
    if not cfg then return tabs, byGroup, bespoke end
    for _, row in ipairs(NS.SchemaForPage(pageKey)) do
        if not byGroup[row.group] then
            byGroup[row.group] = {}
            tabs[#tabs + 1] = { key = row.group, label = row.group }
        end
        local rows = byGroup[row.group]
        rows[#rows + 1] = row
    end
    for _, t in ipairs(spec.tabs or {}) do
        if not t.auraTypes or t.auraTypes[cfg.auraType] then
            tabs[#tabs + 1] = { key = t.key, label = t.label }
            bespoke[t.key] = t
        end
    end
    return tabs, byGroup, bespoke
end

--- Keep the active tab when this render draws it; otherwise fall back to the first.
local function settleActiveTab(ctx, tabs)
    for _, t in ipairs(tabs) do
        if t.key == ctx.activeTab then return end
    end
    ctx.activeTab = tabs[1].key
end

--- The active tab's content, under the page's intro; the empty registry's one line instead.
local function renderActiveTab(ctx, cfg, spec, byGroup, bespoke)
    if not cfg then
        Helpers.TextRow(ctx, L["No containers yet. Create one on the Containers page, or type /am new."])
        return
    end
    if spec.intro then spec.intro(ctx, cfg) end
    local b = bespoke[ctx.activeTab]
    if b then
        b.render(ctx, cfg)
    elseif byGroup[ctx.activeTab] then
        Helpers.RenderRows(ctx, byGroup[ctx.activeTab], spec.afterGroup, nil, { noHeadings = true })
    end
end

--- Render one per-container page: the chrome block (the banner, or a host header), the tab strip
--- over the page's schema groups plus any bespoke tabs, and the active tab's content.
---
--- `spec` fields, all optional:
---   header(ctx, frame)   build the page's one chrome block instead of the plain banner
---   tabs                 { { key, label, render(ctx, cfg), auraTypes } } bespoke tabs, after the
---                        schema's own
---   intro(ctx, cfg)      drawn above every tab's content
---   afterGroup           the flow engine's { [group] = fn(ctx) } hooks
function Helpers.RenderContainerPage(ctx, pageKey, spec)
    spec = spec or {}
    Helpers.ClearScroll(ctx)
    local scroll = Helpers.EnsureScroll(ctx)

    ctx.__staleChromeWidgets = ctx.__chromeWidgets
    ctx.__chromeWidgets = {}
    ctx.__bannerWidget = nil
    if spec.header then
        Helpers.PageHeader(ctx, { height = Helpers.BANNER_H, build = function(_, frame) spec.header(ctx, frame) end })
    else
        Helpers.ContainerBanner(ctx)
    end

    local cfg = NS.ActiveContainer()
    local tabs, byGroup, bespoke = collectTabs(cfg, pageKey, spec)
    -- Every page draws a strip (options-ui-§13), including the empty registry's one-tab page.
    if tabs[1] == nil then tabs[1] = { key = "__empty", label = L["Container"] } end
    ctx.__tabs = tabs   -- test seam: which tabs this render drew
    settleActiveTab(ctx, tabs)

    Helpers.TabStrip(ctx, {
        tabs  = tabs,
        value = ctx.activeTab,
        onSelect = function(key)
            if key == ctx.activeTab then return end
            ctx.activeTab = key
            Helpers.RenderContainerPage(ctx, pageKey, spec)
        end,
    })

    renderActiveTab(ctx, cfg, spec, byGroup, bespoke)

    if scroll and scroll.DoLayout then scroll:DoLayout() end
    releaseStaleChromeWidgets(ctx)
end

-- Test seam: the ctx each per-container page built, by page key. The library keeps its registry
-- private, and a page whose ctx is unreachable is a page whose render is untested.
Helpers.__containerCtx = {}

--- Register a per-container settings page: the Blizzard subcategory, the lazily-drawn body, and a
--- page-wide Defaults button that restores the SELECTED container's rows on this page.
function NS.RegisterContainerPage(pageKey, title, frameName, spec)
    NS.RegisterOptionsPage(pageKey, title, function(mainCategory)
        if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
        local ctx = Helpers.CreatePanel(frameName, title, {
            pageKey         = pageKey,
            defaultsButton  = true,
            defaultsTooltip = L["Restore every setting on this page, for the selected container, to its default."],
        })
        ctx.panel.defaultsOnClick = function() Helpers.RestoreDefaults(pageKey, ctx) end
        Helpers.SetRenderer(ctx, function(c) Helpers.RenderContainerPage(c, pageKey, spec) end)
        Helpers.__containerCtx[pageKey] = ctx
        local cat = Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, title)
        categories[pageKey] = cat
        return cat
    end)
end
