---
name: "Run person detection over a directory with parseable output"
tags: ["inference", "cli"]
runs: 2
max_turns: 4
allowed_tools: [Read, Skill]
---

Give me one eyepop command that runs person detection over every image under ./photos, including subfolders, and prints output a script can parse.
