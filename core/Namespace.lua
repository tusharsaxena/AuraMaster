local addonName, NS = ...

-- Shared namespace bootstrap (architecture-§1). NS is the addon's single private table — the second
-- vararg every TOC-loaded file receives — and there is deliberately no _G[addonName]. Everything the
-- files below publish hangs off this one table.
NS.name = addonName

-- The fallback version. core/EnvSetup.lua's NS.Version() prefers the TOC's `## Version:` field and
-- only answers this when the manifest cannot be read (a headless run, a client with no reader), so
-- a packaged build never reports a constant somebody forgot to edit.
NS.version = "0.1.0"

-- The cyan [AM] chat tag (slash-commands-§4). One constant so every line the addon prints carries
-- the same tag; core/CoreSetup.lua hands it to the library printer as a FUNCTION so a later change
-- is not frozen out at load.
NS.PREFIX = "|cFF00FFFF[AM]|r"
