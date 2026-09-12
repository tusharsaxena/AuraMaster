-- tests/test_preview.lua — modules/Preview.lua: the placeholder auras shown while unlocked or under
-- `/am test`. How many are drawn and where, the pool that keeps them, and when they are dressed again.

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
    local _, n = NS.Pool.Counts(k.previewPool)
    return n
end

test("preview: every placeholder aura is drawn, each where Preview.Offset puts it against the anchor", function()
    local c = cfg({ style = "bars", layout = { axis = "vertical", spacing = 3 } })
    local k = container(c)
    NS.Preview.Show(k)
    local count = #NS.Constants.PREVIEW_AURAS
    assertEqual(active(k), count)
    for i = 1, count do
        local f = k.previewPool.active[i]
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

test("preview: the per-group cap limits the placeholders, and an enchant container shows at most two", function()
    local k = container(cfg({ filter = { maxAuras = 2 } }))
    NS.Preview.Show(k)
    -- red under: Preview.Show ignoring filter.maxAuras
    assertEqual(active(k), 2, "capped")
    k = container(cfg({ auraType = "ENCHANT" }))
    NS.Preview.Show(k)
    -- red under: an enchant preview drawing five placeholders for two weapon slots
    assertEqual(active(k), 2, "main hand and off hand")
    k = container(cfg({ filter = { maxAuras = 0 } }))
    NS.Preview.Show(k)
    assertEqual(active(k), #NS.Constants.PREVIEW_AURAS, "0 means no cap")
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
    local free, used = NS.Pool.Counts(k.previewPool)
    assertEqual(used, 2)
    assertEqual(free, #NS.Constants.PREVIEW_AURAS - 2)
    -- red under: Preview.Show acquiring without releasing the last dress's elements first
    for _, f in ipairs(k.previewPool.free) do assertFalse(f:IsShown(), "a released placeholder still draws") end
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

test("preview: /am test shows placeholders on a locked addon, with the engine off and no drag handle", function()
    local NS2 = fresh()
    local CM = NS2.ContainerManager
    assertTrue(NS2.db.profile.locked, "locked by default")
    local inst = CM.instances[1]
    CM.SetPreview(true)
    local _, n = NS2.Pool.Counts(inst.previewPool)
    -- red under: ShouldShow reading only the lock for previewing
    assertEqual(n, #NS2.Constants.PREVIEW_AURAS)
    assertFalse(inst.engine.__enabled, "real auras do not draw over the placeholders")
    -- red under: ApplyVisibility showing the handle for a preview on a locked addon
    assertFalse(inst.handle:IsShown(), "a locked addon has nothing to drag")
    CM.SetPreview(false)
    _, n = NS2.Pool.Counts(inst.previewPool)
    assertEqual(n, 0)
    assertTrue(inst.engine.__enabled, "the engine is back")
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
