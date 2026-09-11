-- tests/test_docs.lua — the shipped prose is checkable, so it is checked.
--
-- Four rules about text that no code path enforces and no reviewer reliably catches:
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
--      README.md names a file that exists and a range inside it whose first line is not blank. That is
--      mechanical only: whether the cited line still carries the doc's claim stays a reviewer's job.
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
      for path, a, b in line:gmatch("([%w_%./]+%.[lt][uo][ac]):(%d+)%-?(%d*)") do
        if path:match("%.lua$") or path:match("%.toc$") then
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
