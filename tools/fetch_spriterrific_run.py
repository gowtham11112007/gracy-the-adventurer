"""Monitor a running Spriterrific job and download all artifacts when finished.

Usage:
    .venv/bin/python tools/fetch_spriterrific_run.py [JOB_ID]
"""
import os
import sys
import time
import json
import subprocess
from pathlib import Path

BASE = os.environ.get("SPRITERRIFIC_API_BASE", "https://courteous-mouse-611.convex.site")
KEY = os.environ.get("SPRITERRIFIC_API_KEY", "")

if not KEY and os.path.exists(".env"):
    for line in open(".env"):
        if line.startswith("SPRITERRIFIC_API_KEY="):
            KEY = line.split("=", 1)[1].strip()
            break

if not KEY:
    print("Error: SPRITERRIFIC_API_KEY is not set.")
    sys.exit(1)

JOB_ID = sys.argv[1] if len(sys.argv) > 1 else "kh722d50mb2p31634w1qx2s32x8g9c0n"
HEADERS = [
    "-H", f"Authorization: Bearer {KEY}",
    "-H", "X-Spriterrific-Skill-Version: 1.4.2"
]


def get_job():
    cmd = ["curl", "-s"] + HEADERS + [f"{BASE}/api/v1/jobs/{JOB_ID}"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return None
    try:
        data = json.loads(res.stdout)
        return data.get("job")
    except Exception as e:
        return None


def main():
    print(f"Monitoring Spriterrific job {JOB_ID}...")
    print(f"Live web page: https://app.spriterrific.com/jobs/{JOB_ID}")

    last_step = None
    while True:
        job = get_job()
        if not job:
            print("Failed to fetch job status, retrying in 15s...")
            time.sleep(15)
            continue

        status = job.get("status")
        progress = job.get("progress")
        current_step = progress.get("stepId") if progress else None

        if current_step != last_step:
            idx = progress.get("index", "?") if progress else "?"
            tot = progress.get("total", "?") if progress else "?"
            print(f"[{time.strftime('%X')}] Step {idx}/{tot}: {current_step} (job status: {status})")
            last_step = current_step

        if status in ("completed", "partial", "failed", "canceled"):
            print(f"\nJob finished with status: {status.upper()}")
            break

        time.sleep(15)

    name = job.get("characterName", "character")
    suffix = JOB_ID[-8:]
    run_dir = Path("spriterrific-runs") / f"{name}-{suffix}"
    run_dir.mkdir(parents=True, exist_ok=True)
    print(f"\nDownloading artifacts into {run_dir}...")

    # Save job.json
    with open(run_dir / "job.json", "w") as f:
        json.dump(job, f, indent=2)

    artifacts = job.get("artifacts", [])
    for art in artifacts:
        art_name = art.get("name")
        url = art.get("url")
        if not url or not art_name:
            continue

        # Map artifact name to local path
        content_type = art.get("contentType", "")
        if art_name == "anchors/anchor-w":
            local_path = run_dir / "anchor-w.png"
        elif art_name == "anchors/candidate":
            local_path = run_dir / "candidate.png"
        elif "/" in art_name:
            action, file_type = art_name.split("/", 1)
            ext = ".png"
            if file_type == "preview" or "gif" in content_type:
                ext = ".gif"
            elif file_type in ("manifest", "frames-index") or "json" in content_type:
                ext = ".json"
            elif file_type == "raw-video" or "mp4" in content_type:
                ext = ".mp4"
            local_path = run_dir / action / f"{file_type}{ext}"
        else:
            ext = ".json" if "json" in content_type else ".png"
            local_path = run_dir / f"{art_name}{ext}"

        local_path.parent.mkdir(parents=True, exist_ok=True)
        print(f"  Downloading {art_name} -> {local_path}...")
        subprocess.run(["curl", "-s", "-o", str(local_path), url])

    print(f"\nAll artifacts downloaded successfully to {run_dir}!")


if __name__ == "__main__":
    main()
