---
type: regex
pattern: '(?=[\s\S]*eyepop run --model eyepop\.person:latest)(?=[\s\S]*--media-path \./photos)(?=[\s\S]*(--recursive|-r\s))(?=[\s\S]*(--json|--format json))'
match: contains
target: last_message
---

The command names the person model as the --model target, passes the directory with --media-path, recurses, and asks for JSON.
