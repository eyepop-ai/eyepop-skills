# EyePop Skills

Agent skills for working with [EyePop.ai](https://www.eyepop.ai) from Claude Code, Codex, Cursor, OpenCode, and any other agent that reads the [Agent Skills](https://agentskills.io) format.

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
| [`eyepop`](skills/eyepop/SKILL.md) | The `eyepop` CLI end to end: install for your OS, sign in, find a model, run inference on images and video, create and test abilities, build datasets and run evaluations, keep a deployment warm, operate an on-premise instance. Python and Node SDK quickstarts. |

With the skill loaded, an agent can:

- check for the CLI and offer the install command for your platform
- sign in with an API key or the browser flow, and verify it worked
- pick the right pretrained model, ability, or Pop for a task
- run inference on files, directories, and URLs and parse the JSON result
- write a prompt, create an ability, test it, and iterate
- build a dataset, add ground truth, evaluate an ability, and read the metrics
- create, patch, and delete persistent deployments
- set up and operate an on-premise instance, and route runs to it
- write a first Python or Node SDK integration

## Manual install

A skill is a directory with a `SKILL.md`. Copy `skills/eyepop` into your agent's skills directory, for example `.claude/skills/eyepop` for Claude Code.

## Verify it loaded

Start a session in your project and ask:

> What EyePop skills do you have loaded?

The agent names the `eyepop` skill and summarizes what it covers.

## Requirements

- An EyePop account with an active plan, and an API key (`eyp_...`) from https://dashboard.eyepop.ai
- For the SDK quickstarts: Python 3.12+ with `pip install eyepop`, or Node with `npm install @eyepop.ai/eyepop`

## Links

- Docs: https://docs.eyepop.ai
- Dashboard: https://dashboard.eyepop.ai
- Abilities Hub: https://www.eyepop.ai/abilities
- Support: help@eyepop.ai

## License

[MIT](LICENSE)
