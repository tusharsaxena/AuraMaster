local _, NS = ...

-- modules/TextTemplate.lua — the Text style's template language (issue #2): a player-written line
-- such as `$spellname$[ x$stacks$][ - $remainingduration$]` in, an ordered list of PIECES out.
--
-- WHY PIECES. While auras are secret no addon code can read an aura's name, stacks or time, so no
-- addon code can build the line as one string. The engine writes each field into a font string of
-- ours instead, and a line is a CHAIN of font strings: one per engine field, plus static ones for
-- plain text (docs/midnight-quirks.md, "Text chains and animations on engine buttons"). The engine
-- has ONE binding per field, so a token can be used once, and every duration token shares one
-- duration binding, so they must sit together as one run.
--
-- PURE. No frames and no client API: a string in, a table out, so every rule is proven headlessly
-- (tests/test_texttemplate.lua). It reads core/Constants.lua's token list and routes its refusals
-- through NS.L, both loaded long before this file.
--
-- A piece is one of:
--   { kind = "literal",  text }                          static text, merged with its neighbors
--   { kind = "name" }                                    SetSpellName
--   { kind = "stacks",   pre, post, format }             SetApplicationCount; `format` is
--                                                        pre .. "%d" .. post with every % doubled
--   { kind = "dispel",   pre, post }                     SetDispelTypeText; the map adds pre/post
--   { kind = "duration", pre, post, format, components } SetDurationText; `format` is the whole run
--                                                        with each token as {} and the bracket's
--                                                        text around it; `components` holds one
--                                                        { prop, fmt } per {} in order
-- `pre` and `post` are the text inside the token's [ ] group before and after it ("" unbracketed).
--
-- Results are memoized per template string and SHARED: a caller must never edit one.

NS.TextTemplate = NS.TextTemplate or {}
local TT = NS.TextTemplate

local C = NS.Constants
local L = NS.L

--- Every token by its lower-case key: { key, kind, prop, fmt } (core/Constants.lua's TEXT_TOKENS).
TT.TOKENS = {}
for _, def in ipairs(C.TEXT_TOKENS) do TT.TOKENS[def.key] = def end

--- "$spellname$, $stacks$, ..." for the unknown-token refusal, in cheat-sheet order.
local function knownList()
    local out = {}
    for i, def in ipairs(C.TEXT_TOKENS) do out[i] = "$" .. def.key .. "$" end
    return table.concat(out, ", ")
end

local function append(list, v)
    local n = #list
    list[n + 1] = v
end

-- ---------------------------------------------------------------------------
-- 1. Lexing: characters to literals, tokens and bracket marks
-- ---------------------------------------------------------------------------

-- `]]` and `$$` are the escapes for a literal `]` and `$`. `[` is handled separately below: a run of
-- them is ambiguous (`[[[` could open a bracket then escape one `[`, or escape one `[` then open),
-- resolved by parity — see lexBracketOpen.
local ESCAPES = { ["]]"] = "]", ["$$"] = "$" }
local MARKS = { ["]"] = "close" }

--- One `$name$` at `i`: the item and the index after it, or nil when `$` opens no token here (a lone
--- `$` is literal text). An unknown name is refused (rule 1).
local function lexToken(s, i)
    local name, after = s:match("^%$([%w_]+)%$()", i)
    if not name then return nil end
    local def = TT.TOKENS[name:lower()]
    if not def then
        return nil, nil, L["Unknown token $%s$. Known: %s"]:format(name, knownList())
    end
    return { t = "tok", def = def }, after
end

--- One `[` (or a run of them) at `i`: the run's length decides it, not left-to-right greed, so the
--- group a `[` opens (if any) is always the FIRST `[` of an odd run, with every later pair inside
--- it as an escaped `[`. An even run is all escapes, no open (mirrors how a `]` run already lexes:
--- pairs first, an odd run's LAST `]` closes — kept as-is below).
local function lexBracketOpen(s, i)
    local run = s:match("^%[+", i)
    local n = #run
    if n % 2 == 1 then return { t = "open" }, i + 1 end
    return { t = "lit", s = "[" }, i + 2
end

--- The item starting at `i` and the index after it, or nil plus a refusal.
local function lexOne(s, i)
    if s:sub(i, i) == "[" then return lexBracketOpen(s, i) end
    local two = s:sub(i, i + 1)
    if ESCAPES[two] then return { t = "lit", s = ESCAPES[two] }, i + 2 end
    local c = s:sub(i, i)
    if MARKS[c] then return { t = MARKS[c] }, i + 1 end
    if c == "$" then
        local item, after, err = lexToken(s, i)
        if err then return nil, nil, err end
        if item then return item, after end
        return { t = "lit", s = "$" }, i + 1
    end
    local run, stop = s:match("^([^%$%[%]]+)()", i)
    return { t = "lit", s = run }, stop
end

--- The template as a flat list of items, or nil plus the rule-1 refusal.
local function lex(s)
    local items, i, last = {}, 1, #s
    while i <= last do
        local item, after, err = lexOne(s, i)
        if err then return nil, err end
        append(items, item)
        i = after
    end
    return items
end

-- ---------------------------------------------------------------------------
-- 2. The rules, in the order they are reported
-- ---------------------------------------------------------------------------

--- Rule 2: each token at most once.
local function checkOnce(items)
    local seen = {}
    for _, it in ipairs(items) do
        if it.t == "tok" then
            local key = it.def.key
            if seen[key] then return L["$%s$ appears twice — each token can be used once."]:format(key) end
            seen[key] = true
        end
    end
    return nil
end

local function isDuration(it) return it.t == "tok" and it.def.kind == "duration" end

--- The index of the first and the last duration token, or nil when there is none.
local function durationSpan(items)
    local first, last
    for i, it in ipairs(items) do
        if isDuration(it) then
            first = first or i
            last = i
        end
    end
    return first, last
end

--- Rule 3: between the first and the last duration token, only text and duration tokens.
local function checkRun(items)
    local first, last = durationSpan(items)
    if not first then return nil end
    for i = first, last do
        local it = items[i]
        if it.t == "tok" and not isDuration(it) then
            return L["Duration tokens must sit together — $%s$ splits them."]:format(it.def.key)
        end
    end
    return nil
end

--- Rules 4a/4b: the flat items as top-level nodes, each [ ] group one node holding its items.
local function groupItems(items)
    local nodes, open = {}, nil
    for _, it in ipairs(items) do
        if it.t == "open" then
            if open then return nil, L["Brackets can't be nested."] end
            open = { t = "group", items = {} }
            append(nodes, open)
        elseif it.t == "close" then
            if not open then return nil, L["Unmatched [ or ]."] end
            open = nil
        else
            append(open and open.items or nodes, it)
        end
    end
    if open then return nil, L["Unmatched [ or ]."] end
    return nodes
end

--- How many foldable units a group holds ($stacks$, $dispeltype$, the duration run as one), how
--- many of its tokens are durations, and whether it holds the name.
local function unitsIn(group)
    local units, durations, hasName = 0, 0, false
    for _, it in ipairs(group.items) do
        if it.t == "tok" then
            local kind = it.def.kind
            if kind == "duration" then
                durations = durations + 1
            elseif kind == "name" then
                hasName = true
            else
                units = units + 1
            end
        end
    end
    if durations > 0 then units = units + 1 end
    return units, durations, hasName
end

--- The number of duration tokens in the whole template.
local function countDurations(items)
    local n = 0
    for _, it in ipairs(items) do
        if isDuration(it) then n = n + 1 end
    end
    return n
end

--- Rule 4c over every group: each one holds exactly one foldable unit. Checked over every group
--- before rule 5 runs over any of them, so a rule-4 break always outranks a rule-5 break, whichever
--- group each sits in (a later group's rule-4 break must still beat an earlier group's rule-5 one).
local function checkUnits(nodes)
    for _, node in ipairs(nodes) do
        if node.t == "group" then
            local units, _, hasName = unitsIn(node)
            if units ~= 1 or hasName then
                return L["A [ ] group must hold exactly one of $stacks$, $dispeltype$ or the duration tokens."]
            end
        end
    end
    return nil
end

--- Rule 5 over every group: a duration group holds the whole run. Only reached once every group has
--- already passed rule 4c.
local function checkDurationGroups(nodes, totalDurations)
    for _, node in ipairs(nodes) do
        if node.t == "group" then
            local _, durations = unitsIn(node)
            if durations > 0 and durations ~= totalDurations then
                return L["Put all the duration tokens inside the same [ ]."]
            end
        end
    end
    return nil
end

--- Rules 4c and 5, in that order, over every group.
local function checkGroups(nodes, totalDurations)
    return checkUnits(nodes) or checkDurationGroups(nodes, totalDurations)
end

local BRACES = "[{}]"

--- Whether any literal of `list` from `first` to `last` holds a { or }.
local function bracesIn(list, first, last)
    for i = first, last do
        local it = list[i]
        if it.t == "lit" and it.s:find(BRACES) then return true end
    end
    return false
end

--- Rule 6: no { or } inside the duration run, or inside the group that holds it.
local function checkBraces(items, nodes)
    local first, last = durationSpan(items)
    if not first then return nil end
    local bad = bracesIn(items, first, last)
    for _, node in ipairs(nodes) do
        if node.t == "group" and select(2, unitsIn(node)) > 0 then
            local count = #node.items
            bad = bad or bracesIn(node.items, 1, count)
        end
    end
    if bad then return L["{ and } can't be used next to duration tokens."] end
    return nil
end

--- Rule 7: at least one token.
local function checkAnyToken(items)
    for _, it in ipairs(items) do
        if it.t == "tok" then return nil end
    end
    return L["Use at least one $token$."]
end

--- Rules 2 to 8 over lexed `items`: the top-level nodes, or nil plus the first refusal.
local function validate(s, items)
    local err = checkOnce(items) or checkRun(items)
    if err then return nil, err end
    local nodes, groupErr = groupItems(items)
    if not nodes then return nil, groupErr end
    err = checkGroups(nodes, countDurations(items)) or checkBraces(items, nodes) or checkAnyToken(items)
    if err then return nil, err end
    local length = #s
    if length > C.TEXT_TEMPLATE_MAX then
        return nil, L["A template can be at most %d characters."]:format(C.TEXT_TEMPLATE_MAX)
    end
    return nodes
end

-- ---------------------------------------------------------------------------
-- 3. Compiling: nodes to pieces
-- ---------------------------------------------------------------------------

--- A stack or format text with every % doubled, so string.format writes it as it reads.
local function escapePercent(text) return (text:gsub("%%", "%%%%")) end

--- The piece for one token outside any group (pre and post empty), or the start of a duration run.
local function tokenPiece(def)
    if def.kind == "name" then return { kind = "name" } end
    if def.kind == "stacks" then return { kind = "stacks", pre = "", post = "", format = "%d" } end
    if def.kind == "dispel" then return { kind = "dispel", pre = "", post = "" } end
    return { kind = "duration", pre = "", post = "", format = "", components = {} }
end

--- Add one duration token to a run: its {} in the format, its component in order.
local function addComponent(run, def)
    run.format = run.format .. "{}"
    append(run.components, { prop = def.prop, fmt = def.fmt })
end

--- One token inside a [ ] group: the group's piece (built on its first token) with a duration
--- token's {} and component added after the text since the previous token.
local function groupToken(piece, def, pending)
    piece = piece or tokenPiece(def)
    if piece.kind == "duration" then
        piece.format = piece.format .. pending
        addComponent(piece, def)
    end
    return piece
end

--- The piece one [ ] group folds into: its token, with the group's text before and after it. A
--- group holds exactly one unit (rule 4), so every token in it belongs to the one piece.
local function groupPiece(group)
    local pre, pending, piece = "", "", nil
    for _, it in ipairs(group.items) do
        if it.t == "tok" then
            piece, pending = groupToken(piece, it.def, pending), ""
        elseif piece then
            pending = pending .. it.s
        else
            pre = pre .. it.s
        end
    end
    piece.pre, piece.post = pre, pending
    if piece.kind == "stacks" then piece.format = escapePercent(pre) .. "%d" .. escapePercent(pending) end
    if piece.kind == "duration" then piece.format = pre .. piece.format .. pending end
    return piece
end

-- The compile in progress, shared by the helpers below rather than threaded through each call.
local out, buffer, run, durationsLeft

--- Close the pending literal text into a piece of its own; an empty one is dropped.
local function flush()
    if buffer ~= "" then append(out, { kind = "literal", text = buffer }) end
    buffer = ""
end

--- One top-level literal: inside an unfinished duration run it is part of the run's format.
local function addLiteral(text)
    if run and durationsLeft > 0 then
        run.format = run.format .. text
    else
        buffer = buffer .. text
    end
end

--- One top-level token.
local function addToken(def)
    if def.kind ~= "duration" then
        flush()
        append(out, tokenPiece(def))
        return
    end
    if not run then
        flush()
        run = tokenPiece(def)
        append(out, run)
    end
    addComponent(run, def)
    durationsLeft = durationsLeft - 1
end

--- The pieces for validated `nodes`.
local function compile(nodes, totalDurations)
    out, buffer, run, durationsLeft = {}, "", nil, totalDurations
    for _, node in ipairs(nodes) do
        if node.t == "lit" then
            addLiteral(node.s)
        elseif node.t == "tok" then
            addToken(node.def)
        else
            flush()
            append(out, groupPiece(node))
        end
    end
    flush()
    local pieces = out
    out, run = nil, nil
    return pieces
end

--- "name|stacks|duration": the piece kinds in order. modules/Style_Text.lua keeps one chain of font
--- strings per shape, so a template edit that keeps the shape re-dresses the same strings.
local function shapeOf(pieces)
    local kinds = {}
    for i, p in ipairs(pieces) do kinds[i] = p.kind end
    return table.concat(kinds, "|")
end

local function hasKind(pieces, kind)
    for _, p in ipairs(pieces) do
        if p.kind == kind then return true end
    end
    return false
end

local cache = {}

--- Compile one template.
--- @param template any  the stored or typed template
--- @return table  { ok = true, pieces, single, shape, hasDuration, hasDispel } or { ok = false, err }
function TT.Compile(template)
    if type(template) ~= "string" then return { ok = false, err = L["Use at least one $token$."] } end
    local hit = cache[template]
    if hit then return hit end
    local result
    local items, lexErr = lex(template)
    local nodes, err = nil, lexErr
    if items then nodes, err = validate(template, items) end
    if nodes then
        local pieces = compile(nodes, countDurations(items))
        local n = #pieces
        result = { ok = true, pieces = pieces, single = n == 1, shape = shapeOf(pieces),
            hasDuration = hasKind(pieces, "duration"), hasDispel = hasKind(pieces, "dispel") }
    else
        result = { ok = false, err = err }
    end
    cache[template] = result
    return result
end

--- Whether `template` compiles: the Text section's `validate` (settings/Text.lua). A refusal answers
--- false and the localized reason, which the write seam hands on to the panel and to `/am set`.
function TT.Validate(template)
    local r = TT.Compile(template)
    if r.ok then return true end
    return false, r.err
end

--- What a STORED template draws: its own compile, or the default template's when the stored one is
--- refused (a hand-edited SavedVariables file, a token a later version removed), and whether it fell
--- back. modules/Style_Text.lua draws with it and settings/Text.lua explains with it, so the page
--- and the element never disagree about the pieces.
--- @return table compiled, boolean fellBack
function TT.ForDraw(template)
    local r = TT.Compile(template)
    if r.ok then return r, false end
    return TT.Compile(NS.CONTAINER_TEMPLATE.text.template), true
end

-- ---------------------------------------------------------------------------
-- 4. The built-in templates (feedback #5)
-- ---------------------------------------------------------------------------

--- The built-in template keys `auraType` offers, in dropdown order (core/Constants.lua's
--- TEXT_BUILTIN_SETS); an aura type with no set of its own offers the buff set.
--- @return table  keys of C.TEXT_BUILTINS
function TT.Builtins(auraType)
    return C.TEXT_BUILTIN_SETS[auraType] or C.TEXT_BUILTIN_SETS.HELPFUL
end

--- The built-in a stored template and justify are, or nil (the Text section reads nil as Custom). A
--- built-in matches when its template is identical and its justify rule holds: the centered one wants
--- Center, every other one anything but Center. First match in `auraType`'s order.
--- @return string|nil  a key of C.TEXT_BUILTINS
function TT.MatchBuiltin(auraType, template, justifyH)
    local centered = justifyH == "CENTER"
    for _, key in ipairs(TT.Builtins(auraType)) do
        local def = C.TEXT_BUILTINS[key]
        if def.template == template and (def.justifyH == "CENTER") == centered then return key end
    end
    return nil
end
