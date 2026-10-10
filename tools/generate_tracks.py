#!/usr/bin/env python3
"""Data-driven original circuits for TussieCars.

Tracks are closed loops rasterized to a tile grid. The racing engine never
hardcodes a layout; it only reads the JSON written here.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
TILE = 32
DRIVABLE = set("GADSC OWNF")
# string above has a space - fix below
DRIVABLE = set(list("GADSCOWNF"))

ENV = {
    "coastal": {
        "ground": (32, 112, 62),
        "ground2": (24, 96, 54),
        "asphalt": (64, 68, 74),
        "dirt": (132, 98, 58),
        "sand": (198, 176, 112),
        "curb": (204, 48, 44),
        "curb2": (236, 232, 220),
        "barrier": (150, 154, 160),
        "barrier_dark": (78, 82, 90),
        "water": (32, 104, 164),
        "water2": (56, 146, 196),
        "oil": (22, 20, 28),
        "line": (226, 214, 170),
        "edge": (210, 206, 190),
        "decor": ["palm", "rock", "buoy"],
    },
    "desert": {
        "ground": (176, 132, 72),
        "ground2": (160, 112, 58),
        "asphalt": (78, 72, 66),
        "dirt": (146, 104, 62),
        "sand": (214, 180, 112),
        "curb": (186, 86, 42),
        "curb2": (232, 206, 150),
        "barrier": (120, 96, 70),
        "barrier_dark": (72, 54, 38),
        "water": (64, 120, 140),
        "water2": (90, 150, 160),
        "oil": (36, 28, 24),
        "line": (236, 214, 150),
        "edge": (220, 190, 120),
        "decor": ["cactus", "rock"],
    },
    "industrial": {
        "ground": (46, 48, 54),
        "ground2": (36, 38, 44),
        "asphalt": (52, 56, 64),
        "dirt": (90, 78, 60),
        "sand": (120, 108, 84),
        "curb": (214, 170, 32),
        "curb2": (28, 28, 32),
        "barrier": (128, 132, 140),
        "barrier_dark": (48, 50, 58),
        "water": (36, 78, 96),
        "water2": (48, 100, 114),
        "oil": (18, 16, 22),
        "line": (240, 196, 64),
        "edge": (180, 184, 190),
        "decor": ["crate", "lamp", "tank", "building"],
    },
}


def h32(x, y, salt=0):
    n = (int(x) * 374761393 + int(y) * 668265263 + salt * 1444728091) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return n


def norm(vx, vy):
    m = math.hypot(vx, vy) or 1.0
    return vx / m, vy / m


def chaikin(pts, iters=3):
    for _ in range(iters):
        nxt = []
        n = len(pts)
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            nxt.append((0.75 * x1 + 0.25 * x2, 0.75 * y1 + 0.25 * y2))
            nxt.append((0.25 * x1 + 0.75 * x2, 0.25 * y1 + 0.75 * y2))
        pts = nxt
    return pts


def resample(pts, spacing):
    if len(pts) < 2:
        return pts
    closed = pts + [pts[0]]
    out = [closed[0]]
    acc = 0.0
    for i in range(len(closed) - 1):
        x1, y1 = closed[i]
        x2, y2 = closed[i + 1]
        seg = math.hypot(x2 - x1, y2 - y1)
        if seg < 1e-6:
            continue
        while acc + seg >= spacing:
            t = (spacing - acc) / seg
            nx = x1 + (x2 - x1) * t
            ny = y1 + (y2 - y1) * t
            out.append((nx, ny))
            x1, y1 = nx, ny
            seg = math.hypot(x2 - x1, y2 - y1)
            acc = 0.0
            if seg < 1e-8:
                break
        acc += seg
    if len(out) > 2 and math.hypot(out[0][0] - out[-1][0], out[0][1] - out[-1][1]) < spacing * 0.4:
        out.pop()
    return out


def segments_intersect(a, b, c, d):
    def cross(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])

    o1 = cross(a, b, c)
    o2 = cross(a, b, d)
    o3 = cross(c, d, a)
    o4 = cross(c, d, b)
    return o1 * o2 < 0 and o3 * o4 < 0


def self_intersects(pts):
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            c, d = pts[j], pts[(j + 1) % n]
            if segments_intersect(a, b, c, d):
                return True
    return False


def tangent(pts, i):
    n = len(pts)
    x1, y1 = pts[(i - 1) % n]
    x2, y2 = pts[(i + 1) % n]
    return norm(x2 - x1, y2 - y1)


def curvature(pts, i, window=4):
    n = len(pts)
    ax, ay = pts[(i - window) % n]
    bx, by = pts[i]
    cx, cy = pts[(i + window) % n]
    bax, bay = norm(bx - ax, by - ay)
    cbx, cby = norm(cx - bx, cy - by)
    dot = max(-1.0, min(1.0, bax * cbx + bay * cby))
    cross = bax * cby - bay * cbx
    return math.acos(dot), cross


def ellipse(n, w, h, margin, rx, ry, phase=0.0):
    cx, cy = w / 2, h / 2
    radx = (w / 2 - margin) * rx
    rady = (h / 2 - margin) * ry
    pts = []
    for i in range(n):
        a = phase + i / n * math.tau
        pts.append((cx + math.cos(a) * radx, cy + math.sin(a) * rady))
    return pts


def figure8(n, w, h, margin):
    raw = []
    for i in range(n):
        t = i / n * math.tau
        raw.append((math.sin(t), math.sin(t) * math.cos(t)))
    xs = [p[0] for p in raw]
    ys = [p[1] for p in raw]
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    out = []
    for x, y in raw:
        nx = margin + (x - minx) / (maxx - minx) * (w - 2 * margin)
        ny = margin + (y - miny) / (maxy - miny) * (h - 2 * margin)
        out.append((nx, ny))
    return out


def apply_wobbles(pts, wobbles):
    n = len(pts)
    out = []
    for i, (x, y) in enumerate(pts):
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        off = 0.0
        t = i / n
        for w in wobbles:
            a, b, amp = w
            if b < a:
                inside = t >= a or t <= b
                if t >= a:
                    u = (t - a) / ((1 - a) + b)
                else:
                    u = ((1 - a) + t) / ((1 - a) + b)
            else:
                inside = a <= t <= b
                span = max(1e-4, b - a)
                u = (t - a) / span
            if inside:
                off += math.sin(u * math.pi) * amp
        out.append((x + lx * off, y + ly * off))
    return out


def in_span(t, a, b):
    if b < a:
        return t >= a or t <= b
    return a <= t <= b


def radius_at(t, spec):
    r = spec["radius"]
    for a, b, nr in spec.get("narrow", []):
        if in_span(t, a, b):
            r = min(r, nr)
    for a, b, nr in spec.get("wide", []):
        if in_span(t, a, b):
            r = max(r, nr)
    return r


def empty(w, h, fill="G"):
    return [[fill for _ in range(w)] for _ in range(h)]


def stamp(grid, x, y, radius, ch, replace=None):
    h = len(grid)
    w = len(grid[0])
    r = int(math.ceil(radius)) + 1
    x0 = max(0, int(math.floor(x)) - r)
    x1 = min(w - 1, int(math.ceil(x)) + r)
    y0 = max(0, int(math.floor(y)) - r)
    y1 = min(h - 1, int(math.ceil(y)) + r)
    rr = radius * radius
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            if (tx + 0.5 - x) ** 2 + (ty + 0.5 - y) ** 2 <= rr:
                if replace is None or grid[ty][tx] in replace:
                    grid[ty][tx] = ch


def build_grid(spec, pts):
    w, h = spec["w"], spec["h"]
    grid = empty(w, h, "G")
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        t = i / n
        stamp(grid, x, y, radius_at(t, spec), "A")
    # shoulders
    shoulder = spec.get("shoulder", "curb")
    side = {"curb": "C", "sand": "S", "dirt": "D"}[shoulder]
    changed = True
    # one ring only
    core = {"A", "O", "F"}
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if grid[y][x] != "G":
                continue
            if any(grid[y + dy][x + dx] in core for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                grid[y][x] = side
    # sand runoff on the outside of bends
    if spec.get("sand_corners"):
        for i, (x, y) in enumerate(pts):
            curv, cross = curvature(pts, i, 5)
            if curv < 0.45:
                continue
            tx, ty = tangent(pts, i)
            # outside is opposite the turn. positive cross is clockwise (right) in y-down
            ox, oy = (ty, -tx) if cross > 0 else (-ty, tx)
            rad = radius_at(i / n, spec)
            for dist in (rad + 0.2, rad + 1.1, rad + 1.8):
                sx = int(x + ox * dist)
                sy = int(y + oy * dist)
                if 1 <= sx < w - 1 and 1 <= sy < h - 1 and grid[sy][sx] in ("G", "C", "D"):
                    grid[sy][sx] = "S"
    # corner barriers
    rng = np.random.default_rng(spec["seed"])
    wall = spec.get("walls", 0.45)
    for i, (x, y) in enumerate(pts):
        curv, cross = curvature(pts, i, 4)
        if curv < 0.55:
            continue
        if rng.random() > wall:
            continue
        tx, ty = tangent(pts, i)
        ox, oy = (ty, -tx) if cross > 0 else (-ty, tx)
        rad = radius_at(i / n, spec)
        for along in (-0.6, 0.0, 0.6):
            sx = int(x + ox * (rad + 1.55) + tx * along)
            sy = int(y + oy * (rad + 1.55) + ty * along)
            if 2 <= sx < w - 2 and 2 <= sy < h - 2 and grid[sy][sx] in ("G", "C", "S", "D"):
                # keep the racing line clear
                cx, cy = int(x), int(y)
                if abs(sx - cx) + abs(sy - cy) >= 2:
                    grid[sy][sx] = "B"
    for island in spec.get("islands", []):
        i = int(island["t"] * n) % n
        x, y = pts[i]
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        side_n = island.get("side", 1)
        sx = int(x + lx * side_n * 1.05)
        sy = int(y + ly * side_n * 1.05)
        ox = int(x - lx * side_n * 1.15)
        oy = int(y - ly * side_n * 1.15)
        if 2 <= sx < w - 2 and 2 <= sy < h - 2 and 2 <= ox < w - 2 and 2 <= oy < h - 2:
            if grid[sy][sx] == "A" and grid[oy][ox] == "A":
                grid[sy][sx] = "B"
                if island.get("len", 1) > 1:
                    sx2 = int(sx + tx)
                    sy2 = int(sy + ty)
                    if grid[sy2][sx2] == "A":
                        grid[sy2][sx2] = "B"
    for t in spec.get("oil", []):
        i = int(t * n) % n
        x, y = pts[i]
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        for off in (-0.55, 0.15):
            sx = int(x + lx * off)
            sy = int(y + ly * off)
            if 1 <= sx < w - 1 and 1 <= sy < h - 1 and grid[sy][sx] == "A":
                grid[sy][sx] = "O"
                if sy + 1 < h - 1 and grid[sy + 1][sx] == "A":
                    grid[sy + 1][sx] = "O"
    for t in spec.get("pads", [0.3, 0.72]):
        i = int(t * n) % n
        x, y = pts[i]
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        rad = int(radius_at(i / n, spec)) + 1
        for k in range(-rad, rad + 1):
            sx = int(x + lx * k)
            sy = int(y + ly * k)
            if 1 <= sx < w - 1 and 1 <= sy < h - 1 and grid[sy][sx] == "A":
                grid[sy][sx] = "N"
    for t in spec.get("dirt", []):
        i = int(t * n) % n
        x, y = pts[i]
        _, _ = tangent(pts, i)
        lx, ly = tangent(pts, i)
        # reuse left normal
        tx, ty = lx, ly
        lx, ly = -ty, tx
        for off in (1.15, 1.7):
            sx = int(x + lx * off)
            sy = int(y + ly * off)
            if 1 <= sx < w - 1 and 1 <= sy < h - 1 and grid[sy][sx] in ("A", "C", "G"):
                grid[sy][sx] = "D"
    for t in spec.get("water", []):
        i = int(t * n) % n
        x, y = pts[i]
        curv, cross = curvature(pts, i, 3)
        tx, ty = tangent(pts, i)
        ox, oy = (ty, -tx) if cross >= 0 else (-ty, tx)
        rad = radius_at(i / n, spec)
        for dist in (rad + 1.3, rad + 2.1, rad + 2.1):
            for along in (-0.8, 0.0, 0.8):
                sx = int(x + ox * dist + tx * along)
                sy = int(y + oy * dist + ty * along)
                if 1 <= sx < w - 1 and 1 <= sy < h - 1 and grid[sy][sx] in ("G", "C", "S", "D"):
                    grid[sy][sx] = "W"
    # border walls, never eating asphalt
    for y in range(h):
        for x in range(w):
            if x < 1 or y < 1 or x >= w - 1 or y >= h - 1:
                if grid[y][x] in ("G", "C", "S", "D"):
                    grid[y][x] = "B"
    # Keep a drivable racing line if a barrier or hazard landed on the center.
    for x, y in pts:
        stamp(grid, x, y, 0.8, "A", replace={"B", "W"})
    return grid


def rotate_to_straight(pts):
    n = len(pts)
    best_i = 0
    best = 999
    for i in range(n):
        score = 0.0
        for k in range(-8, 9):
            curv, _ = curvature(pts, (i + k) % n, 3)
            score += curv
        if score < best:
            best = score
            best_i = i
    return pts[best_i:] + pts[:best_i]


def choose_points(spec):
    if spec.get("shape") == "figure8":
        pts = figure8(80, spec["w"], spec["h"], spec.get("margin", 6))
        pts = resample(pts, 1.15)
        return pts, True
    pts = ellipse(28, spec["w"], spec["h"], spec.get("margin", 6), spec.get("rx", 0.9), spec.get("ry", 0.78), spec.get("phase", -math.pi / 2))
    pts = chaikin(pts, 2)
    pts = resample(pts, 1.05)
    wobbles = list(spec.get("wobbles", []))
    for _ in range(5):
        trial = apply_wobbles(pts, wobbles) if wobbles else pts
        trial = resample(trial, 1.1)
        if not self_intersects(trial):
            pts = trial
            break
        wobbles = [(a, b, amp * 0.7) for a, b, amp in wobbles]
    else:
        pts = trial
    pts = rotate_to_straight(pts)
    return pts, False


def bfs_reachable(grid, start):
    h = len(grid)
    w = len(grid[0])
    sx, sy = start
    if not (0 <= sx < w and 0 <= sy < h):
        return set()
    if grid[sy][sx] not in DRIVABLE:
        return set()
    seen = {(sx, sy)}
    q = [(sx, sy)]
    while q:
        x, y = q.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen:
                continue
            if 0 <= nx < w and 0 <= ny < h and grid[ny][nx] in DRIVABLE:
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def validate(spec, grid, pts, checks, grid_slots):
    errors = []
    w, h = spec["w"], spec["h"]
    for y, row in enumerate(grid):
        if len(row) != w:
            errors.append(f"row {y} width")
    road = sum(cell == "A" or cell == "O" for row in grid for cell in row)
    if road < 180:
        errors.append(f"road too small {road}")
    for x, y in pts[::3]:
        tx, ty = int(x), int(y)
        if not (0 <= tx < w and 0 <= ty < h) or grid[ty][tx] not in DRIVABLE:
            errors.append("waypoint off road")
            break
        if grid[ty][tx] == "B":
            errors.append("waypoint blocked")
            break
    # border asphalt is a failure
    for y in range(h):
        for x in range(w):
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                if grid[y][x] in ("A", "O", "F"):
                    errors.append("road touches border")
                    break
    sx, sy = int(pts[0][0]), int(pts[0][1])
    seen = bfs_reachable(grid, (sx, sy))
    for i, (x, y) in enumerate(pts):
        if (int(x), int(y)) not in seen and i % 4 == 0:
            errors.append("centerline disconnected")
            break
    for c in checks:
        mx = int((c[0][0] + c[1][0]) / 2 / TILE)
        my = int((c[0][1] + c[1][1]) / 2 / TILE)
        if not (0 <= mx < w and 0 <= my < h) or grid[my][mx] not in DRIVABLE or grid[my][mx] == "B":
            errors.append("checkpoint off road")
            break
    for slot in grid_slots:
        tx = int(slot[0] / TILE)
        ty = int(slot[1] / TILE)
        if not (0 <= tx < w and 0 <= ty < h) or grid[ty][tx] not in ("A", "O", "F", "C", "D", "S"):
            errors.append("grid slot off asphalt")
            break
    return errors


def make_tile(kind, env, variant):
    ts = TILE
    rng = np.random.default_rng(h32(variant, ord(kind[0]), 9))
    col = np.zeros((ts, ts, 4), np.uint8)
    col[:, :, 3] = 255
    if kind in ("A", "F", "O"):
        base = np.array(env["asphalt"], np.int16)
        noise = rng.integers(-6, 7, size=(ts, ts, 1))
        rgb = np.clip(base + noise, 0, 255).astype(np.int16)
        speck = rng.integers(0, 6, size=(ts, ts))
        rgb[speck == 0] -= 14
        rgb[speck == 5] += 12
        # worn sheen, one sun from the north
        rgb[:6, :, :] += 8
        col[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        if kind == "O":
            col[:, :, :3] = (np.array(env["oil"]) * 0.82 + col[:, :, :3] * 0.18).astype(np.uint8)
            for k in range(4):
                x = int(rng.integers(2, ts - 2))
                y = int(rng.integers(2, ts - 2))
                col[y, x, :3] = [(180, 60, 160), (60, 180, 160), (200, 180, 60), (80, 80, 200)][k]
    elif kind == "N":
        base = np.array(env["asphalt"], np.int16)
        noise = rng.integers(-6, 7, size=(ts, ts, 1))
        col[:, :, :3] = np.clip(base + noise, 0, 255).astype(np.uint8)
        glow = np.array((64, 224, 255), np.int16)
        col[1:4, :, :3] = np.clip(base * 0.3 + glow * 0.7, 0, 255).astype(np.uint8)
        col[ts - 4:ts - 1, :, :3] = np.clip(base * 0.3 + glow * 0.7, 0, 255).astype(np.uint8)
        for cx in range(6, ts - 6, 10):
            col[10:ts - 10, cx:cx + 4, :3] = np.clip(base * 0.4 + glow * 0.6, 0, 255).astype(np.uint8)
    elif kind == "G":
        base = np.array(env["ground"], np.int16)
        noise = rng.integers(-6, 7, size=(ts, ts, 1))
        col[:, :, :3] = np.clip(base + noise, 0, 255).astype(np.uint8)
        for _ in range(14):
            x = int(rng.integers(1, ts - 2))
            y = int(rng.integers(3, ts - 1))
            blade = env["ground2"]
            col[y, x, :3] = blade
            col[y - 1, x, :3] = blade
            if y > 2:
                col[y - 2, x, :3] = np.clip(np.array(blade) + 18, 0, 255)
    elif kind == "D":
        base = np.array(env["dirt"], np.int16)
        col[:, :, :3] = np.clip(base + rng.integers(-12, 13, size=(ts, ts, 1)), 0, 255)
    elif kind == "S":
        base = np.array(env["sand"], np.int16)
        col[:, :, :3] = np.clip(base + rng.integers(-10, 11, size=(ts, ts, 1)), 0, 255)
    elif kind == "W":
        c1 = np.array(env["water"])
        c2 = np.array(env["water2"])
        for y in range(ts):
            wave = 6 if (y // 3) % 2 == 0 else 0
            col[y, :, :3] = np.clip(c1.astype(np.int16) + wave if (y // 5) % 2 == 0 else c2.astype(np.int16) + wave // 2, 0, 255)
        for k in range(5):
            x = int(rng.integers(2, ts - 2))
            y = int(rng.integers(2, ts - 2))
            col[y, x:x + 3, :3] = (230, 244, 255)
    elif kind == "C":
        c1 = np.array(env["curb"])
        c2 = np.array(env["curb2"])
        for y in range(ts):
            for x in range(ts):
                col[y, x, :3] = c1 if ((x + y) // 8) % 2 == 0 else c2
    elif kind == "B":
        col[:, :, :3] = env["barrier_dark"]
        col[3:ts - 3, 3:ts - 3, :3] = env["barrier"]
        col[3:6, 3:ts - 3, :3] = np.clip(np.array(env["barrier"]) + 30, 0, 255)
        col[ts - 6:ts - 3, 3:ts - 3, :3] = np.array(env["barrier_dark"])
        col[12:15, 12:15, :3] = (40, 40, 44)
        col[12:15, ts - 15:ts - 12, :3] = (40, 40, 44)
    else:
        col[:, :, :3] = (255, 0, 255)
    return col


def paint(grid, env):
    h = len(grid)
    w = len(grid[0])
    tiles = {}
    for kind in set(cell for row in grid for cell in row):
        tiles[kind] = [make_tile(kind, env, v) for v in range(4)]
    arr = np.zeros((h * TILE, w * TILE, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            variant = h32(x, y) % 4
            arr[y * TILE:(y + 1) * TILE, x * TILE:(x + 1) * TILE] = tiles[grid[y][x]][variant]
    # Break up tile repetition with stable per-pixel grain.
    height, width = arr.shape[:2]
    xs = np.arange(width, dtype=np.uint32)
    ys = np.arange(height, dtype=np.uint32)
    n = (xs[None, :] * np.uint32(198491317)) ^ (ys[:, None] * np.uint32(6542989))
    n = (n ^ (n >> np.uint32(16))) * np.uint32(2246822519)
    delta = ((n & np.uint32(15)).astype(np.int16) - 8)
    rgb = arr[:, :, :3].astype(np.int16)
    rgb += delta[:, :, None]
    arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    arr = _contact_shade(arr, grid)
    return arr


def _contact_shade(arr, grid):
    """Darken the ground beside barriers so the circuit sits in the world."""
    height = len(grid)
    width = len(grid[0])
    mask = np.zeros((height, width), np.float32)
    for y, row in enumerate(grid):
        for x, cell in enumerate(row):
            if cell == "B":
                mask[y, x] = 1.0
    big = np.repeat(np.repeat(mask, TILE, axis=0), TILE, axis=1)
    pad = 18
    padded = np.pad(big, ((pad, pad), (pad, pad)), mode="edge")
    acc = np.zeros_like(big)
    for shift in (2, 6, 12):
        acc += padded[pad + shift:pad + shift + big.shape[0], pad:pad + big.shape[1]] * 0.55
        acc += padded[pad - shift:pad - shift + big.shape[0], pad:pad + big.shape[1]] * 0.9
        acc += padded[pad:pad + big.shape[0], pad + shift:pad + shift + big.shape[1]] * 0.45
        acc += padded[pad:pad + big.shape[0], pad - shift:pad - shift + big.shape[1]] * 0.7
    acc = np.clip(acc / 5.5, 0.0, 1.0)
    rgb = arr[:, :, :3].astype(np.float32)
    rgb *= 1.0 - acc[:, :, None] * 0.42
    arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return arr


def draw_markings(arr, pts, spec, checks, pickups=None):
    im = Image.fromarray(arr, "RGBA")
    dr = ImageDraw.Draw(im)
    env = ENV[spec["environment"]]
    n = len(pts)
    left = []
    right = []
    shoulder_l = []
    shoulder_r = []
    center = []
    for i, (x, y) in enumerate(pts):
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        rad = radius_at(i / n, spec) * TILE
        px, py = x * TILE, y * TILE
        center.append((px, py))
        inset = max(8, rad - 7)
        left.append((px + lx * inset, py + ly * inset))
        right.append((px - lx * inset, py - ly * inset))
        outer = max(inset + 5, rad - 2)
        shoulder_l.append((px + lx * outer, py + ly * outer))
        shoulder_r.append((px - lx * outer, py - ly * outer))
    def poly_line(points, fill, width):
        seq = points + [points[0]]
        dr.line(seq, fill=fill, width=width)

    poly_line(shoulder_l, (36, 38, 44, 255), 7)
    poly_line(shoulder_r, (36, 38, 44, 255), 7)
    for i in range(0, n, 2):
        x, y = pts[i]
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        rad = radius_at(i / n, spec) * TILE
        px, py = x * TILE, y * TILE
        stripe = (214, 86, 32, 255) if (i // 2) % 2 == 0 else (236, 230, 214, 255)
        outer = max(10, rad - 3)
        inner = max(6, rad - 10)
        dr.line([(px + lx * outer, py + ly * outer), (px + lx * inner, py + ly * inner)], fill=stripe, width=2)
        dr.line([(px - lx * outer, py - ly * outer), (px - lx * inner, py - ly * inner)], fill=stripe, width=2)
    poly_line(left, env["edge"] + (255,), 2)
    poly_line(right, env["edge"] + (255,), 2)
    # dashed center and chevrons
    seq = center + [center[0]]
    dist = 0.0
    draw_on = True
    last = seq[0]
    for p in seq[1:]:
        seg = math.hypot(p[0] - last[0], p[1] - last[1])
        if draw_on:
            dr.line([last, p], fill=env["line"] + (255,), width=2)
        dist += seg
        if dist > 14:
            dist = 0
            draw_on = not draw_on
        last = p
    for i in range(0, n, 14):
        x, y = pts[i]
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        px, py = x * TILE, y * TILE
        tip = (px + tx * 12, py + ty * 12)
        wing_a = (px - tx * 4 + lx * 7, py - ty * 4 + ly * 7)
        wing_b = (px - tx * 4 - lx * 7, py - ty * 4 - ly * 7)
        dr.polygon([tip, wing_a, wing_b], fill=env["line"] + (230,))
    # finish checker across checkpoint 0
    if checks:
        (ax, ay), (bx, by) = checks[0]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1
        nx, ny = dx / length, dy / length
        tx, ty = -ny, nx
        steps = int(length)
        for s in range(steps):
            u = s / steps
            cx = ax + dx * u
            cy = ay + dy * u
            dark = (s // 8) % 2 == 0
            col = (20, 20, 24, 255) if dark else (236, 236, 236, 255)
            x0 = cx - tx * 7
            y0 = cy - ty * 7
            x1 = cx + tx * 7
            y1 = cy + ty * 7
            dr.line([(x0, y0), (x1, y1)], fill=col, width=3)
    if pickups:
        for pickup in pickups:
            if pickup.get("kind") != "boost":
                continue
            x, y = pickup["x"], pickup["y"]
            dr.polygon([(x, y - 16), (x + 16, y), (x, y + 16), (x - 16, y)], fill=(255, 132, 28, 235))
            dr.polygon([(x, y - 7), (x + 6, y), (x, y + 7), (x - 6, y)], fill=(255, 228, 150, 255))
    return np.array(im)


def build_checkpoints(pts, spec):
    n = len(pts)
    count = spec.get("checkpoints", 6)
    checks = []
    for k in range(count):
        i = int(round(k / count * n)) % n
        x, y = pts[i]
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        rad = radius_at(i / n, spec) + 0.8
        a = ((x - lx * rad) * TILE, (y - ly * rad) * TILE)
        b = ((x + lx * rad) * TILE, (y + ly * rad) * TILE)
        checks.append((a, b))
    return checks


def build_grid_slots(pts, spec, count=8):
    x, y = pts[0]
    tx, ty = tangent(pts, 0)
    lx, ly = -ty, tx
    slots = []
    for row in range(count // 2):
        for col in range(2):
            back = 2.4 + row * 1.55
            side = -0.7 if col == 0 else 0.7
            sx = x - tx * back + lx * side
            sy = y - ty * back + ly * side
            heading = math.atan2(ty, tx)
            slots.append((sx * TILE, sy * TILE, heading))
    return slots


def decor_and_pickups(grid, pts, spec):
    w, h = spec["w"], spec["h"]
    # distance to core road
    from collections import deque

    dist = [[999 for _ in range(w)] for _ in range(h)]
    q = deque()
    for y in range(h):
        for x in range(w):
            if grid[y][x] in ("A", "O", "F"):
                dist[y][x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and dist[ny][nx] > dist[y][x] + 1:
                dist[ny][nx] = dist[y][x] + 1
                q.append((nx, ny))
    rng = np.random.default_rng(spec["seed"] + 17)
    kinds = ENV[spec["environment"]]["decor"]
    decor = []
    occupied = []
    candidates = [(x, y) for y in range(h) for x in range(w) if 2 <= dist[y][x] <= 5 and grid[y][x] in ("G", "S", "D")]
    rng.shuffle(candidates)
    for x, y in candidates:
        if any(abs(x - ox) + abs(y - oy) < 5 for ox, oy in occupied):
            continue
        kind = kinds[int(rng.integers(0, len(kinds)))]
        if kind == "building" and any(abs(x - ox) + abs(y - oy) < 8 for ox, oy, *_ in [(d["tx"], d["ty"]) for d in decor]):
            continue
        if kind == "buoy" and grid[y][x] != "W" and not any(
            0 <= y + dy < h and 0 <= x + dx < w and grid[y + dy][x + dx] == "W"
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
        ):
            if spec["environment"] == "coastal" and rng.random() < 0.7:
                kind = "palm"
        occupied.append((x, y))
        decor.append({
            "x": round((x + 0.5) * TILE, 1),
            "y": round((y + 0.5) * TILE, 1),
            "tx": x,
            "ty": y,
            "kind": kind,
        })
        if len(decor) >= spec.get("decor_count", 28):
            break
    # buoys on water
    if spec["environment"] == "coastal":
        waters = [(x, y) for y in range(h) for x in range(w) if grid[y][x] == "W"]
        rng.shuffle(waters)
        for x, y in waters[:6]:
            decor.append({"x": round((x + 0.5) * TILE, 1), "y": round((y + 0.5) * TILE, 1), "tx": x, "ty": y, "kind": "buoy"})
    n = len(pts)
    pickups = []
    kinds_p = ["missile", "repair", "boost", "mine", "repair"]
    for k, kind in enumerate(kinds_p):
        i = int((0.12 + k * 0.17) * n) % n
        x, y = pts[i]
        tx, ty = tangent(pts, i)
        lx, ly = -ty, tx
        side = -1 if k % 2 == 0 else 1
        rad = max(0.8, radius_at(i / n, spec) - 1.3)
        px = x + lx * side * rad
        py = y + ly * side * rad
        gx, gy = int(px), int(py)
        if 0 <= gx < w and 0 <= gy < h and grid[gy][gx] in ("A", "C", "D", "S"):
            pickups.append({"x": round(px * TILE, 1), "y": round(py * TILE, 1), "kind": kind})
    return decor, pickups


def spec_list():
    common = dict(tile=TILE)
    tracks = [
        dict(id="harbor_loop", name="Harbor Loop", environment="coastal", laps=3, w=70, h=50, seed=11,
             radius=2.55, rx=0.92, ry=0.80, wobbles=[(0.42, 0.58, 2.4)], walls=0.35, water=[0.22],
             checkpoints=6, shoulder="curb", **common),
        dict(id="pier_chicane", name="Pier Chicane", environment="coastal", laps=4, w=64, h=54, seed=23,
             radius=2.15, rx=0.9, ry=0.84, wobbles=[(0.18, 0.30, 2.2), (0.48, 0.62, -2.6), (0.74, 0.86, 2.0)],
             walls=0.55, water=[0.33, 0.7], narrow=[(0.46, 0.64, 1.55)], checkpoints=6, **common),
        dict(id="lighthouse_run", name="Lighthouse Run", environment="coastal", laps=2, w=100, h=44, seed=31,
             radius=2.85, rx=0.96, ry=0.62, wobbles=[(0.70, 0.82, 1.8)], walls=0.25, water=[0.12],
             wide=[(0.02, 0.28, 3.3)], checkpoints=6, margin=5, **common),
        dict(id="breakwater", name="Breakwater", environment="coastal", laps=3, w=68, h=56, seed=41,
             radius=2.05, rx=0.88, ry=0.86, wobbles=[(0.30, 0.42, 1.6), (0.62, 0.74, -1.8)],
             walls=0.85, water=[0.2, 0.55, 0.8], narrow=[(0.36, 0.48, 1.45), (0.66, 0.76, 1.5)],
             islands=[{"t": 0.15, "side": 1, "len": 2}], checkpoints=6, **common),
        dict(id="dune_straight", name="Dune Straight", environment="desert", laps=2, w=104, h=42, seed=52,
             radius=2.9, rx=0.96, ry=0.58, wobbles=[(0.55, 0.68, 1.5)], walls=0.2, sand_corners=True,
             shoulder="sand", wide=[(0.0, 0.35, 3.4)], checkpoints=5, margin=5, **common),
        dict(id="canyon_switch", name="Canyon Switchbacks", environment="desert", laps=3, w=72, h=60, seed=63,
             radius=2.25, rx=0.86, ry=0.88, wobbles=[(0.12, 0.24, 3.0), (0.28, 0.40, -3.1), (0.46, 0.58, 2.8), (0.64, 0.76, -2.6)],
             walls=0.7, sand_corners=True, shoulder="sand", narrow=[(0.30, 0.42, 1.6)], checkpoints=8, **common),
        dict(id="mesa_cross", name="Mesa Cross", environment="desert", laps=3, w=80, h=64, seed=74,
             shape="figure8", radius=2.35, walls=0.3, sand_corners=True, shoulder="sand",
             oil=[0.48], checkpoints=8, margin=7, **common),
        dict(id="dust_bowl", name="Dust Bowl", environment="desert", laps=3, w=76, h=56, seed=85,
             radius=2.6, rx=0.9, ry=0.82, wobbles=[(0.4, 0.55, 2.0)], walls=0.3, sand_corners=True,
             shoulder="sand", dirt=[0.25, 0.6], oil=[0.72], checkpoints=6, **common),
        dict(id="foundry_mile", name="Foundry Mile", environment="industrial", laps=3, w=84, h=52, seed=97,
             radius=2.55, rx=0.94, ry=0.74, wobbles=[(0.5, 0.62, -2.2)], walls=0.65,
             islands=[{"t": 0.22, "side": -1, "len": 2}, {"t": 0.78, "side": 1, "len": 1}],
             oil=[0.35], checkpoints=6, **common),
        dict(id="warehouse_bend", name="Warehouse Bend", environment="industrial", laps=3, w=60, h=54, seed=108,
             radius=2.05, rx=0.86, ry=0.86, wobbles=[(0.15, 0.28, 2.4), (0.36, 0.5, -2.5), (0.58, 0.72, 2.2), (0.78, 0.9, -2.0)],
             walls=0.9, narrow=[(0.34, 0.5, 1.5)], islands=[{"t": 0.2, "side": 1}, {"t": 0.66, "side": -1}],
             oil=[0.44], checkpoints=7, **common),
        dict(id="neon_overpass", name="Neon Overpass", environment="industrial", laps=2, w=98, h=46, seed=119,
             radius=3.05, rx=0.96, ry=0.6, wobbles=[(0.62, 0.74, 1.6)], walls=0.3,
             wide=[(0.0, 0.4, 3.5)], oil=[0.8], checkpoints=5, margin=5, **common),
        dict(id="rivet_yard", name="Rivet Yard", environment="industrial", laps=3, w=74, h=58, seed=130,
             radius=2.2, rx=0.9, ry=0.84, wobbles=[(0.22, 0.36, 2.3), (0.55, 0.7, -2.4)],
             walls=0.75, narrow=[(0.48, 0.6, 1.48)], oil=[0.18, 0.52, 0.84], water=[0.3],
             islands=[{"t": 0.4, "side": 1, "len": 2}, {"t": 0.88, "side": -1}],
             dirt=[0.66], checkpoints=7, **common),
        dict(id="gull_rock", name="Gull Rock", environment="coastal", laps=3, w=78, h=52, seed=141,
             radius=2.3, rx=0.9, ry=0.82, wobbles=[(0.1, 0.22, 2.7), (0.38, 0.5, -2.9), (0.68, 0.8, 2.4)],
             walls=0.6, water=[0.28, 0.62], narrow=[(0.4, 0.52, 1.5)],
             islands=[{"t": 0.55, "side": -1, "len": 2}], checkpoints=7, **common),
        dict(id="salt_pan", name="Salt Pan", environment="desert", laps=2, w=108, h=44, seed=153,
             radius=3.0, rx=0.97, ry=0.6, wobbles=[(0.3, 0.42, 1.7), (0.72, 0.82, -1.5)], walls=0.15,
             sand_corners=True, shoulder="sand", wide=[(0.1, 0.45, 3.6), (0.6, 0.9, 3.4)],
             checkpoints=5, margin=5, **common),
        dict(id="gearworks", name="Gearworks", environment="industrial", laps=3, w=66, h=60, seed=167,
             radius=2.1, rx=0.88, ry=0.88, wobbles=[(0.08, 0.2, 2.6), (0.3, 0.44, -2.7), (0.56, 0.68, 2.5), (0.8, 0.92, -2.3)],
             walls=0.8, narrow=[(0.32, 0.44, 1.52)], islands=[{"t": 0.14, "side": -1}, {"t": 0.5, "side": 1, "len": 2}, {"t": 0.82, "side": -1}],
             oil=[0.3, 0.64], checkpoints=8, **common),
        dict(id="storm_point", name="Storm Point", environment="coastal", laps=3, w=88, h=56, seed=179,
             radius=2.5, rx=0.93, ry=0.78, wobbles=[(0.12, 0.24, 3.0), (0.34, 0.46, -3.0), (0.52, 0.64, 2.8), (0.78, 0.9, -2.6)],
             walls=0.5, water=[0.15, 0.45, 0.75], wide=[(0.0, 0.2, 3.2)], narrow=[(0.36, 0.48, 1.5), (0.8, 0.9, 1.55)],
             islands=[{"t": 0.6, "side": -1, "len": 2}],
             dirt=[0.4], checkpoints=7, **common),
        dict(id="test_oval", name="Test Oval", environment="coastal", laps=2, w=40, h=28, seed=1,
             radius=2.2, rx=0.8, ry=0.7, wobbles=[], walls=0.2, checkpoints=4, decor_count=6,
             margin=4, championship=False, **common),
    ]
    return tracks


def logic_overlay(art, grid, pts, checks, slots):
    im = Image.fromarray(art).convert("RGBA")
    im.thumbnail((900, 700), Image.Resampling.BOX)
    scale = im.size[0] / (len(grid[0]) * TILE)
    dr = ImageDraw.Draw(im)
    seq = [(x * TILE * scale, y * TILE * scale) for x, y in pts]
    if seq:
        dr.line(seq + [seq[0]], fill=(40, 120, 255, 255), width=1)
    for a, b in checks:
        dr.line([(a[0] * scale, a[1] * scale), (b[0] * scale, b[1] * scale)], fill=(255, 60, 60, 255), width=2)
    for x, y, _h in slots:
        dr.ellipse([x * scale - 2, y * scale - 2, x * scale + 2, y * scale + 2], fill=(255, 40, 220, 255))
    return im


def composite_decor(art, decor):
    im = Image.fromarray(art).convert("RGBA")
    for d in decor:
        path = ROOT / "assets" / "sprites" / "decor" / f"{d['kind']}.png"
        if not path.exists():
            continue
        sprite = Image.open(path).convert("RGBA")
        im.alpha_composite(sprite, (int(d["x"] - sprite.size[0] / 2), int(d["y"] - sprite.size[1] + 4)))
    return im


def emit(spec):
    pts, crossed = choose_points(spec)
    if self_intersects(pts) and spec.get("shape") != "figure8":
        raise SystemExit(f"{spec['id']} self-intersects")
    grid = build_grid(spec, pts)
    checks = build_checkpoints(pts, spec)
    slots = build_grid_slots(pts, spec, 8)
    errors = validate(spec, grid, pts, checks, slots)
    if errors:
        # save debug anyway
        print(spec["id"], "ERRORS", errors)
    else:
        print(spec["id"], "ok", "pts", len(pts), "road", sum(c in 'AO' for row in grid for c in row))
    decor, pickups = decor_and_pickups(grid, pts, spec)
    env = ENV[spec["environment"]]
    art = paint(grid, env)
    art = draw_markings(art, pts, spec, checks, pickups)
    out_png = ROOT / "assets" / "tracks" / f"{spec['id']}.png"
    out_png.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(art, "RGBA").save(out_png, optimize=True)
    heading0 = math.atan2(tangent(pts, 0)[1], tangent(pts, 0)[0])
    data = {
        "id": spec["id"],
        "name": spec["name"],
        "environment": spec["environment"],
        "laps": spec["laps"],
        "tile": TILE,
        "width": spec["w"],
        "height": spec["h"],
        "rows": ["".join(row) for row in grid],
        "waypoints": [[round(x * TILE, 1), round(y * TILE, 1)] for x, y in pts],
        "checkpoints": [{"a": [round(a[0], 1), round(a[1], 1)], "b": [round(b[0], 1), round(b[1], 1)]} for a, b in checks],
        "grid": [[round(s[0], 1), round(s[1], 1), round(s[2], 4)] for s in slots],
        "pickups": pickups,
        "decor": [{"x": d["x"], "y": d["y"], "kind": d["kind"]} for d in decor],
        "image": f"res://assets/tracks/{spec['id']}.png",
        "championship": spec.get("championship", True),
        "start_heading": round(heading0, 4),
    }
    out_json = ROOT / "data" / "tracks" / f"{spec['id']}.json"
    out_json.write_text(json.dumps(data))
    preview = composite_decor(art, decor)
    return data, preview, logic_overlay(art, grid, pts, checks, slots), errors


def contact(images, labels, path, cols=4):
    if not images:
        return
    thumb_w = 360
    thumbs = []
    font = ImageFont.truetype(str(ROOT / "assets" / "fonts" / "Silkscreen-Regular.ttf"), 14) if (ROOT / "assets" / "fonts" / "Silkscreen-Regular.ttf").exists() else None
    for im, label in zip(images, labels):
        im = im.convert("RGBA")
        im.thumbnail((thumb_w, 240), Image.Resampling.BOX)
        canvas = Image.new("RGBA", (thumb_w, im.size[1] + 22), (14, 16, 22, 255))
        canvas.paste(im, (0, 22), im)
        ImageDraw.Draw(canvas).text((6, 3), label, fill=(244, 220, 160, 255), font=font)
        thumbs.append(canvas)
    rows = math.ceil(len(thumbs) / cols)
    sheet = Image.new("RGBA", (cols * thumb_w, rows * max(t.size[1] for t in thumbs)), (8, 8, 12, 255))
    row_h = max(t.size[1] for t in thumbs)
    for i, th in enumerate(thumbs):
        sheet.paste(th, ((i % cols) * thumb_w, (i // cols) * row_h))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(path, optimize=True)


def main():
    arts = []
    logics = []
    labels = []
    failures = []
    index = []
    for spec in spec_list():
        data, preview, logic, errors = emit(spec)
        arts.append(preview)
        logics.append(logic)
        labels.append(spec["name"])
        if errors:
            failures.append((spec["id"], errors))
        if data["championship"]:
            index.append(spec["id"])
    (ROOT / "data" / "tracks" / "index.json").write_text(json.dumps({"order": index}, indent=2))
    contact(arts, labels, ROOT / "docs" / "previews" / "tracks.png")
    contact(logics, labels, ROOT / "docs" / "previews" / "tracks_logic.png")
    if failures:
        raise SystemExit("track validation failed: " + json.dumps(failures))
    print("tracks", len(index))


if __name__ == "__main__":
    main()
