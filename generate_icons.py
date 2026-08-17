from PIL import Image
import os

# Source icon
src = Image.open('assets/ic_launcher.png').convert('RGBA')

# Android launcher icon sizes
sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

for folder, size in sizes.items():
    path = f'android/app/src/main/res/{folder}/ic_launcher.png'
    icon = src.resize((size, size), Image.LANCZOS)
    icon.save(path, 'PNG')
    print(f'Created {path} ({size}x{size})')

print('Done')
