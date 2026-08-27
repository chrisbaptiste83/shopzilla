#!/usr/bin/env python3
"""Compatibility entrypoint for the canonical PES renderer.

The app historically had two independent renderers.  Keep this command for
older rake tasks and operator scripts, but delegate all rendering to
``scripts/render_pes.py`` so color, travel-move, and guide handling cannot drift.
``isolated`` remains accepted as a legacy name for the light storefront style.
"""

import argparse
import importlib.util
from pathlib import Path


def load_renderer():
    script = Path(__file__).resolve().parents[1] / "scripts" / "render_pes.py"
    spec = importlib.util.spec_from_file_location("shopzilla_render_pes", script)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load renderer: {script}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("pes_path")
    parser.add_argument("out_path")
    parser.add_argument(
        "--style",
        choices=["isolated", "dark", "light", "detail"],
        default="isolated",
    )
    args = parser.parse_args()

    renderer = load_renderer()
    style = "light" if args.style == "isolated" else args.style
    renderer.render(
        args.pes_path,
        args.out_path,
        style_name=style,
        trim_guides=True,
    )
