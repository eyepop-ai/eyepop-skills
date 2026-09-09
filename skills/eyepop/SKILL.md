---
name: eyepop
description: Run EyePop.ai computer vision from the terminal or code. Install and sign in to the eyepop CLI, pick a model, ability, or Pop, run inference on images, video, URLs, or directories, read the JSON result, keep a deployment warm, build a dataset and evaluate an ability, or stand up an on-premise instance; Python and Node SDK quickstarts. Use when a task mentions EyePop, eyepop run, an eyepop.*:latest alias, EYEPOP_API_KEY, a Pop or ability, or detecting objects, people, text, or vehicles in images or video.
metadata:
  author: eyepop-ai
---

# EyePop

EyePop.ai turns images, video, and live streams into structured JSON. One vocabulary runs through the CLI, both SDKs, and the docs:

| Word | Meaning | Find yours |
|---|---|---|
| **model** | Pretrained alias with a tag: `eyepop.person:latest` | `eyepop get models` |
| **ability** | A model plus a prompt and a fixed set of output classes; how a VLM task runs | `eyepop get abilities` |
| **Pop** | A pipeline of one or more models or abilities, built-in (`people-common-objects`) or saved (a UUID) | `eyepop get pops` |
| **target** | What a run uses: `--model`, `--pop`, or `--session`. Exactly one per run, and positional arguments are always media | |
| **session** / **deployment** | Compute running a Pop. A deployment is a session kept warm behind a stable UUID | `eyepop get deployments` |
| **instance** | The EyePop runtime installed on hardware you control | `eyepop get instances` |
| **dataset** | Named media with ground truth, scored by `eyepop evaluate` | `eyepop get datasets` |

Flags come from the binary: `eyepop <command> --help` is authoritative. The CLI is in beta, so pin a version in anything automated. Full docs at https://docs.eyepop.ai, indexed for agents at https://docs.eyepop.ai/llms.txt.

## Run inference from the terminal

### 1. Install

macOS or Linux with Homebrew:

```bash
brew tap eyepop-ai/eyepop
brew trust eyepop-ai/eyepop
brew install eyepop
```

Linux or macOS without Homebrew (installs to `~/.local/bin`; set `EYEPOP_VERSION` to pin a release):

```bash
curl -fsSL https://raw.githubusercontent.com/eyepop-ai/homebrew-eyepop/main/install.sh | sh
```

Windows: download `eyepop-v<version>-x86_64-pc-windows-msvc.zip` from https://github.com/eyepop-ai/homebrew-eyepop/releases/latest and put `eyepop.exe` on `PATH`.

Done when `eyepop --version` prints a version. Later, `eyepop update` upgrades a Homebrew install in place and prints the download link for any other install.

### 2. Sign in

Scripts, CI, and agents set the API key. Create one in the dashboard at https://dashboard.eyepop.ai under **API Keys**; it starts with `eyp_` and is shown once.

```bash
export EYEPOP_API_KEY=eyp_...
```

A person at a terminal can use the browser flow instead: `eyepop auth login`, then `eyepop auth status` and `eyepop auth logout`.

Done when `eyepop get models` prints a table. Keep the key in the environment or a `.env` file; `--api-key` works but lands in shell history and process listings.

### 3. Pick a target

```bash
eyepop get models              # pretrained models by alias and tag
eyepop get abilities -q ocr    # published abilities, searchable with -q
eyepop get pops                # built-in and saved Pops
```

Copy the alias straight out of the table. `eyepop.person:latest` detects people; the catalog with label sets is in [references/models.md](references/models.md). A prompt-driven task (describe, count, read a field, classify by description) is an **ability**; an object-detection task is a **model**.

### 4. Run

```bash
eyepop run --model eyepop.person:latest image.jpg
eyepop run --model eyepop.person:latest ./images --recursive --json
eyepop run --model <vlm-ability> image.jpg --prompt "How many people are wearing helmets?"
eyepop run --pop people-common-objects video.mp4
eyepop run --session <session-uuid> https://example.com/frame.jpg
```

Media is a file, a directory, or an HTTP(S) URL; add more as extra positionals or `--media-path`. `--concurrency` (default 4, max 32) runs inputs in parallel. `eyepop tui` is a guided version of the same run.

### 5. Read the result

Add `--json` whenever a program reads the output. One successful file prints a single `{file, response}` record; two or more files, or any failure, prints a batch envelope with `results`, `total`, `success`, `failed`, `failures`, and `pending`. Each `response` is one prediction per image, or per frame for video:

```json
{
  "source_width": 1920,
  "source_height": 1080,
  "objects": [
    { "classLabel": "person", "confidence": 0.95, "x": 100, "y": 50, "width": 80, "height": 200 }
  ]
}
```

Depending on the abilities in the Pop, a prediction also carries fields such as `classes`, `texts`, `keyPoints`, tracking IDs, or a VLM answer. Done when the parsed JSON holds the fields the task asked for.

## Rules the CLI enforces

- One target per run. `run` with no target and no media prints its help.
- `--json` works on every command that prints a table. `eyepop tui` refuses it; `update` and `instance logs` print text; `create deployment` and `patch deployment` print a bare session UUID either way.
- `--no-cache` forces fresh VLM inference; it is refused on `--pop`, `--session`, and any `--model` alias that resolves to a published model.
- Under `EYEPOP_API_KEY` alone, `auth status` reports not logged in and `get accounts` refuses, while reads still span every account you can reach. Pick the account new resources land in with `--account <uuid>` or `EYEPOP_ACCOUNT_UUID`.
- `get` also answers to `ls`, `list`, and `show`, and the common reads drop the verb: `eyepop models`, `eyepop abilities`, `eyepop pops`, `eyepop datasets`.
- Deletes are permanent and prompt; `--yes` skips the prompt.
- API keys are created and revoked in the dashboard only.

## Keep a model warm

A one-off `run` stands up compute per call. An application that runs many times wants a deployment:

```bash
UUID=$(eyepop create deployment --model eyepop.person:latest)   # waits for pipeline_ok, prints the UUID
eyepop run --session "$UUID" image.jpg
eyepop patch deployment "$UUID" --pop ./pop-v2.json               # same UUID and endpoint; requests can fail during the restart
eyepop delete deployment "$UUID" --yes
```

`--pop` on `create deployment` and `patch deployment` takes a saved Pop UUID, a JSON or YAML file, or an inline body. `run --session` and `delete deployment` accept a display name or a UUID prefix of at least 7 characters; `get deployments` and `patch deployment` need the full UUID. SDK clients attach with the same session UUID, see [references/sdk.md](references/sdk.md).

## Create an ability

```bash
eyepop create ability --name helmet-check \
  --prompt 'Determine whether the person is wearing a safety helmet. Return exactly one label from: ["helmet", "no_helmet"].' \
  --class helmet --class no_helmet --publish
eyepop get abilities -q helmet-check      # copy the alias, then run --model <alias>
```

A good prompt names the task and constrains the output; `--class` pins the label set. `--image-size` (512-640 for detection and video events, 768-1024 for documents) and `--fps` for video are the cost levers. Field meanings: https://docs.eyepop.ai/developer-documentation/platform/abilities

## Datasets and evaluation

```bash
eyepop create dataset --name people
eyepop create asset --dataset people --media-path ./images --recursive --partition test
eyepop evaluate --ability my-namespace.find-kittens:latest --dataset people --partition test
eyepop get evals <request_id> --watch
```

Evaluation is asynchronous: the CLI polls for at least 20 seconds (`--timeout` raises it) and otherwise prints a request ID. Uploading media creates assets with no ground truth, so annotate them (dashboard, or the Python data endpoint) before scoring. A dataset is addressed by name, UUID, or version: `people@3`, `people@latest`.

## Branches with their own reference

- **On-premise** — a machine with an instance routes `--pop`, published-model `--model`, and target-less runs to local hardware, and `create deployment` is disabled there: [references/on-premise.md](references/on-premise.md)
- **Python or Node SDK** — transient sessions, persistent deployments, local mode, composable Pops: [references/sdk.md](references/sdk.md)
- **Which model** — the pretrained catalog with label sets: [references/models.md](references/models.md)

## When something fails

| Symptom | Cause | Fix |
|---|---|---|
| Unknown subcommand or flag | Stale binary; the CLI is beta and moves | `eyepop update`, then `eyepop <command> --help` |
| `get accounts` refuses, `auth status` says not logged in | Running under `EYEPOP_API_KEY` alone | Expected; pass `--account <uuid>` to create elsewhere |
| A run bills cloud compute on an on-premise machine | `--model` named a VLM-only ability, which is not on-premise aware | Use `--pop` |
| Instance is not responding | Instance stopped; there is no cloud fallback | `eyepop instance start` |
| Nothing runs, and the dashboard shows no plan | Account has no active plan | Choose a plan in the dashboard; https://docs.eyepop.ai/developer-documentation/pricing |
| Anything else | | `eyepop <command> --help`, https://docs.eyepop.ai/llms.txt, help@eyepop.ai |
