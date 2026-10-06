import sys
import subprocess
from pathlib import Path

from app.core.config import settings
from app.schemas.spec import Slide
from app.services.numbers import spell_text

class TTSClient:
    def synthesize_slide(self, slide: Slide, out_dir: Path) -> Path:
        text = spell_text(slide.narration)
        # We need a stable but unique path per slide in the batch.
        # id(slide) is fast and unique per process execution.
        out_path = out_dir / f"{id(slide)}.wav"
        
        args = [
            sys.executable, "-m", "piper",
            "--data-dir", str(settings.models_dir),
            "-m", "vi_VN-vais1000-medium",
            "-f", str(out_path),
            "--", text
        ]
        
        subprocess.run(args, check=True)
        return out_path
