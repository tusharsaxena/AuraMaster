local _, NS = ...

-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0 (options-ui-§1).
--
-- The canvas shell, the schema-row → AceGUI makers, the two-column flow engine, the chrome band and
-- the tabbed page itself -- the strip, the stale-tab heal, the tab switch, the disabled notice and
-- the page banner with its create button -- are the library's (O.RenderTabbedSchema, O.PageBanner).
-- This file is the part that is ours: where a value lives, which rows belong to which page, what a
-- color looks like on disk -- and the CONTAINER BANNER every per-container page shares, with
-- Helpers.RenderPage, which maps this addon's page spec onto the library's tabbed page.
--
-- Loads after settings/Slash.lua and BEFORE every settings/<page>.lua, because those files call
-- the composers (NS.Helpers.FontGroup, …) at FILE LOAD.

local L = NS.L
local print = NS.Print

local PARENT_TITLE = "Ka0s Aura Master"

-- THE ONE ROW NO RESET THIS PANEL RUNS MAY TOUCH (launcher-§3, standard v2.54.0).
--
-- Whether the minimap button is shown is a PER-INSTALLATION DISPLAY PREFERENCE, the same class of
-- thing as the POSITION LibDBIcon keeps in the very same table and that no reset in the collection
-- touches. Nobody has ever wanted "reset my settings" to mean "and put the button back on my
-- minimap". That is a property of the setting, and it does NOT follow from the row living in the
-- global store: *Reset all settings* here is a profile reset and misses it for that reason, but this
-- page's own DEFAULTS button walks every General row carrying a `default` and reached it — the row
-- is on General, it declares `default = true` (shown), so one press un-hid a button the player had
-- deliberately hidden. Measured, not assumed: `Helpers.RestoreDefaults("general")` did exactly that
-- before this veto existed.
--
-- The veto is the descriptor's `applyDefault`, which is the library's SINGLE reset seam — both
-- O.RestoreDefaults (a page's Defaults) and O.RestoreAllDefaults call it and nothing else — so one
-- clause covers both resets and any reset walk added later. `/am reset global.minimap.shown` is NOT
-- vetoed and must not be: that is the player naming this one row, which is how they bring a hidden
-- button back, and settings/Slash.lua's descriptor carries its own applyDefault for exactly that.
local MINIMAP_PATH = NS.MINIMAP_PATH -- settings/Schema.lua spells it once; it loads first

local function vetoedFromPanelReset(row)
    return row.path == MINIMAP_PATH
end

-- The one rule about what a global reset must not touch, named once because it is enforced twice:
-- by the library through skipRestoreAll, and by the degradation stub's own reset loop. It vetoes
-- the minimap row (above), the Profiles page and every profile-backed row (options-ui-§12): the
-- global reset IS a profile reset, so what the walk keeps is only what a profile reset cannot
-- reach — the session rows.
local function vetoedFromResetAll(row)
    if vetoedFromPanelReset(row) then return true end
    if row.page == "profiles" then return true end
    return not row.sessionOnly
end

-- ---------------------------------------------------------------------
-- The nesting mark
-- ---------------------------------------------------------------------
--
-- Blizzard's Settings tree draws every canvas subcategory of one addon at the SAME depth, and this
-- addon's pages are not one flat set: Filters, Layout, Bars and Icons all edit the container that
-- Containers has selected, while General, Containers and Profiles edit the addon (or, for
-- Containers, the registry of containers itself) and never retarget when the picker moves.
-- Four pages presented as peers of the three that never retarget is the tree lying about what a
-- click will change (N-2).
--
-- There is no API for a third level, so the mark is TYPOGRAPHY, copied from the established pattern
-- in MultiMeters (D6, `MultiMeters/settings/OptionsSetup.lua:91`) rather than invented fresh here:
-- two spaces, a hyphen and a space, prefixed to the tree label ONLY. It is deliberately not part of
-- the page's own title -- the canvas heading and the breadcrumb keep the plain name, because a page
-- heading that starts indented reads as a layout bug.
--
-- THE INDENT DOES THE NESTING; THE HYPHEN MARKS THE ITEM. MultiMeters recorded two earlier spellings
-- that got one of those and not the other, and both failed in their own way (a hollow box where the
-- font had no glyph for a rightward arrow, and a bare "|- " that read as a bulleted list rather than
-- as nesting) -- reasons enough to keep copying the working spelling rather than choosing a new one.
--
-- Whitespace was confirmed in MultiMeters's own client to survive -- leading whitespace is the kind
-- of thing a UI toolkit trims, and this one does not -- which is what makes the hyphen safe to add:
-- it is decoration on an indent that is already doing the work, rather than the only thing standing
-- in for it.
--
-- Not a locale string. It is furniture rather than text, and a translator handed two spaces and a
-- hyphen has nothing to translate and one more chance to drop a space.
local SUBPAGE_MARK = "  - "

--- The tree label for a page nested under Containers.
---
--- Used by the four container pages (Filters, Layout, Bars, Icons) at the
--- RegisterCanvasLayoutSubcategory call and nowhere else. General, Containers and Profiles do NOT
--- call it: none of them is about one container, and marking them would make the mark mean nothing.
--- A helper rather than the literal at each call site so every caller stays exactly one string away
--- from the decision, and a future page that becomes (or stops being) a sub-page changes one call.
---
--- @param name string  the page's own display name
--- @return string
function NS.SubPageLabel(name)
    return SUBPAGE_MARK .. tostring(name)
end

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

--- What the PANEL shows for `path`. A row may carry `panelGet()`, answering the value to show in
--- place of the stored one, or nil to show what is stored: Layout's Fill and growth rows show the
--- flow an attached container inherits (L-6). Only the panel reads through here — /am get
--- (settings/Slash.lua's own descriptor) and every module read the store — so what is written and
--- what a detach restores stay the container's own.
local function panelRead(path)
    local row = NS.FindSchemaRow(path)
    if row and row.panelGet then
        local shown = row.panelGet()
        if shown ~= nil then return shown end
    end
    return NS.GetSetting(path)
end

local descriptor = {
    parentTitle   = PARENT_TITLE,
    mainPanelName = "AuraMasterMainPanel",

    print = function(line) print(line) end,
    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

    get          = panelRead,
    -- A refusal that carries its row's own reason (the Text template's parser) is printed, the same
    -- two lines `/am set` prints: the panel's EditBox re-reads the stored value on refresh, so the
    -- reason is the only trace of why the typed one did not stick. A bare refusal stays silent, as it
    -- always has.
    set          = function(path, value)
        local ok, err, why = NS.SetByPath(path, value)
        if not ok and why then
            print(err)
            print("  " .. why)
        end
    end,
    -- THE PANEL'S ONE RESET SEAM, and therefore where the minimap veto lives (above).
    applyDefault = function(row)
        if vetoedFromPanelReset(row) then return end
        NS.ApplyDefault(row)
    end,
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
    -- tooltip names the equivalence options-ui-§12 asks for: "the same thing Profiles → Reset Profile does"
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
-- /am set and the profile defaults — silently vanishes. So this stub publishes, real enough to
-- finish the load, every member a page file touches at load (measured by deleting one and
-- re-running tests/degraded_env.lua), plus the recovery reset. Every other function member of the
-- live instance, the host's own decorations included, is carried too, as a no-op or one honest
-- line: load-completing narrows what a member does, never which members exist (testing-§8). What
-- it never carries is a copy of the library: no widget maker's body, no flow engine, no header, no
-- LAYOUT or composer constant, no AceGUI, no media lister.
--
-- The composers answer AN EMPTY ROW LIST (options-ui-§1, v2.64.0 of the standard): the page files
-- finish loading and register their own hand-written rows, and every composed block is simply absent
-- from this build's schema. A host copy of a composed block here is anti-pattern #73 -- the copy
-- that drifts from the library it stands in for. The two master paths the host verbs still write,
-- `enabled` and `locked`, reach the seam through settings/Schema.lua's NS.WRITE_THROUGH instead of
-- through a row (route (a)); `/am set` on any composed path answers the library-absent line.
-- tests/test_surface_parity.lua pins the member set against the live instance;
-- tests/test_optionssetup.lua pins the full count, the library-absent count and the named delta.
-- Each per-container page's style gate (`spec.disabledFor`), by page key, recorded on both arms so
-- a library-less build still knows it: modules/Diagnostics.lua reads it to tell a stored value the
-- container's style leaves unused from one in use (B9 DX-2). One source: the page's own predicate.
NS.ContainerPageDisabledFor = NS.ContainerPageDisabledFor or {}
local function recordContainerPage(pageKey, spec)
    NS.ContainerPageDisabledFor[pageKey] = type(spec) == "table" and spec.disabledFor or nil
end

if not lib then
    local function sayMissing() NS.Printf(L["%s, so the settings panel is unavailable."], NS.LIBKA0S_MISSING) end
    local Helpers = {}
    NS.Helpers = Helpers

    -- Every composer answers an empty row list: the composed block is the library's, and a build
    -- without the library has none (options-ui-§1; a copy here is anti-pattern #73).
    local function noRows() return {} end
    Helpers.ColorPair   = noRows
    Helpers.FontGroup   = noRows
    Helpers.BorderGroup = noRows
    Helpers.BarGroup    = noRows

    -- The literal options-ui-§15 mandates; settings/General.lua reads it by name, so both builds
    -- answer it.
    Helpers.MASTER_GROUP = "Master controls"
    Helpers.MasterControls = function() return {}, function() end end

    -- Kept although it is reached at call time: `/am resetall` is a recovery path, and the player
    -- whose panel will not open is the one who needs it.
    -- One bulk act, like the library's: the session rows are written muted, and the profile reset
    -- is logged once, by NS.OnProfileReset (debug-logging-§10). The act says it reset the profile on
    -- `info`, the BulkRun contract (settings/Schema.lua's NS.Bulk).
    Helpers.RestoreAllDefaults = function()
        NS.Bulk.Run("reset", "all", function(info)
            for _, row in ipairs(NS.Schema or {}) do
                if not vetoedFromResetAll(row) then NS.ApplyDefault(row) end
            end
            local db = NS.db
            if not (db and db.ResetProfile) then return end
            db:ResetProfile()
            info.profileReset = true
        end)
    end

    -- Reached only from a builder, a render or a user action, and a library-less build draws no
    -- panel, so a no-op is the honest answer (options-ui-§1). Every function member of the live
    -- instance is here, the host decorations below the `return` included, so no call site finds a
    -- member missing (testing-§8, tests/test_surface_parity.lua).
    for _, name in ipairs({
        -- refreshers and resets
        "RefreshAllPanels", "RefreshScalars", "RefreshPanel", "RestoreDefaults",
        -- panel shell and registration
        "CreatePanel", "RegisterOptionsPage", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll",
        "PatchAlwaysShowScrollbar", "SetChromeHeight", "SetRenderer", "BuildLandingPage",
        -- renderers and widget makers
        "RenderRows", "RenderGrid", "RenderField", "RenderSchema", "RenderTabbedSchema", "Section",
        "AddSpacer", "TextRow", "TabStrip", "SubTabStrip", "PageHeader", "PageBanner",
        "InlineButtonPair", "SessionCheckbox", "AttachTooltip", "ChoiceGrid", "ResolveId", "IdInput",
        "IdList", "UnnamedCandidates", "SelectTab",
        -- this addon's decorations on the live instance (defined below the `return`)
        "SelectContainer", "ContainerBanner", "RenderWarnings", "RenderPage", "RenderContainerPage",
    }) do
        Helpers[name] = function() end
    end
    -- The one table member the ID widgets add: the hint strings a host tooltip may quote. The host
    -- keeps its own localized copy, so an empty table is the inert answer.
    Helpers.ID_NAME_HINT = {}
    Helpers.CreateOptionsPanel = sayMissing
    Helpers.OpenOptionsPanel = sayMissing

    NS.RegisterOptionsPage = function() end
    NS.RefreshOptionsPanel = function() end
    NS.CreateOptionsPanel  = function() sayMissing() end
    NS.OpenOptionsPanel    = function() sayMissing() end
    NS.OpenOptionsPage     = function() sayMissing() end
    NS.RegisterContainerPage = function(pageKey, _, _, spec) recordContainerPage(pageKey, spec) end
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

-- Every Blizzard subcategory a page registered, by page key, so NS.OpenOptionsPage can jump there
-- and the frame picker can bring the player back to the page it started from. Filled by EVERY
-- registered page, not only container pages (N-3): a builder that returns nothing (the
-- library-less stub path, or a build that bails before Settings.RegisterCanvasLayoutSubcategory
-- exists) simply leaves that key unset, and NS.OpenOptionsPage falls back to the main panel.
local categories = {}

NS.RegisterOptionsPage = function(key, name, builder)
    Helpers.RegisterOptionsPage(key, name, function(mainCategory)
        local cat = builder(mainCategory)
        if cat then categories[key] = cat end
        return cat
    end)
end
NS.CreateOptionsPanel  = function() Helpers.CreateOptionsPanel() end
NS.OpenOptionsPanel    = function() Helpers.OpenOptionsPanel() end
NS.RefreshOptionsPanel = function() Helpers.RefreshAllPanels() end

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

--- The picker's entries: every container, labeled with what it shows, by name (B2-2).
local function containerList()
    local list, order = {}, {}
    for _, c in ipairs(NS.Database.GetContainersByName()) do
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
---
--- `opts` (optional) = { tooltip, action }. The Containers page passes its own tooltip and its create
--- act as `action`, which O.PageBanner draws in the band's right half, level with the picker: the
--- picker+create band options-ui-§14 describes, drawn by the library rather than by this file.
--- The library keeps the Dropdown and the Button and gives both back to AceGUI once the next band
--- is drawn (LibKa0s OptionsTabs minor 4), so this file holds neither.
function Helpers.ContainerBanner(ctx, opts)
    opts = opts or {}
    local list, order = containerList()
    local _, activeId = NS.ActiveContainer()
    return Helpers.PageBanner(ctx, {
        label    = L["Container"],
        tooltip  = opts.tooltip or L[BANNER_TOOLTIP],
        list     = list,
        order    = order,
        value    = activeId,
        onSelect = function(id)
            if id == nil or id == activeId then return end
            Helpers.SelectContainer(id)
        end,
        action   = opts.action,
    })
end

--- One orange line per thing the aura engine will silently not do for this container, above the
--- tab's rows (modules/FilterCompiler.lua's plan warnings).
function Helpers.RenderWarnings(ctx, cfg)
    local plan = NS.FilterCompiler.Compile(cfg, NS.FilterCompiler.ProfileContext())
    for _, w in ipairs(plan.warnings or {}) do
        Helpers.TextRow(ctx, "|cffffa040" .. L[w] .. "|r")
    end
end

-- ---------------------------------------------------------------------------
-- The tabbed page: this addon's page spec, mapped onto the library's
-- ---------------------------------------------------------------------------

--- The notice over a page drawn disabled, in the addon's muted red (C.NOTICE_COLOR). The library
--- draws it, in the small font with the ordinary row gap under it, and adds no color of its own.
---
--- It was large orange (GameFontNormalLarge, |cffffa040) across the whole pane until batch 8, which
--- shouted a full-width warning for what is an informational aside — nothing is wrong, the page is
--- simply inert until the player changes one dropdown elsewhere. Gray at the default Label size is
--- the same voice the addon already uses for a line that reports rather than warns (the combat
--- refusals in settings/Containers.lua print in this exact gray), and it leaves orange meaning what
--- it means everywhere else in the panel: RenderWarnings' "the game will not honor this", which can
--- sit on the very same page and must still be the loudest thing on it. The owner then asked for it
--- in a muted gold (2026-09-19, B3): the gray read as disabled text rather than as a note, and a gold
--- quieter than the title's is still no warning. Later the same day the owner asked for muted red
--- instead (Task 20), on bars, icons and text pages alike; the combat refusals keep their gray.
local function mutedNotice(notice, cfg)
    if type(notice) == "function" then notice = notice(cfg) end
    if type(notice) ~= "string" then return nil end
    return "|c" .. C.NOTICE_COLOR .. notice .. "|r"
end

-- The page key an empty registry's render hands the library: no row carries it, so the strip it
-- draws is the one placeholder tab below and nothing else (options-ui-§13: every page draws a strip).
local EMPTY_PAGE = "__empty"
local EMPTY_TABS = { {
    key    = "__empty",
    label  = L["Container"],
    render = function(ctx) Helpers.TextRow(ctx, L["No containers yet. Create one on Containers, or type /am new."]) end,
} }

--- The page's own tabs as the library takes them: those the container's aura type admits, each
--- handed the container as well as its rows. One keyed by a schema group takes that group's place
--- and is handed its rows; one with `before` is drawn ahead of the tab it names (LibKa0s Options
--- 24.31.4.7.4, `opts.tabs`).
local function hostTabs(spec, cfg)
    local out = {}
    for _, t in ipairs(spec.tabs or {}) do
        if not t.auraTypes or (cfg and t.auraTypes[cfg.auraType]) then
            local render, n = t.render, #out
            out[n + 1] = {
                key = t.key, label = t.label, tooltip = t.tooltip, before = t.before,
                render = function(ctx, rows) return render(ctx, cfg, rows) end,
            }
        end
    end
    return out
end

--- The library's `opts` for one render of a page with a container (or an addon-wide page).
local function pageOpts(spec, cfg)
    local disabledFor, notice, intro = spec.disabledFor, spec.disabledNotice, spec.intro
    local opts = { tabs = hostTabs(spec, cfg), cfg = cfg }
    if disabledFor then opts.disabledFor = function(c) return c ~= nil and disabledFor(c) end end
    if notice then opts.disabledNotice = function(c) return mutedNotice(notice, c) end end
    if intro and cfg then opts.chrome = function(c) intro(c, cfg) end end
    return opts
end

--- Render one tabbed page through the library's O.RenderTabbedSchema: the optional `banner(ctx)`
--- first (the strip reserves its band under it), then the strip over the page's schema groups and
--- its own tabs, then the active tab's content. The library owns the partition, the stale-tab heal,
--- the tab-switch re-render, the disabled notice and the release of the banner's widgets; this
--- wrapper owns only what the page spec means for this addon. General and Containers call it
--- directly; every per-container page through RenderContainerPage, which passes the container
--- banner. A per-container page with no container draws the empty registry's one tab and line.
---
--- `spec` fields, all optional:
---   addonWide            the page's tabs do not depend on a container existing (General)
---   tabs                 { { key, label, render(ctx, cfg, rows), auraTypes, before } }: the page's
---                        own tabs, drawn when the container's aura type is in `auraTypes` (or it
---                        has none); one keyed by a schema group replaces that group's rows, one
---                        with `before` is drawn ahead of the tab it names
---   intro(ctx, cfg)      drawn above every tab's content, when a container is selected
---   disabledFor(cfg)     true draws every control of every tab disabled (a page tab's widgets
---                        through `ctx.__renderDisabled`), under `disabledNotice` (a string, or a
---                        function of cfg answering one), drawn as a small muted-red note
---   afterGroup           the flow engine's { [group] = fn(ctx) } hooks
---   pairWith             the flow engine's { [path] = maker(ctx, rowGroup) } right-half partners
function Helpers.RenderPage(ctx, pageKey, spec, banner)
    spec = spec or {}
    Helpers.ClearScroll(ctx)
    local scroll = Helpers.EnsureScroll(ctx)
    if banner then banner(ctx) end
    local cfg = NS.ActiveContainer()
    if cfg or spec.addonWide then
        Helpers.RenderTabbedSchema(ctx, pageKey, spec.afterGroup, spec.pairWith, pageOpts(spec, cfg))
    else
        Helpers.RenderTabbedSchema(ctx, EMPTY_PAGE, nil, nil, { tabs = EMPTY_TABS })
    end
    if scroll and scroll.DoLayout then scroll:DoLayout() end
end

--- Render one per-container page: the container banner (options-ui-§14), then the tabbed page.
function Helpers.RenderContainerPage(ctx, pageKey, spec)
    Helpers.RenderPage(ctx, pageKey, spec, Helpers.ContainerBanner)
end

-- Test seam: the ctx each tabbed page built, by page key. The library keeps its registry private,
-- and a page whose ctx is unreachable is a page whose render is untested.
Helpers.__pageCtx = {}

--- Register a per-container settings page: the Blizzard subcategory, the lazily-drawn body, and a
--- page-wide Defaults button that restores the SELECTED container's rows on this page.
---
--- Every caller of this helper (Filters, Layout, Bars, Icons, Text) is a sub-page of Containers (N-2), so
--- the tree label it registers under always carries NS.SubPageLabel's mark. `title` itself stays
--- plain: it is what CreatePanel draws as the canvas heading and the breadcrumb, and D6 marks the
--- tree entry only, never the page's own name.
function NS.RegisterContainerPage(pageKey, title, frameName, spec)
    recordContainerPage(pageKey, spec)
    NS.RegisterOptionsPage(pageKey, title, function(mainCategory)
        if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
        local ctx = Helpers.CreatePanel(frameName, title, {
            pageKey         = pageKey,
            defaultsButton  = true,
            defaultsTooltip = L["Restore every setting on this page, for the selected container, to its default."],
        })
        ctx.panel.defaultsOnClick = function() Helpers.RestoreDefaults(pageKey, ctx) end
        Helpers.SetRenderer(ctx, function(c) Helpers.RenderContainerPage(c, pageKey, spec) end)
        Helpers.__pageCtx[pageKey] = ctx
        -- categories[pageKey] is recorded by the NS.RegisterOptionsPage wrapper above, from
        -- whatever this builder returns (N-3) — no need to set it here too.
        -- NS.SubPageLabel is applied unconditionally here, so EVERY container page nests under
        -- Containers (true for all five callers today); a future container page that should NOT
        -- nest would need its own registration path, not a call through this helper.
        return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, NS.SubPageLabel(title))
    end)
end
