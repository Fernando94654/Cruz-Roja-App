#!/usr/bin/env bash
# Downloads the MediaPipe pose model next to this script
set -euo pipefail
cd "$(dirname "$0")"
curl -fsSL -o pose_landmarker_full.task \
  https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task
echo "Saved $(pwd)/pose_landmarker_full.task"
