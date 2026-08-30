#!/usr/bin/env python3
"""
Render PES embroidery files to PNG previews.
Usage: python3 render_pes.py <input.pes> <output.png> [--style dark|light|detail]

Styles:
  dark   — dark gray background, thread legend, full design (default)
  light  — warm cream background, thread legend, full design
  detail — dark background, zoomed 1.7x into center, no legend
"""
import sys, os, argparse
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
        "bg":           (250, 250, 248),
        "legend":       True,
        "zoom":         1.0,
        "panel_fill":   (255, 255, 255, 238),
        "panel_title":  (40, 40, 40),
        "panel_text":   (60, 60, 60),
        "vignette_str": 0,
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


def text_width(font, text):
    try:
        return font.getlength(text)
    except AttributeError:
        return len(text) * max(7, getattr(font, "size", 14) * 0.55)


def truncate_text(font, text, max_width):
    """Fit a legend label without allowing it to widen beyond its panel."""
    if text_width(font, text) <= max_width:
        return text

    suffix = "..."
    low, high = 0, len(text)
    while low < high:
        mid = (low + high + 1) // 2
        if text_width(font, text[:mid] + suffix) <= max_width:
            low = mid
        else:
            high = mid - 1
    return text[:low].rstrip() + suffix


def thread_color(rgb, style_name):
    """Render threads true-to-color.

    Embroidery previews are a buying aid: the customer is choosing an actual
    thread color, so the swatch and stitches must match the thread's real RGB.
    We deliberately do NOT saturate, lift, or darken the color. Visibility of
    threads that sit close to the background is handled structurally by the
    per-stitch outline in the draw loop (see render()), not by lying about the
    color."""
    return tuple(int(c) for c in rgb)


def _near_background(color, bg, threshold=48):
    """True if a thread color is close enough to the background that it would
    be hard to see. Uses simple per-channel distance — good enough to decide
    whether a stitch needs a contrast halo."""
    return sum(abs(c - b) for c, b in zip(color, bg)) < threshold


def detect_guide_stitches(stitches):
    """Return a set of stitch indices that are hoop-registration guides, not art.

    Some digitized designs embed non-decorative alignment stitching that a
    *photographed* garment would never show but which pyembroidery replays like
    any other stitch: (a) a basting/placement box — the first color block, a
    sparse perimeter rectangle sewn to register the hoop and torn out after; and
    (b) long axis-aligned colinear running-stitch runs (cross-hair guides). Both
    read as straight lines slashing across an otherwise clean preview.

    This is opt-in (--trim-guides) and conservative: we only flag runs that are
    (1) long relative to the design, (2) essentially perfectly horizontal or
    vertical, and (3) built from uniform short running stitches — the signature
    of a guide, never of a fill. When in doubt we keep the stitch, because a
    false positive erases real art and a false negative just leaves a faint line.
    """
    STITCH = pyembroidery.STITCH
    guide = set()

    pts = [(i, s[0], s[1], s[2]) for i, s in enumerate(stitches)]
    real = [(i, x, y) for i, x, y, c in pts if c == STITCH]
    if len(real) < 20:
        return guide

    allx = [x for _, x, _ in real]
    ally = [y for _, _, y in real]
    w = (max(allx) - min(allx)) or 1
    h = (max(ally) - min(ally)) or 1
    span = (w + h) / 2.0

    # (b) axis-aligned colinear guide runs. Walk consecutive same-block stitches;
    # accumulate a run while it stays on one axis (the off-axis drift stays tiny)
    # and each step is a short running stitch. Flag the whole run if it is long.
    # A placement box often turns corners without emitting a JUMP, so a run must
    # also flush when its orientation changes; otherwise the four sides merge
    # into one non-axis-aligned path and evade detection.
    min_run_len = span * 0.35          # a guide spans a big fraction of the design
    axis_tol = span * 0.01             # off-axis wobble allowed to still be "straight"
    max_step = span * 0.06             # running-stitch step ceiling (guides are dense)

    axis_ratio = 0.08

    def orientation(a, b):
        dx = abs(b[0] - a[0]); dy = abs(b[1] - a[1])
        if max(dx, dy) == 0:
            return None
        ratio = min(dx, dy) / max(dx, dy)
        if ratio > axis_ratio:
            return None
        return "horizontal" if dx >= dy else "vertical"

    def flush(run):
        if len(run) < 8:
            return
        xs0 = [p[1] for p in run]; ys0 = [p[2] for p in run]
        dx = max(xs0) - min(xs0); dy = max(ys0) - min(ys0)
        horizontal = dy <= axis_tol and dx >= min_run_len
        vertical = dx <= axis_tol and dy >= min_run_len
        if horizontal or vertical:
            for p in run:
                guide.add(p[0])

    run = []
    prev = None
    for i, x, y, c in pts:
        if c == pyembroidery.COLOR_CHANGE:
            flush(run); run = []; prev = None; continue
        if c != STITCH:
            flush(run); run = []; prev = None; continue
        if prev is None:
            run = [(i, x, y)]; prev = (x, y); continue
        step = ((x - prev[0]) ** 2 + (y - prev[1]) ** 2) ** 0.5
        run_orientation = (
            orientation(
                (run[-2][1], run[-2][2]),
                (run[-1][1], run[-1][2]),
            )
            if len(run) >= 2 else None
        )
        segment_orientation = orientation(prev, (x, y))
        if step > max_step or (
            run_orientation is not None
            and segment_orientation is not None
            and segment_orientation != run_orientation
        ):
            flush(run); run = [(i, x, y)]; prev = (x, y); continue
        run.append((i, x, y)); prev = (x, y)
    flush(run)

    # (a) first-color placement box: a small, low-count first block whose stitches
    # are almost all near the design's outer edges. Only trip when it is clearly a
    # frame (very few stitches, strongly perimeter-biased) so real first-color
    # art (borders that are part of the picture) is never removed.
    first_block = []
    ci = 0
    for i, x, y, c in pts:
        if c == pyembroidery.COLOR_CHANGE:
            ci += 1
        if ci > 0:
            break
        if c == STITCH:
            first_block.append((i, x, y))
    if first_block and len(first_block) < 0.04 * len(real):
        minx, miny = min(allx), min(ally)
        edge = 0
        for _, x, y in first_block:
            if (x - minx) < w * 0.08 or (max(allx) - x) < w * 0.08 \
               or (y - miny) < h * 0.08 or (max(ally) - y) < h * 0.08:
                edge += 1
        if edge / len(first_block) > 0.6:
            for i, _, _ in first_block:
                guide.add(i)

    return guide


# ── Core renderer ─────────────────────────────────────────────────────────────

def render(pes_path, out_path, size=1200, style_name="dark", trim_guides=False, rotation=0.0):
    cfg = STYLES.get(style_name, STYLES["dark"])

    pattern = pyembroidery.read(pes_path)
    if not pattern:
        print(f"Failed to read {pes_path}", file=sys.stderr)
        sys.exit(1)

    stitches = pattern.stitches
    guide_idx = detect_guide_stitches(stitches) if trim_guides else set()
    xs = [s[0] for s in stitches if s[2] not in (pyembroidery.END, pyembroidery.STOP)]
    ys = [s[1] for s in stitches if s[2] not in (pyembroidery.END, pyembroidery.STOP)]
    if not xs:
        print("No stitch data", file=sys.stderr)
        sys.exit(1)

    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    w = max_x - min_x or 1
    h = max_y - min_y or 1

    # Rotate the artwork around its source bounding-box center while leaving
    # the preview frame and thread legend upright. Positive degrees rotate
    # clockwise in the rendered image coordinate system.
    if rotation:
        import math

        angle = math.radians(float(rotation))
        cos_angle = math.cos(angle)
        sin_angle = math.sin(angle)
        center_x = (min_x + max_x) / 2.0
        center_y = (min_y + max_y) / 2.0

        def rotate_point(x, y):
            dx = x - center_x
            dy = y - center_y
            return (
                center_x + (dx * cos_angle - dy * sin_angle),
                center_y + (dx * sin_angle + dy * cos_angle),
            )

        stitches = [(*rotate_point(stitch[0], stitch[1]), stitch[2]) for stitch in stitches]
        xs = [s[0] for s in stitches if s[2] not in (pyembroidery.END, pyembroidery.STOP)]
        ys = [s[1] for s in stitches if s[2] not in (pyembroidery.END, pyembroidery.STOP)]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        w = max_x - min_x or 1
        h = max_y - min_y or 1

    img = Image.new("RGB", (size, size), cfg["bg"])
    draw = ImageDraw.Draw(img)

    threads = pattern.threadlist

    def raw_color(idx):
        if idx < len(threads):
            t = threads[idx]
            return (t.color >> 16 & 0xFF, t.color >> 8 & 0xFF, t.color & 0xFF)
        return (200, 200, 200)

    def get_color(idx):
        return thread_color(raw_color(idx), style_name)

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

    # Track used colors in order (excluding trimmed guide stitches, so a color
    # block that was purely a basting box does not appear in the legend).
    used_colors = []
    seen = set()
    color_idx = 0
    for stitch_i, stitch in enumerate(stitches):
        cmd = stitch[2]
        if cmd == pyembroidery.COLOR_CHANGE:
            color_idx += 1
        elif cmd == pyembroidery.STITCH and stitch_i not in guide_idx and color_idx not in seen:
            seen.add(color_idx)
            used_colors.append(color_idx)

    # Measure the legend before positioning the artwork. Most designs can stay
    # centered at full size. When the top-right legend would cover stitches,
    # reserve a separate art area to its left and fit the design there instead.
    legend_layout = None
    if cfg["legend"] and used_colors:
        swatch = 20
        margin = 14
        title_row_h = 28
        max_panel_h = size - 36
        row_h = min(
            28,
            max(14, (max_panel_h - margin * 2 - title_row_h) // len(used_colors)),
        )
        font_title = get_font(22)
        font_item = get_font(max(11, min(19, row_h - 7)))
        title = "Thread Colors"

        max_label_w = max(text_width(font_item, get_thread_name(i)) for i in used_colors)
        panel_w = min(
            int(max(max_label_w, text_width(font_title, title)) + swatch + margin * 3 + 32),
            int(size * 0.38),
        )
        panel_h = margin + title_row_h + len(used_colors) * row_h + margin
        legend_layout = {
            "font_title": font_title,
            "font_item": font_item,
            "swatch": swatch,
            "row_h": row_h,
            "margin": margin,
            "title": title,
            "x": size - panel_w - 18,
            "y": 18,
            "width": panel_w,
            "height": panel_h,
        }

    pad = 80
    inner = size - pad * 2
    base_scale = min(inner / w, inner / h)
    scale = base_scale * cfg["zoom"]
    render_w = int(w * scale)
    render_h = int(h * scale)
    offset_x = (size - render_w) // 2
    offset_y = (size - render_h) // 2

    if legend_layout:
        gap = 28
        legend_left = legend_layout["x"]
        legend_top = legend_layout["y"]
        legend_bottom = legend_top + legend_layout["height"]
        overlaps_legend = any(
            stitch[2] == pyembroidery.STITCH
            and stitch_i not in guide_idx
            and legend_left - gap <= int((stitch[0] - min_x) * scale) + offset_x
            and int((stitch[1] - min_y) * scale) + offset_y <= legend_bottom + gap
            and int((stitch[1] - min_y) * scale) + offset_y >= legend_top - gap
            for stitch_i, stitch in enumerate(stitches)
        )

        if overlaps_legend:
            art_width = max(1, legend_left - gap - pad)
            base_scale = min(art_width / w, inner / h)
            scale = base_scale * cfg["zoom"]
            render_w = int(w * scale)
            render_h = int(h * scale)
            offset_x = pad + (art_width - render_w) // 2
            offset_y = pad + (inner - render_h) // 2

    # Draw stitches
    color_idx = 0
    current_color = get_color(0)
    prev = None
    prev_src = None
    drop = cfg["shadow_drop"]
    stitch_width = max(3, int(base_scale * 0.52))

    # Max plausible single-stitch length, in source (0.1mm) units. Real stitches
    # rarely exceed ~12mm; a "stitch" longer than this is an unflagged travel
    # move (some digitizers encode jumps as long STITCH runs with no JUMP/TRIM).
    # Drawing it would streak a straight line across the whole design — the
    # stray lines we see in the raw render. Floor at 200u, but scale up for
    # large designs so we never clip legitimate long fill stitches.
    max_stitch_len = max(200.0, (w + h) * 0.5 * 0.10)

    for stitch_i, stitch in enumerate(stitches):
        x, y, cmd = stitch[0], stitch[1], stitch[2]

        if cmd == pyembroidery.COLOR_CHANGE:
            color_idx += 1
            current_color = get_color(color_idx)
            prev = None
            prev_src = None
            continue

        if cmd in (pyembroidery.END, pyembroidery.STOP, pyembroidery.TRIM, pyembroidery.JUMP):
            # JUMP is a pen-up travel move — resetting prev prevents a stray
            # connecting line being drawn across the design to the next stitch.
            prev = None
            prev_src = None
            continue

        # Guide stitch (basting box / registration cross-hair) — skip it and
        # break the pen path so no line is drawn to or from it.
        if stitch_i in guide_idx:
            prev = None
            prev_src = None
            continue

        px = to_px(x, y)

        # Guard: skip the connecting line for an over-long segment (unflagged
        # travel), but still advance the pen so the next real stitch connects.
        if cmd == pyembroidery.STITCH and prev_src is not None:
            seg_len = ((x - prev_src[0]) ** 2 + (y - prev_src[1]) ** 2) ** 0.5
            if seg_len > max_stitch_len:
                prev = px
                prev_src = (x, y)
                continue

        if cmd == pyembroidery.STITCH and prev is not None:
            # Structural visibility: if the thread sits very close to the
            # background, draw a faint contrast halo so it still reads —
            # without altering the true thread color itself.
            if _near_background(current_color, cfg["bg"]):
                halo = (235, 235, 235) if sum(cfg["bg"]) < 384 else (35, 35, 35)
                draw.line([prev, px], fill=halo, width=stitch_width + 3)
            shadow = tuple(max(0, c - drop) for c in current_color)
            draw.line([prev, px], fill=shadow, width=stitch_width + 1)
            draw.line([prev, px], fill=current_color, width=stitch_width)

        prev = px
        prev_src = (x, y)

    img = img.filter(ImageFilter.SHARPEN)

    # ── Vignette ──────────────────────────────────────────────────────────────
    img = img.convert("RGBA")
    vstr = cfg["vignette_str"]
    if vstr:
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
        img = Image.alpha_composite(img, vignette_rgba)

    # ── Thread legend (dark + light styles only) ──────────────────────────────
    if legend_layout:
        font_title = legend_layout["font_title"]
        font_item = legend_layout["font_item"]
        swatch = legend_layout["swatch"]
        row_h = legend_layout["row_h"]
        margin = legend_layout["margin"]
        title = legend_layout["title"]
        panel_w = legend_layout["width"]
        panel_h = legend_layout["height"]
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ov_draw = ImageDraw.Draw(overlay)
        px_off = legend_layout["x"]
        py_off = legend_layout["y"]
        panel_outline = (216, 222, 218, 255) if style_name == "light" else (255, 255, 255, 45)
        ov_draw.rounded_rectangle(
            [px_off, py_off, px_off + panel_w, py_off + panel_h],
            radius=10,
            fill=cfg["panel_fill"],
            outline=panel_outline,
            width=1,
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
            label_width = panel_w - margin * 3 - swatch - 8
            name = truncate_text(font_item, get_thread_name(cidx), label_width)
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
    parser.add_argument(
        "--rotate",
        type=float,
        default=0.0,
        help="Rotate artwork clockwise by this many degrees; frame and legend stay upright.",
    )
    parser.add_argument(
        "--trim-guides",
        action="store_true",
        help="Remove hoop-registration guides (basting box, cross-hair alignment "
             "runs) that are not part of the design art.",
    )
    args = parser.parse_args()
    render(args.pes_path, args.out_path, style_name=args.style,
           trim_guides=args.trim_guides, rotation=args.rotate)
