"""Run one ability over every image in a folder, keeping each result as JSON.

    pip install eyepop python-dotenv
    python batch_folder.py ./photos eyepop.person:latest

Results land in ./output/<image>.json. A rerun skips images that already have one,
so post-processing can change without paying for inference again.
"""

import asyncio
import json
import sys
from pathlib import Path

from dotenv import load_dotenv
from eyepop import EyePopSdk
from eyepop.worker.worker_types import InferenceComponent, Pop

load_dotenv(Path(__file__).parent / ".env", override=True)

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


async def main(folder: Path, ability: str) -> None:
    output = Path("output")
    output.mkdir(exist_ok=True)
    pop = Pop(components=[InferenceComponent(ability=ability)])
    images = sorted(p for p in folder.rglob("*") if p.suffix.lower() in IMAGE_SUFFIXES)

    async with EyePopSdk.async_worker(pop=pop) as endpoint:
        for image in images:
            cache = output / f"{image.stem}.json"
            if cache.exists():
                result = json.loads(cache.read_text())
            else:
                job = await endpoint.upload(str(image))
                result = await job.predict()
                cache.write_text(json.dumps(result, indent=2))
            objects = result.get("objects") or []
            print(f"{image.name}: {len(objects)} objects")


if __name__ == "__main__":
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("photos")
    ability = sys.argv[2] if len(sys.argv) > 2 else "eyepop.person:latest"
    asyncio.run(main(folder, ability))
