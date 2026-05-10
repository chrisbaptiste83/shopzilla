#!/usr/bin/env python3
"""
Render an embroidery PES file as a styled product preview image.

Usage:
  python3 render_embroidery_preview.py <pes_file> <output_png>

Produces a PNG with the design rendered in thread colors on a gray background,
a thread color swatch panel on the right, and a metadata bar at the bottom.
"""

import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import pyembroidery
from pyembroidery import STITCH, JUMP, TRIM, COLOR_CHANGE, END

# ── Layout ──────────────────────────────────────────────────────────────────
DESIGN_W      = 700   # px – design canvas width  (final image)
DESIGN_H      = 700   # px – design canvas height (final image)
PANEL_W       = 255   # px – right thread-color panel
META_H        = 78    # px – bottom metadata bar
DESIGN_PAD    = 36    # px – padding around stitches inside design canvas
SWATCH_SIZE   = 18    # px – thread color square
SWATCH_GAP    = 7     # px – gap between swatches
PANEL_INDENT  = 14    # px – left indent inside panel
RENDER_SCALE  = 3     # render at 3× then downscale (anti-aliasing)

TOTAL_W = DESIGN_W + PANEL_W
TOTAL_H = DESIGN_H + META_H

# ── Colors ───────────────────────────────────────────────────────────────────
BG        = (82, 82, 82)
PANEL_BG  = (66, 66, 66)
META_BG   = (52, 52, 52)
DIVIDER   = (100, 100, 100)
TEXT_MAIN = (220, 220, 220)
TEXT_DIM  = (160, 160, 160)
PANEL_HDR = (200, 200, 200)

# ── Fonts ────────────────────────────────────────────────────────────────────
_FONT_PATHS = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
]

def _load_font(size):
    for path in _FONT_PATHS:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def _int_to_rgb(color_int):
    return ((color_int >> 16) & 0xFF, (color_int >> 8) & 0xFF, color_int & 0xFF)


def render(pes_path: str, output_path: str) -> None:
    pattern = pyembroidery.read(pes_path)

    bounds = pattern.extents()
    min_x, min_y, max_x, max_y = bounds
    design_w = max_x - min_x or 1
    design_h = max_y - min_y or 1

    avail_w = DESIGN_W - 2 * DESIGN_PAD
    avail_h = DESIGN_H - 2 * DESIGN_PAD
    scale = min(avail_w / design_w, avail_h / design_h)

    rendered_w = design_w * scale
    rendered_h = design_h * scale
    off_x = (DESIGN_W - rendered_w) / 2
    off_y = (DESIGN_H - rendered_h) / 2

    RS = RENDER_SCALE
    img = Image.new("RGB", (TOTAL_W * RS, TOTAL_H * RS), BG)
    draw = ImageDraw.Draw(img)

    # Right panel background
    draw.rectangle(
        [DESIGN_W * RS, 0, TOTAL_W * RS - 1, DESIGN_H * RS],
        fill=PANEL_BG
    )
    # Bottom bar background
    draw.rectangle(
        [0, DESIGN_H * RS, TOTAL_W * RS - 1, TOTAL_H * RS - 1],
        fill=META_BG
    )
    # Dividers
    draw.line([DESIGN_W * RS, 0, DESIGN_W * RS, DESIGN_H * RS], fill=DIVIDER, width=RS)
    draw.line([0, DESIGN_H * RS, TOTAL_W * RS, DESIGN_H * RS], fill=DIVIDER, width=RS)

    # ── Draw stitches ────────────────────────────────────────────────────────
    threads = pattern.threadlist
    thread_idx = 0
    stitch_w = max(1, RS)

    px, py = None, None

    for sx, sy, cmd in pattern.stitches:
        if cmd in (STITCH, JUMP, TRIM):
            cx = int((sx - min_x) * scale + off_x) * RS
            cy = int((sy - min_y) * scale + off_y) * RS

            if cmd == STITCH and px is not None:
                color = _int_to_rgb(threads[thread_idx].color) if thread_idx < len(threads) else (200, 200, 200)
                draw.line([px, py, cx, cy], fill=color, width=stitch_w)

            px, py = cx, cy

        elif cmd == COLOR_CHANGE:
            thread_idx = min(thread_idx + 1, len(threads) - 1)
            px, py = None, None

        elif cmd == END:
            break

    # ── Thread color panel ───────────────────────────────────────────────────
    font_hdr  = _load_font(13 * RS)
    font_item = _load_font(12 * RS)

    py_panel = SWATCH_GAP * 2 * RS
    hdr_x = (DESIGN_W + PANEL_INDENT) * RS

    draw.text((hdr_x, py_panel), "Brother Threads", fill=PANEL_HDR, font=font_hdr)
    py_panel += (13 + SWATCH_GAP * 2) * RS

    row_h = (SWATCH_SIZE + SWATCH_GAP) * RS
    max_panel_y = (DESIGN_H - SWATCH_GAP) * RS

    for i, thread in enumerate(threads):
        if py_panel + row_h > max_panel_y:
            break

        rgb = _int_to_rgb(thread.color)
        sx1 = hdr_x
        sy1 = py_panel
        sx2 = sx1 + SWATCH_SIZE * RS
        sy2 = sy1 + SWATCH_SIZE * RS

        draw.rectangle([sx1, sy1, sx2, sy2], fill=rgb, outline=(30, 30, 30), width=max(1, RS // 2))

        label = f"{i + 1}. {thread.description} ({thread.catalog_number})"
        draw.text(
            (sx2 + SWATCH_GAP * RS, sy1 + RS),
            label,
            fill=TEXT_MAIN,
            font=font_item
        )

        py_panel += row_h

    # ── Metadata bar ─────────────────────────────────────────────────────────
    font_meta = _load_font(12 * RS)

    w_mm = round(design_w * 0.1, 1)
    h_mm = round(design_h * 0.1, 1)
    stitch_count  = sum(1 for _, _, c in pattern.stitches if c == STITCH)
    jump_count    = sum(1 for _, _, c in pattern.stitches if c == JUMP)
    color_count   = len(threads)
    filename      = Path(pes_path).name

    line1 = f"Format: PES  ·  {filename}  ·  {w_mm} × {h_mm} mm  ·  Colors: {color_count}"
    line2 = f"Stitches: {stitch_count:,}  ·  Jump Stitches: {jump_count:,}"

    meta_y = DESIGN_H * RS + (META_H // 2 - 20) * RS
    indent = DESIGN_PAD * RS

    draw.text((indent, meta_y), line1, fill=TEXT_MAIN, font=font_meta)
    draw.text((indent, meta_y + 18 * RS), line2, fill=TEXT_DIM, font=font_meta)

    # ── Downscale and save ───────────────────────────────────────────────────
    final = img.resize((TOTAL_W, TOTAL_H), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    final.save(output_path, "PNG")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <pes_file> <output_png>", file=sys.stderr)
        sys.exit(1)

    try:
        render(sys.argv[1], sys.argv[2])
        print(f"OK: {sys.argv[2]}")
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
