# Candidates

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`, the CHANGELOG block v1.90.0 and the `docs/api/`
documents of every major whose minor moved (`01_DELTA.md` 3c, 3g).

## A. Delivered on the re-vendor

- **Core 15 -> 16** (SF1-L1): the `__` pixel-edge internals (`docs/api/Core/version-16-docs.md`, "A host
  calls none of them").
- **Widgets 23 -> 24, WidgetsAutocomplete 7 -> 8** (SF1-L1): the library's dropdown, search box, menu levels
  and autocomplete list draw a one-physical-pixel edge (`docs/api/Widgets/version-24.5.12.6.8.5-docs.md`,
  "What a host owes: nothing"). AuraMaster draws none of them; the drag handle (`modules/Anchors.lua:691`,
  `WidgetsDragHandle.lua` at 12) is unchanged.
- **SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18** (SF1-L1): `P.px` and the pixel watch call Core's.
- **OptionsAppearance 6 -> 7** (SF1-L2): Apply to all and the Skin-tab copy leave a `keepScope` target's
  Scope alone. For AuraMaster, as a source or a target with no `keepScope`, the copy behaves as before.

## B. Host change required

- **`RegisterOwner(owner, { keepScope = true })`** (Skin 17, `docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md`;
  Options document, "a host whose Scope is a documented deviation registers with `keepScope = true`").
  AuraMaster's Scope defaults are the standard's (`defaults/Profile.lua:55`), not a deviation. Not applicable.

## C. Whole-module adoption

None new in this range. IconBrowser stays settled as in the v1.89.0 bundle (no icon chooser in AuraMaster).
