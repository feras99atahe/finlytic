#!/usr/bin/env python3
"""Generate Finlytic raster icons from the MatWallet glyph (marks.jsx).

Pure-Pillow renderer (no SVG toolchain needed). Shapes are drawn supersampled
then downscaled with LANCZOS for clean anti-aliased edges.

MatWallet (viewBox 0..100):
  body : rounded rect x16 y28 w68 h48 rx9            -> `body` colour
  flap : pocket on the right, straight edge at x84,
         left edge a semicircle (centre 68? -> r8 at x62..54) -> `clasp` colour @ .92
  clasp: circle cx68 cy52 r4.5                         -> `body` colour
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

TERRA = (217, 119, 87)
CREAM = (250, 249, 245)
INK = (20, 20, 19)

SS = 4  # supersample factor


def _draw_wallet(draw, u, ox, oy, body, clasp, base_img, clasp_alpha=235):
    """Draw MatWallet into `draw`. u = px per viewBox unit; (ox,oy) origin px."""
    def P(x, y):
        return (ox + x * u, oy + y * u)

    # body: rounded rect (16,28)-(84,76) r9
    draw.rounded_rectangle([P(16, 28), P(84, 76)], radius=9 * u, fill=body)

    # flap on its own layer for the 0.92 opacity over the body
    flap = Image.new("RGBA", base_img.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(flap)
    cf = (clasp[0], clasp[1], clasp[2], clasp_alpha)
    # right rectangle part: x62..84, y44..60
    fd.rectangle([P(62, 44), P(84, 60)], fill=cf)
    # left semicircle: ellipse centred (62,52) r8 -> bbox (54,44)-(70,60), left half
    fd.pieslice([P(54, 44), P(70, 60)], start=90, end=270, fill=cf)
    base_img.alpha_composite(flap)

    # clasp button: circle centre (68,52) r4.5, in body colour, on top
    d2 = ImageDraw.Draw(base_img)
    d2.ellipse([P(68 - 4.5, 52 - 4.5), P(68 + 4.5, 52 + 4.5)], fill=body + (255,))


def render(size, *, bg, body, clasp, glyph):
    """Full square icon: optional bg fill + centred MatWallet at `glyph` scale."""
    s = size * SS
    img = Image.new("RGBA", (s, s), bg + (255,) if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = (glyph * s) / 100.0          # scale of the 100-unit viewBox
    off = (s - glyph * s) / 2.0      # centre the scaled viewBox
    _draw_wallet(d, u, off, off, body, clasp, img)
    return img.resize((size, size), Image.LANCZOS)


def render_cropped(width, height, *, body, clasp, pad=8):
    """Tight glyph for the widget: content bounds x16..84 y28..76 + padding."""
    cx0, cy0, cx1, cy1 = 16 - pad, 28 - pad, 84 + pad, 76 + pad
    vw, vh = cx1 - cx0, cy1 - cy0
    w, h = width * SS, height * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = min(w / vw, h / vh)
    ox = (w - vw * u) / 2 - cx0 * u
    oy = (h - vh * u) / 2 - cy0 * u
    _draw_wallet(d, u, ox, oy, body, clasp, img)
    return img.resize((width, height), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


# 1) Launcher master (opaque ink tile, terra body, cream flap) for iOS + legacy.
save(render(1024, bg=INK, body=TERRA, clasp=CREAM, glyph=0.66),
     os.path.join(ROOT, "assets/icon/finlytic_icon.png"))

# 2) Adaptive foreground (transparent, more padding for the safe zone).
save(render(1024, bg=None, body=TERRA, clasp=CREAM, glyph=0.56),
     os.path.join(ROOT, "assets/icon/finlytic_foreground.png"))

# 3) Widget logo: terra body + ink flap reads well on the white widget card.
for dens, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3)]:
    w, h = round(40 * scale), round(30 * scale)
    save(render_cropped(w, h, body=TERRA, clasp=INK),
         os.path.join(ROOT, f"android/app/src/main/res/drawable-{dens}/widget_logo.png"))

print("done")
