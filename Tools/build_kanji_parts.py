#!/usr/bin/env python3
"""Build koneko/Resources/kanji_parts.json: the parts each jōyō kanji is made of, with the
meaning and readings of every part, for the "Parts" section of Learn → Kanji (works offline).

    {
      "kanji": { "秋": ["禾", "火"], "海": ["氵", "毎"], ... },
      "parts": {
        "禾": {"m": ["Grain"], "n": "のぎへん", "k": ["いね"], "o": ["か"]},
        "氵": {"m": ["Water"], "n": "さんずい", "f": "水", "k": ["みず"], "o": ["すい"]},
        ...
      }
    }

"m" = meanings, "n" = the part's Japanese name (radicals only), "f" = the full kanji a squeezed
radical comes from (氵 → 水), "k" / "o" = Japanese (kun) / Chinese (on) readings.

The parts are the top-level elements of each kanji in KanjiVG (秋 = 禾 + 火). Meanings and
readings come from KANJIDIC2; common radicals get a hand-written, child-friendly entry below.
Parts without a usable meaning (rare shapes) are left out.

Sources: KanjiVG (© Ulrich Apel, CC BY-SA 3.0) and https://github.com/davidluzgouveia/kanji-data
(from KANJIDIC2, © EDRDG, CC BY-SA 4.0).

Usage: python3 Tools/build_kanji_parts.py [path/to/kanji.json] [path/to/kanjivg/kanji]
"""
import io
import json
import re
import sys
import urllib.request
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INFO = ROOT / "Shared" / "Resources" / "kanji_info.json"
OUT = ROOT / "koneko" / "Resources" / "kanji_parts.json"
DATA_URL = "https://raw.githubusercontent.com/davidluzgouveia/kanji-data/master/kanji.json"
KANJIVG_URL = "https://github.com/KanjiVG/kanjivg/releases/download/r20250816/kanjivg-20250816-main.zip"

SVG = "{http://www.w3.org/2000/svg}"
KVG = "{http://kanjivg.tagaini.net}"

# Radicals and common shapes: meaning, Japanese name, full kanji it comes from, readings.
# Readings left empty are taken from the full kanji ("f"), or else from KANJIDIC2.
# (meaning, name, from, kun, on)
CURATED = {
    "氵": ("Water", "さんずい", "水", None, None),
    "扌": ("Hand", "てへん", "手", None, None),
    "亻": ("Person", "にんべん", "人", None, None),
    "忄": ("Heart", "りっしんべん", "心", None, None),
    "艹": ("Grass", "くさかんむり", "草", None, None),
    "刂": ("Knife", "りっとう", "刀", None, None),
    "灬": ("Fire", "れんが", "火", None, None),
    "礻": ("Altar, god", "しめすへん", "示", None, None),
    "衤": ("Clothes", "ころもへん", "衣", None, None),
    "飠": ("Eat, food", "しょくへん", "食", None, None),
    "⻞": ("Eat, food", "しょくへん", "食", None, None),
    "⻌": ("Walk, road", "しんにょう", "", [], []),
    "辶": ("Walk, road", "しんにょう", "", [], []),
    "⻖": ("Hill", "こざとへん", "", [], []),
    "⻏": ("Village", "おおざと", "", [], []),
    "⺨": ("Animal", "けものへん", "犬", None, None),
    "⺤": ("Claw", "つめかんむり", "爪", None, None),
    "⺌": ("Small", "しょう", "小", None, None),
    "⺍": ("Little dots", "つかんむり", "", [], []),
    "⺗": ("Heart", "したごころ", "心", None, None),
    "⺕": ("Hand", "けいがしら", "", [], []),
    "氺": ("Water", "したみず", "水", None, None),
    "罒": ("Net", "あみがしら", "", [], []),
    "覀": ("Cover", "おおいかんむり", "", [], []),
    "耂": ("Old person", "おいかんむり", "老", None, None),
    "龶": ("Growing plant", "", "生", None, None),
    "王": ("King, jewel", "おうへん", "", None, None),
    "禾": ("Grain", "のぎへん", "", ["いね"], ["か"]),
    "宀": ("Roof", "うかんむり", "", [], []),
    "冖": ("Cover", "わかんむり", "", [], []),
    "亠": ("Lid", "なべぶた", "", [], []),
    "广": ("Building", "まだれ", "", [], []),
    "厂": ("Cliff", "がんだれ", "", [], []),
    "疒": ("Sickness", "やまいだれ", "", [], []),
    "尸": ("Body, house", "しかばね", "", [], []),
    "冫": ("Ice", "にすい", "氷", None, None),
    "儿": ("Legs", "ひとあし", "", [], []),
    "冂": ("Frame", "けいがまえ", "", [], []),
    "囗": ("Box, fence", "くにがまえ", "", [], []),
    "匚": ("Box", "はこがまえ", "", [], []),
    "匸": ("Hiding box", "かくしがまえ", "", [], []),
    "凵": ("Open box", "うけばこ", "", [], []),
    "勹": ("Wrap", "つつみがまえ", "", [], []),
    "卩": ("Kneeling person", "ふしづくり", "", [], []),
    "幺": ("Tiny thread", "いとがしら", "", [], []),
    "廴": ("Long stride", "えんにょう", "", [], []),
    "彳": ("Going", "ぎょうにんべん", "", [], []),
    "彡": ("Hair, decoration", "さんづくり", "", [], []),
    "攵": ("Hit, action", "のぶん", "", [], []),
    "殳": ("Weapon, hit", "るまた", "", [], []),
    "夂": ("Walking slowly", "ふゆがしら", "", [], []),
    "癶": ("Footsteps", "はつがしら", "", [], []),
    "彑": ("Pig's head", "けいがしら", "", [], []),
    "巛": ("River", "まがりがわ", "川", None, None),
    "舛": ("Dancing feet", "まいあし", "", [], []),
    "虍": ("Tiger", "とらかんむり", "", [], []),
    "隹": ("Bird", "ふるとり", "", [], []),
    "頁": ("Head", "おおがい", "", [], []),
    "厶": ("Myself, private", "む", "", [], []),
    "丿": ("Sweeping stroke", "の", "", [], []),
    "丨": ("Line", "ぼう", "", [], []),
    "丶": ("Dot", "てん", "", [], []),
    "亅": ("Hook", "はねぼう", "", [], []),
    "乙": ("Fish hook", "おつ", "", None, None),
    "寸": ("Measure, hand", "すん", "", None, None),
    "斤": ("Axe", "おのづくり", "", None, None),
    "欠": ("Yawn, lack", "あくび", "", None, None),
    "歹": ("Bones", "がつへん", "", [], []),
    "疋": ("Foot", "ひきへん", "", ["あし"], []),
    "廾": ("Two hands", "にじゅうあし", "", [], []),
    "弋": ("Stake", "しきがまえ", "", [], []),
    "戈": ("Halberd", "ほこづくり", "", ["ほこ"], ["か"]),
    "豕": ("Pig", "いのこ", "", [], []),
    "豸": ("Wild animal", "むじな", "", [], []),
    "乂": ("Cut", "", "", [], []),
    "卜": ("Fortune telling", "ぼく", "", ["うらなう"], ["ぼく"]),
    "匕": ("Spoon", "ひ", "", ["さじ"], []),
    "几": ("Table", "つくえ", "", [], []),
    "夕": ("Evening", "ゆうべ", "", None, None),
    "聿": ("Brush", "ふでづくり", "", ["ふで"], []),
    "酉": ("Sake jar", "ひよみのとり", "", [], []),
    "艮": ("Stop, stubborn", "こんづくり", "", [], []),
    "臣": ("Servant", "しん", "", None, None),
    "巾": ("Cloth", "はばへん", "", None, None),
    "韋": ("Leather", "なめしがわ", "", [], []),
    "示": ("Altar, show", "しめす", "", None, None),
    "米": ("Rice", "こめへん", "", None, None),
    "糸": ("Thread", "いとへん", "", None, None),
    "言": ("Words, say", "ごんべん", "", None, None),
    "貝": ("Shell, money", "かいへん", "", None, None),
    "金": ("Metal, gold", "かねへん", "", None, None),
    "竹": ("Bamboo", "たけかんむり", "", None, None),
    "雨": ("Rain", "あめかんむり", "", None, None),
    "門": ("Gate", "もんがまえ", "", None, None),
    "又": ("Hand, again", "また", "", None, None),
    "工": ("Craft, work", "こう", "", None, None),
    "斗": ("Ladle", "とます", "", [], ["と"]),
    "尺": ("Measure", "しゃく", "", None, None),
    "曷": ("Why", "", "", [], ["かつ"]),
}

# KANJIDIC2 meanings that make no sense to a child as a part's meaning.
JUNK = re.compile(r"radical|\*\*|\d|counter for|sign of the|zodiac|calendar sign|surname", re.I)


def kanjivg_files(arg):
    if arg:
        return {p.stem: p.read_bytes() for p in Path(arg).glob("*.svg")}
    data = urllib.request.urlopen(KANJIVG_URL).read()
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        return {Path(n).stem: zf.read(n) for n in zf.namelist() if n.endswith(".svg")}


def top_parts(group, char):
    """The first named elements below the kanji's own group (groups without a name are opened)."""
    result = []
    for child in group.findall(f"{SVG}g"):
        element = child.get(f"{KVG}element")
        found = [element] if element and element != char else top_parts(child, char)
        result += [e for e in found if e not in result]
    return result


def readings(values, limit=3):
    result = []
    for value in values or []:
        if "-" in value:  # prefix/suffix forms such as "-び" or "こ-"
            continue
        clean = value.replace(".", "")
        if clean and clean not in result:
            result.append(clean)
    return result[:limit]


def meanings(values, limit):
    result = [m for m in (values or []) if not JUNK.search(m)]
    return result[:limit]


def main():
    info = json.loads(INFO.read_text(encoding="utf-8"))
    if len(sys.argv) > 1:
        full = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    else:
        full = json.loads(urllib.request.urlopen(DATA_URL).read())
    files = kanjivg_files(sys.argv[2] if len(sys.argv) > 2 else None)

    def entry(char):
        if char in CURATED:
            meaning, name, source, kun, on = CURATED[char]
            base = info.get(source) or full.get(source) or info.get(char) or full.get(char) or {}
            kun = base.get("kun", base.get("readings_kun")) if kun is None else kun
            on = base.get("on", base.get("readings_on")) if on is None else on
            result = {"m": [meaning]}
            if name:
                result["n"] = name
            if source:
                result["f"] = source
        elif char in info:  # a jōyō kanji itself
            base = info[char]
            result = {"m": meanings(base["m"], 2)}
            kun, on = base["kun"], base["on"]
        elif char in full:  # a rarer kanji: its first meaning and its Chinese reading (a sound hint)
            base = full[char]
            result = {"m": meanings(base["meanings"], 1)}
            kun, on = [], base["readings_on"][:1]
        else:
            return None
        if not result["m"]:
            return None
        if readings(kun):
            result["k"] = readings(kun)
        if readings(on, 2):
            result["o"] = readings(on, 2)
        return result

    kanji, parts = {}, {}
    for char in info:
        svg = files.get(f"{ord(char):05x}")
        if svg is None:
            continue
        root = ET.fromstring(svg)
        top = next((g for g in root.iter(f"{SVG}g") if g.get("id") == f"kvg:{ord(char):05x}"), None)
        if top is None:
            continue
        found = []
        for part in top_parts(top, char):
            if len(part) != 1:  # e.g. "CDP-8BC4" (shapes without a Unicode character)
                continue
            if part not in parts:
                data = entry(part)
                if data is None:
                    continue
                parts[part] = data
            found.append(part)
        if found:
            kanji[char] = found

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as f:
        json.dump({"kanji": kanji, "parts": parts}, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    print(f"Wrote {OUT} ({len(kanji)} kanji, {len(parts)} parts)", file=sys.stderr)


if __name__ == "__main__":
    main()
