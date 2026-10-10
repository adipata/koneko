#!/usr/bin/env python3
"""Build Shared/Resources/kanji_info.json: meanings, readings and stroke counts of the 2,136
jōyō kanji, used by the Learn → Kanji browser (works offline).

    { "海": {"g": 2, "s": 9, "m": ["Sea"], "on": ["かい"], "kun": ["うみ"], "r": "氵"}, ... }

"r" is the kanji's radical (its "family", e.g. 氵 water), used to group kanji from grade 3 on.

Sources: https://github.com/davidluzgouveia/kanji-data (from KANJIDIC2, © EDRDG, CC BY-SA 4.0)
and KanjiVG (radicals; © Ulrich Apel, CC BY-SA 3.0).
Only kanji listed in Shared/Resources/kanji_grades.json are kept, with that file's grade.

Usage: python3 Tools/build_kanji_info.py [path/to/kanji.json] [path/to/kanjivg/kanji]
"""
import io
import re
import zipfile
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
URL = "https://raw.githubusercontent.com/davidluzgouveia/kanji-data/master/kanji.json"
GRADES = ROOT / "Shared" / "Resources" / "kanji_grades.json"
OUT = ROOT / "Shared" / "Resources" / "kanji_info.json"
KANJIVG_URL = "https://github.com/KanjiVG/kanjivg/releases/download/r20250816/kanjivg-20250816-main.zip"

# Variants of the same family are merged, so e.g. 亻 and 人 form one "person" group.
RADICAL_MERGE = {"人": "亻", "心": "忄", "灬": "火", "衣": "衤", "手": "扌", "⺡": "氵", "水": "氵"}


def radicals(kanjivg_dir):
    """Radical per kanji from KanjiVG (the element marked kvg:radical="general")."""
    if kanjivg_dir:
        files = {p.stem: p.read_text(encoding="utf-8") for p in Path(kanjivg_dir).glob("*.svg")}
    else:
        data = urllib.request.urlopen(KANJIVG_URL).read()
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            files = {Path(n).stem: zf.read(n).decode("utf-8") for n in zf.namelist() if n.endswith(".svg")}
    result = {}
    for stem, svg in files.items():
        if "-" in stem:
            continue
        match = re.search(r'kvg:element="([^"]+)"[^>]*kvg:radical="general"', svg) or \
            re.search(r'kvg:radical="general"[^>]*kvg:element="([^"]+)"', svg)
        if match:
            radical = match.group(1)
            result[chr(int(stem, 16))] = RADICAL_MERGE.get(radical, radical)
    return result


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
    radical_of = radicals(sys.argv[2] if len(sys.argv) > 2 else None)
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
        if kanji in radical_of:
            info[kanji]["r"] = radical_of[kanji]
    OUT.write_text(json.dumps(info, ensure_ascii=False, separators=(",", ":"), sort_keys=True), encoding="utf-8")
    missing = sum(1 for v in info.values() if not v["m"])
    print(f"Wrote {len(info)} kanji to {OUT} ({OUT.stat().st_size // 1024} KB, {missing} without meanings)", file=sys.stderr)


if __name__ == "__main__":
    main()
