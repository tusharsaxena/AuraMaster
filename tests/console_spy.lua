-- tests/console_spy.lua — record every line that reaches the debug console, whichever door it came
-- through: the gated sink (NS.Debug, which the host's own lines and every LibKa0s descriptor's
-- `debug` field call) AND the console's own writers. The change gates and the at-enable queue
-- (DebugLog 18, DebugLogGates 1) write with the console's `Add`, not through NS.Debug, so a spy on
-- NS.Debug alone would miss exactly the lines the gates own.
--
-- `fn(tag, fmt, ...)` receives a gate's line as an already-formatted `fmt` with its `%` escaped, so
-- a recorder that runs `fmt:format(...)` reads the line unchanged. Answers the restore. Not a suite
-- (tests/run.lua does not list it) and not part of the vendored kit.
return function(NS, fn)
    local D = NS.DebugLog
    local debug, add = NS.Debug, D.Add
    NS.Debug = fn
    D.Add = function(_, tag, msg)
        fn(tag, (tostring(msg):gsub("%%", "%%%%")))
    end
    return function() NS.Debug, D.Add = debug, add end
end
