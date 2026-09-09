"""Detect objects, then classify each detection with your own ability.

    pip install eyepop python-dotenv
    python crop_classify.py ./photos eyepop.vehicle:latest your-namespace.image-classify.vehicle-type:latest

The detection model finds the objects; every crop is forwarded to the classify ability, and its
label appears nested under the parent object. Register the classify ability first
(register_ability.py) so the alias resolves.
"""

import asyncio
import sys
from pathlib import Path

from dotenv import load_dotenv
from eyepop import EyePopSdk
from eyepop.worker.worker_types import CropForward, InferenceComponent, Pop

load_dotenv(Path(__file__).parent / ".env", override=True)

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


async def main(folder: Path, detector: str, classifier: str) -> None:
    pop = Pop(components=[
        InferenceComponent(
            ability=detector,
            confidenceThreshold=0.5,      # only confident detections reach the classifier
            forward=CropForward(targets=[InferenceComponent(ability=classifier)]),
        )
    ])
    images = sorted(p for p in folder.rglob("*") if p.suffix.lower() in IMAGE_SUFFIXES)

    async with EyePopSdk.async_worker(pop=pop) as endpoint:
        for image in images:
            job = await endpoint.upload(str(image))
            result = await job.predict()
            for obj in result.get("objects") or []:
                label = (obj.get("classes") or [{}])[0].get("classLabel", "?")
                print(f"{image.name}: {obj['classLabel']} -> {label} ({obj.get('confidence', 0):.2f})")


if __name__ == "__main__":
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("photos")
    detector = sys.argv[2] if len(sys.argv) > 2 else "eyepop.vehicle:latest"
    classifier = sys.argv[3] if len(sys.argv) > 3 else "your-namespace.image-classify.vehicle-type:latest"
    asyncio.run(main(folder, detector, classifier))
