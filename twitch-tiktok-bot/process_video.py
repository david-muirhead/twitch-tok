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
