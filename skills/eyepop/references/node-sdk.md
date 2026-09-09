# Node SDK

For building a Node, browser, or React Native application. Everyday inference stays on the CLI (`eyepop run ... --json`); a service, a UI, or a live camera is what brings you here.

`npm install --save @eyepop.ai/eyepop` for Node and TypeScript. Docs: https://docs.eyepop.ai/developer-documentation/sdks/node (Configuration, Running Inference, Composable Pops, Visualization). Package source and the full component reference: https://github.com/eyepop-ai/eyepop-sdk-node.

| Runtime | Install |
|---|---|
| Node | `npm install --save @eyepop.ai/eyepop` |
| Browser | `<script src="https://cdn.jsdelivr.net/npm/@eyepop.ai/eyepop/dist/eyepop.min.js"></script>` |
| React Native | `npm install --save @eyepop.ai/react-native-eyepop react-native-canvas react-native-file-access@3.1.1 react-native-tcp-socket react-native-webrtc` |

## First call

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

`process()` resolves to a `ResultStream`, an `AsyncIterable` of predictions: one for an image, one per frame for video or a live stream. Disconnect in `finally`, and reuse one connected endpoint for many sources. Pass the Pop at construction; `endpoint.changePop(pop)` swaps it on a connected endpoint. A Pop is sent by value; `popId` is deprecated and resolves nothing.

## Credentials and sessions

`EYEPOP_API_KEY` in the server environment is read automatically. Credentials and session options go at the **top level** of the endpoint options: `apiKey`, `accessToken`, `session`, `sessionUuid`, `isLocalMode`; the nested `auth` option is deprecated.

| Options | Session |
|---|---|
| `pop`, no session UUID | **Transient**: created on connect, its pipeline deleted on disconnect |
| Neither | Reuses your first live non-persistent session, else creates one |
| `sessionUuid` or `EYEPOP_SESSION_UUID`, no `pop` | Attaches to a persistent **deployment** created with `eyepop create deployment`; the Pop came with it |

Browser and mobile clients never hold the key: create the session on a trusted backend, hand the client the session JSON, and connect with `session`. Deployments need a plan that includes them; a `403` on create means the current plan does not.

## Submitting media

| Source | `process()` argument |
|---|---|
| Local file | `{ source: { path: 'image.jpg' } }` |
| Readable stream, MIME type required | `{ source: { stream: Readable.toWeb(fs.createReadStream('a.jpg')), mimeType: 'image/jpeg' } }` |
| Browser `File` from an input | `{ source: { file } }` |
| HTTP(S) URL, fetched by the platform | `{ source: { url: 'https://example.com/video.mp4' } }` |
| RTSP or RTMP camera, always live | `{ source: { url: 'rtsp://user:password@camera/stream1' } }` |
| Image group, one prediction for the set | `endpoint.uploadGroup([...])`, `uploadStreamGroup([...], [mimeTypes])`, `loadFromGroup([...])` |

Stop a video or stream from inside the loop with `results.cancel()`.

Per-source options sit beside `source`: `fps: '1/1'` (fraction string, frames per second run through the Pop; saves inference, not bandwidth), `roi: { type: AreaType.RECTANGLE, x, y, width, height }`, `videoMode: VideoMode.STREAM` on the source object (process an upload while it uploads; buffered uploads cap at 1 GiB), `isLive`, and motion gating. Scene options that every source should share go on the Pop:

```typescript
pop: {
    components: [{ type: PopComponentType.INFERENCE, ability: 'eyepop.person:latest' }],
    defaults: { fps: '1/1', roi: { type: AreaType.RECTANGLE, x: 160, y: 0, width: 320, height: 480 }, motionDetect: true },
}
```

## Composable Pops

Each inference component can forward its detections. `ForwardOperatorType.CROP` passes each crop, `FULL` the whole image, `CROP_WITH_FULL_FALLBACK` a crop when there is one. Component `type` strings: `inference`, `forward`, `tracking`, `contour_finder`, `component_finder`.

```typescript
import { EyePop, ForwardOperatorType, PopComponentType } from '@eyepop.ai/eyepop'

const endpoint = await EyePop.workerEndpoint({
    pop: {
        components: [{
            type: PopComponentType.INFERENCE,
            ability: 'eyepop.vehicle:latest',
            categoryName: 'vehicles',
            confidenceThreshold: 0.8,
            forward: {
                operator: { type: ForwardOperatorType.CROP },
                targets: [{
                    type: PopComponentType.INFERENCE,
                    ability: 'eyepop.vehicle.license-plate:latest',
                    forward: {
                        operator: { type: ForwardOperatorType.CROP },
                        targets: [{
                            type: PopComponentType.INFERENCE,
                            ability: 'eyepop.text.recognize.landscape:latest',
                            categoryName: 'license-plate',
                        }],
                    },
                }],
            },
        }],
    },
}).connect()
```

- Name a model with `ability: '<alias>:<tag>'` or, for a dashboard-trained model, `abilityUuid`. `model` and `modelUuid` are deprecated spellings.
- A custom VLM ability carries its prompt server-side; reference it by alias and send no prompt. `eyepop.localize-objects:latest` is the open-vocabulary exception and takes `params: { prompts: [{ prompt: 'person' }] }`.
- A `tracking` component beside the second inference inside the crop targets gives each object a stable `trackId`; feed it one video or stream, since tracking state resets between separate uploads.

## Reading results

Boxes are top-left `x, y, width, height` in source pixels; video frames carry `seconds`.

| The ability | Field |
|---|---|
| Detection | `objects[]` with `classLabel`, `confidence`, box, `trackId` when tracking |
| Custom `<ns>.image-classify.<name>` | `classes[0].classLabel` |
| Custom `<ns>.describe.<name>` | `texts[0].text` |
| Crop-forwarded stages | nested under the parent: `objects[*].classes`, `objects[*].texts` |
| Keypoints | `keyPoints[].points[]` |

The wrong field is an empty array, never an error; print one sample prediction before writing parsing code for a model you have not run before.

## Visualization

```bash
npm install --save @eyepop.ai/eyepop @eyepop.ai/eyepop-render-2d canvas
```

```typescript
import { Render2d } from '@eyepop.ai/eyepop-render-2d'

const renderer = Render2d.renderer(context, [Render2d.renderBox({ showClass: true, showConfidence: true })])
for await (const result of results) {
    renderer.draw(result)
}
```

Renderers compose: pass several to draw boxes, poses, and contours on one canvas. In a browser take the context from a DOM canvas and pass `source: { file }`.

## Data endpoint

`EyePop.dataEndpoint(...)` manages datasets and VLM abilities from Node: `listVlmAbilities()`, `getVlmAbility(uuid)`, `createVlmAbility(create, groupUuid)`, `updateVlmAbility(uuid, update)`, `deleteVlmAbility(uuid)`, `publishVlmAbility(uuid, aliasName, tagName)`, `listVlmAbilityGroups()`, `listVlmAbilityEvaluations(uuid)`. Registering an ability is create group, create ability, publish with the alias, tag `latest`; naming rules and result shapes are the same as in [python-sdk.md](python-sdk.md#data-endpoint-datasets-ground-truth-and-vlm-abilities).

## Local mode (on-premise instance)

```typescript
const endpoint = await EyePop.workerEndpoint({ isLocalMode: true, pop }).connect()
```

Talks to `http://127.0.0.1:8080` and always that port; `EYEPOP_LOCAL_MODE=true` selects it from the environment. An `EYEPOP_API_KEY` still in the environment is sent along; unset it to connect anonymously. See [on-premise.md](on-premise.md).

## Errors

A thrown connect error that reports a pipeline error means the Pop is invalid (unknown alias, bad component), while `no available server` is capacity or routing and worth a retry. Keep the two apart in error handling.
