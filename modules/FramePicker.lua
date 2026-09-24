local _, NS = ...

-- modules/FramePicker.lua — point at any frame on screen and click it, to attach a container to it.
--
-- While picking, an overlay tracks the frame under the cursor (GetMouseFoci, through core/Compat.lua),
-- walks up to the nearest NAMED ancestor — a container is stored against a frame's global name, so an
-- unnamed frame cannot be re-found after a /reload — and outlines it with its name beside the cursor.
-- Left-click takes it, right-click or Escape cancels.
--
-- The overlay never takes the mouse itself: if it did, it would be the frame under the cursor.
-- Clicks are read with IsMouseButtonDown, and the picker only arms once both buttons are up, so the
-- click on the "Pick a frame" button that started it cannot pick the frame behind that button.

NS.FramePicker = NS.FramePicker or {}
local FP = NS.FramePicker

local overlay, outline, label
local onPick, onCancel
local armed = false

-- Frames that are never useful as an anchor target: the screen itself, and this addon's own.
local REJECT = { UIParent = true, WorldFrame = true }

--- The nearest named ancestor of `f` that can be an anchor target, and its name.
--- @return table|nil frame, string|nil name
function FP.NamedAncestor(f)
    local hops = 0
    while f and hops < 32 do
        -- A forbidden frame raises on any other method call, so it is asked first and ends the walk.
        if f.IsForbidden and f:IsForbidden() then return nil end
        if f == overlay or f == outline then return nil end
        local name = f.GetName and f:GetName()
        if type(name) == "string" and name ~= "" and not REJECT[name] and not name:match("^AuraMaster") then
            return f, name
        end
        f = f.GetParent and f:GetParent() or nil
        hops = hops + 1
    end
    return nil
end

local function stop()
    armed = false
    if overlay then
        overlay:SetScript("OnUpdate", nil)
        overlay:Hide()
    end
end

local function onUpdate()
    -- Combat ends a pick: the overlay toggles keyboard propagation, which is protected under
    -- lockdown, and attaching a container is a settings change that would wait for combat anyway.
    if InCombatLockdown() then
        stop()
        if onCancel then onCancel() end
        return
    end
    local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
    if not armed then
        if not down then armed = true end
        return
    end

    local target, name = FP.NamedAncestor(NS.Compat.GetMouseFocus())
    if target then
        outline:ClearAllPoints()
        if pcall(outline.SetAllPoints, outline, target) then outline:Show() else outline:Hide() end
        label:SetText(name .. "\n|cffaaaaaa" .. NS.L["Left-click to attach, right-click to cancel"] .. "|r")
    else
        outline:Hide()
        label:SetText("|cffaaaaaa" .. NS.L["Point at a named frame. Right-click to cancel."] .. "|r")
    end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    label:ClearAllPoints()
    label:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 16, y / scale + 16)

    if IsMouseButtonDown("RightButton") then
        stop()
        if onCancel then onCancel() end
    elseif IsMouseButtonDown("LeftButton") and name then
        stop()
        if onPick then onPick(name) end
    end
end

local function build()
    overlay = CreateFrame("Frame", "AuraMasterFramePicker", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:EnableMouse(false)
    overlay:EnableKeyboard(true)
    if overlay.SetPropagateKeyboardInput then overlay:SetPropagateKeyboardInput(true) end
    overlay:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
            stop()
            if onCancel then onCancel() end
            C_Timer.After(0, function()
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            end)
        end
    end)
    overlay:Hide()

    -- The outline anchors to arbitrary frames — including another addon's aura container, which only
    -- accepts anchors from a frame carrying DisableUntrustedLayoutScriptsTemplate. Covering one (or a
    -- laid-out aura button) makes the outline's own size read secret, so it is a plain frame with its
    -- 2px edge drawn as strips (Style.DrawEdge), never a BackdropTemplate, whose OnSizeChanged does
    -- arithmetic on the size (docs/midnight-quirks.md, "A backdrop on an engine button reads a secret
    -- size").
    outline = CreateFrame("Frame", nil, overlay, "DisableUntrustedLayoutScriptsTemplate")
    NS.Style.DrawEdge(outline, 2, 0.2, 0.8, 1, 1)
    outline:Hide()

    label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetJustifyH("LEFT")
end

--- Start picking. `pick(name)` is called with the chosen frame's global name; `cancel()` if the
--- player cancels.
function FP.Start(pick, cancel)
    if not overlay then build() end
    onPick, onCancel = pick, cancel
    armed = false
    overlay:Show()
    overlay:SetScript("OnUpdate", onUpdate)
end

--- The one pick flow, for `/am pick` and Layout's "Pick a frame..." alike: resolve the active
--- container, refuse under combat lockdown with one gray line, and start the picker with a completion
--- that attaches that container (the one selected when the pick began, even if the selection moves)
--- to the picked frame. The callers keep only their own messages and the panel re-open:
--- `onDone(c, name)` after the two writes, `onCanceled()` on a cancel.
--- @return boolean started, table|nil c the container being attached
function FP.PickFor(onDone, onCanceled)
    local L = NS.L
    local c, id = NS.ActiveContainer()
    if not c then
        NS.Print(L["No containers yet — /am new creates one"])
        return false
    end
    if InCombatLockdown() then
        NS.Printf("|cff808080%s|r", L["cannot pick a frame during combat — attaching to a frame waits until combat ends"])
        return false
    end
    FP.Start(function(name)
        NS.SetByPath("container.attach.frame", name, id)
        NS.SetByPath("container.attach.mode", "frame", id)
        if onDone then onDone(c, name) end
    end, onCanceled)
    return true, c
end

--- Stop a pick in progress with no callback -- what the stand-down calls (slash-commands-§7). The
--- overlay's OnUpdate goes with it, because a stood-down addon runs none; a canceled pick prints
--- nothing, since the player did not cancel it.
function FP.Stop()
    stop()
end

--- Whether a pick is in progress.
function FP.IsActive()
    return overlay ~= nil and overlay:IsShown() and true or false
end
