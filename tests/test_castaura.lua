-- tests/test_castaura.lua — the cast -> aura seam (issue #15).
--
-- The rule the whole file turns on: a REWRITE came from a real EffectTriggerSpell edge and may be
-- stored; a CHOICE came from matching names and may not. An early cut of the generator ignored that
-- and produced 215 confident rewrites of spells that apply no aura at all, so the distinction is
-- asserted here rather than trusted.
--
-- The table is stubbed, not read from defaults/CastToAura.lua. That file is generated and its
-- contents move with every Blizzard build; a case pinned to 115151's real candidate list would go
-- red on a re-generation that changed nothing about this code. What is under test is the seam.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

local newEnv = dofile("tests/fresh_env.lua")

--- A loaded addon whose generated table is `tbl`. The real defaults/CastToAura.lua has
--- already loaded by then; replacing it is the point, so a case says what it is testing
--- against instead of depending on whatever the current Blizzard build derived.
local function fresh(tbl)
    local NS = newEnv()
    NS.CastToAura = tbl
    return NS, NS.CastAura
end

local STUB = {
    REWRITE = { [115151] = 119611 },
    CHOICES = { [5782] = { 118699, 130616 } },
}

test("castaura: an id the table has never heard of is stored exactly as typed", function()
    local _, CA = fresh(STUB)
    local stored, line = CA.ForAdd(12345)
    assertEqual(stored, 12345, "the typed id, unchanged")
    assertNil(line, "and nothing is said — this is every ordinary spell")
    assertNil(CA.Note(12345), "and no note under it")
end)

test("castaura: a trigger-derived id is rewritten to its aura, and the player is told", function()
    local _, CA = fresh(STUB)
    local stored, line = CA.ForAdd(115151)
    -- red under: storing what was typed, which is the bug the issue is about
    assertEqual(stored, 119611, "the AURA id is what goes in the list")
    assertTrue(line ~= nil, "and the swap is announced, never silent")
    assertTrue(line:find("119611", 1, true) ~= nil, "the line names the id actually stored")
end)

test("castaura: a name-derived id is NOT rewritten — the candidates are offered", function()
    local _, CA = fresh(STUB)
    local stored, line = CA.ForAdd(5782)
    -- THE LOAD-BEARING ASSERTION. A name match is a candidate and never a conclusion: several
    -- unrelated spells share a name, and storing one would be the silent wrong id this seam exists
    -- to prevent. red under a seam that resolved a choice of its own accord.
    assertEqual(stored, 5782, "stored exactly as typed")
    assertTrue(line ~= nil, "but the player is told it cannot match")
    assertTrue(line:find("118699", 1, true) ~= nil, "and both candidates are named")
    assertTrue(line:find("130616", 1, true) ~= nil)
end)

test("castaura: a stored entry that can never match carries a note", function()
    local _, CA = fresh(STUB)
    local rewrite = CA.Note(115151)
    local choice  = CA.Note(5782)
    -- The add-time line is chat and is gone by the next login; an id stored before this existed
    -- would otherwise sit in the list forever looking perfectly normal.
    assertTrue(rewrite ~= nil and rewrite:find("119611", 1, true) ~= nil,
        "a cast id's note names the aura to use instead")
    assertTrue(choice ~= nil and choice:find("118699", 1, true) ~= nil,
        "a choice's note names the candidates")
end)

test("castaura: an absent or empty table says nothing about any id", function()
    local _, CA = fresh(nil)
    assertNil(CA.Note(115151), "no table, no note")
    local stored, line = CA.ForAdd(115151)
    assertEqual(stored, 115151, "and the add is untouched")
    assertNil(line)
    local _, CA2 = fresh({})
    assertNil(CA2.Note(115151), "an empty table reads the same as an absent one")
end)

test("castaura: a non-number is not resolved", function()
    local _, CA = fresh(STUB)
    assertNil(CA.Resolve("115151"), "a string id resolves to nothing rather than raising")
    assertNil(CA.Resolve(nil))
end)
