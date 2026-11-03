#!/usr/bin/env python3
"""Sync the Flickpitch design system + brand assets into Flickpitch Business.

Why this exists
---------------
Flickpitch Business must always look and feel like Flickpitch: same tokens,
same palette, same typography, same logo, same launcher icons. Those live in
the personal app, which is the source of truth. Hand-copying them drifts.

What is synced (personal -> business)
------------------------------------
  lib/design/                                   design system (fp_tokens, fp_components, ...)
  lib/utils/brand_theme.dart                    brand theme bootstrap
  lib/utils/preference_key/constant/app_colors.dart
  lib/utils/preference_key/constant/app_text_style.dart
  lib/utils/preference_key/constant/app_theme_manage.dart
  lib/utils/preference_key/constant/app_assets.dart   (business block preserved)
  assets/images/**                              logos, illustrations, icons
  android/app/src/main/res/**                   launcher icons, splash
  web/icons/** , web/favicon.png, web/manifest.json

What is only REPORTED (never auto-copied)
-----------------------------------------
  lib/**  outside the list above. Business screens carry business-only code;
  blind copying would break them. The script prints the differing files so a
  human can port fixes deliberately.

Usage
-----
  python3 scripts/sync_design.py            # dry run, prints drift
  python3 scripts/sync_design.py --apply    # writes files
  python3 scripts/sync_design.py --apply --quiet
"""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path

PERSONAL = Path(
    "/home/admin/.openclaw/workspace/session-files/01M5WSF5N364M99HAJ937DYYQZ/"
    "flickpitch-app/src/mobile/_x/whoxa-chat-app/whoxa-chat-app"
)
BUSINESS = Path(
    "/home/admin/.openclaw/workspace/session-files/01M6431BC1VGY8EPXZPSDQP06N/"
    "fp-business-v2"
)

# Whole trees copied verbatim.
TREES = [
    "lib/design",
    "assets/images",
    # NOTE: launcher icons (mipmap-*/ic_launcher*) and web icons are the ONE
    # intentional difference: Flickpitch Business carries a "+" badge, so those
    # files are excluded below and must never be overwritten from personal.
    "android/app/src/main/res",
]

# Individual files copied verbatim.
FILES = [
    "lib/utils/brand_theme.dart",
    "lib/utils/preference_key/constant/app_colors.dart",
    "lib/utils/preference_key/constant/app_text_style.dart",
    "lib/utils/preference_key/constant/app_theme_manage.dart",
    # web/favicon.png intentionally excluded (business icon has the + badge)
]

# Files that need a merge instead of a copy.
SPECIAL = {
    "lib/utils/preference_key/constant/app_assets.dart": "app_assets",
}

# Business-only additions that must survive a resync.
BUSINESS_ASSETS_CLASS = "BusinessAssets"
BUSINESS_ASSETS_FIELD = (
    "  static BusinessAssets businessAssets = BusinessAssets();"
)


def iter_files(root: Path, rel: str):
    base = root / rel
    if not base.exists():
        return
    if base.is_file():
        yield rel
        return
    for p in sorted(base.rglob("*")):
        if not p.is_file():
            continue
        rel = str(p.relative_to(root))
        # Business icon set is deliberately different (plus badge).
        if "ic_launcher" in rel or rel.startswith("web/icons/"):
            continue
        yield rel


def collect(root: Path) -> dict[str, Path]:
    out: dict[str, Path] = {}
    for tree in TREES:
        for rel in iter_files(root, tree):
            out[rel] = root / rel
    for rel in FILES:
        if (root / rel).exists():
            out[rel] = root / rel
    return out


def extract_business_block(text: str) -> str | None:
    """Return the `class BusinessAssets { ... }` block from a file, if any."""
    marker = f"class {BUSINESS_ASSETS_CLASS} "
    start = text.find(marker)
    if start == -1:
        return None
    # find the opening brace, then match braces
    brace = text.find("{", start)
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    return None


def merge_app_assets(personal_text: str, business_text: str) -> str:
    """Take the personal file, re-attach the business-only additions."""
    block = extract_business_block(business_text)
    if not block:
        return personal_text

    merged = personal_text

    # 1) declare the field inside AppAssets (right after the class opening line)
    if BUSINESS_ASSETS_FIELD not in merged:
        anchor = "class AppAssets {"
        idx = merged.find(anchor)
        if idx != -1:
            insert_at = merged.find("\n", idx) + 1
            merged = (
                merged[:insert_at]
                + BUSINESS_ASSETS_FIELD
                + "\n"
                + merged[insert_at:]
            )

    # 2) re-append the class itself
    if f"class {BUSINESS_ASSETS_CLASS} " not in merged:
        merged = merged.rstrip() + "\n\n" + block + "\n"

    return merged


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    if not PERSONAL.exists() or not BUSINESS.exists():
        print(f"missing path: {PERSONAL if not PERSONAL.exists() else BUSINESS}")
        return 2

    personal = collect(PERSONAL)
    business = collect(BUSINESS)

    drift: list[str] = []
    missing: list[str] = []

    for rel, src in personal.items():
        dst = BUSINESS / rel
        if not dst.exists():
            missing.append(rel)
            continue
        if filecmp.cmp(src, dst, shallow=False):
            continue
        drift.append(rel)

    changed = sorted(set(drift) | set(missing))

    if not changed:
        if not args.quiet:
            print("design in sync — no drift")
        return 0

    print(f"drift: {len(changed)} file(s)")
    for rel in changed:
        tag = "missing" if rel in missing else "differs"
        print(f"  {tag:8} {rel}")

    if not args.apply:
        print("\ndry run — rerun with --apply to sync")
        return 1

    for rel in changed:
        src = personal.get(rel) or (PERSONAL / rel)
        dst = BUSINESS / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if rel in SPECIAL and SPECIAL[rel] == "app_assets" and dst.exists():
            merged = merge_app_assets(
                src.read_text(encoding="utf-8"),
                dst.read_text(encoding="utf-8"),
            )
            dst.write_text(merged, encoding="utf-8")
        else:
            shutil.copy2(src, dst)

    print(f"synced {len(changed)} file(s) into {BUSINESS}")

    # Report-only: the rest of lib/ (business code) so fixes can be ported.
    lib_drift = []
    for rel in iter_files(PERSONAL, "lib"):
        if rel in personal:
            continue  # already synced above
        src = PERSONAL / rel
        dst = BUSINESS / rel
        if not dst.exists():
            lib_drift.append(("missing", rel))
        elif not filecmp.cmp(src, dst, shallow=False):
            lib_drift.append(("differs", rel))

    if lib_drift and not args.quiet:
        print(
            f"\nnote: {len(lib_drift)} other lib/ file(s) differ and were NOT "
            "copied (business code). Review these for portable fixes:"
        )
        for tag, rel in lib_drift[:40]:
            print(f"  {tag:8} {rel}")
        if len(lib_drift) > 40:
            print(f"  … and {len(lib_drift) - 40} more")

    return 0


if __name__ == "__main__":
    sys.exit(main())
