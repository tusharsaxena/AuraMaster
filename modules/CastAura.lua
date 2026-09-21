local _, NS = ...

-- modules/CastAura.lua — what to do when a player types a spell that is CAST as one id and lands
-- as another (issue #15).
--
-- THE BUG THIS ANSWERS. Aura Master filters on the id the AURA carries. A player typing a spell
-- NAME into an add box gets the id the client knows, which is the id in the spellbook — the CAST
-- one. Renewing Mist is cast as 115151 and lands as 119611, so an entry reading
-- `Renewing Mist (115151)` draws with the right icon and the right name and matches nothing, in a
-- panel where nothing says why.
--
-- THE CLIENT CANNOT HELP. There is no Lua that answers "what aura does this spell apply":
-- `C_Spell` and `C_SpellBook` give a name, an icon, a cooldown, a range and a description, and
-- none of them exposes `SpellEffect` or its `EffectTriggerSpell` (docs/scope.md, "Out of reach on
-- this client"). So the answer is carried, derived offline from Blizzard's own DB2 exports by
-- `tools/spell-research/research.py --emit-cast-aura` into `defaults/CastToAura.lua`.
--
-- TWO ANSWERS, AND THEY ARE NOT EQUALLY TRUSTWORTHY. That difference is the whole design here:
--
--   * `REWRITE[id]` — the generator found a real `EffectTriggerSpell` edge from the cast to a
--     spell that applies an aura. Data, not inference. 58 ids. The add stores the AURA id and
--     says so, because storing what the player typed would store something that cannot work.
--   * `CHOICES[id]` — no trigger edge; the candidates are aura-applying spells of the same NAME,
--     narrowed by the class family. 590 ids. **Never resolved automatically.** A name is shared
--     across the whole game, and an early cut of the generator that treated a lone name match as
--     an answer produced confident rewrites of Purge, Remove Curse and Pick Pocket — spells that
--     apply no aura at all, matched to unrelated spells reusing the name.
--
-- SO THE PANEL REWRITES ONLY WHAT THE DATA KNOWS, AND OFFERS THE REST. An id this file cannot
-- speak to is stored exactly as typed, which is what every id did before this existed.
--
-- WHAT IT NEVER DOES: refuse. The add always happens, in every branch. A player who means the id
-- they typed — a boss aura the generator has never heard of, an id read off a log — must be able
-- to enter it, and the table's silence about an id is not evidence against it. Informing and
-- refusing are different things, and this file only does the first, exactly as `sayOverlap` does
-- for the two-categories guardrail beside it.

NS.CastAura = NS.CastAura or {}
local CA = NS.CastAura

--- The generated table, or an empty one.
---
--- Read through a function rather than captured at file scope: `defaults/CastToAura.lua` loads
--- before this file today, but a missing or emptied table has to read as "nothing to say about any
--- id" rather than raise, and that is a property worth having independent of load order. Every
--- entry point below goes through this.
local function table_()
    return NS.CastToAura or {}
end

--- What this addon knows about `id`, as one of:
---
---   `nil`                      — nothing. Store it as typed; this is every ordinary spell.
---   `"rewrite", auraId`        — it is a cast whose aura the data names exactly. Store `auraId`.
---   `"choose", { ids… }`       — it applies no aura and these are the candidates. Store as typed
---                                and say so; the player decides.
---
--- The order matters: a rewrite is checked first, because an id in REWRITE is never in CHOICES and
--- the caller should not have to know that.
function CA.Resolve(id)
    if type(id) ~= "number" then return nil end
    local t = table_()
    local rewrite = t.REWRITE and t.REWRITE[id]
    if rewrite then return "rewrite", rewrite end
    local choices = t.CHOICES and t.CHOICES[id]
    if type(choices) == "table" and choices[1] then return "choose", choices end
    return nil
end

--- A spell's name for a message, falling back to the id so a line is never half-built.
local function named(id)
    local name = NS.Compat and NS.Compat.GetSpellInfo and NS.Compat.GetSpellInfo(id)
    if type(name) == "string" and name ~= "" then
        return ("%s (%d)"):format(name, id)
    end
    return tostring(id)
end

--- The id to actually store for `typed`, plus the chat line owed to the player.
---
--- ONE SEAM FOR EVERY ADD BOX. Both the Spell Categories tab and the Filters page's Overrides
--- lists take an id the same way and have the same problem, so they take the same answer here
--- rather than each growing its own copy of the reasoning.
---
--- Returns `storeId, line`. `line` is nil when there is nothing to say, which is the common case.
function CA.ForAdd(typed)
    local kind, value = CA.Resolve(typed)
    if kind == "rewrite" then
        return value, NS.L["%s is cast, but the aura it applies is %s — added %s instead, which is what the filter can match."]
            :format(named(typed), named(value), tostring(value))
    end
    if kind == "choose" then
        local parts = {}
        local n = #value
        for i = 1, n do
            parts[i] = named(value[i])
        end
        return typed, NS.L["%s never appears as an aura, so this entry will match nothing. Auras with that name: %s. Add the one you meant."]
            :format(named(typed), table.concat(parts, ", "))
    end
    return typed, nil
end

--- The gray second line an ALREADY-STORED entry gets, or nil.
---
--- The add-time line is chat and is gone by the next login; an id stored before this addon could
--- say anything about it would otherwise sit in the list forever looking perfectly normal. This is
--- what the list draws under such an entry (LibKa0s `O.IdList`'s `note`).
---
--- A rewrite candidate gets a note too, not only a choice: an entry holding a cast id whose aura
--- IS known is the most fixable case on the page, and the note names the id to use.
function CA.Note(id)
    local kind, value = CA.Resolve(id)
    if kind == "rewrite" then
        return NS.L["Never matches — this is the cast. Its aura is %s."]:format(tostring(value))
    end
    if kind == "choose" then
        local parts = {}
        local n = #value
        for i = 1, n do
            parts[i] = tostring(value[i])
        end
        return NS.L["Never matches — this spell applies no aura. Auras with this name: %s."]
            :format(table.concat(parts, ", "))
    end
    return nil
end
