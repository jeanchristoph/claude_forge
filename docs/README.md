# Regenerating the demo

`demo.gif` is generated from two versioned sources:

- `demo.sh` — replays forge's output with chosen timings
- `demo.tape` — drives the recording (size, font, theme, hidden launch command)

```bash
vhs docs/demo.tape      # run from the repository root
```

## Prerequisites

Linux, or WSL on Windows — VHS does not work reliably on native Windows.

| Tool | Install |
|---|---|
| `ffmpeg`, `chromium` | `apt-get install ffmpeg chromium` |
| `ttyd` | binary from [tsl0922/ttyd releases](https://github.com/tsl0922/ttyd/releases) — dropped from Debian 13 |
| `vhs` | binary from [charmbracelet/vhs releases](https://github.com/charmbracelet/vhs/releases) |

**Do not run as root**: Chromium refuses to start with those privileges and VHS hangs
with no error until it times out.

## Rules

`demo.sh` reproduces the skill's output **word for word**, taken from `skill/phases/`.
A reconstructed demo is fine; a demo showing behaviour the tool does not have is not.

Keep the GIF under 5 MB and around 1100 px wide, otherwise GitHub takes seconds to
display it. After editing `demo.sh`, check the total duration and adjust the `Sleep`
in `demo.tape` to match — trailing frozen frames are wasted bytes.
