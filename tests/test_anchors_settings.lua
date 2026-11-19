-- tests/test_anchors_settings.lua - the settings mark on a container's unlock strip (AD-86-AM,
-- LibKa0s#86). LibKa0s-Widgets-1.0's DragHandle (minor 14) draws a settings mark immediately left of
-- the X when the host passes `spec.settings`; Aura Master's opens the Containers page on THAT
-- container, exactly as a right click on the strip does, and its tooltip names the container and
-- says so. Its own suite, as the close mark's is (tests/test_anchors_close.lua).

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local fresh = dofile("tests/fresh_env.lua")

local RECORDED = { "SetPoint", "SetSize", "SetTexture" }

--- Rebuild container `inst`'s handle under a CreateFrame that records the setters above per frame.
--- The kit hands a texture back as its frame, so a mark's art lands on the mark's own frame.
local function recordedHandle(mocks, NS, inst)
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(...)
        local f = real(...)
        f.__rec = {}
        for _, m in ipairs(RECORDED) do
            rawset(f, m, function(self, ...)
                local log = self.__rec[m] or {}
                self.__rec[m] = log
                log[#log + 1] = { ... }
                return self
            end)
        end
        return f
    end
    local handle = NS.Anchors.BuildHandle(inst)
    mocks.CreateFrame = real
    inst.handle = handle
    return handle
end

local function last(f, method)
    local log = f.__rec[method] or {}
    return log[#log]
end

--- Record every NS.OpenOptionsPage call and the active container at the time.
local function recordOpens(NS)
    local opened = {}
    NS.OpenOptionsPage = function(key)
        opened[#opened + 1] = { key = key, active = NS.State.activeContainerId }
    end
    return opened
end

test("settings mark: it sits immediately left of the X, the catalog settings art at the close mark's size", function()
    local NS, mocks = fresh()
    local h = recordedHandle(mocks, NS, NS.ContainerManager.instances[1])
    -- red under: BuildHandle passing no `settings` (the widget builds no settings mark)
    assertTrue(h.settings ~= nil, "the strip carries a settings mark")
    assertTrue(NS.Icon("settings") ~= nil, "the vendored catalog carries the settings art")
    assertEqual(last(h.settings, "SetTexture")[1], NS.Icon("settings"))
    local cs, ss = h.close.__rec.SetSize, h.settings.__rec.SetSize
    assertEqual(table.concat(ss[1], ","), table.concat(cs[1], ","), "the same click target as the X")
    assertEqual(table.concat(ss[2], ","), table.concat(cs[2], ","), "the same art size as the X")
    local p = h.settings.__rec.SetPoint[1]
    assertEqual(p[1], "RIGHT"); assertTrue(p[2] == h.close, "anchored to the X"); assertEqual(p[3], "LEFT")
end)

test("settings mark: a left click opens the Containers page on THIS container, as a right click on the strip does", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local opened = recordOpens(NS)
    h.settings:__fire("OnClick", "LeftButton")
    -- red under: a mark that opens nothing, or the panel on whichever container was active
    assertEqual(#opened, 1, "one open")
    assertEqual(opened[1].key, "containers")
    assertEqual(opened[1].active, inst.id, "the clicked container is the active one")
    assertTrue(NS.Database.FindContainer(inst.id).enabled, "the settings mark disables nothing")
end)

test("settings mark: a right click opens the settings too, like the strip, the ? and the X", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local opened = recordOpens(NS)
    h.settings:__fire("OnClick", "RightButton")
    assertEqual(#opened, 1, "one open")
    assertEqual(opened[1].key, "containers")
end)

test("settings mark: its tooltip names the container (following a rename) and says what the click opens", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local lines = {}
    local function add(_, s) lines[#lines + 1] = s end
    rawset(mocks.GameTooltip, "SetText", add)
    rawset(mocks.GameTooltip, "AddLine", add)
    rawset(mocks.GameTooltip, "SetOwner", function() lines = {} end)
    NS.SetByPath("container.name", "Renamed Gear", 2)
    h.settings:__fire("OnEnter")
    assertEqual(lines[1], "Renamed Gear", "the title is read on every hover")
    -- red under: the mark falling back to the strip's own tooltip (its body is the drag hint)
    assertEqual(lines[2], NS.L["Click to open this container's settings on the Containers page."])
end)
