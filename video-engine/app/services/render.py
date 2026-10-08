import os
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

from app.core.config import settings
from app.schemas.spec import VideoSpec, RenderResult
from app.services.layout import render_slide_png, CANVAS
from app.services.tts import synthesize, wav_duration
from app.services.timeline import slide_durations, concat_wavs, ffmpeg_args, GAP_SECONDS

def render_job(spec: VideoSpec, out_dir: Path) -> RenderResult:
    size = CANVAS[spec.quality]

    # Scratch inside out_dir: os.replace below is rename(2) and fails with EXDEV
    # when /tmp and the output volume are different mounts (always true in Docker).
    with TemporaryDirectory(dir=out_dir) as tmp_str:
        tmp = Path(tmp_str)
        
        audio_paths = []
        raw_audio_seconds = []
        for slide in spec.slides:
            audio_path = synthesize(slide.narration, settings.voice, settings.cache_dir)
            audio_paths.append(audio_path)
            raw_audio_seconds.append(wav_duration(audio_path))
            
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
        
        tmp_mp4 = tmp / "out.mp4"
        
        args = ffmpeg_args(ffconcat_entries, concat_audio_path, tmp_mp4, size, settings.fps)
        args.insert(0, settings.ffmpeg_bin)
        
        subprocess.run(args, check=True)
        
        out_mp4 = out_dir / f"{spec.job_id}.mp4"
        os.replace(tmp_mp4, out_mp4)
        
        return RenderResult(
            path=str(out_mp4),
            duration_seconds=total_duration,
            size_bytes=out_mp4.stat().st_size
        )
