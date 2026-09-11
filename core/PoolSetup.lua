local _, NS = ...

-- core/PoolSetup.lua — the LibKa0s-Pool-1.0 seam (library-stack-§7).
--
-- Every container re-renders its elements — bars or icons — whenever its unit's auras change, which
-- in combat is several times a second. A container that allocated a fresh frame per aura per render
-- would leak: WoW never frees a frame once created. So each container keeps an ARRAY-shaped pool
-- (the library's `{ free, active }`), acquires one element per aura on render and releases them all
-- before the next render. The keyed shape is not used here: elements are positional, not identified.
--
-- WHAT A DEGRADED INSTALL GETS: the same three members, locally. A call site that branched on the
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
        -- BACKWARD, mirroring LibKa0s-Pool-1.0 minor 3: Acquire pops the free list from the END, so
        -- parking the last element first hands each element back to the slot it already held, and a
        -- steady aura list re-renders without its bars swapping frames.
        for i = #active, 1, -1 do
            local o = active[i]
            if before then before(o) end
            o:Hide()
            pool.free[#pool.free + 1] = o
        end
        for i = #active, 1, -1 do active[i] = nil end
    end,

    Counts = function(pool) return #pool.free, #pool.active end,
}
