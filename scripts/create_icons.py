#!/usr/bin/env python3
"""
Create macOS App Icons for menu-bar-executor
Following Linear Precisionism design philosophy
"""

from PIL import Image, ImageDraw

def create_rounded_rect_mask(size, radius):
    """Create a rounded rectangle mask for macOS app icon style"""
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), size], radius=radius, fill=255)
    return mask

def draw_cursor(draw, x, y, scale=1.0, color=(255, 255, 255, 255), line_width=2):
    """Draw an arrow cursor with thin lines"""
    # Cursor points (arrow shape)
    points = [
        (x, y),  # tip
        (x, y + int(60 * scale)),  # bottom left of arrow head
        (x + int(20 * scale), y + int(45 * scale)),  # inner corner
        (x + int(35 * scale), y + int(70 * scale)),  # bottom of stem
        (x + int(45 * scale), y + int(65 * scale)),  # top of stem
        (x + int(30 * scale), y + int(40 * scale)),  # back to arrow
        (x + int(55 * scale), y + int(40 * scale)),  # right of arrow head
    ]
    draw.polygon(points, outline=color[:3], width=line_width)


def create_icon_option_a():
    """
    Option A: Minimal Menu Bar
    Simple, clean lines - menu bar with cursor
    """
    size = 1024
    radius = 220  # macOS icon corner radius (~22%)

    # Create image with dark background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark gradient-like background
    draw.rounded_rectangle(
        [(0, 0), (size, size)],
        radius=radius,
        fill=(28, 28, 30, 255)  # Deep dark gray
    )

    # Menu bar - thin horizontal rectangle
    bar_y = 280
    bar_height = 100
    bar_margin = 180
    bar_color = (255, 255, 255, 255)
    line_width = 3

    # Menu bar background (subtle)
    draw.rounded_rectangle(
        [(bar_margin, bar_y), (size - bar_margin, bar_y + bar_height)],
        radius=16,
        outline=bar_color[:3],
        width=line_width
    )

    # Menu items (three small vertical lines representing menu items)
    item_y = bar_y + bar_height // 2
    item_spacing = 180
    start_x = size // 2 - item_spacing

    for i in range(3):
        x = start_x + i * item_spacing
        # Small horizontal lines for menu items
        draw.line([(x - 30, item_y), (x + 30, item_y)], fill=bar_color[:3], width=line_width)

    # Cursor pointing to menu bar
    cursor_x = size // 2 - 100
    cursor_y = bar_y + bar_height + 60
    draw_cursor(draw, cursor_x, cursor_y, scale=2.5, color=bar_color, line_width=4)

    # Subtle glow effect on cursor tip
    glow_center = (cursor_x + 20, cursor_y + 30)
    for r in range(40, 0, -5):
        alpha = int(30 * (40 - r) / 40)
        glow_color = (100, 150, 255, alpha)
        draw.ellipse(
            [(glow_center[0] - r, glow_center[1] - r),
             (glow_center[0] + r, glow_center[1] + r)],
            fill=glow_color
        )

    # Apply rounded mask
    mask = create_rounded_rect_mask((size, size), radius)
    img.putalpha(mask)

    return img


def create_icon_option_b():
    """
    Option B: Terminal Fusion
    Menu bar combined with terminal/command prompt elements
    """
    size = 1024
    radius = 220

    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Darker background with subtle blue tint
    draw.rounded_rectangle(
        [(0, 0), (size, size)],
        radius=radius,
        fill=(20, 22, 30, 255)
    )

    line_color = (200, 205, 220, 255)
    accent_color = (90, 140, 255, 255)  # Blue accent
    line_width = 3

    # Terminal window frame
    term_margin = 200
    term_top = 280
    term_bottom = 700
    term_corner = 24

    draw.rounded_rectangle(
        [(term_margin, term_top), (size - term_margin, term_bottom)],
        radius=term_corner,
        outline=line_color[:3],
        width=line_width
    )

    # Title bar line
    draw.line(
        [(term_margin, term_top + 60), (size - term_margin, term_top + 60)],
        fill=line_color[:3],
        width=line_width
    )

    # Window buttons (subtle circles)
    button_y = term_top + 30
    button_x = term_margin + 40
    button_radius = 12
    for i, color in enumerate([(255, 90, 90), (255, 190, 90), (90, 255, 90)]):
        x = button_x + i * 40
        draw.ellipse(
            [(x - button_radius, button_y - button_radius),
             (x + button_radius, button_y + button_radius)],
            outline=color,
            width=2
        )

    # Command prompt ($) with cursor
    prompt_x = term_margin + 60
    prompt_y = term_top + 140
    prompt_color = accent_color[:3]

    # Dollar sign represented as simple lines
    draw.line([(prompt_x, prompt_y - 30), (prompt_x, prompt_y + 30)], fill=prompt_color, width=line_width)
    draw.line([(prompt_x - 15, prompt_y - 10), (prompt_x + 15, prompt_y - 10)], fill=prompt_color, width=line_width)
    draw.line([(prompt_x - 15, prompt_y + 10), (prompt_x + 15, prompt_y + 10)], fill=prompt_color, width=line_width)

    # Cursor line after prompt
    cursor_line_x = prompt_x + 60
    draw.line(
        [(cursor_line_x, prompt_y - 20), (cursor_line_x + 200, prompt_y - 20)],
        fill=line_color[:3],
        width=line_width
    )

    # Blinking cursor (vertical line)
    blink_x = cursor_line_x + 220
    draw.line(
        [(blink_x, prompt_y - 25), (blink_x, prompt_y + 5)],
        fill=accent_color[:3],
        width=line_width + 1
    )

    # Arrow cursor (pointer) at bottom right
    cursor_x = size - 350
    cursor_y = 520
    draw_cursor(draw, cursor_x, cursor_y, scale=3.0, color=line_color, line_width=4)

    # Subtle blue glow under cursor
    glow_center = (cursor_x + 50, cursor_y + 100)
    for r in range(60, 0, -8):
        alpha = int(25 * (60 - r) / 60)
        draw.ellipse(
            [(glow_center[0] - r, glow_center[1] - r),
             (glow_center[0] + r, glow_center[1] + r)],
            fill=(90, 140, 255, alpha)
        )

    mask = create_rounded_rect_mask((size, size), radius)
    img.putalpha(mask)

    return img


def create_icon_option_c():
    """
    Option C: Dynamic Execute
    Menu bar with lightning bolt / execute symbol
    Emphasizes the "execution" action
    """
    size = 1024
    radius = 220

    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Very dark background
    draw.rounded_rectangle(
        [(0, 0), (size, size)],
        radius=radius,
        fill=(18, 18, 20, 255)
    )

    line_color = (240, 240, 245, 255)
    accent_color = (255, 180, 50, 255)  # Orange/amber accent
    line_width = 3

    # Circular background element (subtle)
    center = (size // 2, size // 2)
    for r in range(300, 200, -20):
        alpha = int(15 * (300 - r) / 100)
        draw.ellipse(
            [(center[0] - r, center[1] - r), (center[0] + r, center[1] + r)],
            outline=(255, 255, 255, alpha),
            width=1
        )

    # Lightning bolt / execute symbol
    bolt_points = [
        (center[0] - 40, center[1] - 200),
        (center[0] + 60, center[1] - 50),
        (center[0] - 10, center[1] - 50),
        (center[0] + 80, center[1] + 180),
        (center[0] - 20, center[1] + 20),
        (center[0] + 30, center[1] + 20),
    ]

    # Draw lightning with glow effect
    for offset in range(3, 0, -1):
        for i in range(len(bolt_points) - 1):
            draw.line(
                [bolt_points[i], bolt_points[i + 1]],
                fill=accent_color[:3],
                width=line_width + offset * 2
            )

    # Main lightning bolt
    for i in range(len(bolt_points) - 1):
        draw.line(
            [bolt_points[i], bolt_points[i + 1]],
            fill=(255, 255, 255),
            width=line_width
        )

    # Menu bar at top (minimal)
    bar_y = 220
    bar_height = 60
    bar_margin = 250

    draw.rounded_rectangle(
        [(bar_margin, bar_y), (size - bar_margin, bar_y + bar_height)],
        radius=12,
        outline=line_color[:3],
        width=line_width
    )

    # Three menu dots
    dot_y = bar_y + bar_height // 2
    for i in range(3):
        dot_x = bar_margin + 60 + i * 150
        draw.ellipse(
            [(dot_x - 6, dot_y - 6), (dot_x + 6, dot_y + 6)],
            fill=line_color[:3]
        )

    # Cursor pointing to execute button
    cursor_x = center[0] + 150
    cursor_y = center[1] + 80
    draw_cursor(draw, cursor_x, cursor_y, scale=2.5, color=line_color, line_width=4)

    # Glow at cursor tip
    glow_x = cursor_x + 30
    glow_y = cursor_y + 40
    for r in range(35, 0, -5):
        alpha = int(40 * (35 - r) / 35)
        draw.ellipse(
            [(glow_x - r, glow_y - r), (glow_x + r, glow_y + r)],
            fill=(*accent_color[:3], alpha)
        )

    mask = create_rounded_rect_mask((size, size), radius)
    img.putalpha(mask)

    return img


def main():
    import os

    output_dir = "/Users/wangze/Library/CloudStorage/OneDrive-Personal/codes/menu-bar-exector/assets/icons"
    os.makedirs(output_dir, exist_ok=True)

    # Create all three options
    icons = [
        ("AppIcon-Option-A.png", create_icon_option_a, "简约菜单栏"),
        ("AppIcon-Option-B.png", create_icon_option_b, "终端融合"),
        ("AppIcon-Option-C.png", create_icon_option_c, "动态执行"),
    ]

    for filename, creator, name in icons:
        img = creator()
        filepath = os.path.join(output_dir, filename)
        img.save(filepath, "PNG")
        print(f"✓ Created {filename} ({name})")

    print(f"\n所有图标已保存到: {output_dir}")


if __name__ == "__main__":
    main()
