"""CPR metrics with no camera or model dependencies, so the logic ports directly to Swift (numpy maps to Accelerate)."""

import math
import statistics
from collections import deque
from dataclasses import dataclass, field

import numpy as np

Point = tuple[float, float]


@dataclass(frozen=True)
class Config:
    """Every threshold used by the coach, in one place."""

    # Smallest movement that can count as a compression, in torso lengths
    min_amplitude: float = 0.02
    # Counting threshold as a fraction of the up-and-down swings of the last seconds
    amplitude_fraction: float = 0.35
    swing_window_s: float = 4
    # Exponential smoothing of the signal (1 = no smoothing)
    smoothing: float = 0.5
    # Slow body drift removed with a moving average of this length
    detrend_s: float = 1
    # Torso length is the median over this window, not the noisy per-frame value
    torso_window_s: float = 2
    # Rate comes from the rhythm (autocorrelation) of the last seconds
    rate_window_s: float = 5
    min_periodicity: float = 0.3
    # A shorter lag this strong relative to the best one is the real period, not a harmonic
    harmonic_fraction: float = 0.4
    # A peak this close to the current period, and at least this periodic, keeps the current rhythm
    continuity_tolerance: float = 0.2
    continuity_periodicity: float = 0.15
    min_rate: float = 50
    max_rate: float = 180
    # A compression closer than this fraction of the current period is a double count
    refractory_fraction: float = 0.5
    # The body counts as moving when the last second swings more than min_amplitude
    motion_window_s: float = 1
    min_interval_s: float = 0.3
    target_min_rate: float = 100
    target_max_rate: float = 120
    straight_arm_deg: float = 160
    pause_s: float = 3
    speak_every_s: float = 4
    praise_every_s: float = 8


@dataclass
class CounterUpdate:
    """Counter state after one frame."""

    count: int
    rate: float | None
    compressed: bool


class CompressionCounter:
    """Counts compressions from the vertical shoulder position and measures their rhythm."""

    RESAMPLE_HZ = 30

    def __init__(self, config: Config = Config()):
        self.config = config
        self.count = 0
        self.last_compression_t: float | None = None
        self._raw: deque[tuple[float, float]] = deque()
        self._torsos: deque[tuple[float, float]] = deque()
        self._signal: deque[tuple[float, float]] = deque()
        self._smoothed: float | None = None
        self._going_down = True
        self._extreme = 0.0
        self._extreme_t = 0.0
        self._last_turn: float | None = None
        self._swings: deque[tuple[float, float]] = deque()
        self._rate: float | None = None
        self._phase = 0.0
        self._last_t: float | None = None

    def update(self, t: float, y: float, torso_len: float) -> CounterUpdate:
        """Feeds one frame; y is the shoulder height and grows downward as in image coordinates."""
        c = self.config
        _push(self._torsos, t, torso_len, c.torso_window_s)
        torso = statistics.median(v for _, v in self._torsos)

        _push(self._raw, t, y / torso, c.detrend_s)
        baseline = statistics.fmean(v for _, v in self._raw)
        x = y / torso - baseline
        first = self._smoothed is None
        self._smoothed = x if first else c.smoothing * x + (1 - c.smoothing) * self._smoothed
        s = self._smoothed
        _push(self._signal, t, s, c.rate_window_s)

        if first:
            self._extreme, self._extreme_t = s, t
        peak_t = self._track_peaks(s, t)
        dt = 0.0 if self._last_t is None else t - self._last_t
        self._last_t = t

        self._rate = self._rhythm_rate(t) if self.count >= 2 else None
        compressed = False
        if self._rate and self._is_moving(t):
            # Once the rhythm is clear, count by its phase so one missed or extra peak can't change the total
            self._phase += self._rate / 60 * dt
            if self._phase >= 1:
                self._phase -= 1
                compressed = self._register(t)
        elif peak_t is not None:
            compressed = self._register(peak_t)
            self._phase = 0.0
        return CounterUpdate(self.count, self.rate(t), compressed)

    def _track_peaks(self, s: float, t: float) -> float | None:
        """Hysteresis peak detection; returns the time of a bottom that was just confirmed."""
        threshold = self._threshold(t)
        if self._going_down:
            if s >= self._extreme:
                self._extreme, self._extreme_t = s, t
            elif s <= self._extreme - threshold:
                bottom_t = self._extreme_t
                self._turn(s, t, going_down=False)
                return bottom_t
        else:
            if s <= self._extreme:
                self._extreme, self._extreme_t = s, t
            elif s >= self._extreme + threshold:
                self._turn(s, t, going_down=True)
        return None

    def _is_moving(self, t: float) -> bool:
        """True while the last second still shows compression-sized movement."""
        recent = [v for ts, v in self._signal if t - ts <= self.config.motion_window_s]
        return len(recent) >= 5 and max(recent) - min(recent) >= self.config.min_amplitude

    def _turn(self, s: float, t: float, going_down: bool) -> None:
        """Records the swing that just ended and starts tracking the opposite direction."""
        if self._last_turn is not None:
            _push(self._swings, t, abs(self._extreme - self._last_turn), self.config.swing_window_s)
        self._last_turn = self._extreme
        self._going_down = going_down
        self._extreme, self._extreme_t = s, t

    def _threshold(self, t: float) -> float:
        """Hysteresis that follows how much the person is moving now; old swings, like getting into position, expire."""
        c = self.config
        recent = [v for ts, v in self._swings if t - ts <= c.swing_window_s]
        if len(recent) < 3:
            return c.min_amplitude
        return max(c.min_amplitude, c.amplitude_fraction * statistics.median(recent))

    def _register(self, bottom_t: float) -> bool:
        """Counts a bottom of the movement unless it comes too soon after the previous one."""
        last = self.last_compression_t
        if last is not None:
            refractory = self.config.min_interval_s
            if self._rate:
                refractory = max(refractory, self.config.refractory_fraction * 60 / self._rate)
            if bottom_t - last < refractory:
                return False
        self.count += 1
        self.last_compression_t = bottom_t
        return True

    def _rhythm_rate(self, t: float) -> float | None:
        """Compressions per minute from the autocorrelation of the last seconds, or None if not periodic."""
        c = self.config
        window = [(ts, v) for ts, v in self._signal if t - ts <= c.rate_window_s]
        if len(window) < 20 or window[-1][0] - window[0][0] < c.rate_window_s / 2:
            return None
        ts, vs = np.array(window).T
        grid = np.arange(ts[0], ts[-1], 1 / self.RESAMPLE_HZ)
        # Autocorrelation of the speed, not the height, so slow drift can't hide the rhythm
        v = np.convolve(np.diff(np.interp(grid, ts, vs)), np.ones(3) / 3, mode="same")
        v -= v.mean()
        n = len(v)
        energy = float(v @ v)
        if energy == 0:
            return None
        lo = max(1, int(self.RESAMPLE_HZ * 60 / c.max_rate))
        hi = min(n - 2, int(self.RESAMPLE_HZ * 60 / c.min_rate))
        if hi <= lo:
            return None
        lags = np.arange(lo, hi + 1)
        # Normalized per lag so longer lags are not penalized for having fewer samples
        ac = np.array([v[:-k] @ v[k:] / (n - k) for k in lags]) / (energy / n)
        # Only true local maxima count; the edges of the range are not a rhythm
        peaks = [k for k in range(1, len(ac) - 1) if ac[k] > ac[k - 1] and ac[k] >= ac[k + 1] and ac[k] > 0]
        if not peaks:
            return None
        best = max(ac[k] for k in peaks)
        if best < c.min_periodicity:
            return None
        # The shortest clear lag avoids picking a multiple of the period
        k = next(k for k in peaks if ac[k] >= c.harmonic_fraction * best)
        # Keep following the current rhythm while it is still visible, so the needle doesn't flicker
        if self._rate:
            previous = self.RESAMPLE_HZ * 60 / self._rate
            near = [j for j in peaks if abs(lags[j] - previous) <= c.continuity_tolerance * previous and ac[j] >= c.continuity_periodicity]
            if near:
                k = max(near, key=lambda j: ac[j])
        a, b, d = ac[k - 1], ac[k], ac[k + 1]
        denom = a - 2 * b + d
        lag = float(lags[k]) + (0.5 * (a - d) / denom if denom != 0 else 0.0)
        # At the real period, half a lag is out of phase; if it still correlates, the lag is a double period
        if lag / 2 >= lags[0] and np.interp(lag / 2, lags, ac) >= c.harmonic_fraction * b:
            lag /= 2
        return 60 * self.RESAMPLE_HZ / lag

    def rate(self, t: float) -> float | None:
        """Compressions per minute, or None while paused or before the rhythm is clear."""
        if self.is_paused(t):
            return None
        return self._rate

    def is_paused(self, t: float) -> bool:
        """True when compressions started and then stopped for longer than the pause limit."""
        return self.last_compression_t is not None and t - self.last_compression_t > self.config.pause_s


def _push(buffer: deque[tuple[float, float]], t: float, value: float, keep_s: float) -> None:
    """Appends a sample and drops the ones older than keep_s."""
    buffer.append((t, value))
    while buffer and t - buffer[0][0] > keep_s:
        buffer.popleft()


def arm_angle(shoulder: Point, elbow: Point, wrist: Point) -> float:
    """Elbow angle in degrees; 180 means a fully straight arm."""
    v1 = (shoulder[0] - elbow[0], shoulder[1] - elbow[1])
    v2 = (wrist[0] - elbow[0], wrist[1] - elbow[1])
    norm = math.hypot(*v1) * math.hypot(*v2)
    if norm == 0:
        return 180.0
    cos = (v1[0] * v2[0] + v1[1] * v2[1]) / norm
    return math.degrees(math.acos(max(-1.0, min(1.0, cos))))


# Spoken messages, in priority order
CONTINUE = "Continúa las compresiones"
STRAIGHTEN = "Estira los brazos"
FASTER = "Más rápido"
SLOWER = "Más lento"
GOOD = "Bien, sigue así"


class FeedbackPolicy:
    """Picks the correction to speak, at most one every few seconds."""

    def __init__(self, config: Config = Config()):
        self.config = config
        self._last_spoken_t: float | None = None
        self._last_praise_t: float | None = None

    def decide(self, t: float, counter: CompressionCounter, arms_straight: bool | None) -> str | None:
        """Returns the message to speak now, or None."""
        if counter.count == 0:
            return None
        if self._last_spoken_t is not None and t - self._last_spoken_t < self.config.speak_every_s:
            return None
        message = self.current(t, counter, arms_straight)
        if message == GOOD:
            if self._last_praise_t is not None and t - self._last_praise_t < self.config.praise_every_s:
                return None
            self._last_praise_t = t
        if message is not None:
            self._last_spoken_t = t
        return message

    def current(self, t: float, counter: CompressionCounter, arms_straight: bool | None) -> str | None:
        """Highest-priority message for the current state, without throttling."""
        if counter.is_paused(t):
            return CONTINUE
        if arms_straight is False:
            return STRAIGHTEN
        rate = counter.rate(t)
        if rate is None:
            return None
        if rate < self.config.target_min_rate:
            return FASTER
        if rate > self.config.target_max_rate:
            return SLOWER
        return GOOD


@dataclass
class SessionStats:
    """Accumulates time in range and arm posture for the end-of-session summary."""

    config: Config = field(default_factory=Config)
    duration_s: float = 0.0
    active_s: float = 0.0
    in_range_s: float = 0.0
    straight_s: float = 0.0
    _rates: list[float] = field(default_factory=list)

    def update(self, dt: float, rate: float | None, arms_straight: bool | None) -> None:
        """Adds one frame of duration dt."""
        self.duration_s += dt
        if rate is None:
            return
        self.active_s += dt
        self._rates.append(rate)
        if self.config.target_min_rate <= rate <= self.config.target_max_rate:
            self.in_range_s += dt
        if arms_straight:
            self.straight_s += dt

    def summary(self, count: int) -> dict:
        """Totals ready to save as JSON and attach to the emergency report."""
        pct = lambda part: round(100 * part / self.active_s) if self.active_s else 0
        return {
            "compressions": count,
            "duration_s": round(self.duration_s, 1),
            "average_rate": round(statistics.mean(self._rates)) if self._rates else None,
            "time_in_range_pct": pct(self.in_range_s),
            "straight_arms_pct": pct(self.straight_s),
        }
