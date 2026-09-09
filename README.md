# EyePop Skills

One agent skill, `eyepop`, for working with [EyePop.ai](https://www.eyepop.ai) from Claude Code, Codex, Cursor, OpenCode, and any other agent that reads the [Agent Skills](https://agentskills.io) format.

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

Without `npx`, copy `skills/eyepop` into your agent's skills directory, for example `.claude/skills/eyepop` for Claude Code.

## What the agent can do with it

- Check the machine with `scripts/doctor.sh` and offer the CLI install command for your OS
- Sign in with an API key or the browser flow, and verify the platform answers
- List your models, abilities, Pops, deployments, instances, and datasets with `scripts/inventory.sh`, then prove a run works
- Run inference on files, directories, and URLs and parse the JSON result
- Write a prompt, create an ability, test it on real media, iterate, and give it an alias for the SDK
- Build a dataset, add ground truth, evaluate an ability, and read the metrics
- Create, patch, and delete persistent deployments from the Pop documents in `assets/`
- Set up and operate an on-premise instance, and route runs to it
- Write Python or Node SDK code: sessions, media sources and options, composable Pops, results, the data endpoint, local mode

## Layout

```
skills/eyepop/
  SKILL.md                 the workflow: check, install, sign in, inventory, run, read results
  scripts/doctor.sh        CLI present, credential present, platform reachable; exit code says what is missing
  scripts/inventory.sh     everything the account can run, one section per eyepop get command
  references/cli.md        command map, scripting flags, environment variables, run and evaluate details
  references/abilities.md  create, test, iterate, alias, and evaluate an ability
  references/python-sdk.md Python SDK
  references/node-sdk.md   Node SDK
  references/on-premise.md instances and how runs route on that machine
  references/models.md     pretrained model catalog with label sets
  assets/pop.*.json        Pop documents for eyepop create deployment --pop
evals/                     claude plugin eval cases and graders
```

The skill loads `SKILL.md` first and reaches for a reference only when the task needs it. Facts come from the EyePop docs and the CLI's own `--help`; the CLI is in beta, so the skill tells the agent to trust `eyepop <command> --help` over anything cached here.

## Verify it loaded

Start a session in your project and ask:

> What EyePop skills do you have loaded?

The agent names the `eyepop` skill and summarizes what it covers.

## Evaluate it

The `evals/` directory holds cases for `claude plugin eval` (early access in Claude Code):

```bash
claude plugin eval . --allow-tools Bash Read --report evals/results/report.html
```

## Requirements

- An EyePop account with an active plan, and an API key (`eyp_...`) from https://dashboard.eyepop.ai
- For the SDK paths: Python 3.12+ with `pip install eyepop`, or Node with `npm install @eyepop.ai/eyepop`

## Links

- Docs: https://docs.eyepop.ai
- Dashboard: https://dashboard.eyepop.ai
- Abilities Hub: https://www.eyepop.ai/abilities
- Support: help@eyepop.ai

## License

[MIT](LICENSE)
