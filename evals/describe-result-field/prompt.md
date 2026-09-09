---
name: "Result field for a describe ability"
tags: ["sdk", "results"]
runs: 2
max_turns: 4
allowed_tools: [Read]
---

My Python Pop runs the custom ability `acme-com.describe.shelf-state:latest`. In the prediction dict that `predict()` returns, which field holds the ability's answer? Show the one line of Python that reads it.
