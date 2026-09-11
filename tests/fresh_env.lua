-- tests/fresh_env.lua — builds a FRESH, fully loaded addon environment for a suite that mutates
-- state: its own mock, its own NS, the whole vendored library and every TOC file, and the in-game
-- lifecycle (OnInitialize, OnEnable, the first coalesced apply).
--
-- The shared environment tests/run.lua builds is read by every suite; a case that creates or deletes
-- containers, flips combat or makes auras secret builds one of these instead, so the order the
-- suites run in cannot change what any of them sees. The kit's loader caches compiled chunks, so a
-- fresh environment costs a re-RUN of each file, not a re-read.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Each build writes
-- the AuraMasterDB global, so it starts by clearing it: an environment must not inherit the last
-- one's SavedVariables.
--
-- `opts.before(mocks)` runs after the mock is built and before anything loads, for a case that needs
-- a client without the aura engine, a locked-down one, or a pre-seeded SavedVariables file.
return function(opts)
    opts = opts or {}
    local Loader     = dofile("tests/_kit/loader.lua")
    local buildMocks = dofile("tests/wow_mock.lua")
    Loader.addonName = "AuraMaster"
    local mocks, NS = buildMocks(), {}
    rawset(_G, "AuraMasterDB", opts.savedVariables)
    if opts.before then opts.before(mocks) end
    Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS, mocks)
    Loader.loadAll(Loader.tocFiles("AuraMaster.toc"), NS, mocks)
    NS.addon:OnInitialize()
    NS.addon:OnEnable()
    mocks.__fireTimers()
    return NS, mocks
end
