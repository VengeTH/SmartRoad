"""Make white/light background and border of app icon transparent."""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip install Pillow")
    raise

# Threshold: pixels with R,G,B all >= this become transparent (removes white/light grey)
THRESHOLD = 230

def main():
    root = Path(__file__).resolve().parent.parent
    path = root / "assets" / "app_icon.png"
    if not path.exists():
        print(f"Not found: {path}")
        return 1

    img = Image.open(path)
    img = img.convert("RGBA")
    data = img.getdata()

    new_data = []
    for item in data:
        r, g, b, a = item
        # Make white and near-white (and light grey border) transparent
        if r >= THRESHOLD and g >= THRESHOLD and b >= THRESHOLD:
            new_data.append((r, g, b, 0))
        else:
            new_data.append(item)

    img.putdata(new_data)
    img.save(path, "PNG")
    print(f"Updated {path} (pixels with R,G,B >= {THRESHOLD} are now transparent)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
