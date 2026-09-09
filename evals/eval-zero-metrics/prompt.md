---
name: "Evaluation finished with all-zero metrics"
tags: ["evaluation", "cli"]
runs: 2
max_turns: 4
allowed_tools: [Read, Skill]
---

I ran `eyepop evaluate --ability warehouse-events --dataset dock-cams` over a dataset of 20-minute videos. It finished with every metric at zero and no error. I created a fresh ability with the same prompt and got the same zeros. What is going on and what should I change?
