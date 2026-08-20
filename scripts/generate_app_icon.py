#!/usr/bin/env python3
"""Generate the iOS AppIcon asset catalog from the approved LumaSift prism mark."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "CinaVaultIOS/Assets.xcassets/LumaSiftLogo.imageset/lumasift-prism.png"
DESTINATION = ROOT / "CinaVaultIOS/Assets.xcassets/AppIcon.appiconset"

ICON_SPECS = [
    ("Icon-20@2x.png", "iphone", "20x20", "2x", 40),
    ("Icon-20@3x.png", "iphone", "20x20", "3x", 60),
    ("Icon-29@2x.png", "iphone", "29x29", "2x", 58),
    ("Icon-29@3x.png", "iphone", "29x29", "3x", 87),
    ("Icon-40@2x.png", "iphone", "40x40", "2x", 80),
    ("Icon-40@3x.png", "iphone", "40x40", "3x", 120),
    ("Icon-60@2x.png", "iphone", "60x60", "2x", 120),
    ("Icon-60@3x.png", "iphone", "60x60", "3x", 180),
    ("Icon-1024.png", "ios-marketing", "1024x1024", "1x", 1024),
]


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Missing source mark: {SOURCE}")

    DESTINATION.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE) as source:
        image = source.convert("RGB")
        if image.width != image.height:
            raise ValueError("The LumaSift source icon must be square to preserve all content.")
        for filename, _, _, _, pixels in ICON_SPECS:
            icon = image.resize((pixels, pixels), Image.Resampling.LANCZOS)
            icon.save(DESTINATION / filename, format="PNG", optimize=True)

    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": idiom,
                "scale": scale,
                "size": size,
            }
            for filename, idiom, size, scale, _ in ICON_SPECS
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (DESTINATION / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
