#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def percentile(values: list[int], q: float) -> int:
    if not values:
        return 0
    s = sorted(values)
    idx = min(len(s) - 1, max(0, round((len(s) - 1) * q)))
    return s[idx]


def parse(path: Path) -> dict:
    lines = path.read_text(errors="ignore").splitlines()
    sync_rows: list[tuple[str, int, str]] = []
    store_durations: dict[str, list[int]] = {}

    for line in lines:
        if "SYNC_SUMMARY store=" not in line or "durationMs=" not in line:
            continue
        try:
            store = line.split("store=")[1].split(" ")[0]
            duration_ms = int(line.split("durationMs=")[1].split(" ")[0])
            online = line.split("online=")[1].split(" ")[0]
        except Exception:
            continue
        sync_rows.append((store, duration_ms, online))
        store_durations.setdefault(store, []).append(duration_ms)

    durations = [d for _, d, _ in sync_rows]
    return {
        "path": str(path),
        "line_count": len(lines),
        "sync_count": len(sync_rows),
        "durations": durations,
        "store_durations": store_durations,
        "audit_count": sum("Patient integrity audit issues detected" in l for l in lines),
        "manual_resync_count": sum("Manual Resync Requested" in l for l in lines),
        "connection_closed_count": sum(
            "Connection closed before full header was received" in l for l in lines
        ),
        "status_code_zero_count": sum("statusCode: 0" in l for l in lines),
        "deferred_true_count": sum(
            "SYNC_SUMMARY" in l and "deferred=true" in l for l in lines
        ),
        "over_10s": sum(d > 10_000 for d in durations),
        "over_30s": sum(d > 30_000 for d in durations),
        "p50": percentile(durations, 0.50),
        "p95": percentile(durations, 0.95),
        "max": max(durations) if durations else 0,
        "avg": (sum(durations) / len(durations)) if durations else 0.0,
    }


def print_report(label: str, stats: dict) -> None:
    print(f"=== {label} ===")
    print(f"file: {stats['path']}")
    print(f"lines: {stats['line_count']}")
    print(f"sync_count: {stats['sync_count']}")
    print(
        "duration_ms: "
        f"p50={stats['p50']} p95={stats['p95']} max={stats['max']} avg={stats['avg']:.1f}"
    )
    print(f">10s: {stats['over_10s']} | >30s: {stats['over_30s']}")
    print(f"audit_count: {stats['audit_count']}")
    print(f"manual_resync: {stats['manual_resync_count']}")
    print(f"connection_closed: {stats['connection_closed_count']}")
    print(f"statusCode0: {stats['status_code_zero_count']}")
    print(f"deferred=true summaries: {stats['deferred_true_count']}")

    top = sorted(
        (
            (store, len(vals), round(sum(vals) / len(vals), 1), max(vals))
            for store, vals in stats["store_durations"].items()
        ),
        key=lambda row: row[1],
        reverse=True,
    )[:8]
    print("top stores (count, avg_ms, max_ms):")
    for store, count, avg_ms, max_ms in top:
        print(f"  - {store}: count={count}, avg={avg_ms}, max={max_ms}")


def print_delta(base: dict, fresh: dict) -> None:
    print("=== Delta (fresh - base) ===")
    keys = [
        "sync_count",
        "p50",
        "p95",
        "max",
        "over_10s",
        "over_30s",
        "audit_count",
        "manual_resync_count",
        "connection_closed_count",
        "status_code_zero_count",
        "deferred_true_count",
    ]
    for key in keys:
        print(f"{key}: {fresh[key] - base[key]}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare sync/audit/error characteristics between two activity logs"
    )
    parser.add_argument("base_log", help="Older baseline log path")
    parser.add_argument("fresh_log", help="Newer log path")
    args = parser.parse_args()

    base = parse(Path(args.base_log))
    fresh = parse(Path(args.fresh_log))

    print_report("Base", base)
    print()
    print_report("Fresh", fresh)
    print()
    print_delta(base, fresh)


if __name__ == "__main__":
    main()
