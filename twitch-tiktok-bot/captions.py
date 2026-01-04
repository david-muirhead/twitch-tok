import whisper, os

model = whisper.load_model("base")
os.makedirs("data/captions", exist_ok=True)

for v in os.listdir("data/processed"):
    txt = f"data/captions/{v}.txt"
    if os.path.exists(txt): continue

    r = model.transcribe(f"data/processed/{v}")
    with open(txt,"w") as f:
        f.write(r["text"])
