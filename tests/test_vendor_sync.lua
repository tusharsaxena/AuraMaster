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
