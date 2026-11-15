-- tests/test_settings_pin.lua — the guard item 020 (settings layout, AM-LY) is held to: the set of
-- stored setting paths, their shipped defaults, ranges and choice sets, and every leaf of the shipped
-- defaults, are exactly tests/settings_pin.lua's snapshot. The owner's rule for item 020 is "move,
-- regroup and relabel only", so a tab, heading, label or tooltip may change and none of these may.

local T = _G.AM_TEST
local test, assertEqual = T.test, T.assertEqual
local fresh = dofile("tests/fresh_env.lua")
local snapshot = dofile("tests/settings_pin_snapshot.lua")
local PIN = dofile("tests/settings_pin.lua")

-- The snapshot is the retail profile's. skin.skin's default is the client's default skin
-- (skinning-§2), WoW Forever on the forever profile: those two lines, and only those, read it there.
-- Pinned from the profile, never read back from the addon.
if (os.getenv("KA0S_KIT_CLIENT") or "retail") == "forever" then
    local pinned = {}
    for i, line in ipairs(PIN) do
        if line:find("skin.skin ", 1, true) or line:find("profile.skin.skin=", 1, true) then
            line = line:gsub('"ka0s"', '"forever"', 1)
        end
        pinned[i] = line
    end
    PIN = pinned
end

--- The lines of `a` that `b` lacks, joined for a failure message.
local function missing(a, b)
    local have, out = {}, {}
    for _, line in ipairs(b) do have[line] = true end
    for _, line in ipairs(a) do
        if not have[line] then out[#out + 1] = line end
    end
    return table.concat(out, "\n")
end

test("settings pin: every stored path, default, range and choice set is the snapshot's", function()
    local NS2 = fresh()
    local got = snapshot(NS2)
    -- red under: a layout edit that renames a path, changes a default, a min/max/step or a choice set,
    -- or adds or drops a row
    assertEqual(missing(PIN, got), "", "snapshot lines this build no longer has")
    assertEqual(missing(got, PIN), "", "lines this build has that the snapshot does not")
    assertEqual(#got, #PIN, "the same number of lines")
end)
