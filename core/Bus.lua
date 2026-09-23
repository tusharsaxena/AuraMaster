local addonName, NS = ...

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

-- LibKa0s-Bus-1.0 validates the catalog below and hands back a strict copy (architecture-§4): a
-- mistyped NS.MSG key then raises at the call site for a publisher too, where AceEvent's SendMessage
-- would have fired nil silently. Only Catalog is taken. The major's stand-down record is not: the
-- factory below stays untracked, because every receiver here stands down by hand in its own module
-- and the settings receiver is setup that survives (docs/revendor/2026-09-23/03_DECISIONS.md, D2).
--
-- Degraded (the payload is missing): the Catalog half of the major's untracked-target stub
-- (LibKa0s docs/api/Bus/version-1-docs.md, "Worked example"). It hands back this file's own table,
-- so the declaration is the same literal on both arms; what the degraded install loses is the
-- strict read alone. `New` is left out because nothing here calls it.
local Bus = LibStub("LibKa0s-Bus-1.0", true) or {
    Catalog = function(_, messages) return messages end,
}
-- The resolved major or its stub, published for the surface-parity gate (tests/test_surface_parity.lua).
NS.BusLib = Bus

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
NS.MSG = Bus.Catalog(addonName, {
    -- Sender: modules/ContainerManager.lua. Payload: none. A container was created, deleted,
    -- renamed or duplicated, or the profile under the registry changed. Copying settings between
    -- containers and resetting positions are settings writes, announced by CONFIG_CHANGED.
    CONTAINERS_CHANGED = "Ka0s_AuraMaster_ContainersChanged",
    -- Sender: settings/Schema.lua (the single write seam). Payload: ({ section, containerId, path }).
    -- A setting changed; `containerId` is nil for an addon-wide row, and `path` is the row (or
    -- spell-set) path written, whose `effect` the receiver reads. Session rows send nothing.
    CONFIG_CHANGED     = "Ka0s_AuraMaster_ConfigChanged",
    -- Sender: core/AuraMaster.lua. Payload: none. Combat started or ended, or the world was entered —
    -- anything that can flip the General visibility gate.
    VISIBILITY_CHANGED = "Ka0s_AuraMaster_VisibilityChanged",
    -- Sender: modules/TimedSpells.lua. Payload: none from a scan, ({ byPlayer = true }) from
    -- `/am forgettimed`. A readable-state scan learned timed spells, or the player emptied the set,
    -- so every "without a duration" filter's excluded ids moved. Only the player's change is
    -- announced if the apply it queues has to wait.
    TIMED_SPELLS_CHANGED = "Ka0s_AuraMaster_TimedSpellsChanged",
})
