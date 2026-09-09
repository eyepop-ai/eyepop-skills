---
name: "Long-running service should use a deployment"
tags: ["deployments", "cli", "sdk"]
runs: 2
max_turns: 4
allowed_tools: [Read, Skill]
---

I have a web service that will run the same EyePop model thousands of times a day. What should I set up so each request does not pay to start compute, and how does my Node code attach to it?
