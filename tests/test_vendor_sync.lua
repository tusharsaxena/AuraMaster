-- tests/test_vendor_sync.lua — the consumer-side vendored-payload gate (testing-§11).
--
-- The implementation lives in the payload it checks, at tests/_kit/vendor_sync.lua, so a local patch
-- to the kit breaks the kit's own byte-identity assertion — the right outcome, because a kit fix goes
-- upstream and is re-vendored, never edited here.
--
-- WHAT IT CHECKS: that libs/LibKa0s/ and tests/_kit/ are exactly what the LibKa0s repo published at
-- the tag THIS repo's CLAUDE.md names in its `Bundles [LibKa0s](…) vX.Y.Z (MIT).` provenance line. The
-- line is an INPUT, not a constant: bump it and the bytes in the same commit.
--
-- ONE NORMALIZATION, AND ONLY ONE: `git show` hands back the LF blob while the working tree is CRLF
-- (`.gitattributes` pins `* text=auto eol=crlf`), so CR is stripped from the working-tree side. A real
-- fork in content still fails. A missing sibling checkout reports a SKIP carrying its reason, never a
-- pass.

local VendorSync = dofile("tests/_kit/vendor_sync.lua")

VendorSync.register(_G.AM_TEST, {})

local T = _G.AM_TEST

-- The vendored runner's recorded mode (automated-tests-§2). Byte identity above cannot see it: the
-- mode lives in the git index, not in the file's bytes, and a checkout on a filesystem without an
-- executable bit keeps whatever the index says. This case is local until the LibKa0s kit gate asserts
-- the mode itself (audit docs/audits/2026-09-11, AM-18); drop it once a re-vendored kit does.
T.test("vendor: the automated-test runner is recorded executable (100755)", function()
    -- red under: git update-index --chmod=-x tests/_kit/run-automated-tests.sh
    if not io.popen then T.skip("io.popen is unavailable, so the git index cannot be read") end
    local probe = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
    if not probe then T.skip("io.popen returned no handle for git") end
    local inside = (probe:read("*a") or ""):match("^%s*(%S*)")
    probe:close()
    if inside ~= "true" then T.skip("not a git checkout (or git is missing), so there is no index to read") end

    local pipe = io.popen("git ls-files -s tests/_kit/run-automated-tests.sh")
    local line = pipe and pipe:read("*l") or nil
    if pipe then pipe:close() end
    T.assertTrue(line ~= nil and line ~= "", "tests/_kit/run-automated-tests.sh is not tracked")
    T.assertEqual(line:match("^(%d+)"), "100755", "the runner's recorded mode: " .. tostring(line))
end)
