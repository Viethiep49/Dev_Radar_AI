import wave
from pathlib import Path

GAP_SECONDS = 0.35
MIN_SLIDE_SECONDS = 1.2

def slide_durations(audio_seconds: list[float]) -> list[float]:
    return [max(s + GAP_SECONDS, MIN_SLIDE_SECONDS) for s in audio_seconds]

def concat_wavs(entries: list[tuple[Path, float]], out_path: Path, gap_seconds: float) -> float:
    if not entries:
        return 0.0
        
    nchannels = None
    sampwidth = None
    framerate = None
    
    # Verify matches
    for wav_path, _ in entries:
        with wave.open(str(wav_path), 'rb') as w:
            if nchannels is None:
                nchannels = w.getnchannels()
                sampwidth = w.getsampwidth()
                framerate = w.getframerate()
            else:
                if w.getnchannels() != nchannels or w.getsampwidth() != sampwidth or w.getframerate() != framerate:
                    raise ValueError(f"Mismatched sample rates in {wav_path}")

    # Write
    total_frames = 0
    with wave.open(str(out_path), 'wb') as out_w:
        out_w.setnchannels(nchannels)
        out_w.setsampwidth(sampwidth)
        out_w.setframerate(framerate)
        
        gap_frames_count = int(framerate * gap_seconds)
        gap_bytes = b'\x00' * (gap_frames_count * nchannels * sampwidth)
        
        for i, (wav_path, _) in enumerate(entries):
            with wave.open(str(wav_path), 'rb') as in_w:
                data = in_w.readframes(in_w.getnframes())
                out_w.writeframes(data)
                total_frames += in_w.getnframes()
                
            if i < len(entries) - 1:
                out_w.writeframes(gap_bytes)
                total_frames += gap_frames_count
                
    return total_frames / framerate

def build_ffconcat(entries: list[tuple[Path, float]]) -> str:
    lines = ["ffconcat version 1.0"]
    for path, duration in entries:
        # Convert path to posix for ffconcat compatibility
        posix_path = path.as_posix()
        lines.append(f"file '{posix_path}'")
        lines.append(f"duration {duration}")
    if entries:
        last_path = entries[-1][0].as_posix()
        lines.append(f"file '{last_path}'")
    return "\n".join(lines)

def ffmpeg_args(concat_path: Path, audio_path: Path, out_path: Path, size: tuple[int, int], fps: int) -> list[str]:
    w, h = size
    return [
        "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", concat_path.as_posix(),
        "-i", audio_path.as_posix(),
        "-c:v", "libx264",
        "-preset", "veryfast",
        "-crf", "23",
        "-pix_fmt", "yuv420p",
        "-r", str(fps),
        "-s", f"{w}x{h}",
        "-c:a", "aac",
        "-b:a", "128k",
        "-ar", "44100",
        "-movflags", "+faststart",
        "-shortest",
        out_path.as_posix()
    ]
