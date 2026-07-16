from __future__ import annotations

import random
import time
from dataclasses import dataclass

TRANSIENT_HTTP_STATUSES = {429, 502, 503, 504}
ACCESS_STOP_STATUSES = {401, 403}


@dataclass
class DelayPolicy:
    min_delay: float = 4.0
    max_delay: float = 8.0

    def __post_init__(self) -> None:
        self.min_delay = max(2.0, float(self.min_delay))
        self.max_delay = max(2.0, float(self.max_delay))
        if self.max_delay < self.min_delay:
            self.max_delay = self.min_delay

    def next_delay(self) -> float:
        return random.uniform(self.min_delay, self.max_delay)

    def sleep_between_requests(self) -> float:
        seconds = self.next_delay()
        time.sleep(seconds)
        return seconds


def backoff_seconds(attempt: int, *, base: float = 8.0, cap: float = 90.0) -> float:
    return min(cap, base * (2 ** max(0, attempt - 1)))
