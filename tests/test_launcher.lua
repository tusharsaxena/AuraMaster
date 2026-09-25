-- tests/test_launcher.lua — the launcher (launcher-§1..§5): the one broker object behind both
-- surfaces, its two buttons and the options menu's entries, the Minimap button row's inverting seam,
-- the two reserved verbs, and the degraded install with neither broker library.
--
-- The object, the click dispatch and the Show/Hide plumbing are LibKa0s-Launcher-1.0's and are
-- tested there (testing-§8). What is pinned here is the wiring this addon owns: the folder name it
-- registers under, the icon file it points at, WHICH toggles the right-click menu offers and which
-- handler each reaches, where the visibility is stored, and which way round the row's sense runs.
--
-- The two broker libraries are NOT vendored into the headless load list (they are `libs\` rows, and
-- tests/run.lua loads only the addon's own TOC files), so each case that needs a real registration
-- installs a recording fake through `fresh{ before = … }` — the same LibStub the client's would be,
-- answering the same two majors.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local NS = T.NS
local fresh = dofile("tests/fresh_env.lua")
local loadDegraded = dofile("tests/degraded_env.lua")

local MINIMAP_PATH = "global.minimap.shown"

--- A client with both broker libraries: an environment, plus the recorder they wrote into.
---
--- The fakes record rather than draw. What matters to this addon is WHAT it handed over — one
--- object, one name, one icon, one OnClick — not what LibDBIcon does with it afterwards.
local function withBroker(opts)
    local rec = { objects = {}, registered = {}, shown = {}, hidden = {} }
    opts = opts or {}
    local before = opts.before
    opts.before = function(mocks)
        local LDB = mocks.LibStub:NewLibrary("LibDataBroker-1.1", 4)
        LDB.NewDataObject = function(_, name, obj)
            if rec.objects[name] then return nil end
            rec.objects[name] = obj
            rec.order = (rec.order or 0) + 1
            obj.__name = name
            return obj
        end
        LDB.GetDataObjectByName = function(_, name) return rec.objects[name] end

        local Icon = mocks.LibStub:NewLibrary("LibDBIcon-1.0", 45)
        Icon.Register = function(_, name, obj, db)
            rec.registered[#rec.registered + 1] = { name = name, object = obj, db = db }
        end
        Icon.Show = function(_, name)
            rec.shown[#rec.shown + 1] = name
        end
        Icon.Hide = function(_, name)
            rec.hidden[#rec.hidden + 1] = name
        end

        if before then before(mocks) end
    end
    local NS2, mocks = fresh(opts)
    return NS2, rec, mocks
end

local function capture(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        lines[#lines + 1] = tostring(msg)
    end)
    return lines
end

-- ── The one object, registered twice ──────────────────────────────────────────────────────────

test("launcher: one broker object, of type launcher, registered with LibDBIcon under the FOLDER name",
function()
    local NS2, rec = withBroker()
    assertTrue(NS2.Launcher:IsRegistered(), "both halves wired")

    -- red under: a second LDB object, or a broker-only registration (anti-pattern #81).
    local names = {}
    for name in pairs(rec.objects) do
        names[#names + 1] = name
    end
    assertEqual(#names, 1, "exactly one data object")
    assertEqual(names[1], "AuraMaster", "the FOLDER name: LibDBIcon keys the saved position by it")
    assertEqual(rec.objects.AuraMaster.type, "launcher",
        "a display reads `type`; \"data source\" would promise a text value this object has not got")
    assertEqual(#rec.registered, 1)
    assertEqual(rec.registered[1].name, "AuraMaster", "the SAME name on both registrations")
    assertTrue(rec.registered[1].object == rec.objects.AuraMaster,
        "the very object LibDataBroker holds, not a copy")
end)

test("launcher: Register is idempotent, so a second call builds no second button", function()
    local NS2, rec = withBroker()
    -- The lifecycle already called it once (core/AuraMaster.lua's OnInitialize).
    assertEqual(#rec.registered, 1)
    assertTrue(NS2.Launcher:Register(), "a repeat call reports the launcher wired")
    assertTrue(NS2.Launcher:Register())
    -- red under: dropping the library's `if object and iconLib then return true end` guard — a
    -- second LibDBIcon:Register on a held name draws a second button over the first.
    assertEqual(#rec.registered, 1, "still one registration")
end)

test("launcher: the icon is this addon's own 128 logo — the file ## IconTexture names", function()
    local NS2, rec = withBroker()
    local want = "Interface\\AddOns\\AuraMaster\\media\\logos\\auramaster.logo.128.tga"
    assertEqual(NS2.Constants.LOGO_ICON_PATH, want)
    assertEqual(rec.objects.AuraMaster.icon, want, "one file, three places (launcher-§4)")

    -- The TOC names the same file, so the AddOns list, the minimap and a broker display agree.
    local toc = io.open("AuraMaster.toc", "r")
    local src = toc:read("*a")
    toc:close()
    assertTrue(src:find("## IconTexture: " .. want:gsub("\\", "%%\\"), 1, false) ~= nil
        or src:find("## IconTexture: " .. want, 1, true) ~= nil, "the TOC points at it")

    -- red under: a Blizzard path or a numeric file id (anti-pattern #82).
    assertFalse(want:find("Interface\\Icons", 1, true), "never a borrowed icon")
    -- And the landing page keeps its own, larger file: two files, two jobs (options-ui-§5).
    assertTrue(NS2.Constants.LOGO_PATH ~= NS2.Constants.LOGO_ICON_PATH)
end)

test("launcher: the icon file ships as an uncompressed 32-bit 128x128 TGA", function()
    -- An icon in the wrong format draws NOTHING and raises nothing, so no other gate would say so
    -- (layout-§4, anti-pattern #82). The header is read here because that is the only witness.
    local f = io.open("media/logos/auramaster.logo.128.tga", "rb")
    assertTrue(f ~= nil, "media/logos/auramaster.logo.128.tga exists")
    local head = f:read(18)
    local size = f:seek("end")
    f:close()
    assertEqual(#head, 18, "a TGA header is 18 bytes")
    assertEqual(head:byte(3), 2, "image type 2 — uncompressed true-color, never RLE (type 10)")
    assertEqual(head:byte(17), 32, "32 bits per pixel: convert(\"RGBA\") is what makes it so")
    local w = head:byte(13) + head:byte(14) * 256
    local h = head:byte(15) + head:byte(16) * 256
    assertEqual(w, 128)
    assertEqual(h, 128)
    assertEqual(size, 18 + 128 * 128 * 4 + 26, "header + pixels + Pillow's TGA footer")
end)

-- ── The two buttons (launcher-§2, LibKa0s-Launcher-1.0 minor 4) ─────────────────────────────────
--
-- Left-click opens the settings panel; right-click opens the client's context menu with one
-- checkbox per toggle this addon really has. The menu itself is the library's and tested there; what
-- is pinned here is WHICH entries this addon supplies and that each one reaches the SAME handler its
-- slash verb runs, so the refusals, the combat rules and the chat lines are the addon's.

--- A client with both broker libraries and the context-menu API (tests/mock_menu.lua), installed
--- after load: the library resolves `MenuUtil` on every right click, never at load.
local function withMenu(opts)
    local NS2, rec, mocks = withBroker(opts)
    local menu = dofile("tests/mock_menu.lua")(mocks)
    return NS2, rec, mocks, menu
end

--- Right-click the one object, as LibDBIcon's button would, and answer the menu that opened.
local function rightClick(rec, menu)
    local before = menu.opens
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "RightButton")
    assertEqual(menu.opens, before + 1, "the right click opened the context menu")
    return menu.last
end

--- The chat lines a call prints, color escapes stripped, in order.
local function printed(mocks, fn)
    local lines = capture(mocks)
    fn()
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
    return out
end

test("launcher: the descriptor passes the three toggle pairs this addon has, and no retired field",
function()
    local f = assert(io.open("core/LauncherSetup.lua", "r"))
    local src = f:read("*a")
    f:close()
    -- red under: a descriptor missing a pair — the menu draws only entries with BOTH halves
    for _, field in ipairs({ "isEnabled", "setEnabled", "isLocked", "toggleLock", "isTestMode",
        "toggleTestMode", "version" }) do
        assertTrue(src:find("\n%s*" .. field .. "%s*=%s*function") ~= nil, "descriptor." .. field)
    end
    -- No primary window (the preview is the test mode), so no Show window pair.
    assertNil(src:find("\n%s*isWindowShown%s*="), "no isWindowShown: this addon has no primary window")
    assertNil(src:find("\n%s*toggleWindow%s*="), "no toggleWindow")
    -- red under: dead configuration the library ignores since minor 4 (launcher-§5)
    for _, field in ipairs({ "onClick", "leftClickLabel", "disabledLine", "slash", "onTooltipShow" }) do
        assertNil(src:find("\n%s*" .. field .. "%s*="), "retired or unowed field " .. field)
    end
end)

test("launcher: the LEFT click opens the settings panel and changes nothing else", function()
    local NS2, rec = withMenu()
    local opened = 0
    NS2.OpenOptionsPanel = function() opened = opened + 1 end
    local locked, testMode = NS2.GetSetting("locked"), NS2.State.testMode
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "LeftButton")
    -- red under: a descriptor still routing the left button to the test mode (rung (b), retired)
    assertEqual(opened, 1, "left-click opens the panel (launcher-§2)")
    assertEqual(NS2.GetSetting("locked"), locked, "the lock is untouched")
    assertEqual(NS2.State.testMode, testMode, "the test mode is untouched")
end)

test("launcher: the LEFT click opens the panel while disabled too — it is where the addon is re-enabled",
function()
    local NS2, rec = withMenu()
    local opened = 0
    NS2.OpenOptionsPanel = function() opened = opened + 1 end
    NS2.SetByPath("enabled", false)
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "LeftButton")
    assertEqual(opened, 1, "no refusal on the left button since Launcher minor 4")
    assertFalse(NS2.State.testMode, "and no feature ran")
end)

test("launcher menu: titled with the brand, entries Enabled, Locked, Test mode, in that order", function()
    local NS2, rec, _, menu = withMenu()
    local opened = 0
    NS2.OpenOptionsPanel = function() opened = opened + 1 end
    local m = rightClick(rec, menu)
    assertEqual(m.titles[1], "Ka0s Aura Master", "the plain-text label")
    -- red under: a missing pair, or a Show window entry for a window this addon does not have.
    -- The row the standard's ADDONS.md records for this addon: Enabled · Locked · Test mode.
    assertEqual(table.concat(m:Texts(), " | "), "Enabled | Locked | Test mode")
    assertEqual(opened, 0, "the menu opened instead of the panel")
end)

test("launcher menu: every checkbox reads the live state when the menu opens", function()
    local NS2, rec, _, menu = withMenu()
    NS2.SetByPath("locked", true)
    local m = rightClick(rec, menu)
    assertTrue(m:Checked("Enabled"))
    assertTrue(m:Checked("Locked"))
    assertFalse(m:Checked("Test mode"))
    NS2.SetByPath("locked", false)
    NS2.Slash.ToggleTestMode()
    -- red under: an accessor reading a copy captured at New
    m = rightClick(rec, menu)
    assertFalse(m:Checked("Locked"))
    assertTrue(m:Checked("Test mode"))
end)

test("launcher menu: Enabled calls the enable/disable handler, and prints what /am disable prints",
function()
    local NS2, rec, mocks, menu = withMenu()
    -- By routing: the host's handler, handed the state it moves TO.
    local asked = {}
    local real = NS2.Slash.SetEnabled
    NS2.Slash.SetEnabled = function(on)
        local n = #asked
        asked[n + 1] = tostring(on)
        return real(on)
    end
    local viaMenu = printed(mocks, function() rightClick(rec, menu):Click("Enabled") end)
    NS2.Slash.SetEnabled = real
    -- red under: setEnabled wired to NS.SetByPath directly, past the verb's handler
    assertEqual(table.concat(asked, ","), "false", "one call, moving to disabled")
    assertFalse(NS2.db.profile.enabled, "the SAME stored path the checkbox and the verb write")
    -- By effect: the verb's own words, byte for byte.
    NS2.SetByPath("enabled", true)
    local viaVerb = printed(mocks, function() NS2.Slash:OnSlash("disable") end)
    assertEqual(table.concat(viaMenu, "\n"), table.concat(viaVerb, "\n"), "the menu and /am disable say one thing")
    assertTrue(#viaMenu >= 1, "and it said something")
    -- And back on, from the disabled state: Enabled stays live.
    rightClick(rec, menu):Click("Enabled")
    assertTrue(NS2.db.profile.enabled, "Enabled re-enables from the menu")
end)

test("launcher menu: Locked calls the lock/unlock handler, and prints what /am unlock prints", function()
    local NS2, rec, mocks, menu = withMenu()
    NS2.SetByPath("locked", true)
    local calls = 0
    local real = NS2.Slash.ToggleLock
    NS2.Slash.ToggleLock = function() calls = calls + 1 return real() end
    local viaMenu = printed(mocks, function() rightClick(rec, menu):Click("Locked") end)
    NS2.Slash.ToggleLock = real
    assertEqual(calls, 1, "one call to the host's toggle")
    assertFalse(NS2.GetSetting("locked"), "unlocked")
    NS2.SetByPath("locked", true)
    local viaVerb = printed(mocks, function() NS2.Slash:OnSlash("unlock") end)
    -- red under: toggleLock writing the setting itself, with no confirmation line
    assertEqual(table.concat(viaMenu, "\n"), table.concat(viaVerb, "\n"), "the menu and /am unlock say one thing")
    rightClick(rec, menu):Click("Locked")
    assertTrue(NS2.GetSetting("locked"), "and the next click locks again")
end)

test("launcher menu: Test mode calls the /am test handler, through the switch the checkbox uses", function()
    local NS2, rec, mocks, menu = withMenu()
    local calls, switched = 0, {}
    local real, set = NS2.Slash.ToggleTestMode, NS2.Preview.SetTestMode
    NS2.Slash.ToggleTestMode = function() calls = calls + 1 return real() end
    NS2.Preview.SetTestMode = function(on)
        local n = #switched
        switched[n + 1] = tostring(on)
        return set(on)
    end
    local viaMenu = printed(mocks, function() rightClick(rec, menu):Click("Test mode") end)
    NS2.Slash.ToggleTestMode, NS2.Preview.SetTestMode = real, set
    -- red under: core/LauncherSetup.lua writing NS.State.testMode itself
    assertEqual(calls, 1, "one call to the verb's handler")
    assertEqual(table.concat(switched, ","), "true", "one call to the one writer of the mode")
    assertTrue(NS2.State.testMode)
    assertNil(rawget(NS2.db.profile, "testMode"), "nothing stored")
    local viaVerb = printed(mocks, function() NS2.Slash:OnSlash("test") end)
    assertFalse(NS2.State.testMode)
    local again = printed(mocks, function() rightClick(rec, menu):Click("Test mode") end)
    assertEqual(table.concat(again, "\n"), table.concat(viaMenu, "\n"), "the same line each time it turns on")
    assertTrue(#viaVerb >= 1)
end)

test("launcher menu: while disabled, Locked and Test mode are grayed and Enabled stays live", function()
    local NS2, rec, _, menu = withMenu()
    NS2.SetByPath("enabled", false)
    local m = rightClick(rec, menu)
    assertEqual(table.concat(m:Texts(), " | "),
        "Enabled | Locked (enable the addon first) | Test mode (enable the addon first)")
    assertTrue(m:Find("Enabled").enabled, "Enabled is live")
    assertFalse(m:Find("Locked").enabled, "Locked is grayed")
    assertFalse(m:Find("Test mode").enabled, "Test mode is grayed")
    -- A grayed entry the client dispatched anyway calls no handler (the library's gate).
    local reached = 0
    NS2.Slash.ToggleTestMode = function() reached = reached + 1 end
    m:ForceClick("Test mode")
    assertEqual(reached, 0, "a grayed Test mode reached the handler")
    assertFalse(NS2.State.testMode)
end)

test("launcher menu: on a client without MenuUtil the right click opens the settings panel", function()
    local NS2, rec, _, menu = withMenu()
    menu.remove()
    local opened = 0
    NS2.OpenOptionsPanel = function() opened = opened + 1 end
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "RightButton")
    -- The panel holds every toggle the menu would have.
    assertEqual(opened, 1, "the degraded right click")
end)

-- ── The status tooltip (launcher-§1, LibKa0s-Launcher-1.0 minor 3; hints since minor 4) ─────────
--
-- The library draws the block; this addon only answers its questions. What is pinned here is which
-- questions it answers (the lock and the test mode it really has), through which accessor. The
-- shape itself, the click hints included, is the library's and tested there.

--- The descriptor's tooltip, drawn into a recording GameTooltip, color escapes stripped.
local function hover(rec)
    local lines = {}
    local tt = {}
    function tt.AddLine(_, text)
        local n = #lines
        lines[n + 1] = tostring(text)
    end
    rec.objects.AuraMaster.OnTooltipShow(tt)
    for i, line in ipairs(lines) do
        lines[i] = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end
    return lines
end

--- A TOC reader answering Version = `v`, installed at call time as tests/test_envsetup.lua does.
local function tocVersion(mocks, v)
    mocks.C_AddOns = { GetAddOnMetadata = function(_, field)
        if field == "Version" then return v end
        return nil
    end }
end

test("launcher tooltip: enabled, locked, test mode off — the whole block, in the library's order",
function()
    local NS2, rec, mocks = withBroker()
    tocVersion(mocks, "9.8.7")
    NS2.SetByPath("locked", true)
    local lines = hover(rec)
    -- red under: `version` reading core/Namespace.lua's constant instead of the TOC (9.8.7 here)
    assertEqual(table.concat(lines, "\n"), table.concat({
        "Ka0s Aura Master  v9.8.7",
        "Enabled: Yes",
        "Locked: Yes",
        "Test mode: Off",
        "Left-click: Open settings",
        "Right-click: Options menu",
    }, "\n"))
end)

test("launcher tooltip: every state is read on the show — unlock and test mode change the next hover",
function()
    local NS2, rec = withBroker()
    NS2.SetByPath("locked", false)
    NS2.Slash.ToggleTestMode()
    assertTrue(NS2.State.testMode, "test mode on through the one switch")
    local lines = hover(rec)
    -- red under: an accessor reading a copy, or a value captured at New
    assertEqual(lines[3], "Locked: No")
    assertEqual(lines[4], "Test mode: On")
    NS2.Slash.ToggleTestMode()
    assertEqual(hover(rec)[4], "Test mode: Off")
end)

test("launcher tooltip: shown while disabled, with the same two hints", function()
    local NS2, rec = withBroker()
    NS2.SetByPath("locked", true)
    NS2.SetByPath("enabled", false)
    local lines = hover(rec)
    -- red under: no isEnabled passed (the line would read Yes), or no tooltip while disabled, which
    -- is when the player most needs to ask.
    assertEqual(lines[2], "Enabled: No")
    assertEqual(lines[3], "Locked: Yes", "the status lines still draw")
    assertEqual(lines[4], "Test mode: Off")
    assertEqual(lines[5], "Left-click: Open settings", "the left button is never refused")
    assertEqual(lines[6], "Right-click: Options menu")
    assertEqual(#lines, 6)
end)

-- ── The Minimap button row ────────────────────────────────────────────────────────────────────

test("minimap row: composed, stored not session, default SHOWN, in its canonical position", function()
    local row = NS.FindSchemaRow(MINIMAP_PATH)
    assertTrue(row ~= nil, "the composer emitted it from `minimapPath`")
    assertEqual(row.group, NS.Helpers.MASTER_GROUP)
    assertEqual(row.type, "bool")
    assertEqual(row.label, "Minimap button")
    -- red under: `sessionOnly = true`. A hidden button is furniture the player arranged, not a
    -- thing a reload ends (launcher-§3).
    assertNil(row.sessionOnly)
    assertEqual(row.default, true, "the row's own sense: SHOWN")
    -- The path is VERBATIM and unprefixed: the table is outside the block's profile prefix.
    assertEqual(row.path, MINIMAP_PATH)
end)

test("minimap row: the seam inverts — the row says shown, LibDBIcon's key says hidden", function()
    local NS2, rec = withBroker()
    assertEqual(NS2.db.global.minimap.hide, false, "declared in defaults/Profile.lua, global store")
    assertEqual(NS2.GetSetting(MINIMAP_PATH), true, "get: not hide")

    assertTrue(NS2.SetByPath(MINIMAP_PATH, false))
    -- red under: a seam that stored the row's value straight. The button and the checkbox would
    -- then disagree the first time the player used LibDBIcon's own menu (anti-pattern #81).
    assertEqual(NS2.db.global.minimap.hide, true, "set: hide = not value")
    assertEqual(NS2.GetSetting(MINIMAP_PATH), false)
    assertEqual(rec.hidden[#rec.hidden], "AuraMaster", "and the button moved NOW, not at next reload")

    assertTrue(NS2.SetByPath(MINIMAP_PATH, true))
    assertEqual(NS2.db.global.minimap.hide, false)
    assertEqual(rec.shown[#rec.shown], "AuraMaster")

    -- THE SEAM'S OWN WRITE, on its own. The library's SetShown writes the same key with the
    -- same value, so with the launcher present either one alone would keep this case green;
    -- drop it and only the seam is left to do the inverting.
    NS2.Launcher = nil
    assertTrue(NS2.SetByPath(MINIMAP_PATH, false))
    assertEqual(NS2.db.global.minimap.hide, true, "the seam inverts; the library is not what does it")
    assertEqual(NS2.GetSetting(MINIMAP_PATH), false)
end)

test("minimap row: one record of one state — LibDBIcon writes the very table the row writes", function()
    local NS2, rec = withBroker()
    assertTrue(rec.registered[1].db == NS2.db.global.minimap,
        "the table handed to :Register is the stored one, not a copy")
    -- LibDBIcon writes minimapPos into it when the player drags the button; a write through the
    -- row must leave that alone (architecture-§5).
    rec.registered[1].db.minimapPos = 217
    NS2.SetByPath(MINIMAP_PATH, false)
    assertEqual(NS2.db.global.minimap.minimapPos, 217, "the drag survives the checkbox")
    -- red under: a parallel `show` or `showMinimapIcon` beside `hide`.
    for key in pairs(NS2.db.global.minimap) do
        assertTrue(key == "hide" or key == "minimapPos", "unexpected key: " .. tostring(key))
    end
end)

test("minimap row: Reset all settings and a profile switch both leave the button alone", function()
    local NS2 = withBroker()
    NS2.SetByPath(MINIMAP_PATH, false)
    assertEqual(NS2.db.global.minimap.hide, true)

    -- SURVIVING A RESET IS A PROPERTY OF THE SETTING (launcher-§3, standard v2.54.0), not something
    -- derived from the global store. That this particular reset misses it BECAUSE it is a profile
    -- reset is true here and is worth pinning, but it is not the reason it must — the page's own
    -- Defaults button is a reset the same argument says nothing about, and the case below runs it.
    NS2.Helpers.RestoreAllDefaults()
    assertEqual(NS2.db.global.minimap.hide, true, "a reset must not un-hide a button they hid")
    assertEqual(NS2.GetSetting(MINIMAP_PATH), false)

    -- Nor may a profile switch: the ring of buttons is furniture, arranged once.
    NS2.db:SetProfile("Somebody Else")
    assertEqual(NS2.db.global.minimap.hide, true, "still hidden on another profile")
end)

test("minimap row: the General page's Defaults button leaves the button alone and resets the rest",
function()
    local NS2, rec, mocks = withBroker()
    NS2.SetByPath(MINIMAP_PATH, false)
    NS2.SetByPath("hideBlizzardBuffs", true)
    NS2.SetByPath("alpha", 0.25)
    local shownBefore, hiddenBefore = #rec.shown, #rec.hidden

    -- THE BUTTON A PLAYER PRESSES, not the library call behind it.
    mocks.__subcategories.General.defaultsOnClick()

    -- red under: dropping settings/OptionsSetup.lua's `vetoedFromPanelReset`. The minimap row IS a
    -- General row and it declares `default = true` (SHOWN), so the page's walk reached it and one
    -- press un-hid a button the player had deliberately hidden. Measured before the veto existed.
    assertEqual(NS2.db.global.minimap.hide, true, "a page's Defaults must not un-hide it either")
    assertEqual(NS2.GetSetting(MINIMAP_PATH), false, "and the checkbox still shows what they chose")
    assertEqual(#rec.shown, shownBefore, "nothing told LibDBIcon to put the button back")
    assertEqual(#rec.hidden, hiddenBefore, "and nothing moved it the other way either")

    -- ONE ROW EXEMPTED, not a Defaults button turned off: every other General row came back.
    assertFalse(NS2.db.profile.hideBlizzardBuffs)
    assertEqual(NS2.db.profile.alpha, NS2.defaults.profile.alpha)

    -- A SHOWN button is not re-hidden by the same press (launcher-§3's other direction).
    NS2.SetByPath(MINIMAP_PATH, true)
    hiddenBefore = #rec.hidden
    mocks.__subcategories.General.defaultsOnClick()
    assertEqual(NS2.db.global.minimap.hide, false)
    assertEqual(#rec.hidden, hiddenBefore)
end)

test("minimap row: /am set and /am reset reach it through the same seam, inverted the same way",
function()
    local NS2, _, mocks = withBroker()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("set " .. MINIMAP_PATH .. " false")
    assertEqual(NS2.db.global.minimap.hide, true)
    NS2.Slash:OnSlash("reset " .. MINIMAP_PATH)
    -- The default is derived from the ONE declaration and inverted, never typed as `true` twice.
    assertEqual(NS2.DefaultFor(MINIMAP_PATH), true)
    assertEqual(NS2.db.global.minimap.hide, false, "reset restores the shipped default: shown")
    assertTrue(#lines >= 0)
end)

-- ── The two reserved verbs ────────────────────────────────────────────────────────────────────

test("verbs: /am enable and /am disable are aliases of the Enable row's path, holding no state",
function()
    local NS2, _, mocks = withBroker()
    capture(mocks)
    local row = NS2.FindSchemaRow("enabled")
    assertTrue(row ~= nil and row.group == NS2.Helpers.MASTER_GROUP, "the Master controls Enable row")

    NS2.Slash:OnSlash("disable")
    assertEqual(NS2.db.profile.enabled, false, "the SAME stored path the checkbox writes")
    assertEqual(NS2.GetSetting("enabled"), false)
    NS2.Slash:OnSlash("enable")
    assertEqual(NS2.db.profile.enabled, true)

    -- red under: a verb keeping its own flag. Move the store under it and the verbs must follow.
    NS2.SetByPath("enabled", false)
    assertEqual(NS2.GetSetting("enabled"), false, "no second copy anywhere")
    NS2.Slash:OnSlash("enable")
    assertEqual(NS2.db.profile.enabled, true)
end)

test("verbs: the dispatcher answers while the addon is disabled, or the pair is one-way", function()
    local NS2, _, mocks = withBroker()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("disable")
    assertEqual(NS2.db.profile.enabled, false)

    -- slash-commands-§2: a player who turned the addon off must be able to turn it back on. Every
    -- verb still runs — the disabled state hides containers, it does not unregister the dispatcher.
    for k in pairs(lines) do lines[k] = nil end
    NS2.Slash:OnSlash("enable")
    assertEqual(NS2.db.profile.enabled, true, "/am enable works from the disabled state")

    NS2.Slash:OnSlash("disable")
    local opened = 0
    NS2.OpenOptionsPanel = function() opened = opened + 1 end
    NS2.Slash:OnSlash("")
    assertEqual(opened, 1, "a bare /am opens the panel while disabled (slash-commands-§4)")
    for k in pairs(lines) do lines[k] = nil end
    NS2.Slash:OnSlash("help")
    assertTrue(#lines > 1, "/am help answers too")
    NS2.Slash:OnSlash("enable")
    assertEqual(NS2.db.profile.enabled, true)
end)

test("verbs: the launcher's menu, /am test and the Test mode checkbox are three doors onto one switch",
function()
    local NS2, rec, _, menu = withMenu()
    rightClick(rec, menu):Click("Test mode")
    assertTrue(NS2.State.testMode)
    NS2.Slash:OnSlash("test off")
    assertFalse(NS2.State.testMode)
    NS2.SetByPath("state.testMode", true)
    assertTrue(NS2.State.testMode)
    -- red under: core/LauncherSetup.lua reaching past the published verb handlers
    for _, name in ipairs({ "SetEnabled", "ToggleLock", "ToggleTestMode" }) do
        assertTrue(type(NS2.Slash[name]) == "function", "NS.Slash." .. name .. " published for the menu")
    end
end)

-- ── The degraded install ──────────────────────────────────────────────────────────────────────

test("launcher: a host with neither broker library does not raise, and still records the choice",
function()
    -- tests/run.lua's own environment IS that host: the two libraries are `libs\` rows the headless
    -- load list does not carry, so this is a real absence, not a simulated one.
    assertTrue(NS.Launcher ~= nil, "the instance exists; only the registration could not happen")
    assertFalse(NS.Launcher:IsRegistered())
    assertNil(NS.Launcher:Object())
    assertFalse(NS.Launcher:Register(), "and says so rather than raising")

    -- The store is still the truth, so the checkbox shows what the player chose and a reload that
    -- finds the libraries draws the button where they left it.
    assertEqual(NS.GetSetting(MINIMAP_PATH), true)
    assertTrue(NS.SetByPath(MINIMAP_PATH, false))
    assertEqual(NS.db.global.minimap.hide, true)
    assertEqual(NS.GetSetting(MINIMAP_PATH), false)
    assertTrue(NS.SetByPath(MINIMAP_PATH, true))
    assertEqual(NS.db.global.minimap.hide, false)
end)

test("launcher: with LibDataBroker but no LibDBIcon, the broker plugin still exists", function()
    local rec = { objects = {} }
    local NS2 = fresh({ before = function(mocks)
        local LDB = mocks.LibStub:NewLibrary("LibDataBroker-1.1", 4)
        LDB.NewDataObject = function(_, name, obj) rec.objects[name] = obj; return obj end
        LDB.GetDataObjectByName = function(_, name) return rec.objects[name] end
    end })
    -- `false` is the honest answer: the section's headline surface, the button, is not there.
    assertFalse(NS2.Launcher:IsRegistered())
    assertTrue(NS2.Launcher:Object() ~= nil, "a broker display still draws the row")
    assertEqual(rec.objects.AuraMaster.type, "launcher")
    -- And the row still works, because the store is the record.
    assertTrue(NS2.SetByPath(MINIMAP_PATH, false))
    assertEqual(NS2.db.global.minimap.hide, true)
end)

test("launcher: with LibKa0s absent the stub answers every member, and the row still stores", function()
    local NS2 = loadDegraded()
    assertTrue(NS2.Launcher ~= nil, "core/LauncherSetup.lua published a stub, not nil")
    assertFalse(NS2.Launcher:IsRegistered())
    assertNil(NS2.Launcher:Object())
    assertFalse(NS2.Launcher:Register())
    -- No database in this environment (degraded_env never calls InitDB), so IsShown answers the
    -- shipped default rather than nil: a checkbox handed nil draws unset and would lie.
    assertEqual(NS2.Launcher:IsShown(), true)
    NS2.db = { global = { minimap = { hide = false } } }
    assertFalse(NS2.Launcher:SetShown(false), "there is no button to move")
    assertEqual(NS2.db.global.minimap.hide, true, "but the choice was recorded")
    assertEqual(NS2.Launcher:IsShown(), false)
end)

test("parity: the Launcher stub carries every member of the live instance", function()
    local NS2 = loadDegraded()
    T.assertSurfaceParity(NS2.Launcher, "LibKa0s-Launcher-1.0", {})
end)
