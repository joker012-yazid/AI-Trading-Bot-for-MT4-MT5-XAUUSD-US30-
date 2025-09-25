#!/usr/bin/env python3
"""Validate trading log CSV for ai-trading-bot-spec1."""

from __future__ import annotations

import csv
import os
import sys
from collections import defaultdict
from datetime import datetime

REQUIRED_HEADER = ["timestamp", "tz_offset", "event", "price", "volume", "profit", "comment"]


def load_float(value: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def main(path: str) -> int:
    if not os.path.exists(path):
        print(f"[ERROR] File not found: {path}")
        return 1

    with open(path, "r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        header = reader.fieldnames or []
        missing = [col for col in REQUIRED_HEADER if col not in header]
        if missing:
            print(f"[ERROR] Missing columns: {', '.join(missing)}")
            return 1

        base_equity = float(os.getenv("BASE_EQUITY", "1000"))
        loss_limit_pct = float(os.getenv("DAILY_LOSS_LIMIT", "2.0"))

        daily_profit = defaultdict(float)
        open_volume = 0.0
        close_volume = 0.0

        rows = list(reader)
        if not rows:
            print("[WARN] Log is empty; nothing to validate.")
            return 0

        for row in rows:
            ts = row.get("timestamp", "")
            try:
                day = datetime.fromisoformat(ts.replace("Z", "+00:00")).date()
            except ValueError:
                print(f"[ERROR] Invalid timestamp format: {ts}")
                return 1

            profit = load_float(row.get("profit", "0"))
            daily_profit[day] += profit

            event = row.get("event", "").upper()
            volume = load_float(row.get("volume", "0"))
            if event.endswith("_OPEN"):
                open_volume += volume
            elif event == "POSITION_CLOSE":
                close_volume += volume

        for day, profit in sorted(daily_profit.items()):
            if profit < 0:
                loss_pct = abs(profit) / base_equity * 100.0
                if loss_pct > loss_limit_pct + 1e-6:
                    print(
                        f"[ERROR] Daily loss {loss_pct:.2f}% on {day} exceeds limit {loss_limit_pct:.2f}%"
                    )
                    return 1

        if abs(open_volume - close_volume) > 1e-6:
            print(
                f"[ERROR] Mismatch between open volume ({open_volume}) and close volume ({close_volume})."
            )
            return 1

    print("[OK] Log validation successful.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python tools/validate_logs.py <log.csv>")
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
