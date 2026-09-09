---
type: regex
pattern: 'time(d)? ?out|timeout'
flags: "i"
match: contains
target: last_message
---

Attributes the zeros to the per-asset timeout.
