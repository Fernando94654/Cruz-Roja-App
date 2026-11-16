"""MediaPipe pose wrapper that exposes only the joints Apple Vision also detects."""

from dataclasses import dataclass
from pathlib import Path

import mediapipe as mp
import numpy as np

from cpr_coach.metrics import Point

MODEL = Path(__file__).resolve().parent.parent / "models" / "pose_landmarker_full.task"

# MediaPipe landmark indices for each side
SIDES = {
    "left": {"shoulder": 11, "elbow": 13, "wrist": 15, "hip": 23},
    "right": {"shoulder": 12, "elbow": 14, "wrist": 16, "hip": 24},
}


@dataclass
class Arm:
    """One arm and its hip, in pixels, with the lowest visibility of its joints."""

    shoulder: Point
    elbow: Point
    wrist: Point
    hip: Point
    visibility: float


@dataclass
class Joints:
    """Both arms of the detected person."""

    left: Arm
    right: Arm

    @property
    def best_arm(self) -> Arm:
        """Arm facing the camera, used for the elbow angle."""
        return self.left if self.left.visibility >= self.right.visibility else self.right

    def shoulders_y(self) -> float:
        """Shoulder height weighted by visibility; shoulders move with the compressions and jitter less than the wrists.

        A weighted mean changes smoothly, while switching a half-hidden shoulder in and out makes the signal jump.
        """
        # The 4th power lets the clearly visible shoulder dominate while still changing smoothly
        weights = [(arm.shoulder[1], arm.visibility ** 4) for arm in (self.left, self.right)]
        total = sum(w for _, w in weights)
        if total == 0:
            return self.best_arm.shoulder[1]
        return sum(y * w for y, w in weights) / total

    @property
    def torso_len(self) -> float:
        """Shoulder-to-hip distance of the most visible side, used to normalize movement."""
        arm = self.best_arm
        return max(1.0, float(np.hypot(arm.shoulder[0] - arm.hip[0], arm.shoulder[1] - arm.hip[1])))


class PoseDetector:
    """Runs the pose landmarker on consecutive video frames."""

    def __init__(self, model: Path = MODEL, min_visibility: float = 0.5):
        if not model.exists():
            raise FileNotFoundError(f"Missing {model}. Run models/download.sh first.")
        options = mp.tasks.vision.PoseLandmarkerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=str(model)),
            running_mode=mp.tasks.vision.RunningMode.VIDEO,
            num_poses=1,
        )
        self._landmarker = mp.tasks.vision.PoseLandmarker.create_from_options(options)
        self._min_visibility = min_visibility
        self._last_ms = -1

    def detect(self, rgb: np.ndarray, t: float) -> Joints | None:
        """Returns the joints in pixels, or None when no person is clearly visible."""
        ms = max(self._last_ms + 1, int(t * 1000))
        self._last_ms = ms
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = self._landmarker.detect_for_video(image, ms)
        if not result.pose_landmarks:
            return None
        landmarks = result.pose_landmarks[0]
        h, w = rgb.shape[:2]

        def arm(side: dict[str, int]) -> Arm:
            points = {name: landmarks[i] for name, i in side.items()}
            return Arm(
                **{name: (p.x * w, p.y * h) for name, p in points.items()},
                visibility=min(p.visibility for p in points.values()),
            )

        joints = Joints(left=arm(SIDES["left"]), right=arm(SIDES["right"]))
        if joints.best_arm.visibility < self._min_visibility:
            return None
        return joints

    def close(self) -> None:
        """Releases the model."""
        self._landmarker.close()
