---
name: "CLI-published ability is referenced by alias in the SDK"
tags: ["abilities", "sdk"]
runs: 2
max_turns: 6
allowed_tools: [Read, Skill]
---

I ran `eyepop create ability --name shelf-check --prompt "..." --class empty --class stocked --publish` and it worked. Now I want to use it from a Python Pop, but `InferenceComponent(ability="shelf-check:latest")` fails to resolve when the session opens. What should I put there, and where do I find it?
