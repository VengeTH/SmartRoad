"""Composite app icon onto brand background so all platforms get no transparency."""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip install Pillow")
    raise

# Brand background (dark slate) - DESIGN_GUIDE.md
BG_R, BG_G, BG_B = 0x0F, 0x17, 0x2A  # #0F172A


def main():
    root = Path(__file__).resolve().parent.parent
    path = root / "assets" / "app_icon.png"
    if not path.exists():
        print(f"Not found: {path}")
        return 1

    img = Image.open(path).convert("RGBA")
    w, h = img.size

    # Create opaque background
    bg = Image.new("RGB", (w, h), (BG_R, BG_G, BG_B))
    # Composite icon on top (transparent areas become BG)
    bg.paste(img, (0, 0), img)
    # Save as PNG (opaque, no alpha channel)
    bg.save(path, "PNG")
    print(f"Updated {path} (icon composited on #{BG_R:02x}{BG_G:02x}{BG_B:02x}, no transparency)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
