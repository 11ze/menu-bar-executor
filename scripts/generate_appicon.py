#!/usr/bin/env python3
"""
Generate all required macOS app icon sizes from source image
"""

from PIL import Image
import json
import os

# Icon sizes needed for macOS
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


def generate_contents_json():
    """Generate Contents.json for macOS AppIcon"""
    sizes = ["16x16", "32x32", "128x128", "256x256", "512x512"]
    images = []

    for size in sizes:
        for scale in ["1x", "2x"]:
            filename = f"icon_{size}@2x.png" if scale == "2x" else f"icon_{size}.png"
            images.append({
                "filename": filename,
                "idiom": "mac",
                "scale": scale,
                "size": size
            })

    return {"images": images, "info": {"author": "xcode", "version": 1}}


def main():
    # Paths
    source_path = "/Users/wangze/Library/CloudStorage/OneDrive-Personal/codes/menu-bar-exector/assets/icons/AppIcon-Option-B.png"
    output_dir = "/Users/wangze/Library/CloudStorage/OneDrive-Personal/codes/menu-bar-exector/Resources/Assets.xcassets/AppIcon.appiconset"

    # Load source image
    source_img = Image.open(source_path)
    print(f"Source image: {source_img.size[0]}x{source_img.size[1]}")

    # Generate all sizes
    for filename, size in ICON_SIZES:
        resized = source_img.resize((size, size), Image.Resampling.LANCZOS)
        output_path = os.path.join(output_dir, filename)
        resized.save(output_path, "PNG")
        print(f"✓ {filename} ({size}x{size})")

    # Write Contents.json
    contents = generate_contents_json()
    contents_path = os.path.join(output_dir, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"\n✓ Updated Contents.json")

    print(f"\n所有图标已生成到: {output_dir}")


if __name__ == "__main__":
    main()
