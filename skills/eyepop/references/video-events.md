# Locating an event in time

The question "when does X happen in this video?" is answered from **still frames**, not
from the video file. One command does the whole thing:

```bash
scripts/find-event.sh video.mp4 "an explosion or fireball" --label explosion
```

It prints a per-frame timeline, an onset in seconds with its error bar, and the path to a
contact sheet. `--json` emits `{onset, end, precision_s, confirmed, frames[]}` for a
program. Exit `0` found, `3` not found, `1` error.

## Why stills and not the video

Passing the whole clip to a VLM and asking "does this contain X?" is unreliable, and it
fails silently rather than loudly. Measured on a 13.4s clip whose blast is at 10.45s:

| What was asked | Answer |
|---|---|
| whole clip, "identify timestamp ranges of an explosion" | `00:07 - 00:13` (wrong) |
| whole clip, same prompt, fps 4 | `no event` |
| 4s window containing the blast | `00:01 - 00:03` (right) |
| 4s window, strict "is this an explosion?" | `no event` |
| the same 4s window, "describe this clip" | *"a firework shoots out of the sky"* |
| stills, one frame at a time, "YES or NO" | onset 10.45s, +/- 0.10s |

The model **sees** the event in every case. A whole-clip yes/no question is what it gets
wrong, and a strict definition ("explosion") makes it answer no for something it would
happily describe as a firework. Per-frame judgements are steady, and a frame's timestamp
is arithmetic rather than something the model reports, so it cannot be misremembered.

## Video runs sample fewer frames than you ask for

`run_info` reports what was really used. Always divide:

```
frames_used = visual_tokens / visual_tokens_per_frame
```

Observed: a 13.4s clip at `--fps 4` used **16** frames, not 53; the same clip at `--fps 1`
used 7; a 4s clip at `--fps 4` used 8. `--max-frames` did not raise any of these. The
practical consequence is that **raising `--fps` narrows the span of clip actually looked
at**, which is why the fps-4 run above answered `no event` on a clip that plainly contains
a fireball. If you must run video, cut it into short pieces instead of raising fps.

## A one-class ability fabricates a confident label

An ability created with a single `--class` maps *every* answer onto that class. A run whose
`raw_output` was `"No explosion."` reported `classes[0] = {explosion, confidence: 0.90}`.

- Give a classifier **two or more** classes, or none at all.
- Read `raw_output` before trusting `classes[0]`; when they disagree, `raw_output` is the model.
- A **prompted** run (`--model <uuid> --prompt ...`) returns free text in `texts[]` and no
  `classes` key at all, so it cannot be corrupted this way. `find-event.sh` uses only these.

## Prompted runs still inherit the carrier's config

A prompted run ignores the carrier ability's prompt and class transform but **keeps its
`image_size` and `max_new_tokens`**. Borrowing whatever ability happens to be first in the
account truncates answers — a carrier with `max_new_tokens: 10` cut descriptions to
*"A man with a long white beard and a red"*. `find-event.sh` therefore creates and reuses
one ability of its own, `agent.describe.prompt-carrier` (`image_size 640`,
`max_new_tokens 60`), cached at `~/.cache/eyepop-skill/carrier`. Override with `--carrier`.

## Tuning

| Situation | Flag |
|---|---|
| Long video, pass 1 too slow or costly | `--coarse-budget 60` (default 120 frames, adaptive rate) |
| Event shorter than half a second | `--coarse-fps 4`, then `--fine-fps 20` |
| Only need the rough window | `--coarse-only` |
| Want the frames and sheet kept | `--outdir ./work` |

Pass 2 searches a window around the **first** pass-1 hit, so `onset` is the first
occurrence. If the event recurs, the output says how late pass 1 still saw it.

## Always confirm visually

The script writes `sheet.jpg`, 18 frames at 10fps from 0.6s before the onset, row-major.
Open it. A per-frame classifier agreeing with itself across many frames is still one model;
the sheet is what turns its answer into something you have checked. In the worked example
the sheet showed a calm patio through 10.35s and the first flame at 10.45s, which is what
made the number trustworthy — and an earlier read of a too-narrow sheet, starting *after*
the fireball had grown, had wrongly suggested the scene was simply already on fire.
