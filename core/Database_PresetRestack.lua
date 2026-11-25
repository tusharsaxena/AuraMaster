local _, NS = ...

-- core/Database_PresetRestack.lua -- schema v23, v24 and v25: the owner's 2026-11-23 preset feedback (and v25,
-- their 2026-11-26 request: a preset's icon rows without time text, at the end of the file) carried into a
-- profile an older build's preset wrote (spec docs/superpowers/specs/2026-11-23-preset-restack-design.md,
-- section 4). Run by core/Database.lua's ladder over every stored profile.
--
-- WHAT IT CHANGES, AND ONLY WHILE THE OLD PRESET'S VALUE IS STILL THERE. Nothing records which preset
-- made a container, so a container is the preset's role only by the exact name the v22 builder wrote,
-- "[NN] <name>". Per field:
--   * the fill of a role the owner recolored (Player buffs, short gray to blue; the cooldown roles blue
--     to tan), only while One color, off the skin and off the class color, in the old color exactly;
--   * a bar's width to 240, only while it is one of the two widths the v22 builder could have written
--     on this parent (its column, 240 scaled by the old horizontal scale, rounded either way);
--   * a tower's order and numbers, only while its whole old chain is there, each role once by its old
--     name, each member attached to the one before it, and nothing else attached to any of them.
-- v24 (Database.TurnFarPair) is the owner's second change that day, the special roles' #393939 and
-- the far pair turned round, under the same rule: a step of its own, since a client may have run and
-- stamped v23 before it existed.
-- Everything else is the player's and stays. Each container keeps its id, spells and settings; a
-- restacked tower's slots keep their placement (the head's place, each member's points and offsets),
-- and the roles move between them.
--
-- FROZEN. The old names, the old colors and the old scale are written out here, not read off
-- defaults/Presets.lua, so a later preset change never moves what v23 does. tests/presets_v22_fixture.lua
-- is the v22 builder's own output, and tests/test_database_restack.lua holds this file to it.

NS.Database = NS.Database or {}
local Database = NS.Database

local L = NS.L

-- The roles, by the builder's keys, and the names they carry.
local ROLE = {
    pbuffs = "Player buffs (all)", wpn = "Weapon enchants", pdebuffs = "Player debuffs (all)",
    pshort = "Player buffs, short", pcd = "Player cooldowns", pspec = "Player special (mine)",
    tspec = "Target special (mine)", tdeb = "Target debuffs (mine)", tbuff = "Target buffs (mine)",
    tcc = "Target crowd control", tcdp = "Target cooldowns, players", tcdn = "Target cooldowns, NPCs",
    tsteal = "Target stealable", tcd = "Target cooldowns", fdeb = "Focus debuffs (mine)",
    fbuff = "Focus buffs (mine)", healTarget = "Your heals on target", dispelTarget = "Dispellable by you on target",
    healFocus = "Your heals on focus", dispelFocus = "Dispellable by you on focus",
    ticoD = "Target debuffs (all)", ticoB = "Target buffs (all)",
}
-- THE FAR PAIR (the owner's second 2026-11-23 change): v22 placed [17] Target debuffs (all) on the
-- screen and hung [18] Target buffs (all) on it, BOTTOMLEFT to TOPLEFT, both growing up; now [18] is
-- placed and [17] hangs under it, TOPLEFT to BOTTOMLEFT, both growing down.
local PAIR_UNDER, PAIR_HEAD = { 17, "ticoD" }, { 18, "ticoB" }

-- Every bars role the v22 builder numbered, in any preset: { number, role }.
local BARS = {
    { 1, "pbuffs" }, { 2, "wpn" }, { 3, "pdebuffs" },
    { 4, "pshort" }, { 5, "pcd" }, { 6, "tdeb" }, { 7, "tcd" }, { 8, "fdeb" },
    { 7, "pshort" }, { 8, "pcd" }, { 9, "pspec" }, { 10, "tspec" }, { 11, "tdeb" }, { 12, "tbuff" },
    { 13, "tcc" }, { 14, "tcdp" }, { 15, "tcdn" }, { 16, "tsteal" }, { 19, "fdeb" }, { 20, "fbuff" },
    { 6, "healTarget" }, { 7, "dispelTarget" }, { 8, "healFocus" }, { 9, "dispelFocus" },
}

-- The towers, bottom up (head first): the v22 chain and the roles in their new order. Slot k keeps
-- its number, so the new k-th role takes the old k-th number.
local TOWERS = {
    { preset = "advanced", old = { { 7, "pshort" }, { 8, "pcd" }, { 9, "pspec" } },
        new = { "pspec", "pcd", "pshort" } },
    { preset = "advanced", old = { { 10, "tspec" }, { 11, "tdeb" }, { 12, "tbuff" }, { 13, "tcc" },
        { 14, "tcdp" }, { 15, "tcdn" }, { 16, "tsteal" } },
        new = { "tspec", "tcc", "tcdp", "tcdn", "tdeb", "tbuff", "tsteal" } },
    { preset = "intermediate", old = { { 4, "pshort" }, { 5, "pcd" } }, new = { "pcd", "pshort" } },
    { preset = "intermediate", old = { { 6, "tdeb" }, { 7, "tcd" } }, new = { "tcd", "tdeb" } },
}

local function rgb(r, g, b) return { r = r / 255, g = g / 255, b = b / 255, a = 1 } end
local GRAY, TAN, DARK = rgb(69, 69, 69), rgb(230, 204, 128), rgb(0x39, 0x39, 0x39)
-- The recolored roles, { number, role }, and the fill each goes from and to (nil: the template's).
-- The special roles' #393939 is the owner's second change of 2026-11-23.
local RECOLOR = {
    { from = GRAY, to = nil, roles = { { 7, "pshort" }, { 4, "pshort" } } },
    { from = nil, to = TAN, roles = { { 8, "pcd" }, { 5, "pcd" }, { 15, "tcdn" }, { 7, "tcd" } } },
}
-- v24's (the owner's second change): by the names v23 leaves, Player special (mine) restacked to [07]
-- or still [09] where its tower stayed, from the template's blue; Target special (mine) from gray.
local RECOLOR_V24 = {
    { from = nil, to = DARK, roles = { { 7, "pspec" }, { 9, "pspec" } } },
    { from = GRAY, to = DARK, roles = { { 10, "tspec" } } },
}

-- The v22 builder's horizontal scale: the parent's height over 1080, narrowed where the width is
-- under twice its layout's reach plus the edge room (2 x 846.8), and its column width.
local OLD_REF_H, OLD_SPAN, OLD_COL, NEW_COL = 1080, 1693.6, 240, 240

-- THE V22 PLACES. Each stack's head as the v22 builder placed it, in its reference units (its x the
-- column's left edge from the center line, `mid` a head placed by its middle on the screen's CENTER,
-- `y` an up stack's base from the center line's TOP), and the old names of the roles that headed it.
-- The scale and the cluster's shift are the v22 builder's: k = H / 1080 (1 unreadable), kx = min(k,
-- W / 1693.6), and the cluster moved left by max(0, 1012.8 - (W / (2 kx) - 10)), its width taken at
-- 16:9 where it cannot be read. A head still at that place moves to where a fresh apply puts it now
-- (NS.PresetData.HeadPlace); one the player moved stays.
local OLD_STACKS = {
    cornerRight = { anchor = "CENTER", x = 772.8, mid = 441, cluster = true },
    left = { anchor = "CENTER", x = -426, mid = -153 },
    right = { anchor = "CENTER", x = 186, mid = -153, cluster = true },
    focus = { anchor = "TOP", x = 530, y = -550, up = true, cluster = true },
    far = { anchor = "TOP", x = 530, y = -740, up = true, cluster = true },
}
local OLD_CLUSTER_RIGHT, OLD_EDGE = 1012.8, 10
local HEADS = {
    { 1, "pbuffs", "cornerRight" },
    { 4, "pshort", "left" }, { 6, "tdeb", "right" }, { 8, "fdeb", "focus" },
    { 7, "pshort", "left" }, { 10, "tspec", "right" }, { 17, "ticoD", "far" }, { 19, "fdeb", "focus" },
    { 5, "pcd", "left" }, { 6, "healTarget", "right" }, { 8, "healFocus", "focus" },
}

local function nameOf(entry)
    return ("[%02d] %s"):format(entry[1], L[ROLE[entry[2]]])
end

--- The widths the v22 builder could have written on a `W` x `H` parent: the column, 240, at its
--- horizontal scale, rounded down and up (each edge was rounded on its own). Only 240 where the
--- parent cannot be read (its scale fell back to 1).
local function oldWidths(W, H)
    local kx = 1
    if type(H) == "number" and H == H and H > 0 then kx = H / OLD_REF_H end
    if type(W) == "number" and W == W and W > 0 then kx = math.min(kx, W / OLD_SPAN) end
    return { [math.floor(OLD_COL * kx)] = true, [math.ceil(OLD_COL * kx)] = true }
end

local function round(v) return math.floor(v + 0.5) end

local function readable(v) return type(v) == "number" and v == v and v > 0 end

--- The v22 builder's scales on a `W` x `H` parent: k down, kx across, and the cluster's shift.
local function oldScales(W, H)
    local k = readable(H) and H / OLD_REF_H or 1
    if not readable(W) then W = ((k == 1) and OLD_REF_H or H) * 16 / 9 end
    local kx = math.min(k, W / OLD_SPAN)
    return k, kx, math.min(0, W / (2 * kx) - OLD_EDGE - OLD_CLUSTER_RIGHT)
end

--- Where the v22 builder placed stack `stackKey`'s head in style `style`, growing `growH`.
local function oldPlace(stackKey, style, growH, W, H)
    local s = OLD_STACKS[stackKey]
    local k, kx, shift = oldScales(W, H)
    local x = s.x + (s.cluster and shift or 0)
    local right = growH == "left"
    if s.mid then
        local y = round(s.mid * k)
        if style == "icons" then
            return { point = right and "RIGHT" or "LEFT", relativePoint = s.anchor,
                x = round((right and (x + OLD_COL) or x) * kx), y = y }
        end
        return { point = "CENTER", relativePoint = s.anchor, x = round((x + OLD_COL / 2) * kx), y = y }
    end
    return { point = (s.up and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT"), relativePoint = s.anchor,
        x = round((right and (x + OLD_COL) or x) * kx), y = round(s.y * k) }
end

local CHANNELS = { "r", "g", "b", "a" }

--- Whether stored color `c` is `want` on every channel (a channel it lacks reads as want's).
local function sameColor(c, want)
    if type(c) ~= "table" then return false end
    for _, k in ipairs(CHANNELS) do
        local v = c[k]
        if v == nil then v = want[k] end
        if type(v) ~= "number" or math.abs(v - want[k]) > 1e-6 then return false end
    end
    return true
end

local function templateBars() return NS.CONTAINER_TEMPLATE.bars end

--- Whether bars section `b` holds the fill a v22 preset wrote: One color, off the skin and the class
--- color, in `from` (nil: the template's color).
local function oldFill(b, from)
    local D = templateBars()
    return b.colorMode == "static" and b.barColorFromSkin == false and b.useClassColorBar ~= true
        and sameColor(b.barColor or D.barColor, from or D.barColor)
end

local function writeFill(b, to)
    local D = templateBars()
    b.colorMode = "static"
    b.barColor = Database.DeepCopy(to or D.barColor)
    b.barColorFromSkin, b.useClassColorBar = false, false
end

--- [name] = every container in `p` stored under that name, before anything is renamed.
local function indexByName(p)
    local out = {}
    for _, c in pairs(p.containers) do
        if type(c) == "table" and type(c.name) == "string" then
            local list = out[c.name] or {}
            list[#list + 1] = c
            out[c.name] = list
        end
    end
    return out
end

--- The one container named `name`, or nil when none or more than one is.
local function only(byName, name)
    local list = byName[name]
    return (list and #list == 1) and list[1] or nil
end

local function bars(c)
    return c.style == "bars" and type(c.bars) == "table" and c.bars or nil
end

--- Recolor every role of RECOLOR still in its old fill; note one that is not.
local function recolor(byName, notes, rules)
    local n = 0
    for _, rule in ipairs(rules) do
        for _, entry in ipairs(rule.roles) do
            for _, c in ipairs(byName[nameOf(entry)] or {}) do
                local b = bars(c)
                if b and oldFill(b, rule.from) then
                    writeFill(b, rule.to)
                    n = n + 1
                elseif b then
                    notes[#notes + 1] = { c = c, field = "color", why = "not the old preset fill" }
                end
            end
        end
    end
    return n
end

--- Every bar of an old preset role at the width the v22 builder wrote on this parent goes to 240.
local function resize(byName, W, H, notes)
    local old, n, seen = oldWidths(W, H), 0, {}
    for _, entry in ipairs(BARS) do
        for _, c in ipairs(byName[nameOf(entry)] or {}) do
            local b = bars(c)
            if b and not seen[c] then
                seen[c] = true
                if b.width ~= NEW_COL and old[b.width] then
                    b.width = NEW_COL
                    n = n + 1
                elseif b.width ~= NEW_COL then
                    notes[#notes + 1] = { c = c, field = "width", why = "not the old preset width" }
                end
            end
        end
    end
    return n
end

--- The id of the container `c` hangs from: an attach to a container, or to a container's frame typed
--- by its global name (modules/Container.lua's AuraMasterAnchor<id>); nil for any other.
local function hangsFrom(c)
    local at = type(c) == "table" and c.attach
    if type(at) ~= "table" then return nil end
    if at.mode == "container" then return tonumber(at.container) end
    if at.mode == "frame" and type(at.frame) == "string" then return tonumber(at.frame:match("^AuraMasterAnchor(%d+)$")) end
    return nil
end

local PLACE_FIELDS = { "point", "relativePoint", "x", "y" }

--- Whether stored position `pos` is `want` exactly.
local function samePlace(pos, want)
    if type(pos) ~= "table" then return false end
    for _, f in ipairs(PLACE_FIELDS) do
        if pos[f] ~= want[f] then return false end
    end
    return true
end

--- Where v23 moves a head still at its v22 place: where a fresh apply put it when v23 was written
--- (APR-06), NS.PresetData.HeadPlace's, but for the far stack, whose head v24 turns round: v23's is
--- [17] by its bottom corner on the far base, the column's left edge (its right growing left) as
--- placed now, frozen so v23 does on every account what it did on the first that ran it.
local function v23Place(stack, style, growH, W, H)
    local Data = NS.PresetData
    if stack ~= "far" then return Data.HeadPlace(stack, style, growH, W, H) end
    local col, left = Data.Columns(W, H).far, growH == "left"
    return { point = "BOTTOM" .. (left and "RIGHT" or "LEFT"), relativePoint = col.anchor,
        x = round(col.x * Data.ScaleX(W, H)) + (left and col.width or 0), y = round(col.y * Data.Scale(H)) }
end

--- Every stack head of an old preset still placed on the screen at the v22 builder's place for this
--- parent moves to where a fresh apply puts it now. Run before the restack, on the head's position
--- table, which the restack hands to the tower's new head with the slot.
--- One head `c` of stack `stack`: moved when still at the v22 place, noted when at neither place.
local function replaceHead(c, stack, W, H, notes)
    local at = c.attach
    if type(at) ~= "table" or at.mode ~= "screen" then return 0 end
    local growH = type(c.layout) == "table" and c.layout.growH or "right"
    local new = v23Place(stack, c.style, growH, W, H)
    if not new or samePlace(c.position, new) then return 0 end
    if not samePlace(c.position, oldPlace(stack, c.style, growH, W, H)) then
        notes[#notes + 1] = { c = c, field = "place", why = "not the old preset place" }
        return 0
    end
    for _, f in ipairs(PLACE_FIELDS) do c.position[f] = new[f] end
    return 1
end

local function replaceHeads(byName, W, H, notes)
    local n, Data = 0, NS.PresetData
    if not (Data and Data.HeadPlace) then return 0 end
    for _, entry in ipairs(HEADS) do
        for _, c in ipairs(byName[nameOf(entry)] or {}) do n = n + replaceHead(c, entry[3], W, H, notes) end
    end
    return n
end

local function growHOf(c)
    return type(c.layout) == "table" and c.layout.growH or "right"
end

--- Whether `D` and `B` are still the far pair as v22 wrote it on this parent, and nothing else of the
--- profile `p` hangs from either.
--- Whether `B`'s attach is v22's link onto `D`: BOTTOMLEFT to TOPLEFT, flush.
local function oldLink(B, D)
    local ba = B.attach
    if type(ba) ~= "table" or ba.mode ~= "container" or tonumber(ba.container) ~= D.id then return false end
    return ba.childPoint == "BOTTOMLEFT" and ba.relPoint == "TOPLEFT" and (ba.x or 0) == 0 and (ba.y or 0) == 0
end

local function growsUp(c)
    return type(c.layout) == "table" and c.layout.growV == "up"
end

--- Whether nothing of `p` but `B` hangs from `D` or `B`.
local function pairAlone(p, D, B)
    for _, c in pairs(p.containers) do
        local parent = hangsFrom(c)
        if c ~= B and (parent == D.id or parent == B.id) then return false end
    end
    return true
end

--- Whether `D`'s place is one a preset gave [17]: v22's, or v23's move of it (v23Place).
local function presetFarPlace(D, W, H)
    local growH = growHOf(D)
    return samePlace(D.position, oldPlace("far", D.style, growH, W, H))
        or samePlace(D.position, v23Place("far", D.style, growH, W, H))
end

local function oldPair(p, D, B, W, H)
    local da = D.attach
    if type(da) ~= "table" or da.mode ~= "screen" or not presetFarPlace(D, W, H) then return false end
    return oldLink(B, D) and growsUp(D) and growsUp(B) and pairAlone(p, D, B)
end

--- Re-anchor the far pair while it is v22's: [18] placed where a fresh apply puts it, [17] under it.
local function reanchorPair(p, byName, W, H, notes)
    local D, B = only(byName, nameOf(PAIR_UNDER)), only(byName, nameOf(PAIR_HEAD))
    local Data = NS.PresetData
    if not (D and B and Data and Data.HeadPlace) then return 0 end
    if not oldPair(p, D, B, W, H) then
        notes[#notes + 1] = { c = D, field = "pair", why = "not the old preset pair" }
        return 0
    end
    local new = Data.HeadPlace("far", B.style, growHOf(B), W, H)
    if not new then return 0 end
    B.attach = { mode = "screen", container = 0, frame = "" }
    B.position = Database.DeepCopy(new)
    D.attach = { mode = "container", container = B.id, frame = "", childPoint = "TOPLEFT", relPoint = "BOTTOMLEFT",
        x = 0, y = 0 }
    D.layout.growV, B.layout.growV = "down", "down"
    return 2
end

--- Tower `tower`'s members in `p`, bottom up, while its old chain is whole; nil and why otherwise.
local function chainOf(p, byName, tower)
    local members, ids = {}, {}
    for k, entry in ipairs(tower.old) do
        local c = only(byName, nameOf(entry))
        if not c then return nil, "a role is missing or named twice" end
        members[k], ids[c.id] = c, true
    end
    for k = 2, #members do
        local at = members[k].attach
        if type(at) ~= "table" or at.mode ~= "container" or tonumber(at.container) ~= members[k - 1].id then
            return nil, "a member is not on the one before it"
        end
    end
    for _, c in pairs(p.containers) do
        local parent = hangsFrom(c)
        if parent and ids[parent] then
            local inside = false
            for k = 2, #members do inside = inside or members[k] == c end
            if not inside then return nil, "another container is attached to it" end
        end
    end
    return members
end

--- Refill `order`'s places that hold the tower's ids with `new`'s ids, when they hold them in the
--- old chain's order (`members`); a display order the player changed stays.
local function reorder(order, members, new)
    local at, pos = {}, {}
    for k, c in ipairs(members) do at[c.id] = k end
    for i, id in ipairs(order) do
        if at[id] then pos[#pos + 1] = i end
    end
    if #pos ~= #members then return end
    for j, i in ipairs(pos) do
        if order[i] ~= members[j].id then return end
    end
    for j, i in ipairs(pos) do order[i] = new[j].id end
end

--- Restack one tower whose chain is whole: slot k keeps its placement and its number; the roles move.
local function restack(p, tower, members)
    local byRole, slots, new = {}, {}, {}
    for k, entry in ipairs(tower.old) do
        byRole[entry[2]] = members[k]
        slots[k] = { attach = members[k].attach, position = members[k].position }
    end
    for k, role in ipairs(tower.new) do new[k] = byRole[role] end
    for k, c in ipairs(new) do
        c.attach, c.position = slots[k].attach, slots[k].position
        if k > 1 then c.attach.container = new[k - 1].id end
        c.name = nameOf({ tower.old[k][1], tower.new[k] })
    end
    reorder(p.containerOrder, members, new)
    return #new
end

local function restackAll(p, byName, notes)
    local n = 0
    for _, tower in ipairs(TOWERS) do
        local members, why = chainOf(p, byName, tower)
        if members then
            n = n + restack(p, tower, members)
        else
            -- Noted only where the tower was there to restack: its head under its old name.
            local head = only(byName, nameOf(tower.old[1]))
            if head then notes[#notes + 1] = { c = head, field = "tower", why = why } end
        end
    end
    return n
end

--- The untouched-seed record (modules/Presets.lua) of `p`, matched before the step: re-recorded after.
local function seedMatched(p)
    local Presets = NS.Presets
    local store = type(p.presets) == "table" and p.presets or nil
    return store and type(store.seedPrint) == "number" and Presets and Presets.Fingerprint
        and store.seedPrint == Presets.Fingerprint(p.containers, p.containerOrder)
end

--- The end both steps share: an untouched seed re-recorded, and each note naming its container as
--- it ends the step (a restack renames).
local function finish(p, seeded, n, notes)
    if seeded and n > 0 then p.presets.seedPrint = NS.Presets.Fingerprint(p.containers, p.containerOrder) end
    for _, note in ipairs(notes) do note.name, note.c = note.c.name, nil end
    return n, notes
end

--- v23 over one stored profile `p`, on a `W` x `H` parent (nil when it cannot be read). Answers how
--- many fields it changed, and the notes of every preset field it left because the player had changed
--- it ({ name, field = "color" | "width" | "tower", why }).
--- @return number changed, table notes
function Database.RestackPresets(p, W, H)
    local notes = {}
    if type(p) ~= "table" or type(p.containers) ~= "table" or type(p.containerOrder) ~= "table" then
        return 0, notes
    end
    local seeded = seedMatched(p)
    local byName = indexByName(p)
    local n = recolor(byName, notes, RECOLOR) + resize(byName, W, H, notes) + replaceHeads(byName, W, H, notes)
        + restackAll(p, byName, notes)
    return finish(p, seeded, n, notes)
end

--- v24 over one stored profile `p`, on a `W` x `H` parent: the owner's second 2026-11-23 change,
--- after v23 (a profile from v22 runs both; one a v23 build already stamped runs this alone). The
--- special roles' #393939 and the far pair turned round, each only while still the preset's: the
--- fill of item 1's rule, and the pair while [17] is at the v22 place or v23's move of it, [18] on it
--- by the v22 points, both growing up, nothing else attached. Answers as RestackPresets.
--- @return number changed, table notes
function Database.TurnFarPair(p, W, H)
    local notes = {}
    if type(p) ~= "table" or type(p.containers) ~= "table" or type(p.containerOrder) ~= "table" then
        return 0, notes
    end
    local seeded = seedMatched(p)
    local byName = indexByName(p)
    local n = recolor(byName, notes, RECOLOR_V24) + reanchorPair(p, byName, W, H, notes)
    return finish(p, seeded, n, notes)
end

-- SCHEMA V25 (the owner's 2026-11-26 request, spec docs/superpowers/specs/
-- 2026-11-26-preset-icon-time-text-design.md): a preset's icon rows draw no time text. Every role a
-- builder could have turned into an icon row (the far pair in either look, every bars role in the
-- Icons look) and the numbers it gave that role, frozen: the first numbered builder's (9937767 to
-- the 2026-11-17 rebuild, Advanced's target stack tdeb 10 .. tspec 16), the v22 builder's and the
-- current one's (APR-01's renumbering). A text role is never an icon row.
local ICON_ROLE_NUMBERS = {
    pbuffs = { 1 }, wpn = { 2 }, pdebuffs = { 3 },
    pshort = { 4, 5, 7, 9 }, pcd = { 4, 5, 8 }, pspec = { 7, 9 },
    tspec = { 10, 16 }, tcc = { 11, 12, 13 }, tcdp = { 12, 13, 14 }, tcdn = { 13, 14, 15 },
    tdeb = { 6, 7, 10, 11, 14 }, tbuff = { 11, 12, 15 }, tsteal = { 15, 16 }, tcd = { 6, 7 },
    ticoD = { 17 }, ticoB = { 18 }, fdeb = { 8, 19 }, fbuff = { 20 },
    healTarget = { 6 }, dispelTarget = { 7 }, healFocus = { 8 }, dispelFocus = { 9 },
}

--- [name] = true for every name a preset builder wrote on a container it could make an icon row.
local function iconRowNames()
    local out = {}
    for role, numbers in pairs(ICON_ROLE_NUMBERS) do
        for _, num in ipairs(numbers) do out[nameOf({ num, role })] = true end
    end
    return out
end

--- Whether `name` is one of `names`, or one of them with the " (N)" suffix ContainerManager.Create
--- gives a name already in use (a preset applied with Add over its own containers). A one-digit
--- number reads as its two-digit form: the builder wrote "[%d]" until 3edb6ac (2026-11-15).
local function presetName(names, name)
    if type(name) ~= "string" then return false end
    name = name:gsub("^%[(%d)%] ", "[0%1] ")
    return names[name] == true or names[name:match("^(.-) %(%d+%)$") or ""] == true
end

--- v25 over one stored profile `p`: every icon container a preset made, by its style and name, whose
--- time text still shows as the preset left it (`icons.time.show` true, or missing, which the backfill
--- reads as the template's true) has it hidden. A false stays; a player's Show turned off and on again
--- stores the same true and cannot be told apart. Answers the number of containers changed.
--- @return number
function Database.HidePresetIconTime(p)
    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0 end
    local names, n = iconRowNames(), 0
    for _, c in pairs(p.containers) do
        local icons = type(c) == "table" and c.style == "icons" and c.icons
        local time = type(icons) == "table" and icons.time
        if type(time) == "table" and time.show ~= false and presetName(names, c.name) then
            time.show = false
            n = n + 1
        end
    end
    return n
end

-- The frozen data, read by tests/test_database_restack.lua against the v22 builder's output.
Database.PRESET_RESTACK = {
    BarsNames = function()
        local out = {}
        for _, entry in ipairs(BARS) do out[#out + 1] = nameOf(entry) end
        return out
    end,
    OldPlace = oldPlace,
    HeadStack = function(name)
        for _, entry in ipairs(HEADS) do
            if nameOf(entry) == name then return entry[3] end
        end
        return nil
    end,
    Towers = function()
        local out = {}
        for _, tower in ipairs(TOWERS) do
            local t = { preset = tower.preset, oldNames = {}, newNames = {} }
            for k, entry in ipairs(tower.old) do
                t.oldNames[k] = nameOf(entry)
                t.newNames[k] = nameOf({ entry[1], tower.new[k] })
            end
            out[#out + 1] = t
        end
        return out
    end,
}
