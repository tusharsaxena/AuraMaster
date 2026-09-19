-- tests/region_recorder.lua — a stand-in for one frame region that RECORDS every method called on it.
--
-- The kit's CreateTexture and CreateFontString hand back the frame itself (mock_base's known
-- divergence), so on a kit stub a button's icon, fill, background and texts are one table, and a
-- paint on one cannot be told from a paint on another. The style suites dress an element once, swap
-- each region on `frame.__am` for one of these, and dress it again: every call a region receives is
-- then its own. A recorder also serves as the button itself, where every engine binding it is handed
-- lands in its log.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.
--
-- Any PascalCase method exists, is logged in call order on `__log`, and answers the region itself, as
-- the kit's stub does. The few answers production branches on are real: IsShown tracks Show, Hide and
-- SetShown; SetFont answers true (a font the client accepted); GetStatusBarTexture answers one
-- recorder of its own (the bar's moving edge); CreateTexture answers a new recorder each call, so a
-- border's four strips (modules/Style.lua's ApplyBorder) are four regions; GetWidth and GetHeight
-- answer 0, a real number (fidelity rule 2). SetBackdrop does what Blizzard's does to a frame's size
-- (Blizzard_SharedXML/Backdrop.lua:226, SetupTextureCoordinates): arithmetic on GetWidth and
-- GetHeight, so a recorder whose size reads secret (tests/wow_mock.lua's __layOut) raises there as
-- the client does (B2-3). Per instance, `__answer[name]` replaces an answer, `__absent[name]` makes a
-- method missing, and `__raise[name]` makes it raise.

local new

local STATE = {
    Show = function(self) self.__shown = true end,
    Hide = function(self) self.__shown = false end,
    SetShown = function(self, v) self.__shown = not not v end,
}

local ANSWERS = {
    IsShown = function(self) return self.__shown end,
    SetFont = function() return true end,
    GetStatusBarTexture = function(self)
        self.__edge = self.__edge or new()
        return self.__edge
    end,
    CreateTexture = function(self)
        local tex = new()
        tex.parent = self
        return tex
    end,
    GetWidth = function() return 0 end,
    GetHeight = function() return 0 end,
    SetBackdrop = function(self, info)
        if type(info) == "table" then
            local edge = tonumber(info.edgeSize) or 1
            local _ = self:GetWidth() / edge + self:GetHeight() / edge
        end
        return self
    end,
}

local helpers = {}

--- Every call to `name`, oldest first, each as its argument list.
function helpers.__calls(self, name)
    local out = {}
    for _, e in ipairs(self.__log) do
        if e.name == name then
            local n = #out
            out[n + 1] = e.args
        end
    end
    return out
end

--- The arguments of the last call to `name`, or nil when it was never called.
function helpers.__last(self, name)
    local hit
    for _, e in ipairs(self.__log) do
        if e.name == name then hit = e.args end
    end
    return hit
end

--- How many times `name` was called.
function helpers.__count(self, name)
    local n = 0
    for _, e in ipairs(self.__log) do
        if e.name == name then n = n + 1 end
    end
    return n
end

--- Where the last call to `name` falls in the run's call order, counted across EVERY recorder, so
--- calls on two regions can be ordered; nil when it was never called.
function helpers.__lastSeq(self, name)
    local hit
    for _, e in ipairs(self.__log) do
        if e.name == name then hit = e.seq end
    end
    return hit
end

--- The last call to `name` as one comma-joined string (nil arguments read "nil").
function helpers.__joined(self, name)
    local args = helpers.__last(self, name)
    if not args then return nil end
    local parts = {}
    for i = 1, args.n do parts[i] = tostring(args[i]) end
    return table.concat(parts, ",")
end

local seq = 0   -- one counter for every recorder: the run's call order (__lastSeq)

local function method(name)
    return function(self, ...)
        local log = self.__log
        seq = seq + 1
        log[#log + 1] = { name = name, args = { n = select("#", ...), ... }, seq = seq }
        if self.__raise[name] then error(name .. " refused", 2) end
        local change = STATE[name]
        if change then change(self, ...) end
        local answer = self.__answer[name] or ANSWERS[name]
        if answer then return answer(self, ...) end
        return self
    end
end

new = function()
    local r = { __log = {}, __shown = false, __answer = {}, __absent = {}, __raise = {} }
    return setmetatable(r, { __index = function(t, k)
        local h = helpers[k]
        if h then return h end
        if type(k) ~= "string" or not k:match("^%u") or t.__absent[k] then return nil end
        return method(k)
    end })
end

return new
