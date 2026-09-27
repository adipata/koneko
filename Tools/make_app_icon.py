#!/usr/bin/env python3
"""Draw the Koneko app icon (a kitten with a little ね stamp) and write the asset catalog.

Usage: python3 Tools/make_app_icon.py   (needs Pillow: pip install pillow)
Writes koneko/Assets.xcassets/AppIcon.appiconset/ with the 1024 px iOS icon (full square; the
system rounds the corners) and all macOS sizes (rounded square with margin and shadow).
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "koneko" / "Assets.xcassets" / "AppIcon.appiconset"
FONT = ROOT / "koneko" / "Resources" / "Fonts" / "KleeOne-SemiBold.ttf"
S = 2048  # draw at 2x, then downscale for smooth edges


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def draw_icon():
    # Warm gradient background (icons must be opaque squares; the system rounds the corners).
    img = Image.new("RGB", (S, S))
    top, bottom = (255, 190, 92), (255, 118, 87)
    px = ImageDraw.Draw(img)
    for y in range(S):
        px.line([(0, y), (S, y)], fill=lerp(top, bottom, y / S))

    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    white, pink, ink = (255, 255, 255, 255), (255, 160, 170, 255), (60, 45, 50, 255)

    # Ears
    d.polygon([(470, 820), (560, 330), (900, 640)], fill=white)
    d.polygon([(1578, 820), (1488, 330), (1148, 640)], fill=white)
    d.polygon([(560, 740), (600, 470), (800, 650)], fill=pink)
    d.polygon([(1488, 740), (1448, 470), (1248, 650)], fill=pink)
    # Head
    d.ellipse([370, 560, 1678, 1640], fill=white)
    # Eyes with highlights
    for cx in (780, 1268):
        d.ellipse([cx - 95, 1000, cx + 95, 1200], fill=ink)
        d.ellipse([cx - 45, 1030, cx + 5, 1085], fill=white)
    # Blush
    for cx in (620, 1428):
        d.ellipse([cx - 90, 1215, cx + 90, 1305], fill=(255, 170, 175, 170))
    # Nose and mouth
    d.polygon([(984, 1215), (1064, 1215), (1024, 1265)], fill=pink)
    d.arc([904, 1210, 1024, 1330], start=20, end=160, fill=ink, width=16)
    d.arc([1024, 1210, 1144, 1330], start=20, end=160, fill=ink, width=16)
    # Whiskers
    for side in (-1, 1):
        x0 = 1024 + side * 330
        for dy, slope in ((0, -40), (60, 0), (120, 40)):
            d.line([(x0, 1190 + dy), (x0 + side * 250, 1190 + dy + slope)], fill=(120, 105, 110, 255), width=12)

    # Soft shadow under the head
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([420, 640, 1628, 1700], fill=(120, 40, 20, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    img.paste(shadow, (0, 30), shadow)
    img.paste(layer, (0, 0), layer)

    # Red hanko-style stamp with ね
    stamp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stamp)
    box = [1430, 1430, 1830, 1830]
    sd.rounded_rectangle(box, radius=70, fill=(214, 48, 49, 255))
    sd.rounded_rectangle([b + (22 if i < 2 else -22) for i, b in enumerate(box)], radius=52, outline=(255, 235, 230, 255), width=12)
    font = ImageFont.truetype(str(FONT), 300)
    sd.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2 - 10), "ね", font=font, fill=(255, 255, 255, 255), anchor="mm")
    stamp = stamp.rotate(-8, center=((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), resample=Image.BICUBIC)
    img.paste(stamp, (0, 0), stamp)

    return img.resize((1024, 1024), Image.LANCZOS)


def mac_icon(icon):
    """macOS icons are a rounded square with margins and a shadow (Apple's 824/1024 grid)."""
    body = icon.resize((824, 824), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (824, 824), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 823, 823], radius=185, fill=255)
    body.putalpha(mask)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([100, 112, 924, 936], radius=185, fill=(0, 0, 0, 90))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(body, (100, 100))
    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icon = draw_icon()
    images = [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    icon.save(OUT / "icon-1024.png")
    mac = mac_icon(icon)
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = points * scale
            name = f"icon-mac-{points}@{scale}x.png"
            mac.resize((pixels, pixels), Image.LANCZOS).save(OUT / name)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{points}x{points}"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Wrote {len(images)} icons to {OUT}")


if __name__ == "__main__":
    main()
