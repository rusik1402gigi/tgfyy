# 🎧 Spotigram — Стриминговый сервис в стиле Spotify на базе Telegram

**Spotigram** превращает ваш закрытый (или публичный) Telegram-канал в персональный стриминговый сервис. Вы просто пересылаете или загружаете аудиофайлы в Telegram, а приложение воспроизводит их в привычном темном интерфейсе Spotify с поддержкой фонового звука и экрана блокировки iOS.

---

## ⚡ Особенности архитектуры

- **Стриминг напрямую из Telegram**: Аудиофайлы не занимают терабайты на вашем сервере. Бэкенд проксирует поток через HTTP Range (206 Partial Content), обеспечивая мгновенный старт воспроизведения и перемотку.
- **Интерфейс Spotify**: Темная тема `#121212`, фирменный зеленый `#1DB954`, плавающий мини-плеер, полноэкранный плеер с обложкой, слайдером времени, кнопками перемешивания и повтора.
- **Поддержка iOS**: Фоновое воспроизведение (Background Audio) и управление с экрана блокировки / Центра управления iOS (Now Playing Info Center).
- **Сборка .IPA через GitHub Actions**: Не нужен Mac! Бесплатный CI/CD на виртуальных серверах macOS соберет готовый `.ipa` файл прямо в репозитории.
- **Автоматическая каталогизация**: Извлечение ID3-тегов (название, артист, длительность, обложка) и плейлисты по `#хэштегам` из постов Telegram.

---

## 📁 Структура проекта

```text
spotigram/
├── backend/                  # Серверная часть (FastAPI + Telegram Proxy)
│   ├── app/
│   │   ├── main.py           # REST API эндпоинты
│   │   ├── streamer.py       # Потоковая отдача аудио и обложек
│   │   ├── telegram_sync.py  # Синхронизация с Telegram-каналом
│   │   ├── database.py       # SQLite база треков и избранного
│   │   ├── models.py         # Pydantic схемы
│   │   └── config.py         # Настройки и переменные окружения
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── requirements.txt
│   └── .env.example
├── mobile/                   # iOS-приложение (Flutter)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/          # Главная, Поиск, Медиатека
│   │   ├── widgets/          # MiniPlayer, FullPlayer, TrackTile
│   │   ├── services/         # AudioHandler (just_audio + lockscreen)
│   │   ├── models/
│   │   └── constants/
│   ├── ios/                  # Конфигурация iOS Runner & Info.plist
│   └── pubspec.yaml
└── .github/workflows/
    └── build_ios.yml         # Автоматическая сборка Spotigram.ipa
```

---

## 🚀 Быстрый старт

### 1. Подготовка Telegram бота и канала

1. Откройте [@BotFather](https://t.me/BotFather) в Telegram и создайте нового бота командой `/newbot`.
2. Скопируйте полученный токен (например, `7123456789:AAH...`).
3. Создайте новый частный или публичный канал для вашей музыки (например, `My Secret Music`).
4. Добавьте вашего созданного бота в администраторы канала (с правами чтения/отправки сообщений).
5. Перешлите любой трек в канал. Узнайте ID вашего канала (например, с помощью [@username_to_id_bot] или web-версии Telegram, обычно выглядит как `-100xxxxxxxxxx`).

---

### 2. Запуск бэкенда

#### Вариант A: Локально через Python (Windows / Linux / Mac)
```bash
cd backend
python -m venv venv
venv\Scripts\activate          # для Windows (или source venv/bin/activate для Linux/Mac)
pip install -r requirements.txt

# Создайте файл .env и укажите ваши данные:
copy .env.example .env
```

Отредактируйте `.env`:
```env
BOT_TOKEN=ваш_токен_бота
CHANNEL_ID=-100xxxxxxxxxx
PORT=8000
```

Запуск:
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Интерфейс документации API доступен по адресу: `http://localhost:8000/docs`

#### Вариант B: Через Docker
```bash
cd backend
docker-compose up -d --build
```

---

### 3. Сборка .IPA файла через GitHub Actions (Без Mac)

1. Создайте новый репозиторий на GitHub (например, `spotigram`).
2. Загрузите файлы проекта в репозиторий:
   ```bash
   git init
   git add .
   git commit -m "Initial commit of Spotigram"
   git branch -M main
   git remote add origin https://github.com/ВАШ_ЛОГИН/spotigram.git
   git push -u origin main
   ```
3. Перейдите во вкладку **Actions** в вашем репозитории на GitHub.
4. Выберите воркфлоу **Build iOS IPA** и нажмите кнопку **Run workflow**.
5. GitHub на бесплатном macOS-раннере скомпилирует приложение и упакует его в `Spotigram.ipa`.
6. По завершении скачайте архив `Spotigram-iOS-IPA` внизу страницы сборки (в блоке **Artifacts**).

---

### 4. Установка .IPA на iPhone

Файл `.ipa` можно установить на ваш iOS-девайс любым удобным способом:
- **TrollStore** (для iOS 14.0 — 17.0): установка навсегда без отзыва сертификатов.
- **AltStore / SideStore**: бесплатная подпись через ваш личный Apple ID с автоматическим продлением по Wi-Fi.
- **Sideloadly**: подключите iPhone по проводу к Windows-компьютеру и перетащите `Spotigram.ipa` в окно Sideloadly.
- **Scarlet / Esign**: прямая установка на iPhone с корпоративным сертификатом.

---

### 5. Первое открытие приложения

1. Откройте **Spotigram** на вашем iPhone.
2. В правом верхнем углу нажмите на иконку настроек ⚙️.
3. Введите адрес вашего бэкенда (например, ваш домашний IP: `http://192.168.1.100:8000` или домен вашего VPS-сервера `https://spotigram.yourdomain.com`).
4. Нажмите **Сохранить**.
5. Потяните экран вниз (Pull-to-refresh) для мгновенной подгрузки всей музыки из вашего Telegram-канала!
