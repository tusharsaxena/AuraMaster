-- tests/skin_gate.lua — this addon's facts for the kit's two skin suites (kit revision 50,
-- skinning-§1): the rows of the typed-value gate, and the painted surfaces of the switch test, which
-- flips Ka0s Default against a probe skin and reads what each surface's drawing setters were given.
--
-- Not a suite (tests/run.lua calls it) and not part of the vendored kit. A surface drawn off a button
-- has no listener in a mock, so its `paint` dresses again, the pass modules/ContainerManager.lua's
-- one OnLooksChanged listener runs in the client. A surface marked `scope = "panel"` is what Ignore
-- settings panel keeps stock. A HUD surface's `companion` writes its "Use the skin's ..." row.

-- A channel a stored color lacks: the load backfill fills it, so no player sees this value.
local PARTIAL = "a channel a stored color lacks, which the load backfill fills: no look of its own"

local ROWS = {
    { file = "core/Compat.lua", substring = "expiring.r or 1", cause = "D5",
      why = "the running-out tint: a warning tint carries its meaning, the owner's ruling on D5" },
    { file = "core/Compat.lua", substring = "normal.r or 1", cause = "FS-AM-01", why = PARTIAL },
    { file = "modules/Style.lua", substring = "fallback.r or 1", cause = "FS-AM-01", why = PARTIAL },
    { file = "core/Compat.lua", substring = "region:SetVertexColor(c.r or 1", cause = "MC",
      why = "a dispel type's color off the client's palette: the color is the information" },
    { file = "modules/Style.lua", substring = "map[name] = _G.CreateColor", cause = "MC",
      why = "a dispel type's color in the profile's palette: the color is the information" },
    { file = "modules/Style_Bars.lua", substring = "tex:SetVertexColor(c.r or 1", cause = "MC",
      why = "a placeholder's dispel tint, off the same map the engine is handed" },
    { file = "modules/Style_Text.lua", substring = "_G.CreateColor(1, 1, 1, 0)", cause = "MC",
      why = "a dispel type the palette does not cover: fully clear, so no look at all" },
    { file = "modules/Style_Text.lua", substring = "map[t] =", cause = "MC",
      why = "a dispel type's color on a Text tint: the color is the information" },
    { file = "modules/Style_Icons.lua", substring = "cd:SetSwipeColor(0, 0, 0", cause = "A6",
      why = "the cooldown sweep stays Blizzard's: game feedback players know, the owner's Leave list" },
}

--- A surface with no skin state of its own but what `draw` reads: `draw(obj)` on one recorder.
local function drawn(R, name, draw, scope)
    local obj
    return { name = name, scope = scope,
        build = function() obj = R(); draw(obj); return obj end,
        paint = function(o) draw(o) end }
end

return function(Kit, NS, mocks)
    Kit.skinValues = { calls = { DrawEdge = { 3, 4, 5 } }, rows = ROWS }

    local R = dofile("tests/region_recorder.lua")
    local BS = dofile("tests/border_strips.lua")
    local HR = dofile("tests/handle_recorder.lua")

    --- `over`'s dotted `path` set to `v`, tables made on the way.
    local function set(over, path, v)
        local t, leaf = over, nil
        for seg in path:gmatch("[^%.]+") do
            if leaf then
                t[leaf] = t[leaf] or {}
                t = t[leaf]
            end
            leaf = seg
        end
        t[leaf] = v
    end

    --- A surface on an element dressed from the template with `over` on it: dressed once, its regions
    --- swapped for recorders and dressed again, as the style suites do, so every region's drawing is
    --- its own. `pick(am)` answers what the surface drew; `follow` is its companion's path.
    --- `note(am, obj)`, for a surface the base skin draws nothing on, writes what it drew on `obj`.
    local function element(name, over, follow, pick, note)
        local frame, config
        local function dress(o)
            NS.Style.Element(frame, config, false)
            if note then note(frame.__am, o) end
        end
        return {
            name = name,
            companion = function(on) set(over, follow, on) end,
            build = function()
                config = NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over)
                frame = R()
                NS.Style.Element(frame, config, false)
                for k, v in pairs(frame.__am) do
                    if type(v) == "table" and k ~= "chain" then frame.__am[k] = R() end
                end
                local drew = pick(frame.__am)
                dress(drew[1])
                return unpack(pick(frame.__am))
            end,
            paint = dress,
        }
    end

    local function region(key) return function(am) return { am[key] } end end
    local function strips(key) return function(am) return BS.strips(am[key]) end end
    local ICONS, TEXT = { style = "icons" }, { style = "text" }
    local function over(base, extra)
        local t = NS.Database.DeepCopy(base)
        return NS.Database.Merge(t, extra)
    end

    --- One container's drag strip, rebuilt under the recorder: its own edge strips.
    local function strip()
        local inst = NS.ContainerManager.instances[NS.Database.GetContainers()[1].id]
        inst.anchor:Show()
        return inst, HR.recordedHandle(mocks, NS, inst)
    end

    local pending   -- the strip whose tooltip a surface fires, or the frame picker to stop

    local surfaces = {
        element("a bar's fill", {}, "bars.barColorFromSkin", region("fill")),
        element("a bar's background", {}, "bars.bgColorFromSkin", region("bg")),
        element("a bar's border, Show border on", { bars = { borderShow = true } },
            "bars.borderColorFromSkin", strips("border")),
        element("a bar's border, Show border off", {}, "bars.borderStyleFromSkin", function(am)
            return { am.border }
        end, function(am, o) o:SetText(am.border:IsShown() and "drawn" or "none") end),
        element("a bar's name", {}, "bars.name.fontColorFromSkin", region("name")),
        element("a bar's time", {}, "bars.time.fontColorFromSkin", region("time")),
        element("a bar's stacks", {}, "bars.stacks.fontColorFromSkin", region("stacks")),
        element("the icon beside a bar's border", { bars = { iconBorderShow = true } },
            "bars.iconBorderColorFromSkin", strips("iconBorder")),
        element("an icon's border", over(ICONS, {}), "icons.borderColorFromSkin", strips("border")),
        element("an icon's time", over(ICONS, {}), "icons.time.fontColorFromSkin", region("time")),
        element("an icon's stacks", over(ICONS, {}), "icons.stacks.fontColorFromSkin", region("stacks")),
        element("the icon beside a text line's border", over(TEXT, { text = { icon = "LEFT", iconBorderShow = true } }),
            "text.iconBorderColorFromSkin", strips("iconBorder")),
        drawn(R, "a text line's glow", function(o)
            NS.Style.Text.GlowFont(o, NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE.text), 1)
        end),
        drawn(R, "the name label", function(o)
            local D = NS.CONTAINER_TEMPLATE
            NS.Style.ApplyFont(o, NS.Database.DeepCopy(D.label.font), D.label.font, false)
        end),
        { name = "a drag strip's edge", build = function()
            local _, handle = strip()
            return unpack(BS.strips(handle))
        end },
        { name = "a drag strip's tooltip", build = function()
            local _, handle = strip()
            pending = handle
            handle:__fire("OnEnter")
            return mocks.GameTooltip
        end, paint = function() pending:__fire("OnEnter") end },
        { name = "a drag strip's TEST tag", build = function()
            local _, handle = strip()
            local tag = R()
            rawset(handle, "SetLabel", function(self, text)
                tag:SetText(text)
                return self
            end)
            NS.Preview.SetTestMode(true)
            mocks.__fireTimers()
            return tag
        end },
        { name = "the unlocked outline", build = function()
            local inst = strip()
            local real = mocks.CreateFrame
            mocks.CreateFrame = function(...)
                local f = real(...)
                if select(3, ...) == inst.anchor then BS.recorderTextures(f) end
                return f
            end
            NS.SetByPath("locked", false)
            mocks.CreateFrame = real
            mocks.__fireTimers()
            return unpack(BS.strips(inst.outline))
        end },
        { name = "the frame picker's outline and name", build = function()
            local made, real = {}, mocks.CreateFrame
            mocks.CreateFrame = function(...)
                local f = real(...)
                made[#made + 1] = f
                BS.recorderTextures(f)
                return f
            end
            NS.FramePicker.Start(function() end, function() end)
            mocks.CreateFrame = real
            local overlay = mocks.__globals.AuraMasterFramePicker
            pending = overlay
            local objects = { overlay }
            for _, f in ipairs(made) do
                if f.__parent == overlay then
                    for _, s in ipairs(BS.strips(f)) do objects[#objects + 1] = s end
                end
            end
            return unpack(objects)
        end },
        drawn(R, "the drag-to-attach mark", function(o)
            local c = NS.Anchors.Snap.COLOR.attach
            o:SetColorTexture(c.r, c.g, c.b, c.a)
        end),
        drawn(R, "the Unit dropdown's values", function(o)
            for _, e in ipairs(NS.FindSchemaRow("container.unit").values) do
                if e.value == "focus" then o:SetText(e.text) end
            end
        end, "panel"),
        drawn(R, "a settings page's muted note", function(o) o:SetText(NS.PanelEscape("am.note")) end, "panel"),
        drawn(R, "a plan warning's line", function(o) o:SetText(NS.PanelEscape("am.planWarn")) end, "panel"),
        drawn(R, "the Filters section's link", function(o) o:SetText(NS.PanelEscape("am.link")) end, "panel"),
        drawn(R, "a settings tooltip's line", function(o) o:SetTextColor(NS.PanelTipLine()) end, "panel"),
    }

    Kit.skinSwitch = {
        owner = "AuraMaster",
        skin = function() return mocks.LibStub("LibKa0s-Skin-1.0") end,
        surfaces = surfaces,
        -- What a surface left up: test mode, the unlock and the frame picker.
        reset = function()
            if NS.State.testMode then NS.Preview.SetTestMode(false) end
            if NS.GetSetting("locked") == false then NS.SetByPath("locked", true) end
            local overlay = mocks.__globals.AuraMasterFramePicker
            if overlay and pending == overlay then overlay:__fire("OnKeyDown", "ESCAPE") end
            pending = nil
            mocks.__fireTimers()
        end,
    }
end
