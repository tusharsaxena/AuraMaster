local _, NS = ...

-- modules/Container_Twins.lua — a glowing Text container's twin engines (text glow, TG-11; the glyph
-- glow addendum, docs/superpowers/specs/2026-10-16-text-glow-addendum-glyph-glow.md, and the twins'
-- design note, docs/superpowers/research/2026-10-16-text-glow-twins-design.md, sections 1, 2 and 5).
--
--   anchor ─┬─ main engine     at the flow's start corner (ContainerClass:Build)
--           └─ holder k        the anchor's rect moved thickness × d_k + (X, Y)
--              └─ twin k       at the main's own point on its holder, three levels below the main
--
-- WHY TWINS. The engine writes a button's name, stacks, dispel word and time from the secure side,
-- through forbidden handles, to exactly one target each, and in combat the button's strings refuse
-- every addon call. So the only way to get a second copy of the live, secret text is a second engine
-- that writes it. A container with the glow on builds C.TEXT_GLOW_TWINS of them beside its main, each
-- with the main's unit, groups, view, enchant slots and flow, sent through the same calls in the same
-- order (ContainerClass:Build, Update, ApplyView, Refresh, Restyle and every SetEnabled path mirror
-- them).
-- Their buttons are dressed in the glow (Style.Element with the twin index k) and take no mouse.
--
-- DECORATION ONLY. A twin is never the hang frame, a snap or drag target, the frame picker's focus, or
-- an empty-watch pool, and is never counted as visible auras: it follows its main and nothing reads
-- it but this file, modules/Container.lua and the [Cont] line's count (Twins.Count).
--
-- THE HOLDERS. Each twin hangs from a holder of ours, a plain frame pinned to the anchor by two
-- points at the ring offset. An engine can never be re-anchored after its first group, so a thickness
-- or offset change moves the holders (Twins.Place, every apply) and builds nothing. The anchor's own
-- moves carry them. One holder per k, made on first need and kept for the container's life (frames
-- are never freed). Apply never runs in lockdown (CM.MustDefer), so a holder, an engine's ancestry,
-- is never moved in combat.
--
-- THE LEVELS. The main's level is written in its own pre-group window, max(anchor + 1, GAP + 1)
-- (Twins.LevelMain), and each twin's at main − GAP in its own, after its holder is lowered to
-- main − GAP − 1. Holder first: a twin's level can never be written again after its first group, so
-- nothing may move it from under it. Every apply re-levels the holders from the main's current
-- level, as ApplyBlocker re-levels the blocker, and never writes a live engine.
--
-- Conventional position: right after modules/Container.lua; every peer is resolved at call time.

NS.ContainerTwins = NS.ContainerTwins or {}
local Twins = NS.ContainerTwins

local EMPTY = {}

--- Whether `cfg` draws a glow: a text container with its `text.glow` leaf on. The one predicate
--- LevelMain, Build and Place all ask, so a bars or icons container with a stale true leaf gets
--- neither twins nor a main level write.
function Twins.On(cfg)
    if not cfg or NS.Style.StyleKey(cfg) ~= "text" then return false end
    return (cfg.text and cfg.text.glow) and true or false
end

--- `frame`'s level when it reads as a plain number, else `fallback`. Guarded: a level is a secret
--- aspect on an attachable frame (docs/midnight-quirks.md), and arithmetic on a secret raises.
local function levelOf(frame, fallback)
    local ok, v = pcall(frame.GetFrameLevel, frame)
    if not ok then return fallback end
    return NS.Secrets.NumberOr(v, fallback)
end

--- Holder k's offset from the anchor: thickness × d_k + (glowX, glowY).
--- @return number x, number y
function Twins.Offset(cfg, k)
    local s, D = cfg.text or EMPTY, NS.CONTAINER_TEMPLATE.text
    local t = tonumber(s.glowThickness) or D.glowThickness
    local d = NS.Constants.TEXT_GLOW_RING[k]
    return t * d[1] + (tonumber(s.glowX) or D.glowX), t * d[2] + (tonumber(s.glowY) or D.glowY)
end

--- Decide and write the main engine's level, with the glow on, in the window before its first group
--- (ContainerClass:Build). Answers it, or nil, writing nothing, while the glow is off. A refused write
--- (callEngine logs it once) falls back to the main's level as read, so the twins still level against
--- the main as it is.
--- @return number|nil
function Twins.LevelMain(self, engine, cfg)
    if not Twins.On(cfg) then return nil end
    local stored = tonumber((cfg.layout or EMPTY).level) or NS.CONTAINER_TEMPLATE.layout.level
    local a = levelOf(self.anchor, stored)
    local V = NS.Constants.LAYERS.LEVEL
    local level = math.max(a + V.CONTENT, V.GLOW_GAP + 1)
    if NS.Container.CallEngine(engine, "SetFrameLevel", level) then return level end
    return levelOf(engine, a + 1)
end

--- Holder k, made on first need with the anchor's own template, and kept.
local function holderFor(self, k)
    local holders = self.holders or {}
    self.holders = holders
    local h = holders[k]
    if not h then
        h = CreateFrame("Frame", nil, self.anchor, "DisableUntrustedLayoutScriptsTemplate")
        holders[k] = h
    end
    return h
end

--- Pin holder k to the anchor's rect, moved by the ring offset.
local function pin(self, h, cfg, k)
    local x, y = Twins.Offset(cfg, k)
    local anchor = self.anchor
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
    h:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", x, y)
end

--- Build twin k, in the order its holder and the engine need: the holder lowered first, then the twin
--- made under it, leveled, flowed, anchored and sized before its first group, its unit last
--- (Container.Populate). Answers false when the twin could not be made.
--- @return boolean
local function buildTwin(self, k, cfg, plan, view, flow, level)
    local Container, V = NS.Container, NS.Constants.LAYERS.LEVEL
    local h = holderFor(self, k)
    h:SetFrameLevel(math.max(0, level - V.GLOW_GAP + V.GLOW_HOLDER))
    pin(self, h, cfg, k)
    local twin = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
    if not twin then return false end
    Container.CallEngine(twin, "SetFrameLevel", math.max(0, level - V.GLOW_GAP))
    Container.ApplyFlow(twin, cfg)
    local ex, ey = Container.EngineOffset(flow.growH, flow.growV)
    twin:ClearAllPoints()
    twin:SetPoint(flow.anchorPoint, h, flow.anchorPoint, ex, ey)
    twin:SetSize(1, 1)
    local frames = {}
    Container.Populate(twin, cfg, plan, view, function(frame) self:InitTwinFrame(frame, k) end, frames)
    self.twins[k], self.twinEnchantFrames[k] = twin, frames
    return true
end

--- Build the twins of a main engine just built (ContainerClass:Build), with its plan, view and flow
--- and the level LevelMain decided for it. None while the glow is off. A twin that cannot be made
--- ends the build: every walk below is an ipairs, so a twin built past a hole would draw on with no
--- update, view switch, hide or retire ever reaching it.
function Twins.Build(self, cfg, plan, view, flow, level)
    self.twins, self.twinEnchantFrames = {}, {}
    if not (level and Twins.On(cfg)) then return end
    for k = 1, NS.Constants.TEXT_GLOW_TWINS do
        if not buildTwin(self, k, cfg, plan, view, flow, level) then return end
    end
end

--- Re-point every holder at the current ring offset and re-level it from the main's current level,
--- on every apply (ContainerClass:Apply). Holders are ours, so these are plain writes; no engine is
--- written. An unreadable main level leaves the levels as they are.
function Twins.Place(self, cfg)
    if not (self.engine and Twins.On(cfg)) then return end
    local main = levelOf(self.engine, nil)
    local V = NS.Constants.LAYERS.LEVEL
    for k, h in ipairs(self.holders or EMPTY) do
        pin(self, h, cfg, k)
        if main then h:SetFrameLevel(math.max(0, main - V.GLOW_GAP + V.GLOW_HOLDER)) end
    end
end

--- The live twins, in ring order: `for k, twin in Twins.Each(self)`.
function Twins.Each(self)
    return ipairs(self.twins or EMPTY)
end

--- Send `method` to every twin through callEngine. Answers whether every send went through.
--- @return boolean
function Twins.Send(self, method, ...)
    local ok, call = true, NS.Container.CallEngine
    for _, twin in ipairs(self.twins or EMPTY) do
        ok = call(twin, method, ...) and ok
    end
    return ok
end

--- Retire the twins with their main (ContainerClass:Retire): disabled, hidden and set aside on
--- `retiredTwins`, never `retired`, whose count means main engines. The holders are kept.
function Twins.Retire(self)
    local twins = self.twins
    if not twins then return end
    local retired = self.retiredTwins or {}
    self.retiredTwins = retired
    for _, twin in ipairs(twins) do
        NS.Container.CallEngine(twin, "SetEnabled", false)
        twin:Hide()
        retired[#retired + 1] = twin
    end
    self.twins, self.twinEnchantFrames = {}, {}
end

--- How many live twins the container has (the [Cont] line's `twins=`).
function Twins.Count(self)
    return #(self.twins or EMPTY)
end
