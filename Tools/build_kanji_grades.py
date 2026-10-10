#!/usr/bin/env python3
"""Build Shared/Resources/kanji_grades.json: the school grade in which each jōyō kanji is taught.

    { "一": 1, ..., "茨": 4, ..., "亜": 7 }
    1-6 = elementary school grade (kyōiku kanji), 7 = secondary school (other jōyō kanji)

Source: https://github.com/davidluzgouveia/kanji-data (grades from KANJIDIC2, © EDRDG,
CC BY-SA 4.0). That data uses the pre-2020 grade list, so the 20 prefecture kanji added to
grade 4 in 2020 are patched in below.

Usage: python3 Tools/build_kanji_grades.py [path/to/kanji.json]
"""
import json
import sys
import urllib.request
from pathlib import Path

URL = "https://raw.githubusercontent.com/davidluzgouveia/kanji-data/master/kanji.json"
OUT = Path(__file__).resolve().parent.parent / "Shared" / "Resources" / "kanji_grades.json"
PREFECTURE_KANJI_2020 = "茨媛岡潟岐熊香佐埼崎滋鹿縄井沖栃奈梨阪阜"


def main():
    if len(sys.argv) > 1:
        data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    else:
        data = json.loads(urllib.request.urlopen(URL).read())
    grades = {}
    for kanji, info in data.items():
        grade = info.get("grade")
        if grade in range(1, 7):
            grades[kanji] = grade
        elif grade == 8:
            grades[kanji] = 7
    for kanji in PREFECTURE_KANJI_2020:
        grades[kanji] = 4
    OUT.write_text(json.dumps(grades, ensure_ascii=False, separators=(",", ":"), sort_keys=True), encoding="utf-8")
    counts = {g: sum(1 for v in grades.values() if v == g) for g in range(1, 8)}
    print(f"Wrote {len(grades)} kanji to {OUT}: {counts}", file=sys.stderr)


if __name__ == "__main__":
    main()
