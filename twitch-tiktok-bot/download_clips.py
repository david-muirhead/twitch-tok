import os, json, subprocess

os.makedirs("data/raw", exist_ok=True)

with open("data/clips_meta.json") as f:
    clips = json.load(f)

for c in clips[:5]:
    out = f"data/raw/{c['id']}.mp4"
    if os.path.exists(out): continue
    subprocess.run(["yt-dlp", c["url"], "-o", out])
