-- tests/mock_menu.lua — a headless stand-in for the client's context-menu API (11.0+), for the
-- launcher's right click (LibKa0s-Launcher-1.0 minor 4, launcher-§2).
--
-- MODELED ON THE LIBRARY'S OWN, not vendored from it. LibKa0s keeps its `tests/mock_menu.lua`
-- repo-local rather than in the kit (docs/api/Launcher/version-4-docs.md, "Testing a host"), so a
-- consumer that pins its menu entries installs its own. This one keeps the two fidelity points that
-- file names, because both matter here:
--   * a grayed entry is never clicked. `Click` refuses a disabled checkbox the way the client does,
--     so a case that wants to reach the library's own gate calls `ForceClick` and says so;
--   * `CreateContextMenu` runs the generator when the menu opens, once per open, so a state cached
--     across opens reads stale here exactly as it would in the client.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Installed through
-- `fresh{ before = … }` into the mock table the loader resolves globals through, so the library sees
-- `MenuUtil` and `MenuResponse` at call time, as it would in the client.
return function(mocks)
    local M = { menus = {}, opens = 0 }
    local RESPONSE = { Close = 1, Refresh = 2, Open = 3 }

    --- One opened menu: the owner it anchors to, its title and its entries in creation order.
    local function newRoot(owner)
        local menu = { owner = owner, titles = {}, entries = {} }
        local root = {}
        function root.CreateTitle(_, text)
            menu.titles[#menu.titles + 1] = text
            return {}
        end
        function root.CreateCheckbox(_, text, isSelected, setSelected, data)
            local entry = { text = text, isSelected = isSelected, setSelected = setSelected,
                data = data, enabled = true }
            local element = {}
            function element.SetEnabled(_, on) entry.enabled = on and true or false end
            function element.IsEnabled() return entry.enabled end
            menu.entries[#menu.entries + 1] = entry
            return element
        end

        --- The entries' texts, in order.
        function menu.Texts(self)
            local out = {}
            for i, e in ipairs(self.entries) do out[i] = e.text end
            return out
        end
        --- The entry whose text starts with `prefix`, or nil.
        function menu.Find(self, prefix)
            for _, e in ipairs(self.entries) do
                if e.text:sub(1, #prefix) == prefix then return e end
            end
        end
        --- Whether an entry draws checked, as the client asks it.
        function menu.Checked(self, prefix)
            local e = self:Find(prefix)
            return e and e.isSelected(e.data) and true or false
        end
        --- Click an entry as a player can: a grayed one does nothing and answers nil.
        function menu.Click(self, prefix)
            local e = assert(self:Find(prefix), "no menu entry " .. prefix)
            if not e.enabled then return nil end
            return e.setSelected(e.data)
        end
        --- Run an entry's handler regardless of its gray, to reach the library's own gate.
        function menu.ForceClick(self, prefix)
            local e = assert(self:Find(prefix), "no menu entry " .. prefix)
            return e.setSelected(e.data)
        end
        return root, menu
    end

    M.MenuUtil = {
        CreateContextMenu = function(owner, generator)
            if owner == nil then error("CreateContextMenu: an owner region is required", 2) end
            local root, menu = newRoot(owner)
            M.opens = M.opens + 1
            generator(owner, root)
            M.menus[#M.menus + 1] = menu
            M.last = menu
            return menu
        end,
    }

    --- Put the fake API in the environment, or take it away (a client before 11.0).
    function M.install()
        mocks.MenuUtil = M.MenuUtil
        mocks.MenuResponse = RESPONSE
    end
    function M.remove()
        mocks.MenuUtil = nil
        mocks.MenuResponse = nil
    end

    M.RESPONSE = RESPONSE
    M.install()
    return M
end
