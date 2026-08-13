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
ws ping <name> --due "2026-07-10T22:00" --task "Check results"
ws check-pings       # Show due/overdue pings
ws graph [out.md]    # Generate mermaid graph of workspace tree
```

## Registry Format

The `workspaces.yaml` file is a YAML list:
```yaml
- name: my-project
  desc: Project description
  path: ~/workspaces/my-project/my-project_workspace.md
  tags: [active]
  parent: other-project  # optional — omit for top-level workspaces
  pings:                 # optional — timed reminders
    - due: "2026-07-10T22:00"
      task: "Check if experiment finished"
    - due: "2026-07-11T10:00"
      task: "Compare eval scores"
      done: true
```

## Claude Code Skill

The installer places a [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) at `~/.claude/skills/workspaces/SKILL.md`. This teaches Claude Code how to find, create, update, and archive workspaces using the `ws` CLI, and automatically checks for overdue pings when invoked.

Trigger it with `/workspaces` in Claude Code, or it activates automatically when you ask about workstreams or workspaces.

## Editor Integration

### VSCode / Cursor

Add to `.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "ws: Open Workspace",
      "type": "shell",
      "command": "ws open ${input:workspaceName}",
      "presentation": { "reveal": "always", "panel": "dedicated" },
      "problemMatcher": []
    },
    {
      "label": "ws: Open Workspace (Fresh)",
      "type": "shell",
      "command": "ws open ${input:workspaceName} --fresh",
      "presentation": { "reveal": "always", "panel": "dedicated" },
      "problemMatcher": []
    },
    {
      "label": "ws: New Workspace",
      "type": "shell",
      "command": "ws new ${input:workspaceName}",
      "presentation": { "reveal": "always" },
      "problemMatcher": []
    },
    {
      "label": "ws: Dashboard",
      "type": "shell",
      "command": "ws dashboard",
      "presentation": { "reveal": "always", "panel": "dedicated" },
      "problemMatcher": []
    },
    {
      "label": "ws: List",
      "type": "shell",
      "command": "ws list",
      "presentation": { "reveal": "always" },
      "problemMatcher": []
    }
  ],
  "inputs": [
    {
      "id": "workspaceName",
      "type": "promptString",
      "description": "Workspace name"
    }
  ]
}
```

Add to `.vscode/keybindings.json` (user keybindings):
```json
[
  { "key": "ctrl+shift+w o", "command": "workbench.action.tasks.runTask", "args": "ws: Open Workspace" },
  { "key": "ctrl+shift+w n", "command": "workbench.action.tasks.runTask", "args": "ws: New Workspace" },
  { "key": "ctrl+shift+w d", "command": "workbench.action.tasks.runTask", "args": "ws: Dashboard" },
  { "key": "ctrl+shift+w l", "command": "workbench.action.tasks.runTask", "args": "ws: List" }
]
```

Add to `.vscode/settings.json` to set the registry path:
```json
{
  "terminal.integrated.env.osx": {
    "WORKSPACES": "${env:HOME}/workspaces.yaml"
  },
  "terminal.integrated.env.linux": {
    "WORKSPACES": "${env:HOME}/workspaces.yaml"
  }
}
```

### Zellij Layout

Add a dedicated workspace pane to your zellij layout (`~/.config/zellij/layouts/default.kdl`):
```kdl
layout {
    pane split_direction="vertical" {
        pane size="70%"
        pane split_direction="horizontal" {
            pane name="dashboard" command="ws" {
                args "dashboard"
            }
            pane name="terminal"
        }
    }
}
```

### Fish Shell

Add to `~/.config/fish/config.fish`:
```fish
set -gx WORKSPACES ~/workspaces.yaml

# Abbreviations for quick access
abbr -a wso 'ws open'
abbr -a wsn 'ws new'
abbr -a wsl 'ws list'
abbr -a wsd 'ws dashboard'
```

### Bash/Zsh

Add to `~/.bashrc` or `~/.zshrc`:
```bash
export WORKSPACES=~/workspaces.yaml

# Aliases for quick access
alias wso='ws open'
alias wsn='ws new'
alias wsl='ws list'
alias wsd='ws dashboard'
```

## License

MIT
