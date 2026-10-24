#!/usr/bin/env python3
"""
Generates high-resolution, photorealistic textures for 3D Roulette:
1. assets/textures/roulette_wheel_face.png (1024x1024)
2. assets/textures/roulette_table_felt.png (1024x512)
"""

import math
import os
from PIL import Image, ImageDraw, ImageFont

# European Roulette sequence (clockwise starting from 0)
WHEEL_NUMBERS = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
RED_NUMBERS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}

def get_font(size):
    font_paths = [
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf"
    ]
    for p in font_paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def generate_wheel_texture(out_path):
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    # Radii (in pixels)
    r_outer_wood = 510
    r_ball_track = 480
    r_pocket_outer = 430
    r_pocket_inner = 310
    r_cone_outer = 300
    r_center_turret = 110

    # 1. Outer Mahogany Rim with subtle concentric gradient
    for r in range(r_outer_wood, r_ball_track, -1):
        t = (r - r_ball_track) / (r_outer_wood - r_ball_track)
        # Rich deep mahogany
        col = (int(50 + 25 * t), int(22 + 12 * t), int(12 + 6 * t), 255)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

    # 2. Polished Brass Ball Track
    for r in range(r_ball_track, r_pocket_outer, -1):
        t = (r - r_pocket_outer) / (r_ball_track - r_pocket_outer)
        # Polished metallic brass groove gradient
        shade = math.sin(t * math.pi) * 45
        col = (int(180 + shade), int(145 + shade * 0.8), int(60 + shade * 0.4), 255)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

    # Outer pocket gold border
    draw.ellipse([cx - r_pocket_outer, cy - r_pocket_outer, cx + r_pocket_outer, cy + r_pocket_outer], outline=(230, 190, 80, 255), width=3)

    # 3. Numbered Pockets Ring (37 sectors)
    num_pockets = len(WHEEL_NUMBERS)
    sector_deg = 360.0 / num_pockets
    font = get_font(26)

    for i, num in enumerate(WHEEL_NUMBERS):
        # In European roulette, 0 is at top (-90 degrees)
        start_deg = -90.0 + i * sector_deg - sector_deg / 2.0
        end_deg = start_deg + sector_deg
        
        # Color: 0 is Emerald Green, others alternating Red and Black
        if num == 0:
            fill_col = (18, 120, 52, 255) # Rich casino emerald green
        elif num in RED_NUMBERS:
            fill_col = (195, 28, 28, 255) # Deep vibrant crimson red
        else:
            fill_col = (20, 20, 22, 255)  # Obsidian black

        # Draw sector slice
        draw.pieslice([cx - r_pocket_outer, cy - r_pocket_outer, cx + r_pocket_outer, cy + r_pocket_outer],
                      start=start_deg, end=end_deg, fill=fill_col, outline=(210, 175, 60, 255), width=2)

    # Inner pocket border & cone transition
    draw.ellipse([cx - r_pocket_inner, cy - r_pocket_inner, cx + r_pocket_inner, cy + r_pocket_inner], fill=(15, 15, 18, 255), outline=(230, 190, 80, 255), width=4)

    # 4. Render Numbers onto each sector (oriented radially)
    text_r = (r_pocket_outer + r_pocket_inner) / 2.0 - 2
    for i, num in enumerate(WHEEL_NUMBERS):
        mid_angle_deg = -90.0 + i * sector_deg
        rad = math.radians(mid_angle_deg)
        tx = cx + text_r * math.cos(rad)
        ty = cy + text_r * math.sin(rad)
        
        # Create rotated text snippet
        txt = str(num)
        txt_img = Image.new("RGBA", (80, 50), (0, 0, 0, 0))
        t_draw = ImageDraw.Draw(txt_img)
        bbox = font.getbbox(txt)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        
        # Draw with dark drop shadow and bright white text
        t_draw.text(((80 - w) // 2 + 1, (50 - h) // 2 + 1), txt, font=font, fill=(0, 0, 0, 220))
        t_draw.text(((80 - w) // 2, (50 - h) // 2), txt, font=font, fill=(255, 255, 255, 255))
        
        # Rotate text snippet: point inwards towards center
        rot_deg = -(mid_angle_deg + 90.0)
        rotated_txt = txt_img.rotate(rot_deg, expand=True, resample=Image.BICUBIC)
        rw, rh = rotated_txt.size
        img.paste(rotated_txt, (int(tx - rw // 2), int(ty - rh // 2)), rotated_txt)

    # 5. Inner Cone (Sloping metallic brass/wood)
    for r in range(r_cone_outer, r_center_turret, -1):
        t = (r - r_center_turret) / (r_cone_outer - r_center_turret)
        # Metallic champagne brass radial cone gradient
        shade = math.sin(t * math.pi * 1.5) * 35
        col = (int(165 + shade), int(135 + shade * 0.8), int(55 + shade * 0.4), 255)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

    # Draw 8 deflector diamond pins along the cone
    for d_idx in range(8):
        d_angle = math.radians(d_idx * 45.0 + 22.5)
        dr = 365.0
        dx = cx + dr * math.cos(d_angle)
        dy = cy + dr * math.sin(d_angle)
        # Small diamond pin
        diamond = [
            (dx, dy - 7),
            (dx + 5, dy),
            (dx, dy + 7),
            (dx - 5, dy)
        ]
        draw.polygon(diamond, fill=(255, 235, 150, 255), outline=(120, 95, 30, 255))

    # 6. Central Brass Spindle / Turret
    for r in range(r_center_turret, 0, -1):
        t = r / float(r_center_turret)
        highlight = math.sin(t * math.pi) * 60
        col = (int(210 + highlight * 0.7), int(175 + highlight * 0.6), int(75 + highlight * 0.3), 255)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

    draw.ellipse([cx - r_center_turret, cy - r_center_turret, cx + r_center_turret, cy + r_center_turret], outline=(255, 240, 160, 255), width=3)
    draw.ellipse([cx - 25, cy - 25, cx + 25, cy + 25], fill=(255, 235, 140, 255), outline=(140, 110, 40, 255), width=2)

    # 4 Cross handles on turret
    for h_angle in [0, 90, 180, 270]:
        h_rad = math.radians(h_angle)
        hx = cx + 55 * math.cos(h_rad)
        hy = cy + 55 * math.sin(h_rad)
        draw.circle((hx, hy), 12, fill=(245, 215, 110, 255), outline=(130, 100, 30, 255), width=2)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, "PNG")
    print(f"Saved {out_path} ({size}x{size})")

def generate_felt_texture(out_path):
    w, h = 1024, 512
    img = Image.new("RGBA", (w, h), (12, 65, 32, 255)) # Classic rich casino green felt
    draw = ImageDraw.Draw(img)

    # Fine fabric noise / texture
    import random
    random.seed(42)
    pixels = img.load()
    for y in range(h):
        for x in range(w):
            noise = random.randint(-4, 4)
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (max(0, min(255, r + noise)), max(0, min(255, g + noise * 2)), max(0, min(255, b + noise)), 255)

    gold = (235, 195, 65, 255)
    gold_dim = (180, 150, 50, 200)
    red_col = (195, 28, 28, 255)
    black_col = (24, 24, 28, 255)
    green_col = (18, 120, 52, 255)

    # Outer border
    draw.rectangle([8, 8, w - 9, h - 9], outline=gold, width=4)
    draw.rectangle([14, 14, w - 15, h - 15], outline=gold_dim, width=1)

    # Title header
    font_title = get_font(22)
    title_txt = "★ CEASER VIP ROULETTE  •  EUROPEAN SINGLE ZERO ★"
    t_bbox = font_title.getbbox(title_txt)
    tw = t_bbox[2] - t_bbox[0]
    draw.text(((w - tw) // 2, 22), title_txt, font=font_title, fill=gold)

    # Grid boundaries
    grid_x0 = 80
    grid_y0 = 65
    grid_w = 860
    grid_h = 420

    # 0 box on left
    zero_box = [grid_x0, grid_y0, grid_x0 + 70, grid_y0 + 260]
    draw.rectangle(zero_box, fill=green_col, outline=gold, width=2)
    font_zero = get_font(38)
    draw.text((grid_x0 + 22, grid_y0 + 105), "0", font=font_zero, fill=(255, 255, 255, 255))

    # Numbers 1 to 36 in 12 columns x 3 rows
    col_w = (grid_w - 70 - 70) // 12
    row_h = 260 // 3
    font_num = get_font(22)

    for col in range(12):
        for row in range(3):
            # Row 0: 3, 6, 9, 12... (top row is 3, 6...)
            # Row 1: 2, 5, 8, 11...
            # Row 2: 1, 4, 7, 10...
            val = (col * 3) + (3 - row)
            bx0 = grid_x0 + 70 + col * col_w
            by0 = grid_y0 + row * row_h
            bx1 = bx0 + col_w
            by1 = by0 + row_h
            
            fill = red_col if val in RED_NUMBERS else black_col
            draw.rectangle([bx0, by0, bx1, by1], fill=fill, outline=gold, width=2)
            
            v_str = str(val)
            v_box = font_num.getbbox(v_str)
            vw = v_box[2] - v_box[0]
            vh = v_box[3] - v_box[1]
            draw.text((bx0 + (col_w - vw) // 2, by0 + (row_h - vh) // 2), v_str, font=font_num, fill=(255, 255, 255, 255))

    # 2 to 1 columns on right
    font_col = get_font(15)
    for row in range(3):
        cx0 = grid_x0 + 70 + 12 * col_w
        cy0 = grid_y0 + row * row_h
        cx1 = cx0 + 70
        cy1 = cy0 + row_h
        draw.rectangle([cx0, cy0, cx1, cy1], fill=(15, 60, 30, 255), outline=gold, width=2)
        draw.text((cx0 + 12, cy0 + 32), "2 to 1", font=font_col, fill=gold)

    # Dozen boxes (1st 12, 2nd 12, 3rd 12)
    doz_y0 = grid_y0 + 260
    doz_h = 55
    doz_w = (12 * col_w) // 3
    font_doz = get_font(18)
    doz_labels = ["1st 12 (1 - 12)", "2nd 12 (13 - 24)", "3rd 12 (25 - 36)"]
    for d in range(3):
        dx0 = grid_x0 + 70 + d * doz_w
        dx1 = dx0 + doz_w
        draw.rectangle([dx0, doz_y0, dx1, doz_y0 + doz_h], fill=(16, 75, 36, 255), outline=gold, width=2)
        d_bbox = font_doz.getbbox(doz_labels[d])
        dw = d_bbox[2] - d_bbox[0]
        draw.text((dx0 + (doz_w - dw) // 2, doz_y0 + 18), doz_labels[d], font=font_doz, fill=gold)

    # Outside bet boxes: 1-18, EVEN, RED, BLACK, ODD, 19-36
    out_y0 = doz_y0 + doz_h
    out_h = 60
    out_w = (12 * col_w) // 6
    font_out = get_font(16)
    out_items = [
        ("1 - 18", None),
        ("EVEN", None),
        ("RED", red_col),
        ("BLACK", black_col),
        ("ODD", None),
        ("19 - 36", None)
    ]
    for o, (lbl, bg_override) in enumerate(out_items):
        ox0 = grid_x0 + 70 + o * out_w
        ox1 = ox0 + out_w
        fill_b = bg_override if bg_override else (14, 70, 34, 255)
        draw.rectangle([ox0, out_y0, ox1, out_y0 + out_h], fill=fill_b, outline=gold, width=2)
        o_bbox = font_out.getbbox(lbl)
        ow = o_bbox[2] - o_bbox[0]
        draw.text((ox0 + (out_w - ow) // 2, out_y0 + 20), lbl, font=font_out, fill=(255, 255, 255, 255) if bg_override else gold)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, "PNG")
    print(f"Saved {out_path} ({w}x{h})")

if __name__ == "__main__":
    generate_wheel_texture("/home/eldho/Eldho/stumble-home/assets/textures/roulette_wheel_face.png")
    generate_felt_texture("/home/eldho/Eldho/stumble-home/assets/textures/roulette_table_felt.png")
