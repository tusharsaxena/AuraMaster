-- tests/degraded_env.lua — builds a SECOND addon environment with LibKa0s absent.
--
-- LibKa0s is vendored, so it can go missing: a partial unzip, a user pruning libs/, a packager that
-- dropped the folder. Every setup file carries a degradation stub for that case, and the only honest
-- way to exercise those stubs is a real load without the library — a hand-stub written after the fact
-- cannot reproduce a file that failed to finish loading (testing-§8).
--
-- The list is the TOC's WHOLE list, in the TOC's order: the hazard this environment exists to catch is
-- a page file calling a helper at FILE LOAD, which only a load that reaches the page files can see.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Nothing here calls
-- InitDB or CreateOptionsPanel, so the shared suite's SavedVariables globals are untouched.
return function()
  local Loader     = dofile("tests/_kit/loader.lua")
  local buildMocks = dofile("tests/wow_mock.lua")
  Loader.addonName = "AuraMaster"
  local mocks2, NS2 = buildMocks(), {}
  -- libs/LibKa0s/*.lua deliberately not loaded: LibStub answers nil for every Ka0s major exactly as a
  -- client missing the folder would, so every seam takes its degradation branch at once.
  Loader.loadAll(Loader.tocFiles("AuraMaster.toc"), NS2, mocks2)
  return NS2, mocks2
end
