local _, NS = ...

-- modules/Container.lua — one live container: its anchor, its drag handle, and the Blizzard aura
-- engine that actually draws its auras.
--
-- BUILD, UPDATE OR REBUILD. A container's settings compile (modules/FilterCompiler.lua) into a plan of
-- aura groups. The engine lets most of a group change live — filter string, candidate filters,
-- sorting, cap, layout — so a plan with the same SHAPE as the last one (same number of groups, same
-- enchant slots and hide-permanent flag, same style, same growth corner) is applied in place and
-- every existing button is restyled. A plan of a different shape needs a new engine: groups are
-- add-only, the engine is pinned at its growth corner before its first group and never again, and a
-- frame once created is never destroyed, so the old engine is disabled, hidden and set aside, and a
-- fresh one is built. That only happens on a settings change, never in play.
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
-- The unlocked outline's opacity: faint enough to read as a guide, never as a border (B1).
local OUTLINE_ALPHA = 0.35

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
--- The axis and growth are the EFFECTIVE ones: a container attached to another continues its chain
--- root's flow (Anchors.EffectiveLayout, L-6). The per-line count and spacing are always its own.
--- @return table { axis, anchorPoint, growH, growV, maxLineSize }
function NS.Container.FlowSettings(cfg)
    local L = NS.Anchors.EffectiveLayout(cfg) or {}
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
--- The class read here is the current one, so a stale mark (ContainerManager.RefreshUnit) is settled
--- too: an apply that ran on the flush ending a hold must not be followed by ReapplyStaleClass's.
function ContainerClass:SnapshotClass(cfg)
    local unit = cfg.unit
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
    -- The blocker is anchored to THIS engine (SetAllPoints); hidden with it rather than left covering
    -- a retired frame until Build re-anchors it to the replacement.
    if self.blocker then self.blocker:Hide() end
    self.retired[#self.retired + 1] = engine
    self.engine, self.structure, self.plan, self.enchantDir = nil, nil, nil, nil
    self.enchantFrames = {}
end

--- Create or refresh the container-wide mouse blocker (Style.ApplyBlockerBehavior, L-3 continued):
--- one frame, made once and kept for the container's life, re-anchored to cover WHATEVER engine
--- currently exists and re-gated on the current settings every apply — the same behavior block a
--- live button re-applies. DisableUntrustedLayoutScriptsTemplate, like the anchor itself (New,
--- above) and the frame picker's outline: a frame anchored TO an aura container must carry it or the
--- engine refuses the point (docs/midnight-quirks.md).
---
--- Its level is read from the engine's ACTUAL, current level and set one below that (floored at 0)
--- EVERY apply, never assumed or computed from the anchor: the anchor's own level can be raised by a
--- later apply (layout.level) without the engine's level following it, so deriving the blocker from
--- anything but the engine itself would only hold by coincidence. GetFrameLevel is
--- a read, not a protected mutation, so this never goes through callEngine; ApplyBlocker still never
--- WRITES to the engine, which forbids untrusted work once a group exists (Retire's comment,
--- callEngine) and might refuse a level change reached through the Update path on a live engine.
function ContainerClass:ApplyBlocker(cfg)
    local engine, anchor = self.engine, self.anchor
    if not engine then return end
    local blocker = self.blocker
    if not blocker then
        blocker = CreateFrame("Frame", nil, anchor, "DisableUntrustedLayoutScriptsTemplate")
        self.blocker = blocker
    end
    local ok, engineLevel = pcall(engine.GetFrameLevel, engine)
    -- Guarded (feedback E): an engine's level can read secret, and arithmetic on it raises.
    local level = ok and NS.Secrets.NumberOr(engineLevel, 0) or 0
    blocker:SetFrameLevel(math.max(0, level - 1))
    blocker:ClearAllPoints()
    blocker:SetAllPoints(engine)
    NS.Style.ApplyBlockerBehavior(blocker, cfg)
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
    callEngine(engine, "SetUnit", cfg.unit)
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
    if self.unit ~= cfg.unit then
        callEngine(engine, "SetUnit", cfg.unit)
        self.unit = cfg.unit
    end
    self.plan = plan
    self:Restyle(cfg)
end

--- Re-dress one live button, guarded: a dress that raises costs that button and is reported
--- (Style.ReportError, smoke batch 2 item 7), never swallowed and never the rest of the restyle.
local function redress(frame, cfg, classColor)
    local ok, err = pcall(NS.Style.Element, frame, cfg, true, classColor)
    if not ok then NS.Style.ReportError("restyle", err) end
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
                redress(frame, cfg, self.classColor)
                count = count + 1
            end
        end
    end
    for _, frame in ipairs(self.enchantFrames) do
        redress(frame, cfg, self.classColor)
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
        -- The style, and for a text container its template's shape (Style.StructureKey): a new
        -- shape gets new buttons, so no engine binding is left in the old shape's font strings.
        -- The growth corner too (the effective one, a follower's inherited): Build pins the engine
        -- there and it can never be re-anchored after its first group, so a new corner needs a new
        -- engine. An axis, spacing or per-line change keeps the corner and stays in place.
        local structure = NS.FilterCompiler.StructureKey(plan) .. ":" .. NS.Style.StructureKey(cfg)
            .. ":" .. NS.Container.FlowSettings(cfg).anchorPoint
        if self.engine and self.structure == structure then
            self:Update(cfg, plan)
        else
            self:Retire()
            self:Build(cfg, plan, structure)
        end
        self:ApplyBlocker(cfg)
    end
    -- After SnapshotClass (its class color is the tracked unit's) and outside the engine branch: the
    -- label is our own frame and draws on a client without the engine too.
    self:ApplyLabel(cfg)

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

--- The show ladder, in order. STEP 0 IS THE LATCH (slash-commands-§7, core/LifecycleSetup.lua):
--- whether the addon is running at all, for either reason it might not be -- the player switched it
--- off, or a perf capture is measuring its suspended arm. Nothing below it can re-show a container
--- behind the latch's back, which is why the stand-down refuses AT THE SOURCE rather than hiding
--- frames imperatively: a hidden frame comes back on the next combat transition or target swap.
--- The stored `enabled` path is NOT read again here: on a build with no LibKa0s the degraded
--- NS.IsStoodDown answers from that path itself, so step 0 is the one question.
--- A parked container (Park) shows nothing either: its engine may still be built for a container
--- that no longer lives under its id.
---
--- PREVIEWING IS THE TEST MODE (NS.State.testMode), not the lock (B1): unlocking makes a container
--- draggable and its live auras keep drawing. An UNLOCKED container shows whatever its visibility
--- rule says, so one set to "in combat only" can still be found and moved out of combat. A container
--- in TEST MODE shows too, locked or not: the mode shows the display without an unlock
--- (options-ui-§15).
--- @return boolean show, boolean previewing
function ContainerClass:ShouldShow()
    if NS.IsStoodDown() or self.parked then return false, false end
    local p = NS.db and NS.db.profile
    local cfg = self:Cfg()
    if not (p and cfg and cfg.enabled) then return false, false end
    local previewing = NS.State.testMode and true or false
    return (not p.locked) or previewing or visibilityAllows(p.visibility), previewing
end

--- The anchor's own half of a stand-down (see ApplyVisibility). Returns whether combat deferred it.
function ContainerClass:ApplyAnchorShown()
    if NS.IsStoodDown() then
        if InCombatLockdown() then return true end
        self.anchor:Hide()
    elseif not self.anchor:IsShown() and not InCombatLockdown() then
        self.anchor:Show()
    end
    return false
end

--- The engine's enable and the mouse blocker, which follow one rule: shown and not previewing.
function ContainerClass:ApplyLive(on)
    if self.engine then callEngine(self.engine, "SetEnabled", on) end
    if self.blocker then self.blocker:SetShown(on) end
end

--- The anchor's alpha: the container's own times Master alpha.
function ContainerClass:ApplyAlpha(cfg, p)
    local L = cfg and cfg.layout or {}
    self.anchor:SetAlpha((tonumber(L.alpha) or 1) * (tonumber(p and p.alpha) or 1))
end

--- The unlocked container's OUTLINE (B1), its empty-only PLACEHOLDER (batch 9 HG-1): a faint
--- one-pixel box, one element's size, at the corner its flow starts from, so an EMPTY container can
--- still be seen while unlocked and its followers hang from it. Shown only while the container is
--- predicted empty (modules/EmptyWatch.lua) and hung as `slot`; hidden when it holds auras or that is
--- not knowable, when locked, and in test mode (the placeholders are there then). A frame of ours
--- under the anchor, never the engine's. It takes no mouse: the drag handle does the grabbing. A PLAIN frame
--- with its edge drawn as strips (Style.DrawEdge), never a BackdropTemplate: under an anchor attached
--- to another frame or container its size can read secret, and the Backdrop does arithmetic on the
--- size on every SetBackdrop and resize (docs/midnight-quirks.md, "A backdrop on an engine button
--- reads a secret size").
function ContainerClass:ApplyOutline(cfg, on)
    local o = self.outline
    if not on then
        if o then o:Hide() end
        return
    end
    if not o then
        o = CreateFrame("Frame", nil, self.anchor)
        NS.Style.DrawEdge(o, 1, 1, 1, 1, OUTLINE_ALPHA)
        o:EnableMouse(false)
        self.outline = o
    end
    local w, h = NS.Style.ElementSize(cfg)
    local point = NS.Preview.Offset(cfg, 1)
    o:ClearAllPoints()
    o:SetPoint(point, self.anchor, point, 0, 0)
    o:SetSize(w, h)
    o:Show()
end

--- The optional NAME LABEL (batch 8 NL-1..NL-3): the container's name where its strip sits
--- (Anchors.PlaceLabel), built on the first apply that turns it on. A PLAIN frame under the anchor,
--- taking no mouse and never a backdrop, like the outline: it inherits the anchor's scale, alpha and
--- stand-down. Its font, text and place are set here, in Apply, which is kept out of lockdown; the
--- visibility pass only shows or hides it (ApplyLabelShown). Its class color is the snapshot's, or the
--- player's for a player container (Style.ColorWith).
function ContainerClass:ApplyLabel(cfg)
    local lc = cfg.label
    if not (lc and lc.show) then return end
    if not self.label then
        local host = CreateFrame("Frame", nil, self.anchor)
        host:EnableMouse(false)
        self.label, self.labelText = host, host:CreateFontString(nil, "OVERLAY")
    end
    local fs = self.labelText
    NS.Style.ApplyFont(fs, lc.font or D.label.font, D.label.font, self.classColor or false)
    fs:SetText(tostring(cfg.name or ""))
    NS.Anchors.PlaceLabel(self, cfg)
end

--- Show or hide the name label: shown whenever the container is, locked or unlocked, whatever it holds
--- (its contents are secret), and while unlocked beside the strip, which moves out past it (D6). Our
--- own unprotected frame, so combat-legal; it moves only on a first show, having no points before.
--- `labelShown` is what the strip (Anchors.UpdateHandle) and a follower's seam (stripRoom) read.
--- `show` is whether the container shows at all (ShouldShow).
function ContainerClass:ApplyLabelShown(cfg, show)
    local host = self.label
    local lc = cfg and cfg.label
    local on = (show and host and lc and lc.show) and true or false
    self.labelShown = on
    if not host then return end
    if on and not host.placed then NS.Anchors.PlaceLabel(self, cfg) end
    host:SetShown(on)
end

--- Set a renamed container's label text (CM.NotifyRenamed): a rename applies nothing else.
function ContainerClass:RefreshLabelText()
    local cfg = self.labelText and self:Cfg()
    if cfg then self.labelText:SetText(tostring(cfg.name or "")) end
end

--- What a container attached to this one hangs from (Anchors.HangMode): the placeholder block in test
--- mode (L-4); the one-element anchor its outline marks while unlocked, ONLY when predicted empty
--- (`empty == true`, batch 9 HG-1 as amended 2026-09-25); else the engine. Nil, not knowable, counts
--- as not empty: a wrong "not empty" costs the #9 collapse, a wrong "empty" an overlap.
local function hangModeFor(previewing, unlocked, empty)
    if previewing then return "preview" end
    return (unlocked and empty == true) and "slot" or "engine"
end

--- Whether this container is empty right now: true, false, or nil when that is not knowable
--- (modules/EmptyWatch.lua).
--- @return boolean|nil
function ContainerClass:PredictEmpty()
    return NS.EmptyWatch.Predict(self)
end

--- Record what this container's followers hang from and show its placeholder outline to match. The
--- prediction is read only while it can matter: shown, unlocked and not previewing (`watchEmpty`,
--- which EmptyWatch's re-evaluation pass reads).
function ContainerClass:ApplyHang(cfg, show, previewing, unlocked)
    local watch = (unlocked and cfg and not previewing) and true or false
    local empty = nil
    if watch then empty = self:PredictEmpty() end
    self.watchEmpty, self.predictedEmpty = watch, empty
    self.hangMode = hangModeFor(show and cfg and previewing, unlocked and cfg, empty)
    self:ApplyOutline(cfg, watch and self.hangMode == "slot")
end

--- Enable or disable the engine and show or hide the preview and the handle. Uses the engine's own
--- SetEnabled rather than hiding the anchor, because this runs on every combat transition, when an
--- aura button's ancestry must not be shown or hidden. The blocker is OUR OWN frame, not the engine's
--- ancestry, so it is hidden outright rather than disabled — gated the same as the engine's enable,
--- or a disabled-but-still-drawn engine (out-of-combat visibility, the master switch, perf suspend, a
--- parked container) would leave an invisible mouse-blocking rect over the world where nothing shows.
--- @return boolean show, boolean previewing, boolean deferred -- `deferred` when combat refused the
--- anchor half of a stand-down (core/LifecycleSetup.lua re-runs it on PLAYER_REGEN_ENABLED).
function ContainerClass:ApplyVisibility()
    local show, previewing = self:ShouldShow()
    local p = NS.db and NS.db.profile
    local cfg = self:Cfg()
    -- THE ANCHOR ITSELF, and only while the addon is stood down. A stood-down addon draws NOTHING,
    -- and an anchor left shown is a frame of ours still on screen. It is the aura engine's ancestry,
    -- though, so it must not be shown or hidden under combat lockdown (events-frames-taint-§2):
    -- that half waits for PLAYER_REGEN_ENABLED and is reported here as `deferred`.
    local deferred = self:ApplyAnchorShown()
    self:ApplyLive(show and not previewing)
    self:ApplyAlpha(cfg, p)
    if show and previewing and cfg then
        NS.Preview.Show(self)
    else
        NS.Preview.Hide(self)
    end
    local unlocked = (show and p and not p.locked) and true or false
    self:ApplyHang(cfg, show, previewing, unlocked)
    -- Before the strip, which moves out past a shown label (D6).
    self:ApplyLabelShown(cfg, show)
    NS.Anchors.UpdateHandle(self, unlocked)
    NS.Anchors.PlaceAttached(self)
    return show, previewing, deferred
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
    if self.blocker then self.blocker:Hide() end
    if self.outline then self.outline:Hide() end
    NS.Preview.Hide(self)
    if self.handle then self.handle:Hide() end
    if self.label then self.label:Hide() end
    self.hangMode, self.stripShown, self.labelShown = "engine", false, false   -- re-evaluated by the next visibility pass
    self.watchEmpty, self.predictedEmpty = false, nil
    self.parked = true
end

--- Tear the container down for good: the engine is retired and the anchor hidden. Frames are never
--- destroyed in WoW, so this is as far as "delete" can go. Only ever reached out of lockdown; under
--- lockdown the container is parked instead.
function ContainerClass:Destroy()
    self:Retire()
    NS.Preview.Hide(self)
    if self.outline then self.outline:Hide() end
    if self.handle then self.handle:Hide() end
    if self.label then self.label:Hide() end
    self.hangMode, self.stripShown, self.labelShown = "engine", false, false
    self.watchEmpty, self.predictedEmpty = false, nil
    self.anchor:Hide()
    self.anchor:ClearAllPoints()
end
