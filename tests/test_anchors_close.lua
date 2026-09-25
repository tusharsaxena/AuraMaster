-- tests/test_anchors_close.lua - the close mark on a container's unlock strip (batch 8 CX-3, owner
-- feedback #3). LibKa0s-Widgets-1.0's DragHandle (minor 3) draws an X immediately left of the "?"
-- when the host passes `onClose`; AuraMaster's X disables THAT container through the settings write
-- seam, with no confirmation, and prints one chat line naming it and how to turn it back on. The
-- tooltip says the same.
-- Its own suite because tests/test_anchors.lua sits near layout-§1's 1500-line cap.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
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

--- Every chat line from here on.
local function captureChat(mocks)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        local n = #lines
        lines[n + 1] = tostring(msg)
    end)
    return lines
end

test("close: the X sits immediately left of the help mark, the catalog close glyph at the help mark's size", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    -- red under: BuildHandle passing no onClose (the widget builds no X at all)
    assertTrue(h.close ~= nil, "the strip carries a close mark")
    assertTrue(NS.Icon("close") ~= nil, "the vendored catalog carries the close mark")
    assertEqual(last(h.close, "SetTexture")[1], NS.Icon("close"))
    local hs, cs = h.help.__rec.SetSize, h.close.__rec.SetSize
    assertEqual(table.concat(cs[1], ","), table.concat(hs[1], ","), "the same click target as the ?")
    assertEqual(table.concat(cs[2], ","), table.concat(hs[2], ","), "the same art size as the ?")
    local p = h.close.__rec.SetPoint[1]
    assertEqual(p[1], "RIGHT"); assertTrue(p[2] == h.help, "anchored to the help mark"); assertEqual(p[3], "LEFT")
end)

test("close: with no media catalog the X falls back to the library's Blizzard stop button", function()
    local NS, mocks = fresh()
    NS.Icon = function() return nil end
    local h = recordedHandle(mocks, NS, NS.ContainerManager.instances[1])
    assertEqual(last(h.close, "SetTexture")[1], [[Interface\Buttons\UI-StopButton]])
end)

test("close: a left click disables THIS container through the write seam and says how to bring it back", function()
    local NS, mocks = fresh()
    local CM = NS.ContainerManager
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local inst = CM.instances[2]
    assertTrue(inst.handle:IsShown(), "unlocked: the strip shows")
    local changes = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, p)
        changes[#changes + 1] = p
    end)
    local lines = captureChat(mocks)
    inst.handle.close:__fire("OnClick", "LeftButton")
    mocks.__fireTimers()
    assertFalse(NS.Database.FindContainer(2).enabled, "container 2 is disabled")
    assertTrue(NS.Database.FindContainer(1).enabled, "container 1 is untouched")
    assertEqual(#changes, 1, "one write")
    assertEqual(changes[1].path, "container.enabled")
    assertEqual(changes[1].containerId, 2)
    assertFalse(inst.handle:IsShown(), "the visibility pass hides its strip")
    assertTrue(CM.instances[1].handle:IsShown(), "and leaves the other strips")
    -- red under: a silent disable
    assertEqual(#lines, 1, table.concat(lines, " | "))
    local name = NS.Database.FindContainer(2).name
    assertTrue(lines[1]:find(name, 1, true) ~= nil, "the line names the container: " .. lines[1])
    assertTrue(lines[1]:find(NS.L["Enabled"], 1, true) ~= nil, "and how to turn it back on: " .. lines[1])
end)

test("close: a right click on the X opens the settings like the strip and the ?, and disables nothing", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local opened = {}
    NS.OpenOptionsPage = function(key)
        local n = #opened
        opened[n + 1] = key
    end
    h.close:__fire("OnClick", "RightButton")
    assertEqual(table.concat(opened, ","), "containers")
    assertTrue(NS.Database.FindContainer(2).enabled, "a right click closes nothing")
end)

test("close: in combat the X still disables the container, raising nothing and moving no anchor", function()
    local NS, mocks = fresh()
    NS.SetByPath("locked", false)
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[2]
    local moves = 0
    rawset(inst.anchor, "SetPoint", function() moves = moves + 1 end)
    rawset(inst.anchor, "Show", function() moves = moves + 1 end)
    rawset(inst.anchor, "Hide", function() moves = moves + 1 end)
    mocks.__lockdown = true
    local ok, err = pcall(inst.handle.close.__fire, inst.handle.close, "OnClick", "LeftButton")
    mocks.__fireTimers()
    assertTrue(ok, tostring(err))
    assertFalse(NS.Database.FindContainer(2).enabled, "stored under lockdown, as the Enabled checkbox is")
    assertFalse(inst.handle:IsShown(), "the strip hides")
    mocks.__lockdown = false
    assertEqual(moves, 0, "the protected anchor is never shown, hidden or moved in combat")
end)

test("close: the X's tooltip names the container (following a rename) and says how to turn it back on", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local lines, owners = {}, {}
    local function add(_, s)
        local n = #lines
        lines[n + 1] = s
    end
    rawset(mocks.GameTooltip, "SetText", add)
    rawset(mocks.GameTooltip, "AddLine", add)
    rawset(mocks.GameTooltip, "SetOwner", function(_, owner, anchor)
        owners[#owners + 1] = { owner = owner, anchor = anchor }
    end)
    NS.SetByPath("container.name", "Renamed Close", 2)
    h.close:__fire("OnEnter")
    assertEqual(lines[1], "Renamed Close", "the title is read on every hover")
    -- red under: the X falling back to the strip's own tooltip (its body is the drag hint)
    assertEqual(lines[2], NS.L["Click to disable this container. Its settings are kept; turn Enabled back on for it on the Containers page to bring it back."])
    -- The anchor inherits DisableUntrustedLayoutScriptsTemplate: SetOwner on the X would error.
    assertEqual(#owners, 1)
    assertTrue(owners[1].owner == mocks.UIParent, "owned by UIParent")
    assertEqual(owners[1].anchor, "ANCHOR_CURSOR")
end)
