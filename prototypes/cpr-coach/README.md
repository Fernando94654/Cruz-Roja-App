# CPR coach (prototype)

Live chest-compression coach for Enlace Vital. The webcam tracks the rescuer's arms, counts compressions, shows the rate on a gauge (green between 100 and 120 per minute) and speaks corrections in Spanish. This laptop prototype comes before the iPhone version with Apple Vision.

## Setup

```bash
cd prototypes/cpr-coach
uv sync
bash models/download.sh
```

Voice uses `spd-say` (speech-dispatcher) on Linux and falls back to `pyttsx3`.

## Run

```bash
uv run python -m cpr_coach                      # webcam 0
uv run python -m cpr_coach --record demo.mp4    # also save the annotated video
uv run python -m cpr_coach --video demo.mp4     # replay a recording (same result every time)
```

Press `q` to finish. The session summary (compressions, average rate, % of time in range, % with straight arms) is printed and saved in `sessions/`.

**Camera placement:** put the laptop on the side of the rescuer, about 1.5 m away and at chest height, so both arms and the hip are visible. Kneel next to a pillow or a rolled towel and push with straight arms.

## Feedback

| Situation | Voice |
|---|---|
| No compression for 3 s | Continúa las compresiones |
| Elbow angle under 160° | Estira los brazos |
| Under 100 per minute | Más rápido |
| Over 120 per minute | Más lento |
| In range | Bien, sigue así |

At most one message every 4 s. All thresholds live in `Config` in `cpr_coach/metrics.py`.

## How it works

- `pose.py`: MediaPipe Pose Landmarker returns shoulders, elbows, wrists and hips (the same joints Apple Vision detects).
- `metrics.py`: shoulder height (the hands rest on the chest and their landmarks jitter more) divided by a stable torso length (median of the last 2 s). It removes slow body drift with a 1 s moving average, then finds the rhythm with an autocorrelation of the last 5 s. Compressions are counted with that rhythm, so one missed or extra peak doesn't change the total; before the rhythm is clear, an adaptive peak detector counts them. This file has no camera or model code so it ports directly to Swift.
- `overlay.py` and `voice.py`: drawing and speech. `__main__.py` connects everything.

## Tests

```bash
uv run pytest
```

Synthetic compressions at 80 to 140 per minute check the rate (within 5%) and the count, also with body drift, torso length jitter, detection gaps and landmark spikes. They also cover pauses, the arm angle and the feedback priority.

## iOS version

`CruzRoja/Features/CPRCoach/` is the iPhone port. `CPRMetrics.swift` mirrors `metrics.py` (same thresholds; same counts on the recorded demos), Apple Vision's `VNDetectHumanBodyPoseRequest` replaces MediaPipe, and the screen opens from the emergency summary ("Coach de RCP con la cámara"). The simulator has no camera, so it uses a synthetic rescuer at 110 per minute. Tests: `CruzRojaTestsAprende/CPRCoachTests.swift`.
