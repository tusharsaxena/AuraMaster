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
      for _, entry in ipairs(ignore) do shown[#shown + 1] = tostring(entry) end
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
    if widens then off[#off + 1] = name .. " = " .. tostring(value) end
  end
  if #off > 0 then
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
  if #wide > 0 then
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
    if i > start then out[#out + 1] = blob:sub(start, i - 1) end
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
        if path:sub(1, #prefix) == prefix then skip = true break end
      end
      if not skip then paths[#paths + 1] = path end
    end
  end
  if #paths == 0 then
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
  if #bare > 0 then
    fail("bare `-- luacheck: ignore` directives, which silence every code in scope: "
      .. table.concat(bare, ", "), 2)
  end
end)
