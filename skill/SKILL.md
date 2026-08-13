---
name: workspaces
description: Find, read, create, and maintain workspace docs that track experiment goals, design, status, and logs. Use when the user asks about active workstreams, wants to update a workspace, or create a new one.
---

## FIRST: Check for overdue pings

**Every time this skill is invoked**, before doing anything else:

1. Run `ws check-pings`
2. If there are overdue or due-today pings, show them prominently to the user
3. Ask if they want to act on any ping before proceeding with their original request
4. If no pings are due, continue silently

# Workspaces

## What is a workspace?

A workspace is a markdown document that tracks a single investigation thread: its goal, design decisions, experiment status, results, and a chronological log.

## CLI

All workspace operations go through the `ws` CLI (installed at `~/.local/bin/ws`). Key commands:

```bash
ws new <name> --in <dir> [--desc "..."] [--parent <name>]
ws open <name> [--fresh] [--pane] [--yolo]
ws list [--active|--done|--all]
ws status [<name>]
ws edit <name>
ws add <name> <path> [desc]
ws done <name>
ws ping <name> --due <datetime> --task "..."
ws check-pings
ws graph [output.md]
ws dashboard
```

## Registry

All workspaces are indexed in a YAML registry at `$WORKSPACES` (defaults to `~/workspaces.yaml`).

Schema per entry:

```yaml
- name: <short_slug>
  desc: <short description>
  path: <absolute path to workspace .md file>
  tags: [active]    # 'active' = currently being worked on
  parent: <name of parent workspace>  # optional — omit for top-level workspaces
  pings:            # optional — timed reminders
    - due: "2026-07-10T22:00"
      task: "Check if experiment finished, review loss curves"
    - due: "2026-07-11T10:00"
      task: "Compare eval scores"
      done: true    # set when handled
```

The `parent` field links a workspace to the investigation it was spawned from. This lets you trace lineage. Omit the field entirely for root-level workspaces.

### Pings

Pings are timed reminders attached to a workspace. Add with:

```bash
ws ping my-workspace --due "2026-07-10T22:00" --task "Check if experiment finished"
```

Always convert relative times (e.g. "in 10h") to absolute ISO datetimes before adding.

Check all due pings with `ws check-pings`.

To mark a ping as handled, edit the registry and set `done: true` on the ping entry (or remove it).

If a ping needs more context than one line, add a `## Pings` section in the workspace `.md` file:

```markdown
## Pings

### Check ML4 experiment (due 2026-07-10T22:00)
Look at loss curves in wandb, compare against Hero baseline at step 5k.
If converged, proceed to eval. If not, check LR schedule.
```

**Always read the registry first** to find workspaces. When creating or archiving a workspace, update the registry.

## How to find active workspaces

```bash
ws list --active
```

Or read the YAML directly — it's small.

## Workspace document structure

Every workspace doc should follow this structure:

```markdown
# <workspace_id>: <Title>

## Goal
<Practical and/or research question being investigated>

## Design
<Key design decisions, config comparisons, parameter choices>

## Experiments
<Table of experiments: name, scale, config, status>

## Results
<Findings, tables, links to analysis dirs>

## Analysis plan
<What plots/comparisons to produce, where to put them>

## Progress
<Checklist of tasks>

## Log
### YYYY-MM-DD: <event>
<Chronological entries — what happened, decisions made>
```

Not every section is mandatory — use what fits. The Goal and Experiments sections are the most important.

## Creating a new workspace

Use the CLI:

```bash
ws new my-investigation --in ~/projects/my-investigation --desc "Investigate X" --parent parent-ws
```

This creates the markdown file and adds it to the registry. Then populate the Goal and Design sections at minimum.

## Updating a workspace

When experiments finish, results come in, or plans change — update the workspace doc directly. Key things to keep current:

- Experiment status table (running -> finished, step counts)
- Results section with findings
- Log section with dated entries for significant events
- Progress checklist

**Size check:** If the workspace grows above 20k characters, ask the user about compression or splitting before continuing.

## Archiving a workspace

```bash
ws done my-investigation
```

This removes the `active` tag and replaces it with `done`.

## Regenerating the workspace graph

After any change to workspace structure (creating, archiving, reparenting, or renaming a workspace), regenerate the Mermaid graph:

```bash
ws graph workspaces_graph.md
```

Without an argument, `ws graph` prints the mermaid diagram to stdout.
