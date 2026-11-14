"""Draws DustOrGold's project logo (a heap of shimmering dust beside a stack
of gold coins, split by a diagonal) to media/logo.png. Original artwork, no
game assets.

    python tools/make_logo.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling
W = 400 * S


def p(x, y):
    return (x * S, y * S)


img = Image.new("RGB", (W, W), (26, 22, 40))

# Two halves: violet on the left (dust), warm brown on the right (gold).
right = Image.new("L", (W, W), 0)
ImageDraw.Draw(right).polygon([p(250, 0), p(400, 0), p(400, 400), p(150, 400)], fill=255)
img.paste(Image.new("RGB", (W, W), (48, 34, 22)), (0, 0), right)

# Soft glows behind each pile.
for cx, cy, colour in ((120, 250, (110, 70, 170)), (290, 240, (170, 120, 40))):
    glow = Image.new("L", (W, W), 0)
    ImageDraw.Draw(glow).ellipse((p(cx - 110, cy - 110) + p(cx + 110, cy + 110)), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(50 * S))
    img.paste(Image.new("RGB", (W, W), colour), (0, 0), glow)

d = ImageDraw.Draw(img)

# The diagonal divider.
d.line([p(250, 0), p(150, 400)], fill=(230, 220, 250), width=3 * S)

# Dust heap: a mound of overlapping grains, light at the top.
random.seed(11)
for _ in range(2600):
    t = random.random()
    x = 40 + t * 165
    top = 330 - math.sin(t * math.pi) ** 1.4 * 125
    y = random.uniform(top, 332)
    shade = (y - top) / max(332 - top, 1)
    r = random.uniform(1.6, 3.4)
    colour = (
        int(200 - 90 * shade + random.uniform(-20, 20)),
        int(150 - 90 * shade + random.uniform(-15, 15)),
        int(255 - 60 * shade),
    )
    d.ellipse((p(x - r, y - r) + p(x + r, y + r)), fill=colour)

# Sparkles above the dust.
def sparkle(x, y, size, colour):
    d.polygon([p(x, y - size), p(x + size * 0.22, y), p(x, y + size), p(x - size * 0.22, y)], fill=colour)
    d.polygon([p(x - size, y), p(x, y + size * 0.22), p(x + size, y), p(x, y - size * 0.22)], fill=colour)

for x, y, size in ((90, 150, 16), (150, 120, 11), (60, 205, 9), (175, 175, 8), (118, 92, 7)):
    sparkle(x, y, size, (240, 230, 255))

# Gold coins: a stack, front coin on top, plus two loose coins.
def coin(cx, cy, rx=46, ry=15, thick=9):
    d.ellipse((p(cx - rx, cy - ry + thick) + p(cx + rx, cy + ry + thick)), fill=(150, 100, 20))
    d.rectangle((p(cx - rx, cy) + p(cx + rx, cy + thick)), fill=(150, 100, 20))
    d.ellipse((p(cx - rx, cy - ry) + p(cx + rx, cy + ry)), fill=(240, 190, 60))
    d.ellipse((p(cx - rx + 9, cy - ry + 4) + p(cx + rx - 9, cy + ry - 4)), outline=(200, 145, 35), width=3 * S)

for i in range(8):
    coin(285 + (i % 2) * 3, 318 - i * 18)
coin(345, 330, 30, 10, 7)
coin(235, 338, 28, 9, 6)

# A glint on the top coin.
sparkle(300, 178, 14, (255, 250, 220))

img = img.resize((400, 400), Image.LANCZOS)
out = os.path.join(os.path.dirname(__file__), "..", "media", "logo.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out)
print(os.path.abspath(out))
