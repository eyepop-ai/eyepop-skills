#!/usr/bin/env bash
# find-event.sh - Answer "when does X happen in this video?" in seconds.
#
# Works on STILL FRAMES, never on the video file. A VLM asked "is this X?" about a
# whole clip is unreliable - it will answer "no event" for a clip it can describe
# perfectly - while the same model judging one frame at a time is steady. Frames
# also carry exact timestamps, so the answer needs no trust in model-reported time.
#
#   pass 1  stills across the whole video at a budgeted rate -> which seconds hit
#   pass 2  stills at high rate around the first hit         -> the onset second
#   pass 3  a contact sheet, so the answer can be eyeballed before it is believed
#
# Runs are PROMPTED against a carrier ability: nothing is created per call, and a
# prompted run returns free text in `texts`, so no class transform can invent a
# confident wrong label. See references/video-events.md.
#
# Usage: find-event.sh VIDEO "what to look for" [options]
set -uo pipefail

VIDEO=""; WHAT=""; LABEL="event"
COARSE_FPS=""; COARSE_BUDGET=120; FINE_FPS=10; COARSE_ONLY=0; JSON_OUT=0
CARRIER="${EYEPOP_CARRIER_ABILITY:-}"; OUTDIR=""; CONC=8; FINE_BUDGET=80

die(){ echo "error: $*" >&2; exit 1; }
say(){ [ "$JSON_OUT" -eq 1 ] || printf '%s\n' "$*"; }

usage(){ awk 'NR>1{ if(!/^#/) exit; sub(/^# ?/,""); print }' "$0"; cat <<'U'

Options:
  --label NAME        short name for the event (default: event)
  --coarse-fps N      stills/sec in pass 1 (default: adaptive, <= --coarse-budget)
  --coarse-budget N   max pass-1 frames (default: 120)
  --fine-fps N        stills/sec in pass 2 (default: 10)
  --fine-budget N     max pass-2 frames (default: 80)
  --coarse-only       stop after pass 1
  --carrier UUID      ability UUID to carry the prompt (default: discovered/cached)
  --outdir DIR        keep frames and sheet here (default: temp dir)
  --concurrency N     parallel inferences (default: 8)
  --json              emit machine-readable JSON

Exit: 0 found, 3 not found (prints what the video does contain), 1 error
U
exit 0; }

[ $# -eq 0 ] && usage
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    --label) LABEL="$2"; shift 2 ;;
    --coarse-fps) COARSE_FPS="$2"; shift 2 ;;
    --coarse-budget) COARSE_BUDGET="$2"; shift 2 ;;
    --fine-fps) FINE_FPS="$2"; shift 2 ;;
    --fine-budget) FINE_BUDGET="$2"; shift 2 ;;
    --coarse-only) COARSE_ONLY=1; shift ;;
    --carrier) CARRIER="$2"; shift 2 ;;
    --outdir) OUTDIR="$2"; shift 2 ;;
    --concurrency) CONC="$2"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    -*) die "unknown option $1" ;;
    *) if [ -z "$VIDEO" ]; then VIDEO="$1"; elif [ -z "$WHAT" ]; then WHAT="$1"; else die "unexpected argument $1"; fi; shift ;;
  esac
done

[ -n "$VIDEO" ] || die "need a video path"
[ -f "$VIDEO" ] || die "no such file: $VIDEO"
[ -n "$WHAT" ] || die "need a description, e.g. \"an explosion or fireball\""
for b in eyepop ffmpeg ffprobe python3; do command -v "$b" >/dev/null 2>&1 || die "$b not found on PATH"; done

[ -n "$OUTDIR" ] || OUTDIR=$(mktemp -d "${TMPDIR:-/tmp}/eyepop-event.XXXXXX")
mkdir -p "$OUTDIR/coarse" "$OUTDIR/fine"
DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VIDEO") || die "ffprobe failed"
[ -n "$DUR" ] || die "could not read duration of $VIDEO"

# ---- carrier ability (ours, created once) ----------------------------------
# A prompted run ignores the carrier's PROMPT and class transform, but still
# inherits its CONFIG (image_size, max_new_tokens). Borrowing a random ability
# silently truncates answers, so use one we own with known-good settings.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eyepop-skill"; mkdir -p "$CACHE"
CARRIER_NAME="agent.describe.prompt-carrier"
abilities_json(){ eyepop get abilities --mine --json 2>/dev/null; }
uuid_by_name(){ abilities_json | python3 -c '
import json,sys
want=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
items=d if isinstance(d,list) else d.get("abilities",d.get("results",[]))
for a in items:
    if a.get("name")==want and a.get("uuid"): print(a["uuid"]); break
' "$1"; }
uuid_exists(){ abilities_json | python3 -c '
import json,sys
want=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
items=d if isinstance(d,list) else d.get("abilities",d.get("results",[]))
sys.exit(0 if any(a.get("uuid")==want for a in items) else 1)
' "$1"; }

[ -z "$CARRIER" ] && [ -f "$CACHE/carrier" ] && CARRIER=$(cat "$CACHE/carrier")
[ -n "$CARRIER" ] && { uuid_exists "$CARRIER" || CARRIER=""; }
[ -z "$CARRIER" ] && CARRIER=$(uuid_by_name "$CARRIER_NAME")
if [ -z "$CARRIER" ]; then
  say "note: creating the prompt-carrier ability once ($CARRIER_NAME); reused from now on"
  eyepop create ability --name "$CARRIER_NAME" \
    --description "Generic carrier for prompted one-off VLM runs (created by find-event.sh). Safe to keep." \
    --prompt 'Describe what is happening.' --image-size 640 --max-new-tokens 60 --publish >/dev/null 2>&1
  CARRIER=$(uuid_by_name "$CARRIER_NAME")
fi
[ -n "$CARRIER" ] || die "could not resolve a carrier ability; pass --carrier UUID"
printf '%s' "$CARRIER" > "$CACHE/carrier"

HIT_PROMPT="Look at this single still frame. Does it show ${WHAT}, actively happening in this frame?
Answer with exactly one word: YES or NO.
Answer NO for the calm scene before it starts, and for smoke, dust or aftermath lingering once it is over."
DESC_PROMPT='Describe what is happening in this frame in one short sentence.'

# ---- helpers ---------------------------------------------------------------
PARSE='
import json,sys,os
raw=sys.stdin.read().strip()
try: d=json.loads(raw)
except Exception: sys.exit("could not parse CLI JSON: "+raw[:200])
res = d.get("results") if isinstance(d,dict) and "results" in d else ([d] if isinstance(d,dict) else d)
for r in res or []:
    resp=r.get("response") or {}
    out=(resp.get("raw_output") or "").strip()
    if not out:
        p=resp.get("predictions") or []
        if p:
            t=p[0].get("texts") or []
            if t: out=(t[0].get("text") or "").strip()
    print("\t".join([os.path.basename(r.get("file","") or ""),
                     out.replace("\t"," ").replace("\n"," "),
                     (r.get("error") or "")[:80]]))
'
run_frames(){ # dir prompt outfile
  eyepop run --model "$CARRIER" --no-cache --concurrency "$CONC" --json \
    --prompt "$2" --media-path "$1" --recursive > "$3.json" 2>"$3.err" \
    || { echo "eyepop run failed:" >&2; tail -3 "$3.err" >&2; return 1; }
  python3 -c "$PARSE" < "$3.json" > "$3.tsv"
}

# ---- pass 1: coarse scan over the whole video ------------------------------
if [ -z "$COARSE_FPS" ]; then
  COARSE_FPS=$(python3 -c "
dur=$DUR; b=$COARSE_BUDGET
r = 2.0 if dur*2.0 <= b else b/max(dur,0.001)
print(round(max(0.2, min(4.0, r)), 4))")
fi
NC=$(python3 -c "print(max(1,int($DUR*$COARSE_FPS)+1))")
say "$(printf 'video    %s\nlength   %.2fs\nlooking  %s\npass 1   %s frames at %sfps across the whole clip\n' "$VIDEO" "$DUR" "$WHAT" "$NC" "$COARSE_FPS")"

rm -f "$OUTDIR/coarse"/*.jpg 2>/dev/null
ffmpeg -v error -y -i "$VIDEO" -vf "fps=$COARSE_FPS" -q:v 3 "$OUTDIR/coarse/c%04d.jpg" </dev/null || die "frame extraction failed"
ls "$OUTDIR/coarse"/*.jpg >/dev/null 2>&1 || die "no frames extracted from $VIDEO"
run_frames "$OUTDIR/coarse" "$HIT_PROMPT" "$OUTDIR/coarse_res" || exit 1

read -r NHIT FIRST LAST < <(python3 - "$OUTDIR/coarse_res.tsv" "$COARSE_FPS" <<'PY'
import sys,re
tsv,fps=sys.argv[1],float(sys.argv[2]); hits=[]
for line in open(tsv):
    f,out,err=(line.rstrip("\n").split("\t")+["",""])[:3]
    m=re.match(r"c(\d+)\.jpg",f)
    if not m: continue
    w=re.findall(r"[A-Za-z]+",out)
    if w and w[0].upper().startswith("YES"): hits.append((int(m.group(1))-1)/fps)
hits.sort()
print(len(hits), hits[0] if hits else -1, hits[-1] if hits else -1)
PY
)

if [ "$JSON_OUT" -eq 0 ]; then
  echo; echo "pass 1 hits:"
  python3 - "$OUTDIR/coarse_res.tsv" "$COARSE_FPS" <<'PY'
import sys,re
tsv,fps=sys.argv[1],float(sys.argv[2]); rows=[]
for line in open(tsv):
    f,out,err=(line.rstrip("\n").split("\t")+["",""])[:3]
    m=re.match(r"c(\d+)\.jpg",f)
    if not m: continue
    w=re.findall(r"[A-Za-z]+",out)
    rows.append(((int(m.group(1))-1)/fps, bool(w and w[0].upper().startswith("YES")), err))
rows.sort()
hit=[r for r in rows if r[1]]
if hit:
    for t,_,_ in hit: print(f"  {t:7.2f}s  YES")
else: print("  (none)")
bad=[r for r in rows if r[2]]
if bad: print(f"  note: {len(bad)} frame(s) errored")
PY
  echo
fi

# ---- nothing found: say what IS there, instead of a dead end ---------------
if [ "$NHIT" -eq 0 ]; then
  say "No frame showed \"$WHAT\"."
  mkdir -p "$OUTDIR/sample"; rm -f "$OUTDIR/sample"/*.jpg 2>/dev/null
  python3 - "$OUTDIR/coarse" "$OUTDIR/sample" <<'PY'
import os,sys,shutil
src,dst=sys.argv[1],sys.argv[2]
fs=sorted(f for f in os.listdir(src) if f.endswith(".jpg"))
pick=[fs[i*len(fs)//6] for i in range(6)] if len(fs)>=6 else fs
for f in dict.fromkeys(pick): shutil.copy(os.path.join(src,f),os.path.join(dst,f))
PY
  if run_frames "$OUTDIR/sample" "$DESC_PROMPT" "$OUTDIR/desc_res"; then
    say ""; say "What the video does contain:"
    python3 - "$OUTDIR/desc_res.tsv" "$COARSE_FPS" <<'PY'
import sys,re
for line in sorted(open(sys.argv[1])):
    f,out,err=(line.rstrip("\n").split("\t")+["",""])[:3]
    m=re.match(r"c(\d+)\.jpg",f)
    if m and out: print(f"  {(int(m.group(1))-1)/float(sys.argv[2]):7.2f}s  {out[:100]}")
PY
    say ""; say "If that describes your event in other words, rerun with that wording."
  fi
  say "workdir: $OUTDIR"; exit 3
fi

[ "$COARSE_ONLY" -eq 1 ] && { say "hits from ${FIRST}s to ${LAST}s"; say "workdir: $OUTDIR"; exit 0; }

# ---- pass 2: fine scan around the first hit --------------------------------
read -r FSTART SPAN FINE_FPS < <(python3 -c "
first=$FIRST; step=1.0/$COARSE_FPS; dur=$DUR
s=max(0.0, first-step*1.5)
e=min(dur, first+step*1.5)
if e-s < 1.0: e=min(dur, s+1.0)
span=max(0.3, e-s)
fps=$FINE_FPS
if span*fps > $FINE_BUDGET: fps=max(2, int($FINE_BUDGET/span))
print(round(s,3), round(span,3), fps)")
NF=$(python3 -c "print(int($SPAN*$FINE_FPS)+1)")
say "$(printf 'pass 2   %s frames at %sfps over %.2fs-%.2fs\n' "$NF" "$FINE_FPS" "$FSTART" "$(python3 -c "print($FSTART+$SPAN)")")"

rm -f "$OUTDIR/fine"/*.jpg 2>/dev/null
ffmpeg -v error -y -ss "$FSTART" -t "$SPAN" -i "$VIDEO" -vf "fps=$FINE_FPS" -q:v 3 "$OUTDIR/fine/f%04d.jpg" </dev/null
run_frames "$OUTDIR/fine" "$HIT_PROMPT" "$OUTDIR/fine_res" || exit 1

python3 - "$OUTDIR/fine_res.tsv" "$FSTART" "$FINE_FPS" "$LABEL" "$JSON_OUT" "$OUTDIR" "$FIRST" "$LAST" <<'PY'
import sys,re,json,os
tsv,start,fps,label=sys.argv[1],float(sys.argv[2]),float(sys.argv[3]),sys.argv[4]
as_json,outdir=sys.argv[5]=="1",sys.argv[6]
c_first,c_last=float(sys.argv[7]),float(sys.argv[8])
rows=[]
for line in open(tsv):
    f,out,err=(line.rstrip("\n").split("\t")+["",""])[:3]
    m=re.match(r"f(\d+)\.jpg",f)
    if not m: continue
    w=re.findall(r"[A-Za-z]+",out)
    rows.append((start+(int(m.group(1))-1)/fps, bool(w and w[0].upper().startswith("YES")), err))
rows.sort()
runs=[];cur=None
for t,yes,_ in rows:
    if yes and cur is None: cur=[t,t]
    elif yes: cur[1]=t
    elif cur is not None: runs.append(cur); cur=None
if cur is not None: runs.append(cur)
onset = runs[0][0] if runs else c_first
end   = max(r[1] for r in runs) if runs else c_last
prec  = 1/fps if runs else 1/float(os.environ.get("CFPS","1"))
if not as_json:
    print("\npass 2 frames:")
    for t,yes,err in rows:
        print(f"  {t:7.2f}s  {'YES' if yes else ' no'}{'   ERROR '+err if err else ''}")
    print()
    if runs:
        print(f"==> {label} starts at ~{onset:.2f}s (+/- {prec:.2f}s), last seen ~{end:.2f}s")
        if c_last > end + 0.01:
            print(f"    pass 1 also saw it as late as {c_last:.2f}s")
    else:
        print(f"==> pass 1 saw {label} near {c_first:.2f}s but pass 2 could not confirm a frame;")
        print(f"    treat {c_first:.2f}s as approximate and open the sheet")
    print(f"\nframes:  {outdir}/fine")
    print(f"workdir: {outdir}")
else:
    print(json.dumps({"label":label,"onset":onset,"end":end,"precision_s":prec,
                      "confirmed":bool(runs),"runs":runs,
                      "frames":[{"t":t,"hit":y} for t,y,_ in rows],
                      "workdir":outdir},indent=2))
json.dump({"onset":onset},open(os.path.join(outdir,"result.json"),"w"))
PY

# ---- pass 3: contact sheet -------------------------------------------------
ONSET=$(python3 -c "import json;print(json.load(open('$OUTDIR/result.json'))['onset'])")
SHEET_START=$(python3 -c "print(max(0.0,$ONSET-0.6))")
ffmpeg -v error -y -ss "$SHEET_START" -t 1.8 -i "$VIDEO" \
  -vf "fps=10,scale=320:-1,tile=6x3:padding=4:margin=4:color=white" -frames:v 1 -update 1 \
  "$OUTDIR/sheet.jpg" </dev/null 2>/dev/null
[ -s "$OUTDIR/sheet.jpg" ] && say "$(printf 'sheet:   %s  (%.2fs onward, 10fps, row-major - open it to confirm)' "$OUTDIR/sheet.jpg" "$SHEET_START")"
exit 0
