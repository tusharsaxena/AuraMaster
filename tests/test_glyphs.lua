-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; AM-04 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-19).

local T = _G.AM_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
  T.assertDisplayGlyphs{ label = "AuraMaster" }
end)
