#!/usr/bin/env bash
# List what this account can run: your abilities, Pops, deployments, instances, datasets, models.
#
# Abilities are printed as "uuid  name  alias" parsed from JSON, because the human-readable
# table has several id-shaped columns and the wrong one fails with "No ability found with UUID".
# Models come last and name-only: there are ~100 of them and they drown everything else.
#
# Usage: inventory.sh [text|json] [--full]
set -u

fmt=text; full=0
for a in "$@"; do
  case "$a" in
    json) fmt=json ;;
    text) fmt=text ;;
    --full) full=1 ;;
  esac
done

section(){ printf '\n## %s\n' "$1"; }
show(){
  local out
  if out=$(eyepop "$@" --format "$fmt" 2>&1); then
    if [ -n "$out" ]; then printf '%s\n' "$out"; else echo "(none)"; fi
  else
    echo "(error) $(printf '%s\n' "$out" | head -1)"
  fi
}

section "your abilities: eyepop get abilities --mine"
if [ "$fmt" = json ]; then
  show get abilities --mine
else
  eyepop get abilities --mine --json 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("(none)"); sys.exit()
items=d if isinstance(d,list) else d.get("abilities",d.get("results",[]))
if not items: print("(none)"); sys.exit()
print("UUID".ljust(34) + "NAME".ljust(46) + "ALIAS (run with --model <uuid>)")
for a in items:
    al=a.get("aliases") or []
    alias="-"
    for x in al:
        if x.get("tag")=="latest":
            alias=x.get("alias"); break
    if alias=="-" and al: alias=al[0].get("alias")
    print((a.get("uuid") or "-").ljust(34) + ((a.get("name") or "-")[:44]).ljust(46) + str(alias))
' || echo "(none)"
fi

section "pops: eyepop get pops";               show get pops
section "deployments: eyepop get deployments"; show get deployments
section "instances: eyepop get instances";     show get instances
section "datasets: eyepop get datasets";       show get datasets

section "models: eyepop get models"
if [ "$fmt" = json ] || [ "$full" = 1 ]; then
  show get models
else
  eyepop get models --json 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("(none)"); sys.exit()
items=d if isinstance(d,list) else d.get("models",d.get("results",[]))
names=sorted({(m.get("alias") or m.get("name") or "?") for m in items})
print("(" + str(len(names)) + " pretrained; pass --full, or eyepop get models, for details)")
for i in range(0,len(names),3):
    print("  " + "  ".join(n.ljust(36) for n in names[i:i+3]).rstrip())
' || echo "(none)"
fi
