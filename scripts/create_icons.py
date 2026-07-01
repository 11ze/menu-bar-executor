#!/usr/bin/env python3
"""
Generate MenuBarExecutor app icon and menu bar icon.
Style: white chubby >_ on dark background (rounded balloon font).
"""

from PIL import Image, ImageDraw
import os
import subprocess

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS_DIR = os.path.join(PROJECT_DIR, "assets", "icons")


def rounded_rect_mask(size, radius):
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), size], radius=radius, fill=255)
    return mask


def create_app_icon():
    """1024x1024 app icon: dark background + white >_ prompt."""
    size = 1024
    radius = 224

    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 背景
    draw.rounded_rectangle(
        [(0, 0), (size, size)],
        radius=radius,
        fill=(26, 26, 26, 255)  # #1a1a1a
    )

    # > 箭头（45度 V 形，外接正方形 400x400）
    line_color = (255, 255, 255, 255)
    line_width = 104
    arrow_x = 312       # 正方形左边
    arrow_top = 312     # 正方形顶部
    arrow_mid = 512     # 画布中心（也是正方形中心）
    arrow_bottom = 712  # 正方形底部
    arrow_tip = 512     # 尖端 = 正方形左边 + 200

    draw.line([(arrow_x, arrow_top), (arrow_tip, arrow_mid)],
              fill=line_color, width=line_width)
    draw.line([(arrow_tip, arrow_mid), (arrow_x, arrow_bottom)],
              fill=line_color, width=line_width)

    # 圆角端点补充（line 不支持 linecap，手动画圆）
    cap_r = line_width // 2
    for pos in [(arrow_x, arrow_top), (arrow_tip, arrow_mid), (arrow_x, arrow_bottom)]:
        draw.ellipse(
            [(pos[0] - cap_r, pos[1] - cap_r),
             (pos[0] + cap_r, pos[1] + cap_r)],
            fill=line_color
        )

    # _ 下划线（用 rounded_rectangle 代替 line+ellipse，避免凹凸）
    underline_y = 692
    underline_start = 520
    underline_end = 780     # 长度 260 = 箭头宽度 * 1.3
    draw.rounded_rectangle(
        [(underline_start, underline_y - cap_r),
         (underline_end, underline_y + cap_r)],
        radius=cap_r,
        fill=line_color
    )

    # 应用圆角蒙版
    mask = rounded_rect_mask((size, size), radius)
    img.putalpha(mask)

    return img


def create_menu_bar_icon(canvas_size=44):
    """Menu bar icon: render SVG via rsvg-convert for proper stroke-linecap support."""
    svg_path = os.path.join(ICONS_DIR, "menu-bar-icon.svg")
    output_path = os.path.join(ICONS_DIR, f"menu-bar-icon-{canvas_size}.png")

    result = subprocess.run(
        [
            "/opt/homebrew/bin/rsvg-convert",
            "--width", str(canvas_size),
            "--height", str(canvas_size),
            "--output", output_path,
            svg_path,
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(f"rsvg-convert failed: {result.stderr}")

    return output_path


def main():
    os.makedirs(ICONS_DIR, exist_ok=True)

    # 应用图标
    app_icon = create_app_icon()
    app_path = os.path.join(ICONS_DIR, "AppIcon.png")
    app_icon.save(app_path, "PNG")
    print(f"App icon -> {app_path}")

    # 菜单栏图标 @1x (22px) 和 @2x (44px)
    for scale, size in [("1x", 22), ("2x", 44)]:
        path = create_menu_bar_icon(canvas_size=size)
        print(f"Menu bar icon @ {scale} ({size}px) -> {path}")

    print("\n所有图标已生成")


if __name__ == "__main__":
    main()
