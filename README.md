# zellij-workspaces

A lightweight workspace manager for running multiple Claude Code sessions in parallel zellij panes.

## Features

- Central YAML registry mapping workspace names to markdown docs and directories
- Tree view dashboard showing workspace status (Running/Waiting/Idle)
- Automatic pane renaming when opening/closing workspaces
- Docker container support for isolated workspaces
- Integration with Claude Code's session continuity

## Requirements

- [zellij](https://zellij.dev/) terminal multiplexer
- [Claude Code](https://claude.ai/code) CLI (`claude`)
- Python 3.8+
- bash

## Installation

```bash
git clone https://github.com/yourusername/zellij-workspaces.git
cd zellij-workspaces
./install.sh
```

This installs `ws` and `ws-dashboard` to `~/.local/bin` (or specify a different path as argument).

Make sure `~/.local/bin` is in your PATH:
```bash
# bash/zsh
export PATH="$HOME/.local/bin:$PATH"

# fish
fish_add_path ~/.local/bin
```

## Configuration

Set the `WORKSPACES` environment variable to point to your registry file:
```bash
export WORKSPACES=~/workspaces.yaml
```

Or it defaults to `~/workspaces.yaml`.

## Usage

### Create a workspace
```bash
ws new my-project
# Creates ~/workspaces/my-project/ with a workspace doc
```

### Open a workspace
```bash
ws open my-project          # Continue existing session
ws open my-project --fresh  # Start fresh with workspace context
ws open my-project --yolo   # Skip permission prompts (--dangerously-skip-permissions)
ws open my-project --docker # Run in Docker container
ws open my-project --pane   # Open in new zellij pane
```

### View dashboard
```bash
ws dashboard
```

The dashboard shows a tree of all workspaces with their status:
- **Running** - Claude is actively processing
- **Waiting** - Claude is waiting for input
- **Idle** - Pane is open but Claude isn't active

Press `q` to quit the dashboard.

### Other commands
```bash
ws list              # List all workspaces
ws status            # Quick status of open workspaces
ws close <name>      # Mark workspace as closed
ws done <name>       # Mark workspace as done
ws edit <name>       # Edit workspace doc
ws add <name> <dir>  # Add existing directory as workspace
```

## Registry Format

The `workspaces.yaml` file:
```yaml
workspaces:
  my-project:
    doc: ~/workspaces/my-project/WORKSPACE.md
    dir: ~/workspaces/my-project
    status: active
    parent: null
    description: Project description
```

## License

MIT
