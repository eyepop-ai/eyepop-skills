# CLI reference notes

`eyepop <command> --help` is the flag list; the published copy is https://docs.eyepop.ai/developer-documentation/cli/reference. This page holds the command map and the conventions the help text leaves implicit.

## Command map

| Verb | Nouns | Notes |
|---|---|---|
| `auth` | `login`, `status`, `logout` | Browser OAuth session. Under `EYEPOP_API_KEY` alone, `status` reports not logged in |
| `get` (`ls`, `list`, `show`) | `accounts`, `datasets`, `assets --dataset <d>`, `abilities`, `groups`, `pops`, `models`, `deployments`, `sessions`, `instances`, `evals`, `usage` | A name or UUID after the noun shows one record. `eyepop datasets`, `abilities`, `models`, `pops` drop the verb |
| `create` (`new`) | `dataset`, `asset`, `ability`, `deployment` | |
| `patch` | `deployment` | The only patchable resource |
| `delete` | `ability`, `dataset`, `deployment`, `session` | Prompts; `--yes` skips. Instances go through `instance delete` |
| `run` | | Media, one target flag |
| `evaluate` (`eval`) | | `--ability` and `--dataset` |
| `instance` | `init`, `start`, `stop`, `restart`, `set pop`, `logs`, `delete` | On-premise, see [on-premise.md](on-premise.md) |
| `system` | | Hardware profile of this machine |
| `tui` | | Guided run wizard |
| `update` (`upgrade`) | | Homebrew upgrade in place, else a download link |

## Scripting conventions

- `--json` on any command with a table, or `--format json`; `--format text` gives tab-separated records. Every listing pages with `-l/--limit` (1-1000; default 25 fancy, 100 json) and `--offset`.
- Listings filter server-side with `-q <substring>` (glob matches the whole name: `*find*`) and `--filter key=value,key=value` with globs: abilities take `name=`, `status=published`, `group=`, `public=yes`, `alias=eyepop.*`; datasets take `name=`, `searchable=true`, `assets=12`; evals take `status=completed`, `ability=069*`. `--sort created_at|updated_at|name` with `--order asc|desc` where offered.
- `get abilities` and `get groups` take `--mine` (rows you own) or `--public`, mutually exclusive. `get datasets` takes `--modifiable` and `--version <n>`.
- `--account <uuid>` on any create selects the account the resource lands in; `EYEPOP_ACCOUNT_UUID` does the same for a whole shell.
- `--log-level error|warn|info|debug|trace` (per-module too: `eyepop::api=debug,warn`) writes to stderr, so stdout stays parseable; `--log-file [path]` also writes a file. `EYEPOP_LOG_LEVEL` and `EYEPOP_LOG_FILE` are the environment equivalents.

## Environment variables

| Variable | Read by | Meaning |
|---|---|---|
| `EYEPOP_API_KEY` | every command | The `eyp_...` key; replaces `auth login` |
| `EYEPOP_ACCOUNT_UUID` | creates | Account new resources land in |
| `EYEPOP_LOG_LEVEL`, `EYEPOP_LOG_FILE` | every command | CLI logging |
| `EYEPOP_INSTANCE_DIR` | every command, `run` included | Instance root other than `~/.eyepop` |
| `EYEPOP_VERSION`, `EYEPOP_INSTALL_DIR` | `install.sh` | Pin a release tag; install somewhere other than `~/.local/bin` |

## `run` details

- Targets: `--model <alias-or-uuid>` (models and published abilities), `--pop <alias-or-uuid>` (built-in handle or saved Pop UUID), `--session <uuid>`. Exactly one.
- Inputs: positionals and `--media-path`, each a file, directory, or HTTP(S) URL; `-r/--recursive` descends into directories. `-p/--prompt` sends a text prompt to a VLM ability.
- `--concurrency` 1-32, default 4. `--timeout` is per result: the inference poll on model runs (default 3600 s), the worker response on Pop and session runs (default 120 s).
- `--no-cache` applies to VLM ability runs, with or without `--prompt`; refused on `--pop`, `--session`, and published models. `--dashboard` opens the session dashboard for Pop runs and needs an admin account.
- Output: one file that succeeds prints `{file, response}` plus `request_id` when the run has one; a file still processing prints a pending record; two or more files, or one failure, prints `{results, total, success, failed, failures, pending}`.

## Ability flags

`eyepop create ability` fields, and what they control:

| Flag | Meaning |
|---|---|
| `--name`, `--description` | Identity. The description is also what the prompt-creation agent reads, so make it task-specific |
| `--prompt` | The instruction to the vision-language model; name the task and restrict the outputs |
| `--class <label>` (repeatable) | Fixed output label set the raw answer is mapped into |
| `--publish` | Publish after creation; `run --model` takes published abilities |
| `--public` | Make the ability public |
| `--image-size` | Max dimension media is resized to before inference; the main cost and speed lever |
| `--fps`, `--max-frames`, `--min-frames` | Video sampling |
| `--max-new-tokens`, `--context-length` | Generation and visual context limits |
| `--max-aspect-ratio` | Maximum allowed aspect ratio |
| `--video-chunk-length-ns`, `--video-chunk-overlap` | Chunked video; overlap must be under 0.5 |
| `--set key=value` (repeatable) | Any other config key |

Typical settings: object detection 512-640; find an event in video 512-640 at 2-5 fps; sports 512-640 at 5-10 fps; industrial monitoring 512-640 at 1-3 fps; document analysis 768-1024. The backing model is the shared default (`qwen3-instruct` today) and is not selectable. Abilities belong to **groups** (`eyepop get groups`); a group carries the alias its abilities are referenced by.

## Evaluation details

- `--ability` and `--dataset` take a name or UUID. Datasets also address as `name@3` or `name@latest`.
- `--partition` and `--filter-class` repeat to widen the selection. `--video-chunk-length` (nanoseconds) and `--video-chunk-overlap` (0.0-1.0) shape video scoring.
- Timing: the CLI polls for at least 20 seconds. `--timeout` above 20 waits longer; below 20 it shortens only the server's own wait. `--no-wait` returns the request ID at once.
- `get evals <request_id>` shows one run (`--watch` until it completes, `--timeout` as above); `get evals --ability <a>` or `--dataset <d> [--dataset-version <n>]` lists history; `--filter status=completed` narrows it.
- `create dataset` accepts `--media-path`, `--recursive`, `--partition`, and `--concurrency`, so one command creates and fills a dataset; `--searchable` and `--tags` are metadata. `create asset` adds media later and targets a `--version`.

## Install by hand, or pin a version

Every release publishes one archive per platform under https://github.com/eyepop-ai/homebrew-eyepop/releases. Targets: `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`, `x86_64-apple-darwin`, `aarch64-apple-darwin`, and the Windows zip `x86_64-pc-windows-msvc`.

```bash
TARGET=x86_64-unknown-linux-gnu
VERSION=$(curl -fsSL https://api.github.com/repos/eyepop-ai/homebrew-eyepop/releases/latest \
  | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')

curl -fsSL -o eyepop.tar.gz \
  "https://github.com/eyepop-ai/homebrew-eyepop/releases/download/$VERSION/eyepop-$VERSION-$TARGET.tar.gz"
tar -xzf eyepop.tar.gz
mkdir -p ~/.local/bin
install -m 0755 eyepop ~/.local/bin/eyepop
```

Set `VERSION` to a tag instead to pin. The install script does the same with a SHA-256 check: `EYEPOP_VERSION=<tag> sh install.sh`. Homebrew also runs on Linux with the same three commands as macOS.
