# Evals

Cases for `claude plugin eval`. Each case is a `prompt.md` with frontmatter plus `graders/*.md`; expected answers come from the EyePop docs and the CLI's own `--help`, so a failing grader points at a stale claim in the skill or a regression in how the agent uses it.

```bash
claude plugin eval . --allow-tools Bash Read Skill --json evals/results/latest.json --report evals/results/report.html
claude plugin eval . --ablation with-without    # score the skill against the no-skill baseline
```

`doctor-first` needs the `eyepop` CLI on the machine that runs the suite. Every other case is answerable from the skill alone.

## Running by hand

To probe one case without the harness, run it through `claude -p` in a project that has the skill installed. Allow the `Skill` tool, or the agent cannot load the skill and falls back to reading `SKILL.md` off disk. Isolate the run from your own skills, hooks, and MCP servers so the score reflects this skill alone:

```bash
echo '{"mcpServers":{}}' > /tmp/empty-mcp.json
claude -p "$(awk 'c>=2{print} /^---$/{c++}' evals/keep-warm/prompt.md)" \
  --allowedTools "Bash,Read,Skill" --max-turns 12 \
  --setting-sources project --strict-mcp-config --mcp-config /tmp/empty-mcp.json \
  --output-format json
```

Grade the `result` field against the case's `regex` graders; `llm` and `tool_used` graders need a reader or the trace (`--output-format stream-json --verbose`).
