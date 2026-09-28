#!/usr/bin/env python3
"""Convert KanjiVG SVG files into the compact strokes.json bundled with the app.

Usage:
    python3 Tools/build_strokes.py                # download the pinned KanjiVG release
    python3 Tools/build_strokes.py path/to/kanji  # use an unpacked kanji/ directory

Output: koneko/Resources/strokes.json (all characters, for the app) and
        Shared/Resources/kana_strokes.json (hiragana + katakana only, small, for the watch)
    { "猫": { "s": ["M20.5,...", ...], "n": [[29.25,19.5], ...] }, ... }
    "s" = SVG path data per stroke, in stroke order (109x109 coordinate space)
    "n" = position of each stroke's number label

Stroke data: KanjiVG (c) Ulrich Apel, CC BY-SA 3.0, https://kanjivg.tagaini.net
"""
import io
import json
import re
import sys
import urllib.request
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

RELEASE = "r20250816"
URL = f"https://github.com/KanjiVG/kanjivg/releases/download/{RELEASE}/kanjivg-{RELEASE[1:]}-main.zip"
OUT = Path(__file__).resolve().parent.parent / "koneko" / "Resources" / "strokes.json"
KANA_OUT = Path(__file__).resolve().parent.parent / "Shared" / "Resources" / "kana_strokes.json"

SVG_NS = "{http://www.w3.org/2000/svg}"
STROKE_ID = re.compile(r"-s(\d+)$")
MATRIX = re.compile(r"matrix\(1 0 0 1 ([\d.\-]+) ([\d.\-]+)\)")


def svg_sources(arg):
    if arg:
        for path in sorted(Path(arg).glob("*.svg")):
            yield path.name, path.read_bytes()
        return
    print(f"Downloading {URL}", file=sys.stderr)
    data = urllib.request.urlopen(URL).read()
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        for name in sorted(zf.namelist()):
            if name.endswith(".svg"):
                yield Path(name).name, zf.read(name)


def parse(svg_bytes):
    root = ET.fromstring(svg_bytes)
    strokes = []
    for path in root.iter(f"{SVG_NS}path"):
        match = STROKE_ID.search(path.get("id", ""))
        if match:
            strokes.append((int(match.group(1)), path.get("d").strip()))
    strokes.sort()
    numbers = []
    for text in root.iter(f"{SVG_NS}text"):
        match = MATRIX.search(text.get("transform", ""))
        if match:
            numbers.append((int(text.text), [float(match.group(1)), float(match.group(2))]))
    numbers.sort()
    return [d for _, d in strokes], [pos for _, pos in numbers]


def main():
    result = {}
    for name, data in svg_sources(sys.argv[1] if len(sys.argv) > 1 else None):
        stem = Path(name).stem
        if "-" in stem:  # variant glyphs (e.g. Kaisho); the main set has none
            continue
        char = chr(int(stem, 16))
        strokes, numbers = parse(data)
        if not strokes:
            continue
        if len(numbers) != len(strokes):
            numbers = []
        result[char] = {"s": strokes, "n": numbers}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    print(f"Wrote {len(result)} characters to {OUT} ({OUT.stat().st_size // 1024} KB)", file=sys.stderr)

    kana = {c: v for c, v in result.items() if 0x3041 <= ord(c) <= 0x3096 or 0x30A1 <= ord(c) <= 0x30FA or c == "ー"}
    with KANA_OUT.open("w", encoding="utf-8") as f:
        json.dump(kana, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    print(f"Wrote {len(kana)} kana to {KANA_OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
