#!/usr/bin/env python3
"""Render converter mockups for the README at 2×, light and dark.

    python3 Tools/make-mockups.py            # → docs/mockup-converter-{light,dark}.png

**These are mockups, not screen captures.** They are an HTML composition of the app's own
palette (`Theme.swift`, copied by `make-banner.py`), its type and its sprite, rendered by headless
Chrome. They exist because the real alternatives both fail: `--snapshot` draws the text view as a
yellow placeholder block, and a screen capture needs a permission a terminal rarely has. Replace
them with real captures when a human is at the keyboard, and say "mockup" in any caption until
then.

Requires Google Chrome and Noto Sans Thai (installed locally, or the Thai falls back to
Thonburi, which is what the app would do too).
"""

from __future__ import annotations

import importlib.util
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
WIDTH, HEIGHT = 360, 440          # CSS px; rendered at 2× → 720×880


def banner_module():
    spec = importlib.util.spec_from_file_location("make_banner", ROOT / "Tools" / "make-banner.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sprite_rects(eyes: str = "open") -> str:
    text = (ROOT / "Sources" / "Kibo" / "KiboSprite.swift").read_text()

    def rows(pattern: str) -> list[str]:
        return re.findall(r'"([.Y]+)"', re.search(pattern, text, re.S).group(1))

    grid = (rows(r"private static let dome\s*=\s*\[(.*?)\]")
            + rows(r"case \." + eyes + r":\s*return \[(.*?)\]")
            + rows(r"private static let hem\s*=\s*\[(.*?)\]"))
    out = []
    for y, row in enumerate(grid):
        x = 0
        while x < 16:
            if row[x] == "Y":
                start = x
                while x < 16 and row[x] == "Y":
                    x += 1
                out.append(f'<rect x="{start}" y="{y}" width="{x - start}" height="1"/>')
            else:
                x += 1
    return "".join(out)


def html(palette: dict[str, str], mode_badge: str, input_text: str, result_text: str) -> str:
    p = palette
    on_accent = p["panel"]
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
* {{ box-sizing:border-box; margin:0; }}
html,body {{ width:{WIDTH}px; height:{HEIGHT}px; background:{p['panel']}; color:{p['text']};
  font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",sans-serif; font-size:13px;
  -webkit-font-smoothing:antialiased; overflow:hidden; }}
.wrap {{ padding:14px 14px 12px; }}
.bar {{ display:flex; justify-content:space-between; align-items:center; height:26px; margin-bottom:12px; }}
.bar b {{ font-size:20px; font-weight:600; letter-spacing:-.01em; }}
.bar svg {{ width:16px; height:16px; color:{p['dim']}; }}
.seg {{ display:grid; grid-template-columns:repeat(4,1fr); gap:2px; padding:3px; border-radius:10px; background:{p['fieldFill']}; margin-bottom:16px; }}
.seg span {{ text-align:center; padding:7px 0; border-radius:8px; font-size:13px; font-weight:500; }}
.seg .on {{ background:{p['accent']}; color:{on_accent}; font-weight:600; }}
.row {{ display:flex; justify-content:space-between; align-items:flex-end; height:24px; margin-bottom:4px; }}
.label {{ font-size:12px; font-weight:600; letter-spacing:.08em; text-transform:uppercase; color:{p['dim']}; }}
/* 32 px tall, 4 px of it (two sprite rows — KiboView.tailTuck) behind the field below. */
.ghost {{ position:relative; right:12px; top:8px; width:32px; height:32px; color:{p["kibo"]}; }}
.ghost svg {{ width:32px; height:32px; shape-rendering:crispEdges; display:block; }}
.field {{ background:{p['fieldFill']}; border:1px solid {p['panelEdge']}; border-radius:12px; padding:12px 14px; height:92px;
  font-family:"Noto Sans Thai",-apple-system,Thonburi,sans-serif; font-size:15px; line-height:1.7; margin-bottom:12px; position:relative; }}
.badge {{ display:inline-flex; align-items:center; gap:5px; font-size:12px; font-weight:600; padding:4px 10px; border-radius:999px; background:{p['fieldFill']}; color:{p['dim']}; }}
.badge.green {{ background:{p['green']}1F; color:{p['green']}; }}
.badge svg {{ width:11px; height:11px; }}
.actions {{ display:flex; gap:8px; margin-top:2px; }}
.btn {{ display:inline-flex; align-items:center; gap:6px; font-size:15px; font-weight:600; padding:9px 14px; border-radius:10px; background:{p['fieldFill']}; color:{p['text']}; }}
.btn svg {{ width:15px; height:15px; }}
.btn.primary {{ background:{p['accent']}; color:{on_accent}; }}
.sp {{ flex:1; }}
.foot {{ margin-top:14px; }}
</style></head><body><div class="wrap">
<div class="bar"><b>Kibo</b><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M5.5 2.5h5M6.5 2.5v4.2L3.8 9.6h8.4L9.5 6.7V2.5M8 9.6v4.4"/></svg></div>
<div class="seg"><span class="on">Both</span><span>EN → TH</span><span>TH → EN</span><span>Mixed</span></div>
<div class="row"><span class="label">Input</span><span class="ghost"><svg viewBox="0 0 16 16" fill="currentColor">{sprite_rects("open")}</svg></span></div>
<div class="field">{input_text}</div>
<div class="row"><span class="label">Result</span><span class="badge">{mode_badge}</span></div>
<div class="field" lang="th">{result_text}</div>
<div class="actions">
  <span class="btn"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="3" width="10" height="11" rx="2"/><rect x="5.5" y="1.5" width="5" height="3" rx="1"/></svg>Paste</span>
  <span class="btn"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><circle cx="8" cy="8" r="6.25"/><path d="m5.8 5.8 4.4 4.4M10.2 5.8l-4.4 4.4"/></svg>Clear</span>
  <span class="sp"></span>
  <span class="btn primary"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="5" width="9" height="9" rx="2"/><path d="M3 11V4a1 1 0 0 1 1-1h7"/></svg>Copy</span>
</div>
<div class="foot"><span class="badge green"><svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.5 13 3.5v4c0 3-2.2 5.4-5 6.5-2.8-1.1-5-3.5-5-6.5v-4z"/></svg>Local-only · No network</span></div>
</div></body></html>"""


def render(page: str, out: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "mock.html"
        src.write_text(page)
        subprocess.run([str(CHROME), "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=2", f"--window-size={WIDTH},{HEIGHT}",
                        f"--screenshot={out}", src.as_uri()],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"wrote {out.relative_to(ROOT)}")


def main() -> None:
    if not CHROME.exists():
        sys.exit("Google Chrome not found; mockups need its headless renderer")
    palettes = banner_module().PALETTES
    DOCS.mkdir(exist_ok=True)
    for appearance, palette in palettes.items():
        render(html(palette, "everything, both directions",
                    "l;ylfu ้ำสสน ครับ 2024 :)", "สวัสดี hello ครับ 2024 :)"),
               DOCS / f"mockup-converter-{appearance}.png")


if __name__ == "__main__":
    main()
