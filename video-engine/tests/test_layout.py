import pytest
import sys
from unittest.mock import MagicMock
sys.modules['cairosvg'] = MagicMock()
sys.modules['cairosvg'].svg2png.return_value = b"\x89PNG\r\n\x1a\n"

from pathlib import Path
from app.core.config import settings
settings.font_regular = Path("fonts/BeVietnamPro-Regular.ttf")

from app.schemas.spec import HookSlide, RepoSlide, StatSlide
from app.services.layout import (
    CANVAS,
    SAFE_INSET,
    render_slide_png,
    slide_to_svg,
    wrap_text,
)


def test_wrap_text_returns_at_most_max_lines():
    lines = wrap_text(
        "một hai ba bốn năm sáu bảy tám chín mười",
        str(settings.font_regular),
        font_size=48,
        max_width=300,
        max_lines=2,
    )
    assert len(lines) == 2


def test_wrap_text_ellipsizes_the_last_line_when_it_overflows():
    lines = wrap_text(
        "một hai ba bốn năm sáu bảy tám chín mười",
        str(settings.font_regular),
        font_size=48,
        max_width=300,
        max_lines=2,
    )
    assert lines[-1].endswith("…")


def test_wrap_text_terminates_on_an_unbroken_token():
    lines = wrap_text(
        "awesome-selfhosted-awesome-selfhosted-awesome-selfhosted",
        str(settings.font_regular),
        font_size=48,
        max_width=300,
        max_lines=3,
    )
    assert 1 <= len(lines) <= 3
    assert all(line for line in lines)


def test_wrap_text_keeps_short_text_on_one_line():
    assert wrap_text(
        "Xin chào", str(settings.font_regular), font_size=48, max_width=600, max_lines=3
    ) == ["Xin chào"]


@pytest.mark.parametrize("quality", ["720p", "1080p"])
def test_slide_to_svg_declares_the_canvas_size(quality):
    width, height = CANVAS[quality]
    svg = slide_to_svg(
        HookSlide(title="Lộ trình của tôi", narration="xin chào"),
        index=0,
        total=5,
        size=(width, height),
    )
    assert f'width="{width}"' in svg
    assert f'height="{height}"' in svg
    assert svg.startswith("<svg")


def test_slide_to_svg_keeps_every_text_element_inside_the_safe_box():
    from app.services.layout import safe_insets
    width, height = CANVAS["720p"]
    svg = slide_to_svg(
        RepoSlide(
            full_name="awesome-selfhosted/awesome-selfhosted",
            description="A long description " * 15,
            language="Python",
            stars=128450,
            stars_gained=1240,
            narration="repo hôm nay",
        ),
        index=2,
        total=5,
        size=(width, height),
    )
    assert "128.450" in svg or "128,450" in svg
    
    insets = safe_insets((width, height))
    import re
    text_elements = re.findall(r'<text\b([^>]*?)>', svg)
    for text_attrs in text_elements:
        x_match = re.search(r'\bx="([0-9.]+)"', text_attrs)
        y_match = re.search(r'\by="([0-9.]+)"', text_attrs)
        if x_match:
            x_val = float(x_match.group(1))
            assert insets["left"] <= x_val <= width - insets["right"]
        if y_match:
            y_val = float(y_match.group(1))
            assert insets["top"] <= y_val <= height - insets["bottom"]


def test_render_slide_png_returns_a_png():
    png = render_slide_png(
        StatSlide(label="Repo đã lưu", value="12", narration="mười hai repo"),
        index=1,
        total=5,
        size=CANVAS["720p"],
    )
    assert png[:8] == b"\x89PNG\r\n\x1a\n"
