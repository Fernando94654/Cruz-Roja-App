"""Draws the coach on top of the video: skeleton, counter, rate gauge and subtitle."""

import math
import unicodedata

import cv2
import numpy as np

from cpr_coach.metrics import Config
from cpr_coach.pose import Arm, Joints

RED = (60, 40, 220)
GREEN = (80, 200, 60)
AMBER = (0, 170, 255)
WHITE = (255, 255, 255)
DARK = (30, 30, 30)
FONT = cv2.FONT_HERSHEY_DUPLEX

GAUGE_MIN, GAUGE_MAX = 60, 160


def ascii_text(text: str) -> str:
    """OpenCV fonts have no accents, so draw "Más" as "Mas"."""
    return unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()


def _pt(p) -> tuple[int, int]:
    return int(p[0]), int(p[1])


def draw_skeleton(frame: np.ndarray, joints: Joints, arms_straight: bool | None) -> None:
    """Arms and torso; the arm used for the angle turns red when it is bent."""
    best = joints.best_arm
    other = joints.right if best is joints.left else joints.left
    _draw_arm(frame, other, (200, 200, 200))
    _draw_arm(frame, best, GREEN if arms_straight else RED)


def _draw_arm(frame: np.ndarray, arm: Arm, color) -> None:
    for a, b in ((arm.hip, arm.shoulder), (arm.shoulder, arm.elbow), (arm.elbow, arm.wrist)):
        cv2.line(frame, _pt(a), _pt(b), color, 6, cv2.LINE_AA)
    for p in (arm.shoulder, arm.elbow, arm.wrist, arm.hip):
        cv2.circle(frame, _pt(p), 9, WHITE, -1, cv2.LINE_AA)
        cv2.circle(frame, _pt(p), 9, color, 3, cv2.LINE_AA)


def _panel(frame: np.ndarray, x: int, y: int, w: int, h: int) -> None:
    """Translucent dark box behind the HUD."""
    roi = frame[y:y + h, x:x + w]
    roi[:] = cv2.addWeighted(roi, 0.35, np.full_like(roi, DARK), 0.65, 0)


def draw_hud(frame: np.ndarray, count: int, rate: float | None, arms_straight: bool | None,
             elapsed_s: float, message: str | None, config: Config, pulse: float) -> None:
    """Counter, speedometer, arm status, timer and the last spoken message."""
    h, w = frame.shape[:2]
    _panel(frame, 0, 0, 300, h)

    cv2.putText(frame, "COMPRESIONES", (24, 44), FONT, 0.7, WHITE, 1, cv2.LINE_AA)
    scale = 3.2 + 0.6 * pulse
    cv2.putText(frame, str(count), (24, 140), FONT, scale, WHITE, 4, cv2.LINE_AA)

    _gauge(frame, (150, 300), 110, rate, config)

    label, color = {True: ("Rectos", GREEN), False: ("Doblados", RED), None: ("--", WHITE)}[arms_straight]
    cv2.putText(frame, "BRAZOS", (24, 440), FONT, 0.7, WHITE, 1, cv2.LINE_AA)
    cv2.putText(frame, label, (24, 480), FONT, 1.0, color, 2, cv2.LINE_AA)

    minutes, seconds = divmod(int(elapsed_s), 60)
    cv2.putText(frame, f"{minutes:02d}:{seconds:02d}", (24, h - 30), FONT, 1.2, WHITE, 2, cv2.LINE_AA)

    if message:
        message = ascii_text(message)
        size = cv2.getTextSize(message, FONT, 1.3, 2)[0]
        x = 300 + (w - 300 - size[0]) // 2
        _panel(frame, 300, h - 80, w - 300, 80)
        cv2.putText(frame, message, (x, h - 28), FONT, 1.3, WHITE, 2, cv2.LINE_AA)


def _gauge(frame: np.ndarray, center: tuple[int, int], radius: int, rate: float | None, config: Config) -> None:
    """Semicircle speedometer: red below 100, green 100-120, red above."""
    def angle(value: float) -> float:
        v = min(max(value, GAUGE_MIN), GAUGE_MAX)
        return 180 + 180 * (v - GAUGE_MIN) / (GAUGE_MAX - GAUGE_MIN)

    zones = ((GAUGE_MIN, config.target_min_rate, RED), (config.target_min_rate, config.target_max_rate, GREEN),
             (config.target_max_rate, GAUGE_MAX, RED))
    for lo, hi, color in zones:
        cv2.ellipse(frame, center, (radius, radius), 0, angle(lo), angle(hi), color, 18, cv2.LINE_AA)

    if rate is not None:
        a = math.radians(angle(rate))
        tip = (int(center[0] + (radius - 8) * math.cos(a)), int(center[1] + (radius - 8) * math.sin(a)))
        cv2.line(frame, center, tip, WHITE, 5, cv2.LINE_AA)
    cv2.circle(frame, center, 10, WHITE, -1, cv2.LINE_AA)

    in_range = rate is not None and config.target_min_rate <= rate <= config.target_max_rate
    color = GREEN if in_range else (AMBER if rate is None else RED)
    label = "--" if rate is None else f"{rate:.0f}"
    size = cv2.getTextSize(label, FONT, 1.4, 3)[0]
    cv2.putText(frame, label, (center[0] - size[0] // 2, center[1] + 50), FONT, 1.4, color, 3, cv2.LINE_AA)
    cv2.putText(frame, "por minuto", (center[0] - 62, center[1] + 78), FONT, 0.6, WHITE, 1, cv2.LINE_AA)


def draw_no_person(frame: np.ndarray) -> None:
    """Hint shown while nobody is detected."""
    h, w = frame.shape[:2]
    text = "Colocate de lado frente a la camara"
    size = cv2.getTextSize(text, FONT, 1.0, 2)[0]
    cv2.putText(frame, text, (300 + (w - 300 - size[0]) // 2, 60), FONT, 1.0, AMBER, 2, cv2.LINE_AA)
