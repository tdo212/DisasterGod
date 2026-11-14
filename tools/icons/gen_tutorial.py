from PIL import Image, ImageDraw
import sys
out = sys.argv[1]
# 1) beam strip: one chevron per tile (tiles horizontally along the beam), 256x128
W, H = 256, 128
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
def chevron(cx, color, outline, w):
    pts = [(cx - 50, 12), (cx + 20, 12), (cx + 80, 64), (cx + 20, 116), (cx - 50, 116), (cx + 10, 64)]
    d.polygon(pts, fill=outline)
    inner = [(cx - 50 + w, 12 + w), (cx + 20 - w * 0.4, 12 + w), (cx + 80 - w * 1.6, 64), (cx + 20 - w * 0.4, 116 - w), (cx - 50 + w, 116 - w), (cx + 10 - w * 0.2, 64)]
    d.polygon(inner, fill=color)
chevron(110, (255, 255, 255, 255), (10, 12, 20, 255), 9)
# soft shade on the lower half for a 3D look
shade = Image.new('RGBA', (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(shade)
sd.rectangle([0, 72, W, H], fill=(150, 160, 190, 70))
mask = img.split()[3]
img = Image.composite(Image.alpha_composite(img, shade), img, mask)
img.save(out + '/tut_beam.png')
# 2) UI pointer: big yellow arrow pointing DOWN with black outline, 256x256
img = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
outer = [(78, 8), (178, 8), (178, 120), (238, 120), (128, 246), (18, 120), (78, 120)]
d.polygon(outer, fill=(10, 12, 20, 255))
inner = [(92, 22), (164, 22), (164, 134), (206, 134), (128, 226), (50, 134), (92, 134)]
d.polygon(inner, fill=(255, 210, 40, 255))
d.polygon([(92, 22), (164, 22), (164, 70), (92, 70)], fill=(255, 235, 120, 255))
img.save(out + '/tut_arrow.png')
print('ok')
