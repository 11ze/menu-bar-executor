#!/usr/bin/env python3
"""
Generate all required macOS app icon sizes from source image.
"""

from PIL import Image
import json
import os

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS_DIR = os.path.join(PROJECT_DIR, "assets", "icons")
APPICONSET_DIR = os.path.join(
    PROJECT_DIR, "Resources", "Assets.xcassets", "AppIcon.appiconset"
)

ICON_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def generate_appiconset():
    source_path = os.path.join(ICONS_DIR, "AppIcon.png")
    source_img = Image.open(source_path)
    print(f"Source: {source_path} ({source_img.size[0]}x{source_img.size[1]})")

    os.makedirs(APPICONSET_DIR, exist_ok=True)

    for filename, size in ICON_SIZES:
        resized = source_img.resize((size, size), Image.Resampling.LANCZOS)
        output_path = os.path.join(APPICONSET_DIR, filename)
        resized.save(output_path, "PNG")
        print(f"  {filename} ({size}x{size})")

    sizes = ["16x16", "32x32", "128x128", "256x256", "512x512"]
    images = []
    for size in sizes:
        for scale in ["1x", "2x"]:
            filename = f"icon_{size}@2x.png" if scale == "2x" else f"icon_{size}.png"
            images.append({
                "filename": filename,
                "idiom": "mac",
                "scale": scale,
                "size": size,
            })

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(APPICONSET_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("  Contents.json updated")


def main():
    print("== AppIcon.appiconset ==")
    generate_appiconset()
    print("\nDone")


if __name__ == "__main__":
    main()
