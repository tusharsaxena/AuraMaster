-- tests/page_helpers.lua — drives a settings page the way a player does, on a fresh environment.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. The kit's AceGUI
-- fake records every widget it hands out and exposes `__fire`, and its panels expose `__fire` for
-- the deferred OnShow render, so a page can be drawn and clicked headlessly. What this adds is the
-- bookkeeping each page suite would otherwise repeat: which widgets THIS render drew, finding one
-- by the label the schema row carries, capturing chat, and moving between tabs.
--
-- A kit panel starts hidden, so a structural refresh marks it dirty and the next OnShow re-renders
-- it; `rerender` is exactly that pair.
return function(NS, m)
    local P = {}
    local ace = m.LibStub("AceGUI-3.0")

    --- Every widget created since `mark`, not yet released.
    local function since(mark)
        local out = {}
        local last = #ace.__created
        for i = mark + 1, last do
            local w = ace.__created[i]
            if not w.__released then
                out[#out + 1] = w
            end
        end
        return out
    end

    --- Fire a page's OnShow and answer the widgets that render drew.
    function P.show(page)
        local mark = #ace.__created
        m.__subcategories[page]:__fire("OnShow")
        return since(mark)
    end

    --- A structural refresh, then the next show: the page draws again from the current state.
    function P.rerender(page)
        NS.Helpers.RefreshAllPanels()
        return P.show(page)
    end

    --- The widgets `fn` creates while it runs (a tab click, a button that re-renders).
    function P.during(fn)
        local mark = #ace.__created
        fn()
        return since(mark)
    end

    --- The first widget of `wtype` (any type when nil) whose label or text is `label`.
    function P.find(widgets, wtype, label)
        for _, w in ipairs(widgets) do
            if (wtype == nil or w.type == wtype) and (w.labelText == label or w.text == label) then
                return w
            end
        end
        return nil
    end

    --- Every widget of `wtype` whose label or text is `label` (every one of the type when nil).
    function P.all(widgets, wtype, label)
        local out = {}
        for _, w in ipairs(widgets) do
            if w.type == wtype and (label == nil or w.labelText == label or w.text == label) then
                out[#out + 1] = w
            end
        end
        return out
    end

    --- The widget drawn for the schema row at `path`, found by the label that row declares.
    function P.row(widgets, path)
        local row = NS.FindSchemaRow(path)
        assert(row, "no schema row " .. tostring(path))
        return P.find(widgets, nil, row.label)
    end

    --- Label widgets' texts, for asserting what a page printed in its body.
    function P.texts(widgets)
        local out = {}
        for _, w in ipairs(widgets) do
            if w.type == "Label" and w.text then
                out[#out + 1] = w.text
            end
        end
        return out
    end

    function P.hasText(widgets, needle)
        for _, t in ipairs(P.texts(widgets)) do
            if t:find(needle, 1, true) then return true end
        end
        return false
    end

    --- Click the tab `key` on a container page and answer what that render drew.
    function P.tab(pageKey, key)
        local ctx = NS.Helpers.__containerCtx[pageKey]
        for i, t in ipairs(ctx.__tabs) do
            if t.key == key then
                return P.during(function() ctx.__tabKids[i]:__fire("OnClick") end)
            end
        end
        error("page " .. pageKey .. " drew no tab " .. tostring(key), 2)
    end

    --- The tab keys a container page's last render drew, in order.
    function P.tabKeys(pageKey)
        local out = {}
        for i, t in ipairs(NS.Helpers.__containerCtx[pageKey].__tabs or {}) do out[i] = t.key end
        return out
    end

    --- Capture chat from here on; answers the live list.
    function P.chat()
        local lines = {}
        rawset(m.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
            lines[#lines + 1] = tostring(msg)
        end)
        return lines
    end

    --- Count CONFIG_CHANGED and CONTAINERS_CHANGED from here on.
    function P.messages()
        local n = { config = 0, containers = 0, paths = {} }
        local t = NS.NewBusTarget()
        t:RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, p)
            n.config = n.config + 1
            local path = type(p) == "table" and p.path or nil
            n.paths[#n.paths + 1] = path
        end)
        t:RegisterMessage(NS.MSG.CONTAINERS_CHANGED, function() n.containers = n.containers + 1 end)
        return n
    end

    --- Record StaticPopup_Show calls; answers the list. Each shown popup is a table, as the
    --- client's is, so a caller that stamps `.data` on it can be read back.
    function P.popups()
        local shown = {}
        m.StaticPopup_Show = function(which, text)
            local popup = { which = which, text = text }
            shown[#shown + 1] = popup
            return popup
        end
        return shown
    end

    return P
end
