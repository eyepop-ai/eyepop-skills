---
name: eyepop
description: Run EyePop.ai computer vision from the terminal or code. Checks for the eyepop CLI and installs it for the user's OS, signs in, lists the user's models, abilities, Pops, deployments, and instances and confirms they can run, runs inference on images, video, URLs, or directories and reads the JSON result, creates and tests a VLM ability, builds a dataset and evaluates an ability against ground truth, keeps a deployment warm, operates an on-premise instance, and writes Python or Node SDK code. Use when a task mentions EyePop, eyepop run, an eyepop.*:latest alias, EYEPOP_API_KEY, a Pop or ability, or detecting objects, people, text, or vehicles in images or video, or asks to install the eyepop CLI and walk through a first inference or quickstart.
license: MIT
compatibility: Needs network access to eyepop.ai and the eyepop CLI 0.18.0 or later, which it installs with Homebrew or the curl install script when missing. The SDK paths need Python 3.12+ or Node.
allowed-tools: Bash(eyepop --version) Bash(eyepop get:*) Bash(eyepop auth status:*) Bash(eyepop system:*) Bash(eyepop models:*) Bash(eyepop abilities:*) Bash(eyepop pops:*) Bash(eyepop datasets:*) Read
metadata:
  author: eyepop-ai
  version: "0.2"
---

# EyePop

EyePop.ai turns images, video, and live streams into structured JSON. One vocabulary runs through the CLI, both SDKs, and the docs:

| Word | Meaning | Find yours |
|---|---|---|
| **model** | Pretrained alias with a tag: `eyepop.person:latest` | `eyepop get models` |
| **ability** | A prompt with a fixed label set, run by the shared vision-language model; referenced by its alias | ALIAS column of `eyepop get abilities --mine` |
| **alias** | `<namespace>.<task>.<name>:latest`, how `run --model`, a Pop, and a deployment name an ability; `create ability --publish` prints it | `get abilities`, `get models` |
| **Pop** | A pipeline of one or more models or abilities: a built-in handle (`people-common-objects`), a Pop saved in the dashboard under `<namespace>.<name>:latest`, an ability alias run as a one-stage Pop, or a JSON or YAML document you pass by value | `eyepop get pops`, `assets/` |
| **target** | What a run uses: `--model`, `--pop`, or `--session`. Exactly one per run; media is a flag too, `--media-path`, repeated for more than one | |
| **session** / **deployment** | Compute running a Pop. A deployment is a session kept warm behind a stable UUID | `eyepop get deployments` |
| **instance** | The EyePop runtime installed on hardware you control | `eyepop get instances` |
| **dataset** | Named media with ground truth, scored by `eyepop evaluate` | `eyepop get datasets` |

Everyday inference is a CLI command: one line, no code, JSON out. Reach for an SDK only when the user is building an application in Python or Node, or needs something the CLI cannot do (a live camera, tracking across frames, a custom multi-stage Pop without a deployment, frame-rate throttling, bulk ground truth).

A first-time user who asks to install the CLI and walk through a first inference gets the guided path in [references/quickstart.md](references/quickstart.md): steps 1 and 2 below with an explanation at every stop.

Paths below are relative to this skill's directory. Flags come from the binary: `eyepop <command> --help` is authoritative, and the CLI is in beta, so pin a version in anything automated. Docs at https://docs.eyepop.ai, indexed for agents at https://docs.eyepop.ai/llms.txt.

## 1. Check the machine, offer the install

```bash
scripts/doctor.sh
```

It reports the platform, whether the CLI is installed, which credential is present, and whether the platform answers, then exits `0` ready, `2` CLI missing, `3` no credentials, `4` unreachable. Act on the line it prints:

- **`cli: missing`**: it names the install command for this platform. Tell the user what it will do and run it once they agree, since installing changes their machine. macOS or Homebrew: `brew tap eyepop-ai/eyepop && brew trust eyepop-ai/eyepop && brew install eyepop`. Linux or macOS without Homebrew: the curl script, which installs to `~/.local/bin` (`EYEPOP_VERSION` pins a release). Windows: the zip from https://github.com/eyepop-ai/homebrew-eyepop/releases/latest onto `PATH`. By-hand and pinned installs: [references/cli.md](references/cli.md#install-by-hand-or-pin-a-version).
- **`cli:` older than 0.18.0**: `eyepop update` upgrades a Homebrew install in place; otherwise rerun the curl script, or the by-hand install pinned to the latest tag. Media through `--media-path` works on 0.17.0 too; the unified `--pop` forms need 0.18.0.
- **`auth: none`**: scripts, CI, and agents set `EYEPOP_API_KEY`; the key starts with `eyp_`, is created once under **API Keys** at https://dashboard.eyepop.ai, and lives in the environment or a `.env`, never in a command line. A person at a terminal can run `eyepop auth login` instead.
- **`reachable: no`**: the error line says why. `Token expired` means `eyepop auth login`; otherwise the key or the network.

Done when the script prints `status: READY`.

## 2. See what the user has, and prove it runs

```bash
scripts/inventory.sh          # add json for machine-readable output
```

It lists the pretrained models, the user's own abilities, the Pops, running deployments, on-premise instances, and datasets, each under the command that produced it. Read it before proposing anything: an existing deployment or instance is what the user's application already talks to, and their own abilities are the tasks they have already defined.

Then confirm the account can actually run something. Use media the user names, an HTTP(S) URL they supply, or the sample that ships with the skill:

```bash
eyepop run --model eyepop.person:latest --media-path assets/macgyver.jpg --json   # every account can run this
eyepop run --session <deployment-uuid> --media-path <media> --json                # when a deployment exists
```

Done when a `response` with `source_width` and `source_height` comes back. A response with no `objects` key, or an empty one, is still success: nothing was detected in that media. The sample returns one `person` near confidence 0.95.

## 3. Run inference

Pick the target from the inventory. A prompt-driven task (describe, count, read a field, classify by description) is an **ability**; an object-detection task is a **model**; a multi-stage task is a **Pop**.

```bash
eyepop run --model eyepop.person:latest --media-path image.jpg
eyepop run --model eyepop.person:latest --media-path ./images --recursive --json
eyepop run --model <your-namespace>.classify.helmet:latest --media-path image.jpg
eyepop run --pop people-common-objects --media-path video.mp4
eyepop run --pop <your-namespace>.<name>:latest --media-path image.jpg
eyepop run --pop assets/pop.crop-forward.json --media-path image.jpg
eyepop run --session <session-uuid> --media-path https://example.com/frame.jpg
```

Media goes in `--media-path`: a file, a directory, or an HTTP(S) URL, repeated for more than one. Nothing on `run` is positional. `--concurrency` (default 4, max 32) runs inputs in parallel. `--model` takes an alias from `get models` or the ALIAS column of `get abilities`; an ability's bare name or UUID with `--prompt` is the prompted, one-off VLM run. `eyepop tui` is the guided form of the same run.

Add `--json` whenever a program reads the output. One successful file prints a single `{file, response}` record; two or more files, or any failure, prints `{results, total, success, failed, failures, pending}`. Each `response` is one prediction per image, or per frame for video:

```json
{ "source_width": 1920, "source_height": 1080,
  "objects": [ { "classLabel": "person", "confidence": 0.95, "x": 100, "y": 50, "width": 80, "height": 200 } ] }
```

Which field an ability fills: detection in `objects`, a label in `classes[0].classLabel`, text in `texts[0].text`, crop-forwarded stages nested under their parent object. The wrong field is an empty list, never an error. Done when the parsed JSON holds the field the task asked for.

## 4. Locate an event in time

"When does X happen in this video?" is answered from **still frames**, one at a time, not by
asking an ability about the whole clip:

```bash
scripts/find-event.sh video.mp4 "an explosion or fireball" --label explosion
```

It samples stills across the whole video, looks again at a higher rate around the first one that
shows the event, and prints when the event starts, in seconds with an error bar, plus a contact
sheet to confirm it by eye. `--json` gives the same result to a program. Exit `3` means no frame
showed the event; the script then describes what the video does show, so the wording can be
changed. It needs `ffmpeg` and `ffprobe` on the machine; if they are missing, offer to install
`ffmpeg`, which includes `ffprobe`, the same way as the CLI in step 1.

The first run creates one ability in the user's account, `agent.describe.prompt-carrier`, and
later runs reuse it; tell the user before that first run. A question about a whole clip can miss
a brief event or report the wrong time range; [references/video-events.md](references/video-events.md)
explains why, and how to tune the search.

## Rules the CLI enforces

- One target per run, and media only through `--media-path`; a bare path is refused with `unexpected argument`. `run` with no target and no media prints its help.
- `--pop` takes the same forms on every command that has it (`run`, `create deployment`, `patch deployment`, `instance init`, `instance set pop`): a Pop from `eyepop get pops`, a built-in by its handle (`person`, `people-common-objects`, `vehicles-traffic-cam`) or a saved one by the alias in its POP column, `<your-namespace>.<name>:latest`; an ability alias such as `eyepop.person:latest`, run as a one-stage Pop; or the Pop itself as a JSON or YAML file or inline body (`assets/pop.person.json`, `assets/pop.crop-forward.json`). Pops travel by value, so no command sends a Pop UUID.
- Prefer aliases. `--model eyepop.person:latest` or `--model <your-namespace>.<task>.<name>:latest`; a UUID is the fallback for a trained model that has no alias.
- `--prompt` applies to a prompted VLM run only. A target that is an alias runs as a pipeline and refuses it.
- `--json` works on every command that prints a table. `eyepop tui` refuses it; `update` and `instance logs` print text; `create deployment` and `patch deployment` print a bare session UUID either way.
- `--no-cache` forces fresh VLM inference; it is refused on `--pop`, `--session`, and a `--model` that resolves to a pretrained model.
- Under `EYEPOP_API_KEY` alone, `auth status` reports not logged in and `get accounts` refuses, while reads still span every account you can reach. Pick where new resources land with `--account <uuid>` or `EYEPOP_ACCOUNT_UUID`.
- `get` also answers to `ls`, `list`, `show`, and the common reads drop the verb: `eyepop models`, `eyepop abilities`, `eyepop pops`, `eyepop datasets`.
- Deletes are permanent and prompt; `--yes` skips the prompt. API keys are created and revoked in the dashboard only.

## Keep a model warm

A one-off `run` stands up compute per call. An application that runs many times wants a deployment, which SDK clients attach to by UUID:

```bash
UUID=$(eyepop create deployment --pop assets/pop.person.json)   # waits for pipeline_ok, prints the UUID
eyepop run --session "$UUID" --media-path image.jpg
eyepop patch deployment "$UUID" --pop ./pop-v2.json               # same UUID and endpoint; requests can fail during the restart
eyepop delete deployment "$UUID" --yes
```

`--pop` takes the same forms as on `run`; `--model <alias>` works for a single model. `run --session` and `delete deployment` accept a display name or a UUID prefix of at least 7 characters; `get deployments` and `patch deployment` need the full UUID. Deployments need a plan that includes them; a `403` on create means the current plan does not.

## Branches with their own reference

| Task | Read |
|---|---|
| Walk a new user through install, sign-in, and a first inference, explaining each step | [references/quickstart.md](references/quickstart.md) |
| Create, test, iterate, and alias an ability; build a dataset, add ground truth, evaluate, read metrics | [references/abilities.md](references/abilities.md) |
| Build a Python application: sessions, media forms, `fps` and other source options, composable Pops, reading results, the data endpoint, local mode; runnable templates in `assets/*.py` | [references/python-sdk.md](references/python-sdk.md) |
| Build a Node, TypeScript, browser, or React Native application: the same, plus canvas rendering | [references/node-sdk.md](references/node-sdk.md) |
| Stand up or operate an on-premise instance; how runs route on that machine | [references/on-premise.md](references/on-premise.md) |
| Pick a pretrained model; label sets | [references/models.md](references/models.md) |
| Find when something happens in a video; per-frame timing, and how video frame sampling, one-class abilities, and prompted runs can mislead | [references/video-events.md](references/video-events.md) |
| Command map, scripting flags, environment variables, `run` and `evaluate` details, ability flags | [references/cli.md](references/cli.md) |

When the user is building an application: Python for scripts, batch jobs, and data work (`pip install eyepop`, `EyePopSdk.sync_worker(pop=pop)`); Node for services, browsers, and React Native (`npm install @eyepop.ai/eyepop`, `EyePop.workerEndpoint({ pop }).connect()`). Both take the Pop when the session opens and read `EYEPOP_API_KEY` from the environment. For a one-off question about some media, the answer is still `eyepop run`.

## When something fails

| Symptom | Cause | Fix |
|---|---|---|
| `eyepop: command not found` | CLI missing, or `~/.local/bin` absent from `PATH` | Step 1; `export PATH="$HOME/.local/bin:$PATH"` |
| Unknown subcommand or flag | Stale binary; the CLI is beta and moves | `eyepop update`, then `eyepop <command> --help` |
| `unexpected argument 'image.jpg' found`, or `run requires media` | Media was passed without its flag, or not at all | `--media-path image.jpg`, once per file, directory, or URL |
| `run --pop ./pop.json` or `--pop eyepop.person:latest` answers `No pop found matching` | Binary older than 0.18.0 | `eyepop update`, or the by-hand install pinned to a newer tag |
| `Token expired` | Browser session lapsed | `eyepop auth login`, or set `EYEPOP_API_KEY` |
| `get accounts` refuses, `auth status` says not logged in | Running under `EYEPOP_API_KEY` alone | Expected; `--account <uuid>` to create elsewhere |
| `403` creating a deployment | The current plan does not include deployments | Choose a plan at https://dashboard.eyepop.ai |
| An alias is rejected | It lacks the account's namespace prefix | Copy the prefix from an existing alias in `get abilities --mine` |
| `--prompt does not apply to <alias>` | An alias runs as a pipeline | Drop `--prompt`; the ability's own prompt runs |
| Evaluation reports all-zero metrics and no error | Every asset hit the per-asset timeout | Shorter video assets, images, or an ability created with a lower `--fps`: [references/abilities.md](references/abilities.md#evaluate-against-ground-truth) |
| A run bills cloud compute on an on-premise machine | `--model` named an ability, which is not on-premise aware | Use `--pop` |
| A URL fails with `Resource not found. (error during pre-loading)` | The worker fetches URLs itself, and that host refused it (Wikimedia does) | Download the file and run it from disk |
| Instance is not responding | Instance stopped; there is no cloud fallback | `eyepop instance start` |
| SDK connect error that reports a pipeline error | The Pop is invalid: unknown alias or bad component | Fix the Pop; `no available server` is the capacity error, retry that one |
| A video run answers `no event`, or the wrong time range, for a clip that contains the event | A video run judges a limited number of frames, often far fewer than the clip's duration times the ability's `--fps` | Work on stills: `scripts/find-event.sh`; [references/video-events.md](references/video-events.md) |
| `classes[0]` is confident but contradicts `raw_output` | The ability has a single `--class`, so every answer maps onto it | Use two or more classes, or none; trust `raw_output` |
| A `--prompt` run's answer stops mid-sentence | A prompted run keeps the ability's `max_new_tokens` and `image_size` | Prompt through an ability with a larger `max_new_tokens`, such as the one `scripts/find-event.sh` creates |
| `--publish` printed no alias, and `--model <alias>:latest` is not found | Publishing does not always create an alias | Run by UUID; read identifiers from `eyepop get abilities --mine --json`, not from the table |
| Anything else | | `eyepop <command> --help`, https://docs.eyepop.ai/llms.txt, help@eyepop.ai |
