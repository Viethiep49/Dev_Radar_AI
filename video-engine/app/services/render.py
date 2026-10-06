import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory
import wave

from app.core.config import settings
from app.schemas.spec import VideoSpec, RenderResult
from app.services.layout import render_slide_png, CANVAS
from app.services.tts import TTSClient
from app.services.timeline import slide_durations, concat_wavs, build_ffconcat, ffmpeg_args, GAP_SECONDS

def render_job(spec: VideoSpec, out_dir: Path) -> RenderResult:
    size = CANVAS[spec.quality]
    tts_client = TTSClient()
    
    with TemporaryDirectory() as tmp_str:
        tmp = Path(tmp_str)
        
        audio_paths = []
        for slide in spec.slides:
            audio_path = tts_client.synthesize_slide(slide, tmp)
            audio_paths.append(audio_path)
            
        raw_audio_seconds = []
        for path in audio_paths:
            with wave.open(str(path), 'rb') as w:
                raw_audio_seconds.append(w.getnframes() / w.getframerate())
                
        durations = slide_durations(raw_audio_seconds)
        
        entries = []
        ffconcat_entries = []
        
        for i, slide in enumerate(spec.slides):
            png_bytes = render_slide_png(slide, i, len(spec.slides), size)
            png_path = tmp / f"slide_{i}.png"
            png_path.write_bytes(png_bytes)
            
            entries.append((audio_paths[i], raw_audio_seconds[i]))
            ffconcat_entries.append((png_path, durations[i]))
            
        concat_audio_path = tmp / "joined.wav"
        total_duration = concat_wavs(entries, concat_audio_path, gap_seconds=GAP_SECONDS)
        
        ffconcat_path = tmp / "slides.ffconcat"
        ffconcat_path.write_text(build_ffconcat(ffconcat_entries), encoding="utf-8")
        
        out_mp4 = out_dir / f"{spec.job_id}.mp4"
        
        args = ffmpeg_args(ffconcat_path, concat_audio_path, out_mp4, size, settings.fps)
        args.insert(0, settings.ffmpeg_bin)
        
        subprocess.run(args, check=True)
        
        return RenderResult(
            path=str(out_mp4),
            duration_seconds=total_duration,
            size_bytes=out_mp4.stat().st_size
        )
