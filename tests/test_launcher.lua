-- tests/test_launcher.lua — the launcher (launcher-§1..§5): the one broker object behind both
-- surfaces, the rung its left click sits on, the Minimap button row's inverting seam, the two
-- reserved verbs, and the degraded install with neither broker library.
--
-- The object, the click dispatch and the Show/Hide plumbing are LibKa0s-Launcher-1.0's and are
-- tested there (testing-§8). What is pinned here is the wiring this addon owns: the folder name it
-- registers under, the icon file it points at, WHICH state the left button drives, where the
-- visibility is stored, and which way round the row's sense runs.
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

local MINIMAP_PATH = "global.minimap.hide"

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

-- ── The rung ──────────────────────────────────────────────────────────────────────────────────

test("launcher: rung (b) — the LEFT click toggles the lock, through the addon's own write seam",
function()
    local NS2, rec = withBroker()
    local click = rec.objects.AuraMaster.OnClick
    assertTrue(type(click) == "function", "the object carries the one click implementation")

    NS2.SetByPath("locked", true)
    click(rec.objects.AuraMaster, "LeftButton")
    -- red under: an onClick that opened the settings panel instead (the panel is already on the
    -- right button, so that is a skipped rule rather than a design — anti-pattern #81).
    assertEqual(NS2.GetSetting("locked"), false, "unlocked, which IS this addon's preview")
    click(rec.objects.AuraMaster, "LeftButton")
    assertEqual(NS2.GetSetting("locked"), true)
end)

test("launcher: the left click holds no copy of the lock — it writes the path the checkbox writes",
function()
    local NS2, rec = withBroker()
    local click = rec.objects.AuraMaster.OnClick
    NS2.SetByPath("locked", true)

    -- Everything the seam does for the checkbox, it does for the click: the row's onChange, the
    -- CONFIG_CHANGED announcement, one [Set] line. Watch the bus, which is the observable one.
    local seen = {}
    NS2.bus:RegisterMessage(NS2.MSG.CONFIG_CHANGED, function(_, info)
        seen[#seen + 1] = info.path
    end)
    click(rec.objects.AuraMaster, "LeftButton")
    local sawLocked = false
    for _, p in ipairs(seen) do if p == "locked" then sawLocked = true end end
    assertTrue(sawLocked, "the click went through NS.SetByPath, not around it")
    -- The one stored record: the profile's `locked`, and nothing beside it.
    assertEqual(NS2.db.profile.locked, false)
end)

test("launcher: the RIGHT click opens the settings panel, whatever the left button does", function()
    local NS2, rec = withBroker()
    local opened = 0
    NS2.OpenOptionsPanel = function() opened = opened + 1 end
    local before = NS2.GetSetting("locked")
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "RightButton")
    assertEqual(opened, 1, "right-click ALWAYS opens the panel (launcher-§2)")
    -- red under: a right click that also toggled the rung's switch.
    assertEqual(NS2.GetSetting("locked"), before, "and changes nothing else")
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

test("minimap row: GLOBAL, so a profile switch and Reset all settings both leave the button alone",
function()
    local NS2 = withBroker()
    NS2.SetByPath(MINIMAP_PATH, false)
    assertEqual(NS2.db.global.minimap.hide, true)

    -- Reset all settings IS a profile reset (options-ui-§12), and the button is not in a profile.
    NS2.Helpers.RestoreAllDefaults()
    assertEqual(NS2.db.global.minimap.hide, true, "a reset must not un-hide a button they hid")
    assertEqual(NS2.GetSetting(MINIMAP_PATH), false)

    -- Nor may a profile switch: the ring of buttons is furniture, arranged once.
    NS2.db:SetProfile("Somebody Else")
    assertEqual(NS2.db.global.minimap.hide, true, "still hidden on another profile")
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

test("verbs: the launcher's click, the two verbs and the checkbox are three doors onto one write",
function()
    local NS2, rec = withBroker()
    -- The lock: the click and the two lock verbs.
    NS2.SetByPath("locked", true)
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "LeftButton")
    assertEqual(NS2.db.profile.locked, false)
    NS2.Slash:OnSlash("lock")
    assertEqual(NS2.db.profile.locked, true)
    -- red under: core/LauncherSetup.lua reaching past NS.Slash.SetLocked to write `locked` itself.
    assertTrue(type(NS2.Slash.SetLocked) == "function", "published for exactly one caller")
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
