# Python and Node SDKs

Both SDKs open a session with a Pop, submit media, and read predictions. The Pop goes in when the session opens, so EyePop schedules the right compute before any media arrives. Credentials come from `EYEPOP_API_KEY` in the environment; the key belongs on a server, never in a browser or mobile bundle.

Docs: https://docs.eyepop.ai/developer-documentation/sdks (Python and Node sections cover video, streams, image groups, and visualization).

## Python

```bash
pip install eyepop        # Python 3.12+
```

```python
from eyepop import EyePopSdk
from eyepop.worker.worker_types import InferenceComponent, Pop

pop = Pop(components=[InferenceComponent(ability="eyepop.person:latest")])

with EyePopSdk.sync_worker(pop=pop) as endpoint:
    result = endpoint.upload("photo.jpg").predict()
    print(result)
```

`upload()` queues the file and `predict()` blocks until the result is ready. A video yields one prediction per frame, so loop until `predict()` returns `None`:

```python
with EyePopSdk.sync_worker(pop=pop) as endpoint:
    job = endpoint.load_from("https://example.com/video.mp4")   # the platform fetches the URL
    while result := job.predict():
        print(result)
```

`upload_stream(file, "image/jpeg")` takes an open binary stream. Bulk work uses `EyePopSdk.async_worker(pop=pop)` with `await endpoint.upload(path, on_ready=callback)`.

## Node

```bash
npm install --save @eyepop.ai/eyepop
```

```typescript
import { EyePop, PopComponentType } from '@eyepop.ai/eyepop'

const endpoint = await EyePop.workerEndpoint({
    pop: {
        components: [{ type: PopComponentType.INFERENCE, ability: 'eyepop.person:latest' }],
    },
}).connect()

try {
    const results = await endpoint.process({ source: { path: 'image.jpg' } })
    for await (const result of results) {
        console.log(result)
    }
} finally {
    await endpoint.disconnect()
}
```

`process()` resolves to an `AsyncIterable` of predictions: one for an image, one per frame for video. Sources are `{ path }`, `{ url }`, or `{ stream, mimeType }`. Cancel a video mid-stream with `results.cancel()`. Credentials and session options go at the top level of the endpoint options (`apiKey`, `sessionUuid`, `isLocalMode`); the nested `auth` option is deprecated.

## Sessions

| Options passed | Session |
|---|---|
| `pop`, no session UUID | **Transient**: a new session each connect, its pipeline deleted on exit. The default for building and testing |
| Neither | Reuses an existing non-persistent session when one is available |
| `session_uuid` / `sessionUuid` (or `EYEPOP_SESSION_UUID`), no `pop` | Attaches to a persistent deployment; the Pop was fixed when the deployment was created |

Create the deployment with `eyepop create deployment --model <alias>` and attach with the UUID it prints:

```python
with EyePopSdk.sync_worker(session_uuid="<session-uuid>") as endpoint:
    result = endpoint.upload("photo.jpg").predict()
```

Browser and mobile clients receive a session created on a trusted backend and connect with `session`, so the API key stays server-side.

## Environment variables

| Variable | Meaning |
|---|---|
| `EYEPOP_API_KEY` | The `eyp_...` key. Works with transient Pops and persistent deployments |
| `EYEPOP_SESSION_UUID` | Attach to a persistent deployment |
| `EYEPOP_LOCAL_MODE=true` | Talk to an on-premise instance at `http://127.0.0.1:8080` |
| `EYEPOP_SECRET_KEY` + `EYEPOP_POP_ID` | Named-Pop sessions, the legacy path. `EYEPOP_API_KEY` must be unset here: with both present the Python SDK raises `EYEPOP_API_KEY can only be used with transient pops` |
| `EYEPOP_URL` | Override the API base URL |
| `EYEPOP_LOG_LEVEL` | Log verbosity for the `eyepop` logger tree |

An `eyp_...` key passed as `secret_key=` raises `ValueError`; it is always `api_key=`.

## Local mode (on-premise instance)

Local mode sends no account credentials; reaching the loopback port is the authorization. Pass the Pop the instance serves:

```python
with EyePopSdk.sync_worker(is_local_mode=True, pop=pop) as endpoint:
    result = endpoint.upload("image.jpg").predict()
```

```typescript
const endpoint = await EyePop.workerEndpoint({ isLocalMode: true, pop }).connect()
```

Python takes `eyepop_url="http://127.0.0.1:9090"` for another port; Node local mode always uses port `8080`. Connecting creates a pipeline on the instance and disconnecting removes it, so keep one connected endpoint for many images. See [on-premise.md](on-premise.md) for the instance itself.

## Composable Pops

A Pop chains components: detect, forward each crop, run the next model on the crop. `CropForward` passes each detection; `FullForward` passes the whole image; both take `includeClasses` to filter what is forwarded. Vehicle, then plate, then OCR:

```python
from eyepop.worker.worker_types import (
    Pop, InferenceComponent, TrackingComponent, CropForward, MotionModel,
)

pop = Pop(components=[
    InferenceComponent(
        ability="eyepop.vehicle:latest",
        categoryName="vehicles",
        confidenceThreshold=0.8,
        forward=CropForward(targets=[
            TrackingComponent(maxAgeSeconds=5.0, motionModel=MotionModel.CONSTANT_VELOCITY, agnostic=True),
            InferenceComponent(
                ability="eyepop.vehicle.license-plate:latest",
                topK=1,
                forward=CropForward(targets=[
                    InferenceComponent(
                        ability="eyepop.text.recognize.landscape:latest",
                        categoryName="license-plate",
                    ),
                ]),
            ),
        ]),
    ),
])
```

The same shape in Node uses `forward: { operator: { type: ForwardOperatorType.CROP }, targets: [...] }` on each inference component. Open-vocabulary detection is `eyepop.localize-objects:latest` with `params={"prompts": [{"prompt": "person"}]}`, and a custom VLM ability is referenced by its alias like any other. Component types: `InferenceComponent`, `TrackingComponent`, `ContourFinderComponent`, `ComponentFinderComponent`, `ForwardComponent`.

Full component reference: https://docs.eyepop.ai/developer-documentation/sdks/python/composable-pops and https://docs.eyepop.ai/developer-documentation/sdks/node/composable-pops.

## Datasets, ground truth, and registering VLM abilities from Python

`EyePopSdk.dataEndpoint(api_key=..., account_id=...)` creates datasets, uploads or imports assets, sets ground-truth annotations, and registers custom VLM abilities in code. The worked, copy-ready reference is the `customer-sdk` skill in the public Abilities Hub repo: https://github.com/eyepop-ai/abilities-hub/blob/main/claude/SKILL.md
