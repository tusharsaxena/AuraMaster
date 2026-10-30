-- tests/test_layers.lua — frame layering (frame-layering-§1 to §5, the 2026-10-24 strata run, item
-- 030): the one layers table in core/Constants.lua (NS.Constants.LAYERS) and the strata, level and
-- parent-alpha of every frame class the addon draws, read back through the kit's frame-layer recorder
-- (tests/_kit/mock_layers.lua), plus the player strata row's tooltip (O.StrataTooltip).

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local DH = dofile("tests/drag_helpers.lua")

--- A fresh environment whose every frame records its layers: the recorder is installed before
--- anything loads, so the containers built at login carry it too.
local function layered()
    local restore
    local NS, mocks = fresh({ before = function(m) restore = dofile("tests/_kit/mock_layers.lua")(m) end })
    return NS, mocks, restore
end

-- ── the table ─────────────────────────────────────────────────────────────────────────────────

test("layers: one table, NS.Constants.LAYERS, with the standard's tier keys and this addon's bands", function()
    local LY = T.NS.Constants.LAYERS
    -- red under: no layers table (strata and levels scattered as literals over seven files)
    assertTrue(type(LY) == "table" and type(LY.STRATA) == "table" and type(LY.LEVEL) == "table")
    assertEqual(LY.STRATA.HUD, "MEDIUM", "a container's default tier")
    assertEqual(LY.STRATA.POPUP, "FULLSCREEN_DIALOG", "the drag-time snap highlight")
    assertEqual(LY.STRATA.CURSOR, "TOOLTIP", "the frame picker, which labels the frame under the cursor")
    local V = LY.LEVEL
    -- The display's band (frame-layering-§3): label < outline < handle, over the content. The TEST
    -- marker's band (40) went with the marker (D-14 of the 2026-10-30 skin fonts run).
    assertTrue(V.CONTENT < V.LABEL and V.LABEL < V.OUTLINE and V.OUTLINE < V.HANDLE,
        "content < label < outline < handle")
    assertEqual(V.LABEL, 20); assertEqual(V.OUTLINE, 30); assertEqual(V.HANDLE, 50)
    assertTrue(V.MARKER == nil, "no marker band")
    -- Inside one element, from the element root: fill < spark < border < dispel edge < overlay.
    assertTrue(V.FILL < V.SPARK and V.SPARK < V.BORDER and V.BORDER < V.DISPEL and V.DISPEL < V.OVERLAY,
        "fill < spark < border < dispel < overlay")
    assertTrue(V.OVERLAY < V.LABEL - 1, "an element's whole band sits under the label")
    assertEqual(V.GLOW_GAP, 3, "the glow twins' gap, unchanged")
end)

test("layers: no literal strata and no absolute level in core, modules or settings (frame-layering-§3, §5)", function()
    local found = {}
    for _, path in ipairs(T.loadedAddonFiles) do
        if path:match("^core/") or path:match("^modules/") or path:match("^settings/") then
            local fh = assert(io.open(path, "r"))
            local n = 0
            for line in fh:lines() do
                n = n + 1
                local code = line:gsub("%-%-.*$", "")
                -- red under: FramePicker's SetFrameStrata("TOOLTIP"), or a SetFrameLevel(40)
                if code:find('SetFrameStrata%(%s*"') or code:find("SetFrameLevel%(%s*%d") then
                    found[#found + 1] = path .. ":" .. n
                end
            end
            fh:close()
        end
    end
    assertEqual(table.concat(found, ", "), "")
end)

-- ── a container's frames ──────────────────────────────────────────────────────────────────────

test("layers: an unlocked container's chrome sits at its named bands over the anchor; the strip ignores the container's alpha", function()
    local NS, mocks, restore = layered()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("container.label.show", true, 1)
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local V = NS.Constants.LAYERS.LEVEL
    local L = mocks.__layers(inst.anchor)
    assertEqual(L.strata, "MEDIUM", "the layout's default strata")
    assertEqual(L.level, NS.CONTAINER_TEMPLATE.layout.level, "the layout's level, the band's base")
    -- red under: the label host at the anchor + 1, tied with the engine (AUR-Z04)
    assertEqual(mocks.__layers(inst.label).level, L.level + V.LABEL, "label")
    -- red under: the outline left at its implicit anchor + 1 (AUR-Z03)
    assertEqual(mocks.__layers(inst.outline).level, L.level + V.OUTLINE, "outline")
    local h = mocks.__layers(inst.handle)
    assertEqual(h.level, L.level + V.HANDLE, "handle")
    -- red under: the strip fading with layout.alpha × Master opacity (AUR-Z12, frame-layering-§2)
    assertTrue(h.ignoreParentAlpha, "the strip ignores the container's alpha")
    -- AUR-Z06 was not accepted: the strip keeps the container's strata, never one of its own.
    assertFalse(h.fixedStrata, "no strata of its own")
    NS.SetByPath("container.layout.strata", "LOW", 1)
    mocks.__fireTimers()
    assertEqual(mocks.__layers(inst.anchor).strata, "LOW", "the player's pick reaches the anchor")
    assertEqual(mocks.__layers(inst.handle).strata, "LOW", "and its chrome inherits it")
    restore()
end)

-- ── one element's frames ──────────────────────────────────────────────────────────────────────

--- Dress a fresh element root at level 10 in `style`.
local function element(NS, mocks, style)
    local c = NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE)
    c.style = style
    local frame = mocks.CreateFrame("Button", nil, mocks.UIParent)
    frame:SetFrameLevel(10)
    NS.Style.Element(frame, c, false)
    return frame.__am
end

test("layers: a bar's fill, spark, borders and texts each sit at their own band over the element (AUR-Z02)", function()
    local NS, mocks, restore = layered()
    local V = NS.Constants.LAYERS.LEVEL
    local am = element(NS, mocks, "bars")
    local lv = function(f) return mocks.__layers(f).level end
    assertEqual(lv(am.bar), 10 + V.FILL, "the bar")
    assertEqual(lv(am.sparkClip), 10 + V.SPARK, "the spark's clip")
    -- red under: the borders left at the button + 1, tied with the bar whose fill covers them
    assertEqual(lv(am.border), 10 + V.BORDER, "the border")
    assertEqual(lv(am.iconBorder), 10 + V.BORDER, "the icon's border")
    assertEqual(lv(am.text), 10 + V.OVERLAY, "the texts")
    restore()
end)

test("layers: an icon's swipe, border, dispel edge and texts each sit at their own band over the element (AUR-Z02)", function()
    local NS, mocks, restore = layered()
    local V = NS.Constants.LAYERS.LEVEL
    local am = element(NS, mocks, "icons")
    local lv = function(f) return mocks.__layers(f).level end
    -- red under: the swipe left at its implicit level (frame-layering-§3: given an explicit one)
    assertEqual(lv(am.cd), 10 + V.FILL, "the cooldown swipe")
    assertEqual(lv(am.border), 10 + V.BORDER, "the border")
    assertEqual(lv(am.dispelHost), 10 + V.DISPEL, "the dispel edge")
    assertEqual(lv(am.text), 10 + V.OVERLAY, "the texts")
    restore()
end)

-- ── the edit overlays ─────────────────────────────────────────────────────────────────────────

test("layers: the frame picker's overlay is in the cursor tier", function()
    local NS, mocks = fresh()
    local restore = dofile("tests/_kit/mock_layers.lua")(mocks)
    NS.FramePicker.Start(function() end, function() end)
    local overlay = mocks.__globals.AuraMasterFramePicker
    assertEqual(mocks.__layers(overlay).strata, "TOOLTIP")
    NS.FramePicker.Stop()
    restore()
end)

test("layers: the drag-time snap highlight is in the popup tier, under tooltips (AUR-Z05)", function()
    local NS, mocks = DH.env(2)
    local restore = dofile("tests/_kit/mock_layers.lua")(mocks)
    local CM = NS.ContainerManager
    DH.plant(CM.instances[1].engine, 0, 100, 100, 140)
    local inst = CM.instances[2]
    DH.recordAnchor(inst.anchor)
    inst.handle:__fire("OnDragStart")
    DH.plant(inst.anchor, 0, 75, 20, 95)
    local Snap = NS.Anchors.Snap
    Snap.Tick()
    assertTrue(Snap.highlight ~= nil and Snap.highlight:IsShown(), "shown with a candidate")
    -- red under: HIGHLIGHT_STRATA = "TOOLTIP", the tier GameTooltip draws in
    assertEqual(mocks.__layers(Snap.highlight).strata, "FULLSCREEN_DIALOG")
    restore()
end)

-- ── the player's strata row ───────────────────────────────────────────────────────────────────

test("layers: the Strata row's tooltip is the library's O.StrataTooltip over the row's own values (AUR-Z07)", function()
    local NS = T.NS
    local row
    for _, r in ipairs(NS.Schema) do
        if r.path == "container.layout.strata" then row = r end
    end
    assertTrue(row ~= nil, "the row")
    -- red under: the row's own "Which layer of the interface the container draws in."
    assertEqual(row.desc, NS.Helpers.StrataTooltip(NS.Constants.STRATA))
    assertTrue(row.desc:find("Dialog and above", 1, true) ~= nil, "it warns what Dialog covers")
    local values = {}
    for _, k in ipairs(NS.Constants.STRATA) do values[#values + 1] = k end
    assertEqual(table.concat(values, ","), "BACKGROUND,LOW,MEDIUM,HIGH,DIALOG", "the value set is unchanged")
end)
