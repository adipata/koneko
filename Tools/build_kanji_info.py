#!/usr/bin/env python3
"""Build koneko/Resources/kanji_info.json: meanings, readings and stroke counts of the 2,136
jōyō kanji, used by the Learn → Kanji browser (works offline).

    { "山": {"g": 1, "s": 3, "m": ["mountain"], "on": ["さん", "せん"], "kun": ["やま"]}, ... }

Source: https://github.com/davidluzgouveia/kanji-data (from KANJIDIC2, © EDRDG, CC BY-SA 4.0).
Only kanji listed in Shared/Resources/kanji_grades.json are kept, with that file's grade.

Usage: python3 Tools/build_kanji_info.py [path/to/kanji.json]
"""
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
URL = "https://raw.githubusercontent.com/davidluzgouveia/kanji-data/master/kanji.json"
GRADES = ROOT / "Shared" / "Resources" / "kanji_grades.json"
OUT = ROOT / "koneko" / "Resources" / "kanji_info.json"


def clean_meanings(meanings):
    result = []
    for meaning in meanings:
        if "radical" in meaning.lower():
            continue
        meaning = meaning.strip()
        if meaning and meaning.lower() not in (m.lower() for m in result):
            result.append(meaning)
        if len(result) == 4:
            break
    return result


def main():
    if len(sys.argv) > 1:
        data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    else:
        data = json.loads(urllib.request.urlopen(URL).read())
    grades = json.loads(GRADES.read_text(encoding="utf-8"))
    info = {}
    for kanji, grade in grades.items():
        entry = data.get(kanji, {})
        info[kanji] = {
            "g": grade,
            "s": entry.get("strokes") or 0,
            "m": clean_meanings(entry.get("meanings") or []),
            "on": (entry.get("readings_on") or [])[:4],
            "kun": (entry.get("readings_kun") or [])[:4],
        }
    OUT.write_text(json.dumps(info, ensure_ascii=False, separators=(",", ":"), sort_keys=True), encoding="utf-8")
    missing = sum(1 for v in info.values() if not v["m"])
    print(f"Wrote {len(info)} kanji to {OUT} ({OUT.stat().st_size // 1024} KB, {missing} without meanings)", file=sys.stderr)


if __name__ == "__main__":
    main()
