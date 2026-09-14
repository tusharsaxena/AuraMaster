-- tests/engine_recorder.lua — makes a recorder button (tests/region_recorder.lua) answer its dispel
-- bindings the way the client's CustomAuraButton does. The rules come from the engine source read in
-- docs/superpowers/research/2026-09-13-aura-engine-notes.md (Q1):
--   * every Set* / Add* binding ends in a full apply pass (UpdateAuraDisplay);
--   * that pass tints and shows each registered dispel texture, or hides it when the button holds
--     no aura;
--   * ClearDispelTypeTextures only empties the list: it touches no region and runs no pass.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.

-- The bindings whose engine method ends in UpdateAuraDisplay (AddDispelTypeTexture is handled below).
local PASSES = { "SetDurationBar", "SetDurationCooldown", "SetDurationText", "SetIcon", "SetSpellName",
    "SetApplicationCount", "AddPandemicRegion" }

--- Make `button` answer like an engine button. `opts.tint` is the { r, g, b, a } the pass paints (the
--- dispel color); `opts.aura` false stands for a pooled button that holds no aura.
return function(button, opts)
    local textures = {}
    local function pass(self)
        for _, tex in ipairs(textures) do
            if opts.aura then
                tex:SetVertexColor(unpack(opts.tint))
                tex:Show()
            else
                tex:Hide()
            end
        end
        return self
    end
    for _, name in ipairs(PASSES) do button.__answer[name] = pass end
    button.__answer.AddDispelTypeTexture = function(self, tex)
        textures[#textures + 1] = tex
        return pass(self)
    end
    button.__answer.ClearDispelTypeTextures = function(self)
        textures = {}
        return self
    end
    return button
end
