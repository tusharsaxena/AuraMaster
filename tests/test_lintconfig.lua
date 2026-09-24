-- tests/test_lintconfig.lua — the "no blanket suppression" gate (lint).
--
-- WHAT IT PROVES: that `luacheck .` reaching 0/0 here is a statement about the code and not about the
-- configuration. Four things are checked, all one rule seen from different sides:
--   1. `.luacheckrc` sets no top-level `ignore` — a top-level ignore reaches every file whatever it
--      names, so it reads as coverage and provides none.
--   2. It switches no warning class off wholesale, which is `ignore` spelled as a switch.
--   3. Every `ignore` it does set sits in a `files[...]` stanza that is narrow — the key names one
--      `.lua` file, or the entry names the variable as well as the code (`212/self`).
--   4. No tracked `.lua` file carries a bare inline `-- luacheck: ignore` with no code after it.
--
-- It loads `.luacheckrc` as Lua under a sandbox rather than scanning it as text, so what it inspects
-- is the table luacheck obeys. It FAILS rather than passes when it cannot look — no config, no
-- io.popen, no git — because a gate that goes quiet when it is blind reports success.
--
-- The last case applies the same rule to the complexity gate: no line may hide code from lizard
-- behind a length operator (see "The complexity gate stays sighted" below).
--
-- The final case holds `read_globals` to names some authored file reads as a global (see
-- "read_globals stays honest" below): a stale entry, worst of all a retired API, would lint clean.

local T = _G.AM_TEST
local test, fail = T.test, T.fail

local CONFIG = ".luacheckrc"

-- The warning classes luacheck lets a config switch off in one word.
local CLASS_SWITCHES = {
  "unused", "unused_args", "unused_secondaries", "self",
  "redefined", "global", "allow_defined", "allow_defined_top", "module",
}

--- The parsed `.luacheckrc` as the table of globals it assigns. The sandbox auto-vivifies on read so
--- `files["tests/"] = { ... }` works without a preceding `files = {}`, as luacheck's loader does.
local function loadConfig()
  local fh = io.open(CONFIG, "r")
  if not fh then
    fail("lint config gate: " .. CONFIG .. " could not be opened, so this gate cannot run and must "
      .. "not be reported as passing", 2)
  end
  local text = fh:read("*a")
  fh:close()
  if not text or text == "" then
    fail("lint config gate: " .. CONFIG .. " read as empty; this gate cannot run", 2)
  end

  local env = setmetatable({}, {
    __index = function(t, key)
      local made = {}
      rawset(t, key, made)
      return made
    end,
  })

  local chunk, err = loadstring(text, "@" .. CONFIG)
  if not chunk then
    fail("lint config gate: " .. CONFIG .. " does not compile as Lua (" .. tostring(err) .. ")", 2)
  end
  setfenv(chunk, env)
  local ok, runErr = pcall(chunk)
  if not ok then
    fail("lint config gate: " .. CONFIG .. " errored while loading (" .. tostring(runErr) .. ")", 2)
  end
  return env
end

local function fileStanzas(env)
  local out = {}
  local files = rawget(env, "files")
  if type(files) ~= "table" then return out end
  for key, options in pairs(files) do
    if type(key) == "string" and type(options) == "table" then
      out[#out + 1] = { key = key, options = options }
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

test("lintconfig: .luacheckrc sets no top-level ignore", function()
  local env = loadConfig()
  local ignore = rawget(env, "ignore")
  if ignore ~= nil then
    local shown = {}
    if type(ignore) == "table" then
      for _, entry in ipairs(ignore) do
        shown[#shown + 1] = tostring(entry)
      end
    else
      shown[1] = tostring(ignore)
    end
    fail(".luacheckrc sets a top-level `ignore` of { " .. table.concat(shown, ", ") .. " }. Move each "
      .. "code into a `files[...]` stanza naming the file that earns it, or put a "
      .. "`-- luacheck: ignore <code>` beside the single line that needs it", 2)
  end
end)

test("lintconfig: .luacheckrc switches no warning class off wholesale", function()
  local env = loadConfig()
  local off = {}
  for _, name in ipairs(CLASS_SWITCHES) do
    local value = rawget(env, name)
    -- `allow_defined*` and `module` widen by being true; the rest widen by being false.
    local widens = (name:find("^allow_defined") or name == "module") and value == true
      or (not name:find("^allow_defined") and name ~= "module") and value == false
    if widens then
      off[#off + 1] = name .. " = " .. tostring(value)
    end
  end
  if off[1] then
    fail(".luacheckrc turns a whole warning class off at the top level: " .. table.concat(off, ", "), 2)
  end
end)

test("lintconfig: every files[...] ignore is narrowed to a file or a name", function()
  local env = loadConfig()
  local wide = {}
  for _, stanza in ipairs(fileStanzas(env)) do
    local ignore = rawget(stanza.options, "ignore")
    if type(ignore) == "table" then
      local keyIsOneFile = stanza.key:find("%.lua$") ~= nil
      for _, entry in ipairs(ignore) do
        local text = tostring(entry)
        if not keyIsOneFile and not text:find("/") then
          wide[#wide + 1] = "files[\"" .. stanza.key .. "\"].ignore = " .. text
        end
      end
    end
  end
  if wide[1] then
    fail("luacheck suppressions that cover a whole directory with no name to narrow them: "
      .. table.concat(wide, ", "), 2)
  end
end)

--- Split a NUL-delimited blob (`git ls-files -z`, so a path containing anything but NUL survives).
local function splitNul(blob)
  local out, start = {}, 1
  while true do
    local i = blob:find("\0", start, true)
    if not i then break end
    if i > start then
      out[#out + 1] = blob:sub(start, i - 1)
    end
    start = i + 1
  end
  return out
end

-- Vendored trees are not ours to annotate, and this file quotes the forbidden directive to forbid it.
local SKIPPED_PREFIXES = { "libs/", "tests/_kit/" }
local SKIPPED_FILES = { ["tests/test_lintconfig.lua"] = true }

local function trackedLua()
  if not io.popen then
    fail("lint config gate: io.popen is unavailable, so the tracked set cannot be read", 2)
  end
  local pipe = io.popen("git ls-files -z '*.lua'")
  if not pipe then
    fail("lint config gate: io.popen returned no handle for `git ls-files`", 2)
  end
  local blob = pipe:read("*a") or ""
  pipe:close()

  local paths = {}
  for _, path in ipairs(splitNul(blob)) do
    if not SKIPPED_FILES[path] then
      local skip = false
      for _, prefix in ipairs(SKIPPED_PREFIXES) do
        if path:find(prefix, 1, true) == 1 then skip = true break end
      end
      if not skip then
        paths[#paths + 1] = path
      end
    end
  end
  if not paths[1] then
    fail("lint config gate: `git ls-files` reported no Lua files, which cannot be true here — git is "
      .. "unavailable or nothing is staged; this gate cannot run", 2)
  end
  return paths
end

test("lintconfig: no source file carries a bare inline luacheck ignore", function()
  local bare = {}
  for _, path in ipairs(trackedLua()) do
    local fh = io.open(path, "r")
    if not fh then
      fail("lint config gate: git tracks " .. path .. " but it could not be opened", 2)
    end
    local lineNo = 0
    for line in fh:lines() do
      lineNo = lineNo + 1
      local tail = line:match("%-%-%s*luacheck:%s*ignore(.*)$")
      if tail and tail:match("^%s*\r?$") then
        bare[#bare + 1] = path .. ":" .. lineNo
      end
    end
    fh:close()
  end
  if bare[1] then
    fail("bare `-- luacheck: ignore` directives, which silence every code in scope: "
      .. table.concat(bare, ", "), 2)
  end
end)

-- ── The complexity gate stays sighted ────────────────────────────────────────────────────────────
-- lizard's shared tokenizer reads a `#` outside a string as the start of a C preprocessor line and
-- swallows everything after it up to the newline. In Lua `#` is the length operator, so a keyword or
-- brace after it on the same line never reaches lizard's Lua reader: an `end` there unbalances the
-- block count and every later function in the file goes unmeasured, and an `and`/`or` there
-- undercounts CCN. The `-C 15` gate is then silent because it is blind, not because it passed.

local LIZARD_WORDS = {}
for w in ("and or not then do end function if elseif else for while repeat until return local in break"):gmatch("%a+") do
  LIZARD_WORDS[w] = true
end

--- One source line with its string contents blanked and any trailing `--` comment removed.
local function codeOf(line)
  local out, i, n = {}, 1, #line
  while i <= n do
    local ch = line:sub(i, i)
    if ch == "-" and line:sub(i + 1, i + 1) == "-" then break end
    if ch == '"' or ch == "'" then
      local j = i + 1
      while j <= n and line:sub(j, j) ~= ch do
        if line:sub(j, j) == "\\" then j = j + 1 end
        j = j + 1
      end
      out[#out + 1] = ch .. ch
      i = j + 1
    else
      out[#out + 1] = ch
      i = i + 1
    end
  end
  return table.concat(out)
end

--- Does a length operator on this line have a keyword, or an unbalanced brace, after it? A balanced
--- `{ ... }` is swallowed whole and changes nothing; an opening or a closing brace alone does.
local function lengthHazard(line)
  local code = codeOf(line)
  local at = code:find("#", 1, true)
  if not at then return false end
  local rest = code:sub(at + 1)
  local _, opens = rest:gsub("{", "")
  local _, closes = rest:gsub("}", "")
  if opens ~= closes then return true end
  for word in rest:gmatch("[%a_][%w_]*") do
    if LIZARD_WORDS[word] then return true end
  end
  return false
end

test("lintconfig: no length operator shares its line with a keyword or brace lizard must see", function()
  -- red under: writing `for _, id in ipairs(orphans) do order[#order + 1] = id end` back on one line in core/Database.lua
  if not (lengthHazard("for _, x in ipairs(t) do o[#o + 1] = x end") and lengthHazard("if #t > 0 and ok then")
      and lengthHazard("o[#o + 1] = {") and not lengthHazard("o[#o + 1] = { k = 1 }")
      and not lengthHazard("local n = #t") and not lengthHazard('if s:find("#") then return end')
      and not lengthHazard("o[#o + 1] = x -- then end")) then
    fail("complexity gate: the length-operator scanner itself is wrong", 2)
  end
  local paths = trackedLua()
  paths[#paths + 1] = "tests/test_lintconfig.lua"
  local hits = {}
  for _, path in ipairs(paths) do
    local lineNo = 0
    for line in io.lines(path) do
      lineNo = lineNo + 1
      if lengthHazard(line) then
        hits[#hits + 1] = path .. ":" .. lineNo
      end
    end
  end
  if hits[1] then
    fail(#hits .. " line(s) hide code from lizard behind a `#`; move what follows the length onto its own "
      .. "line or into a local: " .. table.concat(hits, ", "), 2)
  end
end)

-- ── read_globals stays honest ────────────────────────────────────────────────────────────────────
-- A read_globals entry is a promise that some authored file reads that client global. An entry
-- nothing reads is not harmless: declaring a retired global (GetSpellInfo, anti-pattern #10) lets a
-- regression back to it lint clean.

local AUTHORED_PREFIXES = { "core/", "modules/", "settings/", "defaults/", "locales/" }

--- The authored files a read_globals name may be read from: the addon's source trees and the test
--- tree's own top-level .lua files (never tests/_kit/, which is the library's).
local function authoredLua()
  local out = {}
  for _, path in ipairs(trackedLua()) do
    local keep = path:find("^tests/[^/]+%.lua$") ~= nil
    for _, prefix in ipairs(AUTHORED_PREFIXES) do
      if path:find(prefix, 1, true) == 1 then keep = true end
    end
    if keep then
      out[#out + 1] = path
    end
  end
  out[#out + 1] = "tests/test_lintconfig.lua"
  return out
end

--- Does this line's code (strings blanked, trailing comment gone) read `name` as a bare global —
--- not as a `.field` or a `:method`, not as part of a longer identifier, and not as the key of a
--- `name = value` table field (a mock's `{ GetSpellInfo = function ... }` reads nothing).
local function readsGlobal(code, name)
  local padded = " " .. code .. " "
  local start = 1
  while true do
    local i, j = padded:find(name, start, true)
    if not i then return false end
    local before, after = padded:sub(i - 1, i - 1), padded:sub(j + 1, j + 1)
    local isKey = padded:find("^%s*=[^=]", j + 1) ~= nil
    if not before:find("[%w_%.:]") and not after:find("[%w_]") and not isKey then return true end
    start = j + 1
  end
end

-- The scanner's own cases: { line, name, is it a global read? }.
local READS_GLOBAL_CASES = {
  { "local t = GetTime()", "GetTime", true },
  { "if GetTime() == t then", "GetTime", true },
  { "NS.Compat.GetSpellInfo(id)", "GetSpellInfo", false },
  { "C_AddOns:GetAddOnMetadata(x)", "GetAddOnMetadata", false },
  { "local x = C_Timer2", "C_Timer", false },
  { "m.C_AddOns = { GetAddOnMetadata = f }", "GetAddOnMetadata", false },
  { 'f("GameTooltip")', "GameTooltip", false },
  { "x = 1 -- GetSpellInfo is retired", "GetSpellInfo", false },
}

test("lintconfig: every read_globals name is referenced as a global by some authored file", function()
  -- red under: the four stale entries (GameTooltip, C_Spell, GetAddOnMetadata, GetSpellInfo)
  for _, case in ipairs(READS_GLOBAL_CASES) do
    if readsGlobal(codeOf(case[1]), case[2]) ~= case[3] then
      fail("read_globals gate: the global-reference scanner itself is wrong on `" .. case[1] .. "`", 2)
    end
  end
  local declared = rawget(loadConfig(), "read_globals")
  if type(declared) ~= "table" or not declared[1] then
    fail("read_globals gate: .luacheckrc declares no read_globals list, so this gate cannot run", 2)
  end
  local unread = {}
  for _, name in ipairs(declared) do unread[name] = true end
  for _, path in ipairs(authoredLua()) do
    for line in io.lines(path) do
      local code = codeOf(line)
      for name in pairs(unread) do
        if readsGlobal(code, name) then unread[name] = nil end
      end
    end
  end
  local stale = {}
  for name in pairs(unread) do
    stale[#stale + 1] = name
  end
  table.sort(stale)
  if stale[1] then
    fail(".luacheckrc read_globals declares names no authored file reads as a global; take them off "
      .. "the list: " .. table.concat(stale, ", "), 2)
  end
end)
