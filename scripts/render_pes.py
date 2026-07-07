#!/usr/bin/env python3
"""
Render PES embroidery files to StitchBuddy-style dark background PNG previews.
Usage: python3 render_embroidery.py <input.pes> <output.png>
"""
import sys, os
import pyembroidery
from PIL import Image, ImageDraw, ImageFilter, ImageFont

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

def render(pes_path, out_path, size=1200, bg=(80, 80, 80)):
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
    scale = min(inner / w, inner / h)

    render_w = int(w * scale)
    render_h = int(h * scale)
    offset_x = (size - render_w) // 2
    offset_y = (size - render_h) // 2

    img = Image.new("RGB", (size, size), bg)
    draw = ImageDraw.Draw(img)

    def to_px(x, y):
        return (
            int((x - min_x) * scale) + offset_x,
            int((y - min_y) * scale) + offset_y,
        )

    threads = pattern.threadlist

    def get_color(idx):
        if idx < len(threads):
            t = threads[idx]
            return (t.color >> 16 & 0xFF, t.color >> 8 & 0xFF, t.color & 0xFF)
        return (200, 200, 200)

    def get_thread_name(idx):
        if idx < len(threads):
            t = threads[idx]
            desc = getattr(t, 'description', None) or ''
            cat  = getattr(t, 'catalog_number', None) or ''
            if desc and cat:
                return f"{desc} ({cat})"
            return desc or cat or f"Color {idx + 1}"
        return f"Color {idx + 1}"

    # Track which colors are actually used
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

    color_idx = 0
    current_color = get_color(0)
    prev = None
    stitch_width = max(3, int(scale * 0.5))

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
            shadow = tuple(max(0, c - 40) for c in current_color)
            draw.line([prev, px], fill=shadow, width=stitch_width + 1)
            draw.line([prev, px], fill=current_color, width=stitch_width)

        prev = px

    img = img.filter(ImageFilter.SHARPEN)

    # ── Vignette — radial gradient darker at edges ────────────────────────────
    vignette = Image.new("L", (size, size), 0)
    vd = ImageDraw.Draw(vignette)
    cx, cy = size // 2, size // 2
    steps = 60
    for i in range(steps, 0, -1):
        ratio = i / steps
        alpha = int(130 * (1 - ratio) ** 1.8)
        r = int(size * 0.72 * ratio)
        vd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=alpha)
    vignette = vignette.filter(ImageFilter.GaussianBlur(radius=size // 8))
    vignette_rgba = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    vignette_rgba.putalpha(vignette)
    img = img.convert("RGBA")
    img = Image.alpha_composite(img, vignette_rgba)

    # ── Rounded corners mask ──────────────────────────────────────────────────
    corner_r = size // 14  # ~86px radius on 1200px image
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size, size], radius=corner_r, fill=255)
    img.putalpha(mask)

    # ── Thread color legend (top-right corner) ────────────────────────────────
    if used_colors:
        font_title = get_font(22)
        font_item  = get_font(19)

        swatch = 20
        row_h  = 28
        margin = 14
        title  = "Thread Colors"

        # Measure panel width
        max_label = max((get_thread_name(i) for i in used_colors), key=len)
        try:
            label_w = font_item.getlength(max_label)
            title_w = font_title.getlength(title)
        except AttributeError:
            label_w = len(max_label) * 11
            title_w = len(title) * 13

        panel_w = int(max(label_w, title_w) + swatch + margin * 3 + 8)
        panel_h = margin + row_h + len(used_colors) * row_h + margin

        # Semi-transparent dark panel
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ov_draw = ImageDraw.Draw(overlay)
        px_off = size - panel_w - 18
        py_off = 18
        ov_draw.rounded_rectangle(
            [px_off, py_off, px_off + panel_w, py_off + panel_h],
            radius=10,
            fill=(30, 30, 30, 195)
        )
        img = Image.alpha_composite(img.convert("RGBA"), overlay)
        draw = ImageDraw.Draw(img)

        # Title
        draw.text((px_off + margin, py_off + margin), title,
                  fill=(220, 220, 220), font=font_title)

        # Color rows
        for row, cidx in enumerate(used_colors):
            color = get_color(cidx)
            name  = get_thread_name(cidx)
            ry = py_off + margin + row_h + row * row_h

            # Swatch
            sx = px_off + margin
            draw.rounded_rectangle(
                [sx, ry + 2, sx + swatch, ry + swatch + 2],
                radius=4,
                fill=color,
                outline=(0, 0, 0),
                width=1
            )

            # Label
            draw.text((sx + swatch + 8, ry + 4), name,
                      fill=(210, 210, 210), font=font_item)

    img.save(out_path, "PNG", optimize=True)  # saves RGBA with transparency
    print(f"Saved {out_path} ({size}x{size})")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: render_embroidery.py <input.pes> <output.png>")
        sys.exit(1)
    render(sys.argv[1], sys.argv[2])
