-- tests/test_preview.lua — modules/Preview.lua: the placeholder auras shown in test mode. How many
-- are drawn and where, the pool that keeps them, and when they are dressed again.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local NS = T.NS
local R = dofile("tests/region_recorder.lua")
local fresh = dofile("tests/fresh_env.lua")
local D = NS.CONTAINER_TEMPLATE

local function cfg(over, ns)
    ns = ns or NS
    return ns.Database.Merge(ns.Database.DeepCopy(ns.CONTAINER_TEMPLATE), over or {})
end

--- A container as Preview.Show sees one: its settings, its anchor, and a factory that counts the
--- placeholder frames it builds (Preview keeps a factory it is handed).
local function container(c)
    local k = { anchor = R(), built = 0, frames = {} }
    k.Cfg = function() return c end
    k.previewFactory = function()
        k.built = k.built + 1
        local f = R()
        k.frames[#k.frames + 1] = f
        return f
    end
    return k
end

local function active(k)
    local _, n = NS.Pool.Counts(k.previewPools.bars)
    return n
end

test("preview: every placeholder aura is drawn, each where Preview.Offset puts it against the anchor", function()
    local c = cfg({ style = "bars", layout = { axis = "vertical", spacing = 3 } })
    local k = container(c)
    NS.Preview.Show(k)
    local count = #NS.Constants.PREVIEW_AURAS
    assertEqual(active(k), count)
    for i = 1, count do
        local f = k.previewPools.bars.active[i]
        local p = f:__last("SetPoint")
        local point, x, y = NS.Preview.Offset(c, i)
        -- red under: Preview.Show placing every element at the anchor's corner
        assertEqual(p[1], point, "element " .. i)
        assertTrue(p[2] == k.anchor, "element " .. i .. " hangs from the anchor")
        assertEqual(p[3], point); assertEqual(p[4], x); assertEqual(p[5], y)
        assertTrue(f:IsShown(), "element " .. i .. " is shown")
        assertTrue(f.__am ~= nil, "element " .. i .. " is dressed")
    end
end)

test("preview: the per-group cap limits the placeholders", function()
    local k = container(cfg({ filter = { maxAuras = 2 } }))
    NS.Preview.Show(k)
    -- red under: Preview.Show ignoring filter.maxAuras
    assertEqual(active(k), 2, "capped")
    k = container(cfg({ filter = { maxAuras = 0 } }))
    NS.Preview.Show(k)
    assertEqual(active(k), #NS.Constants.PREVIEW_AURAS, "0 means no cap")
end)

test("preview: a container showing only Weapon enchants previews one placeholder per enchant slot, and its extent agrees (feedback #6)", function()
    local enchantsOnly = { style = "bars", layout = { axis = "vertical", spacing = 3 },
        filter = { categories = NS.Categories.EnchantOnlyStates() } }
    local k = container(cfg(enchantsOnly))
    k.previewExtent = R()   -- Preview keeps an extent it is handed, so its size can be read
    NS.Preview.Show(k)
    -- red under: placeholderCount ignoring the plan (five buff placeholders for three weapon slots)
    assertEqual(active(k), 3, "main hand, off hand, ranged")
    local want = container(cfg(enchantsOnly))
    want.previewExtent = R()
    NS.Preview.Extent(want, 3)
    local got, expected = k.previewExtent:__last("SetSize"), want.previewExtent:__last("SetSize")
    -- red under: Preview.Extent sized for every placeholder aura rather than the slots drawn
    assertEqual(got[1], expected[1]); assertEqual(got[2], expected[2])
    k = container(cfg({ filter = { maxAuras = 2, categories = NS.Categories.EnchantOnlyStates() } }))
    NS.Preview.Show(k)
    assertEqual(active(k), 2, "the per-group cap still applies")
    k = container(cfg({ unit = "player", filter = { categories = { weaponEnchants = "show" } } }))
    NS.Preview.Show(k)
    assertEqual(active(k), #NS.Constants.PREVIEW_AURAS, "a buff container that also has enchants keeps every placeholder")
end)

test("preview: a shown preview with nothing applied is left alone; an applied one is dressed again in the same frames", function()
    local k = container(cfg())
    NS.Preview.Show(k)
    local count = #NS.Constants.PREVIEW_AURAS
    assertEqual(k.built, count)
    local first = k.frames[1]
    local sizes = first:__count("SetSize")
    NS.Preview.Show(k)
    assertEqual(first:__count("SetSize"), sizes, "not dressed again: nothing changed")
    k.previewDirty = true
    NS.Preview.Show(k)
    -- red under: Preview.Show building fresh frames on every dress (WoW never frees a frame)
    assertEqual(k.built, count, "the same frames, re-dressed")
    assertTrue(first:__count("SetSize") > sizes, "dressed again")
    assertFalse(k.previewDirty, "and marked clean")
end)

test("preview: a lower cap hides the extra placeholders rather than leaving them drawn", function()
    local c = cfg()
    local k = container(c)
    NS.Preview.Show(k)
    c.filter.maxAuras = 2
    k.previewDirty = true
    NS.Preview.Show(k)
    local free, used = NS.Pool.Counts(k.previewPools.bars)
    assertEqual(used, 2)
    assertEqual(free, #NS.Constants.PREVIEW_AURAS - 2)
    -- red under: Preview.Show acquiring without releasing the last dress's elements first
    for _, f in ipairs(k.previewPools.bars.free) do assertFalse(f:IsShown(), "a released placeholder still draws") end
end)

test("preview: Hide releases every placeholder, and the next Show dresses them again", function()
    local k = container(cfg())
    NS.Preview.Show(k)
    NS.Preview.Hide(k)
    assertEqual(active(k), 0)
    for _, f in ipairs(k.frames) do assertFalse(f:IsShown(), "a hidden preview still draws") end
    local sizes = k.frames[1]:__count("SetSize")
    NS.Preview.Show(k)
    -- red under: Preview.Hide leaving previewShown set, so the next Show returns early
    assertEqual(active(k), #NS.Constants.PREVIEW_AURAS)
    assertTrue(k.frames[1]:__count("SetSize") > sizes, "dressed again after being hidden")
    assertEqual(k.built, #NS.Constants.PREVIEW_AURAS, "from the pool, not new frames")
end)

test("preview: a container whose settings are gone draws nothing and raises nothing", function()
    local k = container(nil)
    local ok, err = pcall(NS.Preview.Show, k)
    -- red under: Preview.Show without its missing-settings guard
    assertTrue(ok, tostring(err))
    assertEqual(k.built, 0)
    assertTrue(k.previewShown == nil)
    ok = pcall(NS.Preview.Hide, k)
    assertTrue(ok, "hiding a preview never shown")
end)

test("preview: placeholders paint with the container's class snapshot, as its real buttons do", function()
    local NS2 = fresh()
    local seen = {}
    local element = NS2.Style.Element
    NS2.Style.Element = function(f, c, engine, classColor)
        seen[#seen + 1] = classColor
        return element(f, c, engine, classColor)
    end
    local k = container(cfg(nil, NS2))
    k.classColor = { r = 0.1, g = 0.2, b = 0.3 }
    NS2.Preview.Show(k)
    NS2.Style.Element = element
    assertEqual(#seen, #NS2.Constants.PREVIEW_AURAS)
    -- red under: Preview.Show dressing without container.classColor (a target container previews in the player's class)
    for i, cc in ipairs(seen) do assertTrue(cc == k.classColor, "element " .. i) end
end)


test("preview: a vertical layout wraps into a new column one element's width plus the line spacing across", function()
    local c = cfg({ style = "bars", bars = { width = 100, height = 10 },
        layout = { axis = "vertical", perLine = 2, spacing = 1, lineSpacing = 5, growH = "right", growV = "down" } })
    local _, x2, y2 = NS.Preview.Offset(c, 2)
    assertEqual(x2, 0); assertEqual(y2, -(10 + 1))
    local _, x3, y3 = NS.Preview.Offset(c, 3)
    -- red under: Offset stepping a vertical wrap by the element's height instead of its width
    assertEqual(x3, 100 + 5); assertEqual(y3, 0)
    c.layout.perLine = 0
    local _, x9, y9 = NS.Preview.Offset(c, 9)
    assertEqual(x9, 0, "perLine 0 never wraps")
    assertEqual(y9, -8 * (10 + 1))
end)

test("preview: a missing layout block grows down and right from the top left with no spacing", function()
    local c = cfg({ style = "icons" })
    c.layout = nil
    local point, x, y = NS.Preview.Offset(c, 2)
    -- red under: Offset indexing cfg.layout without its `or {}`
    assertEqual(point, "TOPLEFT")
    assertEqual(x, D.icons.width); assertEqual(y, 0)
end)

test("preview: switching Color by from dispel type back to static leaves no dispel tint on a placeholder (B-4)", function()
    local c = cfg({ style = "bars", bars = { colorMode = "dispel", useClassColorBar = false,
        barColor = { r = 0.9, g = 0.5, b = 0.1, a = 1 } } })
    local k = container(c)
    NS.Preview.Show(k)
    for _, f in ipairs(k.frames) do
        for key in pairs(f.__am) do f.__am[key] = R() end
    end
    local function fills()
        local out = {}
        for i, f in ipairs(k.previewPools.bars.active) do out[i] = f.__am.fill:__joined("SetVertexColor") end
        return out
    end
    k.previewDirty = true
    NS.Preview.Show(k)
    local m = NS.db.profile.dispelColors.Magic
    local magic = table.concat({ m.r, m.g, m.b, 1 }, ",")
    for i, got in ipairs(fills()) do assertEqual(got, magic, "dispel: placeholder " .. i .. " stands in with Magic") end
    c.bars.colorMode = "static"
    k.previewDirty = true
    NS.Preview.Show(k)
    local own = table.concat({ NS.Style.Color(c.bars.barColor, false) }, ",")
    -- red under: the dress painting the Magic stand-in whatever the colorMode
    for i, got in ipairs(fills()) do assertEqual(got, own, "static: placeholder " .. i .. " paints the bar color") end
end)

test("preview: a background colored by dispel type stands in with Magic, keeping its own alpha (feedback #7)", function()
    local c = cfg({ style = "bars", bars = { bgColorMode = "dispel", useClassColorBg = false,
        bgColor = { r = 0, g = 0, b = 0, a = 0.5 } } })
    local k = container(c)
    NS.Preview.Show(k)
    for _, f in ipairs(k.frames) do
        for key in pairs(f.__am) do f.__am[key] = R() end
    end
    k.previewDirty = true
    NS.Preview.Show(k)
    local m = NS.db.profile.dispelColors.Magic
    for i, f in ipairs(k.previewPools.bars.active) do
        -- red under: the preview painting the background its static color whatever its Color by
        assertEqual(f.__am.bg:__joined("SetVertexColor"), table.concat({ m.r, m.g, m.b, 0.5 }, ","), "placeholder " .. i)
    end
end)

-- ── a style switch while previewing (C-4) ───────────────────────────────────────────────────────

--- Switch container `id`'s style while previewing and flush the apply, returning whether it raised.
local function switchStyle(NS2, mocks, id, style)
    NS2.SetByPath("container.style", style, id)
    return pcall(mocks.__fireTimers)
end

test("preview: switching a previewed container from bars to icons re-dresses without error", function()
    local NS2, mocks = fresh()
    NS2.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local inst = NS2.ContainerManager.instances[1]       -- Player buffs, bars
    assertTrue(inst.previewShown)
    local ok, err = switchStyle(NS2, mocks, 1, "icons")
    -- red under: reusing a bars-built __am for icons (Style_Icons.lua 'attempt to index cd')
    assertTrue(ok, tostring(err))
    assertTrue(inst.previewShown, "the preview re-drew as icons")
    local _, n = NS2.Pool.Counts(inst.previewPools.icons)
    assertEqual(n, #NS2.Constants.PREVIEW_AURAS, "every placeholder drawn as an icon")
end)

test("preview: switching a previewed container from icons to bars re-dresses without error", function()
    local NS2, mocks = fresh()
    NS2.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local inst = NS2.ContainerManager.instances[2]       -- Player debuffs, icons
    assertTrue(inst.previewShown)
    local ok, err = switchStyle(NS2, mocks, 2, "bars")
    -- red under: reusing an icons-built __am for bars (no bar, fill or spark on it)
    assertTrue(ok, tostring(err))
    assertTrue(inst.previewShown, "the preview re-drew as bars")
    local _, n = NS2.Pool.Counts(inst.previewPools.bars)
    assertEqual(n, #NS2.Constants.PREVIEW_AURAS)
end)

test("preview: a bar container duplicated in test mode, then switched to icons, re-dresses (the owner's steps)", function()
    local NS2, mocks = fresh()
    local CM = NS2.ContainerManager
    NS2.Preview.SetTestMode(true)
    mocks.__fireTimers()
    local id = CM.Duplicate(1)
    mocks.__fireTimers()
    local copy
    for _, inst in ipairs(CM.instances) do
        if inst.id == id then copy = inst end
    end
    assertTrue(copy ~= nil and copy.previewShown, "the copy previews as bars")
    local ok, err = switchStyle(NS2, mocks, id, "icons")
    -- red under: a pooled bar placeholder re-dressed as an icon with the bar's regions
    assertTrue(ok, tostring(err))
    assertTrue(copy.previewShown, "the copy re-drew as icons")
end)

test("preview: each style keeps its own pool, and a switch parks the other style's placeholders", function()
    local c = cfg({ style = "bars" })
    local k = container(c)
    NS.Preview.Show(k)
    local count = #NS.Constants.PREVIEW_AURAS
    local bars = {}
    for i, f in ipairs(k.previewPools.bars.active) do bars[i] = f end
    c.style = "icons"
    k.previewDirty = true
    NS.Preview.Show(k)
    local free, used = NS.Pool.Counts(k.previewPools.bars)
    -- red under: one pool shared by both styles (a bar placeholder re-dressed as an icon)
    assertEqual(used, 0, "no bar placeholder is still drawn")
    assertEqual(free, count)
    for i, f in ipairs(k.previewPools.icons.active) do
        for _, b in ipairs(bars) do assertFalse(f == b, "icon " .. i .. " is not a bar's frame") end
    end
    assertEqual(k.built, 2 * count, "one set of frames per style")
    NS.Preview.Hide(k)
    local _, iconsUsed = NS.Pool.Counts(k.previewPools.icons)
    -- red under: Preview.Hide releasing only the current style's pool
    assertEqual(iconsUsed, 0)
end)

test("preview: a placeholder holds the mouse's hover as its container's buttons do, so no world tooltip shows through (L-3)", function()
    --- The last hover and click settings the first placeholder was given, for container settings `over`.
    local function mouseOf(over)
        local k = container(cfg(over))
        NS.Preview.Show(k)
        local f = k.previewPools.bars.active[1]
        return f:__joined("SetMouseMotionEnabled"), f:__joined("SetMouseClickEnabled")
    end
    local motion, click = mouseOf({ style = "bars" })
    -- red under: a placeholder left transparent to the mouse (the world unit under it is moused
    -- over and its GameTooltip shows beside the placeholder)
    assertEqual(motion, "true", "hover stops at the placeholder")
    -- red under: a placeholder that swallows clicks meant for the world under it
    assertEqual(click, "false", "clicks pass through")
    -- red under: a placeholder that ignores Click-through or Show tooltips (it must behave as the
    -- container's real buttons do: Style.TakesHover)
    assertEqual((mouseOf({ style = "bars", behavior = { clickThrough = true } })), "false", "click-through")
    assertEqual((mouseOf({ style = "bars", behavior = { tooltips = false } })), "false", "tooltips off")
end)

-- ── the preview extent (L-4) ────────────────────────────────────────────────────────────────────
-- A container attached to a previewing one hangs from this frame rather than the disabled engine,
-- so it sits where it would beside real auras (tests/test_anchors.lua has the attach side).

test("preview: the extent covers the placeholder block from the corner it starts at, sized by Preview.Offset (L-4)", function()
    local c = cfg({ style = "bars", bars = { width = 100, height = 10 },
        layout = { axis = "vertical", perLine = 2, spacing = 1, lineSpacing = 5, growH = "left", growV = "up" } })
    local k = container(c)
    k.previewExtent = R()
    assertEqual(#NS.Constants.PREVIEW_AURAS, 5, "five placeholders")
    NS.Preview.Show(k)
    local p = k.previewExtent:__last("SetPoint")
    -- red under: the extent hung from a corner other than the one the placeholders start from
    assertEqual(p[1], "BOTTOMRIGHT"); assertTrue(p[2] == k.anchor); assertEqual(p[3], "BOTTOMRIGHT")
    assertEqual(p[4], 0); assertEqual(p[5], 0)
    local s = k.previewExtent:__last("SetSize")
    -- Five in columns of two: three columns across, two elements up.
    -- red under: an extent one element in size (a child would sit on the parent's second column)
    assertEqual(s[1], 3 * 100 + 2 * 5); assertEqual(s[2], 2 * 10 + 1)
    c.filter.maxAuras = 1
    k.previewDirty = true
    NS.Preview.Show(k)
    s = k.previewExtent:__last("SetSize")
    -- red under: an extent sized once and never again (a lower cap would leave a gap before the child)
    assertEqual(s[1], 100); assertEqual(s[2], 10)
end)

test("preview: a real container's extent is a frame of ours under its anchor, kept when the preview hides (L-4)", function()
    local NS2 = fresh()
    local inst = NS2.ContainerManager.instances[1]
    NS2.Preview.SetTestMode(true)
    local extent = inst.previewExtent
    -- red under: Preview.Show without its Preview.Extent call
    assertTrue(extent ~= nil, "built on the first preview")
    assertEqual(extent.__frameType, "Frame"); assertTrue(extent.__parent == inst.anchor)
    NS2.Preview.SetTestMode(false)
    NS2.Preview.SetTestMode(true)
    -- red under: a new extent per preview (WoW never frees a frame)
    assertTrue(inst.previewExtent == extent, "the same frame")
end)

test("preview: under lockdown a placed extent stands, and one never placed is placed once (L-4)", function()
    local NS2, mocks = fresh()
    local c = cfg({ style = "bars" }, NS2)
    local k = container(c)
    k.previewExtent = R()
    mocks.__lockdown = true
    NS2.Preview.Show(k)
    -- red under: an extent first drawn in combat left without points (a container re-placed onto it
    -- once combat ends would hang from nothing)
    assertEqual(k.previewExtent:__count("SetPoint"), 1, "placed once: nothing hangs from it yet")
    c.filter.maxAuras = 1
    k.previewDirty = true
    NS2.Preview.Show(k)
    -- red under: re-sizing the extent under lockdown (an attached container's anchor, which parents an
    -- aura engine, would move with it: events-frames-taint-§2)
    assertEqual(k.previewExtent:__count("SetPoint"), 1)
    assertEqual(k.previewExtent:__count("SetSize"), 1)
    mocks.__lockdown = false
    k.previewDirty = true
    NS2.Preview.Show(k)
    assertEqual(k.previewExtent:__count("SetSize"), 2, "out of combat it follows the block again")
end)

test("preview: a text container's placeholders read its template, each bracket's text hidden with its value", function()
    local B = dofile("tests/region_builder.lua")
    local NS2, m2 = fresh({ before = dofile("tests/text_apis.lua") })
    local c = cfg({ style = "text", text = { template = "$spellname$[ x$stacks$][ - $remainingduration$]" } }, NS2)
    local made = {}
    local k = container(c)
    k.previewFactory = function() return B.new(made) end
    B.during(m2, made, function() NS2.Preview.Show(k) end)
    local lines = {}
    -- red under: Preview.Show handing a text container the bars styler and pool
    for i, f in ipairs(k.previewPools.text.active) do
        local am = f.__am
        local parts = {}
        for j = 1, am.pieceCount do parts[j] = (am["piece" .. j]:__last("SetText") or {})[1] or "" end
        lines[i] = table.concat(parts)
    end
    -- tests/text_apis.lua's formatter writes whole seconds as "<n>s"
    assertEqual(lines[1], "Power Word: Fortitude - 3540s")
    assertEqual(lines[4], "Ignore Pain x3 - 11s", "stacks from two up, with their bracket text")
    -- red under: the duration piece writing " - " for a timeless placeholder
    assertEqual(lines[5], "Well Fed", "a timeless aura: the name alone")
end)
