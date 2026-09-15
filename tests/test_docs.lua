-- tests/test_docs.lua — the shipped prose is checkable, so it is checked.
--
-- Five rules about text that no code path enforces and no reviewer reliably catches:
--
--   1. Angle-bracket argument placeholders must not appear in README.md. CurseForge's renderer treats
--      `<path>` as an unknown HTML tag and strips it — inside backticks too — so a command that reads
--      correctly on GitHub ships to players with its argument silently deleted (documentation-§1).
--   2. US English is the source dialect for every authored string, comment and doc
--      (localization-§5). The BRITISH and ALLOWED lists below are the section's PUBLISHED lists,
--      copied whole — every entry, no additions — because a private subset is a coverage claim nobody
--      outside this repo can check.
--   3. The Tier 2 rows of docs/ARCHITECTURE.md's `## Documentation map` agree with the disk: a doc
--      filed Present exists, and one filed Not applicable does not (documentation-§3).
--   4. Every `path.lua:N[-M]` or `AuraMaster.toc:N[-M]` citation in docs/*.md, DEPENDENCIES.md and
--      README.md names a file that exists and a range inside it whose first line is not blank.
--   5. Each of those citations still points at what its sentence is about: the sentence names
--      something in backticks, and one of those names sits within CITATION_SLACK lines of the cited
--      range. A table row counts as one sentence, and so does each line of a fenced block, whose
--      every identifier counts as a name. A line that moved under a citation fails here while rule 4
--      still passes. It is a
--      heuristic, not a proof: whether the cited code still does what the prose says stays a
--      reviewer's job.
--
-- Out of scope, named rather than inferred (localization-§5): `libs/` and `tests/_kit/` (vendored),
-- the frozen bundles under `docs/audits/`, `docs/reviews/` and `docs/automated-tests/<run>/`,
-- `docs/test-cases.md` (generated from the suite) and this file (it quotes the words it forbids).

local T = _G.AM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function readFile(path)
  local f = io.open(path, "r")
  assertTrue(f ~= nil, "cannot open " .. path .. " (tests run from the repo root)")
  local body = f:read("*a")
  f:close()
  return body
end

--- Shell glob -> sorted list of paths.
local function glob(pattern)
  local out, p = {}, io.popen("ls -1 " .. pattern .. " 2>/dev/null")
  if not p then return out end
  for line in p:lines() do
    if line ~= "" then
      out[#out + 1] = line
    end
  end
  p:close()
  return out
end

-- ── README: no angle-bracket placeholders ──────────────────────────────────────────────────────

local ALLOWED_TAGS = { br = true }

test("README.md carries no angle-bracket argument placeholders", function()
  local body = readFile("README.md")
  local lineNo, offenders = 0, {}
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    lineNo = lineNo + 1
    for tag in line:gmatch("<([^<>]*)>") do
      if not ALLOWED_TAGS[tag:lower():match("^/?%s*(%a*)") or ""] then
        offenders[#offenders + 1] = "README.md:" .. lineNo .. " <" .. tag .. ">"
      end
    end
  end
  assertEqual(#offenders, 0,
    "CurseForge strips these even inside backticks; write the argument bare -- "
      .. table.concat(offenders, "; "))
end)

-- ── US English across the addon's own files (localization-§5, the canonical lists) ─────────────

-- localization-§5 · US English is the source dialect. Copy BOTH lists whole.
-- BRITISH: lowercase substrings, matched case-insensitively.
-- ALLOWED: correct US words that contain a BRITISH substring; removed as WHOLE WORDS first.
local BRITISH = {
  -- -our → -or
  "colour", "behaviour", "favour", "honour", "neighbour", "armour", "flavour",
  "labour", "rumour", "humour", "endeavour", "rigour", "vigour", "saviour",
  -- -re → -er
  "centre", "centring", "metre", "fibre", "calibre", "theatre", "manoeuvre",
  -- -ce → -se
  "defence", "licence", "offence", "pretence", "practis",
  -- -ise / -isation → -ize / -ization, and the -yse verbs
  "initialis", "normalis", "generalis", "specialis", "optimis", "customis",
  "serialis", "summaris", "utilis", "organis", "authoris", "prioritis",
  "alphabetis", "categoris", "sanitis", "visualis", "minimis", "maximis",
  "itemis", "randomis", "tokenis", "capitalis", "localis", "modularis",
  "standardis", "memois", "recognis", "analys", "paralys", "synthesis",
  "emphasis",
  -- a doubled consonant before a suffix, where US English keeps one
  "cancelled", "cancelling", "cancellable", "labelled", "labelling",
  "travelled", "travelling", "modelled", "modelling", "signalled",
  "signalling", "levelled", "levelling", "fuelled", "fuelling", "totalled",
  "totalling", "fulfil",
  -- -ogue → -og
  "catalogue", "dialogue", "analogue",
  -- no family, just British
  "grey", "artefact", "whilst", "amongst", "learnt", "ageing", "enquir",
  "acknowledgement", "judgement", "sceptic", "mould", "sulphur", "programme",
}

local ALLOWED = {
  "analysis", "analyses", "analyst", "analysts",
  "organism", "organisms", "organist",
  "specialist", "specialists", "generalist", "generalists",
  "optimism", "optimist", "optimists", "optimistic", "optimistically",
  "paralysis", "paralyses", "synthesis", "syntheses", "emphasis", "emphases",
  "fulfill", "fulfills", "fulfilled", "fulfilling", "fulfillment",
  "programmer", "programmers", "programmed",
}

local ALLOWED_SET = {}
for _, w in ipairs(ALLOWED) do ALLOWED_SET[w] = true end

--- Every file this repo authors itself. Frozen bundles sit one level deeper and are not globbed.
local function ownFiles()
  local files = {}
  local function add(list)
    for _, p in ipairs(list) do
      files[#files + 1] = p
    end
  end
  add(glob("*.md"))
  add(glob("*.toc"))
  add(glob("docs/*.md"))
  add(glob("docs/perf-analysis/*.md"))
  add(glob("docs/automated-tests/README.md"))
  add(glob("core/*.lua"))
  add(glob("settings/*.lua"))
  add(glob("modules/*.lua"))
  add(glob("defaults/*.lua"))
  add(glob("locales/*.lua"))
  add(glob("tests/*.lua"))

  local skip = { ["docs/test-cases.md"] = true, ["tests/test_docs.lua"] = true }
  local kept = {}
  for _, p in ipairs(files) do
    if not skip[p] and not p:match("^tests/_kit/") then
      kept[#kept + 1] = p
    end
  end
  return kept
end

--- The British substrings found on one line, after ALLOWED words are removed as WHOLE words.
local function britishOn(line)
  local hits = {}
  local kept = {}
  for word in line:gmatch("%a+") do
    local lw = word:lower()
    if not ALLOWED_SET[lw] then
      kept[#kept + 1] = lw
    end
  end
  local text = " " .. table.concat(kept, " ") .. " "
  for _, sub in ipairs(BRITISH) do
    if text:find(sub, 1, true) then
      hits[#hits + 1] = sub
    end
  end
  return hits
end

test("the addon's own files use US spellings (localization-§5's canonical lists)", function()
  local paths = ownFiles()
  assertTrue(#paths > 20, "the glob found almost nothing (" .. #paths .. ") -- run from the root")

  local offenders, report = 0, {}
  for _, path in ipairs(paths) do
    local lineNo = 0
    for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
      lineNo = lineNo + 1
      for _, sub in ipairs(britishOn(line)) do
        offenders = offenders + 1
        local reported = #report
        if reported < 12 then report[reported + 1] = path .. ":" .. lineNo .. " " .. sub end
      end
    end
  end
  assertEqual(offenders, 0, "en-US is this collection's source dialect: " .. table.concat(report, "; "))
end)

test("the spelling gate is falsifiable: it flags a British word and passes its US twin", function()
  -- red under: emptying BRITISH, or matching ALLOWED as a substring instead of a whole word.
  assertTrue(#britishOn("the bar colour is grey") == 2, "two British spellings must be reported")
  assertEqual(#britishOn("the bar color is gray"), 0, "their US forms must pass")
  assertEqual(#britishOn("an analysis of the cooldown"), 0, "an ALLOWED word must pass")
  assertTrue(#britishOn("it was analysed") == 1, "analysed must not hide behind analysis")
end)

-- ── The Tier 2 documentation map agrees with docs/ ─────────────────────────────────────────────

test("every Tier 2 documentation-map row agrees with docs/", function()
  local body = readFile("docs/ARCHITECTURE.md")
  local section = body:match("### Conditional[^\n]*\n(.-)\n###")
  assertTrue(section ~= nil, "docs/ARCHITECTURE.md has no `### Conditional ... Tier 2` section")

  local rows, offenders = 0, {}
  for doc, status in section:gmatch("|%s*`([^`]+)`%s*|%s*([^|]-)%s*|") do
    if status == "Present" or status == "Not applicable" then
      rows = rows + 1
      local f = io.open("docs/" .. doc, "r")
      local exists = f ~= nil
      if f then f:close() end
      if status == "Present" and not exists then
        offenders[#offenders + 1] = doc .. " is filed Present and does not exist"
      elseif status == "Not applicable" and exists then
        offenders[#offenders + 1] = doc .. " exists and is filed Not applicable"
      end
    end
  end

  assertTrue(rows >= 7, "read only " .. rows .. " Tier 2 rows -- the table shape changed")
  assertEqual(#offenders, 0, "the map and the directory disagree: " .. table.concat(offenders, "; "))
end)

test("every .md under docs/ appears in the documentation map", function()
  local body = readFile("docs/ARCHITECTURE.md")
  local map = body:match("\n## Documentation map\r?\n(.-)\n## ")
  assertTrue(map ~= nil, "docs/ARCHITECTURE.md has no `## Documentation map` section")
  local missing = {}
  local docs = {}
  for _, p in ipairs(glob("docs/*.md")) do
    docs[#docs + 1] = p
  end
  for _, p in ipairs(glob("docs/*/README.md")) do
    docs[#docs + 1] = p
  end
  docs[#docs + 1] = "docs/automated-tests/RESULTS.md"
  for _, p in ipairs(docs) do
    local rel = p:gsub("^docs/", "")
    if rel ~= "ARCHITECTURE.md" and not map:find("`" .. rel .. "`", 1, true) then
      missing[#missing + 1] = rel
    end
  end
  assertEqual(#missing, 0, "docs not registered in the map: " .. table.concat(missing, ", "))
end)

-- ── file:line citations resolve ────────────────────────────────────────────────────────────────

--- The docs whose citations are checked: docs/*.md (not the generated inventory), DEPENDENCIES.md
--- and README.md. Frozen bundles sit one level deeper and are not globbed.
local function citingDocs()
  local docs = {}
  for _, p in ipairs(glob("docs/*.md")) do
    if p ~= "docs/test-cases.md" then
      docs[#docs + 1] = p
    end
  end
  docs[#docs + 1] = "DEPENDENCIES.md"
  docs[#docs + 1] = "README.md"
  return docs
end

--- A source file's lines with CRs stripped, cached per path; false when the file cannot be opened.
local sourceCache = {}
local function sourceLines(path)
  if sourceCache[path] == nil then
    local f = io.open(path, "r")
    local out = false
    if f then
      out = {}
      for l in f:lines() do
        out[#out + 1] = (l:gsub("\r$", ""))
      end
      f:close()
    end
    sourceCache[path] = out
  end
  return sourceCache[path]
end

--- One `path:N` or `path:N-M` citation; `isSource` keeps the .lua and .toc hits.
local CITATION = "([%w_%./]+%.[lt][uo][ac]):(%d+)%-?(%d*)"

local function isSource(path)
  return path:match("%.lua$") ~= nil or path:match("%.toc$") ~= nil
end

--- Why one citation does not resolve, or nil when it does.
local function citationFault(path, first, last)
  local src = sourceLines(path)
  if not src then return "missing file" end
  local count = #src
  if first < 1 or last > count then return "outside the file's " .. count .. " lines" end
  if not src[first]:match("%S") then return "a blank line" end
  return nil
end

test("docs: every file:line citation names an existing file and a non-blank line inside it", function()
  -- red under: citing modules/Container.lua:99999 in any checked doc.
  local checked, offenders = 0, {}
  for _, doc in ipairs(citingDocs()) do
    local lineNo = 0
    for line in (readFile(doc) .. "\n"):gmatch("([^\n]*)\n") do
      lineNo = lineNo + 1
      for path, a, b in line:gmatch(CITATION) do
        if isSource(path) then
          checked = checked + 1
          local first = tonumber(a)
          local fault = citationFault(path, first, tonumber(b ~= "" and b or a))
          if fault then
            offenders[#offenders + 1] = ("%s:%d cites %s:%s%s (%s)"):format(
              doc, lineNo, path, a, b ~= "" and ("-" .. b) or "", fault)
          end
        end
      end
    end
  end
  assertTrue(checked > 50, "matched only " .. checked .. " citations -- the pattern or the glob broke")
  assertEqual(#offenders, 0, "citations that do not resolve: " .. table.concat(offenders, "; "))
end)

-- ── file:line citations still point at what their sentence names ──────────────────────────────

--- How far either side of a cited range a sentence's name may sit. Three absorbs a signature or a
--- comment block above the cited code; wider, and a line that moved can land in range by luck.
local CITATION_SLACK = 3

--- Words that name nothing: a backticked code snippet's keywords would match almost any line.
local LUA_KEYWORDS = {
  ["and"] = true, ["break"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true,
  ["false"] = true, ["for"] = true, ["function"] = true, ["local"] = true, ["nil"] = true,
  ["not"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
  ["until"] = true, ["while"] = true,
}

--- One prose paragraph's sentences, appended to `out`. A sentence ends at a `.`, `;` or `:` followed
--- by space and a capital, backtick, bracket or asterisk, and at a bullet, a numbered item or a table
--- row. A table row is one sentence: its first cell names what the row's citation is about.
local function splitProse(para, out)
  local cut = para
    :gsub("\n(%s*[%-%*] )", "\1%1")
    :gsub("\n(%s*%d+%. )", "\1%1")
    :gsub("\n(%s*|)", "\1%1")
    :gsub("([%.;:])(%s+)([%u`%(%*])", "%1\1%2%3")
  for text in (cut .. "\1"):gmatch("([^\1]*)\1") do
    out[#out + 1] = { text = text }
  end
end

--- A doc's sentences, as `{ text, code }`. Prose sentences never cross a blank line; each line of a
--- fenced block is its own sentence, marked `code` (a diagram names things without backticks).
local function docSentences(doc)
  local out, para, fenced = {}, {}, false
  local function flush()
    if para[1] then splitProse(table.concat(para, "\n"), out) end
    para = {}
  end
  for line in (readFile(doc):gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*```") then
      flush()
      fenced = not fenced
    elseif fenced then
      out[#out + 1] = { text = line, code = true }
    elseif line:match("^%s*$") then
      flush()
    else
      para[#para + 1] = line
    end
  end
  flush()
  return out
end

--- The spans of a sentence that name things: its backticked spans, never one that is itself a path;
--- a code line whole, with its paths and citations cut out.
local function namingSpans(sentence)
  if sentence.code then
    local text = sentence.text
    for _, ext in ipairs({ "lua", "toc", "md" }) do
      text = text:gsub("[%w_%./]+%." .. ext .. "[:%d%-]*", "")
    end
    return { text }
  end
  local spans = {}
  for span in sentence.text:gmatch("`([^`]+)`") do
    if not (span:find("%.lua") or span:find("%.toc") or span:find("%.md")) then
      spans[#spans + 1] = span
    end
  end
  return spans
end

--- The names a sentence gives: identifiers of three or more characters in its naming spans, not Lua
--- keywords and not the cited file's own name.
local function sentenceNames(sentence, citedPath)
  local own = citedPath:match("([^/]+)%.%a+$")
  local names = {}
  for _, span in ipairs(namingSpans(sentence)) do
    for word in span:gmatch("[%a_][%w_]*") do
      local long = word:len() >= 3
      if long and word ~= own and not LUA_KEYWORDS[word] then
        names[#names + 1] = word
      end
    end
  end
  return names
end

--- Why a resolving citation no longer points at what its sentence names, or nil when it does.
local function driftFault(sentence, path, first, last)
  local names = sentenceNames(sentence, path)
  if next(names) == nil then return "its sentence names nothing in backticks" end
  local src = sourceLines(path)
  local lo = math.max(1, first - CITATION_SLACK)
  local count = #src
  local hi = math.min(count, last + CITATION_SLACK)
  for i = lo, hi do
    for _, name in ipairs(names) do
      if src[i]:find("%f[%w_]" .. name .. "%f[^%w_]") then return nil end
    end
  end
  return ("none of `%s` within %d lines"):format(table.concat(names, "`, `"), CITATION_SLACK)
end

test("docs: every file:line citation sits within 3 lines of a name its own sentence gives in backticks", function()
  -- red under: moving docs/schema.md's SCHEMA_STEPS citation back to core/Database.lua:683.
  local checked, offenders = 0, {}
  for _, doc in ipairs(citingDocs()) do
    for _, sentence in ipairs(docSentences(doc)) do
      for path, a, b in sentence.text:gmatch(CITATION) do
        local first, last = tonumber(a), tonumber(b ~= "" and b or a)
        if isSource(path) and not citationFault(path, first, last) then
          checked = checked + 1
          local fault = driftFault(sentence, path, first, last)
          if fault then
            offenders[#offenders + 1] = ("%s cites %s:%s%s (%s)"):format(
              doc, path, a, b ~= "" and ("-" .. b) or "", fault)
          end
        end
      end
    end
  end
  assertTrue(checked > 50, "matched only " .. checked .. " citations -- the pattern or the split broke")
  assertEqual(#offenders, 0, #offenders .. " citations drifted from their sentence:\n  "
    .. table.concat(offenders, "\n  "))
end)
