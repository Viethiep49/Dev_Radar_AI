"""Build a video-engine VideoSpec payload from a user's learning roadmap.

Pure: no DB session, no HTTP. Every field the engine bounds is clipped here,
because the engine answers 422 (which we surface as a 502) otherwise.
"""

from collections import Counter
import re

from app.core.errors import AppError, ErrorCode
from app.models import UserRepo

FULL_NAME_PATTERN = re.compile(r"^[^/\s]+/[^/\s]+$")

TITLE_LIMIT = 80
NARRATION_LIMIT = 300
SUBTITLE_LIMIT = 90
DESCRIPTION_LIMIT = 300
FULL_NAME_LIMIT = 120
MAX_LIST_ITEMS = 3


def _clip(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[:limit]


def _is_renderable(row: UserRepo) -> bool:
    full_name = row.repo.full_name or ""
    return bool(FULL_NAME_PATTERN.match(_clip(full_name, FULL_NAME_LIMIT)))


def _count(rows: list[UserRepo], status: str) -> int:
    return sum(1 for row in rows if row.status == status)


def _top_languages(rows: list[UserRepo]) -> list[str]:
    counts = Counter(row.repo.language for row in rows if row.repo.language)
    return [language for language, _ in counts.most_common(MAX_LIST_ITEMS)]


def _stat_slide(narration: str, label: str, value: str, unit: str) -> dict:
    return {
        "kind": "stat",
        "label": label,
        "value": str(value),
        "unit": unit,
        "narration": _clip(narration, NARRATION_LIMIT),
    }


def build_roadmap_spec(job_id: str, display_name: str, rows: list[UserRepo]) -> dict:
    """-> a dict matching video-engine's VideoSpec. Raises AppError(400) if empty."""
    renderable = [row for row in rows if _is_renderable(row)]
    if not renderable:
        raise AppError(
            400, ErrorCode.BAD_REQUEST, "Lộ trình còn trống, chưa thể tạo video"
        )

    name = _clip(display_name, SUBTITLE_LIMIT)
    learning = _count(renderable, "learning")
    used = _count(renderable, "used")

    slides: list[dict] = [
        {
            "kind": "hook",
            "title": _clip(f"Lộ trình của {name}", 60),
            "subtitle": _clip("Tổng kết hành trình học tập", SUBTITLE_LIMIT),
            "narration": _clip(
                f"Xin chào {name}. Đây là tổng kết lộ trình học tập của bạn trên Dev Radar.",
                NARRATION_LIMIT,
            ),
        },
        _stat_slide(f"Bạn đang học {learning} repository.", "Đang học", learning, "repo"),
        _stat_slide(f"Bạn đã dùng {used} repository.", "Đã dùng", used, "repo"),
    ]

    items = _top_languages(renderable)
    if len(items) < 2:
        items = [_clip(row.repo.full_name, FULL_NAME_LIMIT) for row in renderable[:MAX_LIST_ITEMS]]
    if len(items) >= 2:
        slides.append(
            {
                "kind": "list",
                "title": "Ngôn ngữ hàng đầu",
                "items": items,
                "narration": _clip(
                    "Bạn quan tâm nhiều nhất tới: " + ", ".join(items) + ".",
                    NARRATION_LIMIT,
                ),
            }
        )

    top = max(renderable, key=lambda row: row.repo.stars or 0)
    full_name = _clip(top.repo.full_name, FULL_NAME_LIMIT)
    description = top.repo.description
    slides.append(
        {
            "kind": "repo",
            "full_name": full_name,
            "description": _clip(description, DESCRIPTION_LIMIT) if description else None,
            "language": _clip(top.repo.language, 40) if top.repo.language else None,
            "stars": top.repo.stars or 0,
            "narration": _clip(
                f"Nổi bật nhất là {full_name}, với {top.repo.stars or 0} sao trên GitHub.",
                NARRATION_LIMIT,
            ),
        }
    )

    slides.append(
        {
            "kind": "outro",
            "title": "Tiếp tục cố lên!",
            "subtitle": name,
            "narration": _clip(
                f"Cảm ơn {name} đã đồng hành cùng Dev Radar. Hẹn gặp lại ở video tiếp theo!",
                NARRATION_LIMIT,
            ),
        }
    )

    return {
        "job_id": job_id,
        "title": _clip(f"Lộ trình học tập của {name}", TITLE_LIMIT),
        "quality": "720p",
        "slides": slides,
    }
