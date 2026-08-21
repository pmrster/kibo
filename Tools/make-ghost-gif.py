#!/usr/bin/env python3
"""Render Kibo's idle blink and "boo~" as looping GIFs, for the README.

    python3 Tools/make-ghost-gif.py            # → docs/kibo-idle-{light,dark}.gif, docs/kibo-boo-{light,dark}.gif

The grid comes from `Sources/Kibo/KiboSprite.swift` — parsed, not copied — and the timing from
`KiboView.swift`: a blink every 4 s lasting one 0.4 s tick, and a one-pixel drift every 1.6 s.
Every frame is drawn in whole sprite pixels on a transparent background, so the GIF is crisp on
any surface. Two colour variants because a GIF has no dark-mode: midnight for light pages, pale
for dark, the same pair `Palette.kibo` uses.
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SPRITE = ROOT / "Sources" / "Kibo" / "KiboSprite.swift"
DOCS = ROOT / "docs"

PIXEL = 6                      # whole pixels only — see KiboView
TICK_MS = 400                  # KiboView's timeline period
COLOURS = {"light": (0x1E, 0x20, 0x2C), "dark": (0xF2, 0xEE, 0xE6)}   # Palette.kibo
MONO_CANDIDATES = (
    Path("/System/Library/Fonts/SFNSMono.ttf"),
    Path("/System/Library/Fonts/Menlo.ttc"),
    Path("/System/Library/Fonts/Supplemental/Courier New Bold.ttf"),
)


def grid(eyes: str) -> list[list[bool]]:
    text = SPRITE.read_text()

    def rows(pattern: str) -> list[str]:
        match = re.search(pattern, text, re.S)
        if not match:
            raise RuntimeError(f"KiboSprite.swift: no match for {pattern!r}")
        return re.findall(r'"([.Y]+)"', match.group(1))

    dome = rows(r"private static let dome\s*=\s*\[(.*?)\]")
    hem = rows(r"private static let hem\s*=\s*\[(.*?)\]")
    eye_rows = rows(r"case \." + eyes + r":\s*return \[(.*?)\]")
    all_rows = dome + eye_rows + hem
    if len(all_rows) != 16 or any(len(r) != 16 for r in all_rows):
        raise RuntimeError("expected a 16×16 grid")
    return [[c == "Y" for c in row] for row in all_rows]


def mono_font(size: int) -> ImageFont.FreeTypeFont:
    for path in MONO_CANDIDATES:
        if path.exists():
            font = ImageFont.truetype(str(path), size=size)
            try:
                font.set_variation_by_name(b"Bold")
            except (OSError, ValueError):
                pass
            return font
    return ImageFont.load_default()


def frame(canvas: tuple[int, int], origin: tuple[int, int], cells: list[list[bool]],
          colour: tuple[int, int, int], speech: str | None = None) -> Image.Image:
    """A palette image: index 0 transparent, index 1 the ghost. Two colours, no dithering."""
    image = Image.new("P", canvas, 0)
    image.putpalette([0, 0, 0, *colour] + [0, 0, 0] * 254)
    draw = ImageDraw.Draw(image)
    ox, oy = origin
    for y, row in enumerate(cells):
        for x, on in enumerate(row):
            if on:
                draw.rectangle((ox + x * PIXEL, oy + y * PIXEL,
                                ox + (x + 1) * PIXEL - 1, oy + (y + 1) * PIXEL - 1), fill=1)
    if speech:
        # KiboView: bold mono at 2.2× the pixel size, to the left of the sprite, a little above
        # centre. Rendered through an alpha mask and thresholded, so it stays two-colour.
        font = mono_font(int(PIXEL * 2.2 * 1.6))
        mask = Image.new("L", canvas, 0)
        ImageDraw.Draw(mask).text((ox - PIXEL * 9 - 4, oy + int(16 * PIXEL * 0.26)), speech,
                                  font=font, fill=255, anchor="lm")
        image.paste(1, mask=mask.point(lambda v: 255 if v > 110 else 0))
    return image


def idle_frames(colour: tuple[int, int, int]) -> list[Image.Image]:
    """One full cycle: 16 s is the least common multiple of the 4 s blink and 3.2 s drift."""
    open_, shut = grid("open"), grid("shut")
    canvas = (16 * PIXEL, 17 * PIXEL)           # one extra row for the drift
    frames = []
    for tick in range(int(16_000 / TICK_MS)):
        t = tick * TICK_MS / 1000
        eyes = shut if (t % 4.0) < 0.4 else open_
        lift = 0 if (t % 3.2) < 1.6 else -PIXEL
        frames.append(frame(canvas, (0, PIXEL + lift), eyes, colour))
    return frames


def boo_frames(colour: tuple[int, int, int]) -> list[Image.Image]:
    """Idle for a beat, then the pleased look with "boo~" for ~1.2 s, as after a copy."""
    open_, shut = grid("open"), grid("shut")
    canvas = (16 * PIXEL + PIXEL * 11, 17 * PIXEL)
    origin = (PIXEL * 11, PIXEL)
    frames = [frame(canvas, origin, open_, colour)] * 5
    frames += [frame(canvas, origin, shut, colour, speech="boo~")] * 3
    frames += [frame(canvas, origin, shut, colour)] * 2
    return frames


def save(name: str, frames: list[Image.Image]) -> None:
    out = DOCS / name
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=TICK_MS, loop=0,
                   transparency=0, disposal=2, optimize=False)
    print(f"wrote {out.relative_to(ROOT)}  {frames[0].size[0]}x{frames[0].size[1]}  "
          f"{len(frames)} frames  {out.stat().st_size // 1024} KB")


def main() -> None:
    DOCS.mkdir(exist_ok=True)
    for variant, colour in COLOURS.items():
        save(f"kibo-idle-{variant}.gif", idle_frames(colour))
        save(f"kibo-boo-{variant}.gif", boo_frames(colour))


if __name__ == "__main__":
    main()
