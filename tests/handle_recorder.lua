-- tests/handle_recorder.lua — rebuilding a container's drag handle under a CreateFrame that records
-- every setter its look and placement go through, per frame, in call order. Shared by
-- tests/test_anchors.lua and tests/test_anchors_handle.lua, which it was lifted out of when the handle
-- cases were peeled into a suite of their own (AM-ATS-02).
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.
--
--     local HR = dofile("tests/handle_recorder.lua")
--     local h = HR.recordedHandle(mocks, NS, inst)
--     local point = HR.last(h, "SetPoint")

local M = {}

-- Every setter the handle's look and placement go through, recorded in call order per frame.
local RECORDED = {
    "SetPoint", "SetAllPoints", "ClearAllPoints", "SetWidth", "SetHeight", "SetSize",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetTexture",
    "RegisterForDrag",
}

local BS = dofile("tests/border_strips.lua")

--- Rebuild container `inst`'s handle under a CreateFrame that records every frame it makes.
--- Font strings come back as their frame from the kit stub, so a label's setters land on the frame
--- that made it. The strip's own textures (its fill and its edge strips) are region recorders
--- (BS.recorderTextures), so each is read apart; the help mark's icon lands on the help frame.
function M.recordedHandle(mocks, NS, inst)
    local real = mocks.CreateFrame
    mocks.CreateFrame = function(...)
        local f = real(...)
        if select(3, ...) == inst.anchor then BS.recorderTextures(f) end
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

--- The last call recorded for `method` on frame `f`, and how many calls it had.
function M.last(f, method)
    local log = f.__rec[method] or {}
    return log[#log], #log
end

return M
