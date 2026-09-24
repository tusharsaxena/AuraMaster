local _, NS = ...

-- fixtures/CastToAura.lua -- a small copy of defaults/CastToAura.lua in the generated shape.

NS.CastToAura = NS.CastToAura or {}

-- [cast id] = the one aura it applies.
NS.CastToAura.REWRITE = {
    [172] = 146739,   -- Corruption (trigger)
    [98008] = 98007,   -- Spirit Link Totem (fixture)
}

-- [cast id] = { every aura id that could be the one }, ascending.
NS.CastToAura.CHOICES = {
    [53] = { 245689, 319065 },   -- Backstab (name, 2 candidates)
    [114050] = { 114051, 114052, 147059, 1219480, 1252197 },   -- Ascendance (name, 5 candidates)
    [900050] = { 146739, 900051 },   -- a second cast sharing 146739 (fixture)
}
