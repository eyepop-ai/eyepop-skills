---
type: regex
pattern: '\.local/bin'
match: contains
target: last_message
---

Mentions that the script installs to ~/.local/bin, which may need adding to PATH.
