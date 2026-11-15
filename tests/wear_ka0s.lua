-- tests/wear_ka0s.lua — puts a built environment on Ka0s Default by name, the stored pair and the
-- applied choice, for the suites that pin Ka0s Default's own values (its colors, faces and sizes).
--
-- Under the forever kit profile the client's default skin is WoW Forever (LibKa0s Skin minor 18,
-- skinning-§2), so a fresh build wears that, and every case written against Ka0s Default's pixels
-- would read the Forever look instead. tests/run.lua's shared environment and tests/fresh_env.lua
-- call this once the lifecycle has run, so the suite pins one look on both profiles; a case about the
-- client's own default builds with `fresh{ clientSkin = true }` and skips it (tests/test_clients.lua,
-- tests/test_skinsetup.lua). A no-op where the client's default already is Ka0s Default: the retail
-- profile, and a build without the library.
--
-- Only a profile still on the client's default moves: a case that pre-seeds a stored skin keeps it.
--
-- Not a suite (tests/run.lua does not list it). Answers NS.
return function(NS, mocks)
    if NS.DEFAULT_SKIN == nil or NS.DEFAULT_SKIN == "ka0s" then return NS end
    local p = NS.db and NS.db.profile
    if not (p and p.skin and p.skin.source == "ka0s" and p.skin.skin == NS.DEFAULT_SKIN) then return NS end
    p.skin.skin = "ka0s"
    local Skin = mocks.LibStub and mocks.LibStub("LibKa0s-Skin-1.0", true)
    if Skin and Skin:IsOwner("AuraMaster") then Skin:SetChoice("AuraMaster", "ka0s", "ka0s") end
    if mocks.__fireTimers then mocks.__fireTimers() end
    return NS
end
