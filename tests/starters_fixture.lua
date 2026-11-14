-- tests/starters_fixture.lua -- the harness's container fixture: the four containers a fresh profile
-- was seeded with before schema v19 (a player-buff bar stack, a player-debuff icon row, a
-- target-debuff icon row and a text list of the player's offensive and defensive cooldowns).
--
-- WHY A FIXTURE. Since AM-PR04 a new profile starts from the Simple preset (three bar containers,
-- core/Database.lua), and NS.STARTER_CONTAINERS is retired. Hundreds of cases read the old set as
-- their furniture: container 2 is an icon row, 3 tracks the target, 4 is a text container. They test
-- the container they are handed, not the seeding, so the harness hands them the same four, written
-- into the FIRST profile an environment prepares, just before core/Database.lua's PrepareProfile runs
-- on it. The real seeding is untouched and is what every later preparation runs (a reset, a new
-- profile, a direct PrepareProfile call); tests/test_presets_seed.lua builds its environments with
-- `simple = true` and so sees the real first-run seed too.
--
-- Not a suite (tests/run.lua does not list it). `install(NS)` is called after every addon file has
-- loaded and before OnInitialize; `list(NS)` is the four overrides, for a case that compares against
-- one of them.

local M = {}

--- The four overrides, freshly built (the cooldown list reads the live category lists).
function M.list(NS)
    return {
        {
            name = "Player buffs", unit = "player", auraType = "HELPFUL", style = "bars",
            filter = { castBy = "any" },
            position = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -240, y = -220 },
        },
        {
            name = "Player debuffs", unit = "player", auraType = "HARMFUL", style = "icons",
            position = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -240, y = -160 },
            layout = { axis = "horizontal", growH = "left", growV = "down" },
        },
        {
            name = "Target debuffs (mine)", unit = "target", auraType = "HARMFUL", style = "icons",
            filter = { castBy = "mine" },
            position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -160 },
            layout = { axis = "horizontal", growH = "right", growV = "down" },
        },
        {
            -- Only the Offensive cooldowns and Defensive cooldowns lists draw: every other buff
            -- category is Hidden, Uncategorized included (defaults/Categories.lua's StatesShowing).
            name = "Player cooldowns", unit = "player", auraType = "HELPFUL", style = "text",
            filter = { castBy = "any", categories = NS.Categories.StatesShowing({ "offensiveCDs", "defensives" }) },
            position = { point = "CENTER", relativePoint = "CENTER", x = -260, y = -40 },
            layout = { axis = "vertical", growH = "right", growV = "down" },
        },
    }
end

--- Write the four into an unseeded, empty profile, numbered from its own counter. The profile is left
--- unseeded: PrepareProfile then marks it seeded, backfills and follows the skin as it always has.
local function fill(NS, p)
    p.containers = p.containers or {}
    p.containerOrder = p.containerOrder or {}
    if p.seeded or next(p.containers) ~= nil then return end
    local Database = NS.Database
    for _, spec in ipairs(M.list(NS)) do
        local id = p.nextContainerId or 1
        p.nextContainerId = id + 1
        local c = Database.Merge(Database.DeepCopy(NS.CONTAINER_TEMPLATE), spec)
        c.id = id
        p.containers[id] = c
        p.containerOrder[#p.containerOrder + 1] = id
    end
end

--- Wrap PrepareProfile for its FIRST call only (the login's, from NS.RunMigrations): the fixture goes
--- into that profile, then the wrapper takes itself out.
function M.install(NS)
    local Database = NS.Database
    local real = Database.PrepareProfile
    Database.PrepareProfile = function(p)
        Database.PrepareProfile = real
        if type(p) == "table" then fill(NS, p) end
        return real(p)
    end
end

return M
