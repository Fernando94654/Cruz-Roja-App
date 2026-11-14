"""Spanish text-to-speech in a background thread so the video never waits for the voice."""

import queue
import shutil
import subprocess
import threading


class Voice:
    """Speaks one message at a time and drops messages that arrive while it is talking."""

    def __init__(self, enabled: bool = True):
        self.enabled = enabled
        self._queue: queue.Queue[str] = queue.Queue(maxsize=1)
        if enabled:
            threading.Thread(target=self._run, daemon=True).start()

    def say(self, text: str) -> None:
        """Queues a message unless the voice is busy."""
        if not self.enabled:
            return
        try:
            self._queue.put_nowait(text)
        except queue.Full:
            pass

    def _run(self) -> None:
        """Worker loop; prefers speech-dispatcher on Linux and falls back to pyttsx3."""
        speak = self._spd_say if shutil.which("spd-say") else self._pyttsx3()
        while True:
            speak(self._queue.get())

    @staticmethod
    def _spd_say(text: str) -> None:
        subprocess.run(["spd-say", "-l", "es", "-r", "20", "-w", text], check=False)

    @staticmethod
    def _pyttsx3():
        """Builds a pyttsx3 speaker with a Spanish voice when one is installed."""
        import pyttsx3

        engine = pyttsx3.init()
        spanish = next((v for v in engine.getProperty("voices") if "es" in v.id.lower() or "spanish" in v.name.lower()), None)
        if spanish:
            engine.setProperty("voice", spanish.id)

        def speak(text: str) -> None:
            engine.say(text)
            engine.runAndWait()

        return speak
