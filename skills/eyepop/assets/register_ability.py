"""Register a custom VLM ability once, so Pops can reference it by alias.

    pip install eyepop python-dotenv
    python register_ability.py

Fill in NAMESPACE, TASK, NAME, PROMPT, and CLASSES below, then run it once. It needs
EYEPOP_API_KEY and EYEPOP_ACCOUNT_ID (see env.example). The alias must start with your
account's namespace prefix; copy it from an existing alias in `eyepop get abilities --mine`
or the dashboard. TASK sets the result shape: image-classify answers in classes, describe in texts.
"""

import asyncio
import os
from pathlib import Path

from aiohttp import ClientResponseError
from dotenv import load_dotenv
from eyepop import EyePopSdk
from eyepop.data.data_types import (
    InferRuntimeConfig,
    TransformInto,
    VlmAbilityCreate,
    VlmAbilityGroupCreate,
)
from eyepop.worker.worker_types import InferenceComponent, Pop

load_dotenv(Path(__file__).parent / ".env", override=True)

NAMESPACE = "your-namespace"
TASK = "image-classify"          # or "describe"
NAME = "helmet"
DESCRIPTION = "Whether the person in the crop wears a safety helmet"
PROMPT = 'Determine whether the person is wearing a safety helmet. Return exactly one label from: ["helmet", "no_helmet"].'
CLASSES = ["helmet", "no_helmet"]   # leave empty for a describe ability

ALIAS = f"{NAMESPACE}.{TASK}.{NAME}"
ACCOUNT_UUID = os.environ["EYEPOP_ACCOUNT_ID"]


def register() -> str:
    with EyePopSdk.dataEndpoint(account_id=ACCOUNT_UUID) as data:
        existing = next((a for a in data.list_vlm_abilities() if a.name == ALIAS), None)
        if existing:
            print(f"already registered: {ALIAS} -> {existing.uuid}")
            return existing.uuid

        group = data.create_vlm_ability_group(
            create=VlmAbilityGroupCreate(name=ALIAS, description=DESCRIPTION, default_alias_name=ALIAS)
        )
        ability = data.create_vlm_ability(
            create=VlmAbilityCreate(
                name=ALIAS,
                description=DESCRIPTION,
                worker_release="qwen3-instruct",
                text_prompt=PROMPT,
                transform_into=TransformInto(classes=CLASSES) if CLASSES else TransformInto(),
                config=InferRuntimeConfig(max_new_tokens=10 if CLASSES else 350, image_size=512),
                is_public=False,
            ),
            vlm_ability_group_uuid=group.uuid,
        )
        data.publish_vlm_ability(vlm_ability_uuid=ability.uuid, alias_name=ALIAS)
        data.add_vlm_ability_alias(vlm_ability_uuid=ability.uuid, alias_name=ALIAS, tag_name="latest")
        print(f"registered: {ALIAS}:latest -> {ability.uuid}")
        return ability.uuid


async def wait_until_resolvable(alias: str, attempts: int = 12, wait_seconds: int = 10) -> None:
    """A new alias can take a little while to resolve on a worker. Open a session against it until it does."""
    pop = Pop(components=[InferenceComponent(ability=f"{alias}:latest")])
    for attempt in range(1, attempts + 1):
        try:
            async with EyePopSdk.async_worker(pop=pop):
                print(f"{alias}:latest resolves")
                return
        except ClientResponseError as error:
            if attempt == attempts:
                raise
            print(f"not resolvable yet ({error.status}); retry {attempt}/{attempts} in {wait_seconds}s")
            await asyncio.sleep(wait_seconds)


if __name__ == "__main__":
    register()
    asyncio.run(wait_until_resolvable(ALIAS))
