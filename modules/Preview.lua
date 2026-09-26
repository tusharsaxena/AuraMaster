local _, NS = ...

-- modules/Preview.lua — placeholder auras, so a container can be seen, styled and placed without
-- waiting for a real buff (preview-mode).
--
-- WHY THESE ARE NOT ENGINE FRAMES. Blizzard's aura engine only ever shows real auras; there is no way
-- to hand it a fake one. So preview elements are Buttons of our own, dressed by the SAME Style code the
-- engine's buttons are (modules/Style*.lua, with `engine` false) and laid out by the same flow rules
-- the engine uses, with invented values filled in. Everything a player changes on the Bars, Icons or
-- Text section therefore shows up here exactly as it will on a real aura. A container showing debuffs
-- previews debuffs of every dispel type, one showing buffs previews buffs (C.PREVIEW_AURAS, TD-1).
--
-- Preview is on while TEST MODE is (NS.State.testMode, switched only by Preview.SetTestMode below);
-- while it is, each container's engine is disabled so real auras do not draw on top of the
-- placeholders. Unlocking is separate: it makes containers draggable and leaves live auras drawing
-- (B1, 2026-09-19).

NS.Preview = NS.Preview or {}
local Preview = NS.Preview

local C = NS.Constants

--- Turn test mode on or off: every container shows its placeholder auras while it is on
--- (preview-mode, options-ui-§15). Session-only, never saved. A START in combat is refused with one
--- gray line and changes nothing (the checkbox then reads false again); combat ending it is
--- core/AuraMaster.lua's PLAYER_REGEN_DISABLED, which calls this with false. The Master controls
--- checkbox, `/am test` and the launcher's left-click all come through here.
--- @return boolean  whether test mode is now what was asked for
function Preview.SetTestMode(on)
    on = on and true or false
    if on and InCombatLockdown() then
        NS.Printf("|cff808080%s|r", NS.L["Test mode can't start in combat."])
        return false
    end
    if NS.State.testMode ~= on then
        NS.State.testMode = on
        NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
    end
    if NS.Helpers and NS.Helpers.RefreshScalars then NS.Helpers.RefreshScalars() end
    return true
end

--- Where preview element `index` (1-based) sits relative to the anchor, for `cfg`'s flow settings.
--- Pure arithmetic, so the layout rules are testable headlessly. The axis and growth are the
--- effective ones, inherited by a container attached to another (Anchors.EffectiveLayout, L-6).
--- @return string point, number x, number y
function Preview.Offset(cfg, index)
    local w, h = NS.Style.ElementSize(cfg)
    local L = NS.Anchors.EffectiveLayout(cfg) or {}
    local spacing, lineSpacing = tonumber(L.spacing) or 0, tonumber(L.lineSpacing) or 0
    local perLine = tonumber(L.perLine) or 0
    local vertical = (L.axis == "vertical")
    local i = index - 1
    local along, across
    if perLine > 0 then
        along, across = i % perLine, math.floor(i / perLine)
    else
        along, across = i, 0
    end

    local dx, dy
    if vertical then
        dy = along * (h + spacing)
        dx = across * (w + lineSpacing)
    else
        dx = along * (w + spacing)
        dy = across * (h + lineSpacing)
    end
    local right, down = (L.growH ~= "left"), (L.growV ~= "up")
    local point = (down and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
    return point, right and dx or -dx, down and -dy or dy
end

--- `cfg`'s compiled plan, as the engine would get it.
local function compilePlan(cfg)
    local FC = NS.FilterCompiler
    return FC.Compile(cfg, FC.ProfileContext())
end

--- The placeholder set for `cfg`: the weapon enchants for a container whose plan has enchant slots
--- and no aura group (one showing only Weapon enchants, batch 9 SEP-4), else its buffs or its
--- debuffs by aura type, and the buffs when the type is missing or unknown (batch 8 TD-1). `plan`
--- is its compiled plan when the caller has one; it is compiled here when not.
--- @return table  a list from C.PREVIEW_AURAS, never to be written to
function Preview.AurasFor(cfg, plan)
    local P = C.PREVIEW_AURAS
    if not cfg then return P.HELPFUL end
    plan = plan or compilePlan(cfg)
    if plan.enchants and not plan.groups[1] then return P.ENCHANT end
    return (cfg.auraType == "HARMFUL") and P.HARMFUL or P.HELPFUL
end

-- [placeholder entry] = a plain copy of it with the client's own name and icon, built once per session
-- and never written back into the constant (TD-3). No secret name can reach it: the preview draws only
-- in test mode, which cannot start or stay on in combat (SetTestMode above; core/AuraMaster.lua).
local resolved = {}

--- `a` with the client's name and icon for its spell id, the fixed literals where the client has none.
local function resolve(a)
    local r = resolved[a]
    if r then return r end
    local name, icon = NS.Compat.GetSpellInfo(a.spellId)
    r = {
        name = (type(name) == "string" and name ~= "") and name or a.name,
        icon = (type(icon) == "number") and icon or a.icon,
        remaining = a.remaining, duration = a.duration, stacks = a.stacks, dispel = a.dispel,
    }
    resolved[a] = r
    return r
end

local function factory(parent)
    return function()
        return CreateFrame("Button", nil, parent)
    end
end

--- A placeholder holds the hover exactly when its container's real buttons would (Style.TakesHover),
--- so the world unit under it is not moused over and its tooltip does not show (L-3). It has no aura,
--- so it shows no tooltip of its own. It never takes clicks: those reach whatever is under it, and
--- the drag handle sits above every placeholder (modules/Anchors.lua).
local function setMouse(f, cfg)
    f:SetMouseMotionEnabled(NS.Style.TakesHover(cfg))
    f:SetMouseClickEnabled(false)
end

--- Park every placeholder of every style's pool.
local function releaseAll(pools)
    for _, pool in pairs(pools) do NS.Pool.ReleaseAll(pool) end
end

--- `style`'s pool for `container`, created on demand, after parking every style's placeholders.
local function poolFor(container, style)
    local pools = container.previewPools
    if not pools then
        pools = {}
        container.previewPools = pools
    end
    releaseAll(pools)
    local pool = pools[style]
    if not pool then
        pool = NS.Pool.New()
        pools[style] = pool
    end
    return pool
end

--- How many placeholders `cfg` shows: every placeholder aura of its set, under the per-group cap,
--- and no more than its enchant slots for a container whose plan has no aura group (one showing only Weapon
--- enchants, schema v5: the engine draws those slots and nothing else). The plan is compiled here
--- when the caller has none, not read off the container: Show runs only when the preview is dirty,
--- and a container that has never built an engine has no plan to read.
local function placeholderCount(cfg, plan)
    plan = plan or compilePlan(cfg)
    local count = #Preview.AurasFor(cfg, plan)
    local cap = tonumber(cfg.filter and cfg.filter.maxAuras) or 0
    if cap > 0 and cap < count then count = cap end
    if plan.enchants and not plan.groups[1] then
        local slots = #plan.enchants.slots
        if slots < count then count = slots end
    end
    return count
end

--- Draw the placeholders for one container. They are dressed again only when they were hidden in
--- between or the container's settings were applied since the last dress (`previewDirty`, set by
--- ContainerClass:Apply): a visibility pass alone leaves them as they are.
---
--- ONE POOL PER STYLE (`container.previewPools[style]`, C-4): a placeholder built as a bar is never
--- handed out again as an icon, so a style switch cannot re-dress a frame with the other style's
--- regions (Style.RegionsFor is the element-level guard). Every pool is released before acquiring,
--- so a switch leaves none of the old style's placeholders drawn.
function Preview.Show(container)
    local cfg = container:Cfg()
    if not cfg then return end
    if container.previewShown and not container.previewDirty then return end
    local style = NS.Style.StyleKey(cfg)
    local pool = poolFor(container, style)
    local plan = compilePlan(cfg)
    local count = placeholderCount(cfg, plan)
    local styler = NS.Style.Styler(cfg)
    local make = container.previewFactory or factory(container.anchor)
    container.previewFactory = make
    local auras = Preview.AurasFor(cfg, plan)
    for i = 1, count do
        local f = NS.Pool.Acquire(pool, make)
        NS.Style.Element(f, cfg, false, container.classColor)
        styler.FillPreview(f, resolve(auras[i]), cfg)
        setMouse(f, cfg)
        local point, x, y = Preview.Offset(cfg, i)
        f:ClearAllPoints()
        f:SetPoint(point, container.anchor, point, x, y)
    end
    Preview.Extent(container, count)
    container.previewShown, container.previewDirty = true, false
end

--- The frame a container attached to this one hangs from while this one previews (L-4). The engine
--- is disabled then and keeps only a stale rect (its provisional 1x1 on a fresh build), so a child
--- anchored to it sat on the first placeholder with its handle among them. The extent is a plain
--- frame of ours under the anchor, hung from the corner the placeholders start at and as wide and
--- tall as their block, by Preview.Offset's arithmetic: the child sits where it would beside real
--- auras. It is never hidden, so a child still hanging from it has a rect to hang from.
---
--- Placing it moves every container attached to it, whose anchor parents an aura engine: layout
--- work (events-frames-taint-§2). Under lockdown a placed extent stands; one never placed is placed
--- once, because nothing hangs from it yet (Anchors.Place never runs under lockdown).
--- @return table|nil  the extent, or nil when the container's settings are gone
function Preview.Extent(container, count)
    local cfg = container:Cfg()
    if not cfg then return nil end
    local extent = container.previewExtent
    if not extent then
        extent = CreateFrame("Frame", nil, container.anchor)
        container.previewExtent = extent
    end
    if extent.placed and InCombatLockdown() then return extent end
    local w, h = NS.Style.ElementSize(cfg)
    local corner, farX, farY = Preview.Offset(cfg, 1), 0, 0
    for i = 2, count or placeholderCount(cfg) do
        local _, x, y = Preview.Offset(cfg, i)
        farX, farY = math.max(farX, math.abs(x)), math.max(farY, math.abs(y))
    end
    extent:ClearAllPoints()
    extent:SetPoint(corner, container.anchor, corner, 0, 0)
    extent:SetSize(farX + w, farY + h)
    -- Kept as a plain number: what a follower's strip room reads (Anchors, EO-2). The frame's own
    -- height can read secret under an attached anchor.
    extent.height = farY + h
    extent.placed = true
    return extent
end

--- Remove one container's placeholders, of every style.
function Preview.Hide(container)
    if container.previewPools then releaseAll(container.previewPools) end
    container.previewShown = false
end
