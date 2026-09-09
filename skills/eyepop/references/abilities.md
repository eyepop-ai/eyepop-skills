# Abilities and evaluation

An **ability** is a prompt, an optional fixed label set, and runtime config (`image_size`, `fps`, token limits), run by the shared vision-language model. The CLI and the dashboard create them; `eyepop run --model` and `eyepop evaluate` run them by **name or UUID**. A Pop, in the SDK or a deployment, references an ability only through an **alias** of the form `<namespace>.<task>.<name>:latest`, which is a separate, later step.

## Create

```bash
eyepop create ability --name helmet-check \
  --description "Flags people without a safety helmet on a construction site" \
  --prompt 'Determine whether the person is wearing a safety helmet. Return exactly one label from: ["helmet", "no_helmet"].' \
  --class helmet --class no_helmet \
  --image-size 512 --publish
```

- The prompt names the task and constrains the output. `Analyze the image` yields inconsistent labels, verbose text, and higher cost.
- `--class` (repeatable) pins the label set the raw answer is mapped into. Without classes the answer is free text.
- `--image-size` is the main cost and speed lever: 512-640 for detection and video events, 768-1024 for documents. `--fps` samples video: 1-3 industrial, 2-5 events, 5-10 sports. `--max-new-tokens` around 10 for a label, around 350 for a description.
- The backing model is the shared default and is not selectable.
- `--publish` publishes immediately. A published ability is immutable and, from the CLI, carries **no alias**: it runs by name or UUID, and a Pop cannot reference it until an alias exists (below).
- The command prints the ability's `uuid`, `name`, `status`, and `aliases`. `eyepop get abilities --mine` lists yours with NAME, ALIAS, STATUS, GROUP, PUBLIC columns; `eyepop get abilities <name-or-uuid>` shows one.

Name an ability you intend to alias with the convention the alias will need: `<namespace>.image-classify.<name>` for a label, `<namespace>.describe.<name>` for text.

## Test

```bash
eyepop run --model helmet-check sample.jpg --json
eyepop run --model helmet-check sample.jpg --prompt 'Try a different wording' --no-cache
```

`--model` resolves a pretrained model alias first; anything else is looked up as an ability by name or UUID and runs through VLM inference, polling a `request_id` (`--timeout` per result, default 3600 s). `--prompt` overrides the stored prompt for that run only, which is the cheap way to try wordings before creating the next version. `--no-cache` forces fresh inference; without it a repeated image can answer from cache.

With `--class` the answer is in `classes[0].classLabel`; a free-text ability answers in `texts[0].text`. Print one result and read the field that is filled.

## Iterate

There is no `patch ability` and a published ability is immutable. Create the next version under a new name, test it, then `eyepop delete ability <old-name-or-uuid>`. `eyepop get abilities -q helmet` finds every version; `eyepop get groups` lists ability groups.

## Give it an alias for the SDK

Only a Pop in an SDK application or a deployment needs this; the CLI runs the ability by name. A Pop needs `ability="<alias>:latest"`. Mint the alias in the dashboard for an ability the CLI created. When a Python application owns the ability, register it from code instead, which publishes with the alias and tags `latest` in one run: `assets/register_ability.py`, explained in [python-sdk.md](python-sdk.md#data-endpoint-datasets-ground-truth-and-vlm-abilities).

- The alias must start with the account's **namespace prefix**. The rejection never names the prefix; read it off an existing alias in `eyepop get abilities --mine`, or from any alias the dashboard shows for the account.
- The `<task>` segment sets the result shape a Pop reader expects: `image-classify` in `classes`, `describe` in `texts`.
- A new alias can take a little while to resolve on a worker; retry when the error mentions model uuids not found or an unresolved alias.

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
eyepop evaluate --ability helmet-check --dataset helmets --partition test
eyepop evaluate --ability helmet-check --dataset helmets --filter-class helmet --no-wait
eyepop get evals <request_id> --watch
eyepop get evals --ability helmet-check
eyepop get evals --dataset helmets --filter status=completed
```

- `--ability` and `--dataset` take a name or UUID; `--partition` and `--filter-class` repeat.
- The CLI polls for at least 20 seconds and prints the metrics when the run finishes in that window; otherwise it prints a request ID. `--timeout` above 20 waits longer; `--no-wait` returns at once.
- **All-zero metrics with no error** means every asset hit the server's per-asset time limit, which a long video exhausts, not that the ability found nothing. Creating a new ability with the same prompt changes nothing. Split the videos into shorter assets, evaluate images, or create the ability with a lower `--fps` so fewer frames are sampled; `eyepop evaluate` itself has no frame-rate flag.
- `--video-chunk-length` (nanoseconds) and `--video-chunk-overlap` (0.0-1.0) shape how video assets are scored.
