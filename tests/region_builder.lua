-- tests/region_builder.lua — a recorder (tests/region_recorder.lua) that BUILDS recorders: every
-- font string, texture, animation group and animation asked of it is a recorder of its own, and so
-- is every frame CreateFrame builds while `B.during` runs. The kit's CreateFontString answers the
-- frame itself (mock_base's known divergence), which would make every piece of a Text style's chain
-- one table; built this way each piece, and the frames around it, record their own calls from the
-- first dress on.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.
--
--     local B = dofile("tests/region_builder.lua")
--     local made = {}
--     local frame = B.new(made)
--     B.during(mocks, made, function() NS.Style.Element(frame, cfg, true) end)
--
-- Every recorder built is appended to `made` in creation order, stamped `kind` (FontString, Texture,
-- AnimationGroup, Animation, or the frame type), `parent` (who created it) and `args` (the create
-- call's arguments).

local R = dofile("tests/region_recorder.lua")

local B = {}

--- Append `v` to `list`; the length sits on a line of its own (tests/test_lintconfig.lua).
local function push(list, v)
    local n = #list
    list[n + 1] = v
end

local CHILDREN = { CreateFontString = "FontString", CreateTexture = "Texture",
    CreateAnimationGroup = "AnimationGroup", CreateAnimation = "Animation" }

--- A recorder whose Create* methods answer new builders, each recorded on `made`.
function B.new(made)
    local r = R()
    for method, kind in pairs(CHILDREN) do
        r.__answer[method] = function(self, ...)
            local c = B.new(made)
            c.kind, c.parent, c.args = kind, self, { ... }
            push(made, c)
            return c
        end
    end
    return r
end

--- Run `fn` with the mock's CreateFrame answering builders (each recorded on `made`), then put the
--- mock's own back, a raise included.
function B.during(m, made, fn)
    local real = m.CreateFrame
    m.CreateFrame = function(frameType, _, parent, template)
        local f = B.new(made)
        f.kind, f.parent, f.args = frameType, parent, { template }
        push(made, f)
        return f
    end
    local ok, err = pcall(fn)
    m.CreateFrame = real
    if not ok then error(err, 0) end
end

--- The recorders on `made` of `kind` whose parent is `parent` (any parent when nil), in order.
function B.children(made, kind, parent)
    local out = {}
    for _, r in ipairs(made) do
        if r.kind == kind and (parent == nil or r.parent == parent) then push(out, r) end
    end
    return out
end

return B
