# Evals

Cases for `claude plugin eval` (early access). Each case is a `prompt.md` with frontmatter plus `graders/*.md`; expected answers come from the EyePop docs and the eyepop-cli source, so a failing grader points at a stale claim in the skill or a regression in the agent's use of it.

```bash
claude plugin eval . --allow-tools Bash Read --json evals/results/latest.json --report evals/results/report.html
claude plugin eval . --ablation with-without    # score the skill against the no-skill baseline
```

`doctor-first` needs the `eyepop` CLI on the machine that runs the suite. Every other case is answerable from the skill alone.
