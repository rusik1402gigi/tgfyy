import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    BOT_TOKEN: str = os.getenv("BOT_TOKEN", "")
    CHANNEL_ID: str = os.getenv("CHANNEL_ID", "")
    TELEGRAM_API_URL: str = os.getenv("TELEGRAM_API_URL", "https://api.telegram.org")
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    DB_PATH: str = os.getenv("DB_PATH", "spotigram.db")
    CACHE_DIR: str = os.getenv("CACHE_DIR", "./cache")
    ENABLE_LOCAL_CACHE: bool = os.getenv("ENABLE_LOCAL_CACHE", "false").lower() in ("true", "1")
    CORS_ORIGINS: str = os.getenv("CORS_ORIGINS", "*")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
