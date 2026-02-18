"""Strip any white/light pixels from icon: replace with exact brand background."""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip install Pillow")
    raise

# Brand background - DESIGN_GUIDE.md
BG_R, BG_G, BG_B = 0x0F, 0x17, 0x2A  # #0F172A

# Any pixel with R,G,B all >= this becomes #0F172A (removes white, light grey, halo)
LIGHT_THRESHOLD = 180


def main():
    root = Path(__file__).resolve().parent.parent
    path = root / "assets" / "app_icon_new.png"
    out_path = root / "assets" / "app_icon.png"
    if not path.exists():
        print(f"Not found: {path}")
        return 1

    img = Image.open(path).convert("RGB")
    data = list(img.getdata())
    w, h = img.size

    new_data = []
    for item in data:
        r, g, b = item
        if r >= LIGHT_THRESHOLD and g >= LIGHT_THRESHOLD and b >= LIGHT_THRESHOLD:
            new_data.append((BG_R, BG_G, BG_B))
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(out_path, "PNG")
    print(f"Saved {out_path} (light pixels replaced with #{BG_R:02x}{BG_G:02x}{BG_B:02x})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
