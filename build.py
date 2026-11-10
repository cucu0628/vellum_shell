#!/usr/bin/env python3
"""Build the Vellum Shell website (gh-pages branch, served at vellum.asked.hu).

The page sources live in `src/` on this branch. Everything that describes the
shell itself is read from the main branch at build time, so the site cannot
drift from the code:

- the theme switcher gets the real `themes/*/theme.conf` palettes (themes.js),
- the documentation is rendered from `README.md` (docs.html),
- screenshots and screensaver previews are copied from `assets/`.

Usage:

    python3 -m pip install --user markdown   # the only dependency
    ./build.py                               # fetch origin/main, write docs/
    python3 -m http.server -d docs           # preview on http://localhost:8000

GitHub Pages serves the `docs/` folder of this branch.
"""

from __future__ import annotations

import argparse
import html
import io
import json
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
REPO_URL = "https://github.com/cucu0628/vellum_shell"
DOMAIN = "vellum.asked.hu"
DEFAULT_THEME = "japanese-ink"
MAIN_PATHS = ["README.md", "themes", "assets"]

# theme.conf key -> colour name used by theme.js (which turns it into a CSS variable).
THEME_KEYS = {
    "BACKGROUND": "bg",
    "DARK_BACKGROUND": "bgDark",
    "DARKER_BACKGROUND": "bgDarker",
    "LIGHTER_BACKGROUND": "bgLight",
    "SURFACE": "surface",
    "SELECTION": "selection",
    "FOREGROUND": "fg",
    "BRIGHT_FOREGROUND": "fgBright",
    "LIGHT_FOREGROUND": "fgLight",
    "DARK_FOREGROUND": "fgDim",
    "MUTED": "muted",
    "ACCENT": "accent",
    "RED": "red",
    "YELLOW": "yellow",
    "ORANGE": "orange",
    "GREEN": "green",
    "CYAN": "cyan",
    "BLUE": "blue",
    "MAGENTA": "magenta",
}
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")

# Templates and build inputs; everything else in src/ is published as is.
NOT_PUBLISHED = {"docs.template.html", "partials"}


def git(*args: str) -> bytes:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, check=True).stdout


def checkout_main(ref: str, fetch: bool, into: Path) -> str:
    """Extract README, themes and assets of `ref` into `into`; return the commit sha."""
    if fetch:
        remote, _, branch = ref.partition("/")
        if branch:
            print(f"fetching {remote} {branch}")
            git("fetch", "--quiet", remote, branch)
    try:
        sha = git("rev-parse", "--verify", f"{ref}^{{commit}}").decode().strip()
        archive = git("archive", "--format=tar", sha, *MAIN_PATHS)
    except subprocess.CalledProcessError as err:
        sys.exit(f"cannot read {ref}: {err.stderr.decode().strip()}")
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(into, filter="data")
    return sha


def parse_conf(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def load_themes(main: Path) -> list[dict]:
    themes = []
    for conf in sorted((main / "themes").glob("*/theme.conf")):
        values = parse_conf(conf)
        slug = conf.parent.name
        colors = {
            name: values[key].lower()
            for key, name in THEME_KEYS.items()
            if HEX.match(values.get(key, ""))
        }
        missing = [k for k in ("bg", "fg", "accent") if k not in colors]
        if missing:
            print(f"skipping {slug}: no {', '.join(missing)}", file=sys.stderr)
            continue
        # Fill missing shades from their nearest relative, in dependency order.
        for name, fallback in (
            ("surface", "bg"), ("bgDark", "bg"), ("bgDarker", "bgDark"), ("bgLight", "surface"),
            ("selection", "surface"), ("fgBright", "fg"), ("fgLight", "fg"), ("muted", "fg"),
            ("fgDim", "muted"),
        ):
            colors.setdefault(name, colors[fallback])
        for name in ("red", "yellow", "orange", "green", "cyan", "blue", "magenta"):
            colors.setdefault(name, colors["accent"])
        themes.append({
            "id": slug,
            "name": values.get("NAME", slug.replace("-", " ").title()),
            "dynamic": slug.startswith("dynamic"),
            "colors": colors,
        })
    # The dynamic theme is not a fixed palette but derived from the wallpaper: list it last.
    themes.sort(key=lambda t: t["dynamic"])
    return themes


def readme_markdown(main: Path) -> str:
    text = (main / "README.md").read_text(encoding="utf-8")
    # Title and preview are on the front page; the docs open with the introduction.
    text = re.sub(r"\A# [^\n]*\n", "", text)
    text = re.sub(r"^## Preview\n.*?(?=^## )", "", text, flags=re.S | re.M)
    return text


def rewrite_links(body: str) -> str:
    def href(match: re.Match) -> str:
        target = match.group(1)
        if re.match(r"^(https?:|mailto:|#|assets/)", target):
            return match.group(0)
        return f'href="{REPO_URL}/blob/main/{target}"'

    body = re.sub(r'href="([^"]+)"', href, body)
    body = body.replace("<img ", '<img loading="lazy" decoding="async" ')
    body = body.replace("<table>", '<div class="table-wrap"><table>')
    return body.replace("</table>", "</table></div>")


def toc_html(tokens: list[dict]) -> str:
    items = []
    for token in tokens:
        children = "".join(
            f'<li><a href="#{child["id"]}">{child["name"]}</a></li>'
            for child in token.get("children", [])
        )
        sub = f'<ol class="toc-sub">{children}</ol>' if children else ""
        items.append(f'<li><a href="#{token["id"]}">{token["name"]}</a>{sub}</li>')
    return f'<ol class="toc-list">{"".join(items)}</ol>'


def render_docs(main: Path) -> tuple[str, str]:
    try:
        import markdown
    except ImportError:
        sys.exit("build.py needs Python-Markdown: python3 -m pip install --user markdown")

    md = markdown.Markdown(
        extensions=["tables", "fenced_code", "toc", "sane_lists"],
        extension_configs={
            "toc": {
                "toc_depth": "2-3",
                "permalink": "#",
                "permalink_class": "anchor",
                "permalink_title": "Link to this section",
            }
        },
    )
    body = md.convert(readme_markdown(main))
    return rewrite_links(body), toc_html(md.toc_tokens)


def fill(template: str, partials: dict[str, str], values: dict[str, str]) -> str:
    for name, content in partials.items():
        template = template.replace(f"<!-- @{name} -->", content)
    for key, value in values.items():
        template = template.replace("{{" + key + "}}", value)
    leftover = re.findall(r"\{\{[A-Z_]+\}\}|<!-- @[a-z]+ -->", template)
    if leftover:
        sys.exit(f"unfilled placeholders: {', '.join(sorted(set(leftover)))}")
    return template


def build(out: Path, ref: str, fetch: bool) -> None:
    out = out.resolve()
    if out in (ROOT, SRC) or not out.is_relative_to(ROOT):
        sys.exit(f"refusing to write the site to {out}")

    with tempfile.TemporaryDirectory(prefix="vellum-site-") as tmp:
        main = Path(tmp)
        sha = checkout_main(ref, fetch, main)
        themes = load_themes(main)
        if not themes:
            sys.exit("no usable themes under themes/")
        body, toc = render_docs(main)

        if out.exists():
            shutil.rmtree(out)
        out.mkdir(parents=True)
        shutil.copytree(main / "assets", out / "assets")

    default = DEFAULT_THEME if any(t["id"] == DEFAULT_THEME for t in themes) else themes[0]["id"]
    payload = json.dumps({"defaultTheme": default, "themes": themes}, indent=1)
    (out / "themes.js").write_text(
        f"// Generated by build.py from themes/*/theme.conf at {sha[:7]}.\n"
        f"window.VELLUM_THEMES = {payload};\n",
        encoding="utf-8",
    )

    partials = {p.stem: p.read_text(encoding="utf-8").strip() for p in sorted((SRC / "partials").glob("*.html"))}
    values = {
        "REVISION": html.escape(sha[:7]),
        "REVISION_URL": f"{REPO_URL}/commit/{sha}",
        "REPO_URL": REPO_URL,
        "DOMAIN": DOMAIN,
        "THEME_COUNT": str(len(themes)),
    }

    for entry in sorted(SRC.iterdir()):
        if entry.name in NOT_PUBLISHED or entry.name.startswith("."):
            continue
        target = out / entry.name
        if entry.is_dir():
            shutil.copytree(entry, target)
        elif entry.suffix == ".html":
            target.write_text(fill(entry.read_text(encoding="utf-8"), partials, values), encoding="utf-8")
        else:
            shutil.copy2(entry, target)

    docs = (SRC / "docs.template.html").read_text(encoding="utf-8")
    docs = docs.replace("<!-- @content -->", body).replace("<!-- @toc -->", toc)
    (out / "docs.html").write_text(fill(docs, partials, values), encoding="utf-8")

    # Pages keeps the custom domain in CNAME on branch deployments; no Jekyll pass.
    (out / "CNAME").write_text(DOMAIN + "\n", encoding="utf-8")
    (out / ".nojekyll").write_text("", encoding="utf-8")

    print(f"built {out.relative_to(ROOT)}/ from {ref} {sha[:7]} ({len(themes)} themes)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the Vellum Shell website into docs/.")
    parser.add_argument("--ref", default="origin/main", help="branch or commit to read the shell from (default: origin/main)")
    parser.add_argument("--no-fetch", action="store_true", help="use the local copy of --ref without fetching it")
    parser.add_argument("--out", type=Path, default=ROOT / "docs", help="output directory inside this branch (default: docs)")
    args = parser.parse_args()
    build(args.out, args.ref, not args.no_fetch)


if __name__ == "__main__":
    main()
