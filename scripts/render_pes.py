#!/usr/bin/env python3
"""
Render PES embroidery files to PNG previews.
Usage: python3 render_pes.py <input.pes> <output.png> [--style dark|light|detail]

Styles:
  dark   — dark gray background, thread legend, full design (default)
  light  — warm cream background, thread legend, full design
  detail — dark background, zoomed 1.7x into center, no legend
"""
import sys, os, argparse, colorsys
import pyembroidery
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ── Style definitions ─────────────────────────────────────────────────────────

STYLES = {
    "dark": {
        "bg":           (72, 72, 72),
        "legend":       True,
        "zoom":         1.0,
        "panel_fill":   (25, 25, 25, 200),
        "panel_title":  (225, 225, 225),
        "panel_text":   (210, 210, 210),
        "vignette_str": 130,
        "shadow_drop":  20,
    },
    "light": {
        "bg":           (245, 240, 228),
        "legend":       True,
        "zoom":         1.0,
        "panel_fill":   (255, 255, 255, 215),
        "panel_title":  (40, 40, 40),
        "panel_text":   (60, 60, 60),
        "vignette_str": 40,
        "shadow_drop":  15,
    },
    "detail": {
        "bg":           (58, 58, 58),
        "legend":       False,
        "zoom":         1.75,
        "panel_fill":   None,
        "panel_title":  None,
        "panel_text":   None,
        "vignette_str": 90,
        "shadow_drop":  18,
    },
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def get_font(size):
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSText.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()


def boost_color(rgb, style_name):
    """Boost saturation and ensure visibility against the background."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    # Saturate — push muted colors toward their hue
    s = min(1.0, s * 1.35)

    if style_name == "dark" or style_name == "detail":
        # Lift very dark threads so they read against the dark bg
        v = max(v, 0.28)
    else:
        # On light bg, darken very pale threads so they don't disappear
        if v > 0.92 and s < 0.15:
            v = 0.75

    r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
    return (int(r2 * 255), int(g2 * 255), int(b2 * 255))


# ── Core renderer ─────────────────────────────────────────────────────────────

def render(pes_path, out_path, size=1200, style_name="dark"):
    cfg = STYLES.get(style_name, STYLES["dark"])

    pattern = pyembroidery.read(pes_path)
    if not pattern:
        print(f"Failed to read {pes_path}", file=sys.stderr)
        sys.exit(1)

    stitches = pattern.stitches
    xs = [s[0] for s in stitches if s[2] not in (pyembroidery.END, pyembroidery.STOP)]
    ys = [s[1] for s in stitches if s[2] not in (pyembroidery.END, pyembroidery.STOP)]
    if not xs:
        print("No stitch data", file=sys.stderr)
        sys.exit(1)

    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    w = max_x - min_x or 1
    h = max_y - min_y or 1

    pad = 80
    inner = size - pad * 2
    base_scale = min(inner / w, inner / h)
    scale = base_scale * cfg["zoom"]

    render_w = int(w * scale)
    render_h = int(h * scale)
    offset_x = (size - render_w) // 2
    offset_y = (size - render_h) // 2

    img = Image.new("RGB", (size, size), cfg["bg"])
    draw = ImageDraw.Draw(img)

    threads = pattern.threadlist

    def raw_color(idx):
        if idx < len(threads):
            t = threads[idx]
            return (t.color >> 16 & 0xFF, t.color >> 8 & 0xFF, t.color & 0xFF)
        return (200, 200, 200)

    def get_color(idx):
        return boost_color(raw_color(idx), style_name)

    def get_thread_name(idx):
        if idx < len(threads):
            t = threads[idx]
            desc = getattr(t, "description", None) or ""
            cat  = getattr(t, "catalog_number", None) or ""
            if desc and cat:
                return f"{desc} ({cat})"
            return desc or cat or f"Color {idx + 1}"
        return f"Color {idx + 1}"

    def to_px(x, y):
        return (
            int((x - min_x) * scale) + offset_x,
            int((y - min_y) * scale) + offset_y,
        )

    # Track used colors in order
    used_colors = []
    seen = set()
    color_idx = 0
    for stitch in stitches:
        cmd = stitch[2]
        if cmd == pyembroidery.COLOR_CHANGE:
            color_idx += 1
        elif cmd == pyembroidery.STITCH and color_idx not in seen:
            seen.add(color_idx)
            used_colors.append(color_idx)

    # Draw stitches
    color_idx = 0
    current_color = get_color(0)
    prev = None
    drop = cfg["shadow_drop"]
    stitch_width = max(3, int(base_scale * 0.52))

    for stitch in stitches:
        x, y, cmd = stitch[0], stitch[1], stitch[2]

        if cmd == pyembroidery.COLOR_CHANGE:
            color_idx += 1
            current_color = get_color(color_idx)
            prev = None
            continue

        if cmd in (pyembroidery.END, pyembroidery.STOP, pyembroidery.TRIM):
            prev = None
            continue

        px = to_px(x, y)

        if cmd == pyembroidery.STITCH and prev is not None:
            shadow = tuple(max(0, c - drop) for c in current_color)
            draw.line([prev, px], fill=shadow, width=stitch_width + 1)
            draw.line([prev, px], fill=current_color, width=stitch_width)

        prev = px

    img = img.filter(ImageFilter.SHARPEN)

    # ── Vignette ──────────────────────────────────────────────────────────────
    vstr = cfg["vignette_str"]
    vignette = Image.new("L", (size, size), 0)
    vd = ImageDraw.Draw(vignette)
    cx, cy = size // 2, size // 2
    steps = 60
    for i in range(steps, 0, -1):
        ratio = i / steps
        alpha = int(vstr * (1 - ratio) ** 1.8)
        r = int(size * 0.72 * ratio)
        vd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=alpha)
    vignette = vignette.filter(ImageFilter.GaussianBlur(radius=size // 8))
    vignette_rgba = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    vignette_rgba.putalpha(vignette)
    img = img.convert("RGBA")
    img = Image.alpha_composite(img, vignette_rgba)

    # ── Rounded corners ───────────────────────────────────────────────────────
    corner_r = size // 14
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size, size], radius=corner_r, fill=255)
    img.putalpha(mask)

    # ── Thread legend (dark + light styles only) ──────────────────────────────
    if cfg["legend"] and used_colors:
        font_title = get_font(22)
        font_item  = get_font(19)

        swatch = 20
        row_h  = 28
        margin = 14
        title  = "Thread Colors"

        max_label = max((get_thread_name(i) for i in used_colors), key=len)
        try:
            label_w = font_item.getlength(max_label)
            title_w = font_title.getlength(title)
        except AttributeError:
            label_w = len(max_label) * 11
            title_w = len(title) * 13

        panel_w = int(max(label_w, title_w) + swatch + margin * 3 + 8)
        panel_h = margin + row_h + len(used_colors) * row_h + margin

        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ov_draw = ImageDraw.Draw(overlay)
        px_off = size - panel_w - 18
        py_off = 18
        ov_draw.rounded_rectangle(
            [px_off, py_off, px_off + panel_w, py_off + panel_h],
            radius=10,
            fill=cfg["panel_fill"],
        )
        img = Image.alpha_composite(img.convert("RGBA"), overlay)
        draw = ImageDraw.Draw(img)

        draw.text(
            (px_off + margin, py_off + margin),
            title,
            fill=cfg["panel_title"],
            font=font_title,
        )

        for row, cidx in enumerate(used_colors):
            color = get_color(cidx)
            name  = get_thread_name(cidx)
            ry = py_off + margin + row_h + row * row_h
            sx = px_off + margin

            # Swatch border: dark on light bg, light on dark bg
            border = (180, 180, 180) if style_name == "light" else (0, 0, 0)
            draw.rounded_rectangle(
                [sx, ry + 2, sx + swatch, ry + swatch + 2],
                radius=4,
                fill=color,
                outline=border,
                width=1,
            )
            draw.text(
                (sx + swatch + 8, ry + 4),
                name,
                fill=cfg["panel_text"],
                font=font_item,
            )

    img.save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path} ({size}x{size}, style={style_name})")


# ── CLI ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("pes_path")
    parser.add_argument("out_path")
    parser.add_argument("--style", choices=["dark", "light", "detail"], default="dark")
    args = parser.parse_args()
    render(args.pes_path, args.out_path, style_name=args.style)
