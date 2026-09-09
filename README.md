# EyePop Skills

Agent skills for working with [EyePop.ai](https://www.eyepop.ai) — install and use the CLI, run inference on images and video, and call the Python and Node SDKs. Works with Claude Code, Codex, Cursor, OpenCode, and any agent that reads the [Agent Skills](https://agentskills.io) format.

## Install

```bash
npx skills add eyepop-ai/eyepop-skills
```

Install for one agent, or globally for every project:

```bash
npx skills add eyepop-ai/eyepop-skills -a claude-code
npx skills add eyepop-ai/eyepop-skills -g
```

Preview what the repo ships without installing:

```bash
npx skills add eyepop-ai/eyepop-skills --list
```

## Skills

| Skill | Covers |
| --- | --- |
| [`eyepop`](skills/eyepop/SKILL.md) | The `eyepop` CLI: install, sign in, find a model, run inference, deployments, datasets and evaluation, on-premise instances. Python and Node SDK quickstarts. |

## Manual install

A skill is a directory with a `SKILL.md`. Copy `skills/eyepop` into your agent's skills directory, for example `.claude/skills/eyepop` for Claude Code.

## Links

- Docs: https://docs.eyepop.ai
- Dashboard: https://dashboard.eyepop.ai
- Abilities Hub: https://www.eyepop.ai/abilities
- Support: help@eyepop.ai
