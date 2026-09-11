local _, NS = ...

-- settings/About.lua — the landing page's body (options-ui-§5): logo, the TOC's one-line Notes, a
-- "Slash Commands" heading and one row per NS.COMMANDS entry, rendered through the same formatter
-- `/am help` prints with, so the page and the help block cannot drift.
--
-- The body is DATA: LibKa0s-Options-1.0 owns the landing renderer (BuildLandingPage), which clears
-- the scroll on every re-render. `notes` and `rows` are functions because both resolve at RENDER
-- time — the TOC's Notes is not readable at declaration, and a later file may add a command.

local L = NS.L
local Helpers = NS.Helpers

local SPEC = {
    logo  = NS.Constants.LOGO_PATH,
    notes = function() return NS.Meta("Notes") or "" end,
    sections = {
        { heading = L["Slash Commands"], rows = function() return NS.Slash:LandingRows() end },
    },
}

function Helpers.BuildMainContent(ctx)
    if Helpers.BuildLandingPage then Helpers.BuildLandingPage(ctx, SPEC) end
end
