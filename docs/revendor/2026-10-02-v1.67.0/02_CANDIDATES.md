# 02 - Candidates: LibKa0s v1.66.0 -> v1.67.0

Sources:

```sh
git -C ../LibKa0s log --oneline v1.66.0..v1.67.0
git -C ../LibKa0s show v1.67.0:CHANGELOG.md          # the v1.67.0 block
git -C ../LibKa0s show v1.67.0:docs/api/Core/version-10-docs.md
git -C ../LibKa0s show v1.67.0:docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md
```

No interview. The census-adoption bundle's design (`01_DESIGN.md` D1, D2, D3) already decides which
item takes each surface; this file records the mapping for AuraMaster.

## A. Delivered on the re-vendor alone

- **OptionsIdList minor 3, the loaded-addon guard**: a wrong or missing descriptor `addonName` draws
  the client glyph plus one gated `Cfg` line, never a dead texture path.
- **Options minor 28**: a docblock correction only.

## B. Host change required

| Candidate | Evidence | Taken by |
|---|---|---|
| Options descriptor `addonName` (the folder name, the first vararg) | CHANGELOG v1.67.0, *OptionsIdList minor 3 and Options minor 28*; `01_DESIGN.md` D2 | **`CA-AM-NM`**: `settings/OptionsSetup.lua` keeps `addonName` from `...` and passes `addonName = addonName,`. AuraMaster is the one host whose help marks change visibly (the `info` art, tinted by level) |
| `MakeResizable` `canResize` | CHANGELOG v1.67.0, *Core minor 10*; `docs/api/Core/version-10-docs.md`, "The resize grip" | **none**: AuraMaster builds no resize grip of its own |
| `MakeResizable` `onResizeStop` | as above | **none** |
| `MakeResizable` `gripParent` | as above | **none** |

AuraMaster has no adoption item in the census-adoption bundle beyond `CA-AM-NM`.

## C. Whole-module adoption

None. No major is added in this range; `LibKa0s-Item-1.0` stays unbound, as before.
