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
