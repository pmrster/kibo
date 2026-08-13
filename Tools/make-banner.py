#!/usr/bin/env python3
"""Render Kibo's light and dark README/social-preview banners.

Run with no arguments from anywhere:

    python3 Tools/make-banner.py

The source icon is deliberately not resized.  Its logical pixel grid is recovered
from the repeated run lengths along the sprite edges, sampled into a boolean grid,
and painted again as whole 10 px squares.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path
from statistics import median

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ICON = ROOT / "icon.png"
OUTPUTS = {
    "light": ROOT / "docs" / "banner-light.png",
    "dark": ROOT / "docs" / "banner-dark.png",
}

WIDTH = 1280
HEIGHT = 640
SPRITE_SCALE = 10

# Verbatim from Sources/Kibo/Theme.swift.
PALETTES = {
    "light": {
        "panel": "#F7F4EF",
        "panelEdge": "#E0DAD0",
        "text": "#1C1A17",
        "dim": "#6E655C",
        "accent": "#24262F",
        "green": "#0E8A6B",
        "kibo": "#1E202C",
        "fieldFill": "#EDE8E1",
    },
    "dark": {
        "panel": "#1C1A17",
        "panelEdge": "#2A2620",
        "text": "#EDE6DC",
        "dim": "#9A8F84",
        "accent": "#EDE9E1",
        "green": "#10A37F",
        "kibo": "#F2EEE6",
        "fieldFill": "#221F1B",
    },
}

FONT_ROOTS = (
    Path("/System/Library/Fonts"),
    Path("/Library/Fonts"),
    Path.home() / "Library/Fonts",
)
SYSTEM_FONT_CANDIDATES = (
    Path("/System/Library/Fonts/SFNS.ttf"),
    Path("/System/Library/Fonts/HelveticaNeue.ttc"),
    Path("/System/Library/Fonts/Helvetica.ttc"),
)
THAI_FALLBACK_CANDIDATES = (
    Path("/System/Library/Fonts/ThonburiUI.ttc"),
    Path("/System/Library/Fonts/Supplemental/Thonburi.ttc"),
)


def luma(pixel: tuple[int, int, int]) -> int:
    """A simple ordering metric; the icon's two clusters are very far apart."""

    red, green, blue = pixel
    return red + green + blue


def icon_mask(image: Image.Image) -> list[list[bool]]:
    """Separate the pale sprite from the midnight background without fixed colors."""

    rgb = image.convert("RGB")
    values = [luma(rgb.getpixel((x, y))) for y in range(rgb.height) for x in range(rgb.width)]
    cutoff = (min(values) + max(values)) // 2
    return [
        [luma(rgb.getpixel((x, y))) > cutoff for x in range(rgb.width)]
        for y in range(rgb.height)
    ]


def stable_run_lengths(values: list[int], tolerance: int = 2) -> list[int]:
    """Measure flat runs in a noisy edge trace.

    The 1254 px source contains slight tonal/edge noise, so positions within two
    pixels count as the same logical edge. Long body runs are retained here and
    filtered when the base block is selected.
    """

    start = 0
    low = high = values[0]
    runs: list[int] = []
    for index, value in enumerate(values[1:], start=1):
        next_low = min(low, value)
        next_high = max(high, value)
        if next_high - next_low <= tolerance:
            low, high = next_low, next_high
            continue
        runs.append(index - start)
        start = index
        low = high = value
    runs.append(len(values) - start)
    return runs


def detect_source_block(mask: list[list[bool]]) -> tuple[int, tuple[int, int, int, int]]:
    """Infer the source block size by scanning run lengths along both side edges."""

    left_edge: list[int] = []
    right_edge: list[int] = []
    on_x: list[int] = []
    on_y: list[int] = []

    for y, row in enumerate(mask):
        foreground = [x for x, enabled in enumerate(row) if enabled]
        if not foreground:
            continue
        left_edge.append(foreground[0])
        right_edge.append(foreground[-1] + 1)
        on_x.extend(foreground)
        on_y.extend([y] * len(foreground))

    if not left_edge:
        raise RuntimeError("No pale sprite could be separated from icon.png")

    runs = stable_run_lengths(left_edge) + stable_run_lengths(right_edge)
    # Logical steps occupy about 1–2% of this source's height. Filtering to this
    # band excludes the long straight body without assuming the answer is 18.
    source_height = len(mask)
    candidates = [
        run for run in runs
        if source_height * 0.009 <= run <= source_height * 0.020
    ]
    if not candidates:
        raise RuntimeError("Could not infer the icon sprite's logical block size")

    block = round(median(candidates))
    bbox = (min(on_x), min(on_y), max(on_x) + 1, max(on_y) + 1)
    return block, bbox


def enclosed_holes(grid: list[list[bool]]) -> list[list[tuple[int, int]]]:
    """Return background components enclosed by the sprite silhouette."""

    rows = len(grid)
    columns = len(grid[0])
    seen: set[tuple[int, int]] = set()
    holes: list[list[tuple[int, int]]] = []

    for row in range(rows):
        for column in range(columns):
            if grid[row][column] or (row, column) in seen:
                continue
            queue = deque([(row, column)])
            seen.add((row, column))
            component: list[tuple[int, int]] = []
            touches_border = False
            while queue:
                current_row, current_column = queue.popleft()
                component.append((current_row, current_column))
                touches_border |= (
                    current_row in (0, rows - 1)
                    or current_column in (0, columns - 1)
                )
                for row_step, column_step in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    next_row = current_row + row_step
                    next_column = current_column + column_step
                    next_cell = (next_row, next_column)
                    if not (0 <= next_row < rows and 0 <= next_column < columns):
                        continue
                    if grid[next_row][next_column] or next_cell in seen:
                        continue
                    seen.add(next_cell)
                    queue.append(next_cell)
            if not touches_border:
                holes.append(component)
    return holes


def extract_sprite_grid(source: Path) -> tuple[list[list[bool]], int]:
    """Recover a clean logical grid from the non-integrally-scaled source icon."""

    with Image.open(source) as image:
        mask = icon_mask(image)

    source_block, (left, top, right, bottom) = detect_source_block(mask)
    columns = round((right - left) / source_block)
    rows = round((bottom - top) / source_block)

    # Sample cell centers from a proportional grid. This compensates for the
    # source's 1254 px canvas not being an integer multiple of its logical grid.
    grid: list[list[bool]] = []
    for row in range(rows):
        sample_y = min(
            len(mask) - 1,
            round(top + (row + 0.5) * (bottom - top) / rows),
        )
        logical_row: list[bool] = []
        for column in range(columns):
            sample_x = min(
                len(mask[0]) - 1,
                round(left + (column + 0.5) * (right - left) / columns),
            )
            logical_row.append(mask[sample_y][sample_x])
        grid.append(logical_row)

    # Sampling artifacts in a non-integral resize can make one side lose a cell.
    # The mascot is bilaterally symmetric, so union each pair back onto the grid.
    for row in grid:
        for column in range(columns // 2):
            enabled = row[column] or row[columns - 1 - column]
            row[column] = row[columns - 1 - column] = enabled

    # The current source file has a tiny central mouth-like cutout. Product rules
    # specify two eye holes and no mouth, so keep the two largest enclosed holes.
    holes = sorted(enclosed_holes(grid), key=len, reverse=True)
    for component in holes[2:]:
        for row, column in component:
            grid[row][column] = True

    if (columns, rows) != (37, 39):
        raise RuntimeError(
            f"Unexpected logical sprite size {columns}x{rows}; expected 37x39"
        )
    return grid, source_block


def locate_noto_sans_thai() -> Path | None:
    """Find the real installed face in standard macOS font directories."""

    for root in FONT_ROOTS:
        if not root.exists():
            continue
        candidates = sorted(
            path for path in root.rglob("*")
            if path.is_file()
            and "notosansthai" in path.name.lower().replace("-", "").replace("_", "")
            and path.suffix.lower() in {".ttf", ".ttc", ".otf"}
        )
        if candidates:
            return candidates[0]
    return None


def locate_system_font() -> Path:
    for candidate in SYSTEM_FONT_CANDIDATES:
        if candidate.exists():
            return candidate
    raise RuntimeError("No macOS system UI font file could be resolved")


def locate_thai_fallback(system_path: Path) -> Path:
    for candidate in THAI_FALLBACK_CANDIDATES:
        if candidate.exists():
            return candidate
    return system_path


def load_font(path: Path, size: int, variation: str | None = None) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(path), size=size)
    if variation is not None:
        try:
            font.set_variation_by_name(variation.encode("ascii"))
        except (OSError, ValueError):
            pass
    return font


def font_set() -> tuple[dict[str, ImageFont.FreeTypeFont], Path, Path | None, Path]:
    system_path = locate_system_font()
    thai_path = locate_noto_sans_thai()
    actual_thai_path = thai_path or locate_thai_fallback(system_path)
    return (
        {
            "title": load_font(system_path, 88, "Semibold"),
            "subtitle": load_font(system_path, 29),
            "body": load_font(system_path, 27),
            "example_latin": load_font(system_path, 46, "Semibold"),
            "example_arrow": load_font(system_path, 38, "Semibold"),
            "thai_name": load_font(actual_thai_path, 31),
            "example_thai": load_font(actual_thai_path, 50, "Semibold" if thai_path else None),
        },
        system_path,
        thai_path,
        actual_thai_path,
    )


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> int:
    left, _top, right, _bottom = draw.textbbox((0, 0), text, font=font)
    return right - left


def draw_sprite(
    draw: ImageDraw.ImageDraw,
    grid: list[list[bool]],
    origin: tuple[int, int],
    color: str,
) -> None:
    origin_x, origin_y = origin
    for row, cells in enumerate(grid):
        for column, enabled in enumerate(cells):
            if not enabled:
                continue
            x = origin_x + column * SPRITE_SCALE
            y = origin_y + row * SPRITE_SCALE
            draw.rectangle(
                (x, y, x + SPRITE_SCALE - 1, y + SPRITE_SCALE - 1),
                fill=color,
            )


def validate_sprite_lattice(grid: list[list[bool]], origin: tuple[int, int]) -> None:
    """Verify every horizontal and vertical output run occupies whole sprite pixels."""

    rows = len(grid)
    columns = len(grid[0])
    origin_x, origin_y = origin
    for row in range(rows):
        transitions = [origin_x]
        previous = False
        for column in range(columns):
            current = grid[row][column]
            if current != previous:
                transitions.append(origin_x + column * SPRITE_SCALE)
            previous = current
        transitions.append(origin_x + columns * SPRITE_SCALE)
        if any((value - origin_x) % SPRITE_SCALE for value in transitions):
            raise RuntimeError("A horizontal sprite run left the integer-pixel lattice")

    for column in range(columns):
        transitions = [origin_y]
        previous = False
        for row in range(rows):
            current = grid[row][column]
            if current != previous:
                transitions.append(origin_y + row * SPRITE_SCALE)
            previous = current
        transitions.append(origin_y + rows * SPRITE_SCALE)
        if any((value - origin_y) % SPRITE_SCALE for value in transitions):
            raise RuntimeError("A vertical sprite run left the integer-pixel lattice")


def render_banner(
    appearance: str,
    grid: list[list[bool]],
    fonts: dict[str, ImageFont.FreeTypeFont],
) -> Image.Image:
    palette = PALETTES[appearance]
    image = Image.new("RGB", (WIDTH, HEIGHT), palette["panel"])
    draw = ImageDraw.Draw(image)

    # Restrained left-aligned typographic block.
    draw.text((86, 61), "Kibo", font=fonts["title"], fill=palette["text"])
    draw.text(
        (91, 165),
        "Who Forgot To Change Lang",
        font=fonts["subtitle"],
        fill=palette["text"],
    )
    draw.text(
        (90, 207),
        "ใครลืมเปลี่ยนภาษา",
        font=fonts["thai_name"],
        fill=palette["dim"],
    )
    draw.text(
        (90, 277),
        "Fixes text typed with the wrong keyboard layout.",
        font=fonts["body"],
        fill=palette["dim"],
    )

    # The transformation is the only explanatory device on the banner.
    field = (88, 366, 724, 500)
    draw.rounded_rectangle(
        field,
        radius=24,
        fill=palette["fieldFill"],
        outline=palette["panelEdge"],
        width=2,
    )
    parts = (
        ("l;ylfu", fonts["example_latin"], palette["text"]),
        ("→", fonts["example_arrow"], palette["dim"]),
        ("สวัสดี", fonts["example_thai"], palette["accent"]),
    )
    gaps = (45, 45)
    widths = [text_width(draw, text, font) for text, font, _color in parts]
    content_width = sum(widths) + sum(gaps)
    cursor = field[0] + (field[2] - field[0] - content_width) // 2
    baselines = (404, 408, 397)
    for index, ((text, font, color), width, y) in enumerate(zip(parts, widths, baselines)):
        draw.text((cursor, y), text, font=font, fill=color)
        cursor += width
        if index < len(gaps):
            cursor += gaps[index]

    # Kibo sits on a quiet rule rather than floating in the empty half.
    sprite_width = len(grid[0]) * SPRITE_SCALE
    sprite_height = len(grid) * SPRITE_SCALE
    sprite_origin = (828, 168)
    draw.line((790, 558, 1218, 558), fill=palette["panelEdge"], width=2)
    draw_sprite(draw, grid, sprite_origin, palette["kibo"])
    validate_sprite_lattice(grid, sprite_origin)

    expected_right = sprite_origin[0] + sprite_width
    expected_bottom = sprite_origin[1] + sprite_height
    if expected_right > WIDTH or expected_bottom != 558:
        raise RuntimeError("Sprite placement no longer fits the 1280x640 composition")
    return image


def main() -> None:
    grid, source_block = extract_sprite_grid(SOURCE_ICON)
    fonts, system_path, thai_path, actual_thai_path = font_set()

    for appearance, output in OUTPUTS.items():
        output.parent.mkdir(parents=True, exist_ok=True)
        image = render_banner(appearance, grid, fonts)
        if image.size != (WIDTH, HEIGHT):
            raise RuntimeError(f"Rendered {appearance} banner at {image.size}, not 1280x640")
        image.save(output, format="PNG", optimize=True)

    thai_resolution = str(thai_path) if thai_path else f"fallback to {actual_thai_path}"
    print(f"source logical block: {source_block}px")
    print(f"logical sprite: {len(grid[0])}x{len(grid)}")
    print(f"output sprite scale: {SPRITE_SCALE}x ({len(grid[0]) * SPRITE_SCALE}x{len(grid) * SPRITE_SCALE}px)")
    print(f"system UI font: {system_path} (Regular/Semibold variations)")
    print(f"Noto Sans Thai: {thai_resolution}")
    for output in OUTPUTS.values():
        print(f"wrote {output} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
