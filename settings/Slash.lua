local _, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash

-- settings/Slash.lua — NS.COMMANDS and the LibKa0s-Slash-1.0 descriptor (slash-commands).
--
-- The dispatcher, the help renderer, the key/value formatters, the list builder and the type-aware
-- value parser are the library's. What stays here is what is genuinely ours: the ordered verb
-- table, the host verbs that reach into this addon's own state, and the note appended to a
-- container setting saying WHICH container it read.
--
-- NS.COMMANDS is passed INTO the library rather than owned by it: the landing page renders the
-- same table (settings/About.lua), and a library that owned it would force the options library to
-- consume this one — two libraries reaching for each other is a real dependency cycle.
--
-- Entries are positional triples {name, desc, fn}; a table of named fields is invisible to the
-- library and every verb becomes unknown.

local L = NS.L
local print = NS.Print
-- The formatting printer, captured the same way: this file loads after core/AuraMaster.lua has
-- reclaimed both from AceConsole. A whole sentence goes in as one L[...] key with %s slots, and the
-- printer formats it over secret-safe arguments (events-frames-taint-§8).
local printf = NS.Printf

local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
-- Built at the bottom, once NS.COMMANDS exists; every handler reaches it at CALL time.
local cli

local runEnabled, runResetAll, runContainers, runSelect, runNew, runDelete, runLock, runPick
local runResetPosition, runForgetTimed, runDebug, runPerf

NS.COMMANDS = {
    {"help",          L["List available commands"],
        function() cli:PrintHelp() end},
    {"config",        L["Open the settings panel"],
        function() NS.OpenOptionsPanel() end},
    {"enable",        L["Turn Aura Master on (every enabled container shows again)"],
        function() runEnabled(true) end},
    {"disable",       L["Turn Aura Master off (hides every container)"],
        function() runEnabled(false) end},
    {"list",         L["List every setting and its current value (container settings read the selected container)"],
        function() cli:CliList() end},
    {"get",           L["Print a setting's current value — /am get path"],
        function(rest) cli:CliGet(rest) end},
    {"set",           L["Set a setting — /am set path value (try /am list)"],
        function(rest) cli:CliSet(rest) end},
    {"reset",         L["Reset one setting to its default — /am reset path"],
        function(rest) cli:CliReset(rest) end},
    {"resetall",      L["Reset every setting to defaults"],
        function() runResetAll() end},
    {"containers",    L["List your containers; the selected one is marked"],
        function() runContainers() end},
    {"select",        L["Choose the container settings apply to — /am select id or name"],
        function(rest) runSelect(rest) end},
    {"new",           L["Create a container — /am new [player|target|focus|pet] [buffs|debuffs|enchants] [bars|icons]"],
        function(rest) runNew(rest) end},
    {"delete",        L["Delete a container — /am delete id or name"],
        function(rest) runDelete(rest) end},
    {"lock",          L["Lock every container in place"],
        function() runLock(true) end},
    {"unlock",        L["Unlock containers so they can be dragged (shows placeholder auras)"],
        function() runLock(false) end},
    {"pick",          L["Attach the selected container to a frame by clicking it"],
        function() runPick() end},
    {"resetposition", L["Move every container back to its default screen position"],
        function() runResetPosition() end},
    {"forgettimed",   L["Forget which buffs were learned to have a duration"],
        function() runForgetTimed() end},
    {"debug",         L["Toggle the debug console — on/off enable or disable logging"],
        function(rest) runDebug(rest) end},
    {"perf",          L["Measure performance — try /am perf for the workflow"],
        function(rest) runPerf(rest) end},
    {"version",       L["Print the addon version"],
        function() printf("v%s", NS.Version()) end},
}

-- ---------------------------------------------------------------------------
-- The disabled gate (slash-commands-§2)
-- ---------------------------------------------------------------------------
--
-- DISABLED means the addon stands its FEATURES down — every container is hidden, nothing is drawn.
-- A verb that drives those features is therefore asking for something the addon is currently not
-- doing, and acting on it anyway is wrong twice over: the player does not get what they asked for,
-- and a silent no-op leaves them with no clue why. So such a verb answers on ONE tagged line that
-- names `/am enable`, and does nothing else. One line is the whole courtesy.
--
-- ONE PLACE, AND IT IS THE VERB TABLE ITSELF. Every dispatch path in this addon ends at an entry's
-- `entry[3]` — the library's dispatcher calls it, and so does the degradation stub's own OnSlash
-- below — so wrapping the handlers here gates both surfaces with no second copy and no per-verb
-- guard. A guard pasted into each verb is a dozen places to forget, and the NEXT verb added forgets
-- it by default; here the default runs the other way, and a new verb is gated unless the set below
-- names it.
--
-- THE LIVE SET IS DATA, NAMED ONCE. slash-commands-§2's own list is the floor — a player must be
-- able to READ AND REPAIR SETTINGS and REACH THE PANEL while the addon is off, which is exactly
-- when they are most likely to need to, and `enable` above all or the pair is one-way. `debug` and
-- `perf` are diagnostics rather than features: the usual reason to reach for either is that the
-- addon is misbehaving.
local LIVE_WHILE_DISABLED = {
    help = true, config = true, version = true, enable = true, disable = true,
    debug = true, perf = true,
    get = true, set = true, list = true, reset = true, resetall = true,
    -- TWO MORE THAN THE SECTION NAMES, and the reason is this addon's path model. Almost every
    -- schema path here is container-relative (`container.bars.width`) and resolves against the
    -- SELECTED container, so `/am containers` and `/am select` are how a player AIMS get, set and
    -- reset at the container they mean — they are part of reading and repairing settings, not
    -- features. Neither draws, hides, creates or deletes anything: `containers` prints a list, and
    -- `select` moves one integer of session state. §2's list is what a refusal may never be turned
    -- on, not a ceiling on what stays live.
    containers = true, select = true,
}

--- Whether the addon is standing its features down. EXPLICITLY false only: before core/Database.lua
--- builds NS.db the read answers nil, and reading nil as "off" would refuse every feature verb on a
--- load that has not finished.
local function standingDown()
    return NS.GetSetting("enabled") == false
end

for _, entry in ipairs(NS.COMMANDS) do
    if not LIVE_WHILE_DISABLED[entry[1]] then
        local run = entry[3]
        entry[3] = function(rest)
            -- One line, and NOTHING else: no partial work, no side effect, no second line.
            if standingDown() then return print(L["Aura Master is off — /am enable turns it back on"]) end
            return run(rest)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Host verbs
-- ---------------------------------------------------------------------------

local C = NS.Constants

local function firstWord(rest)
    return ((rest or ""):match("^%s*(%S*)") or ""):lower()
end

--- A container by id or by name (case-insensitive), or nil. A name more than one container answers
--- to — a profile saved before names were kept unique case-insensitively — is refused rather than
--- guessed: nil, the ambiguity sentence and the name as typed, for the caller to printf.
local function findContainer(arg)
    arg = (arg or ""):match("^%s*(.-)%s*$")
    if arg == "" then return nil end
    local id = tonumber(arg)
    if id then return NS.Database.FindContainer(id) end
    local want, found = arg:lower(), nil
    for _, c in ipairs(NS.Database.GetContainers()) do
        if type(c.name) == "string" and c.name:lower() == want then
            if found then
                return nil, L["More than one container is called '%s' — use its number from /am containers."], arg
            end
            found = c
        end
    end
    return found
end

--- The line for a lookup that found nothing: the ambiguity sentence when there is one.
local function sayNotFound(ambiguous, name)
    if ambiguous then return printf(ambiguous, name) end
    print(L["No such container — /am containers lists them"])
end

-- The fields are one localized string per state (localization-§1), so a translator can reorder
-- them and the status tag; only the name and the gray markup around the fields stay outside.
local function describe(c)
    local fields = c.enabled and L["#%s - %s - %s - %s"] or L["#%s - %s - %s - %s - disabled"]
    return ("%s  |cff888888%s|r"):format(NS.SafeToString(c.name or "?"), fields:format(tostring(c.id),
        L[C.UNIT_LABELS[c.unit] or tostring(c.unit)],
        L[C.AURA_TYPE_LABELS[c.auraType] or tostring(c.auraType)],
        L[C.STYLE_LABELS[c.style] or tostring(c.style)]))
end

local function afterRegistryChange()
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end

-- The gray combat refusal (options-ui-§2's canonical shape).
local function refuse(line) printf("|cff808080%s|r", line) end

-- The master switch, through the same seam as General → Master controls' "Enable Aura Master" and
-- `/am set enabled`: the [Set] line, CONFIG_CHANGED and the visibility pass. Not refused in combat —
-- the pass flips each engine through its own SetEnabled, which is combat-legal.
function runEnabled(on)
    local ok, err = NS.SetByPath("enabled", on)
    if not ok then return print(err) end
    print(on and L["Aura Master enabled"] or L["Aura Master disabled — /am enable turns it back on"])
end

function runResetAll()
    -- Not refused in combat: this is Profiles → Reset Profile (options-ui-§12), which takes the
    -- parked teardown there. The acknowledgment lives INSIDE the guard: on a load where
    -- settings/OptionsSetup.lua never ran there is nothing to delegate to, and printing it anyway
    -- would claim work that did not happen.
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
        -- The same keys the General page's Reset Profile prints: one message, one key (F-018).
        print(L["All settings reset to defaults."])
    else
        print(L["Cannot reset settings — the settings helpers failed to load."])
    end
end

function runContainers()
    local list = NS.Database.GetContainers()
    local count = #list
    if count == 0 then return print(L["No containers yet — /am new creates one"]) end
    local _, activeId = NS.ActiveContainer()
    print(L["Containers"])
    for _, c in ipairs(list) do
        printf("  %s %s", c.id == activeId and "|cff33ff99>|r" or " ", describe(c))
    end
end

function runSelect(rest)
    local c, ambiguous, name = findContainer(rest)
    if not c then return sayNotFound(ambiguous, name) end
    NS.State.SetActiveContainer(c.id)
    afterRegistryChange()
    printf(L["Selected %s"], describe(c))
end

-- The words `/am new` understands, each mapped onto the stored value it means.
local NEW_WORDS = {
    player = { unit = "player" }, target = { unit = "target" }, focus = { unit = "focus" },
    pet = { unit = "pet" },
    buff = { auraType = "HELPFUL" }, buffs = { auraType = "HELPFUL" },
    debuff = { auraType = "HARMFUL" }, debuffs = { auraType = "HARMFUL" },
    enchant = { auraType = "ENCHANT" }, enchants = { auraType = "ENCHANT" },
    bars = { style = "bars" }, bar = { style = "bars" },
    icons = { style = "icons" }, icon = { style = "icons" },
}

function runNew(rest)
    local overrides = {}
    for word in (rest or ""):gmatch("%S+") do
        local spec = NEW_WORDS[word:lower()]
        if not spec then
            return printf(L["Unknown word '%s' — try /am new target debuffs icons"], word)
        end
        for k, v in pairs(spec) do overrides[k] = v end
    end
    local id, err, refused = NS.ContainerManager.Create(overrides)
    if not id then
        if refused then return refuse(err) end
        return print(err or L["Could not create a container"])
    end
    NS.State.SetActiveContainer(id)
    afterRegistryChange()
    printf(L["Created %s"], describe(NS.Database.FindContainer(id)))
end

function runDelete(rest)
    if InCombatLockdown() then
        return refuse(L["cannot delete a container during combat — its display cannot be torn down until combat ends"])
    end
    local c, ambiguous, typed = findContainer(rest)
    if not c then return sayNotFound(ambiguous, typed) end
    local name = c.name
    local ok, err = NS.ContainerManager.Delete(c.id)
    if not ok then return print(err) end
    afterRegistryChange()
    printf(L["Deleted '%s'"], name)
end

function runLock(locked)
    NS.SetByPath("locked", locked)
    print(locked and L["Containers locked"] or L["Containers unlocked — drag a container by its handle"])
end

function runPick()
    local c, id = NS.ActiveContainer()
    if not c then return print(L["No containers yet — /am new creates one"]) end
    if InCombatLockdown() then
        return printf("|cff808080%s|r", L["cannot pick a frame during combat — attaching to a frame waits until combat ends"])
    end
    printf(L["Point at a frame and left-click to attach '%s'. Right-click or Escape cancels."], c.name)
    NS.FramePicker.Start(function(name)
        NS.SetByPath("container.attach.frame", name, id)
        NS.SetByPath("container.attach.mode", "frame", id)
        printf(L["'%s' is now attached to %s"], c.name, name)
    end, function()
        print(L["Frame pick canceled"])
    end)
end

function runResetPosition()
    NS.ContainerManager.ResetPositions()
    print(L["Container positions reset"])
end

function runForgetTimed()
    NS.TimedSpells.Forget()
    print(L["Forgot every learned timed buff; they are relearned out of combat"])
end

-- /am debug        toggles the console WINDOW (the logging flag is untouched).
-- /am debug on|off enables or disables session logging through the one SetEnabled seam.
function runDebug(rest)
    local word = firstWord(rest)
    if word == "on" or word == "off" then
        NS.DebugLog:SetEnabled(word == "on")
        return
    end
    NS.DebugLog:Toggle()
end

-- `perf` is a reserved verb the ADDON registers (performance-§4); the harness returns lines and
-- this prints them with the addon's own tag.
function runPerf(rest)
    for _, line in ipairs(NS.Perf.OnCommand(rest or "")) do print(line) end
end

-- ---------------------------------------------------------------------------
-- The degradation stub
-- ---------------------------------------------------------------------------
--
-- Degrade, never error: `/am` is registered unconditionally, so something must answer it. The
-- host verbs never went to the library and keep working; the schema verbs name the missing
-- library instead of going quiet. The stub keeps only a minimal "/am verb — desc" join, so the
-- landing page and `/am help` still list the verbs; nothing else of the library is copied here — no
-- parser, no `key = value` shape.
if not SlashLib then
    SlashLib = { FormatRow = function(cmd, desc) return cmd .. " — " .. desc end }

    function SlashLib.New(_, d)
        local stub = { SetRowAnnotator = function() end }
        local function absent(verb)
            return function() printf(L["/am %s is unavailable. %s."], verb, NS.LIBKA0S_MISSING) end
        end
        for _, verb in ipairs({ "List", "Get", "Set", "Reset" }) do
            stub["Cli" .. verb] = absent(verb:lower())
        end
        stub.LandingRows = function()
            local out = {}
            for _, e in ipairs(d.commands) do
                out[#out + 1] = SlashLib.FormatRow("/am " .. e[1], e[2])
            end
            return out
        end
        stub.PrintHelp = function()
            printf(L["v%s — slash commands"], d.version())
            for _, row in ipairs(stub.LandingRows()) do printf("  %s", row) end
        end
        -- The verb by name, or nil. Bare /am runs `config` (slash-commands-§4), as the library's
        -- dispatcher does since Slash minor 11; with no `config` it falls back to the help list.
        local function verb(name)
            for _, e in ipairs(d.commands) do
                if e[1] == name then return e end
            end
        end
        stub.OnSlash = function(_, msg)
            local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
            if raw == "" then
                local config = verb("config")
                if config then return config[3]("") end
                return stub.PrintHelp()
            end
            local cmd, rest = raw:match("^(%S+)%s*(.*)$")
            cmd = (cmd or ""):lower()
            cmd = (d.aliases or {})[cmd] or cmd
            local e = verb(cmd)
            if e then return e[3](rest or "") end
            printf(L["Unknown command '%s'"], cmd)
            stub.PrintHelp()
        end
        return stub
    end
end

-- ---------------------------------------------------------------------------
-- The dispatcher
-- ---------------------------------------------------------------------------

local function colorDecode(c)
    if type(c) ~= "table" then c = {} end
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

--- A value as `/am get|set|list|reset` echo it. A row marked `printLabel` (the Filters categories)
--- prints the label the panel shows, Show / Hide, with the stored value that `/am set` takes after
--- it in gray; every other row prints as the library formats it. The hook replaces the library's
--- formatter outright, colorDecode included, so a color is decoded here.
local function formatValue(row, v)
    if type(row) == "table" and row.printLabel then
        for _, choice in ipairs(row.values or {}) do
            if choice.value == v then
                return ("%s |cff808080(%s)|r"):format(choice.text, tostring(v))
            end
        end
    end
    if type(row) == "table" and row.type == "color" and type(v) == "table" then
        local r, g, b, a = colorDecode(v)
        return SlashLib.FormatValue(row, { r = r, g = g, b = b, a = a })
    end
    return SlashLib.FormatValue(row, v)
end

cli = SlashLib:New({
    slash        = "/am",
    slashAliases = { "/auramaster" },
    commands     = NS.COMMANDS,
    aliases      = { options = "config" },

    print   = function(line) print(line) end,
    version = function() return NS.Version() end,

    -- The schema seams. SetByPath rather than a bare write, so a CLI change takes the path a panel
    -- change takes — the [Set] line, the row's onChange, CONFIG_CHANGED and the panel re-sync.
    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, v)
        local ok, err = NS.SetByPath(path, v)
        if not ok and err then print(err) end
    end,
    findRow      = function(path) return NS.FindSchemaRow(path) end,
    -- A row with no meaningful default (the container name's `noReset`) is refused with a reason:
    -- say it, or `/am reset` would echo the unchanged value as if the reset had worked.
    applyDefault = function(row)
        local ok, why = NS.ApplyDefault(row)
        if ok == false and why then print(why) end
    end,
    allRows      = function() return NS.Schema end,
    groupKey     = function(row) return row.page end,
    -- The same bulk pair the Options descriptor takes (LibKa0s-Slash minor 8): CliResetAll writes
    -- through the seam muted and logs one `[Set] reset all: N rows` line (debug-logging-§10).
    bulkBegin    = function(...) NS.Bulk.Begin(...) end,
    bulkEnd      = function(...) NS.Bulk.End(...) end,

    colorDecode = colorDecode,
    colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
    format      = formatValue,
})

-- A `container.` value is the SELECTED container's, and a CLI line that did not say which would
-- read as the only one. Gray, so it stays subordinate to the gold key and white value.
cli:SetRowAnnotator(function(row)
    if type(row) == "table" and type(row.path) == "string" and row.path:find("^container%.") then
        local c = NS.ActiveContainer()
        if c then return "  |cff808080(" .. tostring(c.name) .. ")|r" end
    end
    return ""
end)

-- Published for introspection (read by tests/run.lua and tests/test_surface_parity.lua).
Sl.__cli = cli

--- The command list the landing page renders — the same rows `/am help` prints, without the chat
--- indent.
function Sl.LandingRows() return cli:LandingRows() end

function Sl.OnSlash(_, msg) cli:OnSlash(msg) end

--- Lock or unlock every container -- what `/am lock` and `/am unlock` run, published so the
--- launcher's left click (core/LauncherSetup.lua, rung (b)) drives the SAME write and prints the
--- same line. The lock is stored once, by NS.SetByPath; nothing here holds a copy of it.
function Sl.SetLocked(locked) runLock(locked) end

function Sl.Register()
    NS.addon:RegisterChatCommand("am", function(msg) Sl:OnSlash(msg) end)
    NS.addon:RegisterChatCommand("auramaster", function(msg) Sl:OnSlash(msg) end)
end
