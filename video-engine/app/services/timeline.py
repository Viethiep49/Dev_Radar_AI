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
    
    for wav_path, _ in entries:
        with wave.open(str(wav_path), 'rb') as w:
            if nchannels is None:
                nchannels = w.getnchannels()
                sampwidth = w.getsampwidth()
                framerate = w.getframerate()
            else:
                if w.getnchannels() != nchannels or w.getsampwidth() != sampwidth or w.getframerate() != framerate:
                    raise ValueError(f"Mismatched sample rates in {wav_path}")

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

def ffmpeg_args(entries: list[tuple[Path, float]], audio_path: Path, out_path: Path, size: tuple[int, int], fps: int) -> list[str]:
    w, h = size
    
    args = ["-y"]
    
    for img_path, _ in entries:
        args.extend(["-i", img_path.as_posix()])
        
    args.extend(["-i", audio_path.as_posix()])
    
    filter_chains = []
    concat_inputs = ""
    for i, (_, duration) in enumerate(entries):
        frames = int(duration * fps)
        # Slow zoom in: z='1.0+on*0.0005'
        zoom_expr = "1.0+on*0.0005"
        x_expr = "iw/2-(iw/zoom)/2"
        y_expr = "ih/2-(ih/zoom)/2"
        
        chain = f"[{i}:v]scale={w}:{h},zoompan=z='{zoom_expr}':d={frames}:s={w}x{h}:fps={fps}:x='{x_expr}':y='{y_expr}'[v{i}]"
        filter_chains.append(chain)
        concat_inputs += f"[v{i}]"
        
    concat_filter = f"{concat_inputs}concat=n={len(entries)}:v=1:a=0[outv]"
    filter_chains.append(concat_filter)
    
    filter_complex = ";".join(filter_chains)
    
    args.extend([
        "-filter_complex", filter_complex,
        "-map", "[outv]",
        "-map", f"{len(entries)}:a",
        "-c:v", "libx264",
        "-preset", "veryfast",
        "-crf", "23",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "128k",
        "-movflags", "+faststart",
        "-shortest",
        out_path.as_posix()
    ])
    return args
