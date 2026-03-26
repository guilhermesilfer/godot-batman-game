from PIL import Image
import os

input_folder = "input_sprites"
output_folder = "output_sprites"

os.makedirs(output_folder, exist_ok=True)

leftmost_positions = []

images = []

# Passo 1: encontrar o pixel mais à esquerda de cada imagem
for filename in sorted(os.listdir(input_folder)):
    if filename.endswith(".png"):
        path = os.path.join(input_folder, filename)
        img = Image.open(path).convert("RGBA")
        pixels = img.load()

        width, height = img.size
        leftmost = width

        for x in range(width):
            for y in range(height):
                if pixels[x, y][3] > 0:  # alpha > 0
                    leftmost = x
                    break
            if leftmost != width:
                break

        leftmost_positions.append(leftmost)
        images.append((filename, img, leftmost))

# referência: menor valor (mais à esquerda)
reference = min(leftmost_positions)

# Passo 2: alinhar todas
for filename, img, leftmost in images:
    width, height = img.size
    offset = leftmost - reference

    new_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    new_img.paste(img, (-offset, 0))

    new_img.save(os.path.join(output_folder, filename))

print("Alinhamento concluído.")
