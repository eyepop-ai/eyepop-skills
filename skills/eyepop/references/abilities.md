# Abilities and evaluation

An **ability** is a prompt, an optional fixed label set, and runtime config (`image_size`, `fps`, token limits), run by the shared vision-language model. Every ability is referenced by its **alias**, `<namespace>.<task>.<name>:latest`, in the CLI, in an SDK Pop, and in a deployment alike. Aliases are the way to name things on EyePop; UUIDs exist for a trained model that has no alias yet.

## Create

```bash
eyepop create ability --name helmet \
  --description "Flags people without a safety helmet on a construction site" \
  --prompt 'Determine whether the person is wearing a safety helmet. Return exactly one label from: ["helmet", "no_helmet"].' \
  --class helmet --class no_helmet \
  --image-size 512 --publish
```

- The prompt names the task and constrains the output. `Analyze the image` yields inconsistent labels, verbose text, and higher cost.
- `--class` (repeatable) pins the label set the raw answer is mapped into. Without classes the answer is free text.
- `--image-size` is the main cost and speed lever: 512-640 for detection and video events, 768-1024 for documents. `--fps` samples video: 1-3 industrial, 2-5 events, 5-10 sports. `--max-new-tokens` around 10 for a label, around 350 for a description.
- The backing model is the shared default and is not selectable.
- `--publish` publishes the ability under the account's namespace and prints its alias. Copy the alias from the output, or later from the ALIAS column of `eyepop get abilities --mine`. A published ability is immutable.

The `<task>` segment of the alias says what the ability returns: `classify` answers with a label in `classes[0].classLabel`, `describe` with text in `texts[0].text`, `find-events` with events in video.

## Test

```bash
eyepop run --model <your-namespace>.classify.helmet:latest --media-path sample.jpg --json
```

The alias runs the ability as a pipeline with its own prompt, so `--prompt` is refused there. A prompted, one-off run names the ability by its bare name or UUID instead, which is the cheap way to try wordings before creating the next version:

```bash
eyepop run --model helmet --media-path sample.jpg --prompt 'Try a different wording' --no-cache
```

`--no-cache` forces fresh inference on that prompted run; without it a repeated image can answer from cache. Print one result and read the field the ability fills.

## Iterate

There is no `patch ability` and a published ability is immutable. Create the next version under a new name, test it, then `eyepop delete ability <old-name-or-uuid>`. `eyepop get abilities -q helmet` finds every version; `eyepop get groups` lists ability groups.

## Aliases

- An alias must start with the account's **namespace prefix**. A rejection never names the prefix; read it off any existing alias in `eyepop get abilities --mine` or in the dashboard.
- A Python application that owns its ability registers it from code, which publishes with the alias and tags `latest` in one run: `assets/register_ability.py`, explained in [python-sdk.md](python-sdk.md#data-endpoint-datasets-ground-truth-vlm-abilities).

## Evaluate against ground truth

An evaluation runs an ability over the accepted assets of a dataset and compares each result with that asset's ground truth.

```bash
eyepop create dataset --name helmets --media-path ./images --recursive --partition test
eyepop get assets --dataset helmets
```

- One command creates the dataset and uploads media; `eyepop create asset --dataset helmets --media-path ./more --partition test` adds more later. A partition is assigned at upload, so name the split you will score.
- An asset must reach status `accepted` before it can be annotated.
- Uploading creates no ground truth. Annotate in the dashboard, or from Python with `update_asset_ground_truth`: a classification ground truth is `Prediction(classes=[PredictedClass(classLabel=..., confidence=1.0)])`; a detection ground truth is `objects` with top-left `x, y, width, height` in source pixels.
- A dataset has one editable draft version; frozen versions are addressed as `helmets@3`. `eyepop get datasets helmets --version 3` reads one.

```bash
eyepop evaluate --ability <your-namespace>.classify.helmet:latest --dataset helmets --partition test
eyepop evaluate --ability <your-namespace>.classify.helmet:latest --dataset helmets --filter-class helmet --no-wait
eyepop get evals <request_id> --watch
eyepop get evals --ability <your-namespace>.classify.helmet:latest
eyepop get evals --dataset helmets --filter status=completed
```

- `--ability` takes an alias, name, or UUID; `--dataset` a name or UUID; `--partition` and `--filter-class` repeat.
- The CLI polls for at least 20 seconds and prints the metrics when the run finishes in that window; otherwise it prints a request ID. `--timeout` above 20 waits longer; `--no-wait` returns at once.
- A run over a dataset with no accepted assets, or no ground truth, completes with `metrics: {}` and zero counts in `run_info`; check `eyepop get assets --dataset <name>` first.
- **All-zero metrics with no error on a dataset that does have annotated assets** means every asset hit the server's per-asset time limit, which a long video exhausts. Creating a new ability with the same prompt changes nothing. Split the videos into shorter assets, evaluate images, or create the ability with a lower `--fps` so fewer frames are sampled; `eyepop evaluate` itself has no frame-rate flag.
- `--video-chunk-length` (nanoseconds) and `--video-chunk-overlap` (0.0-1.0) shape how video assets are scored.
