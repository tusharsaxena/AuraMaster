-- core/EnvSetup.lua — the LibKa0s-Env-1.0 seam: where this addon reads its own TOC manifest
-- (library-stack-§7).
--
-- The library is told this addon's FOLDER name because it is vendored and cannot know which folder
-- it was copied into. `addonName` is the first vararg the client hands every TOC-loaded file — never
-- the `## Title`, never the chat prefix, never a hand-typed literal. A wrong name reads some other
-- addon's manifest, or none, and answers nil without raising.
--
-- A degraded install (libs/LibKa0s missing) falls back to the same C_AddOns → deprecated global →
-- nil ladder the library runs, so `/am version` and the landing page's Notes line still work.
--
-- Nothing here is resolved at load beyond the LibStub lookup, so the TOC position is conventional.

local addonName, NS = ...

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC manifest, or nil. Nil is a real answer: the library may be absent,
--- the client may expose no reader (a headless run), or the TOC may not carry the field.
--- @param field string  a TOC key: "Version", "Title", "Notes", …
--- @return string|nil
function NS.Meta(field)
    if Env then return Env.GetAddOnMetadata(addonName, field) end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, field)
    end
    return nil
end

--- This addon's version, preferring the TOC over core/Namespace.lua's fallback. Never nil.
--- `NS.version` is read at CALL time, so this file does not depend on where core/Namespace.lua sits.
--- @return string
function NS.Version()
    if Env then return Env.Version(addonName, NS.version) or "?" end
    return NS.Meta("Version") or NS.version or "?"
end
