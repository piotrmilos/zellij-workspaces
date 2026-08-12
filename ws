#!/usr/bin/env bash
# ws - Workspace manager for zellij + Claude Code
# Prototype implementation based on zellij_workspaces_design.md

set -euo pipefail

REGISTRY_FILE="${WORKSPACES:-$HOME/workspaces.yaml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure registry exists
ensure_registry() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo "# Workspace registry" > "$REGISTRY_FILE"
    fi
}

# Parse YAML registry (simple line-based parsing)
# Returns: name|desc|path|tags|parent
get_workspaces() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        return
    fi

    WS_REGISTRY="$REGISTRY_FILE" WS_HOME="$HOME" python3 -c '
import yaml
import os

registry_file = os.environ["WS_REGISTRY"]
home = os.environ["WS_HOME"]

with open(registry_file) as f:
    data = yaml.safe_load(f) or []
for ws in data:
    name = ws.get("name", "")
    desc = ws.get("desc", "")
    path = ws.get("path", "").replace("~", home)
    tags = ",".join(ws.get("tags", []))
    parent = ws.get("parent", "")
    container = ws.get("container", {}).get("image", "")
    worktree_branch = ws.get("worktree", {}).get("branch", "")
    print(f"{name}|{desc}|{path}|{tags}|{parent}|{container}|{worktree_branch}")
'
}

# Get single workspace by name
get_workspace() {
    local name="$1"
    get_workspaces | grep "^${name}|" | head -1
}

# Add workspace to registry
add_to_registry() {
    local name="$1"
    local desc="$2"
    local path="$3"
    local parent="${4:-}"

    WS_REGISTRY="$REGISTRY_FILE" \
    WS_NAME="$name" \
    WS_DESC="$desc" \
    WS_PATH="$path" \
    WS_PARENT="$parent" \
    python3 -c '
import yaml
import os

registry_file = os.environ["WS_REGISTRY"]
name = os.environ["WS_NAME"]
desc = os.environ["WS_DESC"]
path = os.environ["WS_PATH"]
parent = os.environ.get("WS_PARENT") or None

# Load existing
with open(registry_file) as f:
    data = yaml.safe_load(f) or []

# Check for duplicate
for ws in data:
    if ws.get("name") == name:
        print(f"Error: workspace {name} already exists")
        exit(1)

# Add new entry
entry = {
    "name": name,
    "desc": desc,
    "path": path,
    "tags": ["active"]
}
if parent:
    entry["parent"] = parent

data.append(entry)

# Write back
with open(registry_file, "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
'
}

# Mark workspace as done
mark_done() {
    local name="$1"

    WS_REGISTRY="$REGISTRY_FILE" WS_NAME="$name" python3 -c '
import yaml
import os

registry_file = os.environ["WS_REGISTRY"]
name = os.environ["WS_NAME"]

with open(registry_file) as f:
    data = yaml.safe_load(f) or []

found = False
for ws in data:
    if ws.get("name") == name:
        found = True
        ws["tags"] = ["done"]
        break

if not found:
    print(f"Error: workspace {name} not found")
    exit(1)

with open(registry_file, "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
'
}

# Get zellij panes as name|id pairs
get_panes() {
    if ! command -v zellij &>/dev/null; then
        return
    fi

    # Try to get panes, fail silently if not in zellij session
    zellij action list-panes --json 2>/dev/null | \
        python3 -c '
import json
import sys
try:
    data = json.load(sys.stdin)
    for pane in data:
        title = pane.get("title", "")
        pane_id = pane.get("id", 0)
        print(f"{title}|{pane_id}")
except:
    pass
' 2>/dev/null || true
}

# Check if pane exists for workspace
pane_exists() {
    local name="$1"
    get_panes | grep -q "^${name}|"
}

# Get pane ID for workspace
get_pane_id() {
    local name="$1"
    get_panes | grep "^${name}|" | cut -d'|' -f2
}

# Create new workspace
cmd_new() {
    local name=""
    local dir=""
    local desc=""
    local parent=""
    local filename=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --in)
                dir="$2"
                shift 2
                ;;
            --desc)
                desc="$2"
                shift 2
                ;;
            --parent)
                parent="$2"
                shift 2
                ;;
            --file)
                filename="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo "Usage: ws new <name> --in <dir> [--desc \"...\"] [--parent <name>] [--file <name>.md]" >&2
        exit 1
    fi

    if [[ -z "$dir" ]]; then
        echo "Error: --in <dir> is required" >&2
        exit 1
    fi

    # Expand ~ and make absolute
    dir="${dir/#\~/$HOME}"
    mkdir -p "$dir"
    dir="$(cd "$dir" && pwd)"

    # Default filename
    if [[ -z "$filename" ]]; then
        filename="${name}_workspace.md"
    fi

    local workspace_path="$dir/$filename"

    # Check if file already exists
    if [[ -f "$workspace_path" ]]; then
        echo -e "${YELLOW}Warning: $workspace_path already exists${NC}"
        read -p "Use existing file? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        # Create workspace document
        mkdir -p "$dir"
        cat > "$workspace_path" << EOF
# ${name}: Workspace

## Goal
${desc:-"(describe the goal of this investigation)"}

## Design
Key decisions and approach...

## Experiments
| Name | Config | Status |
|------|--------|--------|
| | | |

## Results
*To be filled in*

## Log
### $(date +%Y-%m-%d): Created
- Workspace initialized
EOF
        echo -e "${GREEN}Created:${NC} $workspace_path"
    fi

    # Add to registry
    ensure_registry
    add_to_registry "$name" "${desc:-$name}" "$workspace_path" "$parent"
    echo -e "${GREEN}Registered:${NC} $name"
}

# Open workspace in current terminal (or new pane with --pane)
cmd_open() {
    local name=""
    local fresh=false
    local new_pane=false
    local skip_perms=false
    local use_docker=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fresh)
                fresh=true
                shift
                ;;
            --pane)
                new_pane=true
                shift
                ;;
            --yolo|--dangerously-skip-permissions)
                skip_perms=true
                shift
                ;;
            --docker)
                shift
                # Check if next arg is an image (not a flag and not empty)
                if [[ $# -gt 0 && "${1:-}" != -* ]]; then
                    use_docker="$1"
                    shift
                else
                    use_docker="node:20"
                fi
                ;;
            -*)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo "Usage: ws open <name> [--fresh] [--pane] [--yolo] [--docker [image]]" >&2
        exit 1
    fi

    local ws
    ws=$(get_workspace "$name")
    if [[ -z "$ws" ]]; then
        echo "Error: workspace '$name' not found" >&2
        exit 1
    fi

    local path desc
    path=$(echo "$ws" | cut -d'|' -f3)
    path="${path/\$HOME/$HOME}"
    desc=$(echo "$ws" | cut -d'|' -f2)

    local workdir
    workdir=$(dirname "$path")

    if [[ ! -d "$workdir" ]]; then
        echo "Error: directory does not exist: $workdir" >&2
        exit 1
    fi

    # Check for container config (from registry or --docker flag)
    local container
    container=$(echo "$ws" | cut -d'|' -f6)
    [[ -n "$use_docker" ]] && container="$use_docker"

    # Build claude args
    local claude_args=()
    [[ "$fresh" != "true" ]] && claude_args+=("-c")
    [[ "$skip_perms" == "true" ]] && claude_args+=("--dangerously-skip-permissions")

    # For fresh sessions, show context hint
    show_fresh_hint() {
        echo -e "${DIM}Workspace: $name${NC}"
        echo -e "${DIM}Doc: $path${NC}"
        echo -e "${DIM}Tip: Start with 'read $path and /workspaces'${NC}"
        echo ""
    }

    local pane_title="~~~ Workspace: $name ~~~"

    if [[ -n "$container" ]]; then
        local container_name="ws-sandbox-$name"

        # In Docker: --yolo doesn't work as root, and -c won't find host sessions
        if [[ "$skip_perms" == "true" ]]; then
            echo -e "${YELLOW}Warning: --yolo ignored in Docker (root not allowed)${NC}"
        fi
        # Always fresh in Docker (sessions are path-specific, /workspace != host path)
        claude_args=()

        # Ensure container exists and is running (AoE-style: docker run -d with sleep infinity)
        if ! docker container inspect "$container_name" &>/dev/null; then
            echo -e "${DIM}Creating container $container_name...${NC}"
            # Use docker run -d (like AoE) - creates and starts in one command
            # Mount workspace at same path as host for session compatibility
            # Pass ANTHROPIC_API_KEY via -e KEY (value inherited from env, not in argv)
            # Pass all ANTHROPIC_* and CLAUDE_* env vars to container
            local env_args=()
            while IFS='=' read -r key value; do
                [[ -n "$key" ]] && env_args+=("-e" "$key")
            done < <(env | grep -E "^(ANTHROPIC_|CLAUDE_)" | cut -d= -f1 | sort -u)

            docker run -d \
                --name "$container_name" \
                -v "$workdir:$workdir" \
                -v "$HOME/.claude:/root/.claude" \
                -v "$HOME/.claude.json:/root/.claude.json" \
                -w "$workdir" \
                "${env_args[@]}" \
                -e TERM=xterm-256color \
                "$container" \
                sleep infinity
        else
            docker start "$container_name" 2>/dev/null || true
        fi

        # Install claude if not present
        if ! docker exec "$container_name" which claude &>/dev/null; then
            echo -e "${DIM}Installing claude in container...${NC}"
            docker exec "$container_name" npm install -g @anthropic-ai/claude-code
        fi

        echo -e "${GREEN}Opening${NC} $name ${DIM}(container: $container)${NC}"
        if [[ "$new_pane" == "true" ]]; then
            zellij action new-pane --name "$pane_title" -- docker exec -it "$container_name" claude ${claude_args[@]+"${claude_args[@]}"}
        else
            # Capture original pane title before renaming
            local original_title
            original_title=$(zellij action list-panes --json 2>/dev/null | python3 -c '
import json,sys
for p in json.load(sys.stdin):
    if p.get("is_focused"):
        print(p.get("title", ""))
        break
' 2>/dev/null || echo "")

            # Setup cleanup trap to restore original pane title on exit/interrupt
            trap "zellij action rename-pane '$original_title' 2>/dev/null || true" EXIT INT TERM

            zellij action rename-pane "$pane_title" 2>/dev/null || true
            [[ "$fresh" == "true" ]] && show_fresh_hint
            docker exec -it "$container_name" claude ${claude_args[@]+"${claude_args[@]}"}
            # Cleanup runs via trap
        fi
    else
        echo -e "${GREEN}Opening${NC} $name"
        cd "$workdir"
        if [[ "$new_pane" == "true" ]]; then
            zellij action new-pane --name "$pane_title" --cwd "$workdir" -- claude ${claude_args[@]+"${claude_args[@]}"}
        else
            # Capture original pane title before renaming
            local original_title
            original_title=$(zellij action list-panes --json 2>/dev/null | python3 -c '
import json,sys
for p in json.load(sys.stdin):
    if p.get("is_focused"):
        print(p.get("title", ""))
        break
' 2>/dev/null || echo "")

            # Setup cleanup trap to restore original pane title on exit/interrupt
            trap "zellij action rename-pane '$original_title' 2>/dev/null || true" EXIT INT TERM

            zellij action rename-pane "$pane_title" 2>/dev/null || true
            [[ "$fresh" == "true" ]] && show_fresh_hint
            claude ${claude_args[@]+"${claude_args[@]}"}
            # Cleanup runs via trap
        fi
    fi
}

# Close workspace pane
cmd_close() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: ws close <name>" >&2
        exit 1
    fi

    if ! pane_exists "$name"; then
        echo "Pane '$name' not open" >&2
        return
    fi

    local pane_id
    pane_id=$(get_pane_id "$name")

    # Focus and close
    zellij action focus-pane --pane-id "terminal_$pane_id" 2>/dev/null || true
    zellij action close-pane 2>/dev/null || true

    echo -e "${DIM}Closed${NC} $name"
}

# Mark workspace as done
cmd_done() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: ws done <name>" >&2
        exit 1
    fi

    # Close pane if open
    if pane_exists "$name"; then
        cmd_close "$name"
    fi

    # Mark as done in registry
    mark_done "$name"
    echo -e "${GREEN}Marked done:${NC} $name"
}

# List workspaces
cmd_list() {
    local filter="active"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --active) filter="active"; shift ;;
            --done) filter="done"; shift ;;
            --all) filter="all"; shift ;;
            *) shift ;;
        esac
    done

    ensure_registry

    local panes
    panes=$(get_panes)

    echo -e "${BOLD}Workspaces${NC} (filter: $filter)"
    echo

    local count=0
    while IFS='|' read -r name desc path tags parent container worktree; do
        [[ -z "$name" ]] && continue

        # Apply filter
        case "$filter" in
            active)
                [[ "$tags" != *active* ]] && continue
                ;;
            done)
                [[ "$tags" != *done* ]] && continue
                ;;
        esac

        # Check if pane is open
        local status_icon="${DIM}-${NC}"
        local is_open=false
        if echo "$panes" | grep -q "^${name}|"; then
            is_open=true
            status_icon="${GREEN}*${NC}"
        fi

        if [[ "$tags" == *done* ]]; then
            status_icon="${DIM}v${NC}"
        fi

        # Build suffix
        local suffix=""
        [[ -n "$container" ]] && suffix+=" [docker]"
        [[ -n "$worktree" ]] && suffix+=" [worktree: $worktree]"
        [[ -n "$parent" ]] && suffix+=" (from: $parent)"

        # Print
        local indent=""
        [[ -n "$parent" ]] && indent="  "

        printf "%s%b %s%b - %s%s\n" \
            "$indent" "$status_icon" "$name" "${NC}" "$desc" "$suffix"

        ((count++))
    done < <(get_workspaces)

    if [[ $count -eq 0 ]]; then
        echo -e "${DIM}No workspaces found${NC}"
    fi
}

# Open dashboard
cmd_dashboard() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local dashboard_script="$script_dir/ws-dashboard.py"
    local venv_python="$script_dir/.venv/bin/python"

    if [[ ! -f "$dashboard_script" ]]; then
        echo "Error: dashboard script not found at $dashboard_script" >&2
        exit 1
    fi

    if [[ ! -f "$venv_python" ]]; then
        echo "Error: venv not found. Run: cd $script_dir && uv venv && uv pip install rich pyyaml" >&2
        exit 1
    fi

    exec "$venv_python" "$dashboard_script"
}

# Edit workspace document
cmd_edit() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: ws edit <name>" >&2
        exit 1
    fi

    local ws
    ws=$(get_workspace "$name")
    if [[ -z "$ws" ]]; then
        echo "Error: workspace '$name' not found" >&2
        exit 1
    fi

    local path
    path=$(echo "$ws" | cut -d'|' -f3)
    path="${path/\$HOME/$HOME}"

    ${EDITOR:-vim} "$path"
}

# Add existing workspace doc to registry
cmd_add() {
    local name="$1"
    local path="$2"
    local desc="${3:-$name}"

    if [[ -z "$name" || -z "$path" ]]; then
        echo "Usage: ws add <name> <path> [desc]" >&2
        exit 1
    fi

    # Expand and validate path
    path="${path/#\~/$HOME}"
    if [[ ! -f "$path" ]]; then
        echo "Error: file not found: $path" >&2
        exit 1
    fi

    path="$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"

    ensure_registry
    add_to_registry "$name" "$desc" "$path"
    echo -e "${GREEN}Added:${NC} $name -> $path"
}

# Show status
cmd_status() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        # Show all open panes
        echo -e "${BOLD}Open workspace panes:${NC}"
        get_panes | while IFS='|' read -r pname pid; do
            [[ -z "$pname" ]] && continue
            echo "  $pname (pane $pid)"
        done
        return
    fi

    local ws
    ws=$(get_workspace "$name")
    if [[ -z "$ws" ]]; then
        echo "Error: workspace '$name' not found" >&2
        exit 1
    fi

    local path desc tags parent container worktree
    IFS='|' read -r _ desc path tags parent container worktree <<< "$ws"
    path="${path/\$HOME/$HOME}"

    echo -e "${BOLD}$name${NC}"
    echo "  Path: $path"
    echo "  Desc: $desc"
    echo "  Tags: $tags"
    [[ -n "$parent" ]] && echo "  Parent: $parent"
    [[ -n "$container" ]] && echo "  Container: $container"
    [[ -n "$worktree" ]] && echo "  Worktree: $worktree"

    if pane_exists "$name"; then
        echo -e "  Pane: ${GREEN}open${NC}"
    else
        echo -e "  Pane: ${DIM}closed${NC}"
    fi
}

# Print usage
usage() {
    cat << 'EOF'
ws - Workspace manager for zellij + Claude Code

Usage:
  ws new <name> --in <dir> [--desc "..."] [--parent <name>]
  ws open <name> [--fresh] [--pane] [--yolo] [--docker [image]]
  ws close <name>
  ws done <name>
  ws list [--active|--done|--all]
  ws status [<name>]
  ws dashboard
  ws edit <name>
  ws add <name> <path> [desc]

Options for 'open':
  --fresh   Start new Claude session (not continue)
  --pane    Open in new zellij pane (default: current pane)
  --yolo    Skip permission prompts (--dangerously-skip-permissions)
  --docker  Run in Docker container (default image: node:20)

Examples:
  ws new feature-x --in ~/projects/feature_x --desc "Feature X investigation"
  ws open feature-x
  ws open feature-x --fresh --yolo    # New session, skip prompts
  ws open feature-x --docker node:20  # Run in node container
  ws list --active
  ws done feature-x
EOF
}

# Main
main() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        new)      cmd_new "$@" ;;
        open)     cmd_open "$@" ;;
        close)    cmd_close "$@" ;;
        done)     cmd_done "$@" ;;
        list|ls)  cmd_list "$@" ;;
        status)   cmd_status "$@" ;;
        dashboard) cmd_dashboard "$@" ;;
        edit)     cmd_edit "$@" ;;
        add)      cmd_add "$@" ;;
        -h|--help|help|"")
            usage
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
