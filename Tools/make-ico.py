#!/usr/bin/env python3
"""Render the Windows app icon to Windows/Kibo.App/Assets/Kibo.ico.

Windows wants one .ico carrying every size Explorer, the taskbar and the Alt-Tab switcher might
ask for. The two small sizes are drawn from the grid in `Sources/Kibo/KiboSprite.swift` — parsed,
not copied, the same way `make-download-button.py` does it — at pixel sizes 1 and 2, so the
ghost is crisp rectangles rather than a blurred-down photograph of the big icon. The four large
sizes are resampled from `icon.png` in the repository root, which is the reference art.

The result is committed, like the PNGs in docs/: regenerate with this script, never hand-edit.

    python3 Tools/make-ico.py    # → Windows/Kibo.App/Assets/Kibo.ico
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPRITE = ROOT / "Sources" / "Kibo" / "KiboSprite.swift"
ICON = ROOT / "icon.png"
OUT = ROOT / "Windows" / "Kibo.App" / "Assets" / "Kibo.ico"

# Theme.swift: the mascot's midnight ground and its pale body — the icon is the dark-side pair.
GROUND = "#1E202C"
KIBO = "#F2EEE6"

SPRITE_SIZES = {16: 1, 32: 2}          # icon size → pixel size
RESAMPLED_SIZES = [48, 64, 128, 256]


def grid() -> list[list[bool]]:
    source = SPRITE.read_text(encoding="utf-8")

    def rows(pattern: str) -> list[str]:
        match = re.search(pattern, source, re.S)
        if not match:
            raise RuntimeError(f"KiboSprite.swift: no match for {pattern!r}")
        return re.findall(r'"([.Y]{16})"', match.group(1))

    dome = rows(r"private static let dome\s*=\s*\[(.*?)\]")
    hem = rows(r"private static let hem\s*=\s*\[(.*?)\]")
    eyes = rows(r"case \.open:\s*return \[(.*?)\]")
    all_rows = dome + eyes + hem
    if len(all_rows) != 16 or any(len(r) != 16 for r in all_rows):
        raise RuntimeError("expected a 16×16 grid")
    return [[c == "Y" for c in row] for row in all_rows]


def sprite_icon(size: int, pixel: int, cells: list[list[bool]]) -> Image.Image:
    """A rounded midnight square with the ghost drawn on it at whole pixels. The eyes are holes,
    so the ground shows through them, as it does everywhere else the sprite is drawn."""
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=max(2, size // 6), fill=GROUND)
    for y, row in enumerate(cells):
        for x, filled in enumerate(row):
            if filled:
                draw.rectangle((x * pixel, y * pixel, (x + 1) * pixel - 1, (y + 1) * pixel - 1), fill=KIBO)
    return image


def resampled_icon(size: int, source: Image.Image) -> Image.Image:
    return source.resize((size, size), Image.LANCZOS)


def main() -> None:
    cells = grid()
    source = Image.open(ICON).convert("RGBA")
    images = [sprite_icon(size, pixel, cells) for size, pixel in SPRITE_SIZES.items()]
    images += [resampled_icon(size, source) for size in RESAMPLED_SIZES]
    # Largest first; Pillow writes the base image plus each appended one at its own size.
    images.sort(key=lambda im: im.size[0], reverse=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    images[0].save(OUT, format="ICO", sizes=[im.size for im in images], append_images=images[1:])
    print(f"wrote {OUT.relative_to(ROOT)} with sizes {[im.size[0] for im in images]}")


if __name__ == "__main__":
    main()
