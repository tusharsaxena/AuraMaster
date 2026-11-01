local addonName, NS = ...

-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§1, §2, §3).
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("AuraMaster")`: the painting vocabulary
--                           (Shell, Text, Divider, ...) and Token / Color / Resolve / OnLooksChanged.
--                           Every surface that draws reads its colors here.
--   NS.SKIN_TOKENS          this addon's OWN tokens (skinning-§1, LibKa0s Skin minor 7): the colors
--                           it draws that no library token holds exactly, each with its Ka0s Default
--                           value (today's pixel) and the library ROLE token every other skin draws
--                           it from. Handed to RegisterOwner, and answered by the degraded facade.
--   NS.SKIN_FALLBACK        the host copy of the library's Ka0s Default tokens the degraded facade
--                           answers, limited to the ones this addon reads. A surface converted to a
--                           library token adds it here in the same change.
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.GetSetting; "ka0s",
--                           "ka0s" before NS:InitDB has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.SetByPath, the one seam
--                           `/am set` and the panel already write through (architecture-§5); `i`, the
--                           Scope's `{ panel, fonts }`, writes the two exceptions, and `m`, the Font and
--                           texture section's `{ font, texture, outline }`, the two overrides ("" for
--                           false) and, when its `outline` is not nil, skin.outline.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before NS:InitDB.
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions (`Skin:SetIgnore`), live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.ApplySkinOverride(f,t) moves the applied overrides (`Skin:SetOverride`), live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.SkinOutline()        the stored font outline mode, "all", "hud" or "off" (LibKa0s v1.82.0, Skin
--                           minor 9, ruling D-06); "hud" before NS:InitDB (LibKa0s v1.83.0, D-10).
--   NS.ApplySkinOutline(m)  moves the applied font outline (`Skin:SetOutline`), live; no argument
--                           applies the stored skin.outline.
--   NS.SKIN_OUTLINE_OPTIONS the outline row's values: "all", "hud", "off", the library's order.
--   NS.RunSkinVerb()        `/am skin` (ruling D-16): O.SkinVerb with NS.SkinPickerSpec(), the picker a
--                           new profile shows whatever skin.pickerSeen says; the library-absent line
--                           on nil, "absent".
--   NS.ApplySkinChoice(s,k) moves the applied skin (`Skin:SetChoice`: resolve, repaint every frame
--                           recorded for this owner, THEN fire OnLooksChanged). No argument applies the
--                           stored pair and with it the stored exceptions, overrides and outline
--                           (addon:OnInitialize, the three profile callbacks); a nil half keeps that
--                           half (each skin row's onChange).
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/General.lua reads both.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque), so
--                           a literal that became a token keeps its arity on Ka0s Default.
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cff888888).
--   NS.PanelEscape(name)    the same for a settings page's markup, Ka0s Default's bytes while the
--                           owner ignores its settings panel (D-03), so a page never mixes the two.
--   NS.PanelTipLine()       r, g, b of a tooltip line a settings page writes: `gtip.line`, or nothing
--                           while the owner ignores its settings panel.
--   NS.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this owner:
--   NS.SkinPaintAceTree(c)  `Skin:PaintAce` / `Skin:PaintAceTree` with the owner bound (the facade
--                           carries neither). Nothing while the owner ignores its settings panel;
--                           release restores stock.
--   NS.SkinOnRelease(w, fn) host release work chained onto the widget's own OnRelease
--                           (`Skin:OnRelease`), so it and the skin's restore both run.
--   NS.MaybeShowSkinPicker() the first-run skin picker (LibKa0s OptionsSkinPicker 1, owner ruling
--                           O3): `O.SkinPicker` while the profile's `skin.pickerSeen` is false and
--                           the addon stands up; held to PLAYER_REGEN_ENABLED in combat. Answers the
--                           frame, or nil, "queued" behind another Ka0s addon's picker.
--   NS.HideSkinPicker()     takes a shown picker down (its pending preview put back) or out of the
--                           queue WITHOUT marking it seen: the stand-down, a profile that has seen
--                           it, and first on every profile event; drops a held combat deferral.
--   NS.SkinPickerSpec()     the spec MaybeShowSkinPicker hands O.SkinPicker.
--   NS.SkinPickerDue()      true while this profile has not closed the picker and the addon stands
--                           up: what MaybeShowSkinPicker asks, and whether the login arms its timer.
--   NS.SkinDegraded         true on the degraded arm alone: no skin to follow, so stored values draw.
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua (NS.Print, for the reload line) and before core/Bus.lua and every module
-- that builds a frame, so NS.Skin exists for all of them; settings/General.lua reads NS.SKIN_OPTIONS
-- at file load and is far below. The owner registers at FILE LOAD (skinning-§1), never at
-- PLAYER_LOGIN, so the EllesmereUI provider can offer it before EllesmereUI dispatches its skins.
-- Nothing here reads the profile at load: RegisterOwner calls `get` once, before AceDB exists, and
-- it answers Ka0s Default; the profile's pair is applied by NS.ApplySkinChoice right after NS:InitDB
-- (core/AuraMaster.lua).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never picked.
-- Applying only the row's own half against the applied choice makes each write a no-op (SetChoice is
-- idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/am set skin.skin obsidian` still repaints.
--
-- Nothing skin-related keys off CONFIG_CHANGED: the rows carry `effect = "none"`, so no container
-- re-applies for a skin write. A surface that has to redraw on a skin change subscribes to
-- NS.Skin.OnLooksChanged, which fires after the new skin is resolved and the recorded frames are
-- repainted.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local OUTLINE_PATH, OUTLINE_DEFAULT = "skin.outline", "hud"
local DEFAULT = "ka0s"
local BRAND = "Ka0s Aura Master"

--- A "|cffrrggbb" byte as the channel value the escape always drew, so a token's default rounds
--- back to the same byte (NS.SkinEscape) and nothing on Ka0s Default moves.
local function byte(n) return n / 255 end

--- core/Constants.lua's "aarrggbb" escape body as a token's default.
local function hex(s)
    return { tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, tonumber(s:sub(7, 8), 16) / 255, 1 }
end
local C = NS.Constants

-- THE OWNER TOKENS (skinning-§1; LK-01 of Ka0sAddonsCommonTasks docs/2026-10-29-SKINNING_ROLLOUT,
-- decisions X1, X2 and X12). Each is a color AuraMaster draws today whose exact value no library
-- token holds, so snapping it to the nearest one would move a Ka0s Default pixel. The name is in
-- this addon's own namespace (`am.`), never a library family; `default` is the value drawn today,
-- exactly; `follow` is the nearest library ROLE token, whose value every other skin and EllesmereUI
-- draw it in. The gap each meets is the inventory's (that bundle's inputs/inventory/AuraMaster.md §5).
NS.SKIN_TOKENS = {
    -- AM-G2: the drag strip's name of an attached container, a warm gray: the strip's gold with the
    -- color drained out, so at a glance it reads as attached (the owner, 2026-09-26).
    ["am.attachedName"] = { default = { byte(0x8c), byte(0x8a), byte(0x84), 1 }, follow = "text.muted" },
    -- AM-G4: the drag-to-attach marks, a go/no-go pair (modules/Anchors_Snap.lua's Snap.COLOR), opaque
    -- so they read over any bar or icon color.
    ["am.attach"]       = { default = { 0.25, 0.90, 0.35, 1 }, follow = "sem.good" },
    ["am.detach"]       = { default = { 0.95, 0.25, 0.25, 1 }, follow = "sem.bad" },
    -- AM-G5: the frame picker's outline (modules/FramePicker.lua).
    ["am.pick"]         = { default = { 0.2, 0.8, 1, 1 }, follow = "sem.info" },
    -- AM-G6: a container page's plan-warning lines (|cffffa040).
    ["am.planWarn"]     = { default = { byte(0xff), byte(0xa0), byte(0x40), 1 }, follow = "sem.warn" },
    -- AM-G7: the settings grays, the container picker's suffix (|cff888888) and the Filters
    -- section's "(info)" (|cffbbbbbb).
    ["am.note"]         = { default = { byte(0x88), byte(0x88), byte(0x88), 1 }, follow = "text.muted" },
    ["am.noteAlt"]      = { default = { byte(0xbb), byte(0xbb), byte(0xbb), 1 }, follow = "text.muted" },
    -- AM-G8: the panel's secondary gold (batch 10 F6), the growth note and the "yours" marker: the
    -- drag handle's gold dimmed toward its help mark.
    ["am.goldMuted"]    = { default = { byte(0xd9), byte(0xb8), byte(0x61), 1 }, follow = "text.headingAlt" },
    -- AM-G9: the Filters section's in-panel "See spells" link (|cff6699ff).
    ["am.link"]         = { default = { byte(0x66), byte(0x99), byte(0xff), 1 }, follow = "text.accent" },
    -- FS-AM-FLIP: an icon border's 1 px and the text glow's black ring, which Ka0s Default's own
    -- `icon.borderSize` (2) and `glow.color` (gold) are not. Every other skin draws those tokens.
    ["am.iconBorderSize"] = { default = 1, follow = "icon.borderSize" },
    ["am.textGlow"]     = { default = { 0, 0, 0, 1 }, follow = "glow.color" },
    -- FS-AM-FIX (cause L5): the General page's Unit, Aura type and Style values. Each stays apart from
    -- its neighbors in a dropdown, so each follows a different role; the aura types keep good and bad.
    ["am.unitPlayer"]   = { default = hex(C.UNIT_COLORS.player), follow = "sem.info" },
    ["am.unitTarget"]   = { default = hex(C.UNIT_COLORS.target), follow = "sem.warn" },
    ["am.unitFocus"]    = { default = hex(C.UNIT_COLORS.focus), follow = "text.accent" },
    ["am.unitPet"]      = { default = hex(C.UNIT_COLORS.pet), follow = "sem.good" },
    ["am.auraHelpful"]  = { default = hex(C.AURA_TYPE_COLORS.HELPFUL), follow = "sem.good" },
    ["am.auraHarmful"]  = { default = hex(C.AURA_TYPE_COLORS.HARMFUL), follow = "sem.bad" },
    ["am.styleBars"]    = { default = hex(C.STYLE_COLORS.bars), follow = "sem.warn" },
    ["am.styleIcons"]   = { default = hex(C.STYLE_COLORS.icons), follow = "sem.info" },
    ["am.styleText"]    = { default = hex(C.STYLE_COLORS.text), follow = "text.accent" },
}

-- The Ka0s Default tokens the DEGRADED facade answers, copied from the library and limited to the
-- ones this addon reads. Both arms publish the table, so tests/test_skinsetup.lua can hold each
-- entry to the live library's Ka0s Default value: a copy that drifts goes red there. Each surface
-- converted to a library token adds it here in the same change.
NS.SKIN_FALLBACK = {
    -- AM-02, the unlock furniture: the drag strip's own edge (the host painter draws it), the strip
    -- and close-mark tooltips' title and body lines, the TEST tag, the unlocked outline, and the
    -- frame picker's name and hint.
    ["handle.edge"]     = { 1, 0.82, 0, 0.6 },
    ["gtip.title"]      = { 1, 0.82, 0, 1 },
    ["gtip.value"]      = { 1, 1, 1, 1 },
    ["sem.warn"]        = { 1, 0.5, 0, 1 },
    ["chart.crosshair"] = { 1, 1, 1, 0.35 },
    ["text.accent"]     = { 1, 0.82, 0, 1 },
    ["cover.text"]      = { 0.667, 0.667, 0.667, 1 },
    -- AM-02, the settings pages' markup: the muted notes and the gold emphasis.
    ["text.disabled"]   = { 0.5, 0.5, 0.5, 1 },
    ["text.heading"]    = { 1, 0.82, 0, 1 },
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (1/3 is 55,
--- .5 is 80), so markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a
--- token the skin leaves alone.
local function escape(r, g, b)
    local function toByte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(toByte(r), toByte(g), toByte(b))
end

function NS.SkinEscape(name)
    local r, g, b = NS.Skin.Color(name)
    if r == nil then return nil end
    return escape(r, g, b)
end

--- NS.SkinEscape for markup on a SETTINGS PAGE (Ka0sAddonsCommonTasks
--- docs/2026-10-30-SKIN_LIBRARY_FOLLOWUPS, decision D-03): while the owner ignores its settings
--- panel (`Skin:GetIgnore`, the public half) the page around it is stock, so the markup draws Ka0s
--- Default's bytes, the ones it wrote before skins, under any skin; otherwise the skin's escape. The
--- Ka0s Default value is the owner token's `default` or the host copy's (NS.SKIN_FALLBACK, held to
--- the library by tests/test_surface_parity.lua). Windows and the HUD keep NS.SkinEscape (D-01).
function NS.PanelEscape(name)
    if Skin and type(Skin.GetIgnore) == "function" and Skin:GetIgnore(addonName) == true then
        local own = NS.SKIN_TOKENS[name]
        local c = own and own.default or NS.SKIN_FALLBACK[name]
        if c then return escape(c[1], c[2], c[3]) end
    end
    return NS.SkinEscape(name)
end

--- The r, g, b of a line this addon writes on GameTooltip from a settings page (skinning-§7, cause
--- L2): `gtip.line`, or nothing, the client's own line color, while the owner ignores its panel or the
--- skin leaves the token alone. The library's own rows read the same token.
function NS.PanelTipLine()
    if Skin and type(Skin.GetIgnore) == "function" and Skin:GetIgnore(addonName) == true then return nil end
    return NS.SkinColor("gtip.line")
end

-- The font outline modes (LibKa0s-Skin-1.0 minor 9's OUTLINE_MODES, in its order), with the Skin
-- tab's words. settings/Schema.lua's skin.outline row validates `/am set` against them.
NS.SKIN_OUTLINE_OPTIONS = {
    { value = "all", text = "All text" },
    { value = "hud", text = "HUD text only" },
    { value = "off", text = "Off" },
}

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    if not (NS.db and NS.GetSetting) then return DEFAULT, DEFAULT end
    return NS.GetSetting(SOURCE_PATH) or DEFAULT, NS.GetSetting(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through NS.SetByPath (validate, store, the [Set] line, onChange).
--- `media` is `{ font = key|false, texture = key|false, outline = mode|nil }`: the Skin tab's Font
--- and texture pick, its Font outline (LibKa0s v1.82.0) and another addon's copy all hand it here,
--- after Skin:SetOverride / Skin:SetOutline moved the applied state, so each row's onChange
--- re-applies its own half as a no-op. A nil `outline` leaves skin.outline alone.
function NS.WriteSkinChoice(source, skin, ignore, media)
    if not (NS.db and NS.SetByPath) then return end
    if source ~= nil then NS.SetByPath(SOURCE_PATH, source) end
    if skin ~= nil then NS.SetByPath(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        NS.SetByPath(PANEL_PATH, ignore.panel == true)
        NS.SetByPath(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        NS.SetByPath(FONT_PATH, storedKey(media.font))
        NS.SetByPath(TEXTURE_PATH, storedKey(media.texture))
        if media.outline ~= nil then NS.SetByPath(OUTLINE_PATH, media.outline) end
    end
end

--- The stored font outline mode, nil-safely: "hud" until the profile store exists.
function NS.SkinOutline()
    if not (NS.db and NS.GetSetting) then return OUTLINE_DEFAULT end
    return NS.GetSetting(OUTLINE_PATH) or OUTLINE_DEFAULT
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
    if not (NS.db and NS.GetSetting) then return false, false end
    local font, texture = storedKey(NS.GetSetting(FONT_PATH)), storedKey(NS.GetSetting(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: false, false until the profile store exists.
local function storedIgnore()
    if not (NS.db and NS.GetSetting) then return false, false end
    return NS.GetSetting(PANEL_PATH) == true, NS.GetSetting(FONTS_PATH) == true
end

-- ── the first-run skin picker (LibKa0s OptionsSkinPicker 1, LibKa0s#64; owner ruling O3) ──────
--
-- WHEN. Once per session, two seconds after the first world entry (addon:OnEnterWorld, an event
-- registered only while the addon stands up), after OnInitialize applied the stored skin; and again
-- after every profile event (core/AuraMaster.lua's rebuildProfile), because a new, copied or reset
-- profile carries its own `pickerSeen`. Never while the addon stands down (the stand-down takes it
-- down, core/LifecycleSetup.lua), and never in combat: a start in combat is held for the
-- PLAYER_REGEN_ENABLED edge, one target at most.
--
-- SEEN. The library calls `onClose` once per showing, by any route the player takes (Apply, its
-- close control, the gear, Escape), and once for a picker still queued behind another Ka0s addon's
-- when that addon's "Apply to all Ka0s addons" dismisses it unshown; that is the one write of
-- `skin.pickerSeen`, through NS.SetByPath. A close this addon makes itself (NS.HideSkinPicker: the
-- stand-down, a profile event) is not the player's and writes nothing.
--
-- PREVIEW. A pick only previews (the Skin major moves and this addon repaints); `set`
-- (NS.WriteSkinChoice) runs only on Apply, the gear or Apply to all, and the close control and
-- Escape put back the stored choice as `get` reads it at the close. The eye (X6: AuraMaster has a
-- test mode to preview in) starts test mode, so the player sees the skin on the containers'
-- placeholders; the library raises its DIALOG window after onPreview returns.
--
-- QUEUED. One picker is up at a time across every Ka0s addon: while another addon's is up,
-- O.SkinPicker queues this one and answers nil, "queued", which NS.MaybeShowSkinPicker passes
-- through; it shows when the other closes.

local PICKER_PATH = "skin.pickerSeen"
local pickerTarget       -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held
local quietClose = false -- true while NS.HideSkinPicker takes the picker down

--- The eye: test mode on, so every container draws its placeholders in the previewed skin. A mode
--- already on needs nothing; a refused start (combat) prints its own line.
local function previewSkin()
    local P = NS.Preview
    if not (P and P.SetTestMode) then return end
    if not (NS.State and NS.State.testMode) then P.SetTestMode(true, "skin picker") end
end

--- The player's close: the picker seen, and nothing else. The library's put-back already wears the
--- stored choice, so the skin is not this callback's to move.
local function pickerClosed()
    if quietClose then return end
    if not (NS.db and NS.SetByPath) then return end
    NS.SetByPath(PICKER_PATH, true)
end

--- The spec NS.MaybeShowSkinPicker hands O.SkinPicker. The gear's default opens General
--- (O.OpenOptionsPanel("general")) on its Skin tab (O.SelectTab("general", "Appearance"), the key
--- settings/General.lua gives O.AppearanceTab).
function NS.SkinPickerSpec()
    return {
        owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice,
        page = "general", tab = "Appearance",
        onPreview = previewSkin, onClose = pickerClosed,
    }
end

--- `/am skin` (LibKa0s v1.82.0, OptionsSkinPicker minor 3's O.SkinVerb, ruling D-16): the picker a
--- new profile shows, whatever skin.pickerSeen says. The library prints its own lines (combat on
--- every call, queued, unavailable); without LibKa0s the stub answers nil, "absent" and this prints
--- the library-absent line. The dispatcher refuses the verb while the addon is disabled. Answers
--- the picker's frame, or nil and the reason.
function NS.RunSkinVerb()
    local O = NS.Helpers
    local verb = O and type(O.SkinVerb) == "function" and O.SkinVerb or nil
    local win, why
    if verb then win, why = verb(NS.SkinPickerSpec()) else why = "absent" end
    if win == nil and why == "absent" and NS.Printf then
        NS.Printf(NS.L["%s is unavailable: the LibKa0s library did not load."], "/am skin")
    end
    return win, why
end

local function dropPickerDeferral()
    if pickerTarget then pickerTarget:UnregisterAllEvents(); pickerTarget = nil end
end

--- True while this profile has not closed the picker and the addon stands up.
local function pickerDue()
    if not (NS.db and NS.GetSetting) then return false end
    if NS.IsStoodDown and NS.IsStoodDown() then return false end
    return NS.GetSetting(PICKER_PATH) == false
end
NS.SkinPickerDue = pickerDue

--- Take a shown picker down (its pending preview put back) or out of the queue WITHOUT marking it
--- seen, and drop a held combat start: the stand-down, a profile that has seen it, and first on
--- every profile event.
function NS.HideSkinPicker()
    dropPickerDeferral()
    local O = NS.Helpers
    if not (O and type(O.HideSkinPicker) == "function") then return end
    quietClose = true
    local ok, err = pcall(O.HideSkinPicker)
    quietClose = false
    if not ok then error(err, 0) end
end

--- Show the picker when this profile has not seen it: answers O.SkinPicker's frame, or nil, "queued"
--- while another Ka0s addon's picker is up (it shows when that one closes), or nil.
function NS.MaybeShowSkinPicker()
    local O = NS.Helpers
    if not (O and type(O.SkinPicker) == "function") then return nil end
    if not pickerDue() then
        NS.HideSkinPicker()
        return nil
    end
    if InCombatLockdown() then
        if pickerTarget then return nil end
        pickerTarget = NS.NewBusTarget and NS.NewBusTarget()
        if not pickerTarget then return nil end
        NS.SafeRegisterEvent(pickerTarget, "PLAYER_REGEN_ENABLED", function()
            dropPickerDeferral()
            NS.MaybeShowSkinPicker()
        end, NS.RejectedEvents)
        return nil
    end
    return O.SkinPicker(NS.SkinPickerSpec())
end

-- AceGUI keeps ONE callback per event name (options-ui-§19). Without the library's chain there is
-- no skin restore to share the release with, so the host's work takes the callback.
local function releaseByCallback(widget, fn)
    if type(widget) ~= "table" or type(fn) ~= "function" or type(widget.SetCallback) ~= "function" then
        return nil
    end
    widget:SetCallback("OnRelease", function(w) fn(w) end)
    return fn
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function color(name)
        local c = NS.SKIN_FALLBACK[name]
        if not c then
            local own = NS.SKIN_TOKENS[name]
            c = own and own.default
        end
        if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises: AuraMaster has no window of its own, so without the library nothing is shelled. The
    -- list is LibKa0s-Skin-1.0's VOCAB; tests/test_skinsetup.lua holds this table to the live facade
    -- key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture", "FontFlags", "HudFontSize", "Mark",
        -- LibKa0s v1.85.0: nil is each getter's degraded answer. The three colors answer nothing, so
        -- the stored color draws; HudShadow's nil is "the stored fontShadow stands". BarGloss draws
        -- nothing: no skin, no gloss.
        "HudTextColor", "HudLabelColor", "BarFillColor", "HudShadow", "BarGloss", "HoverArt",
    }) do S[name] = noop end

    S.Token = function(name)
        local c = NS.SKIN_FALLBACK[name]
        if c ~= nil then return c end
        local own = NS.SKIN_TOKENS[name]
        return own and own.default
    end
    S.Color = color
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end
    -- A string in a color role or token: the one the host copy holds, on the string itself.
    S.Text = function(fs, role)
        local r, g, b, a = color(role)
        if r == nil then r, g, b, a = color("text." .. tostring(role)) end
        if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
    end
    S.GetFont = function() return STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end
    -- The two LibKa0s v1.82.0 answers SetFont reads, so neither may be a no-op's nil: a picked flag
    -- as stored, "OUTLINE" for From skin or nothing stored (Ka0s Default's HUD outline, D-07); a
    -- positive size as stored, else 12, never scaled (Ka0s Default is the baseline, D-09).
    S.FontFlags = function(v)
        if type(v) == "string" and v ~= S.FROM_SKIN then return v end
        return "OUTLINE"
    end
    S.HudFontSize = function(size)
        local n = tonumber(size)
        return (n and n > 0) and n or 12
    end
    -- No skin states a border, so the stored style, Show border and thickness stand.
    S.BarBorder = function(style, show, size) return style, show, size end
    -- LibKa0s v1.85.0: a string a caller concatenates, so never nil; the art in its own color, there
    -- being no tint to read.
    S.MarkText = function(path, size)
        size = size or 14
        return ("|T%s:%d:%d|t"):format(path, size, size)
    end
    -- The one member that must draw, or a string has no face (Options docs, "The degradation
    -- facade"). Flags go through S.FontFlags, because a host stores "@skin". No font object is built,
    -- so a client that draws only an object's shadow draws none here, which is accepted.
    S.HudFont = function(fs, opts)
        opts = type(opts) == "table" and opts or {}
        local face = opts.face
        if type(face) ~= "string" or face == "" then face = STANDARD_TEXT_FONT end
        if type(face) ~= "string" then return nil end
        fs:SetFont(face, S.HudFontSize(opts.size), S.FontFlags(opts.flags))
        local on = opts.shadow and true or false
        fs:SetShadowColor(0, 0, 0, on and 1 or 0)
        fs:SetShadowOffset(on and 1 or 0, on and -1 or 0)
    end

    NS.Skin = S
    -- A stored value stands wherever a companion follows the skin: Style.Followed and Style.SkinKey.
    NS.SkinDegraded = true
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    function NS.ApplySkinOutline() return false end
    -- Nothing to paint an AceGUI widget with: stock AceGUI, as the client draws it.
    function NS.SkinPaintAce() return false end
    function NS.SkinPaintAceTree() return 0 end
    NS.SkinOnRelease = releaseByCallback
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
NS.SkinDegraded = false
Skin:RegisterOwner(addonName, {
    label  = BRAND,
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup for its
-- own picks.
local RELOAD_LINE = NS.L["Reload your interface (/reload) to finish changing the skin."]

-- The AceGUI widgets (LibKa0s SkinAce.lua). NS.AceGUI is normally the Options instance's owner
-- proxy, which paints on Create already; PaintAce for the same owner repaints in place, so the
-- explicit call after it is harmless, and it is what paints a widget acquired any other way
-- (AceConfigDialog's, on the Profiles page). Nothing is painted while the Scope's Ignore settings
-- panel is on, and the release puts the widget back in AceGUI's shared pool stock. Each guards on
-- the member, so a copy whose SkinAce secondary did not attach paints nothing.
function NS.SkinPaintAce(widget)
    if type(Skin.PaintAce) ~= "function" then return false end
    return Skin:PaintAce(addonName, widget)
end

function NS.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

--- Host release work chained onto the widget's own OnRelease (Skin:OnRelease), so it and the
--- skin's restore both run; AuraMaster sets none today, and any it adds goes through here.
function NS.SkinOnRelease(widget, fn)
    if type(Skin.OnRelease) ~= "function" then return releaseByCallback(widget, fn) end
    return Skin:OnRelease(widget, fn)
end

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it (the
--- skin's own). A copy without SetOverride (a Skin major before minor 6) moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- The applied font outline (LibKa0s-Skin-1.0 minor 9, ruling D-06): Skin:SetOutline, live, which
--- repaints and fires OnLooksChanged on a change. No argument applies the stored mode; the library
--- reads an unknown one as its default, "hud". A copy without SetOutline moves nothing.
function NS.ApplySkinOutline(mode)
    if type(Skin.SetOutline) ~= "function" then return false end
    if mode == nil then mode = NS.SkinOutline() end
    return Skin:SetOutline(addonName, mode)
end

--- No argument applies the stored pair AND the stored exceptions, overrides and outline
--- (addon:OnInitialize, the profile callbacks); a nil half keeps that half and leaves the rest alone
--- (each skin row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
        NS.ApplySkinOutline()
    end
    return changed, reload
end
