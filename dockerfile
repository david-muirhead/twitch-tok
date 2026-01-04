FROM python:3.11-slim

RUN apt update && apt install -y \
    ffmpeg \
    chromium \
    chromium-driver \
    curl \
    git \
    nano \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir requests yt-dlp playwright whisper
RUN playwright install chromium

WORKDIR /app
COPY . .

CMD ["bash", "run.sh"]
