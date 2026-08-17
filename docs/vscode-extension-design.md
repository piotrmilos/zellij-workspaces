# VS Code Extension: Workspace Dashboard

## Overview

A VS Code extension that brings the `ws` workspace manager into the editor as a native sidebar panel. Instead of switching to a terminal to run `ws list` or `ws dashboard`, you get a live tree view, quick actions, and notifications — all integrated with VS Code's UI.

## Core Features

### 1. Sidebar Tree View

A dedicated view in the Explorer or a custom Activity Bar icon showing all workspaces as a tree.

```
WORKSPACES (2 open / 3 active)
├── * distillation-CE          Running  — OPD from GLM 5.2
│   ├── ! distillation-CE-brainstorm   Waiting  — Brainstorming
│   └── - distillation-experiment-planning  Closed  — Exp plan
└── - sft-scaling              Closed  — SFT scaling laws
```

- **Status icons**: `*` Running (green), `!` Waiting (red), `o` Idle, `-` Closed, `v` Done
- **Parent/child hierarchy** from registry `parent` field
- **Auto-refresh** every few seconds (configurable polling interval) - PM: pool for changes every 0.1 sec, and refress if needed.
- **Filters**: Active / Done / All (toggle buttons at top)

### 2. Context Menu Actions

Right-click any workspace for:

- **Open** → runs `ws open <name>` in a VS Code terminal
- **Open (fresh)** → `ws open <name> --fresh`
- **Open in Pane** → `ws open <name> --pane` (zellij pane)
- **Edit Doc** → opens the workspace `.md` file in the editor
- **Mark Done** → `ws done <name>`
- **Add Ping** → quick input for due date + task, runs `ws ping`
- **Copy Path** → copy workspace doc path to clipboard
- **Open Directory** → open workspace dir in a new VS Code window

### 3. Inline Workspace Doc Preview

Click a workspace to show a read-only preview of its markdown doc in the editor. Double-click to edit. This gives you instant context on any workspace without leaving the sidebar.
PM: can we just make it opne in the editor instead of a readonly prvie.

### 4. Ping Notifications

- On extension activation, run `ws check-pings`
- Show VS Code notifications for overdue/due-today pings
- Each notification has actions: "Open Workspace", "Mark Done", "Snooze 1h"
- Optional: periodic re-check (every 15 min) with notification badge on the sidebar icon

### 5. Status Bar Item

A small status bar widget showing:
```
WS: 2 running · 1 waiting
```
Click to open the sidebar. Changes color when a workspace is waiting for input (red).

### 6. Quick Pick / Command Palette

Commands accessible via `Ctrl+Shift+P`:

- `Workspaces: Open` → quick pick list of active workspaces → opens selected
- `Workspaces: New` → prompts for name, directory, description, parent
- `Workspaces: Dashboard` → opens the terminal dashboard (`ws dashboard`)
- `Workspaces: List` → show quick pick with all workspaces
- `Workspaces: Check Pings` → show overdue pings as notifications
- `Workspaces: Graph` → generate and display mermaid graph in preview

### 7. Workspace Doc Editing Support

- Snippets for common workspace sections (Goal, Experiments table, Log entry)
- Auto-insert dated log entry: `### YYYY-MM-DD: ` with cursor positioned
- Code lens on experiment tables to jump to related wandb/eval links

## Stretch Features

### 8. Live Pane Content Preview

For open workspaces, show a small preview of what Claude is currently doing — last few lines of pane output. Like a mini-terminal view. Uses `zellij action dump-screen`.

### 9. Mermaid Graph Webview

A webview panel rendering the workspace dependency graph as an interactive mermaid diagram. Click nodes to navigate to workspaces. Regenerated on workspace changes.

### 10. Multi-Machine Support

If workspaces run on remote machines (SSH), support reading the registry over SSH or from a shared filesystem. Detect the current machine context and show appropriate workspaces.

### 11. Workspace Templates

Pre-built templates for common patterns:
- Experiment workspace (with wandb links, config tables)
- Literature review workspace
- Bug investigation workspace

`Workspaces: New from Template` in command palette.

### 12. Integration with Claude Code Extension

If the Claude Code VS Code extension is installed:
- "Open in Claude Code" action that launches Claude Code with the workspace context
- Show Claude Code session status directly (not just pane-based detection)

## Architecture

```
vscode-ws-dashboard/
├── package.json          # Extension manifest, commands, views
├── src/
│   ├── extension.ts      # Activation, command registration
│   ├── workspaceTree.ts  # TreeDataProvider for sidebar
│   ├── registry.ts       # Parse workspaces.yaml, watch for changes
│   ├── paneStatus.ts     # Shell out to ws/zellij for status
│   ├── pings.ts          # Ping checking and notifications
│   ├── statusBar.ts      # Status bar widget
│   └── graphView.ts      # Mermaid webview panel
├── resources/
│   └── icons/            # Tree view icons
└── README.md
```

### Key Design Decisions

**Shell out to `ws` CLI vs. read YAML directly?**
Read YAML directly for the tree view (faster, no process spawn per refresh). Use `ws` CLI for mutations (open, new, done, ping) to stay consistent and avoid reimplementing logic.

**Polling vs. file watching?**
File-watch `workspaces.yaml` for registry changes (instant). Poll zellij for pane status (every 2-5s, configurable). No polling when VS Code is in background.

**Zellij dependency?**
Status detection is best-effort. Without zellij or outside a zellij session, the tree still shows all workspaces — just without Running/Waiting/Idle status. Graceful degradation.

## Configuration

```jsonc
{
  "workspaces.registryPath": "~/workspaces.yaml",
  "workspaces.pollInterval": 3,          // seconds
  "workspaces.showInActivityBar": true,   // own icon vs Explorer section
  "workspaces.pingCheckInterval": 15,     // minutes, 0 to disable
  "workspaces.defaultOpenMode": "terminal" // "terminal" | "pane"
}
```

## Priority

| Priority | Feature | Effort | Decision |
|----------|---------|--------|
| P0 | Sidebar tree view with hierarchy | M | + |
| P0 | Context menu actions (open, edit, done) | S | - |
| P0 | Command palette commands | S | - |
| P1 | Ping notifications | S | - |
| P1 | Status bar widget | S | + |
| P1 | Workspace doc preview on click | S | + |
| P2 | Live status detection (zellij) | M | - |
| P2 | Mermaid graph webview | M | - |
| P3 | Pane content preview | L | - |
| P3 | Templates | S | - |
| P3 | Claude Code integration | M | - |
