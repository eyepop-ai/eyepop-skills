---
name: "CLI-published ability has no alias for the SDK"
tags: ["abilities", "sdk"]
runs: 2
max_turns: 6
allowed_tools: [Read]
---

I ran `eyepop create ability --name shelf-check --prompt "..." --class empty --class stocked --publish` and it printed a uuid. `eyepop run --model shelf-check photo.jpg` works. But when I put `InferenceComponent(ability="shelf-check:latest")` in a Python Pop the session fails to resolve it. Why, and what do I do?
