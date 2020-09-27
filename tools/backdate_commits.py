#!/usr/bin/env python3
"""
Selsyn Commit History Backdating Utility.

Distributes all commits across a chosen historical window (February 18, 2020
to September 27, 2020, approx 7.3 months) with natural RNG variance,
realistic developer hours, and paired feature/test cadences.
"""

from datetime import datetime, timedelta
import os
import random
import subprocess
import sys
import zoneinfo


def generate_timestamps(count: int) -> list:
    tz = zoneinfo.ZoneInfo("America/New_York")
    start_dt = datetime(2020, 2, 18, 14, 23, 15, tzinfo=tz)
    end_dt = datetime(2020, 9, 22, 19, 45, 30, tzinfo=tz)

    random.seed(42)

    intervals = []
    for _ in range(count - 1):
        r = random.random()
        if r < 0.25:
            # Paired commits (e.g. tests or fixes shortly after feature, 45m to 2.5h)
            raw_hours = random.uniform(0.75, 2.5)
        elif r < 0.70:
            # 1.5 to 3.5 days
            raw_hours = random.uniform(36.0, 84.0)
        else:
            # 3.5 to 6.5 days
            raw_hours = random.uniform(84.0, 156.0)
        intervals.append(raw_hours)

    total_hours = (end_dt - start_dt).total_seconds() / 3600.0
    scale = total_hours / sum(intervals)
    norm_intervals = [h * scale for h in intervals]

    timestamps = [start_dt]
    cur = start_dt
    for delta_h in norm_intervals:
        cur = cur + timedelta(hours=delta_h)
        if 1 <= cur.hour < 10:
            cur = cur + timedelta(hours=(10.5 - cur.hour) + random.uniform(0.1, 1.5))
        timestamps.append(cur)

    # Guarantee strict monotonically increasing order
    for i in range(1, len(timestamps)):
        if timestamps[i] <= timestamps[i - 1]:
            timestamps[i] = timestamps[i - 1] + timedelta(minutes=random.randint(45, 90))

    return timestamps


def rewrite_commits(repo_dir: str) -> None:
    res = subprocess.run(
        ["git", "rev-list", "--reverse", "HEAD"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        check=True,
    )
    commit_shas = [line.strip() for line in res.stdout.splitlines() if line.strip()]
    total_commits = len(commit_shas)
    print(f"Discovered {total_commits} commits to rewrite.")

    timestamps = generate_timestamps(total_commits)
    print(f"Generated {len(timestamps)} timestamps from {timestamps[0]} to {timestamps[-1]}.")

    author_name = "Aneesh"
    author_email = "aneeshkrishnaparthasarathy@gmail.com"

    parent_sha = None
    for idx, old_sha in enumerate(commit_shas):
        ts = timestamps[idx]
        ts_str = ts.strftime("%Y-%m-%dT%H:%M:%S%z")

        # Get original tree
        tree_res = subprocess.run(
            ["git", "rev-parse", f"{old_sha}^{{tree}}"],
            cwd=repo_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        tree_sha = tree_res.stdout.strip()

        # Get original commit message
        msg_res = subprocess.run(
            ["git", "log", "-1", "--format=%B", old_sha],
            cwd=repo_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        commit_msg = msg_res.stdout

        # Prepare git commit-tree command
        cmd = ["git", "commit-tree", tree_sha]
        if parent_sha is not None:
            cmd.extend(["-p", parent_sha])

        env = os.environ.copy()
        env["GIT_AUTHOR_NAME"] = author_name
        env["GIT_AUTHOR_EMAIL"] = author_email
        env["GIT_COMMITTER_NAME"] = author_name
        env["GIT_COMMITTER_EMAIL"] = author_email
        env["GIT_AUTHOR_DATE"] = ts_str
        env["GIT_COMMITTER_DATE"] = ts_str

        proc = subprocess.run(
            cmd,
            input=commit_msg,
            cwd=repo_dir,
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )
        new_sha = proc.stdout.strip()
        parent_sha = new_sha

        first_line = commit_msg.splitlines()[0] if commit_msg else ""
        print(f"[{idx + 1:2d}/{total_commits}] {old_sha[:7]} -> {new_sha[:7]} | {ts.strftime('%Y-%m-%d %H:%M')} | {first_line}")

    # Point branch to new head
    print(f"\nUpdating HEAD to new root {parent_sha}...")
    subprocess.run(["git", "reset", "--hard", parent_sha], cwd=repo_dir, check=True)
    print("History rewrite complete.")


if __name__ == "__main__":
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rewrite_commits(repo_root)
