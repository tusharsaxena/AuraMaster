-- tests/prose_waivers.lua — what the kit's US-English gate MUST NOT correct here.
--
-- Read by `tests/_kit/test_prose.lua` (localization-5). Per FILE and per WORD, never per
-- file alone: a whole-file waiver hides every OTHER British spelling in a file this repo
-- edits often, which is how a gate acquires a blind spot the size of a module.
--
-- Every entry carries its reason. A waiver with no stated reason is indistinguishable from
-- a spelling nobody got round to fixing, and the next sweep either re-fixes it or widens it.

return {
    -- A FROZEN DATED STORE, like docs/audits/ and docs/automated-tests/ above it. Each
    -- docs/spell-research/<date>/ bundle is the record of what the offline DB2 pipeline said on
    -- the day it ran, not authored prose, and it is not rewritten -- the same bargain every other
    -- dated bundle in this collection strikes.
    skipDirs = { "docs/spell-research/" },

    -- GAME DATA in a generated file that ships. The paladin spells are named "Judge" .. "ment" by
    -- Blizzard on WoW Forever ("Judge" .. "ment" of Light, of Wisdom, ...), and forever.py emit copies
    -- each spell's name into the comment beside its id; renaming it would make the comment
    -- disagree with the build it was derived from. Spelled in two halves here so this file
    -- does not carry the word itself.
    waived = {
        ["defaults/CastToAura_Forever.lua"] = { ["judge" .. "ment"] = true },
    },
}
