---
type: regex
pattern: 'eyepop run --model eyepop\.person:latest[^\n]*\./shots|eyepop run[^\n]*\./shots[^\n]*eyepop\.person:latest'
match: contains
target: last_message
---

Answers with one eyepop run command over the folder.
