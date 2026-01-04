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
