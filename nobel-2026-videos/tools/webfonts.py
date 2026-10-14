"""Inline the LXGW WenKai glyphs a film uses into its web page (Google Fonts has
no simplified-Chinese WenKai, and the artifact page may only load fonts from
Google or from data: URIs).

usage: python3 tools/webfonts.py <page.html> <source files...>
Replaces everything between /* kai:start */ and /* kai:end */ in the page.
"""
import base64, io, logging, os, re, sys
from fontTools import subset
from fontTools.ttLib import TTFont

logging.getLogger("fontTools").setLevel(logging.ERROR)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = f"{ROOT}/engine/fonts/lxgw-wenkai-webfont"


def ranges(s):
    out = []
    for part in s.split(","):
        a, _, b = part.strip()[2:].partition("-")
        out.append((int(a, 16), int(b or a, 16)))
    return out


def main():
    page, sources = sys.argv[1], sys.argv[2:]
    used = {ord(ch) for f in sources for ch in open(f, encoding="utf-8").read() if ord(ch) > 0x2000}
    rules = []
    total = 0
    for css, weight in (("lxgwwenkai-regular.css", 400), ("lxgwwenkai-bold.css", 700)):
        for m in re.finditer(r"url\('\./(files/[^']+)'\).*?unicode-range:\s*([^\n}]+)", open(f"{WEB}/{css}").read(), re.S):
            cps = sorted(c for c in used if any(a <= c <= b for a, b in ranges(m.group(2))))
            if not cps:
                continue
            font = TTFont(f"{WEB}/{m.group(1)}")
            opts = subset.Options(); opts.flavor = "woff2"; opts.layout_features = ["*"]
            sub = subset.Subsetter(opts); sub.populate(unicodes=cps); sub.subset(font)
            buf = io.BytesIO(); font.flavor = "woff2"; font.save(buf)
            data = base64.b64encode(buf.getvalue()).decode()
            total += len(data)
            ur = ",".join(f"U+{c:x}" for c in cps)
            rules.append(f"@font-face{{font-family:'LXGW WenKai';font-weight:{weight};font-display:block;"
                         f"src:url(data:font/woff2;base64,{data}) format('woff2');unicode-range:{ur}}}")
    html = open(page, encoding="utf-8").read()
    html = re.sub(r"/\* kai:start \*/.*?/\* kai:end \*/", lambda _: "/* kai:start */\n" + "\n".join(rules) + "\n/* kai:end */", html, flags=re.S)
    open(page, "w", encoding="utf-8").write(html)
    print(f"{len(used)} glyphs, {len(rules)} faces, {total / 1024:.0f} KiB inlined")


if __name__ == "__main__":
    main()
