#!/usr/bin/env python3
"""tools/spell-research/logs.py — combat-log evidence for AuraMaster's spell categories.

Design of record: docs/superpowers/specs/2026-09-24-spell-ids-from-combat-logs-design.md.

Subcommands:
    scan     Stream every WoWCombatLog-*.txt in a folder (only logs not already cached),
             merge the per-spec evidence of player-applied auras, print a summary and write
             evidence.json (counts only; no player name, realm, GUID or hash).

The per-log cache and its salt live outside the repo (default
~/.cache/auramaster-spell-research/). Python 3.8+ standard library only.
"""

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import research  # noqa: E402
import sid_cache  # noqa: E402

DEFAULT_LOGS = Path("/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Logs/RaiderIOLogsArchive")
DEFAULT_DB2_CACHE = HERE / ".cache"


def spec_to_class_from_db2(db2_cache, build=None):
    """spec id -> class token, from ChrSpecialization in the DB2 cache (sid_db2, imported lazily)."""
    try:
        import sid_db2
    except ImportError as exc:
        raise SystemExit("logs.py: the DB2 reader sid_db2 is not available (%s)" % exc)
    tables = sid_db2.open_db2(Path(db2_cache), build)
    spec_map = sid_db2.load_spec_map(tables["ChrSpecialization"])
    return {int(spec): info["class"] for spec, info in spec_map.items()}


def format_summary(s):
    return ("Scanned %d logs (%.1f MB): read %d, cached %d; dates %s..%s; "
            "lines %d, skipped %d, unattributed %d"
            % (s["files"], s["bytes"] / 1e6, s["read"], s["cached"],
               s["first_date"] or "-", s["last_date"] or "-",
               s["lines"], s["skipped"], s["unattributed"]))


def cmd_scan(args):
    spec_to_class = spec_to_class_from_db2(args.db2_cache)
    agg, summary = sid_cache.scan_dir(args.logs, args.cache, spec_to_class,
                                      progress=lambda m: print(m, flush=True))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    evidence = sid_cache.evidence_to_json(agg, summary)
    research.write_repo_text(out, json.dumps(evidence, indent=1, ensure_ascii=False) + "\n")
    print(format_summary(summary))
    print("Wrote %s" % out)
    return 0


def build_parser():
    p = argparse.ArgumentParser(prog="logs.py", description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="command", metavar="command")
    sub.required = True

    scan = sub.add_parser("scan", help="scan combat logs into evidence.json")
    scan.add_argument("--logs", type=Path, default=DEFAULT_LOGS,
                      help="folder of WoWCombatLog-*.txt files (default: %(default)s)")
    scan.add_argument("--cache", type=Path, default=sid_cache.DEFAULT_CACHE_DIR,
                      help="per-log cache and salt, outside the repo (default: %(default)s)")
    scan.add_argument("--db2-cache", type=Path, default=DEFAULT_DB2_CACHE,
                      help="research.py's DB2 CSV cache (default: %(default)s)")
    scan.add_argument("--out", type=Path, required=True,
                      help="evidence.json to write, e.g. docs/spell-research/<date>-logs/evidence.json")
    scan.set_defaults(func=cmd_scan)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
