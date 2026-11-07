import asyncio
from typing import Optional, List
from fastapi import FastAPI, Request, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .database import (
    init_db, get_tracks, get_track_by_id, search_tracks,
    toggle_favorite, get_favorites, get_playlists, get_total_tracks_count
)
from .telegram_sync import telegram_sync
from .streamer import stream_audio_file, stream_cover_art
from .models import StatusResponse, SyncResponse, Playlist, TrackResponse

app = FastAPI(
    title="Spotigram Music Backend",
    description="Spotify-like streaming backend powered directly by a Telegram Channel",
    version="1.0.0"
)

# Enable CORS for Flutter mobile, desktop, and web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.CORS_ORIGINS == "*" else settings.CORS_ORIGINS.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    init_db()
    # Trigger initial channel sync in background if configured
    if settings.BOT_TOKEN and settings.CHANNEL_ID:
        asyncio.create_task(telegram_sync.sync_channel_updates())

def enrich_track(track: dict, request: Request) -> dict:
    base_url = str(request.base_url).rstrip("/")
    track_id = track["id"]
    return {
        **track,
        "stream_url": f"{base_url}/api/stream/{track_id}",
        "cover_url": f"{base_url}/api/cover/{track_id}" if track.get("has_cover") else None
    }

@app.get("/")
def root():
    return {
        "service": "Spotigram API",
        "status": "online",
        "docs": "/docs"
    }

@app.get("/api/status", response_model=StatusResponse)
async def get_status():
    bot_info = await telegram_sync.get_me()
    chat_info = await telegram_sync.get_chat_info()
    return StatusResponse(
        status="healthy",
        channel_id=settings.CHANNEL_ID,
        total_tracks=get_total_tracks_count(),
        bot_connected=bot_info is not None,
        channel_title=chat_info.get("title") if chat_info else None
    )

@app.get("/api/tracks")
def list_tracks(
    request: Request,
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    tag: Optional[str] = None
):
    tracks = get_tracks(limit=limit, offset=offset, tag=tag)
    return [enrich_track(t, request) for t in tracks]

@app.get("/api/search")
def search(
    request: Request,
    q: str = Query(..., min_length=1),
    limit: int = Query(30, ge=1, le=50)
):
    tracks = search_tracks(query_str=q, limit=limit)
    return [enrich_track(t, request) for t in tracks]

@app.get("/api/favorites")
def list_favorites(
    request: Request,
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200)
):
    tracks = get_favorites(limit=limit, offset=offset)
    return [enrich_track(t, request) for t in tracks]

@app.post("/api/tracks/{track_id}/favorite")
def api_toggle_favorite(track_id: str):
    is_fav = toggle_favorite(track_id)
    return {"track_id": track_id, "is_favorite": is_fav}

@app.get("/api/playlists", response_model=List[Playlist])
def list_playlists():
    return get_playlists()

@app.post("/api/sync", response_model=SyncResponse)
async def trigger_sync():
    result = await telegram_sync.sync_channel_updates()
    return SyncResponse(
        status=result.get("status", "ok"),
        new_tracks_count=result.get("new_tracks", 0),
        total_tracks=result.get("total_tracks", get_total_tracks_count()),
        message=result.get("message", "Sync completed")
    )

@app.get("/api/stream/{track_id}")
async def stream_track(track_id: str, request: Request):
    return await stream_audio_file(track_id, request)

@app.get("/api/cover/{track_id}")
async def cover_art(track_id: str):
    return await stream_cover_art(track_id)

@app.post("/api/webhook")
async def telegram_webhook(request: Request):
    try:
        body = await request.json()
        msg = body.get("channel_post") or body.get("message")
        if msg:
            telegram_sync.process_message(msg)
        return {"ok": True}
    except Exception as e:
        return {"ok": False, "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
