#!/usr/bin/env python3
"""Render a static preview image of the quick-add widget for the picker.

Some launchers (and Android < 12, which ignores previewLayout) need a
previewImage or they hide / show a blank entry for the widget. This draws a
representative card so the widget always previews nicely.
"""
import os
from PIL import Image, ImageDraw, ImageFont
from gen_icons import _draw_wallet, TERRA, CREAM, INK, SS  # reuse wallet renderer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GREEN = (120, 140, 93)
WHITE = (255, 255, 255)
LIGHT = (250, 249, 245)
MIDGRAY = (176, 174, 165)
BORDER = (232, 230, 220)


def font(size, bold=True):
    for p in [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def rrect(d, box, r, **kw):
    d.rounded_rectangle(box, radius=r, **kw)


W, H = 400, 176
img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
S = SS
pad = 14 * S

# card
rrect(d, [pad, pad, W * S - pad, H * S - pad], 20 * S, fill=WHITE, outline=BORDER, width=2 * S)

inner = pad + 14 * S
# wallet logo (terra body, ink flap) top-left
logo = Image.new("RGBA", (40 * S, 30 * S), (0, 0, 0, 0))
ld = ImageDraw.Draw(logo)
u = min(40 * S / 80, 30 * S / 70)
_draw_wallet(ld, u, (40 * S - 68 * u) / 2 - 16 * u + 8 * u, (30 * S - 48 * u) / 2 - 28 * u + 8 * u,
             TERRA, INK, logo)
img.alpha_composite(logo, (inner, inner))

d.text((inner + 48 * S, inner + 2 * S), "finlytic", font=font(16 * S), fill=INK)
bal = "$1,240.00"
bf = font(13 * S)
bw = d.textlength(bal, font=bf)
d.text((W * S - pad - 14 * S - bw, inner + 4 * S), bal, font=bf, fill=MIDGRAY)
d.text((inner + 48 * S, inner + 24 * S), "Quick add", font=font(11 * S, bold=False), fill=MIDGRAY)

# buttons
by0 = inner + 52 * S
by1 = H * S - pad - 14 * S
bw_total = W * S - 2 * inner
gap = 8 * S
bw_each = (bw_total - 2 * gap) / 3
labels = [("+ Income", GREEN), ("- Expense", TERRA), ("Transfer", INK)]
for i, (lbl, col) in enumerate(labels):
    x0 = inner + i * (bw_each + gap)
    rrect(d, [x0, by0, x0 + bw_each, by1], 12 * S, fill=col)
    lf = font(13 * S)
    lw = d.textlength(lbl, font=lf)
    bbox = d.textbbox((0, 0), lbl, font=lf)
    th = bbox[3] - bbox[1]
    d.text((x0 + (bw_each - lw) / 2, (by0 + by1) / 2 - th / 2 - bbox[1]), lbl, font=lf, fill=LIGHT)

out = os.path.join(ROOT, "android/app/src/main/res/drawable-nodpi/widget_preview.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
img.resize((W, H), Image.LANCZOS).save(out)
print("wrote", os.path.relpath(out, ROOT))
