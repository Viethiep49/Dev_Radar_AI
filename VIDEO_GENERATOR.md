# AI Video Generator: Implementation Guide for Backend & Frontend

The `video-engine` service is now implemented and exposes a REST API for generating videos synchronously. This document outlines the required integration steps for both the Backend and Frontend teams.

## 1. Backend Integration

The `video-engine` is exposed locally within the docker-compose network at `http://video-engine:9000`.

### 1.1 Triggering Video Generation

To generate a video, send a `POST` request to `http://video-engine:9000/render` with a `VideoSpec` JSON payload.

**Example Request:**
```json
{
  "job_id": "user_123_roadmap_2026_10",
  "title": "Lộ trình của tôi",
  "quality": "720p",
  "slides": [
    {
      "kind": "hook",
      "title": "Lộ trình của tôi",
      "narration": "Xin chào, đây là lộ trình học tập của bạn",
      "subtitle": "Cập nhật tháng 10"
    },
    {
      "kind": "repo",
      "full_name": "awesome-selfhosted/awesome-selfhosted",
      "description": "A list of Free Software network services and web applications.",
      "language": "Python",
      "stars": 128450,
      "stars_gained": 1240,
      "narration": "Repo đáng chú ý hôm nay là awesome selfhosted"
    }
  ]
}
```

**Example Response (`200 OK`):**
```json
{
  "path": "/data/videos/user_123_roadmap_2026_10.mp4",
  "duration_seconds": 15.3,
  "size_bytes": 1048576
}
```

### 1.2 Storage and Delivery

1. **Shared Volume:** The `video-engine` writes the output MP4 to `/data/videos` (as defined by `OUTPUT_DIR`). Ensure the Backend service mounts this same volume to access the generated file.
2. **Long Request Timeout:** Video generation can take several seconds to a few minutes depending on slide count. Ensure the HTTP client configured to call `video-engine` has a sufficiently high timeout (e.g., 5 minutes).
3. **Cloud Upload:** Once the Backend receives the `RenderResult`, it should read the file from the shared volume (`path`) and upload it to an S3-compatible cloud storage or serve it directly via a CDN.
4. **Database:** Save the `duration_seconds`, `size_bytes`, and the CDN URL into the user's video records in the PostgreSQL database.

---

## 2. Frontend Integration

The generated video is intended to be shared natively on the user's device via the system share sheet, *not* automatically uploaded to platforms like TikTok.

### 2.1 Video Playback UI

- Implement a Video Player component to preview the generated "Lộ trình của tôi" (My Roadmap) or "Repo of the Day" videos.
- Display metadata provided by the backend (duration, creation date).

### 2.2 System Share Sheet Integration

Use the [Web Share API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Share_API) to trigger the native share sheet (e.g., on iOS/Android).

```javascript
async function shareVideo(videoUrl, title) {
  if (navigator.share) {
    try {
      await navigator.share({
        title: title,
        text: 'Check out my Dev Radar update!',
        url: videoUrl,
      });
      console.log('Video shared successfully');
    } catch (error) {
      console.error('Error sharing the video:', error);
    }
  } else {
    // Fallback for desktop browsers: provide a direct download link
    const a = document.createElement('a');
    a.href = videoUrl;
    a.download = 'dev-radar-video.mp4';
    a.click();
  }
}
```

### 2.3 User Experience Flow

1. **Generate Button:** Provide a button to trigger video generation. Show a loading state (spinner/progress) since the backend generation process is synchronous and takes time.
2. **Preview:** Once generated, transition the user to a preview screen where they can watch the video.
3. **Share:** Provide a prominent "Share" button to invoke `navigator.share()`.
