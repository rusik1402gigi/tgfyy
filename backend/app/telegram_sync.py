import asyncio
import re
import httpx
from typing import Dict, Any, List, Optional
from .config import settings
from .database import upsert_track, get_sync_meta, set_sync_meta, get_total_tracks_count

HASHTAG_REGEX = re.compile(r"#(\w+)")

class TelegramSyncService:
    def __init__(self):
        self.bot_token = settings.BOT_TOKEN
        self.channel_id = settings.CHANNEL_ID
        self.base_url = f"{settings.TELEGRAM_API_URL}/bot{self.bot_token}"
        self.file_url = f"{settings.TELEGRAM_API_URL}/file/bot{self.bot_token}"

    async def get_me(self) -> Optional[Dict[str, Any]]:
        if not self.bot_token:
            return None
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(f"{self.base_url}/getMe")
                data = res.json()
                if data.get("ok"):
                    return data.get("result")
        except Exception as e:
            print(f"[TelegramSync] getMe failed: {e}")
        return None

    async def get_chat_info(self) -> Optional[Dict[str, Any]]:
        if not self.bot_token or not self.channel_id:
            return None
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(f"{self.base_url}/getChat", json={"chat_id": self.channel_id})
                data = res.json()
                if data.get("ok"):
                    return data.get("result")
        except Exception as e:
            print(f"[TelegramSync] getChat failed: {e}")
        return None

    def _extract_tags(self, text: Optional[str]) -> List[str]:
        if not text:
            return []
        matches = HASHTAG_REGEX.findall(text)
        return [m.lower() for m in matches]

    def process_message(self, message: Dict[str, Any]) -> bool:
        message_id = message.get("message_id")
        date_added = message.get("date", 0)
        caption = message.get("caption", "") or message.get("text", "")
        tags = self._extract_tags(caption)

        audio = message.get("audio")
        doc = message.get("document")

        target_file = None
        is_audio = False

        if audio:
            target_file = audio
            is_audio = True
        elif doc:
            mime = doc.get("mime_type", "")
            file_name = doc.get("file_name", "").lower()
            if mime.startswith("audio/") or file_name.endswith((".mp3", ".flac", ".m4a", ".wav", ".aac", ".ogg")):
                target_file = doc
                is_audio = True

        if not is_audio or not target_file:
            return False

        file_id = target_file.get("file_id")
        file_unique_id = target_file.get("file_unique_id", str(message_id))
        duration = target_file.get("duration", 0)
        file_size = target_file.get("file_size", 0)
        mime_type = target_file.get("mime_type", "audio/mpeg")
        
        # Performer and title extraction
        performer = target_file.get("performer") or ""
        title = target_file.get("title") or ""
        file_name = target_file.get("file_name") or ""

        if not title:
            # Fallback to file_name or caption
            if file_name:
                clean_name = re.sub(r"\.(mp3|flac|m4a|wav|aac|ogg)$", "", file_name, flags=re.IGNORECASE)
                if " - " in clean_name:
                    parts = clean_name.split(" - ", 1)
                    if not performer:
                        performer = parts[0].strip()
                    title = parts[1].strip()
                else:
                    title = clean_name
            elif caption:
                title = caption.split("\n")[0][:60]
            else:
                title = f"Track #{message_id}"

        if not performer:
            performer = "Неизвестный исполнитель"

        # Check thumbnail / cover
        thumb = target_file.get("thumbnail") or target_file.get("thumb")
        has_cover = thumb is not None
        cover_file_id = thumb.get("file_id") if thumb else None

        track_id = f"tg_{file_unique_id}"

        return upsert_track(
            track_id=track_id,
            file_id=file_id,
            message_id=message_id,
            title=title.strip(),
            artist=performer.strip(),
            duration=duration,
            file_size=file_size,
            mime_type=mime_type,
            has_cover=has_cover,
            cover_file_id=cover_file_id,
            tags=tags,
            date_added=date_added
        )

    async def sync_channel_updates(self) -> Dict[str, Any]:
        """
        Polls updates from Telegram. Reads both channel_post and regular messages.
        """
        if not self.bot_token:
            return {"status": "error", "message": "BOT_TOKEN not configured", "new_tracks": 0}

        offset_str = get_sync_meta("last_update_id", "0")
        offset = int(offset_str) if offset_str else 0

        new_tracks = 0
        try:
            async with httpx.AsyncClient(timeout=25.0) as client:
                params = {
                    "offset": offset,
                    "limit": 100,
                    "allowed_updates": ["channel_post", "edited_channel_post", "message"]
                }
                res = await client.get(f"{self.base_url}/getUpdates", params=params)
                data = res.json()
                if not data.get("ok"):
                    return {
                        "status": "error",
                        "message": data.get("description", "Unknown Telegram error"),
                        "new_tracks": 0
                    }

                updates = data.get("result", [])
                max_update_id = offset

                for upd in updates:
                    upd_id = upd.get("update_id", 0)
                    if upd_id >= max_update_id:
                        max_update_id = upd_id + 1

                    msg = upd.get("channel_post") or upd.get("message") or upd.get("edited_channel_post")
                    if msg:
                        # Check channel ID filter if configured
                        chat = msg.get("chat", {})
                        chat_id = str(chat.get("id", ""))
                        chat_username = f"@{chat.get('username', '')}"

                        target_channel = str(self.channel_id).strip()
                        if target_channel:
                            if chat_id != target_channel and chat_username.lower() != target_channel.lower():
                                continue

                        if self.process_message(msg):
                            new_tracks += 1

                if max_update_id > offset:
                    set_sync_meta("last_update_id", str(max_update_id))

        except Exception as e:
            return {"status": "error", "message": str(e), "new_tracks": 0}

        total = get_total_tracks_count()
        return {
            "status": "ok",
            "message": f"Синхронизировано: добавлено {new_tracks} новых треков.",
            "new_tracks": new_tracks,
            "total_tracks": total
        }

telegram_sync = TelegramSyncService()
