"""Create the tracked application PNG and multi-resolution Windows ICO."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ICON_SIZES = ((16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Source PNG image")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "assets",
    )
    args = parser.parse_args()

    if not args.source.is_file():
        raise FileNotFoundError(args.source)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    output_png = args.output_dir / "Win-windows-manager.png"
    output_ico = args.output_dir / "Win-windows-manager.ico"

    with Image.open(args.source) as source:
        image = source.convert("RGBA")
        alpha = image.getchannel("A")
        if alpha.getbbox() is None:
            raise ValueError("Source image is fully transparent")
        image.save(output_png, format="PNG", optimize=True)
        image.save(output_ico, format="ICO", sizes=ICON_SIZES)

    print(output_png)
    print(output_ico)


if __name__ == "__main__":
    main()
