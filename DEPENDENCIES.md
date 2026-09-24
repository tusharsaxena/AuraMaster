# Dependencies — Ka0s Aura Master

What you need installed to build, run, test or release this addon. Commands are for
**WSL2 / Ubuntu** (the collection's development environment). How to *verify* the addon once
you are set up is `docs/testing.md`; this file only covers *what to install* (documentation-§7).

Every entry says what needs it and how that is known. Anything only plausibly required is
marked as such rather than listed as a requirement.

| Group | Who needs it | Short answer |
|---|---|---|
| Runtime (in-game) | Players | World of Warcraft (Retail), patch 12.1 or later. Nothing else. |
| Development | Contributors | Lua **5.1** (+ `luac`), `luacheck`, `lizard`, `git`, `bash`, and a POSIX shell with `ls` and `grep` (`nproc` optional, for `-j auto`). |
| Release / assets | Whoever regenerates a committed asset | Python **3.8+** (the spell-research generator, `tools/spell-research/research.py`, which regenerates `defaults/CastToAura.lua`) and a working internet connection for its non-`--replay` runs; Pillow (the 128 icon TGA). Not needed to build, run or test. |

## Runtime (in-game) — what a player needs

- **World of Warcraft (Retail).** Single `## Interface: 120100` line in `AuraMaster.toc:1` — Retail
  only. The addon needs the 12.1 aura container engine: `CM.Init` asks
  `Compat.EnsureAuraContainer` (`core/Compat.lua:34`), which loads Blizzard's on-demand aura
  container and then checks for it (`Compat.HasAuraContainer`, `core/Compat.lua:25`). On a client
  without it, `CM.Init` prints a one-line notice (`modules/ContainerManager.lua:621`) and draws
  nothing.
- **No deprecated API fallback.** `NS.Meta` (`core/EnvSetup.lua:24`) reads the TOC through
  `LibKa0s-Env-1.0`, or through `C_AddOns.GetAddOnMetadata` when the library is absent. It never
  falls back to the deprecated global `GetAddOnMetadata`; the TOC is Retail-only, where `C_AddOns`
  always exists.
- **Nothing else.** The TOC declares no `## Dependencies`. Every library it loads — LibStub,
  CallbackHandler-1.0, the Ace3 modules, LibDataBroker-1.1, LibDBIcon-1.0, LibKa0s,
  LibSharedMedia-3.0 and AceGUI-3.0-SharedMediaWidgets — is vendored under `libs/` and listed in
  the `# Libraries` block (`AuraMaster.toc:15-32`). `## OptionalDeps:` (`AuraMaster.toc:8`) names the vendored libs for load
  ordering, not as things to download (library-stack).
- **No optional integration.** Nothing in the addon checks whether another addon is loaded before
  using it. The only add-on-loaded check is `Compat.EnsureAuraContainer`'s own
  (`core/Compat.lua:34`), and it asks only about Blizzard's `Blizzard_AuraContainer`. The frame
  anchor re-resolves on every `ADDON_LOADED` (`addon:OnAddonLoaded`, `core/AuraMaster.lua:128`) whatever the addon is.

## Development — the contributor toolchain

| Tool | Version | Needed for | Evidence |
|---|---|---|---|
| `lua5.1` (+ `luac`) | **5.1 exactly** | the headless suite, `lua tests/run.lua`; the offline perf runner `lua tests/perf.lua`; one-file syntax checks `luac -p file.lua` | `tests/_kit/loader.lua:72` and `:91` call `setfenv`, `:89` calls `loadstring` |
| `luacheck` | any recent | `luacheck .`, the other half of the green gate | `.luacheckrc` at the repo root |
| `lizard` | any recent | the `complexity` suite of `tests/_kit/run-automated-tests.sh` (automated-tests) | `tests/_kit/run-automated-tests.sh:167` probes `command -v lizard` |
| `git` | any recent | the vendored-payload gate, the lint-config gate, the line-ending gate, the runner-mode (100755) case, and the runner's manifest | `tests/_kit/vendor_sync.lua:195` (`git -C … show`), `tests/test_lintconfig.lua:157` (`git ls-files`), `tests/_kit/test_eol.lua` (`git check-attr`), `tests/_kit/vendor_sync.lua:371` (`git ls-files -s`, the kit's runner-mode case), `tests/_kit/run-automated-tests.sh:169` (`git rev-parse`) |
| `bash` | any recent | running the vendored automated-test runner, and the standard utilities it pipes through: `sed`, `grep`, `awk`, `date`, `find`, `wc`, `sort`, `head`, `tail`, `tr` | `tests/_kit/run-automated-tests.sh:1` is `#!/usr/bin/env bash` and uses bash arrays; `:68`, `:80` and `:93` (`sed`), `:80` and `:165` (`grep`), `:100` (`date`), `:77` (`head`), `:80` (`tr`); `awk` builds `PERF_SCENARIOS`, `PERF_TABLE` and `CCN_BAND_ROWS`, `find`, `wc` and `sort` build `CCN_BAND_ROWS`, and `tail` picks the lint `Total:` line and the tests `footer` |
| POSIX shell with `ls` and `grep` (`-r`, `--include`) | any | tests that list or scan source files by shelling out: the docs gate, the locale gate, the close-button and metadata-reader source scans, and the kit's directory listing | `tests/test_docs.lua:43` and `tests/test_locale.lua:24` (`io.popen("ls -1 …")`), `tests/test_setups.lua:42` and `:74` (`io.popen("grep -rn … --include='*.lua' …")`), `tests/_kit/framework.lua` (`listDir`, `ls -A`) |
| POSIX `sh` + `nproc` (coreutils) | any | the parallel harness, which `lua tests/run.lua` uses by default (`jobs = "auto"`; `-j N` overrides); `nproc` is optional: without it (or `sysctl -n hw.ncpu`), `auto` falls back to one job | `tests/_kit/framework.lua` (`nproc` for `--jobs auto`; `os.execute(":")`, the POSIX-shell probe; shards backgrounded with `&` and joined with `wait`) |

**Lua 5.1 is a requirement, not a preference.** The harness sandboxes each source file with
`setfenv`, which was removed in 5.2. "5.2 will probably work" is false and costs an hour to
disprove. WoW's own client is Lua 5.1 too, which is why the harness can run the addon source
unmodified.

```sh
# Lua 5.1 (luac arrives in the same package) and luacheck
sudo apt-get update
sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck

# lizard — via pipx, NOT pip. Ubuntu 24.04 marks its Python EXTERNALLY-MANAGED (PEP 668),
# so `pip install lizard` fails; pipx installs it into its own venv and puts it on PATH.
sudo apt-get install -y pipx
pipx ensurepath          # then open a new shell, or: source ~/.bashrc
pipx install lizard

# git (bash, sh, ls, grep, nproc and the runner's text utilities ship with Ubuntu already)
sudo apt-get install -y git

# verify — each of these must print a version
lua5.1 -v                # Lua 5.1.5 …   (if `lua` is not 5.1, use lua5.1 explicitly)
luac5.1 -v               # Lua 5.1.5 …
luacheck --version       # Luacheck: 1.x
lizard --version         # 1.x
git --version            # git version 2.x
bash --version | head -1 # GNU bash, version 5.x
```

Versions are pinned only where a version matters: `lua5.1` is hard, `luacheck` and `lizard` are
"any recent" and pinning them would be false precision.

### Optional: a sibling `../LibKa0s` checkout

`tests/test_vendor_sync.lua` hands the comparison to the vendored `tests/_kit/vendor_sync.lua`, which
reads the tag named in root `CLAUDE.md` (`v1.57.0`) out of a checkout at `../LibKa0s` and compares
`libs/LibKa0s/` and `tests/_kit/` against it. Without that checkout the case records a **skip with
its reason**, not a pass and not a failure (testing-§11). Clone it if you touch `libs/`, re-vendor,
or want that case to actually compare:

```sh
git clone https://github.com/tusharsaxena/LibKa0s.git ../LibKa0s
git -C ../LibKa0s rev-parse --short v1.57.0   # verify: prints a commit
```

### Not dependencies of this repo

- **LuaFileSystem.** Not used; the kit lists directories by shelling out. `luacheck` pulls it in for
  itself, which is LuaRocks' business rather than this addon's.
- **Any pip-installed Python package.** Pillow, the one Python package here, comes from apt (Release /
  assets, above). `tools/spell-research/research.py` is standard library only, on purpose:
  Ubuntu 24.04 marks its Python EXTERNALLY-MANAGED (PEP 668), so a single `pip install` in that
  generator would have dragged a virtualenv or a pipx recipe into a tool that runs a handful of
  times per expansion. The complexity suite's `lizard` is installed through pipx (above) and is a
  different tool with a different justification; nothing about it licenses `pip install` here.
- **A CI runner.** There is none; every gate is local and hand-run (testing-§5).
- **The vendored libraries.** LibStub, CallbackHandler-1.0, the Ace3 modules, LibDataBroker-1.1,
  LibDBIcon-1.0, LibKa0s, LibSharedMedia-3.0 and AceGUI-3.0-SharedMediaWidgets are committed
  under `libs/`. Listing them here does not license fetching them at build time.

## Release / assets

This addon is packaged from the committed tree. `.pkgmeta` sets `package-as: AuraMaster` with no
`externals:` block, and nothing is generated at build time. This group is what it takes to
*regenerate* a committed asset: the spell-research data and the 128 icon. **None of this group is
required to build, run or test the addon.**

| Tool | Version | Needed for | Evidence |
|---|---|---|---|
| `python3` | **3.8** or newer | the spell-research generator, `tools/spell-research/research.py` — the offline half of issue #11's Part C, which derives the Hard CC / Soft CC spell lists from Blizzard's DB2 exports. Not part of the green gate, and not needed to build, run or test the addon | `tools/spell-research/research.py:1` is `#!/usr/bin/env python3`, and it imports `argparse`, `csv`, `gzip`, `json`, `urllib` and friends and **nothing outside the standard library** — so there is no `pip install` step and no virtualenv. 3.8 is the floor because the file's `from __future__ import annotations` is what lets it write `dict[int, str]` and `str \| None` annotations on an older interpreter |
| a working internet connection | — | the same generator, on any run that is not `--replay`: it fetches the DB2 CSV exports over HTTPS and caches them in `tools/spell-research/.cache/` (~75 MB a build, git-ignored). A frozen bundle can be re-derived offline (`--replay docs/spell-research/<date>`) | `tools/spell-research/research.py` imports `urllib.request` and `urllib.error`; `tools/spell-research/.gitignore:1-2` describes the cache as "~75 MB a build, re-downloadable at any time" |
| Pillow (`python3-pil`) | any recent | regenerating the 128 icon TGA (below) | the recipe below does `from PIL import Image` |

```sh
# Python 3 ships with Ubuntu; Pillow comes from apt (PEP 668 rules out a bare pip install)
sudo apt-get install -y python3 python3-pil

# verify
python3 --version                                  # Python 3.8 or newer
python3 -c 'import PIL; print(PIL.__version__)'    # prints a version
```

- **The logo is committed in every form, and TWO of them are loaded.** `auramaster.logo.tga` is
  the settings panel's landing-page art (`C.LOGO_PATH`, `core/Constants.lua:26`) and
  `auramaster.logo.128.tga` is the icon the AddOns list, the minimap button and a broker display
  all draw (`C.LOGO_ICON_PATH`, `core/Constants.lua:32`, `AuraMaster.toc:6`). The `.png` and
  `.jpg` beside them are the 2000×2000 source art and the project-page image, and `.pkgmeta`
  keeps both out of the package.
- **Pillow regenerates the 128 icon, and is NOT required to build, run or test the addon.** The
  file is committed; the recipe is recorded so it is reproducible rather than a one-off export
  (layout-§4). It must come out uncompressed 32-bit — TGA image type 2, 32 bpp, ~64 KB — which
  `tests/test_launcher.lua` reads out of the header, because an icon in the wrong format draws
  nothing and raises nothing.

  ```sh
  python3 -c "from PIL import Image; Image.open('media/logos/auramaster.logo.png')\
    .convert('RGBA').resize((128,128), Image.LANCZOS)\
    .save('media/logos/auramaster.logo.128.tga', format='TGA')"
  ```
- **The debug console's monospace face is not this addon's asset.** It ships in the vendored
  `libs/LibKa0s/media/fonts/` and is reached through `core/MediaSetup.lua`.

## Am I set up correctly?

```sh
lua tests/run.lua                                     # the suite, sharded across CPUs — must be green
lua tests/run.lua -j 1                                # same, serially; must match it (testing-§14)
luacheck .                                            # must be 0 warnings / 0 errors
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .     # the complexity report (release-time)
```

See `docs/testing.md` for what those commands mean and when each is run.
