#!/usr/bin/env python3
"""Remove circular features.dart imports from lib/core (except app_router)."""

import lib.transport
import lib.session
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

KEEP_FEATURES = {
    LIB / "core" / "navigator" / "app_router.dart",
}


def clean_file(path: Path) -> bool:
    text = path.read_text()
    original = text

    if path in KEEP_FEATURES:
        return False

    if path.is_relative_to(LIB / "core"):
        text = text.replace("import 'package:zedu/features/features.dart';\n", "")

    # Drop stale commented barrel imports left by format_imports.py
    lines = text.splitlines(keepends=True)
    filtered = [
        line
        for line in lines
        if not line.strip().startswith("// import 'package:zedu/")
    ]
    text = "".join(filtered)

    if text != original:
        path.write_text(text)
        return True
    return False


def main() -> None:
    changed = 0
    for path in LIB.rglob("*.dart"):
        if clean_file(path):
            changed += 1
    print(f"Updated {changed} files")


if __name__ == "__main__":
    main()
