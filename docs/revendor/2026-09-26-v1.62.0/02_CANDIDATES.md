# 02 - Candidates: LibKa0s v1.61.0 -> v1.62.0

Sources:

```sh
git -C ../LibKa0s log --oneline v1.61.0..v1.62.0
git -C ../LibKa0s show v1.62.0:CHANGELOG.md          # the v1.62.0 block
```

## A. Delivered on the re-vendor alone

| What | Evidence | Why no host change |
|---|---|---|
| An empty watch-list table in `RESULTS.md` prints `None.` (`ATS-20`) | `CHANGELOG.md` v1.62.0, *Test kit revision 30* | The vendored `tests/_kit/run-automated-tests.sh` writes it; the next `/wow-addon:automated-tests` run shows it |
| Generated files leave the band table (`ATS-21`) | `CHANGELOG.md` v1.62.0, *Test kit revision 31* | The runner asks `tests/run.lua --layout-cap-exempt`; AuraMaster declares no `Kit.layoutCap.exempt` set, so its band table is the same as before |
| The Options major's files all under the 1500-line cap | `CHANGELOG.md` v1.62.0, the three peels | Members attach from new files in the same order; nothing for a host to call |
| The kit's `framework.lua` and `test_prose.lua` out of the 1000-1500 band | `CHANGELOG.md` v1.62.0, *Test kit revisions 28 and 29* | Loaded by the kit from its own folder |

## B. Host change required

None. No member, descriptor field, row field or kit surface is added.

## C. Whole-module adoption

None. No major is added in this range.
