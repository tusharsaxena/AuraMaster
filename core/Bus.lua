local _, NS = ...

-- core/Bus.lua — the closed cross-module message bus (architecture-§4).
--
-- Modules never reach into each other's tables to trigger work: they PUBLISH named messages on
-- NS.bus, and every receiver SUBSCRIBES on its OWN target from NS.NewBusTarget(). CallbackHandler
-- keys a callback by (message, target), so two receivers sharing one target would silently clobber
-- each other — last registrant wins (anti-pattern #32). A per-receiver target makes that impossible.
--
-- The catalog below is the contract: one sender per message. docs/ARCHITECTURE.md → Message Bus
-- lists each one's payload and consumers.

local AceEvent = LibStub("AceEvent-3.0")

-- The shared publish target. SendMessage on any AceEvent embed fans out to every receiver.
NS.bus = NS.bus or {}
AceEvent:Embed(NS.bus)

--- A fresh AceEvent-embedded table per receiver, so no two receivers ever share one target.
--- @return table
function NS.NewBusTarget()
    local t = {}
    AceEvent:Embed(t)
    return t
end

-- Message-name catalog, prefixed Ka0s_<Addon>_ so no other addon can collide with it.
-- There is no aura-data message, and that is the design: Blizzard's aura engine owns UNIT_AURA for
-- every container and nothing in this addon reads an aura to pass on (docs/data-flow.md).
NS.MSG = {
    -- Sender: modules/ContainerManager.lua. Payload: none. A container was created, deleted,
    -- renamed or duplicated, one container's settings were replaced wholesale (copy-from, reset
    -- positions), or the profile under the registry changed.
    CONTAINERS_CHANGED = "Ka0s_AuraMaster_ContainersChanged",
    -- Sender: settings/Schema.lua (the single write seam). Payload: ({ section, containerId, path }).
    -- A setting changed; `containerId` is nil for an addon-wide row, and `path` is the row (or
    -- spell-set) path written, whose `effect` the receiver reads. Session rows send nothing.
    CONFIG_CHANGED     = "Ka0s_AuraMaster_ConfigChanged",
    -- Sender: core/AuraMaster.lua. Payload: none. Combat started or ended, or the world was entered —
    -- anything that can flip the General visibility gate.
    VISIBILITY_CHANGED = "Ka0s_AuraMaster_VisibilityChanged",
}
