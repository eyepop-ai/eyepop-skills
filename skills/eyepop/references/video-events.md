# Locating an event in time

The question "when does X happen in this video?" is answered from **still frames**, one at a
time, not from the video file. One command does the whole thing:

```bash
scripts/find-event.sh video.mp4 "an explosion or fireball" --label explosion
```

It prints a per-frame timeline, an onset in seconds with its error bar, and the path to a
contact sheet. `--json` emits `{onset, end, precision_s, confirmed, frames[]}` for a
program, also after `--coarse-only`; when nothing is found, `onset` is null and
`contains[]` says what the video shows instead. Exit `0` found, `3` not found, `1` error.

It needs the `eyepop` CLI, signed in, plus `ffmpeg`, `ffprobe`, and `python3`.

## How it works

1. **Pass 1** extracts stills across the whole video, two per second for a clip up to a
   minute long; a longer video is spread over about 120 frames, but never fewer than one
   every five seconds. It asks of each still whether it shows the event.
2. **Pass 2** extracts stills at up to 10 per second around the first frame that did, and
   asks again. That puts the onset within a fraction of a second; the output gives the exact
   error bar.
3. **Pass 3** writes a contact sheet around the onset.

A frame's timestamp comes from its position in the video, so the time never depends on what
a model reports. Pass 2 searches around the **first** hit, so `onset` is the first
occurrence; if the event recurs, the output says how late pass 1 still saw it.

## Why stills and not the whole video

Asking an ability about a whole clip ("does this contain X, and when?") can miss a brief
event entirely or report the wrong time range. A yes or no about one frame is a steadier
judgement, and every answer can be checked against the frame it came from.

Part of the reason is how a video run samples frames. An ability's `--fps` is a target, not
a guarantee: a run can use far fewer frames than the clip's duration times `--fps`, and
`--max-frames` may not raise the count. `run_info` in the result says what was used:

```
frames_used = visual_tokens / visual_tokens_per_frame
```

Because the number of frames is limited, raising `--fps` can make a run cover a shorter
stretch of the clip rather than add detail. If you do run a video through an ability, cut it
into short pieces instead of raising `--fps`.

## Describe the event the way a frame shows it

Describe what the frames show, for example "an explosion or fireball", rather than a strict
category such as "explosion": a strict definition can make the model answer no for something
it would readily describe in other words. When nothing is found, the script describes a few
frames from across the video, so the wording can be changed and the search run again.

## The ability every question runs on

Each question is a prompted run, `eyepop run --model <ability> --prompt ...`. A prompted run
replaces the ability's prompt and answers in free text (`texts[]`), with no `classes`, so no
class can turn a "no" into a confident label. It still keeps the ability's `image_size` and
`max_new_tokens`, and an ability with a small `max_new_tokens` cuts answers short.

So the script uses an ability with known settings. The first run creates
`agent.describe.prompt-carrier` in your account (`image_size` 640, `max_new_tokens` 60),
remembers its UUID in `${XDG_CACHE_HOME:-~/.cache}/eyepop-skill/carrier`, and later runs
reuse it. `--carrier <uuid>` uses a different ability.

## A one-class ability always reports its class

An ability created with a single `--class` maps every answer onto that class, so
`classes[0]` can report the class with high confidence while `raw_output` says the opposite.

- Give a classifier **two or more** classes, or none at all.
- Read `raw_output` before trusting `classes[0]`; when they disagree, `raw_output` is the
  model's answer.

## Tuning

| Situation | Flags |
|---|---|
| Long video, pass 1 too slow or costly | `--coarse-budget 60` (default 120 frames, adaptive rate) |
| Event shorter than half a second | `--coarse-fps 4 --fine-fps 20` |
| Only need the rough window | `--coarse-only` |
| Want the frames and sheet kept | `--outdir ./work` |

## Always confirm visually

The script writes `sheet.jpg`: 18 frames at 10 per second from 0.6s before the onset, in
reading order. Open it before relying on the answer. Every per-frame answer comes from the
same model; the sheet is the independent check.
