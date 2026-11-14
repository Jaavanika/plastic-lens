"""Draw the PlasticLens logo (same design as website/assets/icon.svg) and
write the Android launcher icons and the website's social-share image.

    python tools/make_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
GREEN, OCEAN, DEEP = (46, 125, 79), (11, 110, 153), (6, 66, 92)
RES = ROOT / "android_app" / "android" / "app" / "src" / "main" / "res"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def gradient(size: int, a, b) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return img


def logo(size: int) -> Image.Image:
    s = size * 4  # draw large, then downsample for smooth edges
    base = gradient(s, GREEN, OCEAN).convert("RGBA")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, s - 1, s - 1), fill=255)
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    out.paste(base, mask=mask)

    d = ImageDraw.Draw(out)
    u = s / 64  # SVG units
    w = round(4 * u)
    for (x0, y0, x1, y1, x2, y2) in [(16, 24, 16, 16, 24, 16), (40, 16, 48, 16, 48, 24), (48, 40, 48, 48, 40, 48), (24, 48, 16, 48, 16, 40)]:
        d.line([(x0 * u, y0 * u), (x1 * u, y1 * u), (x2 * u, y2 * u)], fill="white", width=w, joint="curve")
    d.polygon([(32 * u, 21 * u), (41 * u, 36 * u), (23 * u, 36 * u)], outline="white", width=round(3.5 * u))
    d.ellipse((29 * u, 28 * u, 35 * u, 34 * u), fill="white")
    return out.resize((size, size), Image.Resampling.LANCZOS)


def og_image():
    w, h = 1200, 630
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w) * 0.7 + (y / h) * 0.3
            px[x, y] = tuple(round(DEEP[i] + (OCEAN[i] - DEEP[i]) * t) for i in range(3))
    img.paste(logo(220), (110, 205), logo(220))
    d = ImageDraw.Draw(img)
    try:
        big = ImageFont.truetype("segoeuib.ttf", 92)
        small = ImageFont.truetype("segoeui.ttf", 40)
    except OSError:
        big = small = ImageFont.load_default()
    d.text((380, 220), "PlasticLens", fill="white", font=big)
    d.text((385, 340), "Know your plastic. Recycle it right.", fill=(220, 238, 244), font=small)
    out = ROOT / "website" / "assets" / "og.png"
    img.save(out, optimize=True)
    return out


def main():
    for folder, size in SIZES.items():
        path = RES / f"mipmap-{folder}" / "ic_launcher.png"
        logo(size).save(path, optimize=True)
    logo(512).save(ROOT / "documentation" / "figures" / "logo.png", optimize=True)
    print("launcher icons written;", og_image())


if __name__ == "__main__":
    main()
