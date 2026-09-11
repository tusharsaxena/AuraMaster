local _, NS = ...

-- core/PoolSetup.lua — the LibKa0s-Pool-1.0 seam (library-stack-§7).
--
-- The pool serves the preview's placeholder elements (modules/Preview.lua is its only caller); the
-- live aura buttons are the Blizzard engine's own and never come from here. Each preview dress
-- re-acquires its placeholders, and WoW never frees a frame once created, so a preview that made
-- fresh frames on every dress would leak. So each container keeps an ARRAY-shaped pool (the
-- library's `{ free, active }`), acquires one placeholder per slot on a dress and releases them all
-- before the next. The keyed shape is not used here: placeholders are positional, not identified.
--
-- WHAT A DEGRADED INSTALL GETS: the same four members, locally. A call site that branched on the
-- library's presence would be a call site with a memory leak on one of its two paths.

local Pool = LibStub and LibStub("LibKa0s-Pool-1.0", true)

NS.Pool = Pool or {
    New = function() return { free = {}, active = {} } end,

    Acquire = function(pool, factory)
        local o = table.remove(pool.free)
        if not o then o = factory() end
        pool.active[#pool.active + 1] = o
        o:Show()
        return o
    end,

    ReleaseAll = function(pool, before)
        local active = pool.active
        -- BACKWARD: Acquire pops the free list from the END, so parking the last element first hands
        -- each element back to the slot it already held, and a re-dressed preview keeps every
        -- placeholder in the frame it had.
        local count = #active
        for i = count, 1, -1 do
            local o = active[i]
            if before then before(o) end
            o:Hide()
            pool.free[#pool.free + 1] = o
        end
        count = #active
        for i = count, 1, -1 do
            active[i] = nil
        end
    end,

    Counts = function(pool)
        return #pool.free, #pool.active
    end,
}
