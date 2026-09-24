-- tests/fresh_env.lua — builds a FRESH, fully loaded addon environment for a suite that mutates
-- state: its own mock, its own NS, the whole vendored library and every TOC file, and the in-game
-- lifecycle (OnInitialize, OnEnable, the first coalesced apply).
--
-- The shared environment tests/run.lua builds is read by every suite; a case that creates or deletes
-- containers, flips combat or makes auras secret builds one of these instead, so the order the
-- suites run in cannot change what any of them sees. The kit's loader caches compiled chunks, so a
-- fresh environment costs a re-RUN of each file, not a re-read — but only through the runner's ONE
-- Loader (AM_TEST.Loader). A `dofile("tests/_kit/loader.lua")` here is a new module with an EMPTY
-- cache, and taking one per build re-read and re-parsed the whole tree for every environment:
-- 66,515 loadfile calls and about three minutes of a serial run at 29% CPU (testing-§14). The same
-- goes for the mock builder (a dofile of tests/wow_mock.lua re-parses four mock files) and the two
-- load lists, which the runner has already derived from the XML and the TOC.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Each build writes
-- the AuraMasterDB global, so it starts by clearing it: an environment must not inherit the last
-- one's SavedVariables.
--
-- `opts.before(mocks)` runs after the mock is built and before anything loads, for a case that needs
-- a client without the aura engine, a locked-down one, or a pre-seeded SavedVariables file.
return function(opts)
    opts = opts or {}
    local T          = assert(AM_TEST and AM_TEST.Loader and AM_TEST, "fresh_env: run through tests/run.lua")
    local Loader, buildMocks = T.Loader, T.buildMocks
    local mocks, NS = buildMocks(), {}
    rawset(_G, "AuraMasterDB", opts.savedVariables)
    if opts.before then opts.before(mocks) end
    Loader.loadAll(T.loadedLibFiles, NS, mocks)
    Loader.loadAll(T.loadedAddonFiles, NS, mocks)
    NS.addon:OnInitialize()
    NS.addon:OnEnable()
    mocks.__fireTimers()
    return NS, mocks
end
