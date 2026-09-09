---
type: regex
pattern: '(?=[\s\S]*eyepop run --model eyepop\.person:latest)(?=[\s\S]*--media-path \./shots)'
match: contains
target: last_message
---

Answers with one eyepop run command over the folder, media passed with --media-path.
