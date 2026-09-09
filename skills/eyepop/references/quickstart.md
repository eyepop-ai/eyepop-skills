# Quickstart: install, sign in, first inference

A guided walkthrough for someone who has never run EyePop. The user is watching and learning, so before each command say what it does and what to expect, run it (or hand it to them to type, if they prefer), then read the result back in plain words. Ask before anything that changes their machine. Finish when they have seen a prediction from their own media and know the one command that produced it. Paths are relative to this skill's directory.

## 1. Where things stand

```bash
scripts/doctor.sh
```

Read the lines it prints and tell the user which of these applies:

- `status: READY`: the CLI is installed and signed in. Go to step 4.
- `cli: missing`: step 2.
- `auth: none`: step 3.
- `reachable: no`: the error line says why. `Token expired` means step 3 again; otherwise the key or the network.

## 2. Install the CLI

The doctor line names the command for this platform. Say what it will do (it installs one binary), ask, then run it:

| Platform | Command |
|---|---|
| macOS, or Linux with Homebrew | `brew tap eyepop-ai/eyepop && brew trust eyepop-ai/eyepop && brew install eyepop` |
| Linux or macOS without Homebrew | `curl -fsSL https://raw.githubusercontent.com/eyepop-ai/homebrew-eyepop/main/install.sh \| sh`, which installs into `~/.local/bin` |
| Windows | The zip from https://github.com/eyepop-ai/homebrew-eyepop/releases/latest, with `eyepop.exe` on `PATH` |

Done when `eyepop --version` prints a version. If the shell says `command not found` after the curl script, `export PATH="$HOME/.local/bin:$PATH"` and suggest adding that line to their shell profile.

## 3. Sign in

A person at a terminal signs in through the browser:

```bash
eyepop auth login
```

It opens the dashboard; they log in, and the CLI keeps the session. No account yet: https://dashboard.eyepop.ai, and a plan must be active before anything runs. A script or CI uses an API key from **API Keys** in the dashboard, set as `EYEPOP_API_KEY` in the environment, never pasted into a command line.

Done when `scripts/doctor.sh` prints `status: READY`.

## 4. Pick some media

Ask for an image or a short video on this machine, or an HTTP(S) URL. Something with a person in it makes the first result obvious. If they have nothing to hand, use the sample that ships with the skill, `assets/macgyver.jpg`: Richard Dean Anderson at a podium, a public-domain U.S. Air Force photo with one person in it. The same file is online at https://raw.githubusercontent.com/eyepop-ai/eyepop-skills/main/skills/eyepop/assets/macgyver.jpg for a run from anywhere.

## 5. Run the first inference

```bash
eyepop run --model eyepop.person:latest --media-path <media>                 # their file or URL
eyepop run --model eyepop.person:latest --media-path assets/macgyver.jpg     # the sample
```

Say what the parts mean: `run` sends media to EyePop, `--model` names what to run, `eyepop.person:latest` is the pretrained person detector every account can use, and `--media-path` names the media, repeated for more than one file. Then run it with `--json` and walk through the result:

```json
{ "source_width": 1920, "source_height": 1080,
  "objects": [ { "classLabel": "person", "confidence": 0.95, "x": 100, "y": 50, "width": 80, "height": 200 } ] }
```

- `source_width` and `source_height` are the media's pixel size.
- Each entry in `objects` is one detection: a label, a confidence from 0 to 1, and a box in pixels measured from the top-left corner.
- No `objects`, or an empty list, means nothing was found. That is a successful run, not an error; try media with a person in it.
- A video prints one such prediction per frame.

With the sample, expect `source_width` 505, `source_height` 640, and one `person` object near confidence 0.95. Done when the user can point at a box in the output and say what it is.

## 6. Show what is next

One or two of these, matched to what they said they want to do:

- Another detector: `eyepop get models` lists them. `eyepop.common-objects:latest`, `eyepop.vehicle:latest`, and `eyepop.text:latest` are good second runs; [models.md](models.md) has the label sets.
- A whole folder: `eyepop run --model eyepop.person:latest --media-path ./photos --recursive --json > results.json`.
- A multi-stage pipeline: `eyepop run --pop people-common-objects --media-path <media>`; `eyepop get pops` lists the rest.
- A question in words (describe, count, read a field): an ability, in [abilities.md](abilities.md).
- `eyepop tui` is the same run as a guided form.
- Building an application: [python-sdk.md](python-sdk.md) or [node-sdk.md](node-sdk.md).

Leave them with the one-line summary: install once, `eyepop auth login` once, then `eyepop run --model <alias> --media-path <media>` for anything.
