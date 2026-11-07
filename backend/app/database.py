import sqlite3
import json
import os
from typing import List, Optional, Dict, Any
from .config import settings

def get_db_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(settings.DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS tracks (
            id TEXT PRIMARY KEY,
            file_id TEXT NOT NULL,
            message_id INTEGER NOT NULL UNIQUE,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            duration INTEGER DEFAULT 0,
            file_size INTEGER DEFAULT 0,
            mime_type TEXT DEFAULT 'audio/mpeg',
            has_cover INTEGER DEFAULT 0,
            cover_file_id TEXT,
            tags TEXT DEFAULT '[]',
            date_added INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS favorites (
            track_id TEXT PRIMARY KEY,
            added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
        );
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT
        );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(artist);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tracks_title ON tracks(title);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tracks_date ON tracks(date_added DESC);")
    conn.commit()
    conn.close()

def upsert_track(
    track_id: str,
    file_id: str,
    message_id: int,
    title: str,
    artist: str,
    duration: int,
    file_size: int,
    mime_type: str,
    has_cover: bool,
    cover_file_id: Optional[str],
    tags: List[str],
    date_added: int
) -> bool:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO tracks (id, file_id, message_id, title, artist, duration, file_size, mime_type, has_cover, cover_file_id, tags, date_added)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                file_id=excluded.file_id,
                title=excluded.title,
                artist=excluded.artist,
                duration=excluded.duration,
                file_size=excluded.file_size,
                mime_type=excluded.mime_type,
                has_cover=excluded.has_cover,
                cover_file_id=excluded.cover_file_id,
                tags=excluded.tags,
                date_added=excluded.date_added
        """, (
            track_id, file_id, message_id, title, artist, duration,
            file_size, mime_type, 1 if has_cover else 0, cover_file_id,
            json.dumps(tags, ensure_ascii=False), date_added
        ))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error upserting track {track_id}: {e}")
        return False
    finally:
        conn.close()

def row_to_track_dict(row: sqlite3.Row) -> Dict[str, Any]:
    return {
        "id": row["id"],
        "file_id": row["file_id"],
        "message_id": row["message_id"],
        "title": row["title"],
        "artist": row["artist"],
        "duration": row["duration"],
        "file_size": row["file_size"],
        "mime_type": row["mime_type"],
        "has_cover": bool(row["has_cover"]),
        "cover_file_id": row["cover_file_id"],
        "tags": json.loads(row["tags"]) if row["tags"] else [],
        "date_added": row["date_added"],
        "is_favorite": bool(row["is_favorite"]) if "is_favorite" in row.keys() else False
    }

def get_tracks(limit: int = 50, offset: int = 0, tag: Optional[str] = None) -> List[Dict[str, Any]]:
    conn = get_db_connection()
    cursor = conn.cursor()
    query = """
        SELECT t.*, CASE WHEN f.track_id IS NOT NULL THEN 1 ELSE 0 END AS is_favorite
        FROM tracks t
        LEFT JOIN favorites f ON t.id = f.track_id
    """
    params = []
    if tag:
        query += " WHERE t.tags LIKE ? "
        params.append(f'%"{tag}"%')
    query += " ORDER BY t.date_added DESC, t.id DESC LIMIT ? OFFSET ?"
    params.extend([limit, offset])
    cursor.execute(query, params)
    rows = cursor.fetchall()
    conn.close()
    return [row_to_track_dict(r) for r in rows]

def get_track_by_id(track_id: str) -> Optional[Dict[str, Any]]:
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT t.*, CASE WHEN f.track_id IS NOT NULL THEN 1 ELSE 0 END AS is_favorite
        FROM tracks t
        LEFT JOIN favorites f ON t.id = f.track_id
        WHERE t.id = ?
    """, (track_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return row_to_track_dict(row)
    return None

def search_tracks(query_str: str, limit: int = 30) -> List[Dict[str, Any]]:
    conn = get_db_connection()
    cursor = conn.cursor()
    pattern = f"%{query_str.strip()}%"
    cursor.execute("""
        SELECT t.*, CASE WHEN f.track_id IS NOT NULL THEN 1 ELSE 0 END AS is_favorite
        FROM tracks t
        LEFT JOIN favorites f ON t.id = f.track_id
        WHERE t.title LIKE ? OR t.artist LIKE ? OR t.tags LIKE ?
        ORDER BY t.date_added DESC LIMIT ?
    """, (pattern, pattern, pattern, limit))
    rows = cursor.fetchall()
    conn.close()
    return [row_to_track_dict(r) for r in rows]

def toggle_favorite(track_id: str) -> bool:
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT track_id FROM favorites WHERE track_id = ?", (track_id,))
    exists = cursor.fetchone()
    if exists:
        cursor.execute("DELETE FROM favorites WHERE track_id = ?", (track_id,))
        is_fav = False
    else:
        cursor.execute("INSERT INTO favorites (track_id) VALUES (?)", (track_id,))
        is_fav = True
    conn.commit()
    conn.close()
    return is_fav

def get_favorites(limit: int = 100, offset: int = 0) -> List[Dict[str, Any]]:
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT t.*, 1 AS is_favorite
        FROM tracks t
        INNER JOIN favorites f ON t.id = f.track_id
        ORDER BY f.added_at DESC LIMIT ? OFFSET ?
    """, (limit, offset))
    rows = cursor.fetchall()
    conn.close()
    return [row_to_track_dict(r) for r in rows]

def get_total_tracks_count() -> int:
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM tracks")
    count = cursor.fetchone()[0]
    conn.close()
    return count

def get_playlists() -> List[Dict[str, Any]]:
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Favorites playlist
    cursor.execute("SELECT COUNT(*) FROM favorites")
    fav_count = cursor.fetchone()[0]
    
    # 2. Total count for "All Tracks"
    cursor.execute("SELECT COUNT(*) FROM tracks")
    total_count = cursor.fetchone()[0]
    
    # 3. Discover tag-based playlists from captions
    cursor.execute("SELECT tags FROM tracks WHERE tags != '[]' AND tags IS NOT NULL")
    tag_rows = cursor.fetchall()
    conn.close()
    
    playlists = [
        {
            "id": "favorites",
            "title": "Любимые треки",
            "subtitle": f"{fav_count} треков",
            "track_count": fav_count,
            "tag": None,
            "is_system": True
        },
        {
            "id": "recently_added",
            "title": "Все треки из канала",
            "subtitle": f"{total_count} треков",
            "track_count": total_count,
            "tag": None,
            "is_system": True
        }
    ]
    
    # Aggregate tags
    tag_counts: Dict[str, int] = {}
    for r in tag_rows:
        try:
            t_list = json.loads(r[0])
            for t in t_list:
                clean_t = t.strip("#").strip()
                if clean_t:
                    tag_counts[clean_t] = tag_counts.get(clean_t, 0) + 1
        except Exception:
            pass
            
    for tag_name, count in sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
        playlists.append({
            "id": f"tag_{tag_name}",
            "title": f"#{tag_name}",
            "subtitle": f"{count} треков",
            "track_count": count,
            "tag": tag_name,
            "is_system": False
        })
        
    return playlists

def get_sync_meta(key: str, default: Optional[str] = None) -> Optional[str]:
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT value FROM sync_meta WHERE key = ?", (key,))
    row = cursor.fetchone()
    conn.close()
    return row[0] if row else default

def set_sync_meta(key: str, value: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO sync_meta (key, value) VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value=excluded.value
    """, (key, value))
    conn.commit()
    conn.close()
