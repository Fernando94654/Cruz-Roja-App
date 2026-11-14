import math
import random

import pytest

from cpr_coach.metrics import (
    CONTINUE,
    FASTER,
    GOOD,
    SLOWER,
    STRAIGHTEN,
    CompressionCounter,
    FeedbackPolicy,
    SessionStats,
    arm_angle,
)

FPS = 30
TORSO = 0.3


def compressions(bpm: float, seconds: float, start: float = 0.0, noise: float = 0.003, drift: float = 0.0, seed: int = 1):
    """Synthetic shoulder heights on a 30 fps camera: pushes of 0.1 torso lengths, gaussian noise and slow body drift."""
    rng = random.Random(seed)
    f = bpm / 60
    frames = int(seconds * FPS)
    samples = []
    for i in range(frames):
        t = start + i / FPS
        y = 0.5 + 0.015 * math.sin(2 * math.pi * f * t) + drift * math.sin(2 * math.pi * 0.15 * t) + rng.gauss(0, noise)
        samples.append((t, y))
    return samples


def run(counter: CompressionCounter, samples, torso_jitter: float = 0.0, seed: int = 2):
    rng = random.Random(seed)
    update = None
    for t, y in samples:
        update = counter.update(t, y, TORSO * (1 + rng.uniform(-torso_jitter, torso_jitter)))
    return update


@pytest.mark.parametrize("bpm", [80, 100, 110, 120, 140])
def test_rate_is_within_five_percent(bpm):
    counter = CompressionCounter()
    update = run(counter, compressions(bpm, 30))
    assert update.rate == pytest.approx(bpm, rel=0.05)


@pytest.mark.parametrize("bpm", [100, 120])
def test_counts_every_compression(bpm):
    counter = CompressionCounter()
    run(counter, compressions(bpm, 30))
    assert abs(counter.count - bpm / 2) <= 1


def test_ignores_small_movements():
    counter = CompressionCounter()
    for i in range(10 * FPS):
        counter.update(i / FPS, 0.5 + 0.0015 * math.sin(2 * math.pi * 2 * i / FPS), TORSO)
    assert counter.count == 0


@pytest.mark.parametrize("bpm", [90, 110, 130])
def test_handles_body_drift_and_torso_jitter(bpm):
    counter = CompressionCounter()
    update = run(counter, compressions(bpm, 30, drift=0.03), torso_jitter=0.25)
    assert update.rate == pytest.approx(bpm, rel=0.05)
    assert abs(counter.count - bpm / 2) <= 2


def test_count_follows_rhythm_through_detection_gaps_and_spikes():
    samples = compressions(110, 30)
    rng = random.Random(3)
    # Flatten one push in seven (a detection gap) and add sharp landmark spikes
    period = 60 / 110
    skipped = {k for k in range(55) if k % 7 == 3}
    edited = []
    for t, y in samples:
        if int(t / period) in skipped:
            y = 0.5
        if rng.random() < 0.02:
            y += rng.choice([-1, 1]) * 0.02
        edited.append((t, y))
    counter = CompressionCounter()
    update = run(counter, edited)
    assert update.rate == pytest.approx(110, rel=0.05)
    assert abs(counter.count - 55) <= 3


def test_pause_resets_rate_and_asks_to_continue():
    counter = CompressionCounter()
    run(counter, compressions(110, 10))
    t = 10 + 3.5
    counter.update(t, 0.5, TORSO)
    assert counter.is_paused(t)
    assert counter.rate(t) is None
    assert FeedbackPolicy().decide(t, counter, arms_straight=True) == CONTINUE


@pytest.mark.parametrize("bpm, message", [(80, FASTER), (110, GOOD), (140, SLOWER)])
def test_rate_feedback(bpm, message):
    counter = CompressionCounter()
    run(counter, compressions(bpm, 10))
    assert FeedbackPolicy().decide(10, counter, arms_straight=True) == message


def test_bent_arms_come_before_rate():
    counter = CompressionCounter()
    run(counter, compressions(80, 10))
    assert FeedbackPolicy().decide(10, counter, arms_straight=False) == STRAIGHTEN


def test_feedback_is_throttled():
    counter = CompressionCounter()
    run(counter, compressions(80, 10))
    policy = FeedbackPolicy()
    assert policy.decide(10, counter, True) == FASTER
    assert policy.decide(11, counter, True) is None


def test_arm_angle():
    assert arm_angle((0, 0), (0, 1), (0, 2)) == pytest.approx(180)
    assert arm_angle((0, 0), (0, 1), (1, 1)) == pytest.approx(90)


def test_session_summary():
    counter = CompressionCounter()
    stats = SessionStats()
    for t, y in compressions(110, 20):
        update = counter.update(t, y, TORSO)
        stats.update(1 / FPS, update.rate, arms_straight=True)
    summary = stats.summary(counter.count)
    assert summary["average_rate"] == pytest.approx(110, rel=0.05)
    assert summary["time_in_range_pct"] >= 90
    assert summary["straight_arms_pct"] == 100


def test_alternating_strong_and_weak_pushes_keep_the_real_rate():
    # Every other push moves the shoulders more, which makes a double period look stronger
    f = 110 / 60
    samples = [(i / FPS, 0.5 + 0.015 * math.sin(2 * math.pi * f * i / FPS) + 0.009 * math.sin(math.pi * f * i / FPS))
               for i in range(20 * FPS)]
    counter = CompressionCounter()
    update = run(counter, samples)
    assert update.rate == pytest.approx(110, rel=0.05)
