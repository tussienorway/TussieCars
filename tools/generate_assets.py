#!/usr/bin/env python3
"""Original pixel-art and chiptune assets for TussieCars.

Nothing here is taken from Super Cars II. Silkscreen is bundled under the OFL.
"""

from __future__ import annotations

import math
import shutil
import struct
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
FONT_SRC = Path("/tmp/Silkscreen-Regular.ttf")
OFL_SRC = Path("/tmp/OFL.txt")


def rot(x: float, y: float, deg: float, cx: float = 96, cy: float = 96):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    # Clockwise in a y-down image, matching Godot's Vector2.from_angle.
    rx = x * ca - y * sa
    ry = x * sa + y * ca
    return (cx + rx, cy + ry)


def blot(draw: ImageDraw.ImageDraw, pts, ang, fill, ox=0, oy=0):
    draw.polygon([rot(x + ox, y + oy, ang) for x, y in pts], fill=fill)


def outlined(draw, pts, ang, fill, outline=(12, 10, 16, 255)):
    for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, 2), (-2, 2), (2, -2)):
        blot(draw, pts, ang, outline, dx, dy)
    blot(draw, pts, ang, fill)


def wheel(draw, x, y, ang, length=18, width=9):
    pts = [
        (x + length / 2, y - width / 2),
        (x + length / 2, y + width / 2),
        (x - length / 2, y + width / 2),
        (x - length / 2, y - width / 2),
    ]
    outlined(draw, pts, ang, (28, 28, 32, 255), (8, 8, 10, 255))
    hub = [
        (x + 4, y - 3),
        (x + 4, y + 3),
        (x - 4, y + 3),
        (x - 4, y - 3),
    ]
    blot(draw, hub, ang, (186, 186, 196, 255))


def lights(draw, ang, nose_x, tail_x, half_y):
    for s in (-1, 1):
        blot(
            draw,
            [(nose_x, s * half_y - 2), (nose_x + 7, s * half_y - 1), (nose_x + 7, s * half_y + 3), (nose_x, s * half_y + 2)],
            ang,
            (255, 236, 150, 255),
        )
        blot(
            draw,
            [(tail_x, s * (half_y - 1)), (tail_x - 6, s * (half_y - 2)), (tail_x - 6, s * (half_y + 3)), (tail_x, s * (half_y + 2))],
            ang,
            (220, 40, 48, 255),
        )


BODIES = {
    "dart": {
        "hull": [(-46, -16), (-30, -20), (18, -18), (48, -6), (52, 0), (48, 6), (18, 18), (-30, 20), (-46, 16)],
        "cabin": [(4, -11), (22, -4), (22, 4), (2, 11), (-18, 8), (-18, -8)],
        "stripe": [(-28, -3), (36, -3), (36, 3), (-28, 3)],
        "wheels": [(-18, -20), (16, -20), (-18, 20), (16, 20)],
        "nose": 46,
        "tail": -44,
        "light_y": 8,
    },
    "viper": {
        "hull": [(-50, -14), (-20, -16), (10, -14), (40, -8), (58, 0), (40, 8), (10, 14), (-20, 16), (-50, 14)],
        "cabin": [(-6, -9), (14, -3), (14, 3), (-8, 9), (-24, 6), (-24, -6)],
        "stripe": [(-40, -2), (44, -2), (44, 2), (-40, 2)],
        "wheels": [(-22, -18), (20, -18), (-22, 18), (20, 18)],
        "nose": 52,
        "tail": -48,
        "light_y": 6,
    },
    "mule": {
        "hull": [(-42, -22), (28, -22), (40, -14), (40, 14), (28, 22), (-42, 22), (-48, 12), (-48, -12)],
        "cabin": [(-8, -14), (16, -12), (18, 0), (16, 12), (-8, 14), (-20, 10), (-20, -10)],
        "stripe": [(-36, -4), (24, -4), (24, 4), (-36, 4)],
        "wheels": [(-20, -24), (16, -24), (-20, 24), (16, 24)],
        "nose": 36,
        "tail": -46,
        "light_y": 12,
        "bull": [ (40, -12), (48, -12), (48, 12), (40, 12) ],
    },
    "fang": {
        "hull": [(-40, -20), (8, -18), (36, -10), (50, -2), (50, 2), (36, 10), (8, 18), (-40, 20)],
        "cabin": [(-2, -8), (16, -3), (16, 3), (-4, 8), (-16, 6), (-16, -6)],
        "stripe": [(-30, -3), (28, -3), (28, 3), (-30, 3)],
        "wheels": [(-16, -20), (18, -20), (-16, 20), (18, 20)],
        "nose": 46,
        "tail": -38,
        "light_y": 7,
        "wing": [(-48, -24), (-40, -24), (-40, 24), (-48, 24)],
        "wing_post": [(-40, -4), (-28, -4), (-28, 4), (-40, 4)],
    },
}

PAINTS = {
    "cyan": ((28, 196, 198, 255), (236, 244, 242, 255), (18, 40, 52, 255)),
    "white": ((232, 236, 240, 255), (48, 120, 186, 255), (20, 28, 38, 255)),
    "red": ((186, 36, 46, 255), (24, 24, 28, 255), (255, 214, 150, 255)),
    "blackred": ((32, 28, 34, 255), (176, 32, 42, 255), (240, 196, 110, 255)),
    "olive": ((96, 112, 58, 255), (214, 156, 42, 255), (28, 32, 22, 255)),
    "yellow": ((228, 180, 36, 255), (32, 32, 36, 255), (90, 48, 18, 255)),
    "orange": ((224, 104, 32, 255), (20, 36, 70, 255), (255, 226, 180, 255)),
    "blue": ((36, 96, 188, 255), (220, 228, 236, 255), (12, 22, 40, 255)),
    "violet": ((124, 62, 186, 255), (22, 18, 32, 255), (255, 150, 196, 255)),
    "green": ((32, 146, 78, 255), (236, 240, 232, 255), (10, 40, 24, 255)),
}


def render_car_sheet(style: str, paint: str) -> Image.Image:
    spec = BODIES[style]
    primary, secondary, glass = PAINTS[paint]
    frames = []
    for i in range(16):
        ang = i * 22.5
        hi = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
        d = ImageDraw.Draw(hi)
        for wx, wy in spec["wheels"]:
            wheel(d, wx, wy, ang, 20 if style == "mule" else 16, 10 if style == "mule" else 8)
        if "wing" in spec:
            outlined(d, spec["wing"], ang, secondary)
            blot(d, spec["wing_post"], ang, primary)
        if "bull" in spec:
            outlined(d, spec["bull"], ang, (70, 74, 80, 255))
        outlined(d, spec["hull"], ang, primary)
        blot(d, spec["stripe"], ang, secondary)
        outlined(d, spec["cabin"], ang, glass, (8, 10, 16, 255))
        # windshield glint
        cabin = spec["cabin"]
        glint = [cabin[0], cabin[1], ((cabin[1][0] + cabin[2][0]) / 2, (cabin[1][1] + cabin[2][1]) / 2)]
        blot(d, glint, ang, (255, 255, 255, 90))
        lights(d, ang, spec["nose"], spec["tail"], spec["light_y"])
        graded = _sun_grade(hi)
        small = graded.resize((96, 96), Image.Resampling.LANCZOS)
        frames.append(small)
    sheet = Image.new("RGBA", (96 * 16, 96), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * 48, 0), frame)
    return sheet


def _sun_grade(im: Image.Image) -> Image.Image:
    """Light from the north-west so every facing reads as one sun."""
    arr = np.array(im).astype(np.float32)
    height, width, _ = arr.shape
    ys = np.linspace(22.0, -26.0, height)[:, None, None]
    xs = np.linspace(12.0, -16.0, width)[None, :, None]
    mask = arr[:, :, 3:4] > 20.0
    arr[:, :, :3] = np.clip(arr[:, :, :3] + np.where(mask, ys + xs, 0.0), 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def save_grade_fx():
    out = ASSETS / "sprites" / "fx"
    out.mkdir(parents=True, exist_ok=True)
    pix = np.zeros((48, 96, 4), np.float32)
    yy, xx = np.mgrid[0:48, 0:96]
    nx = (xx - 48) / 46.0
    ny = (yy - 24) / 20.0
    fall = np.clip(1.0 - (nx * nx + ny * ny), 0, 1) ** 1.6
    pix[:, :, 3] = fall * 150.0
    Image.fromarray(pix.astype(np.uint8), "RGBA").save(out / "soft_shadow.png")
    vig = np.zeros((256, 256, 4), np.float32)
    cy, cx = np.mgrid[0:256, 0:256]
    dist = np.sqrt(((cx - 128) / 128.0) ** 2 + ((cy - 128) / 150.0) ** 2)
    alpha = np.clip((dist - 0.45) / 0.7, 0, 1) ** 1.35
    vig[:, :, 3] = alpha * 210.0
    Image.fromarray(vig.astype(np.uint8), "RGBA").save(out / "vignette.png")


def save_cars():
    out = ASSETS / "sprites" / "cars"
    out.mkdir(parents=True, exist_ok=True)
    lineup = []
    for style in BODIES:
        for paint in PAINTS:
            sheet = render_car_sheet(style, paint)
            sheet.save(out / f"{style}_{paint}.png")
        lineup.append(render_car_sheet(style, {"dart": "cyan", "viper": "red", "mule": "olive", "fang": "violet"}[style]).crop((0, 0, 96, 96)))
    preview = Image.new("RGBA", (96 * len(lineup) + 24, 120), (18, 20, 28, 255))
    for i, frame in enumerate(lineup):
        preview.paste(frame, (12 + i * 96, 12), frame)
    preview.save(ROOT / "docs" / "previews" / "cars.png")


def _shade(base, d):
    return tuple(int(max(0, min(255, c + d))) for c in base) + ((255,) if len(base) == 3 else ())


def sprite_canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def draw_palm():
    im = sprite_canvas(40, 64)
    d = ImageDraw.Draw(im)
    d.polygon([(20, 60), (16, 34), (22, 30), (26, 58)], fill=(110, 72, 40, 255))
    d.polygon([(18, 48), (14, 40), (20, 42)], fill=(92, 60, 32, 255))
    for ang, col in ((-70, (34, 140, 62)), (-30, (46, 160, 70)), (0, (28, 120, 54)), (30, (52, 168, 74)), (70, (30, 128, 58))):
        a = math.radians(ang)
        x2 = 20 + math.sin(a) * 18
        y2 = 30 - math.cos(a) * 16
        d.line([(20, 32), (x2, y2)], fill=col + (255,), width=3)
        d.ellipse([x2 - 3, y2 - 2, x2 + 4, y2 + 3], fill=col + (255,))
    d.ellipse([16, 28, 24, 36], fill=(40, 110, 52, 255))
    return im


def draw_cactus():
    im = sprite_canvas(32, 48)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([12, 14, 20, 44], radius=4, fill=(48, 130, 62, 255), outline=(16, 60, 28, 255))
    d.rounded_rectangle([4, 20, 14, 28], radius=3, fill=(42, 120, 58, 255), outline=(16, 60, 28, 255))
    d.rounded_rectangle([18, 18, 28, 26], radius=3, fill=(56, 146, 70, 255), outline=(16, 60, 28, 255))
    d.line([(6, 22), (6, 12)], fill=(42, 120, 58, 255), width=4)
    d.line([(26, 20), (26, 10)], fill=(56, 146, 70, 255), width=4)
    for x, y in ((14, 20), (17, 28), (15, 36), (8, 24), (24, 22)):
        d.point((x, y), fill=(210, 220, 180, 255))
    return im


def draw_rock():
    im = sprite_canvas(36, 28)
    d = ImageDraw.Draw(im)
    d.polygon([(4, 22), (8, 10), (16, 6), (28, 10), (33, 20), (24, 26), (10, 26)], fill=(120, 116, 110, 255), outline=(48, 46, 44, 255))
    d.polygon([(10, 14), (16, 8), (22, 14), (14, 16)], fill=(168, 164, 156, 255))
    return im


def draw_crate():
    im = sprite_canvas(28, 28)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 4, 24, 24], fill=(148, 96, 48, 255), outline=(70, 42, 22, 255))
    d.line([(3, 4), (24, 24)], fill=(92, 58, 30, 255), width=2)
    d.line([(24, 4), (3, 24)], fill=(92, 58, 30, 255), width=2)
    d.rectangle([3, 4, 24, 8], fill=(176, 124, 64, 255))
    return im


def draw_lamp():
    im = sprite_canvas(20, 52)
    d = ImageDraw.Draw(im)
    d.rectangle([9, 16, 12, 48], fill=(70, 74, 82, 255))
    d.rectangle([4, 46, 16, 50], fill=(50, 52, 58, 255))
    d.polygon([(2, 16), (10, 4), (18, 16)], fill=(40, 44, 52, 255))
    d.ellipse([5, 10, 15, 18], fill=(255, 214, 90, 255))
    return im


def draw_tank():
    im = sprite_canvas(44, 36)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([6, 10, 38, 28], radius=8, fill=(86, 92, 100, 255), outline=(30, 32, 38, 255))
    d.ellipse([28, 8, 42, 30], fill=(110, 116, 124, 255), outline=(30, 32, 38, 255))
    d.rectangle([10, 16, 30, 20], fill=(196, 64, 48, 255))
    d.rectangle([4, 22, 10, 30], fill=(60, 64, 70, 255))
    return im


def draw_buoy():
    im = sprite_canvas(18, 28)
    d = ImageDraw.Draw(im)
    d.polygon([(9, 26), (3, 18), (15, 18)], fill=(40, 70, 90, 255))
    d.ellipse([3, 4, 15, 20], fill=(220, 48, 42, 255), outline=(80, 16, 16, 255))
    d.rectangle([3, 10, 15, 14], fill=(240, 236, 228, 255))
    return im


def draw_building():
    im = sprite_canvas(52, 78)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 18, 46, 74], fill=(42, 46, 56, 255), outline=(16, 18, 24, 255))
    d.polygon([(4, 20), (26, 4), (48, 20)], fill=(58, 62, 74, 255))
    d.rectangle([22, 8, 30, 20], fill=(70, 50, 48, 255))
    for y in range(28, 68, 10):
        for x in range(12, 40, 10):
            lit = (x + y) % 20 == 2
            d.rectangle([x, y, x + 5, y + 6], fill=(255, 196, 96, 255) if lit else (20, 24, 34, 255))
    return im


def save_decor():
    out = ASSETS / "sprites" / "decor"
    out.mkdir(parents=True, exist_ok=True)
    arts = {
        "palm": draw_palm(),
        "cactus": draw_cactus(),
        "rock": draw_rock(),
        "crate": draw_crate(),
        "lamp": draw_lamp(),
        "tank": draw_tank(),
        "buoy": draw_buoy(),
        "building": draw_building(),
    }
    for name, im in arts.items():
        im.save(out / f"{name}.png")
    return arts


def save_fx():
    out = ASSETS / "sprites" / "fx"
    out.mkdir(parents=True, exist_ok=True)
    exp = Image.new("RGBA", (64 * 8, 64), (0, 0, 0, 0))
    for i in range(8):
        frame = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(frame)
        t = i / 7
        r = 6 + int(26 * t)
        alpha = int(255 * (1 - t * 0.85))
        d.ellipse([32 - r, 32 - r, 32 + r, 32 + r], fill=(255, 150, 40, alpha))
        r2 = max(2, r - 8)
        d.ellipse([32 - r2, 32 - r2, 32 + r2, 32 + r2], fill=(255, 236, 160, alpha))
        if i > 2:
            s = 10 + i * 3
            d.ellipse([32 - s, 36 - s // 2, 32 + s, 36 + s], fill=(60, 60, 64, int(alpha * 0.55)))
        exp.paste(frame, (i * 64, 0), frame)
    exp.save(out / "explosion.png")

    smoke = Image.new("RGBA", (16 * 4, 16), (0, 0, 0, 0))
    for i in range(4):
        frame = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(frame)
        a = 180 - i * 40
        rad = 3 + i * 2
        d.ellipse([8 - rad, 8 - rad, 8 + rad, 8 + rad], fill=(210, 210, 214, a))
        smoke.paste(frame, (i * 16, 0), frame)
    smoke.save(out / "smoke.png")

    spark = Image.new("RGBA", (12 * 4, 12), (0, 0, 0, 0))
    for i in range(4):
        frame = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        d = ImageDraw.Draw(frame)
        d.line([(1, 6), (11, 6)], fill=(255, 220, 120, 255 - i * 50), width=2)
        d.line([(6, 1), (6, 11)], fill=(255, 240, 180, 220 - i * 40), width=1)
        spark.paste(frame, (i * 12, 0), frame)
    spark.save(out / "spark.png")

    missile = sprite_canvas(20, 8)
    d = ImageDraw.Draw(missile)
    d.polygon([(2, 4), (6, 1), (16, 1), (18, 4), (16, 7), (6, 7)], fill=(210, 214, 220, 255), outline=(20, 20, 24, 255))
    d.rectangle([4, 3, 10, 5], fill=(180, 40, 36, 255))
    d.polygon([(16, 2), (20, 4), (16, 6)], fill=(255, 170, 60, 255))
    missile.save(out / "missile.png")

    mine = sprite_canvas(16, 16)
    d = ImageDraw.Draw(mine)
    d.ellipse([1, 1, 14, 14], fill=(50, 54, 62, 255), outline=(16, 16, 18, 255))
    d.ellipse([6, 5, 10, 9], fill=(255, 70, 60, 255))
    d.line([(8, 1), (8, 4)], fill=(20, 20, 22, 255))
    d.line([(8, 12), (8, 15)], fill=(20, 20, 22, 255))
    d.line([(1, 8), (4, 8)], fill=(20, 20, 22, 255))
    d.line([(12, 8), (15, 8)], fill=(20, 20, 22, 255))
    mine.save(out / "mine.png")

    shadow = sprite_canvas(32, 14)
    d = ImageDraw.Draw(shadow)
    d.ellipse([1, 2, 30, 12], fill=(0, 0, 0, 140))
    shadow.save(out / "shadow.png")

    def icon():
        im = sprite_canvas(18, 18)
        draw = ImageDraw.Draw(im)
        draw.rounded_rectangle([0, 0, 17, 17], radius=3, fill=(16, 18, 26, 230), outline=(255, 196, 64, 255))
        return im, draw

    missile_icon, missile_draw = icon()
    missile_draw.polygon([(3, 9), (11, 4), (11, 14)], fill=(255, 214, 80, 255))
    missile_draw.rectangle([8, 6, 14, 12], fill=(214, 224, 232, 255))
    missile_draw.rectangle([13, 7, 16, 11], fill=(230, 70, 36, 255))
    missile_icon.save(out / "pickup_missile.png")
    boost_icon, boost_draw = icon()
    boost_draw.polygon([(9, 2), (14, 9), (10, 9), (13, 16), (4, 8), (8, 8)], fill=(255, 148, 36, 255))
    boost_draw.polygon([(8, 5), (11, 9), (8, 9), (10, 13), (5, 8)], fill=(255, 226, 140, 255))
    boost_icon.save(out / "pickup_boost.png")
    mine_icon, mine_draw = icon()
    mine_draw.ellipse([5, 5, 12, 12], fill=(90, 92, 102, 255), outline=(220, 64, 48, 255))
    mine_draw.line([(8, 1), (8, 5)], fill=(220, 64, 48, 255))
    mine_draw.line([(8, 12), (8, 16)], fill=(220, 64, 48, 255))
    mine_draw.line([(1, 8), (5, 8)], fill=(220, 64, 48, 255))
    mine_draw.line([(12, 8), (16, 8)], fill=(220, 64, 48, 255))
    mine_icon.save(out / "pickup_mine.png")
    repair_icon, repair_draw = icon()
    repair_draw.rectangle([7, 3, 10, 14], fill=(72, 210, 120, 255))
    repair_draw.rectangle([3, 7, 14, 10], fill=(72, 210, 120, 255))
    repair_icon.save(out / "pickup_repair.png")


def save_icon():
    im = Image.new("RGBA", (256, 256), (16, 18, 26, 255))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([16, 16, 240, 240], radius=28, fill=(22, 28, 40, 255), outline=(240, 160, 32, 255), width=8)
    # chunky car
    d.polygon([(40, 150), (70, 110), (150, 100), (210, 120), (220, 150), (190, 168), (60, 168)], fill=(32, 190, 196, 255))
    d.polygon([(100, 112), (150, 108), (160, 132), (96, 136)], fill=(18, 36, 48, 255))
    d.ellipse([70, 150, 110, 190], fill=(20, 20, 24, 255))
    d.ellipse([160, 150, 200, 190], fill=(20, 20, 24, 255))
    d.ellipse([82, 162, 98, 178], fill=(200, 200, 206, 255))
    d.ellipse([172, 162, 188, 178], fill=(200, 200, 206, 255))
    d.rectangle([200, 128, 224, 140], fill=(255, 220, 120, 255))
    im.save(ASSETS / "icon.png")
    im.save(ASSETS / "icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    if FONT_SRC.exists():
        logo = Image.new("RGBA", (720, 120), (0, 0, 0, 0))
        ld = ImageDraw.Draw(logo)
        font = ImageFont.truetype(str(FONT_SRC), 48)
        ld.text((8, 28), "TUSSIECARS", font=font, fill=(244, 239, 228, 255))
        logo.save(ASSETS / "sprites" / "logo.png")


def _write_wav(path: Path, samples: np.ndarray, rate: int = 22050):
    samples = np.asarray(samples, dtype=np.float64)
    peak = float(np.max(np.abs(samples))) if samples.size else 1.0
    if peak < 1e-8:
        peak = 1.0
    pcm = np.clip(samples / peak * 0.9, -1, 1)
    ints = (pcm * 32767).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(ints.tobytes())


def _env(n, rate, attack=0.01, release=0.05):
    t = np.ones(n, dtype=np.float64)
    a = max(1, int(attack * rate))
    r = max(1, int(release * rate))
    if a < n:
        t[:a] = np.linspace(0, 1, a)
    if r < n:
        t[-r:] *= np.linspace(1, 0, r)
    return t


def save_audio():
    out = ASSETS / "audio"
    rate = 22050

    def tone(freq, dur, vol=0.4, kind="square", duty=0.5, attack=0.005, release=0.04):
        n = int(rate * dur)
        tt = np.arange(n) / rate
        ph = (tt * freq) % 1.0
        if kind == "square":
            wave_s = np.where(ph < duty, 1.0, -1.0)
        elif kind == "tri":
            wave_s = 2 * np.abs(2 * ph - 1) - 1
        else:
            wave_s = np.sin(2 * np.pi * ph)
        return wave_s * _env(n, rate, attack, release) * vol

    def noise(dur, vol=0.5, decay=6.0):
        n = int(rate * dur)
        rng = np.random.default_rng(3)
        env = np.exp(-np.arange(n) / rate * decay)
        return rng.uniform(-1, 1, n) * env * vol

    _write_wav(out / "ui_click.wav", tone(880, 0.045, 0.35, "square", release=0.02))
    _write_wav(out / "ui_back.wav", tone(320, 0.07, 0.3, "square", release=0.03))
    _write_wav(out / "countdown.wav", tone(660, 0.16, 0.4, "square"))
    go = np.concatenate([tone(880, 0.08, 0.45, "square", release=0.02), tone(1320, 0.18, 0.45, "square")])
    _write_wav(out / "go.wav", go)
    sweep_n = int(rate * 0.16)
    tt = np.arange(sweep_n) / rate
    freq = np.linspace(900, 280, sweep_n)
    ph = np.cumsum(freq) / rate
    missile = np.where((ph % 1) < 0.5, 1.0, -1.0) * _env(sweep_n, rate, 0.002, 0.04) * 0.45
    _write_wav(out / "missile.wav", missile)
    freq2 = np.linspace(420, 140, sweep_n)
    ph2 = np.cumsum(freq2) / rate
    rear = np.where((ph2 % 1) < 0.35, 1.0, -1.0) * _env(sweep_n, rate, 0.002, 0.05) * 0.4
    _write_wav(out / "rear_missile.wav", rear)
    thud = tone(140, 0.12, 0.5, "sine", release=0.08)
    grit = noise(0.12, 0.15, 20)
    if grit.size < thud.size:
        grit = np.pad(grit, (0, thud.size - grit.size))
    _write_wav(out / "mine_drop.wav", thud + grit[: thud.size])
    boom = noise(0.55, 0.8, 5.5)
    boom[: int(rate * 0.08)] += tone(90, 0.08, 0.6, "sine", release=0.04)[: int(rate * 0.08)]
    _write_wav(out / "explosion.wav", boom)
    crash_n = noise(0.28, 0.7, 10)
    crash_t = tone(80, 0.28, 0.4, "sine")
    _write_wav(out / "crash.wav", crash_n + crash_t[: crash_n.size])
    pick = np.concatenate([tone(660, 0.06, 0.3, "square", release=0.02), tone(990, 0.1, 0.3, "square")])
    _write_wav(out / "pickup.wav", pick)
    _write_wav(out / "buy.wav", np.concatenate([tone(523, 0.07, 0.3, "square"), tone(784, 0.12, 0.3, "square")]))
    _write_wav(out / "denied.wav", tone(180, 0.16, 0.4, "square", duty=0.25))
    _write_wav(out / "finish.wav", np.concatenate([
        tone(523, 0.1, 0.35, "square"),
        tone(659, 0.1, 0.35, "square"),
        tone(784, 0.22, 0.4, "square"),
    ]))
    _write_wav(out / "warning.wav", np.concatenate([tone(440, 0.08, 0.35, "square"), np.zeros(int(rate * 0.05)), tone(440, 0.08, 0.35, "square")]))
    screech = noise(0.35, 0.35, 3.0)
    # band-ish by differencing
    screech = np.convolve(screech, [0.5, -0.5], mode="same")
    _write_wav(out / "screech.wav", screech)

    n = rate  # 1 second, 48 cycles exactly
    tt = np.arange(n) / rate
    f = 48.0
    ph = tt * f
    engine = np.where((ph % 1) < 0.5, 1.0, -1.0)
    engine += 0.45 * np.where(((ph * 2) % 1) < 0.5, 1.0, -1.0)
    engine += 0.2 * np.sin(2 * np.pi * ph * 3)
    _write_wav(out / "engine.wav", engine * 0.45)

    songs = {
        "music_menu": (96, [57, 60, 64, 60, 65, 64, 62, 60], [45, 45, 48, 48], 0.22),
        "music_coastal": (132, [64, 67, 69, 67, 72, 69, 67, 64], [40, 40, 45, 43], 0.28),
        "music_desert": (126, [62, 65, 69, 67, 74, 69, 65, 62], [38, 38, 43, 41], 0.28),
        "music_industrial": (140, [52, 55, 59, 55, 64, 59, 55, 52], [36, 36, 40, 36], 0.3),
    }
    for name, (bpm, lead, bass, vol) in songs.items():
        _write_wav(out / f"{name}.wav", _song(rate, bpm, lead, bass, vol))


def _midi(m):
    return 440.0 * (2 ** ((m - 69) / 12))


def _song(rate, bpm, lead_degrees, bass_degrees, vol):
    beat = 60.0 / bpm
    eighth = beat / 2
    bars = 8
    total = bars * 8 * eighth
    n = int(rate * total)
    buf = np.zeros(n, dtype=np.float64)
    rng = np.random.default_rng(bpm)

    def add(start, dur, freq, amp, kind="square", duty=0.5):
        i0 = int(start * rate)
        i1 = min(n, int((start + dur) * rate))
        if i1 <= i0:
            return
        tt = np.arange(i1 - i0) / rate
        ph = (tt * freq) % 1.0
        if kind == "square":
            w = np.where(ph < duty, 1.0, -1.0)
        elif kind == "tri":
            w = 2 * np.abs(2 * ph - 1) - 1
        else:
            w = np.sin(2 * np.pi * ph)
        env = _env(i1 - i0, rate, 0.01, min(0.06, dur * 0.4))
        buf[i0:i1] += w * env * amp

    step = eighth
    for i in range(bars * 8):
        t = i * step
        note = lead_degrees[i % len(lead_degrees)]
        if i % 8 in (0, 4, 7):
            add(t, step * 0.9, _midi(note), vol, "square", 0.35)
        elif i % 2 == 0:
            add(t, step * 0.7, _midi(note + 12), vol * 0.55, "tri")
        b = bass_degrees[(i // 2) % len(bass_degrees)]
        if i % 2 == 0:
            add(t, step * 1.6, _midi(b), vol * 0.8, "square", 0.25)
        if i % 2 == 1:
            i0 = int(t * rate)
            i1 = min(n, i0 + int(rate * 0.03))
            burst = rng.uniform(-1, 1, i1 - i0) * np.linspace(1, 0, i1 - i0) * vol * 0.25
            buf[i0:i1] += burst
    # gentle lowpass
    for _ in range(2):
        buf[1:-1] = buf[:-2] * 0.25 + buf[1:-1] * 0.5 + buf[2:] * 0.25
    # fade edges so the loop does not click
    fade = int(rate * 0.02)
    buf[:fade] *= np.linspace(0, 1, fade)
    buf[-fade:] *= np.linspace(1, 0, fade)
    return buf


def copy_font():
    dest = ASSETS / "fonts"
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy(FONT_SRC, dest / "Silkscreen-Regular.ttf")
    shutil.copy(OFL_SRC, dest / "OFL-Silkscreen.txt")


def main():
    (ROOT / "docs" / "previews").mkdir(parents=True, exist_ok=True)
    copy_font()
    save_fx()
    save_decor()
    save_icon()
    save_cars()
    save_audio()
    print("assets ok", ASSETS)


if __name__ == "__main__":
    main()
