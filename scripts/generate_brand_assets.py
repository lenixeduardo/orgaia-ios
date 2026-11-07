#!/usr/bin/env python3
"""Generate the opaque Foteka V2 iOS AppIcon from the checked-in SVG.

Setup: python3 -m pip install cairosvg
Run: python3 scripts/generate_brand_assets.py
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Brand" / "FotekaLayerIcon.svg"
OUT = ROOT / "App" / "Assets.xcassets" / "AppIcon.appiconset"

def main():
    import cairosvg
    OUT.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(url=str(SRC), write_to=str(OUT / "AppIcon.png"), output_width=1024, output_height=1024)
    (OUT / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1}
    }, indent=2) + "\n", encoding="utf-8")
    print("Generated Foteka V2 AppIcon, 1024x1024")
if __name__ == "__main__":
    main()
