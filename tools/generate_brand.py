"""TussieCars brand art: menu logo and trackside billboard banner."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "Silkscreen-Regular.ttf"


def logo() -> None:
    im = Image.new("RGBA", (720, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(str(FONT), 52)
    d.text((12, 32), "TUSSIECARS", font=font, fill=(20, 12, 30, 200))
    d.text((8, 26), "TUSSIE", font=font, fill=(255, 96, 160, 255))
    w = d.textlength("TUSSIE", font=font)
    d.text((8 + w, 26), "CARS", font=font, fill=(255, 210, 59, 255))
    im.save(ROOT / "assets" / "sprites" / "logo.png")


def banner() -> None:
    # Same 256x128 layout as the Kenney billboard UVs: the sign face fills the canvas.
    im = Image.new("RGBA", (256, 128), (24, 16, 40, 255))
    d = ImageDraw.Draw(im)
    for x in range(0, 256, 16):
        d.polygon([(x, 0), (x + 8, 0), (x - 24, 128), (x - 32, 128)], fill=(40, 26, 64, 255))
    d.rectangle([0, 0, 255, 9], fill=(255, 96, 160, 255))
    d.rectangle([0, 118, 255, 127], fill=(255, 210, 59, 255))
    font = ImageFont.truetype(str(FONT), 34)
    tw = d.textlength("TUSSIE", font=font) + d.textlength("CARS", font=font)
    x0 = (256 - tw) / 2
    d.text((x0, 38), "TUSSIE", font=font, fill=(255, 96, 160, 255))
    d.text((x0 + d.textlength("TUSSIE", font=font), 38), "CARS", font=font, fill=(255, 210, 59, 255))
    small = ImageFont.truetype(str(FONT), 12)
    tag = "ARMED CLUB RACING"
    d.text(((256 - d.textlength(tag, font=small)) / 2, 88), tag, font=small, fill=(240, 236, 228, 255))
    im.save(ROOT / "assets" / "kenney" / "billboard_tankcoBanner.png")


if __name__ == "__main__":
    logo()
    banner()
