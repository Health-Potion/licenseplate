"""
generate_plate_textures.py
Generates white (front) and yellow (rear) Mauritius plate base textures.

Requirements:
    pip install Pillow

Output:
    plate_white.png   — front plate background (white, black border)
    plate_yellow.png  — rear plate background  (yellow, black border)

These PNGs then need to be imported into vehshare.ytd using OpenIV:
    1. Open OpenIV → GTA V → pc/textures/vehshare.ytd
    2. Edit mode → import plate_white.png  as  plateback2  (style 0 — white)
    3. import plate_yellow.png             as  plateback1  (style 1 — yellow)
    4. Save & rebuild archive

Or place the exported vehshare.ytd in:
    mu-licenseplate/stream/vehshare.ytd
FiveM will stream it automatically and override the default plate textures.

Notes:
- The game renders the registration number text on top of the base texture.
- No text should be drawn here — keep backgrounds clean.
- Charles Wright font is baked into a separate glyph texture (vehplate.ytd).
  Replacing that requires a custom font texture (see README).
"""

from PIL import Image, ImageDraw

# GTA5 plate texture dimensions (must match original vehshare.ytd size)
WIDTH  = 512
HEIGHT = 256

BORDER       = 12      # black border thickness (px)
BORDER_COLOR = (0, 0, 0)
SCREW_RADIUS = 8       # mounting screw hole radius
SCREW_COLOR  = (180, 180, 180)


def draw_plate(bg_color: tuple, filename: str):
    img  = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background fill
    draw.rectangle([0, 0, WIDTH - 1, HEIGHT - 1], fill=bg_color)

    # Black border
    for t in range(BORDER):
        draw.rectangle([t, t, WIDTH - 1 - t, HEIGHT - 1 - t],
                       outline=BORDER_COLOR)

    # Screw holes (four corners, inset from border)
    inset = BORDER + 18
    for cx, cy in [
        (inset,          inset),
        (WIDTH - inset,  inset),
        (inset,          HEIGHT - inset),
        (WIDTH - inset,  HEIGHT - inset),
    ]:
        draw.ellipse(
            [cx - SCREW_RADIUS, cy - SCREW_RADIUS,
             cx + SCREW_RADIUS, cy + SCREW_RADIUS],
            fill=SCREW_COLOR, outline=BORDER_COLOR
        )

    img.save(filename)
    print(f"Saved: {filename}  ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    # Front plate — white background
    draw_plate(bg_color=(255, 255, 255), filename="plate_white.png")

    # Rear plate — yellow background  (Mauritius rear spec)
    draw_plate(bg_color=(255, 214, 0),  filename="plate_yellow.png")

    print("\nNext steps:")
    print("  1. Open OpenIV → Tools → ASI Manager → make sure OpenIV.ASI is installed")
    print("  2. Navigate to: GTA V / pc / textures / vehshare.ytd")
    print("  3. Enter Edit Mode")
    print("  4. Import plate_white.png  → replace texture named  plateback2")
    print("  5. Import plate_yellow.png → replace texture named  plateback1")
    print("  6. Save → export the modified vehshare.ytd")
    print("  7. Place it in:  mu-licenseplate/stream/vehshare.ytd")
    print("  8. FiveM will stream it automatically — no client mod needed.")
