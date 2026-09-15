local _, NS = ...

-- Session-only runtime state. NOTHING here is persisted to SavedVariables.
--
--   debug              the debug-console logging flag — off at login, reset on every /reload
--                      (debug-logging-§5); read and written only through core/DebugLogSetup.lua.
--   activeContainerId  which container every `container.`-prefixed settings path resolves against
--                      (settings/Schema.lua). The settings banner moves it; nil means "the
--                      first container in display order", which is what the CLI gets on a fresh
--                      login where nothing has ever selected one.
--
-- There is no preview flag: the placeholders show while the addon is unlocked, and only then
-- (ContainerClass:ShouldShow reads the lock).
NS.State = NS.State or {}
local State = NS.State

State.debug = false
State.activeContainerId = nil

--- Point every container-relative settings path at `id` (or nil for "the first container").
--- The ONE writer of the pointer: the settings banner, Containers' create/duplicate/delete
--- and the CLI all come through here, so a later side effect has one home.
--- @param id number|nil
function State.SetActiveContainer(id)
    State.activeContainerId = id
end
