"""Run one ability over a recorded video, sampled at a fixed frame rate, into a JSONL sidecar.

    pip install eyepop python-dotenv
    python video_jsonl.py clip.mp4 eyepop.person:latest 1/1

One JSON line per sampled frame lands in ./output/<video>.jsonl. A rerun reads the file
instead of re-running inference; delete it when the ability, the frame rate, or the video changes.
Tracking components need every frame in order, so leave the frame rate off for those Pops.
"""

import asyncio
import json
import sys
from pathlib import Path

from dotenv import load_dotenv
from eyepop import EyePopSdk
from eyepop.worker.worker_types import InferenceComponent, Pop

load_dotenv(Path(__file__).parent / ".env", override=True)


async def infer_or_load(video: Path, ability: str, fps: str) -> list[dict]:
    cache = Path("output") / f"{video.stem}.jsonl"
    if cache.exists():
        return [json.loads(line) for line in cache.read_text().splitlines()]

    cache.parent.mkdir(exist_ok=True)
    pop = Pop(components=[InferenceComponent(ability=ability)])
    results = []
    async with EyePopSdk.async_worker(pop=pop) as endpoint, cache.open("w") as sidecar:
        job = await endpoint.upload(str(video), fps=fps)
        while result := await job.predict():
            results.append(result)
            sidecar.write(json.dumps(result) + "\n")
    return results


async def main(video: Path, ability: str, fps: str) -> None:
    for frame in await infer_or_load(video, ability, fps):
        print(f"{frame.get('seconds', 0):8.2f}s  {len(frame.get('objects') or [])} objects")


if __name__ == "__main__":
    video = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("clip.mp4")
    ability = sys.argv[2] if len(sys.argv) > 2 else "eyepop.person:latest"
    fps = sys.argv[3] if len(sys.argv) > 3 else "1/1"
    asyncio.run(main(video, ability, fps))
