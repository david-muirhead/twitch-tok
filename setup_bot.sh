#!/bin/bash

# Create main folder and subfolders
mkdir -p twitch-tiktok-bot/data/raw
mkdir -p twitch-tiktok-bot/data/processed
mkdir -p twitch-tiktok-bot/data/captions

cd twitch-tiktok-bot || exit

# --------------------
# run.sh
cat > run.sh << 'EOF'
#!/bin/bash
python fetch_clips.py
python rank_clips.py
python download_clips.py
python process_video.py
python captions.py
python upload_tiktok.py
EOF
chmod +x run.sh

# --------------------
# Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim
RUN apt update && apt install -y ffmpeg chromium chromium-driver curl git nano && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir requests yt-dlp playwright whisper
RUN playwright install chromium
WORKDIR /app
COPY . .
CMD ["bash", "run.sh"]
EOF

# --------------------
# docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  bot:
    build: .
    env_file:
      - .env
    volumes:
      - ./data:/app/data
      - ./cookies.json:/app/cookies.json
    shm_size: 2gb
EOF

# --------------------
# .env.example
cat > .env.example << 'EOF'
TWITCH_CLIENT_ID=your_client_id_here
TWITCH_CLIENT_SECRET=your_client_secret_here

TWITCH_GAMES=VALORANT,Fortnite
CLIPS_PER_GAME=30

MAX_POSTS_PER_RUN=1
EOF

# --------------------
# .gitignore
cat > .gitignore << 'EOF'
.env
cookies.json
data/
__pycache__/
*.pyc
EOF

# --------------------
# fetch_clips.py
cat > fetch_clips.py << 'EOF'
import os, requests, json

CID = os.getenv("TWITCH_CLIENT_ID")
SECRET = os.getenv("TWITCH_CLIENT_SECRET")
GAMES = os.getenv("TWITCH_GAMES").split(",")
CLIPS_PER_GAME = int(os.getenv("CLIPS_PER_GAME", 30))

def get_token():
    r = requests.post(
        "https://id.twitch.tv/oauth2/token",
        params={
            "client_id": CID,
            "client_secret": SECRET,
            "grant_type": "client_credentials"
        }
    )
    return r.json()["access_token"]

token = get_token()
headers = {
    "Client-ID": CID,
    "Authorization": f"Bearer {token}"
}

all_clips = []

for game in GAMES:
    r = requests.get(
        "https://api.twitch.tv/helix/games",
        headers=headers,
        params={"name": game.strip()}
    )
    data = r.json()["data"]
    if not data: continue
    game_id = data[0]["id"]
    r = requests.get(
        "https://api.twitch.tv/helix/clips",
        headers=headers,
        params={
            "game_id": game_id,
            "first": CLIPS_PER_GAME
        }
    )
    clips = r.json()["data"]
    for c in clips:
        c["game_name"] = game.strip()
        all_clips.append(c)

os.makedirs("data", exist_ok=True)
with open("data/clips_meta.json", "w") as f:
    json.dump(all_clips, f, indent=2)
EOF

# --------------------
# rank_clips.py
cat > rank_clips.py << 'EOF'
import json, datetime

with open("data/clips_meta.json") as f:
    clips = json.load(f)

def score(c):
    created = datetime.datetime.fromisoformat(c["created_at"].replace("Z",""))
    minutes = max((datetime.datetime.utcnow() - created).total_seconds() / 60, 1)
    return c["view_count"] / minutes

ranked = sorted(clips, key=score, reverse=True)

with open("data/clips_meta.json","w") as f:
    json.dump(ranked, f, indent=2)
EOF

# --------------------
# download_clips.py
cat > download_clips.py << 'EOF'
import os, json, subprocess

os.makedirs("data/raw", exist_ok=True)

with open("data/clips_meta.json") as f:
    clips = json.load(f)

for c in clips[:5]:
    out = f"data/raw/{c['id']}.mp4"
    if os.path.exists(out): continue
    subprocess.run(["yt-dlp", c["url"], "-o", out])
EOF

# --------------------
# process_video.py
cat > process_video.py << 'EOF'
import os, subprocess

os.makedirs("data/processed", exist_ok=True)

for v in os.listdir("data/raw"):
    src = f"data/raw/{v}"
    dst = f"data/processed/{v}"
    if os.path.exists(dst): continue

    subprocess.run([
        "ffmpeg","-y","-i",src,
        "-filter_complex",
        "[0:v]scale=1080:1920:force_original_aspect_ratio=decrease,"
        "boxblur=10:1[bg];[0:v]scale=1080:-1[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2",
        "-c:a","copy",dst
    ])
EOF

# --------------------
# captions.py
cat > captions.py << 'EOF'
import whisper, os

model = whisper.load_model("base")
os.makedirs("data/captions", exist_ok=True)

for v in os.listdir("data/processed"):
    txt = f"data/captions/{v}.txt"
    if os.path.exists(txt): continue

    r = model.transcribe(f"data/processed/{v}")
    with open(txt,"w") as f:
        f.write(r["text"])
EOF

# --------------------
# upload_tiktok.py
cat > upload_tiktok.py << 'EOF'
import asyncio, os, random, time
from playwright.async_api import async_playwright

POSTED_FILE = "data/posted.txt"
MAX_POSTS = int(os.getenv("MAX_POSTS_PER_RUN", 1))

async def main():
    posted = set()
    if os.path.exists(POSTED_FILE):
        posted = set(open(POSTED_FILE).read().splitlines())

    videos = [v for v in os.listdir("data/processed") if v not in posted][:MAX_POSTS]

    if not videos: return

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False,args=["--disable-blink-features=AutomationControlled","--no-sandbox"])
        context = await browser.new_context(storage_state="cookies.json")
        page = await context.new_page()

        for video in videos:
            await page.goto("https://www.tiktok.com/upload", timeout=60000)
            await page.wait_for_selector("input[type=file]")
            await page.set_input_files("input[type=file]", f"data/processed/{video}")
            await page.wait_for_timeout(random.randint(15000,25000))
            await page.keyboard.type(f"🔥 {video} #twitchclips #gaming #fyp")
            await page.wait_for_timeout(random.randint(5000,10000))
            await page.click("text=Post")
            time.sleep(random.randint(30,60))
            with open(POSTED_FILE,"a") as f:
                f.write(video+"\n")
        await browser.close()

asyncio.run(main())
EOF

# --------------------
# done
echo "✅ All files created under $(pwd)"
echo "Run 'zip -r twitch-tiktok-bot.zip twitch-tiktok-bot' to create a zip archive if needed."

