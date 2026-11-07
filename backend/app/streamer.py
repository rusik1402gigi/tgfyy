import time
import httpx
from typing import Dict, Tuple, Optional
from fastapi import Request, Response
from fastapi.responses import StreamingResponse
from .config import settings
from .database import get_track_by_id

# In-memory cache for telegram file paths: file_id -> (file_path, expire_timestamp)
_file_path_cache: Dict[str, Tuple[str, float]] = {}
CACHE_TTL = 40 * 60  # 40 minutes

async def get_telegram_file_path(file_id: str) -> Optional[str]:
    now = time.time()
    if file_id in _file_path_cache:
        path, expire_at = _file_path_cache[file_id]
        if now < expire_at:
            return path

    url = f"{settings.TELEGRAM_API_URL}/bot{settings.BOT_TOKEN}/getFile"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(url, params={"file_id": file_id})
            data = res.json()
            if data.get("ok"):
                file_path = data["result"].get("file_path")
                if file_path:
                    _file_path_cache[file_id] = (file_path, now + CACHE_TTL)
                    return file_path
    except Exception as e:
        print(f"[Streamer] getFile error for {file_id}: {e}")
    return None

async def stream_audio_file(track_id: str, request: Request) -> Response:
    track = get_track_by_id(track_id)
    if not track:
        return Response(content="Track not found", status_code=404)

    file_id = track["file_id"]
    file_path = await get_telegram_file_path(file_id)
    if not file_path:
        return Response(content="Unable to resolve audio file from Telegram", status_code=502)

    telegram_file_url = f"{settings.TELEGRAM_API_URL}/file/bot{settings.BOT_TOKEN}/{file_path}"
    range_header = request.headers.get("range")

    headers_to_forward = {}
    if range_header:
        headers_to_forward["Range"] = range_header

    client = httpx.AsyncClient(timeout=60.0)
    try:
        req = client.build_request("GET", telegram_file_url, headers=headers_to_forward)
        tg_res = await client.send(req, stream=True)

        status_code = tg_res.status_code
        response_headers = {
            "Accept-Ranges": "bytes",
            "Content-Type": track.get("mime_type") or tg_res.headers.get("content-type", "audio/mpeg"),
            "Cache-Control": "public, max-age=3600",
        }

        if "content-range" in tg_res.headers:
            response_headers["Content-Range"] = tg_res.headers["content-range"]
        if "content-length" in tg_res.headers:
            response_headers["Content-Length"] = tg_res.headers["content-length"]

        async def stream_generator():
            try:
                async for chunk in tg_res.aiter_bytes(chunk_size=64 * 1024):
                    yield chunk
            finally:
                await tg_res.aclose()
                await client.aclose()

        return StreamingResponse(
            stream_generator(),
            status_code=status_code,
            headers=response_headers,
            media_type=response_headers["Content-Type"]
        )

    except Exception as e:
        await client.aclose()
        return Response(content=f"Streaming error: {e}", status_code=500)

async def stream_cover_art(track_id: str) -> Response:
    track = get_track_by_id(track_id)
    if not track or not track.get("cover_file_id"):
        # Return standard 1x1 or SVG placeholder for album cover
        svg_cover = """<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300">
            <rect width="300" height="300" fill="#282828"/>
            <circle cx="150" cy="150" r="70" fill="#181818"/>
            <path d="M135 115v70l50-35z" fill="#1DB954"/>
        </svg>"""
        return Response(content=svg_cover, media_type="image/svg+xml")

    cover_file_id = track["cover_file_id"]
    file_path = await get_telegram_file_path(cover_file_id)
    if not file_path:
        return Response(status_code=404)

    telegram_cover_url = f"{settings.TELEGRAM_API_URL}/file/bot{settings.BOT_TOKEN}/{file_path}"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(telegram_cover_url)
            return Response(
                content=res.content,
                media_type=res.headers.get("content-type", "image/jpeg"),
                headers={"Cache-Control": "public, max-age=86400"}
            )
    except Exception:
        return Response(status_code=502)
