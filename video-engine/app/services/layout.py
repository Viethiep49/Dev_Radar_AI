import html
import cairosvg
from PIL import ImageFont
from app.schemas.spec import Slide

CANVAS = {"720p": (720, 1280), "1080p": (1080, 1920)}

def safe_insets(size: tuple[int, int]) -> dict[str, int]:
    w, h = size
    return {
        "top": round(h * 0.09),
        "bottom": round(h * 0.235),
        "left": round(w * 0.083),
        "right": round(w * 0.167),
    }

SAFE_INSET = safe_insets(CANVAS["720p"])

def wrap_text(
    text: str, font_path: str, font_size: int, max_width: int, max_lines: int
) -> list[str]:
    try:
        font = ImageFont.truetype(font_path, font_size)
    except OSError:
        font = ImageFont.load_default()

    def get_width(s):
        return font.getlength(s)

    words = text.split()
    lines = []
    current_line = []

    for word in words:
        if get_width(word) > max_width:
            if current_line:
                lines.append(" ".join(current_line))
                current_line = []
            current_chunk = ""
            for char in word:
                if get_width(current_chunk + char) <= max_width:
                    current_chunk += char
                else:
                    if current_chunk:
                        lines.append(current_chunk)
                    current_chunk = char
            if current_chunk:
                current_line.append(current_chunk)
        else:
            test_line = " ".join(current_line + [word]) if current_line else word
            if get_width(test_line) <= max_width:
                current_line.append(word)
            else:
                lines.append(" ".join(current_line))
                current_line = [word]

    if current_line:
        lines.append(" ".join(current_line))

    if len(lines) > max_lines:
        lines = lines[:max_lines]
        last_line = lines[-1]
        while len(last_line) > 1 and get_width(last_line + "…") > max_width:
            last_line = last_line[:-1]
        lines[-1] = last_line.strip() + "…"

    return lines


def slide_to_svg(slide: Slide, index: int, total: int, size: tuple[int, int]) -> str:
    w, h = size
    insets = safe_insets(size)
    
    text_color = "#FFFFFF"
    
    svg = [
        f'<svg width="{w}" height="{h}" xmlns="http://www.w3.org/2000/svg">',
        '<defs>',
        '  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">',
        '    <stop offset="0%" stop-color="#0F2027"/>',
        '    <stop offset="50%" stop-color="#203A43"/>',
        '    <stop offset="100%" stop-color="#2C5364"/>',
        '  </linearGradient>',
        '</defs>',
        f'<rect width="{w}" height="{h}" fill="url(#bg)" />',
    ]

    # Progress bar
    bar_width = (index + 1) / total * w
    svg.append(f'<rect x="0" y="0" width="{bar_width}" height="{h * 0.01}" fill="#4CAF50" />')

    # Card layout
    card_margin = insets["left"]
    card_w = w - card_margin * 2
    card_h = h - insets["top"] - insets["bottom"] - 100
    card_y = insets["top"] + 100
    
    svg.append(f'<rect x="{card_margin}" y="{card_y}" width="{card_w}" height="{card_h}" rx="32" fill="rgba(255, 255, 255, 0.07)" stroke="rgba(255, 255, 255, 0.15)" stroke-width="2"/>')

    cx = w / 2

    def escape(s: str) -> str:
        return html.escape(s)
        
    def add_text_lines(text: str, y_start: int, font_size: int, font_weight: str, fill: str, max_lines: int) -> int:
        lines = wrap_text(text, "", font_size, card_w - 60, max_lines)
        cy = y_start
        for line in lines:
            svg.append(f'<text x="{cx}" y="{cy}" fill="{fill}" font-family="Be Vietnam Pro" font-size="{font_size}" font-weight="{font_weight}" text-anchor="middle">{escape(line)}</text>')
            cy += font_size + 15
        return cy

    if slide.kind == "hook":
        y = card_y + card_h / 2 - 40
        y = add_text_lines(slide.title, y, 64, "bold", text_color, 2)
        if slide.subtitle:
            y += 20
            add_text_lines(slide.subtitle, y, 40, "normal", "#A0AAB2", 2)

    elif slide.kind == "stat":
        y = card_y + card_h / 2 - 60
        y = add_text_lines(slide.label, y, 40, "normal", "#A0AAB2", 2)
        y += 20
        svg.append(f'<text x="{cx}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="80" font-weight="bold" text-anchor="middle">{escape(slide.value)}</text>')
        y += 90
        if slide.unit:
            svg.append(f'<text x="{cx}" y="{y}" fill="#4CAF50" font-family="Be Vietnam Pro" font-size="40" font-weight="bold" text-anchor="middle">{escape(slide.unit)}</text>')

    elif slide.kind == "list":
        y = card_y + 80
        y = add_text_lines(slide.title, y, 56, "bold", text_color, 2)
        y += 40
        for item in slide.items:
            # Left align list items slightly offset from center
            svg.append(f'<text x="{card_margin + 60}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="36" font-weight="normal">• {escape(item)}</text>')
            y += 60

    elif slide.kind == "repo":
        y = card_y + 100
        y = add_text_lines(slide.full_name, y, 48, "bold", text_color, 2)
        
        y += 30
        if slide.description:
            y = add_text_lines(slide.description[:120], y, 32, "normal", "#E0E0E0", 3)
            
        y += 40
        if slide.language:
            svg.append(f'<text x="{cx}" y="{y}" fill="#888888" font-family="Be Vietnam Pro" font-size="32" text-anchor="middle">Lập trình bằng {escape(slide.language)}</text>')
            y += 60
            
        # Draw star
        stars_str = f"{slide.stars:,}".replace(",", ".")
        gained_str = f"(+{slide.stars_gained:,})".replace(",", ".") if slide.stars_gained else ""
        
        star_path = "M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"
        # Translate to center-ish
        svg.append(f'<g transform="translate({cx - 150}, {y - 45}) scale(1.5)">')
        svg.append(f'<path d="{star_path}" fill="#FFD700" />')
        svg.append('</g>')
        
        svg.append(f'<text x="{cx}" y="{y}" fill="#FFD700" font-family="Be Vietnam Pro" font-size="40" font-weight="bold" text-anchor="middle">{stars_str} <tspan fill="#4CAF50" font-size="32">{gained_str}</tspan></text>')

    elif slide.kind == "outro":
        y = card_y + card_h / 2 - 40
        y = add_text_lines(slide.title, y, 64, "bold", text_color, 2)
        if slide.subtitle:
            y += 20
            add_text_lines(slide.subtitle, y, 40, "normal", "#A0AAB2", 2)

    svg.append("</svg>")
    return "\n".join(svg)

def render_slide_png(slide: Slide, index: int, total: int, size: tuple[int, int]) -> bytes:
    svg_str = slide_to_svg(slide, index, total, size)
    return cairosvg.svg2png(bytestring=svg_str.encode("utf-8"))
