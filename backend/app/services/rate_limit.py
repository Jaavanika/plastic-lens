from __future__ import annotations

import threading
import time
from collections import defaultdict, deque


class RateLimiter:
    """Sliding-window limit per user (in memory, per server instance).

    Good enough for a single Cloud Run/Render instance; with several
    instances, move the counters to Firestore or Redis.
    """

    def __init__(self, limit: int, window_s: float = 3600, clock=time.monotonic):
        self.limit = limit
        self.window_s = window_s
        self._clock = clock
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str) -> tuple[bool, int]:
        """(allowed, seconds until a slot frees up)."""
        now = self._clock()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] >= self.window_s:
                hits.popleft()
            if len(hits) >= self.limit:
                return False, int(self.window_s - (now - hits[0])) + 1
            hits.append(now)
            return True, 0
