"""
Render every frame of the MakeupPalette brag video as a pure function of time.

- 1080x1920, 30 fps, 20s -> 600 frames
- All colors, names, layout dimensions pulled from the app source.
- Scenes are drawn independently then cross-dissolved (0.5s, centered on boundaries).

Output: work/frames/frame_%04d.png
"""

from __future__ import annotations
import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ---------- config ----------
W, H = 1080, 1920
FPS = 30
DURATION = 20.0
N = int(DURATION * FPS)  # 600
XFADE = 0.5  # seconds of cross-dissolve at each scene boundary

OUT = Path(__file__).resolve().parent / "frames"
OUT.mkdir(parents=True, exist_ok=True)

# ---------- fonts ----------
HN = "/System/Library/Fonts/HelveticaNeue.ttc"
def font(size, weight="regular"):
    idx = {"regular": 0, "bold": 1, "medium": 10, "light": 7}[weight]
    return ImageFont.truetype(HN, size, index=idx)

# ---------- palette (from MakeupCatalog.swift) ----------
def hex_(v: int) -> tuple[int, int, int]:
    return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)

LIPS = [
    ("Classic Red", 0xC41E3A, False),
    ("Nude Beige",  0xC8A08A, False),
    ("Rosy Pink",   0xD46A7E, False),
    ("Berry",       0x8E2A4F, False),
    ("Coral",       0xF26B5B, False),
    ("Mauve",       0xA8757F, False),
    ("Wine",        0x5E1A2E, True),
    ("Peach",       0xF4A68A, True),
    ("Hot Pink",    0xE0457B, True),
    ("Brick Brown", 0x9C4A3A, True),
]
BLUSH = [
    ("Soft Pink",   0xF4A7B0, False),
    ("Peach",       0xF6A889, False),
    ("Coral",       0xE8837A, False),
    ("Rose",        0xD3727F, False),
    ("Berry",       0xB04A64, True),
    ("Terracotta",  0xC6705A, True),
]
BROWS = [
    ("Taupe",       0x8B776B, False),
    ("Soft Brown",  0x6D4F3E, False),
    ("Chestnut",    0x794634, False),
    ("Espresso",    0x352A28, True),
]

ACCENT = (int(0.71 * 255), int(0.32 * 255), int(0.43 * 255))  # rose/berry
GOLD = (int(0.83 * 255), int(0.62 * 255), int(0.16 * 255))
TILE_BG = (243, 243, 243)
TILE_BORDER = (204, 204, 204)
CHARCOAL = (16, 16, 18)
PAPER = (255, 255, 255)
INK = (0, 0, 0)
DIM = (110, 110, 110)

# ---------- easing ----------
def clamp(v, lo=0.0, hi=1.0): return max(lo, min(hi, v))
def ease_out_cubic(t): t = clamp(t); return 1 - (1 - t) ** 3
def ease_in_out(t): t = clamp(t); return 0.5 - 0.5 * math.cos(math.pi * t)
def smoothstep(a, b, x):
    if b == a: return 0.0
    return ease_in_out((x - a) / (b - a))

# ---------- primitives ----------
def draw_rrect(img: Image.Image, box, r, fill=None, outline=None, width=1):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)

def text_size(draw, text, fnt):
    b = draw.textbbox((0, 0), text, font=fnt)
    return b[2] - b[0], b[3] - b[1]

def draw_text_center(img, text, cx, cy, fnt, fill=INK, alpha=255):
    d = ImageDraw.Draw(img)
    tw, th = text_size(d, text, fnt)
    # PIL's textbbox for TTC can have baseline offset; use anchor to fix.
    d.text((cx, cy), text, font=fnt, fill=fill + (alpha,) if len(fill) == 3 else fill, anchor="mm")

def draw_text_left(img, text, x, y, fnt, fill=INK, alpha=255):
    d = ImageDraw.Draw(img)
    d.text((x, y), text, font=fnt, fill=fill + (alpha,) if len(fill) == 3 else fill, anchor="lm")

# ---------- swatch tile ----------
def draw_swatch(img, x, y, size, color=None, label=None, label_fnt=None,
                selected=False, locked=False, none_tile=False, preview_all=False,
                label_alpha=255, tile_alpha=255):
    """Draw a swatch cell (66x66 tile centered, label under it). Cell = 90x104 like the app."""
    tile = size
    tile_box = (x, y, x + tile, y + tile)
    # base bg
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_rrect(layer, tile_box, r=int(tile * 14 / 66), fill=TILE_BG + (tile_alpha,))

    if none_tile:
        d = ImageDraw.Draw(layer)
        d.text((x + tile / 2, y + tile / 2), "—",
               font=font(int(tile * 0.42), "regular"),
               fill=DIM + (tile_alpha,), anchor="mm")
    elif preview_all:
        # A 2x2 mini-grid icon inside the tile
        pad = int(tile * 0.22)
        cell = int((tile - pad * 2 - 6) / 2)
        gap = 6
        ox = x + pad
        oy = y + pad
        for i in range(2):
            for j in range(2):
                bx = ox + j * (cell + gap)
                by = oy + i * (cell + gap)
                draw_rrect(layer, (bx, by, bx + cell, by + cell),
                           r=int(cell * 0.28), fill=(30, 30, 30, tile_alpha),
                           outline=None)
    elif color is not None:
        r, g, b = color
        draw_rrect(layer, tile_box, r=int(tile * 14 / 66),
                   fill=(r, g, b, tile_alpha))

    # border
    border_col = INK if selected else TILE_BORDER
    if locked: border_col = GOLD
    bw = 3 if (selected or locked) else 2
    draw_rrect(layer, tile_box, r=int(tile * 14 / 66),
               outline=border_col + (tile_alpha,), width=bw)

    # lock badge
    if locked:
        badge_r = int(tile * 0.16)
        cx = x + tile - badge_r - int(tile * 0.06)
        cy = y + tile - badge_r - int(tile * 0.06)
        d = ImageDraw.Draw(layer)
        d.ellipse((cx - badge_r, cy - badge_r, cx + badge_r, cy + badge_r),
                  fill=(255, 255, 255, tile_alpha))
        d.ellipse((cx - badge_r, cy - badge_r, cx + badge_r, cy + badge_r),
                  outline=GOLD + (tile_alpha,), width=2)
        # mini lock glyph via rounded rects
        lw = int(badge_r * 0.7); lh = int(badge_r * 0.55)
        d.rounded_rectangle(
            (cx - lw / 2, cy - lh / 2 + int(badge_r * 0.05),
             cx + lw / 2, cy + lh / 2 + int(badge_r * 0.05)),
            radius=int(lw * 0.2), fill=GOLD + (tile_alpha,)
        )
        # shackle
        d.arc((cx - lw * 0.42, cy - lh * 0.9,
               cx + lw * 0.42, cy - lh * 0.1),
              start=180, end=360, fill=GOLD + (tile_alpha,), width=int(lw * 0.18))

    img.alpha_composite(layer)

    if label:
        d = ImageDraw.Draw(img)
        d.text((x + tile / 2, y + tile + int(tile * 0.32)),
               label, font=label_fnt or font(int(tile * 0.22), "regular"),
               fill=INK + (label_alpha,), anchor="mm")


# ---------- scene 1: hook ----------
def render_scene1(t: float, scene_dur: float) -> Image.Image:
    img = Image.new("RGBA", (W, H), CHARCOAL + (255,))

    # Red bloom (Classic Red)
    bloom_t = ease_out_cubic(clamp(t / 1.1))
    max_r = 210
    r = int(max_r * bloom_t)
    cx, cy = W // 2, int(H * 0.42)
    if r > 4:
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(overlay)
        # soft halo
        for pad, alpha in [(80, 25), (40, 45), (0, 255)]:
            rr = r + pad
            d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr),
                      fill=hex_(0xC41E3A) + (alpha,))
        overlay = overlay.filter(ImageFilter.GaussianBlur(radius=6))
        # crisp core over the blur
        d = ImageDraw.Draw(overlay)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=hex_(0xC41E3A) + (255,))
        img.alpha_composite(overlay)

    # Wordmark
    title_t = ease_out_cubic(clamp((t - 0.9) / 1.0))
    if title_t > 0.02:
        y_off = int((1 - title_t) * 30)
        alpha = int(title_t * 255)
        d = ImageDraw.Draw(img)
        d.text((W / 2, int(H * 0.62) + y_off), "Glammie",
               font=font(160, "medium"), fill=(245, 245, 245, alpha), anchor="mm")

    # subline
    sub_t = ease_out_cubic(clamp((t - 1.7) / 0.9))
    if sub_t > 0.02:
        alpha = int(sub_t * 200)
        d = ImageDraw.Draw(img)
        d.text((W / 2, int(H * 0.68)),
               "for the foldable iPhone Duo",
               font=font(38, "light"),
               fill=(210, 210, 210, alpha), anchor="mm")

    return img


# ---------- palette panel drawing (shared by S2 and S3) ----------
def paint_palette_panel(target: Image.Image, ox: int, oy: int,
                        width: int, height: int,
                        rows_visible: int = 3,
                        title_alpha: int = 255,
                        row_alphas: tuple[int, int, int] = (255, 255, 255),
                        selected_indices=(0, None, None),
                        tile_size: int = 128,
                        include_opacity_top: bool = False,
                        opacity_value: float = 1.0,
                        inner_pad_x: int = 60,
                        header_size: int = 70,
                        section_size: int = 52,
                        label_size_scale: float = 0.22):
    """Draw the white palette panel with 'Makeup' header and up to 3 category rows.

    `selected_indices` is (lip_idx, blush_idx, brow_idx); None means None-tile selected.
    """
    # panel background
    panel = Image.new("RGBA", (width, height), PAPER + (255,))
    target.paste(panel, (ox, oy))

    inner_x = ox + inner_pad_x
    top = oy + 70

    if include_opacity_top:
        # horizontal opacity slider
        d = ImageDraw.Draw(target)
        d.text((inner_x, top), "Opacity", font=font(44, "bold"),
               fill=INK + (255,), anchor="lm")
        track_x0 = inner_x + 220
        track_x1 = ox + width - 220
        track_y = top
        d.rounded_rectangle((track_x0, track_y - 6, track_x1, track_y + 6),
                            radius=6, fill=(230, 230, 230, 255))
        fill_x = int(track_x0 + (track_x1 - track_x0) * opacity_value)
        d.rounded_rectangle((track_x0, track_y - 6, fill_x, track_y + 6),
                            radius=6, fill=ACCENT + (255,))
        # thumb
        d.ellipse((fill_x - 20, track_y - 20, fill_x + 20, track_y + 20),
                  fill=(255, 255, 255, 255), outline=ACCENT + (255,), width=4)
        d.text((ox + width - 60, top), f"{int(opacity_value * 100)}%",
               font=font(36, "regular"), fill=INK + (255,), anchor="rm")
        top += 90

    # Header 'Makeup'
    if title_alpha > 0:
        d = ImageDraw.Draw(target)
        d.text((inner_x, top), "Makeup", font=font(header_size, "medium"),
               fill=INK + (title_alpha,), anchor="lm")
    top += int(header_size * 1.3)

    rows = [
        ("Lips",  LIPS,  selected_indices[0]),
        ("Blush", BLUSH, selected_indices[1]),
        ("Brows", BROWS, selected_indices[2]),
    ]

    # Compute vertical footprint so section headings never collide with the
    # previous row's labels.
    label_px = int(tile_size * label_size_scale)
    # heading text + gap + tile + label + breathing room
    row_gap = int(section_size * 1.1) + int(tile_size * 0.55) + 24 + tile_size + int(label_px * 2.4) + 24
    for i, (heading, items, sel_idx) in enumerate(rows[:rows_visible]):
        a = row_alphas[i]
        if a <= 0:
            continue
        # heading
        d = ImageDraw.Draw(target)
        d.text((inner_x, top),
               heading, font=font(section_size, "bold"),
               fill=INK + (a,), anchor="lm")
        # swatch row: None tile, Preview All tile, then options
        tile = tile_size
        cell_w = int(tile * 90 / 66)
        gap = int(tile * 10 / 66)
        row_y = top + int(tile * 0.55) + 24
        x = inner_x
        # None tile
        draw_swatch(target, x, row_y, tile, none_tile=True,
                    label="None",
                    label_fnt=font(label_px, "regular"),
                    selected=(sel_idx is None),
                    tile_alpha=a, label_alpha=a)
        x += cell_w + gap
        # Preview All tile
        draw_swatch(target, x, row_y, tile, preview_all=True,
                    label="Preview All",
                    label_fnt=font(label_px, "regular"),
                    tile_alpha=a, label_alpha=a)
        x += cell_w + gap
        # options
        for j, (name, rgb, is_premium) in enumerate(items):
            selected = (sel_idx == j)
            draw_swatch(target, x, row_y, tile,
                        color=hex_(rgb), label=name,
                        label_fnt=font(label_px, "regular"),
                        selected=selected, locked=is_premium,
                        tile_alpha=a, label_alpha=a)
            x += cell_w + gap
            # only draw as many as fit (with a bit past the visible edge to imply scroll)
            if x > ox + width + 40:
                break
        top += row_gap


# ---------- scene 2: palette panel reveal ----------
def render_scene2(t: float, scene_dur: float) -> Image.Image:
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    # subtle top gradient to give the panel some breathing room
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for yy in range(0, 160):
        a = int(24 * (1 - yy / 160))
        gd.rectangle((0, yy, W, yy + 1), fill=(0, 0, 0, a))
    img.alpha_composite(grad)

    # Panel slides up + rows appear one-by-one
    slide = ease_out_cubic(clamp(t / 0.8))
    panel_offset = int((1 - slide) * 120)
    title_a = int(255 * clamp((t - 0.4) / 0.5))
    r1 = int(255 * clamp((t - 0.9) / 0.5))
    r2 = int(255 * clamp((t - 1.6) / 0.5))
    r3 = int(255 * clamp((t - 2.3) / 0.5))

    paint_palette_panel(
        img,
        ox=0, oy=panel_offset,
        width=W, height=H - panel_offset,
        rows_visible=3,
        title_alpha=title_a,
        row_alphas=(r1, r2, r3),
        selected_indices=(0, None, None),  # Classic Red selected
        tile_size=138,
    )

    # Caption at bottom, fades in after all rows settled
    cap_t = clamp((t - 3.3) / 0.6)
    if cap_t > 0.02:
        a = int(ease_in_out(cap_t) * 235)
        d = ImageDraw.Draw(img)
        d.text((W / 2, H - 150), "The whole palette. On one panel.",
               font=font(46, "medium"), fill=(30, 30, 30, a), anchor="mm")

    return img


# ---------- scene 3: fold as region ----------
def render_scene3(t: float, scene_dur: float) -> Image.Image:
    img = Image.new("RGBA", (W, H), CHARCOAL + (255,))

    # Caption top
    cap_a = int(255 * clamp(t / 0.6))
    d = ImageDraw.Draw(img)
    d.text((W / 2, 200), "The hinge is a region.",
           font=font(64, "medium"), fill=(240, 240, 240, cap_a), anchor="mm")

    # Phone body seen face-on, split vertically along the fold.
    open_t = ease_in_out(clamp((t - 0.4) / 1.6))
    body_w = 900
    body_h = 1240
    body_x = (W - body_w) // 2
    body_y = 380
    r = 92

    # background phone body (behind the two panels)
    bg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_rrect(bg, (body_x - 10, body_y - 10, body_x + body_w + 10, body_y + body_h + 10),
               r=r + 10, fill=(50, 50, 55, 255))
    img.alpha_composite(bg)

    seam_gap = int(6 + open_t * 46)  # crease widens as the phone opens
    half_w = (body_w - seam_gap) // 2
    left_box = (body_x, body_y, body_x + half_w, body_y + body_h)
    right_box = (body_x + half_w + seam_gap, body_y, body_x + body_w, body_y + body_h)

    # ---- Left: camera preview (gradient + face oval + lip hint) ----
    left_panel = Image.new("RGBA", (half_w, body_h), (0, 0, 0, 0))
    lp = ImageDraw.Draw(left_panel)
    for yy in range(body_h):
        v = yy / body_h
        rC = int(70 + (36 - 70) * v)
        gC = int(45 + (36 - 45) * v)
        bC = int(88 + (100 - 88) * v)
        lp.rectangle((0, yy, half_w, yy + 1), fill=(rC, gC, bC, 255))
    fx0, fy0 = int(half_w * 0.22), int(body_h * 0.20)
    fx1, fy1 = int(half_w * 0.78), int(body_h * 0.74)
    lp.ellipse((fx0, fy0, fx1, fy1), outline=(255, 255, 255, 180), width=6)
    lip_y = int(body_h * 0.60)
    lp.rounded_rectangle((int(half_w * 0.36), lip_y - 11,
                          int(half_w * 0.64), lip_y + 11),
                         radius=11, fill=hex_(0xC41E3A) + (230,))
    # cheek dots
    lp.ellipse((int(half_w * 0.28), int(half_w * 0.30),
                int(half_w * 0.36), int(half_w * 0.30) + int(half_w * 0.08)),
               fill=hex_(0xF4A7B0) + (110,))
    lp.ellipse((int(half_w * 0.64), int(half_w * 0.30),
                int(half_w * 0.72), int(half_w * 0.30) + int(half_w * 0.08)),
               fill=hex_(0xF4A7B0) + (110,))
    mask = Image.new("L", (half_w, body_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, half_w, body_h),
                                           radius=r, fill=255)
    img.paste(left_panel, (left_box[0], left_box[1]), mask=mask)

    # ---- Right: compact palette snippet clipped to rounded rect ----
    tmp_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    paint_palette_panel(
        tmp_img,
        ox=right_box[0], oy=right_box[1],
        width=half_w, height=body_h,
        rows_visible=2,
        title_alpha=255,
        row_alphas=(255, 255, 255),
        selected_indices=(0, None, None),
        tile_size=76,
        inner_pad_x=32,
        header_size=54,
        section_size=40,
        label_size_scale=0.24,
    )
    mask_r = Image.new("L", (half_w, body_h), 0)
    ImageDraw.Draw(mask_r).rounded_rectangle((0, 0, half_w, body_h),
                                             radius=r, fill=255)
    right_cropped = tmp_img.crop((right_box[0], right_box[1],
                                  right_box[0] + half_w, right_box[1] + body_h))
    img.paste(right_cropped, (right_box[0], right_box[1]), mask=mask_r)

    # ---- Vertical opacity capsule sitting IN the crease ----
    crease_x0 = body_x + half_w
    crease_x1 = body_x + half_w + seam_gap
    crease_cx = (crease_x0 + crease_x1) // 2
    cap_w = max(min(seam_gap - 8, 26), 10)
    cap_top = body_y + 170
    cap_bot = body_y + body_h - 170
    d2 = ImageDraw.Draw(img)
    d2.rounded_rectangle((crease_cx - cap_w // 2, cap_top,
                          crease_cx + cap_w // 2, cap_bot),
                         radius=cap_w // 2, fill=(230, 230, 230, 60))
    fill_t = ease_out_cubic(clamp((t - 1.6) / 1.4))
    fill_len = int((cap_bot - cap_top) * fill_t)
    d2.rounded_rectangle((crease_cx - cap_w // 2, cap_bot - fill_len,
                          crease_cx + cap_w // 2, cap_bot),
                         radius=cap_w // 2, fill=ACCENT + (255,))
    # knob
    knob_r = max(cap_w // 2 + 6, 14)
    knob_y = cap_bot - fill_len
    d2.ellipse((crease_cx - knob_r, knob_y - knob_r,
                crease_cx + knob_r, knob_y + knob_r),
               fill=(255, 255, 255, 255), outline=ACCENT + (255,), width=3)

    # Percent label ABOVE the phone body (never over the body itself)
    pct = int(fill_t * 100)
    d2.text((W / 2, body_y - 42), f"Opacity  {pct}%",
            font=font(38, "regular"), fill=(210, 210, 210, 230), anchor="mm")

    # Second-line hint appears late
    hint_a = int(210 * clamp((t - 2.7) / 0.9))
    if hint_a > 0:
        d3 = ImageDraw.Draw(img)
        d3.text((W / 2, H - 170),
                "Slider lives in the fold.",
                font=font(38, "light"), fill=(230, 230, 230, hint_a), anchor="mm")

    return img


# ---------- scene 4: preview all 2x2 ----------
def render_scene4(t: float, scene_dur: float) -> Image.Image:
    img = Image.new("RGBA", (W, H), (12, 12, 14, 255))

    # Caption top
    cap_a = int(255 * clamp(t / 0.5))
    d = ImageDraw.Draw(img)
    d.text((W / 2, 200), "Try four at once.",
           font=font(58, "medium"), fill=(245, 245, 245, cap_a), anchor="mm")

    # 2x2 grid of "camera" cells, each with a different lip tint
    cells = [LIPS[0], LIPS[2], LIPS[4], LIPS[3]]  # Classic Red, Rosy Pink, Coral, Berry
    grid_top = 320
    grid_bot = H - 260
    grid_h = grid_bot - grid_top
    gap = 28
    cw = (W - gap * 3) // 2
    ch = (grid_h - gap) // 2

    for i, (name, rgb, _premium) in enumerate(cells):
        row, col = divmod(i, 2)
        x = gap + col * (cw + gap)
        y = grid_top + row * (ch + gap)
        # stagger entrance
        appear_t = ease_out_cubic(clamp((t - 0.3 - i * 0.18) / 0.6))
        if appear_t <= 0.02:
            continue
        alpha = int(appear_t * 255)
        scale = 0.94 + 0.06 * appear_t
        cw_s = int(cw * scale); ch_s = int(ch * scale)
        xs = x + (cw - cw_s) // 2
        ys = y + (ch - ch_s) // 2
        # gradient background per cell
        cell = Image.new("RGBA", (cw_s, ch_s), (0, 0, 0, 0))
        cd = ImageDraw.Draw(cell)
        base = hex_(rgb)
        for yy in range(ch_s):
            v = yy / max(ch_s, 1)
            rr = int(50 + (base[0] - 50) * 0.55)
            gg = int(35 + (base[1] - 35) * 0.55)
            bb = int(70 + (base[2] - 70) * 0.55)
            # deeper at top, warmer at bottom
            factor = 0.75 + 0.5 * v
            cd.rectangle((0, yy, cw_s, yy + 1),
                         fill=(min(int(rr * factor), 255),
                               min(int(gg * factor), 255),
                               min(int(bb * factor), 255), 255))
        # face oval
        fx0, fy0 = int(cw_s * 0.22), int(ch_s * 0.16)
        fx1, fy1 = int(cw_s * 0.78), int(ch_s * 0.78)
        cd.ellipse((fx0, fy0, fx1, fy1), outline=(255, 255, 255, 170), width=5)
        # lip strip in this shade
        ly = int(ch_s * 0.60)
        cd.rounded_rectangle((int(cw_s * 0.36), ly - 12,
                              int(cw_s * 0.64), ly + 12),
                             radius=12, fill=base + (240,))
        # cheek dots
        cd.ellipse((int(cw_s * 0.28), int(ch_s * 0.52),
                    int(cw_s * 0.36), int(ch_s * 0.58)),
                   fill=base + (100,))
        cd.ellipse((int(cw_s * 0.64), int(ch_s * 0.52),
                    int(cw_s * 0.72), int(ch_s * 0.58)),
                   fill=base + (100,))
        # name pill
        pill_w = int(cw_s * 0.66)
        pill_h = 62
        px = (cw_s - pill_w) // 2
        py = ch_s - pill_h - 24
        cd.rounded_rectangle((px, py, px + pill_w, py + pill_h),
                             radius=pill_h // 2, fill=(0, 0, 0, 150))
        cd.text((cw_s / 2, py + pill_h / 2), name,
                font=font(30, "medium"), fill=(255, 255, 255, 255), anchor="mm")
        # rounded clip
        mask = Image.new("L", (cw_s, ch_s), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, cw_s, ch_s), radius=44, fill=255)
        # apply overall alpha
        if alpha < 255:
            a_layer = cell.split()[3].point(lambda v: int(v * alpha / 255))
            cell.putalpha(a_layer)
        img.paste(cell, (xs, ys), mask=mask)

    return img


# ---------- scene 5: outro ----------
def render_scene5(t: float, scene_dur: float) -> Image.Image:
    img = Image.new("RGBA", (W, H), CHARCOAL + (255,))

    # small red dot returns
    dot_t = ease_out_cubic(clamp((t - 0.1) / 0.6))
    if dot_t > 0.02:
        r = int(46 * dot_t)
        cx, cy = W // 2, int(H * 0.40)
        d = ImageDraw.Draw(img)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=hex_(0xC41E3A) + (255,))

    # wordmark
    w_t = ease_out_cubic(clamp((t - 0.35) / 0.75))
    if w_t > 0.02:
        alpha = int(w_t * 255)
        d = ImageDraw.Draw(img)
        d.text((W / 2, int(H * 0.50)), "Glammie",
               font=font(170, "medium"), fill=(245, 245, 245, alpha), anchor="mm")

    # tagline
    tag_t = ease_out_cubic(clamp((t - 0.95) / 0.9))
    if tag_t > 0.02:
        alpha = int(tag_t * 220)
        d = ImageDraw.Draw(img)
        d.text((W / 2, int(H * 0.56)), "Foldable-first.",
               font=font(46, "light"), fill=(220, 220, 220, alpha), anchor="mm")

    # fade to black at the end
    if t > scene_dur - 0.7:
        fade = clamp((t - (scene_dur - 0.7)) / 0.7)
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, int(fade * 255)))
        img.alpha_composite(overlay)

    return img


# ---------- scene composer ----------
SCENES = [
    (0.0,  3.0,  render_scene1),
    (3.0,  8.0,  render_scene2),
    (8.0,  12.5, render_scene3),
    (12.5, 17.0, render_scene4),
    (17.0, 20.0, render_scene5),
]

def frame_at(t: float) -> Image.Image:
    """Return the composite frame at time t, cross-dissolving between scenes."""
    # Figure out which scene(s) contribute and their weights.
    contributors = []
    for start, end, render in SCENES:
        # weight function: 0 outside [start-XFADE/2, end+XFADE/2]; ramps up over XFADE/2 at each side
        half = XFADE / 2
        if t < start - half or t > end + half:
            continue
        # in-ramp
        if t < start + half:
            w = smoothstep(start - half, start + half, t)
        elif t > end - half:
            w = 1 - smoothstep(end - half, end + half, t)
        else:
            w = 1.0
        w = clamp(w)
        contributors.append((start, end, render, w))

    if not contributors:
        return Image.new("RGBA", (W, H), (0, 0, 0, 255))

    # Normalize (a hard cross-dissolve without gamma; polished, quiet).
    total = sum(c[3] for c in contributors)
    if total <= 0:
        return Image.new("RGBA", (W, H), (0, 0, 0, 255))

    base = None
    for start, end, render, w in contributors:
        local_t = t - start
        img = render(local_t, end - start)
        alpha = w / total
        if base is None:
            base = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        # blend img onto base with weight `alpha`
        blend_layer = img.copy()
        a_ch = blend_layer.split()[3].point(lambda v: int(v * alpha))
        blend_layer.putalpha(a_ch)
        base.alpha_composite(blend_layer)
    return base


def main():
    for i in range(N):
        t = i / FPS
        img = frame_at(t).convert("RGB")
        img.save(OUT / f"frame_{i:04d}.png", "PNG", optimize=False)
        if i % 30 == 0:
            print(f"frame {i}/{N} @ {t:.2f}s")
    print("done")


if __name__ == "__main__":
    main()
