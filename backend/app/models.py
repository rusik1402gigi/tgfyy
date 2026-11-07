from typing import Optional, List
from pydantic import BaseModel

class TrackBase(BaseModel):
    id: str
    file_id: str
    message_id: int
    title: str
    artist: str
    duration: int
    file_size: int
    mime_type: str
    has_cover: bool
    cover_file_id: Optional[str] = None
    tags: List[str] = []
    date_added: int
    is_favorite: bool = False

class TrackResponse(TrackBase):
    stream_url: str
    cover_url: Optional[str] = None

class Playlist(BaseModel):
    id: str
    title: str
    subtitle: str
    track_count: int
    cover_url: Optional[str] = None
    tag: Optional[str] = None

class StatusResponse(BaseModel):
    status: str
    channel_id: str
    total_tracks: int
    bot_connected: bool
    channel_title: Optional[str] = None

class SyncResponse(BaseModel):
    status: str
    new_tracks_count: int
    total_tracks: int
    message: str
