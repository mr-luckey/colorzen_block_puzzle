"""Process ColorZen logo: transparent outer bg, generate launcher icons."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

SRC = Path(
    r"C:\Users\engin\.cursor\projects\d-Playstore-colorzen-block-puzzle\assets"
    r"\c__Users_engin_AppData_Roaming_Cursor_User_workspaceStorage_"
    r"9a684426401d8bd22a2cb3779c4a71d2_images_ChatGPT_Image_Jul_24__2026__"
    r"11_25_37_PM-78a146c5-2252-4a8b-9220-361557c9c26f.png"
)
ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "assets" / "images"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_ICONSET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"


def is_outer_black(r: int, g: int, b: int) -> bool:
    return r <= 12 and g <= 12 and b <= 12


def remove_outer_black(im: Image.Image) -> Image.Image:
    """Flood-fill from edges so only the outer black canvas becomes transparent."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    for x in range(w):
        for y in (0, h - 1):
            r, g, b, _ = px[x, y]
            if is_outer_black(r, g, b):
                visited[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y][x]:
                r, g, b, _ = px[x, y]
                if is_outer_black(r, g, b):
                    visited[y][x] = True
                    q.append((x, y))

    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        if is_outer_black(r, g, b):
            px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                rr, gg, bb, _ = px[nx, ny]
                if is_outer_black(rr, gg, bb):
                    visited[ny][nx] = True
                    q.append((nx, ny))
    return im


def to_square(im: Image.Image, pad: int = 8) -> Image.Image:
    bbox = im.getbbox()
    if bbox is None:
        raise RuntimeError("Logo became fully transparent")
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    cropped = im.crop((x0, y0, x1, y1))
    side = max(cropped.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - cropped.width) // 2
    oy = (side - cropped.height) // 2
    square.paste(cropped, (ox, oy), cropped)
    return square


def main() -> None:
    IMAGES.mkdir(parents=True, exist_ok=True)
    IOS_ICONSET.mkdir(parents=True, exist_ok=True)

    logo = to_square(remove_outer_black(Image.open(SRC)))
    logo_path = IMAGES / "app_logo.webp"
    logo.save(logo_path, "WEBP", quality=82, method=6)
    print(f"saved {logo_path} {logo.size} mode={logo.mode}")

    master = logo.resize((1024, 1024), Image.Resampling.LANCZOS)
    master_path = IMAGES / "app_icon_1024.png"
    master.save(master_path, "PNG")
    print(f"saved {master_path}")

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        dest = ANDROID_RES / folder / "ic_launcher.png"
        master.resize((size, size), Image.Resampling.LANCZOS).save(dest, "PNG")
        print(f"android {dest.name} {size}")

    ios_icons = [
        ("Icon-App-20x20@1x.png", 20),
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ]
    for name, size in ios_icons:
        img = master.resize((size, size), Image.Resampling.LANCZOS)
        dest = IOS_ICONSET / name
        # App Store 1024 icon must be opaque (no alpha).
        if "1024" in name:
            bg = Image.new("RGB", (size, size), (0, 0, 0))
            bg.paste(img, mask=img.split()[-1])
            bg.save(dest, "PNG")
        else:
            img.save(dest, "PNG")
        print(f"ios {name} {size}")

    c0 = logo.getpixel((0, 0))
    print(f"corner alpha check: {c0}")


if __name__ == "__main__":
    main()
