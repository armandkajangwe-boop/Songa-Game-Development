#!/usr/bin/env python3
"""Build one offline, dependency-free browser file, without network requests."""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def data_url(path: Path, mime: str) -> str:
    return "data:" + mime + ";base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def build() -> None:
    assets = {
        name: data_url(ROOT / "web" / "assets" / (name + ".png"), "image/png")
        for name in ("backdrop", "hero_run", "hero_air", "hero_slide", "adult_run")
    }
    style = (ROOT / "web/style.css").read_text()
    style = style.replace("__FONT_BODY__", data_url(ROOT / "assets/fonts/OpenSans-Regular.ttf", "font/ttf"))
    style = style.replace("__FONT_BOLD__", data_url(ROOT / "assets/fonts/OpenSans-ExtraBold.ttf", "font/ttf"))
    replacements = {
        "__STYLE__": style,
        "__ASSETS_JSON__": json.dumps(assets),
        "__RUNNER_MODEL__": (ROOT / "web/runner-model.js").read_text(),
        "__PLAYER_JS__": (ROOT / "web/player.js").read_text(),
    }
    html = (ROOT / "web/template.html").read_text()
    for marker, content in replacements.items():
        assert html.count(marker) == 1, marker
        html = html.replace(marker, content)
    assert "__ASSETS_JSON__" not in html
    outputs = [ROOT / "index.html", ROOT / "artifacts/Songa-Play.html"]
    for output in outputs:
        output.parent.mkdir(exist_ok=True, parents=True)
        output.write_text(html)
    print(f"Built offline browser game: {len(html.encode()):,} bytes, {len(assets)} embedded images.")


if __name__ == "__main__":
    build()
