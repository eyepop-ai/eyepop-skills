# On-premise instances

An **instance** is the EyePop runtime installed on one machine you control, serving one Pop. While a machine has an instance the CLI on it is **on-premise**: runs go to the local hardware and nothing stands up EyePop compute.

Docs: https://docs.eyepop.ai/developer-documentation/cli/on-premise (CLI) and https://docs.eyepop.ai/developer-documentation/deploying/on-premise (Compose package, discrete GPUs).

## Prerequisites

- Docker with Compose v2
- An API key: `EYEPOP_API_KEY`, `--api-key`, or let `init` prompt on a terminal

## Set up

```bash
eyepop instance init --pop eyepop.person:latest
```

One command detects the hardware profile, checks prerequisites, installs a registry credential when docker holds none, registers the instance with your account, pulls the runtime image (several gigabytes, silent unless `EYEPOP_LOG_LEVEL=debug`), and starts the container. Done when it reports healthy; `eyepop run --media-path image.jpg` then runs on the instance.

Everything lives in the **instance root**, `~/.eyepop` by default (`--config-dir` renames it; `EYEPOP_INSTANCE_DIR` points every command, `run` included, at one). It holds `docker-compose.yml`, `eyepop-instance.yml` (your API key in plaintext, mode `0600`), `pop.json`, and `license.pem` when issued.

Useful `init` flags: `--name` (defaults to the hostname), `--tag` (runtime image tag), `--profile`, `--bind`, `--wait` (seconds to wait for healthy, 300 default), `--yes` (accept defaults, Pop defaults to `eyepop.person:latest`), `--dump` (render the files into `./eyepop-instance/` and stop, touching nothing else).

## Hardware profiles

`eyepop system` reports what the machine is and the profile it maps to; `--json` adds detail.

| Profile | Hardware | Provisionable by `init` |
|---|---|---|
| `cpu` | Any machine | yes |
| `cuda-jetpack6` | NVIDIA Jetson on JetPack 6 | yes |
| `qnn` | Qualcomm Dragonwing with the QAIRT SDK on the host | yes |
| `cuda` | Discrete NVIDIA GPU | refused; use `--profile cpu` or the Compose package |
| `openvino` | Intel GPU | refused; use `--profile cpu` or the Compose package |

QNN: install the QAIRT SDK first, in `/opt/qcom/aistack/qairt`, `/opt/qairt`, `/usr/local/qairt`, or `$XDG_DATA_HOME/eyepop/qairt` (exactly one; `QAIRT_SDK_ROOT` overrides). The host needs the `fastrpc` group with `/dev/fastrpc-*` nodes, or the machine is not detected as `qnn`, and the `dmaheap` group, or `eyepop system` reports `QNN.ready` false.

## How runs route on an on-premise machine

| Run | Goes to |
|---|---|
| `eyepop run --pop <pop> --media-path <media>` | The instance, before any catalog lookup. Prefer this form |
| `eyepop run --media-path <media>` (no target) | The instance, serving its configured Pop |
| `eyepop run --model <published model> --media-path <media>` | The instance, after resolving the alias against the platform (so it needs network); bills no compute |
| `eyepop run --model <VLM-only ability> --media-path <media>` | Cloud inference, and it bills. Use `--pop` instead |
| `eyepop run --session <uuid> --media-path <media>` | That cloud session |

A target naming a single ability is refused when it mismatches the single ability the instance serves; a Pop-name target, or an instance serving a composed Pop, is served as configured. On-premise runs create no session, so `eyepop get sessions` shows nothing new. Commands that would start EyePop compute, `create deployment` among them, answer that they are disabled on-premise; reads work as always.

A stopped instance has no cloud fallback: `run` reports the instance is not responding and names `eyepop instance start`.

## Operate

| Command | Effect |
|---|---|
| `eyepop instance stop` / `start` / `restart` | Container lifecycle; state and registration survive a stop |
| `eyepop instance set pop <pop>` | Serve a different Pop: resolves it against your account first, rewrites `pop.json`, recreates the container, keeps the model cache. Down for the recreate, waits up to `--wait` |
| `eyepop instance logs --tail 50` | Runtime logs; `--follow` streams |
| `eyepop system` | Hardware and profile |
| `eyepop get instances` | The account's instances |

## Repair

Re-run `eyepop instance init`. A deleted container, wiped volume, or half-written instance root all heal, and the instance keeps its identity and billing history. When the root is gone but the account still holds a record under this hostname, `init` adopts it, except a record registered in the last 24 hours, which needs `--adopt <uuid>` to confirm this machine replaces it.

## Remove

```bash
eyepop instance delete --yes
```

Removes containers, volumes including the model cache, the network, the pulled image, the instance root, the account record, and the registry credential the CLI minted (with `docker logout`). `--uuid <instance-uuid>` deletes only the account record of a machine you no longer have.

## From the SDK

Local mode points the SDK at `http://127.0.0.1:8080` with no credentials; pass the Pop the instance serves. See [python-sdk.md](python-sdk.md#local-mode-on-premise-instance) and [node-sdk.md](node-sdk.md#local-mode-on-premise-instance).
