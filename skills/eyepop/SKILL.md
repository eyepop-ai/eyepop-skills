---
name: eyepop
description: Run EyePop.ai computer vision from the terminal or code. Checks for the eyepop CLI and installs it for the user's OS, signs in, lists the user's models, abilities, Pops, deployments, and instances and confirms they can run, runs inference on images, video, URLs, or directories and reads the JSON result, creates and tests a VLM ability, builds a dataset and evaluates an ability against ground truth, keeps a deployment warm, operates an on-premise instance, and writes Python or Node SDK code. Use when a task mentions EyePop, eyepop run, an eyepop.*:latest alias, EYEPOP_API_KEY, a Pop or ability, or detecting objects, people, text, or vehicles in images or video.
license: MIT
compatibility: Needs network access to eyepop.ai. Installs the eyepop CLI with Homebrew or the curl install script when it is missing. The SDK paths need Python 3.12+ or Node.
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
| **Pop** | A pipeline of one or more models or abilities: a built-in handle (`people-common-objects`) or a JSON document you send by value | `eyepop get pops`, `assets/` |
| **target** | What a run uses: `--model`, `--pop`, or `--session`. Exactly one per run, and positional arguments are always media | |
| **session** / **deployment** | Compute running a Pop. A deployment is a session kept warm behind a stable UUID | `eyepop get deployments` |
| **instance** | The EyePop runtime installed on hardware you control | `eyepop get instances` |
| **dataset** | Named media with ground truth, scored by `eyepop evaluate` | `eyepop get datasets` |

Everyday inference is a CLI command: one line, no code, JSON out. Reach for an SDK only when the user is building an application in Python or Node, or needs something the CLI cannot do (a live camera, tracking across frames, a custom multi-stage Pop without a deployment, frame-rate throttling, bulk ground truth).

Paths below are relative to this skill's directory. Flags come from the binary: `eyepop <command> --help` is authoritative, and the CLI is in beta, so pin a version in anything automated. Docs at https://docs.eyepop.ai, indexed for agents at https://docs.eyepop.ai/llms.txt.

## 1. Check the machine, offer the install

```bash
scripts/doctor.sh
```

It reports the platform, whether the CLI is installed, which credential is present, and whether the platform answers, then exits `0` ready, `2` CLI missing, `3` no credentials, `4` unreachable. Act on the line it prints:

- **`cli: missing`**: it names the install command for this platform. Tell the user what it will do and run it once they agree, since installing changes their machine. macOS or Homebrew: `brew tap eyepop-ai/eyepop && brew trust eyepop-ai/eyepop && brew install eyepop`. Linux or macOS without Homebrew: the curl script, which installs to `~/.local/bin` (`EYEPOP_VERSION` pins a release). Windows: the zip from https://github.com/eyepop-ai/homebrew-eyepop/releases/latest onto `PATH`. By-hand and pinned installs: [references/cli.md](references/cli.md#install-by-hand-or-pin-a-version).
- **`auth: none`**: scripts, CI, and agents set `EYEPOP_API_KEY`; the key starts with `eyp_`, is created once under **API Keys** at https://dashboard.eyepop.ai, and lives in the environment or a `.env`, never in a command line. A person at a terminal can run `eyepop auth login` instead.
- **`reachable: no`**: the error line says why. `Token expired` means `eyepop auth login`; otherwise the key or the network.

Done when the script prints `status: READY`.

## 2. See what the user has, and prove it runs

```bash
scripts/inventory.sh          # add json for machine-readable output
```

It lists the pretrained models, the user's own abilities, the Pops, running deployments, on-premise instances, and datasets, each under the command that produced it. Read it before proposing anything: an existing deployment or instance is what the user's application already talks to, and their own abilities are the tasks they have already defined.

Then confirm the account can actually run something. Use media the user names, or any HTTP(S) image URL they supply:

```bash
eyepop run --model eyepop.person:latest <media> --json          # every account can run this
eyepop run --session <deployment-uuid> <media> --json           # when a deployment exists
```

Done when a `response` with `source_width` and `source_height` comes back. A response with no `objects` key, or an empty one, is still success: nothing was detected in that media.

## 3. Run inference

Pick the target from the inventory. A prompt-driven task (describe, count, read a field, classify by description) is an **ability**; an object-detection task is a **model**; a multi-stage task is a **Pop**.

```bash
eyepop run --model eyepop.person:latest image.jpg
eyepop run --model eyepop.person:latest ./images --recursive --json
eyepop run --model <your-namespace>.classify.helmet:latest image.jpg
eyepop run --pop people-common-objects video.mp4
eyepop run --pop <saved-pop-uuid> image.jpg
eyepop run --session <session-uuid> https://example.com/frame.jpg
```

Media is a file, a directory, or an HTTP(S) URL; more of them go as extra positionals or `--media-path`. `--concurrency` (default 4, max 32) runs inputs in parallel. `--model` takes an alias from `get models` or the ALIAS column of `get abilities`; an ability's bare name or UUID with `--prompt` is the prompted, one-off VLM run. `eyepop tui` is the guided form of the same run.

Add `--json` whenever a program reads the output. One successful file prints a single `{file, response}` record; two or more files, or any failure, prints `{results, total, success, failed, failures, pending}`. Each `response` is one prediction per image, or per frame for video:

```json
{ "source_width": 1920, "source_height": 1080,
  "objects": [ { "classLabel": "person", "confidence": 0.95, "x": 100, "y": 50, "width": 80, "height": 200 } ] }
```

Which field an ability fills: detection in `objects`, a label in `classes[0].classLabel`, text in `texts[0].text`, crop-forwarded stages nested under their parent object. The wrong field is an empty list, never an error. Done when the parsed JSON holds the field the task asked for.

## Rules the CLI enforces

- One target per run. `run` with no target and no media prints its help.
- `--pop` takes what `eyepop get pops` lists: a built-in by its handle (`person`, `people-common-objects`, `vehicles-traffic-cam`), or a Pop saved in the dashboard by the UUID in its POP column (OWNER `mine`). Saved-Pop display names are refused, since they are neither unique nor stable, and a model alias is refused too. A Pop written by hand (`assets/pop.person.json`, `assets/pop.crop-forward.json`) goes to `create deployment --pop ./pop.json`, then runs with `--session`.
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
eyepop run --session "$UUID" image.jpg
eyepop patch deployment "$UUID" --pop ./pop-v2.json               # same UUID and endpoint; requests can fail during the restart
eyepop delete deployment "$UUID" --yes
```

`--pop` here takes a JSON or YAML file or an inline body; `--model <alias>` works for a single model. `run --session` and `delete deployment` accept a display name or a UUID prefix of at least 7 characters; `get deployments` and `patch deployment` need the full UUID. Deployments need a plan that includes them; a `403` on create means the current plan does not.

## Branches with their own reference

| Task | Read |
|---|---|
| Create, test, iterate, and alias an ability; build a dataset, add ground truth, evaluate, read metrics | [references/abilities.md](references/abilities.md) |
| Build a Python application: sessions, media forms, `fps` and other source options, composable Pops, reading results, the data endpoint, local mode; runnable templates in `assets/*.py` | [references/python-sdk.md](references/python-sdk.md) |
| Build a Node, TypeScript, browser, or React Native application: the same, plus canvas rendering | [references/node-sdk.md](references/node-sdk.md) |
| Stand up or operate an on-premise instance; how runs route on that machine | [references/on-premise.md](references/on-premise.md) |
| Pick a pretrained model; label sets | [references/models.md](references/models.md) |
| Command map, scripting flags, environment variables, `run` and `evaluate` details, ability flags | [references/cli.md](references/cli.md) |

When the user is building an application: Python for scripts, batch jobs, and data work (`pip install eyepop`, `EyePopSdk.sync_worker(pop=pop)`); Node for services, browsers, and React Native (`npm install @eyepop.ai/eyepop`, `EyePop.workerEndpoint({ pop }).connect()`). Both take the Pop when the session opens and read `EYEPOP_API_KEY` from the environment. For a one-off question about some media, the answer is still `eyepop run`.

## When something fails

| Symptom | Cause | Fix |
|---|---|---|
| `eyepop: command not found` | CLI missing, or `~/.local/bin` absent from `PATH` | Step 1; `export PATH="$HOME/.local/bin:$PATH"` |
| Unknown subcommand or flag | Stale binary; the CLI is beta and moves | `eyepop update`, then `eyepop <command> --help` |
| `Token expired` | Browser session lapsed | `eyepop auth login`, or set `EYEPOP_API_KEY` |
| `get accounts` refuses, `auth status` says not logged in | Running under `EYEPOP_API_KEY` alone | Expected; `--account <uuid>` to create elsewhere |
| `403` creating a deployment | The current plan does not include deployments | Choose a plan at https://dashboard.eyepop.ai |
| An ability shows no ALIAS in `get abilities`, so a Pop cannot reference it | Published without an alias | Mint one in the dashboard: [references/abilities.md](references/abilities.md#aliases) |
| An alias is rejected | It lacks the account's namespace prefix | Copy the prefix from an existing alias in `get abilities --mine` |
| `--prompt does not apply to <alias>` | An alias runs as a pipeline | Drop `--prompt`; the ability's own prompt runs |
| `--pop` says a name is a pop flow named by its UUID | Saved-Pop names are not resolvable | Use the UUID from the POP column of `get pops` |
| Evaluation reports all-zero metrics and no error | Every asset hit the per-asset timeout | Shorter video assets, images, or an ability created with a lower `--fps`: [references/abilities.md](references/abilities.md#evaluate-against-ground-truth) |
| A run bills cloud compute on an on-premise machine | `--model` named an ability, which is not on-premise aware | Use `--pop` |
| Instance is not responding | Instance stopped; there is no cloud fallback | `eyepop instance start` |
| SDK connect error that reports a pipeline error | The Pop is invalid: unknown alias or bad component | Fix the Pop; `no available server` is the capacity error, retry that one |
| Anything else | | `eyepop <command> --help`, https://docs.eyepop.ai/llms.txt, help@eyepop.ai |
