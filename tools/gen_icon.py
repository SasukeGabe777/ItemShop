"""Generate the project icon: a pixel-art crossroads signpost. Run once."""
from PIL import Image, ImageDraw

img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rectangle([4, 4, 59, 59], fill=(40, 44, 72, 255), outline=(24, 26, 48, 255), width=2)
d.rectangle([30, 14, 34, 54], fill=(122, 82, 48, 255))  # post
for y, w_, c in ((16, 22, (216, 176, 64)), (28, 18, (80, 160, 96)), (40, 14, (200, 88, 88))):
    d.rectangle([32 - w_, y, 32 + w_, y + 8], fill=c + (255,), outline=(24, 26, 48, 255))
d.ellipse([26, 2, 38, 14], fill=(102, 224, 255, 255), outline=(24, 26, 48, 255))  # Patch
img.save(r"C:\Users\Game Station\Desktop\crossroads\assets\shared\ui\icon.png")
print("icon written")
