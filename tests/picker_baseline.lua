-- tests/picker_baseline.lua -- the harness's baseline for the first-run preset picker.
--
-- A new, reset or copied profile opens the first-run preset picker (core/AuraMaster.lua's
-- rebuildProfile calls NS.MaybeShowPresetPicker), and since 2026-11-15 the picker turns test mode on
-- as it opens (settings/PresetPicker.lua, openUnlocked). Every suite but the picker's own was
-- written against a build where that showing left test mode alone, so test mode on would change
-- what those suites draw and which events they count. This wraps the first-run showing so that it
-- does not turn test mode on: the picker still up and the containers still unlocked, as
-- before. A suite that wants the picker's own state passes `keep = true` (fresh_env's
-- `opts.pickerTestMode`); the picker's suites open it through NS.ShowPresetPicker or that option.
return function(NS, keep)
    if keep or type(NS.MaybeShowPresetPicker) ~= "function" then return end
    local show = NS.MaybeShowPresetPicker
    NS.MaybeShowPresetPicker = function(...)
        -- The picker's own SetTestMode(true, "preset picker") is held for this call alone, so the
        -- showing sends no test-mode broadcast at all, just as before 2026-11-15.
        local preview = NS.Preview
        local set = preview and preview.SetTestMode
        if set then
            preview.SetTestMode = function(on, source, ...)
                if on and source == "preset picker" then return end
                return set(on, source, ...)
            end
        end
        local ok, r = pcall(show, ...)
        if set then preview.SetTestMode = set end
        if not ok then error(r, 0) end
        return r
    end
end
