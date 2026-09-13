local _, NS = ...

-- modules/Container.lua — one live container: its anchor, its drag handle, and the Blizzard aura
-- engine that actually draws its auras.
--
-- BUILD, UPDATE OR REBUILD. A container's settings compile (modules/FilterCompiler.lua) into a plan of
-- aura groups. The engine lets most of a group change live — filter string, candidate filters,
-- sorting, cap, layout — so a plan with the same SHAPE as the last one (same number of groups, same
-- enchant slots and hide-permanent flag, same style) is applied in place and every existing button is
-- restyled. A plan of a different shape needs a new engine: groups are add-only and a frame once
-- created is never destroyed, so the old engine is disabled, hidden and set aside, and a fresh one is
-- built. That only happens on a settings change, never in play.
--
-- NEVER WHILE AURAS ARE SECRET. Building, updating and restyling all touch aura buttons, which the
-- engine locks while auras are secret. modules/ContainerManager.lua holds every apply until secrecy
-- lifts; this file assumes it is only called when it is safe.

NS.Container = NS.Container or {}
local ContainerClass = {}
ContainerClass.__index = ContainerClass

local Perf = NS.Perf
local D = NS.CONTAINER_TEMPLATE
local HUGE = math.huge

local function callEngine(engine, method, ...)
    local fn = engine and engine[method]
    if type(fn) ~= "function" then return false end
    local ok, err = pcall(fn, engine, ...)
    if not ok and NS.Debug then NS.Debug("Engine", "%s failed: %s", method, err) end
    return ok
end

--- A new live container for stored container `id`. Builds the anchor and the handle; the engine is
--- built by the first Apply.
function NS.Container.New(id)
    local self = setmetatable({ id = id, retired = {}, enchantFrames = {} }, ContainerClass)
    -- DisableUntrustedLayoutScriptsTemplate: the anchor may be attached to ANOTHER container's engine
    -- frame (modules/Anchors.lua), and Blizzard refuses that anchoring to any frame without it.
    self.anchor = CreateFrame("Frame", "AuraMasterAnchor" .. id, UIParent,
        "DisableUntrustedLayoutScriptsTemplate")
    self.anchor:SetMovable(true)
    -- Movable frames are saved in the client's layout cache and restored at login over the stored
    -- position; the stored position is the only one.
    if self.anchor.SetDontSavePosition then self.anchor:SetDontSavePosition(true) end
    self.anchor:SetClampedToScreen(true)
    self.handle = NS.Anchors.BuildHandle(self)
    return self
end

function ContainerClass:Cfg()
    return NS.Database.FindContainer(self.id)
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

--- A layout's growth, normalized: "right" unless "left", "down" unless "up". Published for the drag
--- handle (modules/Anchors.lua), which sits on the side the auras do not grow into.
local function growthOf(L)
    return (L.growH == "left") and "left" or "right", (L.growV == "up") and "up" or "down"
end
NS.Container.Growth = growthOf

--- The corner auras grow away from: auras growing down and right start at the top left.
function NS.Container.AnchorPoint(growH, growV)
    return ((growV == "down") and "TOP" or "BOTTOM") .. ((growH == "right") and "LEFT" or "RIGHT")
end

--- How long one line may get before the engine starts the next: `perLine` elements, or no limit.
local function maxLineSize(perLine, elementSize, spacing)
    if perLine <= 0 then return HUGE end
    return perLine * elementSize + (perLine - 1) * spacing
end

--- The engine's flow-layout settings for `cfg`, as plain values (a test seam as much as a helper).
--- @return table { axis, anchorPoint, growH, growV, maxLineSize }
function NS.Container.FlowSettings(cfg)
    local L = cfg.layout or {}
    local w, h = NS.Style.ElementSize(cfg)
    local vertical = (L.axis == "vertical")
    local growH, growV = growthOf(L)
    return {
        axis        = vertical and "vertical" or "horizontal",
        anchorPoint = NS.Container.AnchorPoint(growH, growV),
        growH       = growH,
        growV       = growV,
        maxLineSize = maxLineSize(tonumber(L.perLine) or 0, vertical and h or w, tonumber(L.spacing) or 0),
    }
end

--- The per-group layout table the engine takes (AddAuraGroup's `layout`).
local function groupLayout(cfg, index)
    local L = cfg.layout or {}
    local w, h = NS.Style.ElementSize(cfg)
    local spacing, lineSpacing = tonumber(L.spacing) or 0, tonumber(L.lineSpacing) or 0
    return {
        elementSpacing = spacing, lineSpacing = lineSpacing,
        groupSpacing = spacing, groupLineSpacing = lineSpacing,
        elementWidth = w, elementHeight = h, layoutIndex = index,
    }
end

local function applyFlow(engine, cfg)
    local Compat = NS.Compat
    local flow = NS.Container.FlowSettings(cfg)
    callEngine(engine, "SetFlowLayoutAxis", Compat.FlowAxis(flow.axis))
    callEngine(engine, "SetFlowLayoutAnchorPoint", flow.anchorPoint)
    callEngine(engine, "SetFlowLayoutGrowthDirection", Compat.FlowDirection(flow.growH),
        Compat.FlowDirection(flow.growV))
    callEngine(engine, "SetFlowLayoutPadding", 0, 0, 0, 0)
    callEngine(engine, "SetFlowLayoutMaximumLineSize", flow.maxLineSize)
    return flow
end

-- ---------------------------------------------------------------------------
-- Engine build / update
-- ---------------------------------------------------------------------------

function ContainerClass:InitFrame(frame)
    local cfg = self:Cfg()
    if cfg then NS.Style.Element(frame, cfg, true, self.classColor) end
end

-- ---------------------------------------------------------------------------
-- Class color, snapshotted per apply
-- ---------------------------------------------------------------------------
-- A container tracking another unit paints its class colors with that unit's class (options-ui-§17).
-- The class is read HERE, once per apply — and an apply only runs while auras are readable — then
-- used by every dress until the next one: engine buttons created mid-combat, a restyle, the preview.
-- So every button of one container shows one class at every moment. A swap of the tracked unit to a
-- different class re-applies the container (modules/ContainerManager.lua's RefreshUnit), or marks it
-- stale while that has to wait.

--- A unit's class color, or nil when it does not resolve. Guarded, because the unit is not the
--- player: a class token the client withholds (a secret) raises where the library indexes
--- RAID_CLASS_COLORS with it, and that failure is an unresolved class, painted with the swatch.
function NS.Container.ClassOf(unit)
    local ok, r, g, b = pcall(NS.ClassColor, unit)
    if not ok then return nil end
    return r, g, b
end

--- The tracked unit's class as { r, g, b }, in a table reused per instance. When the class does not
--- resolve (an NPC, no such unit) the channels are nil, and Style.Color falls through to the swatch.
function ContainerClass:ResolveUnitClass(unit)
    local c = self.classBuf or {}
    self.classBuf = c
    c.r, c.g, c.b = NS.Container.ClassOf(unit)
    return c
end

--- Record the class this apply paints with, and whether a unit swap has to re-apply the container.
--- An enchant container shows the player's enchants whatever its unit, so it describes the player.
--- The class read here is the current one, so a stale mark (ContainerManager.RefreshUnit) is settled
--- too: an apply that ran on the flush ending a hold must not be followed by ReapplyStaleClass's.
function ContainerClass:SnapshotClass(cfg)
    local unit = (cfg.auraType == "ENCHANT") and "player" or cfg.unit
    local tracked = unit ~= "player"
    self.classColor = tracked and self:ResolveUnitClass(unit) or nil
    self.usesClass = tracked and NS.Style.UsesClassColor(cfg)
    self.classStale = nil
end

function ContainerClass:Retire()
    local engine = self.engine
    if not engine then return end
    callEngine(engine, "SetEnabled", false)
    -- Hidden, never re-anchored: once a group exists the engine forbids untrusted layout work on
    -- itself, and a disabled, hidden engine draws nothing wherever it is anchored.
    engine:Hide()
    self.retired[#self.retired + 1] = engine
    self.engine, self.structure, self.plan, self.enchantDir = nil, nil, nil, nil
    self.enchantFrames = {}
end

function ContainerClass:Build(cfg, plan, structure)
    local Compat = NS.Compat
    local anchor = self.anchor
    local engine = CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
    if not engine then return end
    self.engine = engine

    -- Anchor the engine BEFORE adding any group: AddAuraGroup forbids untrusted layout scripts on the
    -- container, after which an addon can no longer anchor it (Blizzard_CustomAuraContainer.lua).
    local flow = applyFlow(engine, cfg)
    engine:ClearAllPoints()
    engine:SetPoint(flow.anchorPoint, anchor, flow.anchorPoint, 0, 0)
    -- A provisional size: the engine drains its parse and layout work from an OnUpdate that runs only
    -- while visible, so it needs a renderable rect from its first dirty mark. Every layout pass then
    -- replaces the size with the real one (CustomAuraContainerFlowLayoutMixin:OnLayoutComplete).
    engine:SetSize(1, 1)

    local init = function(frame) self:InitFrame(frame) end
    for i, g in ipairs(plan.groups) do
        callEngine(engine, "AddAuraGroup", g.key, g.filter, {
            initializeFrame  = init,
            candidateFilters = g.candidateFilters,
            sortMethod       = Compat.SortMethod(g.sortMethod),
            sortDirection    = Compat.SortDirection(g.sortDirection),
            maxFrameCount    = g.maxFrameCount,
            layout           = groupLayout(cfg, i),
        })
    end

    self.enchantFrames = {}
    if plan.enchants then
        local layout = groupLayout(cfg, #plan.groups + 1)
        layout.placement = Compat.EnchantPlacementAfter()
        callEngine(engine, "SetItemEnchantmentSortMethod", Compat.EnchantSortByDuration(),
            Compat.SortDirection(cfg.filter and cfg.filter.sortDirection))
        callEngine(engine, "SetItemEnchantmentLayout", layout)
        for _, slot in ipairs(plan.enchants.slots) do
            local ok, frame = pcall(engine.AddItemEnchantment, engine, Compat.EnchantSlot(slot), {
                initializeFrame = init, hidePermanent = plan.enchants.hidePermanent,
            })
            if ok and frame then
                self.enchantFrames[#self.enchantFrames + 1] = frame
            end
        end
    end

    -- The unit LAST, once every group exists, so the engine registers UNIT_AURA for a container that
    -- already knows what it is looking for.
    callEngine(engine, "SetUnit", (cfg.auraType == "ENCHANT") and "player" or cfg.unit)
    self.unit = cfg.unit
    self.enchantDir = cfg.filter and cfg.filter.sortDirection
    self.plan, self.structure = plan, structure
end

--- The enchant slots on a live engine: the layout every time, the sort only when the direction moved
--- (recorded, so later updates do not re-send it). hidePermanent cannot change here; it is part of
--- the structure key, so toggling it rebuilds.
local function updateEnchants(self, engine, cfg, plan)
    if not plan.enchants then return end
    local Compat = NS.Compat
    local layout = groupLayout(cfg, #plan.groups + 1)
    layout.placement = Compat.EnchantPlacementAfter()
    callEngine(engine, "SetItemEnchantmentLayout", layout)
    local dir = cfg.filter and cfg.filter.sortDirection
    if dir ~= self.enchantDir then
        callEngine(engine, "SetItemEnchantmentSortMethod", Compat.EnchantSortByDuration(),
            Compat.SortDirection(dir))
        self.enchantDir = dir
    end
end

function ContainerClass:Update(cfg, plan)
    local Compat = NS.Compat
    local engine = self.engine
    local old = self.plan
    local Sig = NS.FilterCompiler.Signature
    applyFlow(engine, cfg)
    for i, g in ipairs(plan.groups) do
        local o = old.groups[i]
        if o.filter ~= g.filter then
            callEngine(engine, "SetAuraGroupFilterString", g.key, g.filter)
        end
        if Sig(o.candidateFilters) ~= Sig(g.candidateFilters) then
            callEngine(engine, "SetAuraGroupCandidateFilters", g.key, g.candidateFilters or {})
        end
        if o.sortMethod ~= g.sortMethod or o.sortDirection ~= g.sortDirection then
            callEngine(engine, "SetAuraGroupSortMethod", g.key, Compat.SortMethod(g.sortMethod),
                Compat.SortDirection(g.sortDirection))
        end
        if o.maxFrameCount ~= g.maxFrameCount then
            callEngine(engine, "SetAuraGroupMaxFrameCount", g.key, g.maxFrameCount)
        end
        callEngine(engine, "SetAuraGroupLayout", g.key, groupLayout(cfg, i))
    end
    updateEnchants(self, engine, cfg, plan)
    local unit = (cfg.auraType == "ENCHANT") and "player" or cfg.unit
    if self.unit ~= cfg.unit then
        callEngine(engine, "SetUnit", unit)
        self.unit = cfg.unit
    end
    self.plan = plan
    self:Restyle(cfg)
end

--- Re-dress every button the engine has created, from the current settings.
function ContainerClass:Restyle(cfg)
    local engine = self.engine
    if not (engine and self.plan) then return end
    local count = 0
    for _, g in ipairs(self.plan.groups) do
        local ok, n = pcall(engine.GetAuraGroupFrameCount, engine, g.key)
        for i = 1, (ok and n or 0) do
            local okF, frame = pcall(engine.GetAuraGroupFrame, engine, g.key, i)
            if okF and frame then
                pcall(NS.Style.Element, frame, cfg, true, self.classColor)
                count = count + 1
            end
        end
    end
    for _, frame in ipairs(self.enchantFrames) do
        pcall(NS.Style.Element, frame, cfg, true, self.classColor)
        count = count + 1
    end
    return count
end

--- Apply the container's current settings. The caller (ContainerManager) guarantees aura secrecy is
--- not active. Returns the plan applied.
function ContainerClass:Apply()
    local cfg = self:Cfg()
    if not cfg then return nil end
    local t0 = Perf.on and debugprofilestop()

    local plan = NS.FilterCompiler.Compile(cfg, NS.FilterCompiler.ProfileContext())
    self.warnings = plan.warnings

    local anchor = self.anchor
    local L = cfg.layout or {}
    local p = NS.db.profile
    anchor:SetScale(math.max(0.1, (tonumber(L.scale) or 1) * (tonumber(p.scale) or 1)))
    anchor:SetFrameStrata(L.strata or D.layout.strata)
    anchor:SetFrameLevel(tonumber(L.level) or D.layout.level)
    self.placedAs = NS.Anchors.Place(self)
    -- Before any dress below: Update restyles, and Build's buttons are dressed as they are created.
    self:SnapshotClass(cfg)

    if NS.Compat.HasAuraContainer() then
        local structure = NS.FilterCompiler.StructureKey(plan) .. ":" .. tostring(cfg.style)
        if self.engine and self.structure == structure then
            self:Update(cfg, plan)
        else
            self:Retire()
            self:Build(cfg, plan, structure)
        end
    end

    -- The look may have changed, so the next visibility pass re-dresses the preview (Preview.Show).
    self.previewDirty = true
    -- Built for the data now stored under this id, so a container parked by a profile change while
    -- an apply must wait (combat or aura secrecy), including one marked staleData, may draw again.
    self.parked, self.staleData = nil, nil
    self:ApplyVisibility()
    if t0 then Perf.Note("applyContainer", debugprofilestop() - t0, "applyPass") end
    return plan
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------

--- Whether General visibility lets containers show right now (options-ui-§15's four values).
local function visibilityAllows(vis)
    if vis == "never" then return false end
    if vis == "inCombat" or vis == "outOfCombat" then
        local inCombat = UnitAffectingCombat("player") and true or false
        return (vis == "inCombat") == inCombat
    end
    return true
end

--- The show ladder, in order. Step 0 is the perf probe's suspend (performance-§6): nothing below it
--- can re-enable a container behind suspend's back. A parked container (Park) shows nothing either:
--- its engine may still be built for a container that no longer lives under its id.
--- @return boolean show, boolean previewing
function ContainerClass:ShouldShow()
    if NS.Perf.suspended or self.parked then return false, false end
    local p = NS.db and NS.db.profile
    local cfg = self:Cfg()
    if not (p and cfg and p.enabled and cfg.enabled) then return false, false end
    local previewing = (not p.locked) or (NS.State and NS.State.preview) or false
    return visibilityAllows(p.visibility), previewing
end

--- Enable or disable the engine and show or hide the preview and the handle. Uses the engine's own
--- SetEnabled rather than hiding the anchor, because this runs on every combat transition, when an
--- aura button's ancestry must not be shown or hidden.
function ContainerClass:ApplyVisibility()
    local show, previewing = self:ShouldShow()
    local p = NS.db and NS.db.profile
    local cfg = self:Cfg()
    if self.engine then callEngine(self.engine, "SetEnabled", show and not previewing) end
    local L = cfg and cfg.layout or {}
    self.anchor:SetAlpha((tonumber(L.alpha) or 1) * (tonumber(p and p.alpha) or 1))
    if previewing and cfg then
        NS.Preview.Show(self)
    else
        NS.Preview.Hide(self)
    end
    NS.Anchors.UpdateHandle(self, previewing and p and not p.locked)
    return show, previewing
end

--- Tell the engine its unit may now be someone else (target / focus / pet changed).
function ContainerClass:Refresh()
    if self.engine then callEngine(self.engine, "UpdateAllAuras") end
end

--- Set the container aside under combat lockdown, when its anchor and the engine's ancestry must not
--- be shown, hidden or re-anchored (events-frames-taint-§2): the engine is disabled — combat-legal,
--- the same call ApplyVisibility makes — and only our own preview and handle are hidden.
--- modules/ContainerManager.lua destroys a parked container once combat ends, or revives it if its
--- id comes back first.
function ContainerClass:Park()
    if self.engine then callEngine(self.engine, "SetEnabled", false) end
    NS.Preview.Hide(self)
    if self.handle then self.handle:Hide() end
    self.parked = true
end

--- Tear the container down for good: the engine is retired and the anchor hidden. Frames are never
--- destroyed in WoW, so this is as far as "delete" can go. Only ever reached out of lockdown; under
--- lockdown the container is parked instead.
function ContainerClass:Destroy()
    self:Retire()
    NS.Preview.Hide(self)
    if self.handle then self.handle:Hide() end
    self.anchor:Hide()
    self.anchor:ClearAllPoints()
end
