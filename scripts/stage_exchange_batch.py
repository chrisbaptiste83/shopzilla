#!/usr/bin/env python3
"""
Shopzilla Exchange Batch Stager
===============================
Prepares a curated exchange batch for peer-to-peer catalog curation over Tailscale.

Actions performed:
1. Scans source directory for valid .pes embroidery files.
2. Normalizes filenames into snake_case.
3. Renders high-resolution 1200x1200px stitch previews with cream canvas & drop shadow.
4. Computes cryptographic SHA-256 checksums for source PES files and preview images.
5. Emits manifest.json and checksums.sha256 into the target batch folder.

Usage:
  python3 scripts/stage_exchange_batch.py \
    --source-dir "$HOME/Desktop/Embroidery Files" \
    --batch-name "batch-02-animals" \
    --limit 10 \
    --category "Animals & Pets"
"""

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
import pyembroidery
from PIL import Image, ImageDraw, ImageFilter, ImageFont


def compute_sha256(filepath: Path) -> str:
    hasher = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()


def sanitize_filename(name: str) -> str:
    base, ext = os.path.splitext(name)
    clean_base = re.sub(r"[^\w\s-]", "", base).strip().lower()
    clean_base = re.sub(r"[-\s]+", "_", clean_base)
    return f"{clean_base}{ext.lower()}"


def format_title(filename: str) -> str:
    base, _ = os.path.splitext(filename)
    clean = re.sub(r"[_\-]+", " ", base).strip()
    words = clean.split()
    capitalized = [w.capitalize() for w in words]
    title = " ".join(capitalized)
    return title if len(title) >= 3 else f"{title} Design"


def infer_category(title: str, default: str = "Embroidery Designs") -> str:
    lower = title.lower()
    if any(k in lower for k in ["rose", "flower", "floral", "vignette", "bud", "petal", "bloom", "blossom", "daisy"]):
        return "Floral Designs"
    if any(k in lower for k in ["bear", "dog", "cat", "bird", "duck", "owl", "butterfly", "animal", "pet", "fish", "bunny"]):
        return "Animals & Pets"
    if any(k in lower for k in ["heart", "xmas", "christmas", "easter", "holiday", "santa", "halloween", "valentine", "tree"]):
        return "Holidays & Celebrations"
    if any(k in lower for k in ["mono", "letter", "alphabet", "border", "font", "crest"]):
        return "Monograms & Borders"
    if any(k in lower for k in ["baby", "nursery", "bib", "rattle", "teddy", "kid", "child"]):
        return "Baby & Nursery"
    return default


def get_font(size: int):
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


def render_pes_preview(pes_path: Path, output_png: Path):
    pattern = pyembroidery.read(str(pes_path))
    if not pattern or not pattern.stitches:
        raise ValueError(f"No stitches found in {pes_path}")

    # Remove trim jump lines
    valid_stitches = [s for s in pattern.stitches if s[2] == pyembroidery.STITCH]
    if not valid_stitches:
        raise ValueError("Pattern contains no stitch commands")

    xs = [s[0] for s in valid_stitches]
    ys = [s[1] for s in valid_stitches]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    w_stitch = max_x - min_x or 1
    h_stitch = max_y - min_y or 1

    canvas_w, canvas_h = 1200, 1200
    stitch_area_w, stitch_area_h = 960, 960

    scale = min(stitch_area_w / w_stitch, stitch_area_h / h_stitch)
    offset_x = (canvas_w - w_stitch * scale) / 2 - min_x * scale
    offset_y = (canvas_h - h_stitch * scale) / 2 - min_y * scale - 30

    # Base canvas (Warm cream)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (250, 250, 248, 255))

    # Stitch layer
    stitch_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(stitch_layer)

    thread_colors = pattern.threadlist if pattern.threadlist else []
    color_index = 0
    current_color = (60, 60, 60, 240)

    if thread_colors:
        t = thread_colors[0]
        current_color = (t.get_red(), t.get_green(), t.get_blue(), 240)

    prev_x, prev_y = None, None
    for s in pattern.stitches:
        cmd = s[2]
        if cmd == pyembroidery.COLOR_CHANGE:
            color_index += 1
            if color_index < len(thread_colors):
                t = thread_colors[color_index]
                current_color = (t.get_red(), t.get_green(), t.get_blue(), 240)
            prev_x, prev_y = None, None
            continue

        if cmd != pyembroidery.STITCH:
            prev_x, prev_y = None, None
            continue

        cur_x = s[0] * scale + offset_x
        cur_y = s[1] * scale + offset_y

        if prev_x is not None:
            draw.line([(prev_x, prev_y), (cur_x, cur_y)], fill=current_color, width=2)
        prev_x, prev_y = cur_x, cur_y

    # Drop shadow
    shadow_mask = stitch_layer.getchannel("A")
    shadow = Image.new("RGBA", (canvas_w, canvas_h), (30, 30, 30, 70))
    shadow.putalpha(shadow_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))

    canvas.paste(shadow, (0, 10), shadow)
    canvas.paste(stitch_layer, (0, 0), stitch_layer)

    # Info badge at bottom
    font_title = get_font(26)
    font_sub = get_font(18)
    badge_draw = ImageDraw.Draw(canvas)
    title_text = format_title(pes_path.name)
    sub_text = f"Stitches: {len(valid_stitches):,}  |  Format: PES  |  Colors: {max(1, len(thread_colors))}"

    badge_draw.rectangle([(60, canvas_h - 110), (canvas_w - 60, canvas_h - 40)], fill=(255, 255, 255, 230), outline=(220, 220, 220, 255), width=1)
    badge_draw.text((80, canvas_h - 102), title_text, fill=(40, 40, 40, 255), font=font_title)
    badge_draw.text((80, canvas_h - 70), sub_text, fill=(100, 100, 100, 255), font=font_sub)

    final_img = canvas.convert("RGB")
    final_img.save(output_png, "PNG", optimize=True)


def main():
    parser = argparse.ArgumentParser(description="Stage an exchange batch for Tailscale curation")
    parser.add_argument("--source-dir", required=True, help="Directory containing source PES files")
    parser.add_argument("--batch-name", required=True, help="Batch directory name (e.g. batch-02-animals)")
    parser.add_argument("--target-base", default="/Users/Shared/ShopzillaCatalog/10-exchange/ready", help="Target base exchange path")
    parser.add_argument("--limit", type=int, default=10, help="Max designs to stage")
    parser.add_argument("--category", default=None, help="Explicit category override")
    args = parser.parse_args()

    source_path = Path(args.source_dir).expanduser().resolve()
    if not source_path.exists():
        print(f"Error: source directory '{source_path}' does not exist", file=sys.stderr)
        sys.exit(1)

    batch_dir = Path(args.target_base).expanduser().resolve() / args.batch_name
    source_dir = batch_dir / "source"
    previews_dir = batch_dir / "previews"

    source_dir.mkdir(parents=True, exist_ok=True)
    previews_dir.mkdir(parents=True, exist_ok=True)

    pes_candidates = sorted([p for p in source_path.rglob("*") if p.suffix.lower() == ".pes" and not p.name.startswith(".")])
    if not pes_candidates:
        print(f"Error: no .pes files found in '{source_path}'", file=sys.stderr)
        sys.exit(1)

    selected = pes_candidates[:args.limit]
    print(f"Staging {len(selected)} PES designs into {batch_dir}...")

    items = []
    checksum_lines = []

    for idx, orig_pes in enumerate(selected, 1):
        clean_name = sanitize_filename(orig_pes.name)
        staged_pes_dest = source_dir / clean_name

        # Copy PES
        with open(orig_pes, "rb") as sf, open(staged_pes_dest, "wb") as df:
            df.write(sf.read())

        pes_sha = compute_sha256(staged_pes_dest)
        checksum_lines.append(f"{pes_sha}  source/{clean_name}")

        # Render preview
        preview_filename = f"{Path(clean_name).stem}_preview_light.png"
        preview_dest = previews_dir / preview_filename
        render_pes_preview(staged_pes_dest, preview_dest)

        img_sha = compute_sha256(preview_dest)
        checksum_lines.append(f"{img_sha}  previews/{preview_filename}")

        title = format_title(orig_pes.name)
        category = args.category if args.category else infer_category(title)

        items.append({
            "original_filename": orig_pes.name,
            "staged_filename": clean_name,
            "candidate_title": title,
            "candidate_category": category,
            "format": "PES",
            "file_size_bytes": staged_pes_dest.stat().st_size,
            "sha256": pes_sha,
            "preview_image": f"previews/{preview_filename}",
            "curator_notes": "",
            "curation_status": "pending_review"
        })
        print(f"  [{idx}/{len(selected)}] {clean_name} -> {title} ({category})")

    # Write checksums.sha256
    checksum_file = batch_dir / "checksums.sha256"
    checksum_file.write_text("\n".join(checksum_lines) + "\n")

    # Write manifest.json
    manifest = {
        "batch_id": args.batch_name,
        "created_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "prepared_by": os.environ.get("USER", "Christopher Baptiste"),
        "assigned_to": "Gloria",
        "total_designs": len(items),
        "status": "ready_for_curation",
        "instructions": "Verify stitch preview quality, confirm candidate title, verify category taxonomy, and set dimensions if known.",
        "items": items
    }
    manifest_file = batch_dir / "manifest.json"
    with open(manifest_file, "w") as f:
        json.dump(manifest, f, indent=2)

    print("\nBatch staged successfully!")
    print(f"  Batch Directory: {batch_dir}")
    print(f"  Manifest:        {manifest_file}")
    print(f"  Checksums:       {checksum_file}")
    print(f"  Total items:     {len(items)}")


if __name__ == "__main__":
    main()
