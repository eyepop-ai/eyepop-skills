---
type: tool_used
tool: Bash
input_match: 'doctor\.sh|eyepop --version|command -v eyepop|which eyepop'
min: 1
target: trace
---

The agent probes for the CLI (the skill's doctor script or an equivalent version check) instead of guessing.
