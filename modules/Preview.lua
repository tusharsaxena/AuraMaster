local _, NS = ...

-- modules/Preview.lua — placeholder auras, so a container can be seen, styled and placed without
-- waiting for a real buff (preview-mode).
--
-- WHY THESE ARE NOT ENGINE FRAMES. Blizzard's aura engine only ever shows real auras; there is no way
-- to hand it a fake one. So preview elements are Buttons of our own, dressed by the SAME Style code the
-- engine's buttons are (modules/Style*.lua, with `engine` false) and laid out by the same flow rules
-- the engine uses, with invented values filled in. Everything a player changes on the Bars or Icons
-- page therefore shows up here exactly as it will on a real aura.
--
-- Preview is on whenever the addon is UNLOCKED, or when `/am test` turns it on; while it is, each
-- container's engine is disabled so real auras do not draw on top of the placeholders.

NS.Preview = NS.Preview or {}
local Preview = NS.Preview

local C = NS.Constants

--- Where preview element `index` (1-based) sits relative to the anchor, for `cfg`'s flow settings.
--- Pure arithmetic, so the layout rules are testable headlessly.
--- @return string point, number x, number y
function Preview.Offset(cfg, index)
    local w, h = NS.Style.ElementSize(cfg)
    local L = cfg.layout or {}
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

local function factory(parent)
    return function()
        local f = CreateFrame("Button", nil, parent)
        f:EnableMouse(false)
        return f
    end
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

--- How many placeholders `cfg` shows: every placeholder aura, under the per-group cap, and at most
--- two (main hand and off hand) for a weapon-enchant container.
local function placeholderCount(cfg)
    local count = #C.PREVIEW_AURAS
    local cap = tonumber(cfg.filter and cfg.filter.maxAuras) or 0
    if cap > 0 and cap < count then count = cap end
    if cfg.auraType == "ENCHANT" then count = math.min(count, 2) end
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
    local style = (cfg.style == "icons") and "icons" or "bars"
    local pool = poolFor(container, style)
    local count = placeholderCount(cfg)
    local styler = (style == "icons") and NS.Style.Icons or NS.Style.Bars
    local make = container.previewFactory or factory(container.anchor)
    container.previewFactory = make
    for i = 1, count do
        local f = NS.Pool.Acquire(pool, make)
        NS.Style.Element(f, cfg, false, container.classColor)
        styler.FillPreview(f, C.PREVIEW_AURAS[i], cfg)
        local point, x, y = Preview.Offset(cfg, i)
        f:ClearAllPoints()
        f:SetPoint(point, container.anchor, point, x, y)
    end
    container.previewShown, container.previewDirty = true, false
end

--- Remove one container's placeholders, of every style.
function Preview.Hide(container)
    if container.previewPools then releaseAll(container.previewPools) end
    container.previewShown = false
end
