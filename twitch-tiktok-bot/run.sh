#!/bin/bash
python fetch_clips.py
python rank_clips.py
python download_clips.py
python process_video.py
python captions.py
python upload_tiktok.py
