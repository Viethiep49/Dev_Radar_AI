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

    bg_color = "#1E1E1E"
    text_color = "#FFFFFF"

    svg = [
        f'<svg width="{w}" height="{h}" xmlns="http://www.w3.org/2000/svg">',
        f'<rect width="{w}" height="{h}" fill="{bg_color}" />',
    ]

    bar_width = (index + 1) / total * w
    svg.append(f'<rect x="0" y="0" width="{bar_width}" height="{h * 0.01}" fill="#4CAF50" />')

    x = insets["left"]
    y = insets["top"] + 50

    svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="24">{index + 1}/{total}</text>')
    y += 50

    def escape(s: str) -> str:
        return html.escape(s)

    if slide.kind == "hook":
        svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="48" font-weight="bold">{escape(slide.title)}</text>')
        if slide.subtitle:
            y += 60
            svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="32">{escape(slide.subtitle)}</text>')

    elif slide.kind == "stat":
        svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="32">{escape(slide.label)}</text>')
        y += 60
        svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="64" font-weight="bold">{escape(slide.value)}</text>')
        if slide.unit:
            svg.append(f'<text x="{x + 200}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="32">{escape(slide.unit)}</text>')

    elif slide.kind == "list":
        svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="48" font-weight="bold">{escape(slide.title)}</text>')
        y += 60
        for item in slide.items:
            svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="32">• {escape(item)}</text>')
            y += 50

    elif slide.kind == "repo":
        svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="36" font-weight="bold">{escape(slide.full_name)}</text>')
        y += 50
        if slide.description:
            svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="28">{escape(slide.description[:100])}</text>')
            y += 40
        if slide.language:
            svg.append(f'<text x="{x}" y="{y}" fill="#888888" font-family="Be Vietnam Pro" font-size="28">{escape(slide.language)}</text>')
            y += 40
        stars_str = f"{slide.stars:,}".replace(",", ".")
        svg.append(f'<text x="{x}" y="{y}" fill="#FFD700" font-family="Be Vietnam Pro" font-size="28">⭐ {stars_str}</text>')
        if slide.stars_gained:
            gained_str = f"+{slide.stars_gained:,}".replace(",", ".")
            svg.append(f'<text x="{x + 200}" y="{y}" fill="#4CAF50" font-family="Be Vietnam Pro" font-size="28">{gained_str}</text>')

    elif slide.kind == "outro":
        svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="48" font-weight="bold">{escape(slide.title)}</text>')
        if slide.subtitle:
            y += 60
            svg.append(f'<text x="{x}" y="{y}" fill="{text_color}" font-family="Be Vietnam Pro" font-size="32">{escape(slide.subtitle)}</text>')

    svg.append("</svg>")
    return "\n".join(svg)


def render_slide_png(slide: Slide, index: int, total: int, size: tuple[int, int]) -> bytes:
    svg_str = slide_to_svg(slide, index, total, size)
    return cairosvg.svg2png(bytestring=svg_str.encode("utf-8"))
