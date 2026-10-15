# Makes the Android app icons and splash screens from Gemini's art/app_icon.png.
# Run from the project folder after `npx cap add android`:  .venv/bin/python tools/make_android_icons.py
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'game/android/app/src/main/res'
icon = Image.open(ROOT / 'art/app_icon.png').convert('RGBA')
purple = icon.getpixel((12, 12))[:3]  # the icon's own background colour

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

for name, k in DENSITIES.items():
    folder = RES / f'mipmap-{name}'
    # old-style square icon and round icon (48dp)
    size = round(48 * k)
    square = icon.resize((size, size), Image.LANCZOS)
    square.save(folder / 'ic_launcher.png')
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    round_icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    round_icon.paste(square, (0, 0), mask)
    round_icon.save(folder / 'ic_launcher_round.png')
    # adaptive icon layer (108dp); the phone crops it to its own shape, her face stays in the middle
    fg = round(108 * k)
    icon.resize((fg, fg), Image.LANCZOS).save(folder / 'ic_launcher_foreground.png')

(RES / 'values/ic_launcher_background.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'    <color name="ic_launcher_background">#{purple[0]:02X}{purple[1]:02X}{purple[2]:02X}</color>\n'
    '</resources>\n')

# splash screens: black, with the icon in a rounded square in the middle
for path in RES.glob('drawable*/splash.png'):
    w, h = Image.open(path).size
    splash = Image.new('RGB', (w, h), (0, 0, 0))
    s = round(min(w, h) * 0.35)
    mask = Image.new('L', (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=s // 6, fill=255)
    splash.paste(icon.resize((s, s), Image.LANCZOS).convert('RGB'), ((w - s) // 2, (h - s) // 2), mask)
    splash.save(path)

print('icons and splash screens written')
