"""Build a video-engine VideoSpec payload from a user's learning roadmap.

Pure: no DB session, no HTTP. Every field the engine bounds is clipped here,
because the engine answers 422 (which we surface as a 502) otherwise.
"""

from collections import Counter
import re

from app.core.errors import AppError, ErrorCode
from app.models import Repo, UserRepo

FULL_NAME_PATTERN = re.compile(r"^[^/\s]+/[^/\s]+$")

TITLE_LIMIT = 80
NARRATION_LIMIT = 300
SUBTITLE_LIMIT = 90
DESCRIPTION_LIMIT = 300
FULL_NAME_LIMIT = 120
MAX_LIST_ITEMS = 3


def _clip(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[:limit]


def normalize_narration(text: str) -> str:
    """Normalizes English brand names to phonetic Vietnamese for Piper TTS."""
    text = re.sub(r"\bdev[\s_-]*radar[\s_-]*ai\b", "đép ra đa ây ai", text, flags=re.IGNORECASE)
    text = re.sub(r"\bdev[\s_-]*radar\b", "đép ra đa ây ai", text, flags=re.IGNORECASE)
    return text


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
        "narration": _clip(normalize_narration(narration), NARRATION_LIMIT),
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
                normalize_narration(
                    f"Xin chào {name}. Đây là tổng kết lộ trình học tập của bạn trên Dev Radar AI."
                ),
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
                normalize_narration(
                    f"Cảm ơn {name} đã đồng hành cùng Dev Radar AI. Hẹn gặp lại ở video tiếp theo!"
                ),
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


def build_repo_video_spec(
    job_id: str,
    repo: Repo,
    summary_text: str | None = None,
    quickstart_text: str | None = None,
) -> dict:
    """Build a detailed analysis video spec for a specific repository."""
    full_name = _clip(repo.full_name or "repo/name", FULL_NAME_LIMIT)
    if not FULL_NAME_PATTERN.match(full_name):
        full_name = "developer/project"

    name = repo.name or full_name.split("/")[-1]
    stars = repo.stars or 0
    forks = repo.forks or 0
    lang = repo.language or "Công nghệ"

    # Slide 1: Hook - Giới thiệu & Vấn đề giải quyết
    intro_problem = (
        _clip(summary_text, 140)
        if summary_text and summary_text != "Chưa có mô tả."
        else (repo.description or f"Dự án {lang} mạnh mẽ cho lập trình viên.")
    )
    hook_narration = _clip(
        normalize_narration(
            f"Chào mừng bạn đến với Dev Radar AI. Hôm nay chúng ta cùng phân tích repository {name}. "
            f"Dự án này giải quyết bài toán: {intro_problem}"
        ),
        NARRATION_LIMIT,
    )

    # Slide 2: Repo Overview - Repo làm được gì & Điểm khác biệt công nghệ cũ
    repo_narration = _clip(
        normalize_narration(
            f"{name} làm được những gì? Đây là giải pháp đột phá giúp tối ưu hiệu năng và quy trình phát triển, "
            f"khắc phục nhiều hạn chế cố hữu của các công nghệ cũ nhờ thiết kế hiện đại và linh hoạt."
        ),
        NARRATION_LIMIT,
    )

    # Slide 3: Stat - Độ uy tín & Đánh giá cộng đồng
    stat_narration = _clip(
        normalize_narration(
            f"Về độ uy tín, dự án hiện đạt {stars:,} sao trên GitHub cùng {forks:,} lượt fork, "
            f"khẳng định chất lượng và độ tin cậy từ cộng đồng mã nguồn mở quốc tế."
        ),
        NARRATION_LIMIT,
    )

    # Slide 4: List - Cách người dùng tương tác & Tính năng nổi bật
    topics = [t.capitalize() for t in (repo.topics or []) if t]
    if len(topics) >= 2:
        features = [_clip(t, 35) for t in topics[:3]]
    else:
        features = ["Tích hợp mã nguồn mở", "Hiệu năng tối ưu", "Cộng đồng hỗ trợ mạnh"]
    if len(features) < 2:
        features.append("Kiến trúc hiện đại")
    features = features[:4]

    feature_narration = _clip(
        normalize_narration(
            f"Người dùng có thể tương tác và khai thác {name} thông qua các tính năng cốt lõi: {', '.join(features)}."
        ),
        NARRATION_LIMIT,
    )

    # Slide 5: List - Hướng dẫn cài đặt
    lang_lower = (repo.language or "").lower()
    if "python" in lang_lower:
        install_items = [f"pip install {name.lower()}", "import thư viện", "Khởi chạy ứng dụng"]
    elif "dart" in lang_lower or "flutter" in lang_lower:
        install_items = [f"flutter pub add {name.lower()}", "import package", "Khởi chạy dự án"]
    elif "javascript" in lang_lower or "typescript" in lang_lower or "node" in lang_lower:
        install_items = [f"npm install {name.lower()}", "Cấu hình module", "Chạy thử nghiệm"]
    elif "go" in lang_lower:
        install_items = [f"go get {full_name}", "import package", "Build chương trình"]
    else:
        install_items = [f"git clone {name}", "Cài đặt dependencies", "Chạy theo README"]

    install_narration = _clip(
        normalize_narration(
            f"Để cài đặt {name}, bạn có thể sử dụng trình quản lý gói hoặc tải mã nguồn từ GitHub theo các bước cơ bản sau."
        ),
        NARRATION_LIMIT,
    )

    # Slide 6: Outro - Đánh giá tổng kết & Lời khuyên
    outro_narration = _clip(
        normalize_narration(
            f"Tổng kết lại, {name} là một công cụ rất đáng trải nghiệm. "
            f"Hãy lưu ngay vào bộ sưu tập hoặc lộ trình học tập của bạn trên Dev Radar AI!"
        ),
        NARRATION_LIMIT,
    )

    slides = [
        {
            "kind": "hook",
            "title": _clip(f"Phân tích {name}", 60),
            "subtitle": _clip(full_name, SUBTITLE_LIMIT),
            "narration": hook_narration,
        },
        {
            "kind": "repo",
            "full_name": full_name,
            "description": _clip(repo.description, DESCRIPTION_LIMIT) if repo.description else "Dự án mã nguồn mở.",
            "language": _clip(repo.language, 40) if repo.language else None,
            "stars": stars,
            "narration": repo_narration,
        },
        {
            "kind": "stat",
            "label": "Độ uy tín cộng đồng",
            "value": str(stars if stars <= 999999999 else 999999999),
            "unit": "sao GitHub",
            "narration": stat_narration,
        },
        {
            "kind": "list",
            "title": "Tính năng & Cách sử dụng",
            "items": features,
            "narration": feature_narration,
        },
        {
            "kind": "list",
            "title": "Hướng dẫn cài đặt nhanh",
            "items": install_items,
            "narration": install_narration,
        },
        {
            "kind": "outro",
            "title": "Khám phá trên Dev Radar AI",
            "subtitle": _clip(full_name, SUBTITLE_LIMIT),
            "narration": outro_narration,
        },
    ]

    return {
        "job_id": job_id,
        "title": _clip(f"Phân tích {name}", TITLE_LIMIT),
        "quality": "720p",
        "slides": slides,
    }
