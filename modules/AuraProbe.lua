local _, NS = ...

-- modules/AuraProbe.lua — TEMPORARY. `/am probe` dumps every aura currently on the watched units
-- to the debug log, so a human can answer the one question the data cannot (issue #15, item 3).
--
-- DELETE THIS FILE, its TOC line and its `/am probe` verb once the five ids below are settled.
-- It is a diagnostic, not a feature: nothing in the addon calls it, no setting turns it on, and it
-- is listed here so that the next person to read the module map knows it is scaffolding.
--
-- WHY IT EXISTS. `defaults/Categories.lua` ships five ids that apply no aura of their own, so each
-- is drawing a row in the editor and matching nothing:
--
--     1706    Levitate
--     5782    Fear
--     35546   Fatal Flourish
--     98007   Spirit Link Totem
--     102793  Ursol's Vortex
--
-- NONE of the five can be fixed from the data. `tools/spell-research/research.py` resolves a cast
-- to its aura through `EffectTriggerSpell`, and **not one of these five has a trigger edge at all**
-- — the links are server-side script. All the generator can offer is aura-applying spells of the
-- same NAME, and that is a candidate and never a conclusion: an early cut of it treated a lone
-- name match as an answer and produced confident rewrites of Purge and Remove Curse to unrelated
-- spells that happened to reuse the word.
--
-- So the only instrument left is the live client: apply the aura and read what actually landed.
-- That is what this does, and it is why the answer has to come from a person rather than a run.
--
-- IT DUMPS TO THE DEBUG LOG, NOT CHAT (owner's instruction). A chat frame eats long lines, wraps
-- them and loses the start; the debug console has a copy box that hands back exactly what was
-- written. `/am debug` opens it.

NS.AuraProbe = NS.AuraProbe or {}
local AP = NS.AuraProbe

-- The units worth reading, in the order a player checks them. `player` is where a self-buff lands
-- (Levitate, Fatal Flourish, Spirit Link Totem's link); `target` is where a cast-at aura lands
-- (Fear, Ursol's Vortex).
local PROBE_UNITS = { "player", "target", "focus", "pet" }

-- Both halves, because three of the five are buffs and two are debuffs and a probe that guessed
-- would send the player back to run it again.
local PROBE_FILTERS = { "HELPFUL", "HARMFUL" }

-- The same ceiling TimedSpells scans to. An aura past it is one no container would draw either.
local MAX_INDEX = 40

--- One aura's line. Everything is read through `Secrets` because an aura table is secret in combat
--- and a secret value raises on comparison rather than answering false.
local function line(unit, filter, index, aura)
    local Secrets = NS.Secrets
    local id = aura.spellId
    if not Secrets.IsSafeKey(id) then return nil end
    local name = aura.name
    if type(name) ~= "string" then name = "?" end
    local duration = Secrets.NumberOr(aura.duration, -1)
    local source = aura.sourceUnit
    if type(source) ~= "string" then source = "?" end
    return ("%-7s %-8s %2d  id=%-9s %-34s dur=%-6s src=%s")
        :format(unit, filter, index, tostring(id), name, tostring(duration), source)
end

--- Dump every readable aura on every watched unit to the debug log.
---
--- Returns how many lines were written, so the chat acknowledgment can say whether there was
--- anything to read at all — a probe that silently wrote nothing is indistinguishable from a probe
--- that did not run.
function AP.Dump()
    if NS.Compat.AurasAreSecret() then
        NS.Print("Auras are secret right now (combat, an encounter, Mythic+ or PvP). Leave combat and run /am probe again.")
        return 0
    end
    local api = _G.C_UnitAuras
    if not (api and api.GetAuraDataByIndex) then
        NS.Print("This client has no C_UnitAuras.GetAuraDataByIndex; nothing to probe.")
        return 0
    end
    local written = 0
    NS.Debug("Probe", "---- /am probe ----")
    for _, unit in ipairs(PROBE_UNITS) do
        if _G.UnitExists and _G.UnitExists(unit) then
            for _, filter in ipairs(PROBE_FILTERS) do
                for i = 1, MAX_INDEX do
                    local ok, aura = pcall(api.GetAuraDataByIndex, unit, i, filter)
                    if not ok or type(aura) ~= "table" then break end
                    local text = line(unit, filter, i, aura)
                    if text then
                        NS.Debug("Probe", "%s", text)
                        written = written + 1
                    end
                end
            end
        else
            NS.Debug("Probe", "%-7s (no such unit)", unit)
        end
    end
    NS.Debug("Probe", "---- %d aura(s) ----", written)
    NS.Print(("Probe wrote %d aura line(s) to the debug log. Open it with /am debug and copy the block."):format(written))
    return written
end
