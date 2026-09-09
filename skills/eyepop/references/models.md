# Pretrained models and abilities

Every pretrained model is referenced by alias with a tag, `eyepop.person:latest`, from `eyepop run --model`, an `InferenceComponent` in a Pop, or `eyepop create deployment --model`. A custom trained model is referenced by its UUID. `eyepop get models` lists what your account can run; this page is the commonly used subset with label sets. The full searchable catalog, including community and structured-OCR abilities, is the Abilities Hub at https://www.eyepop.ai/abilities.

## Object detection and classification

| Alias | Detects | Labels |
|---|---|---|
| `eyepop.common-objects:latest` | Everyday objects | `person, eyepop logo, bicycle, car, motorcycle, airplane, bus, train, truck, boat, traffic light, fire hydrant, stop sign, parking meter, cat, dog, horse, umbrella, handbag, suitcase, sports ball, baseball bat, baseball glove, skateboard, surfboard, tennis racket, bottle, wine glass, cup, bowl, hot dog, chair, couch, potted plant, bed, dining table, toilet, tv, microwave, sink, refrigerator, book, laptop, mouse, remote, keyboard, cell phone, clock, scissors, hair drier, toothbrush` |
| `eyepop.animal:latest` | Animals | `bird, cat, dog, horse, sheep, cow, elephant, bear, zebra, giraffe` |
| `eyepop.vehicle:latest` | Vehicles | `bicycle, car, motorcycle, bus, train, truck` |
| `eyepop.vehicle.license-plate:latest` | License plates, usually on a vehicle crop | `license-plate` |
| `eyepop.device:latest` | Electronic devices | `clock, laptop, mouse, remote, keyboard, cell phone` |
| `eyepop.sports:latest` | Sports equipment | `frisbee, skis, snowboard, sports ball, kite, baseball bat, baseball glove, skateboard, surfboard, tennis racket` |
| `eyepop.localize-objects:latest` | Objects named in a prompt, no fixed label set | open vocabulary; takes `params={"prompts": [{"prompt": "person"}]}` in a Pop |

## Person analysis

| Alias | Returns |
|---|---|
| `eyepop.person:latest` | Person boxes, label `person` |
| `eyepop.expression:latest` | Facial expression: `Happy, Neutral, Sad, Surprise, Angry, Fear, Disgust` |
| `eyepop.person.pose:latest` | Human pose |
| `eyepop.person.2d-body-points:latest` | 2D keypoints: eyes, ears, shoulders, hips, elbows, wrists, knees, ankles, nose, `midpoint_lowest`, `midpoint_highest` |
| `eyepop.person.3d-body-points.full:latest` / `.heavy` / `.lite` | 3D body pose at three sizes |
| `eyepop.person.3d-hand-points:latest` | 3D hand keypoints |
| `eyepop.person.face-mesh:latest` | Facial mesh |
| `eyepop.person.face.long-range:latest` / `.short-range` | Face boxes for distant or close subjects |
| `eyepop.person.palm:latest` | Palm boxes |
| `eyepop.person.reid:latest` | Re-identification embedding; name it from a tracking component |
| `eyepop.person.segment:latest` | Person segmentation mask |

## Text

| Alias | Returns |
|---|---|
| `eyepop.text:latest` | Text region boxes |
| `eyepop.text.recognize.landscape:latest` | OCR for landscape text, the usual choice after a plate or label crop |
| `eyepop.text.recognize.landscape-tiny:latest` | Lighter landscape OCR |
| `eyepop.text.recognize.square:latest` | OCR for square and document text |

Structured OCR abilities that return typed fields (driver's license, invoice, and so on) live in the Abilities Hub; list yours with `eyepop get abilities -q ocr`.

## Segmentation

| Alias | Returns |
|---|---|
| `eyepop.sam.small:latest` | Segmentation masks, usually run on a detection crop |

## Choosing

- People, vehicles, animals, common objects: a detection **model** above, the cheapest and fastest path.
- Anything described in words (count helmets, read the total on a receipt, is the shelf empty): an **ability**, either one from the Hub or one you create with `eyepop create ability`.
- Two stages (find plates, then read them; find people, then classify each): a **Pop** that forwards crops, see [python-sdk.md](python-sdk.md#composable-pops) or [node-sdk.md](node-sdk.md#composable-pops).

Docs page: https://docs.eyepop.ai/developer-documentation/platform/abilities/pretrained-models-and-abilities
