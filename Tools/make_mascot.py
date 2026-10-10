#!/usr/bin/env python3
"""Draw the Koneko mascot (an anime-style kitten, transparent background) for the splash
screen and About page. Writes koneko/Assets.xcassets/Mascot.imageset/.

Usage: python3 Tools/make_mascot.py   (needs Pillow)
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "koneko" / "Assets.xcassets" / "Mascot.imageset"
S = 2048


def main():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    white, ink, pink = (255, 255, 255, 255), (58, 42, 52, 255), (255, 158, 170, 255)
    outline = (240, 150, 110, 255)

    # Soft shadow
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([380, 1680, 1668, 1860], fill=(120, 60, 40, 70))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(40)))

    # Ears (with outline)
    for pts, inner in (
        ([(420, 900), (520, 300), (930, 640)], [(520, 800), (570, 450), (820, 650)]),
        ([(1628, 900), (1528, 300), (1118, 640)], [(1528, 800), (1478, 450), (1228, 650)]),
    ):
        d.polygon(pts, fill=outline)
        shrunk = [(x + (1024 - x) * 0.04, y + 25) for x, y in pts]
        d.polygon(shrunk, fill=white)
        d.polygon(inner, fill=pink)

    # Head
    d.ellipse([290, 560, 1758, 1760], fill=outline)
    d.ellipse([310, 580, 1738, 1740], fill=white)
    # Little forehead stripes (tabby)
    for dx in (-90, 0, 90):
        d.rounded_rectangle([1024 + dx - 22, 640, 1024 + dx + 22, 800], radius=22, fill=(255, 190, 140, 255))

    # Big anime eyes: dark iris, gradient-ish ring, two highlights
    for cx in (740, 1308):
        d.ellipse([cx - 150, 1000, cx + 150, 1330], fill=ink)
        d.ellipse([cx - 110, 1120, cx + 110, 1320], fill=(110, 70, 160, 255))
        d.ellipse([cx - 70, 1180, cx + 70, 1310], fill=(170, 120, 220, 255))
        d.ellipse([cx - 95, 1035, cx - 5, 1125], fill=white)
        d.ellipse([cx + 40, 1180, cx + 85, 1225], fill=white)
    # Blush with little lines
    for cx in (600, 1448):
        d.ellipse([cx - 110, 1340, cx + 110, 1440], fill=(255, 150, 160, 150))
        for k in (-40, 0, 40):
            d.line([(cx + k - 15, 1410), (cx + k + 15, 1370)], fill=(255, 110, 130, 200), width=10)
    # Nose and cat mouth
    d.polygon([(994, 1350), (1054, 1350), (1024, 1390)], fill=pink)
    d.arc([914, 1340, 1024, 1450], start=20, end=160, fill=ink, width=18)
    d.arc([1024, 1340, 1134, 1450], start=20, end=160, fill=ink, width=18)
    # Whiskers
    for side in (-1, 1):
        x0 = 1024 + side * 560
        for dy, slope in ((0, -45), (60, 0), (120, 45)):
            d.line([(x0, 1170 + dy), (x0 + side * 260, 1170 + dy + slope)], fill=(150, 130, 135, 255), width=12)
    # Sparkles
    for x, y, r in ((1700, 420, 70), (330, 470, 45), (1820, 760, 35)):
        d.polygon([(x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y), (x + r * 0.28, y + r * 0.28),
                   (x, y + r), (x - r * 0.28, y + r * 0.28), (x - r, y), (x - r * 0.28, y - r * 0.28)],
                  fill=(255, 210, 90, 255))

    OUT.mkdir(parents=True, exist_ok=True)
    img.resize((1024, 1024), Image.LANCZOS).save(OUT / "mascot.png")
    contents = {"images": [{"filename": "mascot.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Wrote {OUT / 'mascot.png'}")


if __name__ == "__main__":
    main()
