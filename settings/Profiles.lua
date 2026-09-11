local _, NS = ...

-- settings/Profiles.lua — the Profiles sub-page (options-ui-§3). AceConfigDialog draws the
-- AceDBOptions table into an AceGUI group inside our canvas; it is one of the two pages the tab
-- strip does not apply to (options-ui-§13), because the flow engine never renders it.
--
-- A profile holds every container. Switching, copying or resetting one reaches
-- NS.OnProfileChanged (core/AuraMaster.lua), which rebuilds every container from it.
--
-- Optional dependency: without AceDBOptions / AceConfigDialog the page opts out (a nil return).

local L = NS.L

local APPNAME = "AuraMaster-Profiles"

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    if not LibStub then return nil end
    local AceDBOptions    = LibStub("AceDBOptions-3.0", true)
    local AceConfig       = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceGUI          = LibStub("AceGUI-3.0", true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI) then return nil end
    if not (NS.db and NS.db.profile) then return nil end
    local H = NS.Helpers

    AceConfig:RegisterOptionsTable(APPNAME, AceDBOptions:GetOptionsTable(NS.db))

    local ctx = H.CreatePanel("AuraMasterProfilesPanel", L["Profiles"], {
        pageKey = "profiles", defaultsButton = false,
    })

    -- Built on first show, never in the builder (options-ui-§5), and re-opened on every render
    -- because AceConfigDialog re-reads the current profile on each Open.
    local container
    H.SetRenderer(ctx, function()
        if not container then
            container = AceGUI:Create("SimpleGroup")
            container:SetLayout("Fill")
            container.frame:SetParent(ctx.body)
            container.frame:ClearAllPoints()
            container.frame:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", 8, -8)
            container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
        end
        AceConfigDialog:Open(APPNAME, container)
    end)

    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["Profiles"])
end

NS.RegisterOptionsPage("profiles", L["Profiles"], build)
