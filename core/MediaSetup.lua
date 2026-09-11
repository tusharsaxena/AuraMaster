-- core/MediaSetup.lua — the LibKa0s-Media-1.0 seam: the collection's shared icon catalog, the
-- monospace face and the bar textures (library-stack-§8).
--
-- The art ships inside the vendored payload at libs/LibKa0s/media/, so this addon carries no copy of
-- any of it (layout-§3, anti-pattern #63). What this file does is the three lines of real work: tell
-- the library our folder name, and register its faces and textures with LibSharedMedia.
--
-- LOAD-BEARING POSITION: core/Constants.lua resolves FONT_MONO from NS.MediaFont at FILE LOAD, so this
-- file must precede it. A Constants that loaded first would resolve the debug console's face to the
-- fallback on a perfectly healthy install, and nothing would say so. tests/test_loadorder.lua pins it.
--
-- NIL IS A REAL ANSWER from both functions: the library may be absent, or the name may not be one it
-- ships. Nothing here builds a path by concatenation to paper over that — a plausible path to a file
-- that is not there draws nothing and raises nothing, which is strictly worse than nil.

local addonName, NS = ...

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon (extensionless, by the library's contract), or nil. The
--- addon's own draws use one mark: "help", the unlock handle's help icon (modules/Anchors.lua), which
--- falls back to a Blizzard texture when this answers nil.
--- @param name string  an entry of the library's ICONS catalog, e.g. "help"
--- @return string|nil
function NS.Icon(name)
    if not Media then return nil end
    return Media.Icon(addonName, name)
end

--- The path of one shipped font face, or nil.
--- @param name string  a key of the library's FONTS, e.g. "JetBrains Mono"
--- @return string|nil
function NS.MediaFont(name)
    if not Media then return nil end
    return Media.Font(addonName, name)
end

-- At FILE LOAD, not PLAYER_LOGIN: LibSharedMedia is vendored under libs/ and has already run, and a
-- shipped default naming a face or texture LSM has not heard of yet would resolve to nothing. It also
-- puts the shared statusbar textures into every bar-texture dropdown this addon draws.
if Media then Media.RegisterLSM(addonName) end
