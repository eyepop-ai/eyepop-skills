---
type: regex
pattern: 'eyepop run --model eyepop\.person:latest[^\n]*\./photos[^\n]*(--recursive|-r)[^\n]*(--json|--format json)|eyepop run[^\n]*(--recursive|-r)[^\n]*(--json|--format json)[^\n]*eyepop\.person:latest'
match: contains
target: last_message
---

The command names the person model as the --model target, passes the directory as media, recurses, and asks for JSON.
