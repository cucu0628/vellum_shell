#!/usr/bin/env python3
"""Build the Vellum Shell website (gh-pages branch, served at vellum.asked.hu).

The page sources live in `src/` on this branch. Everything that describes the
shell itself is read from the main branch at build time, so the site cannot
drift from the code:

- the theme switcher gets the real `themes/*/theme.conf` palettes (themes.js),
- screensaver previews and the logo are copied from `assets/`.

The guide pages are Markdown in `src/guide/`; the screenshots and videos in
`src/media/` were recorded from a real shell in a sandboxed compositor.

Usage:

    python3 -m pip install --user markdown   # the only dependency
    ./build.py                               # fetch origin/main, write docs/
    python3 -m http.server -d docs           # preview on http://localhost:8000

GitHub Pages serves the `docs/` folder of this branch.
"""

from __future__ import annotations

import argparse
import hashlib
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
MAIN_PATHS = ["themes", "assets"]

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
NOT_PUBLISHED = {"guide", "guide.template.html", "partials"}


def git(*args: str) -> bytes:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, check=True).stdout


def checkout_main(ref: str, fetch: bool, into: Path) -> str:
    """Extract the themes and assets of `ref` into `into`; return the commit sha."""
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


def file_hash(path: Path) -> str:
    """Short content hash for cache-busting URLs."""
    return hashlib.sha256(path.read_bytes()).hexdigest()[:10]


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


def parse_page(path: Path) -> tuple[dict[str, str], str]:
    """Split a guide page into its `key: value` front matter and Markdown body."""
    text = path.read_text(encoding="utf-8")
    meta: dict[str, str] = {}
    if text.startswith("---\n"):
        head, _, text = text[4:].partition("\n---\n")
        for line in head.splitlines():
            key, sep, value = line.partition(":")
            if sep:
                meta[key.strip()] = value.strip()
    for key in ("title", "description", "group", "order"):
        if key not in meta:
            sys.exit(f"{path.name}: front matter needs '{key}'")
    meta["slug"] = path.stem
    return meta, text


def toc_html(tokens: list[dict]) -> str:
    items = []
    for token in tokens:
        children = "".join(
            f'<li><a href="#{child["id"]}">{child["name"]}</a></li>'
            for child in token.get("children", [])
        )
        sub = f'<ol class="toc-sub">{children}</ol>' if children else ""
        items.append(f'<li><a href="#{token["id"]}">{token["name"]}</a>{sub}</li>')
    return f'<ol class="toc-list">{"".join(items)}</ol>' if items else ""


def page_url(slug: str) -> str:
    return "/guide/" if slug == "index" else f"/guide/{slug}.html"


def render_guide(out: Path, partials: dict[str, str], values: dict[str, str]) -> int:
    try:
        import markdown
    except ImportError:
        sys.exit("build.py needs Python-Markdown: python3 -m pip install --user markdown")

    pages = [parse_page(p) for p in sorted((SRC / "guide").glob("*.md"))]
    pages.sort(key=lambda page: float(page[0]["order"]))
    template = (SRC / "guide.template.html").read_text(encoding="utf-8")

    groups: dict[str, list[dict]] = {}
    for meta, _ in pages:
        groups.setdefault(meta["group"], []).append(meta)

    def nav(current: str) -> str:
        blocks = []
        for group, metas in groups.items():
            links = "".join(
                f'<li><a href="{page_url(m["slug"])}"'
                + (' aria-current="page" class="on"' if m["slug"] == current else "")
                + f'>{html.escape(m.get("nav", m["title"]))}</a></li>'
                for m in metas
            )
            blocks.append(f'<p class="guide-nav-group">{html.escape(group)}</p><ul>{links}</ul>')
        return "".join(blocks)

    (out / "guide").mkdir(exist_ok=True)
    for index, (meta, body) in enumerate(pages):
        md = markdown.Markdown(
            extensions=["tables", "fenced_code", "toc", "sane_lists", "attr_list", "md_in_html", "admonition"],
            extension_configs={"toc": {"toc_depth": "2-3", "permalink": "#", "permalink_class": "anchor",
                                       "permalink_title": "Link to this section"}},
        )
        content = md.convert(body)
        content = content.replace("<table>", '<div class="table-wrap"><table>').replace("</table>", "</table></div>")
        content = content.replace("<img ", '<img loading="lazy" decoding="async" ')
        prev_link = next_link = ""
        if index > 0:
            p = pages[index - 1][0]
            prev_link = f'<a class="pager-prev" href="{page_url(p["slug"])}"><small>Previous</small><span>{html.escape(p["title"])}</span></a>'
        if index + 1 < len(pages):
            n = pages[index + 1][0]
            next_link = f'<a class="pager-next" href="{page_url(n["slug"])}"><small>Next</small><span>{html.escape(n["title"])}</span></a>'
        page = template
        for key, value in {
            "content": content, "toc": toc_html(md.toc_tokens), "nav": nav(meta["slug"]),
            "pager": prev_link + next_link,
        }.items():
            page = page.replace(f"<!-- @{key} -->", value)
        page_values = dict(values)
        page_values.update({
            "PAGE_TITLE": html.escape(meta["title"]),
            "PAGE_DESCRIPTION": html.escape(meta["description"]),
            "PAGE_GROUP": html.escape(meta["group"]),
            "PAGE_URL": page_url(meta["slug"]),
            "PAGE_SOURCE": f"{REPO_URL}/blob/gh-pages/src/guide/{meta['slug']}.md",
        })
        target = out / "guide" / ("index.html" if meta["slug"] == "index" else f"{meta['slug']}.html")
        target.write_text(fill(page, partials, page_values), encoding="utf-8")
    return len(pages)


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

        if out.exists():
            shutil.rmtree(out)
        out.mkdir(parents=True)
        shutil.copytree(main / "assets", out / "assets")

    # Content hashes for every image and video. Pages lets browsers keep files for
    # ten minutes under the same URL, so a re-recorded video would otherwise show
    # the old take; with the hash in the URL every change is a new address.
    media_versions = {}
    for base, prefix in ((SRC / "media", "/media/"), (out / "assets", "/assets/")):
        for path in sorted(base.rglob("*")):
            if path.is_file():
                media_versions[prefix + path.relative_to(base).as_posix()] = file_hash(path)

    default = DEFAULT_THEME if any(t["id"] == DEFAULT_THEME for t in themes) else themes[0]["id"]
    payload = json.dumps({"defaultTheme": default, "themes": themes}, indent=1)
    (out / "themes.js").write_text(
        f"// Generated by build.py from themes/*/theme.conf at {sha[:7]}.\n"
        f"window.VELLUM_THEMES = {payload};\n"
        f"window.VELLUM_MEDIA = {json.dumps(media_versions, indent=1, sort_keys=True)};\n",
        encoding="utf-8",
    )

    partials = {p.stem: p.read_text(encoding="utf-8").strip() for p in sorted((SRC / "partials").glob("*.html"))}
    version = file_hash

    values = {
        "V_STYLE": version(SRC / "style.css"),
        "V_THEME": version(SRC / "theme.js"),
        "V_SITE": version(SRC / "site.js"),
        "V_THEMES": version(out / "themes.js"),
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

    page_count = render_guide(out, partials, values)
    # The first version of the site had a single docs.html; keep old links working.
    (out / "docs.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>Vellum Shell guide</title>'
        '<meta http-equiv="refresh" content="0; url=/guide/"><link rel="canonical" href="/guide/">'
        '<a href="/guide/">Vellum Shell guide</a>\n',
        encoding="utf-8",
    )

    versioned = 0
    for page in out.rglob("*.html"):
        text = page.read_text(encoding="utf-8")

        def stamp(match: re.Match) -> str:
            url = match.group(2)
            digest = media_versions.get(url)
            return f'{match.group(1)}="{url}?v={digest}"' if digest else match.group(0)

        text, count = re.subn(r'\b(src|href|poster|data-src)="(/(?:media|assets)/[^"?#]+)"', stamp, text)
        versioned += count
        page.write_text(text, encoding="utf-8")

    # Pages keeps the custom domain in CNAME on branch deployments; no Jekyll pass.
    (out / "CNAME").write_text(DOMAIN + "\n", encoding="utf-8")
    (out / ".nojekyll").write_text("", encoding="utf-8")

    print(f"built {out.relative_to(ROOT)}/ from {ref} {sha[:7]} ({len(themes)} themes, {page_count} guide pages, {versioned} media links versioned)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the Vellum Shell website into docs/.")
    parser.add_argument("--ref", default="origin/main", help="branch or commit to read the shell from (default: origin/main)")
    parser.add_argument("--no-fetch", action="store_true", help="use the local copy of --ref without fetching it")
    parser.add_argument("--out", type=Path, default=ROOT / "docs", help="output directory inside this branch (default: docs)")
    args = parser.parse_args()
    build(args.out, args.ref, not args.no_fetch)


if __name__ == "__main__":
    main()
