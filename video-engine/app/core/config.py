from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    output_dir: Path = Path('/data/videos')
    cache_dir: Path = Path('/data/cache')
    models_dir: Path = Path('/app/models')
    voice: str = 'vi_VN-vais1000-medium'
    font_regular: Path = Path('/usr/share/fonts/truetype/bevietnampro/BeVietnamPro-Regular.ttf')
    font_bold: Path = Path('/usr/share/fonts/truetype/bevietnampro/BeVietnamPro-Bold.ttf')
    fps: int = 30
    piper_bin: str = 'piper'
    ffmpeg_bin: str = 'ffmpeg'
    model_config = SettingsConfigDict(env_file='.env', extra='ignore')

settings = Settings()
