from PIL import Image
import os

input_folder = "input_sprites"
output_folder = "output_sprites"

os.makedirs(output_folder, exist_ok=True)

images = []
lowest_points = []

# 1. Carregar imagens e achar o ponto mais baixo
for filename in sorted(os.listdir(input_folder)):
    if filename.endswith(".png"):
        path = os.path.join(input_folder, filename)
        img = Image.open(path).convert("RGBA")
        pixels = img.load()

        width, height = img.size
        lowest_y = 0

        for y in range(height):
            for x in range(width):
                if pixels[x, y][3] > 0:  # alpha > 0
                    if y > lowest_y:
                        lowest_y = y

        images.append((filename, img, lowest_y))
        lowest_points.append(lowest_y)

# 2. Descobrir o pé mais baixo geral
global_lowest = max(lowest_points)

# 3. Ajustar todas as imagens
for filename, img, lowest_y in images:
    width, height = img.size
    offset = global_lowest - lowest_y

    new_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    new_img.paste(img, (0, offset))

    output_path = os.path.join(output_folder, filename)
    new_img.save(output_path)

print("Sprites alinhadas com sucesso!")