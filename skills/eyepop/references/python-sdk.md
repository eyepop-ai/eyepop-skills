# Python SDK

`pip install eyepop`, Python 3.12+. Docs: https://docs.eyepop.ai/developer-documentation/sdks/python (Configuration, Running Inference, Composable Pops, Data Endpoint). Package source: https://github.com/eyepop-ai/eyepop-sdk-python.

## Entry points

| Need | Call |
|---|---|
| One-shot script, single images | `EyePopSdk.sync_worker(pop=pop)` as a `with` block |
| Video, batches, anything I/O-bound | `EyePopSdk.async_worker(pop=pop)` as an `async with` block; `predict()` yields while the worker runs the next frame |
| Datasets, ground truth, VLM ability registration | `EyePopSdk.dataEndpoint(api_key=..., account_id=...)`; management only, never inference |

Pass `pop=` when the session opens so EyePop schedules the right compute before any media arrives; `endpoint.set_pop(pop)` swaps it on a connected endpoint. A Pop is a document sent by value; looking one up by UUID (`pop_id`) is deprecated and returns nothing useful.

```python
from eyepop import EyePopSdk
from eyepop.worker.worker_types import InferenceComponent, Pop

pop = Pop(components=[InferenceComponent(ability="eyepop.person:latest")])

with EyePopSdk.sync_worker(pop=pop) as endpoint:
    result = endpoint.upload("photo.jpg").predict()
    print(result)
```

## Credentials and sessions

`EYEPOP_API_KEY` in the environment is read automatically; `api_key="eyp_..."` passes it explicitly. Load a `.env` with `load_dotenv(path, override=True)`, since a stale shell variable otherwise wins silently. An `eyp_` key passed as `secret_key=` raises `ValueError`; `secret_key` is only for the legacy named-Pop path (`EYEPOP_SECRET_KEY` + `EYEPOP_POP_ID`), and with `EYEPOP_API_KEY` also set that path raises `EYEPOP_API_KEY can only be used with transient pops`.

| Call | Session |
|---|---|
| `sync_worker(pop=pop)` | **Transient**: created on connect, its pipeline deleted on exit. Right for building, testing, batch jobs |
| `sync_worker()` with no `pop` | Reuses an existing non-persistent session when one exists |
| `sync_worker(session_uuid="...")` or `EYEPOP_SESSION_UUID` | Attaches to a persistent **deployment**; the Pop was fixed when `eyepop create deployment` made it, so pass none |

Deployments are capped at 10 per user and need a paid plan; a `403` on create means the account is on the free tier. Other variables: `EYEPOP_ACCOUNT_ID` (needed by some Data API calls), `EYEPOP_URL`, `EYEPOP_LOG_LEVEL`, `EYEPOP_LOCAL_MODE`.

## Submitting media

| Source | Call |
|---|---|
| Local file | `endpoint.upload("photo.jpg")` |
| Open binary stream | `endpoint.upload_stream(file, "image/jpeg")` |
| HTTP(S) URL, fetched by the platform | `endpoint.load_from("https://example.com/image.jpg")` |
| RTSP or RTMP camera, always live (frames drop rather than queue) | `endpoint.load_from("rtsp://user:password@camera/stream1")` |
| Image group, one prediction for the set | `endpoint.upload_group([...])`, `upload_stream_group([...])`, `load_from_group([...])` |

Each call returns a job. `job.predict()` blocks for the next prediction and returns `None` when the source is exhausted, so a video or live stream is a loop; `job.cancel()` stops it.

```python
with EyePopSdk.sync_worker(pop=pop) as endpoint:
    job = endpoint.load_from("https://example.com/video.mp4", fps="1/1")
    while result := job.predict():
        print(result["seconds"], len(result.get("objects", [])))
```

Batch independent images by queueing uploads first, then reading each `predict()`. Async form with callbacks:

```python
async with EyePopSdk.async_worker(pop=pop) as endpoint:
    for path in paths:
        await endpoint.upload(path, on_ready=lambda job: print(job.predict()))
```

Per-source options, all keyword arguments on `upload` / `load_from`:

| Option | Effect |
|---|---|
| `fps="1/1"` | Fraction string; frames per second run through the Pop. Drops frames after decode, so it cuts inference, not bandwidth |
| `roi=RectangleArea(x, y, width, height)` | Crop every frame before inference |
| `video_mode=VideoMode.STREAM` | Process an uploaded video while it uploads; buffered uploads (the default) cap at 1 GiB |
| `is_live=True` | Treat an uploaded stream as real time |
| motion detection (`motionDetect`, `motionSensitivity`, ...) | Pause inference while the scene is still |

Set scene options once for every source with `Pop(defaults=SourceDefaults(fps="1/1", roi=..., motionDetect=True))`.

## Composable Pops

Detect, forward each crop, run the next model on the crop. `CropForward` passes each detection, `FullForward` the whole image; both take `includeClasses`.

```python
from eyepop.worker.worker_types import (
    Pop, InferenceComponent, TrackingComponent, CropForward, MotionModel,
)

pop = Pop(components=[
    InferenceComponent(
        ability="eyepop.vehicle:latest",
        categoryName="vehicles",
        confidenceThreshold=0.8,          # gate the forward so weak boxes skip the slow stage
        forward=CropForward(targets=[
            TrackingComponent(maxAgeSeconds=5.0, motionModel=MotionModel.CONSTANT_VELOCITY, agnostic=True),
            InferenceComponent(
                ability="eyepop.vehicle.license-plate:latest",
                topK=1,
                forward=CropForward(targets=[
                    InferenceComponent(ability="eyepop.text.recognize.landscape:latest", categoryName="license-plate"),
                ]),
            ),
        ]),
    ),
])
```

- Name a model with `ability="<alias>:<tag>"` or, for a model trained in the dashboard, `abilityUuid="<uuid>"`. The two are mutually exclusive; `model` and `modelUuid` are deprecated spellings.
- A custom VLM ability carries its prompt server-side: reference it by alias and send no prompt at inference. The exception is `eyepop.localize-objects:latest`, an open-vocabulary detector that takes `params={"prompts": [{"prompt": "person"}]}`.
- `TrackingComponent` sits beside the second inference inside `CropForward.targets` and gives each object a stable `trackId` across frames. Tracking state lives in the endpoint, so feed it one `upload(video)` or `load_from(rtsp)`; uploading extracted frames one by one resets it.
- `InferenceComponent(targetFps=...)` rates one component; `fps` on the source rates the whole Pop.
- Component types: `InferenceComponent`, `TrackingComponent`, `ContourFinderComponent`, `ComponentFinderComponent`, `ForwardComponent`.

## Reading results

One prediction per image, or per frame (`seconds`) for video. Boxes are top-left `x, y, width, height` in source pixels.

| The ability | Result field |
|---|---|
| Detection (`eyepop.person`, `eyepop.vehicle`, ...) | `objects[]` with `classLabel`, `confidence`, box, and `trackId` when tracking |
| Custom `<ns>.image-classify.<name>` | `classes[0].classLabel` |
| Custom `<ns>.describe.<name>` | `texts[0].text` |
| OCR after a crop | nested: `objects[*].texts[*].text` |
| Keypoints | `keyPoints[].points[]` |
| Crop-forwarded classification | nested: `objects[*].classes[0].classLabel` |

Read the field the ability produces; the wrong field is an empty list, never an error. For a trained model referenced by UUID, print one sample prediction before writing parsing code.

Long jobs: write each prediction as one JSON line to a sidecar `.jsonl` and skip inference when the file exists. Delete it when the Pop, the `fps`, or the source changes.

## Data endpoint: datasets, ground truth, VLM abilities

```python
from eyepop import EyePopSdk
from eyepop.data.data_types import DatasetCreate, AssetImport, Prediction, PredictedClass

with EyePopSdk.dataEndpoint(api_key=API_KEY, account_id=ACCOUNT_UUID) as data:
    dataset = data.create_dataset(DatasetCreate(name="helmets", tags=["safety"]))

    with open("image.jpg", "rb") as f:
        asset = data.upload_asset_job(f, mime_type="image/jpeg", dataset_uuid=dataset.uuid).result()
    while data.get_asset(asset.uuid, dataset_uuid=dataset.uuid).status != "accepted":
        time.sleep(1)                                   # the transform worker must accept it first

    asset = data.import_asset_job(AssetImport(url="https://example.com/a.jpg"), dataset_uuid=dataset.uuid).result()

    data.update_asset_ground_truth(
        asset_uuid=asset.uuid, dataset_uuid=dataset.uuid,
        ground_truth=Prediction(source_width=1920, source_height=1080,
                                classes=[PredictedClass(classLabel="helmet", confidence=1.0)]),
    )
    for a in data.list_assets(dataset_uuid=dataset.uuid, include_annotations=True):
        print(a.uuid, a.status)
```

`is_async=True` gives the awaitable form. A dataset has one editable draft version; `eyepop get datasets <name> --version N` reads a frozen one.

Registering a custom VLM ability in code is four calls, and the alias is what a Pop references afterwards:

```python
from eyepop.data.data_types import (
    VlmAbilityGroupCreate, VlmAbilityCreate, TransformInto, InferRuntimeConfig,
)

NAME = f"{NAMESPACE}.image-classify.helmet"     # <namespace>.<task>.<name>

with EyePopSdk.dataEndpoint(api_key=API_KEY, account_id=ACCOUNT_UUID) as data:
    if any(a.name == NAME for a in data.list_vlm_abilities()):
        raise SystemExit("already registered; delete the old group first or reuse it")
    group = data.create_vlm_ability_group(VlmAbilityGroupCreate(
        name=NAME, description="Helmet or no helmet on a person crop", default_alias_name=NAME))
    ability = data.create_vlm_ability(
        create=VlmAbilityCreate(
            name=NAME, description="Helmet or no helmet on a person crop",
            worker_release="qwen3-instruct",
            text_prompt='Is the person wearing a safety helmet? Return exactly one label from: ["helmet", "no_helmet"].',
            transform_into=TransformInto(classes=["helmet", "no_helmet"]),
            config=InferRuntimeConfig(max_new_tokens=10, image_size=512),
            is_public=False),
        vlm_ability_group_uuid=group.uuid)
    ability = data.publish_vlm_ability(ability.uuid, alias_name=NAME)
    ability = data.add_vlm_ability_alias(ability.uuid, alias_name=NAME, tag_name="latest")
```

- `NAMESPACE` is the account's namespace prefix, generated from the account email at signup (for `jane@acme.com`, `acme-com`; a collision appends the local part). An alias outside it is rejected without naming the prefix; read an existing alias from `eyepop get abilities --mine` to see yours.
- The `<task>` segment picks the result shape: `image-classify` answers in `classes`, `describe` in `texts`. Other task words have no defined shape.
- `max_new_tokens` around 10 for a label, around 350 for a description. `image_size` 512 for most crops.
- Registration is not idempotent: check `list_vlm_abilities()` first, and delete the old group before re-registering.
- A freshly published alias can take a minute to resolve on a worker. Retry `set_pop` when the error mentions model uuids not found or an unresolved alias.

Experimental Data API calls, subject to change: `infer_asset(asset_uuid, InferRequest(text_prompt=...))` and `evaluate_dataset(EvaluateRequest(dataset_uuid=..., infer=InferRequest(...)))`. The CLI's `eyepop evaluate` is the stable path.

## Local mode (on-premise instance)

```python
with EyePopSdk.sync_worker(is_local_mode=True, pop=pop) as endpoint:
    result = endpoint.upload("image.jpg").predict()
```

Talks to `http://127.0.0.1:8080` with no account credentials; `eyepop_url="http://127.0.0.1:9090"` for another port, `EYEPOP_LOCAL_MODE=true` to select it from the environment. Use it only when the user wants on-device inference; the cloud endpoint is the default. `abilityUuid` works locally once the instance has fetched the bundle. See [on-premise.md](on-premise.md).

## Errors

- A session error carrying `SESS_007` or a `pipeline_error` means the Pop is invalid (an unknown alias, a bad component). `no available server` means capacity or routing, a different problem; retry that one.
- `Compute API endpoint (https://compute.eyepop.ai) requires EYEPOP_API_KEY`: an `access_token` was given where the Compute API wants an API key. Deployments need `api_key`.
