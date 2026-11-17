"""Live CPR coach: python -m cpr_coach --camera 0 (or --video file.mp4)."""

import argparse
import json
import os
import time
from datetime import datetime
from pathlib import Path

import cv2
import numpy as np

# Silence MediaPipe's native logs before it loads
os.environ.setdefault("GLOG_minloglevel", "2")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

from cpr_coach import overlay  # noqa: E402
from cpr_coach.metrics import CompressionCounter, Config, FeedbackPolicy, SessionStats, arm_angle  # noqa: E402
from cpr_coach.pose import PoseDetector  # noqa: E402
from cpr_coach.voice import Voice  # noqa: E402

WIDTH, HEIGHT = 1280, 720
SESSIONS = Path(__file__).resolve().parent.parent / "sessions"
WINDOW = "Enlace Vital - Coach de RCP"
PANEL = 300


def to_canvas(frame: np.ndarray) -> np.ndarray:
    """Fits the frame without stretching to the right of the side panel."""
    canvas = np.zeros((HEIGHT, WIDTH, 3), np.uint8)
    h, w = frame.shape[:2]
    scale = min((WIDTH - PANEL) / w, HEIGHT / h)
    resized = cv2.resize(frame, (int(w * scale), int(h * scale)))
    y = (HEIGHT - resized.shape[0]) // 2
    x = PANEL + (WIDTH - PANEL - resized.shape[1]) // 2
    canvas[y:y + resized.shape[0], x:x + resized.shape[1]] = resized
    return canvas


def parse_args() -> argparse.Namespace:
    """Command-line options."""
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--camera", type=int, default=0, help="webcam index")
    source.add_argument("--video", type=Path, help="replay a recorded video instead of the webcam")
    parser.add_argument("--record", type=Path, help="save the annotated video to this .mp4")
    parser.add_argument("--mute", action="store_true", help="no voice feedback")
    parser.add_argument("--no-window", action="store_true", help="process without showing the video")
    return parser.parse_args()


def open_source(args: argparse.Namespace) -> cv2.VideoCapture:
    """Opens the webcam or the video file."""
    if args.video:
        cap = cv2.VideoCapture(str(args.video))
    else:
        cap = cv2.VideoCapture(args.camera)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, WIDTH)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, HEIGHT)
    if not cap.isOpened():
        raise SystemExit(f"Could not open {args.video or f'camera {args.camera}'}")
    return cap


def main() -> None:
    """Runs the capture, pose, metrics, feedback and drawing loop until q or the video ends."""
    args = parse_args()
    config = Config()
    cap = open_source(args)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    detector = PoseDetector()
    counter = CompressionCounter(config)
    policy = FeedbackPolicy(config)
    stats = SessionStats(config)
    voice = Voice(enabled=not args.mute and not args.video)
    writer = cv2.VideoWriter(str(args.record), cv2.VideoWriter_fourcc(*"mp4v"), fps, (WIDTH, HEIGHT)) if args.record else None

    try:
        run_loop(args, cap, config, detector, counter, policy, stats, voice, writer, fps)
    except KeyboardInterrupt:
        pass
    finally:
        cap.release()
        detector.close()
        if writer:
            writer.release()
        cv2.destroyAllWindows()
        save_summary(stats.summary(counter.count))


def run_loop(args, cap, config, detector, counter, policy, stats, voice, writer, fps) -> None:
    """Processes frames until q, Esc, the window is closed or the video ends."""
    start = time.monotonic()
    frame_index = 0
    previous_t = 0.0
    message, message_t, pulse_t = None, -10.0, -10.0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        # Video files use their own clock so replays give identical results
        t = frame_index / fps if args.video else time.monotonic() - start
        frame_index += 1
        frame = to_canvas(frame if args.video else cv2.flip(frame, 1))

        joints = detector.detect(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB), t)
        arms_straight = None
        rate = counter.rate(t)
        if joints:
            arm = joints.best_arm
            arms_straight = arm_angle(arm.shoulder, arm.elbow, arm.wrist) >= config.straight_arm_deg
            update = counter.update(t, joints.shoulders_y(), joints.torso_len)
            rate = update.rate
            if update.compressed:
                pulse_t = t
            overlay.draw_skeleton(frame, joints, arms_straight)
        else:
            overlay.draw_no_person(frame)

        stats.update(t - previous_t, rate, arms_straight)
        previous_t = t

        spoken = policy.decide(t, counter, arms_straight)
        if spoken:
            voice.say(spoken)
            message, message_t = spoken, t
        shown = message if t - message_t < 3 else None
        pulse = max(0.0, 1 - (t - pulse_t) / 0.25)
        overlay.draw_hud(frame, counter.count, rate, arms_straight, t, shown, config, pulse)

        if writer:
            writer.write(frame)
        if not args.no_window:
            cv2.imshow(WINDOW, frame)
            if cv2.waitKey(1) & 0xFF in (ord("q"), 27) or cv2.getWindowProperty(WINDOW, cv2.WND_PROP_VISIBLE) < 1:
                break


def save_summary(summary: dict) -> None:
    """Prints the session summary and saves it as JSON in sessions/."""
    SESSIONS.mkdir(exist_ok=True)
    path = SESSIONS / f"session-{datetime.now():%Y%m%d-%H%M%S}.json"
    path.write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    print(f"Saved {path}")


if __name__ == "__main__":
    main()
