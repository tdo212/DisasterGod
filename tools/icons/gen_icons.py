"""Sticker-style icon sheets for DisasterGod (matches the UIReference look):
glossy flat fills, a thick navy outline, a soft top highlight and little sparkles.
Draws at 512px per icon (supersampled), packs 16 icons per 1024x1024 sheet at 256px."""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.dirname(os.path.abspath(__file__))
S = 512  # working size
U = S / 100.0
OUTLINE = (24, 20, 46, 255)


def P(x, y):
    return (x * U, y * U)


def pts(seq):
    return [P(x, y) for x, y in seq]


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


class Pen:
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def circle(self, x, y, r, fill):
        self.d.ellipse((P(x - r, y - r), P(x + r, y + r)), fill=fill)

    def ellipse(self, x0, y0, x1, y1, fill):
        self.d.ellipse((P(x0, y0), P(x1, y1)), fill=fill)

    def poly(self, seq, fill):
        self.d.polygon(pts(seq), fill=fill)

    def rect(self, x0, y0, x1, y1, fill, r=0):
        if r:
            self.d.rounded_rectangle((P(x0, y0), P(x1, y1)), radius=r * U, fill=fill)
        else:
            self.d.rectangle((P(x0, y0), P(x1, y1)), fill=fill)

    def line(self, seq, fill, w):
        self.d.line(pts(seq), fill=fill, width=int(w * U), joint="curve")
        for x, y in (seq[0], seq[-1]):
            self.circle(x, y, w / 2, fill)

    def arc(self, x, y, r, a0, a1, fill, w):
        self.d.arc((P(x - r, y - r), P(x + r, y + r)), a0, a1, fill=fill, width=int(w * U))

    def star(self, x, y, r, fill, points=5, inner=0.45, rot=-90):
        seq = []
        for i in range(points * 2):
            rr = r if i % 2 == 0 else r * inner
            a = math.radians(rot + i * 180 / points)
            seq.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
        self.poly(seq, fill)


def bolt(p, x, y, s, fill, dark):
    seq = [(x + 6 * s, y - 30 * s), (x - 14 * s, y + 4 * s), (x - 1 * s, y + 4 * s), (x - 7 * s, y + 30 * s), (x + 15 * s, y - 6 * s), (x + 2 * s, y - 6 * s)]
    p.poly(seq, fill)
    p.poly([(x + 6 * s, y - 30 * s), (x - 14 * s, y + 4 * s), (x - 6 * s, y + 4 * s), (x + 2 * s, y - 14 * s)], shade(fill, 1.15))


def sparkle(p, x, y, r):
    p.star(x, y, r, (255, 255, 255, 255), points=4, inner=0.28, rot=0)


def finish(pen, sparkles=()):
    base = pen.img
    alpha = base.split()[3]
    # glossy highlight on the upper half, clipped to the shape
    grad = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(grad)
    for yy in range(S):
        t = yy / S
        gd.line([(0, yy), (S, yy)], fill=int(max(0, 70 * (1 - t / 0.55))) if t < 0.55 else 0)
    hl = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    hl.putalpha(ImageChops.multiply(grad, alpha))
    body = Image.alpha_composite(base, hl)
    # inner dark edge for depth
    inner = alpha.filter(ImageFilter.MinFilter(9))
    edge = ImageChops.subtract(alpha, inner)
    edge_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    edge_layer.putalpha(edge.point(lambda v: int(v * 0.25)))
    body = Image.alpha_composite(body, edge_layer)
    # thick navy outline behind
    outline = alpha.filter(ImageFilter.MaxFilter(27)).filter(ImageFilter.MaxFilter(13))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ol = Image.new("RGBA", (S, S), OUTLINE)
    ol.putalpha(outline)
    out = Image.alpha_composite(out, ol)
    out = Image.alpha_composite(out, body)
    if sparkles:
        sp = Pen()
        for (x, y, r) in sparkles:
            sparkle(sp, x, y, r)
        spa = sp.img.split()[3].filter(ImageFilter.MaxFilter(11))
        spo = Image.new("RGBA", (S, S), OUTLINE)
        spo.putalpha(spa)
        out = Image.alpha_composite(out, spo)
        out = Image.alpha_composite(out, sp.img)
    return out


# ---------------------------------------------------------------- icons
GOLD = (255, 200, 40, 255)
GOLD_D = (220, 140, 20, 255)
WHITE = (255, 255, 255, 255)
RED = (235, 60, 60, 255)
BLUE = (70, 160, 255, 255)
CYAN = (70, 220, 255, 255)
GREEN = (80, 215, 70, 255)
PURPLE = (150, 80, 255, 255)
PINK = (255, 90, 190, 255)
ORANGE = (255, 140, 30, 255)
GREY = (150, 160, 180, 255)
DARK = (50, 45, 75, 255)
BROWN = (150, 95, 55, 255)

ICONS = {}


def icon(name, sparkles=()):
    def deco(fn):
        ICONS[name] = (fn, sparkles)
        return fn
    return deco


@icon("Shop", [(80, 22, 7)])
def _(p):
    p.poly([(18, 36), (82, 36), (76, 88), (24, 88)], (255, 120, 60, 255))
    p.poly([(18, 36), (82, 36), (80, 48), (20, 48)], (255, 160, 90, 255))
    p.arc(50, 36, 17, 180, 360, (110, 60, 40, 255), 6)
    p.circle(50, 66, 13, GOLD)
    p.circle(50, 66, 8, GOLD_D)
    p.rect(47, 58, 53, 74, GOLD)


@icon("Spin", [(82, 20, 7)])
def _(p):
    cols = [RED, GOLD, GREEN, BLUE, PURPLE, ORANGE]
    for i, c in enumerate(cols):
        p.d.pieslice((P(14, 14), P(86, 86)), i * 60 - 90, (i + 1) * 60 - 90, fill=c)
    p.circle(50, 50, 10, WHITE)
    p.circle(50, 50, 5, DARK)
    p.poly([(43, 6), (57, 6), (50, 20)], RED)


@icon("Quests", [(80, 18, 6)])
def _(p):
    p.rect(22, 14, 78, 88, (245, 230, 190, 255), 6)
    p.rect(22, 14, 78, 24, (220, 190, 130, 255), 6)
    for i, y in enumerate((38, 56, 74)):
        p.line([(30, y), (36, y + 6), (46, y - 6)], GREEN if i < 2 else GREY, 5)
        p.rect(52, y - 3, 70, y + 3, (170, 150, 120, 255), 2)


@icon("Passes", [(84, 20, 7), (16, 78, 5)])
def _(p):
    p.poly([(12, 30), (88, 30), (88, 44), (82, 50), (88, 56), (88, 70), (12, 70), (12, 56), (18, 50), (12, 44)], GOLD)
    p.rect(12, 30, 88, 40, (255, 225, 110, 255))
    p.star(50, 52, 13, WHITE)


@icon("Spectate", [(82, 22, 6)])
def _(p):
    p.ellipse(10, 28, 90, 72, WHITE)
    p.circle(50, 50, 17, BLUE)
    p.circle(50, 50, 9, DARK)
    p.circle(55, 45, 4, WHITE)


@icon("PlayGod", [(84, 16, 7), (14, 30, 5)])
def _(p):
    p.poly([(16, 72), (14, 30), (32, 46), (50, 22), (68, 46), (86, 30), (84, 72)], GOLD)
    p.rect(16, 70, 84, 84, GOLD_D, 3)
    for x in (32, 50, 68):
        p.circle(x, 77, 4, RED)
    bolt(p, 50, 50, 0.5, (120, 220, 255, 255), DARK)


@icon("Settings", [(82, 18, 6)])
def _(p):
    for i in range(8):
        a = math.radians(i * 45)
        x, y = 50 + math.cos(a) * 31, 50 + math.sin(a) * 31
        p.d.regular_polygon((P(x, y), 9 * U), 4, rotation=-i * 45, fill=(90, 160, 230, 255))
    p.circle(50, 50, 30, (90, 160, 230, 255))
    p.circle(50, 50, 22, (120, 190, 250, 255))
    p.circle(50, 50, 11, (40, 80, 140, 255))


@icon("Coin", [(78, 22, 7)])
def _(p):
    p.circle(50, 52, 34, GOLD_D)
    p.circle(50, 48, 34, GOLD)
    p.circle(50, 48, 25, (255, 220, 80, 255))
    p.star(50, 48, 15, GOLD_D)


@icon("Emote", [(84, 16, 6)])
def _(p):
    p.circle(50, 50, 36, GOLD)
    p.circle(37, 42, 6, DARK)
    p.d.pieslice((P(56, 34), P(70, 48)), 0, 180, fill=DARK)
    p.d.chord((P(30, 52), P(70, 76)), 0, 180, fill=DARK)
    p.d.chord((P(40, 62), P(60, 78)), 180, 360, fill=RED)


@icon("Dash", [(84, 22, 6)])
def _(p):
    for i, (y, l) in enumerate(((32, 30), (50, 40), (68, 30))):
        p.line([(10, y), (10 + l, y)], (150, 220, 255, 255), 6)
    p.poly([(44, 22), (88, 50), (44, 78), (54, 50)], CYAN)
    p.poly([(44, 22), (88, 50), (60, 50), (54, 50)], (140, 240, 255, 255))


@icon("Close")
def _(p):
    p.line([(24, 24), (76, 76)], RED, 16)
    p.line([(76, 24), (24, 76)], RED, 16)


@icon("SpeedSoda", [(80, 20, 6)])
def _(p):
    p.poly([(26, 30), (74, 30), (68, 88), (32, 88)], (255, 90, 120, 255))
    p.rect(22, 24, 78, 34, WHITE, 4)
    p.line([(56, 26), (66, 6)], (80, 200, 255, 255), 5)
    bolt(p, 50, 60, 0.6, GOLD, DARK)


@icon("Glider", [(82, 18, 6)])
def _(p):
    p.ellipse(22, 8, 78, 70, (255, 80, 110, 255))
    p.ellipse(32, 16, 50, 36, (255, 160, 180, 255))
    p.poly([(46, 68), (54, 68), (50, 76)], (255, 80, 110, 255))
    p.line([(50, 76), (44, 92)], WHITE, 3)


@icon("Shield", [(80, 20, 6)])
def _(p):
    p.poly([(50, 10), (84, 22), (80, 58), (50, 90), (20, 58), (16, 22)], (60, 140, 250, 255))
    p.poly([(50, 18), (76, 28), (73, 56), (50, 80)], (120, 190, 255, 255))
    p.star(50, 50, 14, GOLD)


@icon("Trophy", [(82, 16, 7)])
def _(p):
    p.arc(26, 38, 12, 90, 270, GOLD_D, 6)
    p.arc(74, 38, 12, 270, 90, GOLD_D, 6)
    p.poly([(26, 18), (74, 18), (70, 46), (58, 60), (42, 60), (30, 46)], GOLD)
    p.rect(44, 58, 56, 72, GOLD_D)
    p.rect(30, 72, 70, 86, (150, 90, 40, 255), 3)
    p.star(50, 36, 9, WHITE)


@icon("Skull")
def _(p):
    p.ellipse(18, 12, 82, 70, (240, 240, 245, 255))
    p.rect(32, 58, 68, 84, (240, 240, 245, 255), 6)
    p.circle(37, 44, 9, DARK)
    p.circle(63, 44, 9, DARK)
    p.poly([(50, 54), (45, 63), (55, 63)], DARK)
    for x in (42, 50, 58):
        p.rect(x - 1.5, 72, x + 1.5, 84, DARK)


@icon("Lightning", [(82, 18, 6)])
def _(p):
    bolt(p, 50, 50, 1.25, GOLD, DARK)


@icon("Gust", [(84, 16, 5)])
def _(p):
    p.arc(56, 30, 14, 180, 450, (190, 235, 255, 255), 8)
    p.line([(10, 44), (56, 44)], (190, 235, 255, 255), 8)
    p.arc(64, 66, 12, -90, 180, (150, 215, 255, 255), 8)
    p.line([(18, 54), (64, 54)], (150, 215, 255, 255), 8)
    p.line([(14, 70), (40, 70)], (120, 200, 250, 255), 7)


@icon("Meteor", [(20, 80, 5)])
def _(p):
    p.poly([(84, 12), (52, 30), (62, 40), (40, 46), (70, 18)], ORANGE)
    p.poly([(88, 30), (60, 46), (72, 52), (54, 60)], GOLD)
    p.circle(38, 62, 24, (255, 100, 30, 255))
    p.circle(38, 62, 17, (130, 70, 50, 255))
    p.circle(32, 56, 5, (90, 50, 40, 255))
    p.circle(44, 68, 4, (90, 50, 40, 255))


@icon("Tornado", [(84, 20, 5)])
def _(p):
    rows = [(16, 84, 18), (24, 76, 34), (32, 68, 50), (40, 60, 66), (46, 54, 82)]
    for i, (x0, x1, y) in enumerate(rows):
        p.rect(x0, y - 7, x1, y + 7, (200 - i * 12, 205 - i * 12, 225 - i * 10, 255), 7)


@icon("FaultCleave", [(84, 18, 6)])
def _(p):
    p.poly([(10, 60), (90, 60), (86, 88), (14, 88)], BROWN)
    p.poly([(10, 60), (90, 60), (88, 66), (12, 66)], (110, 190, 80, 255))
    p.poly([(46, 60), (54, 60), (60, 72), (50, 76), (56, 88), (44, 88), (40, 74), (48, 70)], (255, 110, 30, 255))
    p.star(50, 34, 22, ORANGE, points=8, inner=0.55)
    p.star(50, 34, 12, GOLD, points=8, inner=0.55)


@icon("ChainLightning", [(14, 20, 5)])
def _(p):
    bolt(p, 36, 42, 0.95, (130, 210, 255, 255), DARK)
    bolt(p, 66, 58, 0.95, CYAN, DARK)


@icon("Eruption", [(82, 14, 5)])
def _(p):
    p.poly([(10, 88), (38, 36), (62, 36), (90, 88)], (120, 85, 70, 255))
    p.poly([(38, 36), (62, 36), (58, 46), (54, 56), (46, 52), (42, 44)], (255, 110, 30, 255))
    p.circle(42, 22, 9, ORANGE)
    p.circle(58, 16, 7, GOLD)
    p.circle(52, 28, 6, (255, 90, 30, 255))


@icon("Glitch")
def _(p):
    g = (255, 70, 200, 255)
    grid = ["..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.", "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX..."]
    for r, row in enumerate(grid):
        for c, ch in enumerate(row):
            if ch == "X":
                p.rect(8 + c * 7.6, 22 + r * 7.6, 8 + c * 7.6 + 7.4, 22 + r * 7.6 + 7.4, g if r % 2 else (120, 255, 200, 255))


@icon("SeismicPing", [(84, 16, 5)])
def _(p):
    p.circle(50, 50, 38, (40, 30, 80, 255))
    for r in (30, 20, 10):
        p.arc(50, 50, r, 0, 360, (180, 120, 255, 255), 3)
    p.d.pieslice((P(12, 12), P(88, 88)), -90, -30, fill=(190, 140, 255, 200))
    p.circle(64, 36, 5, GREEN)
    p.circle(38, 62, 4, GREEN)


@icon("GravitySingularity", [(84, 16, 6), (16, 84, 4)])
def _(p):
    p.ellipse(8, 36, 92, 64, PURPLE)
    p.ellipse(18, 42, 82, 58, (200, 140, 255, 255))
    p.circle(50, 50, 18, (20, 10, 30, 255))
    p.arc(50, 50, 22, 200, 340, (230, 200, 255, 255), 3)


@icon("TectonicSpire", [(84, 18, 5)])
def _(p):
    p.poly([(14, 88), (26, 40), (38, 88)], (150, 120, 100, 255))
    p.poly([(34, 88), (50, 10), (66, 88)], (175, 140, 110, 255))
    p.poly([(50, 10), (66, 88), (56, 88)], (130, 100, 80, 255))
    p.poly([(62, 88), (76, 34), (88, 88)], (150, 120, 100, 255))
    p.rect(8, 84, 92, 92, BROWN)


@icon("ChainArc", [(82, 16, 6)])
def _(p):
    for i, (x, y) in enumerate(((30, 66), (50, 50), (70, 34))):
        p.ellipse(x - 14, y - 9, x + 14, y + 9, (90, 230, 255, 255) if i % 2 == 0 else (60, 180, 240, 255))
        p.ellipse(x - 7, y - 3, x + 7, y + 3, (24, 20, 46, 255))


@icon("MeteorBarrage")
def _(p):
    p.circle(50, 50, 38, RED)
    p.circle(50, 50, 28, WHITE)
    p.circle(50, 50, 18, RED)
    p.circle(50, 50, 8, WHITE)
    p.rect(47, 6, 53, 94, (24, 20, 46, 255))
    p.rect(6, 47, 94, 53, (24, 20, 46, 255))


@icon("PyroclastSurge", [(84, 14, 5)])
def _(p):
    p.poly([(8, 88), (8, 56), (24, 40), (42, 44), (56, 26), (74, 30), (92, 52), (92, 88)], (255, 110, 30, 255))
    p.poly([(8, 88), (8, 70), (30, 60), (54, 66), (92, 62), (92, 88)], (200, 60, 30, 255))
    p.circle(60, 40, 5, GOLD)
    p.circle(30, 52, 4, GOLD)


@icon("SystemOverride")
def _(p):
    p.rect(26, 8, 74, 92, (60, 70, 100, 255), 10)
    p.rect(32, 16, 68, 78, (70, 230, 255, 255), 4)
    p.line([(36, 22), (64, 72)], RED, 7)
    p.circle(50, 85, 4, WHITE)


@icon("AstralCollapse", [(16, 18, 6), (84, 82, 5)])
def _(p):
    p.circle(50, 50, 34, (255, 200, 90, 255))
    p.circle(50, 50, 24, (255, 235, 160, 255))
    p.circle(50, 50, 12, (60, 30, 90, 255))
    p.arc(50, 50, 40, 200, 330, (255, 240, 190, 255), 4)


@icon("MaelstromVortex", [(84, 16, 5)])
def _(p):
    for i, r in enumerate((36, 27, 18, 9)):
        p.arc(50, 50, r, 30 + i * 70, 300 + i * 70, (110 + i * 30, 170 + i * 20, 255, 255), 7)
    p.circle(50, 50, 4, WHITE)


@icon("Heart", [(80, 20, 6)])
def _(p):
    p.circle(35, 38, 20, (255, 70, 110, 255))
    p.circle(65, 38, 20, (255, 70, 110, 255))
    p.poly([(16, 46), (84, 46), (50, 86)], (255, 70, 110, 255))
    p.circle(33, 32, 6, (255, 170, 190, 255))


@icon("Gift", [(82, 16, 6)])
def _(p):
    p.rect(16, 42, 84, 88, (80, 200, 255, 255), 4)
    p.rect(12, 32, 88, 46, (120, 220, 255, 255), 4)
    p.rect(44, 32, 56, 88, RED)
    p.ellipse(28, 14, 50, 34, RED)
    p.ellipse(50, 14, 72, 34, RED)


@icon("Vote", [(82, 16, 6)])
def _(p):
    p.rect(14, 46, 86, 88, (90, 160, 230, 255), 5)
    p.rect(14, 46, 86, 56, (120, 190, 250, 255), 5)
    p.rect(30, 50, 70, 54, DARK)
    p.rect(32, 12, 68, 50, WHITE, 3)
    p.line([(40, 30), (47, 38), (60, 22)], GREEN, 5)


@icon("Bag", [(80, 22, 6)])
def _(p):
    p.ellipse(16, 30, 84, 90, (200, 160, 90, 255))
    p.poly([(36, 34), (64, 34), (58, 16), (42, 16)], (200, 160, 90, 255))
    p.rect(36, 30, 64, 36, (140, 100, 50, 255), 2)
    p.circle(50, 62, 14, GOLD)
    p.star(50, 62, 8, GOLD_D)


@icon("Crown", [(84, 18, 6)])
def _(p):
    p.poly([(14, 74), (12, 30), (32, 48), (50, 20), (68, 48), (88, 30), (86, 74)], GOLD)
    p.rect(14, 72, 86, 86, GOLD_D, 3)
    for x, c in ((32, RED), (50, BLUE), (68, GREEN)):
        p.circle(x, 79, 4, c)


@icon("Timer", [(82, 18, 5)])
def _(p):
    p.rect(42, 6, 58, 16, GREY, 2)
    p.circle(50, 54, 36, WHITE)
    p.circle(50, 54, 30, (240, 245, 255, 255))
    p.d.pieslice((P(22, 26), P(78, 82)), -90, 30, fill=(255, 110, 100, 255))
    p.circle(50, 54, 4, DARK)


@icon("Star", [(84, 16, 6)])
def _(p):
    p.star(50, 52, 40, GOLD)
    p.star(50, 52, 22, (255, 230, 120, 255))


@icon("Flare", [(84, 16, 6)])
def _(p):
    p.rect(44, 48, 56, 90, RED, 3)
    p.circle(50, 38, 16, ORANGE)
    p.circle(50, 34, 10, GOLD)
    p.circle(50, 30, 5, WHITE)


@icon("Crate", [(82, 18, 6)])
def _(p):
    p.rect(14, 22, 86, 86, (230, 160, 70, 255), 4)
    p.rect(14, 22, 86, 34, (250, 200, 110, 255), 4)
    p.line([(20, 40), (80, 80)], (170, 110, 50, 255), 6)
    p.rect(44, 22, 56, 86, (60, 200, 255, 255))


@icon("Firework", [(16, 16, 6)])
def _(p):
    for i in range(10):
        a = math.radians(i * 36)
        c = [RED, GOLD, GREEN, BLUE, PINK][i % 5]
        p.line([(50 + math.cos(a) * 14, 50 + math.sin(a) * 14), (50 + math.cos(a) * 38, 50 + math.sin(a) * 38)], c, 6)
    p.circle(50, 50, 10, WHITE)


@icon("Berry", [(80, 22, 6)])
def _(p):
    p.circle(50, 58, 30, (230, 50, 90, 255))
    for x, y in ((40, 50), (58, 48), (48, 66), (62, 66), (36, 66)):
        p.circle(x, y, 2.5, GOLD)
    p.poly([(36, 30), (50, 22), (64, 30), (50, 36)], GREEN)


@icon("Bandage")
def _(p):
    p.d.rounded_rectangle((P(10, 36), P(90, 64)), radius=14 * U, fill=(250, 210, 170, 255))
    p.rect(38, 36, 62, 64, (255, 240, 225, 255))
    p.rect(46, 44, 54, 56, RED)
    p.rect(42, 48, 58, 52, RED)


@icon("Mastery", [(84, 16, 6)])
def _(p):
    p.poly([(30, 50), (20, 90), (36, 82), (44, 92), (50, 56)], RED)
    p.poly([(70, 50), (80, 90), (64, 82), (56, 92), (50, 56)], (200, 40, 50, 255))
    p.circle(50, 40, 30, GOLD)
    p.circle(50, 40, 22, (255, 225, 110, 255))
    p.star(50, 40, 14, GOLD_D)


@icon("Robux")
def _(p):
    p.d.regular_polygon((P(50, 50), 40 * U), 6, rotation=0, fill=(80, 215, 90, 255))
    p.d.regular_polygon((P(50, 50), 24 * U), 6, rotation=0, fill=WHITE)
    p.d.regular_polygon((P(50, 50), 12 * U), 6, rotation=0, fill=(80, 215, 90, 255))


@icon("Sound", [(84, 18, 5)])
def _(p):
    p.poly([(14, 38), (32, 38), (54, 18), (54, 82), (32, 62), (14, 62)], (90, 160, 230, 255))
    p.arc(56, 50, 16, -50, 50, WHITE, 6)
    p.arc(56, 50, 28, -50, 50, WHITE, 6)


def main():
    names = list(ICONS.keys())
    cell = 256
    per = 16
    sheets = {}
    index = {}
    for start in range(0, len(names), per):
        sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        k = start // per
        for i, name in enumerate(names[start:start + per]):
            fn, sp = ICONS[name]
            pen = Pen()
            fn(pen)
            img = finish(pen, sp).resize((cell, cell), Image.LANCZOS)
            x, y = (i % 4) * cell, (i // 4) * cell
            sheet.alpha_composite(img, (x, y))
            index[name] = [k, x, y]
        fname = f"sheet{k + 1}.png"
        sheet.save(os.path.join(OUT, fname))
        sheets[k] = fname
    json.dump(index, open(os.path.join(OUT, "index.json"), "w"), indent=0)
    # preview
    prev = Image.new("RGBA", (1024 * len(sheets), 1024), (60, 70, 90, 255))
    for k, f in sheets.items():
        prev.alpha_composite(Image.open(os.path.join(OUT, f)), (1024 * k, 0))
    prev.convert("RGB").resize((768 * len(sheets) // 1, 768)).save(os.path.join(OUT, "preview.jpg"))
    print(len(names), "icons ->", list(sheets.values()))


if __name__ == "__main__":
    main()
